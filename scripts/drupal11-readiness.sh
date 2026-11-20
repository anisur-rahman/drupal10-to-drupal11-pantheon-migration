#!/usr/bin/env bash
# Read-only audit of a Drupal 10 site's readiness for Drupal 11.
# Checks core version, PHP, database server, removed core modules, custom
# extension info.yml constraints and Composer blockers.
#
# Usage: scripts/drupal11-readiness.sh [--docroot web] [--run-upgrade-status]
#   --run-upgrade-status   also run 'drush upgrade_status:analyze --all' (slow)
#
# Run from the project root. Override tools with DRUSH="ddev drush" / COMPOSER_CMD="ddev composer".
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DOCROOT="web"
RUN_US=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --docroot) DOCROOT="${2:?missing value}"; shift 2 ;;
    --run-upgrade-status) RUN_US=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

resolve_drush
resolve_composer

section "Drupal core"
version="$(drush_quiet status --field=drupal-version)"
[[ -n "$version" ]] || die "Drush could not bootstrap Drupal"
if version_ge "$version" 11.0; then
  info "Site already runs Drupal $version; use verify-upgrade.sh instead"
elif version_ge "$version" 10.3; then
  pass "Drupal $version (10.3+ is required before upgrading to 11)"
else
  fail "Drupal $version: update to the latest Drupal 10 minor release first"
fi

section "Platform"
php_v="$(drush_quiet status --field=php-version)"
if [[ -n "$php_v" ]] && version_ge "$php_v" 8.3; then pass "PHP $php_v"
else fail "PHP ${php_v:-unknown}: Drupal 11 requires PHP 8.3+"; fi

driver="$(drush_quiet status --field=db-driver)"
db_v="$(drush_quiet sql:query 'SELECT VERSION()' | last_line)"
case "$driver" in
  mysql)
    num="$(extract_version "$db_v")"
    if printf '%s' "$db_v" | grep -qi mariadb; then
      if version_ge "$num" 10.6; then pass "MariaDB $num"
      else fail "MariaDB $num: Drupal 11 requires 10.6+ (Pantheon: set database.version: 10.6 in pantheon.yml)"; fi
    elif [[ -n "$num" ]]; then
      if version_ge "$num" 8.0; then pass "MySQL $num"
      else fail "MySQL $num: Drupal 11 requires 8.0+"; fi
    else
      warn "Could not read database version"
    fi ;;
  '') warn "Could not determine database driver" ;;
  *) info "Database driver '$driver': check Drupal 11 system requirements manually" ;;
esac

section "Core modules removed in Drupal 11"
enabled="$(drush_quiet pm:list --type=module --status=enabled --format=tsv --fields=name,path)"
found=0
for entry in $D11_REMOVED_MODULES; do
  name="${entry%%:*}"; repl="${entry#*:}"
  path="$(printf '%s\n' "$enabled" | awk -F'\t' -v n="$name" '$1 == n { print $2 }')"
  [[ -z "$path" ]] && continue
  found=1
  if [[ "$path" == core/* ]]; then
    if [[ "$repl" == drupal/* ]]; then
      fail "$name is enabled from core: run 'composer require $repl' before upgrading, or uninstall it"
    else
      fail "$name is enabled: uninstall it ($repl)"
    fi
  else
    pass "$name is already provided by contrib ($path)"
  fi
done
[[ "$found" -eq 0 ]] && pass "None of the removed core modules are enabled"

section "Custom extensions"
custom_found=0
for dir in "$DOCROOT/modules/custom" "$DOCROOT/themes/custom" "$DOCROOT/profiles/custom"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r info_file; do
    custom_found=1
    req="$(grep -E '^core_version_requirement:' "$info_file" | head -n1 || true)"
    if printf '%s' "$req" | grep -q '\^11'; then
      pass "$info_file declares Drupal 11 support"
    else
      fail "$info_file: core_version_requirement lacks ^11 (${req:-missing})"
    fi
  done < <(find "$dir" -name '*.info.yml' -not -path '*/tests/*' 2>/dev/null)
done
[[ "$custom_found" -eq 0 ]] && info "No custom modules, themes or profiles under $DOCROOT"

section "Composer"
if [[ "${#COMPOSER_RUN[@]}" -gt 0 && -f composer.json ]]; then
  # Symfony and core-recommended lines are expected (resolved by 'composer update -W');
  # the real blockers are other packages whose constraint excludes drupal/core 11.
  why="$("${COMPOSER_RUN[@]}" why-not drupal/core 11.0.0 2>&1 || true)"
  blockers="$(printf '%s\n' "$why" | sed "s/^.*stdout='//" \
    | grep -E 'requires +drupal/core \(' | grep -vE '^drupal/core-recommended ' | sort -u || true)"
  if [[ -z "$blockers" ]]; then
    pass "No package other than drupal/core-recommended pins drupal/core below 11"
  else
    fail "Packages whose constraints exclude Drupal 11 (update, patch or remove):"
    printf '%s\n' "$blockers" | sed 's/^/       /'
  fi
  info "Full detail: composer why-not drupal/core 11.0.0"
else
  warn "Composer not available or no composer.json; skipped dependency check"
fi

section "Upgrade Status"
if printf '%s\n' "$enabled" | awk -F'\t' '$1 == "upgrade_status"' | grep -q .; then
  pass "upgrade_status module is enabled"
  if [[ "$RUN_US" -eq 1 ]]; then
    run_drush upgrade_status:analyze --all || warn "Upgrade Status reported problems (see above)"
  else
    info "Run with --run-upgrade-status, or open /admin/reports/upgrade-status"
  fi
else
  warn "upgrade_status not enabled: composer require --dev drupal/upgrade_status && drush en upgrade_status -y"
fi

summary
