#!/usr/bin/env bash
# Read-only post-upgrade verification of a Drupal site (local, DDEV or Pantheon).
# Checks core major version, PHP, bootstrap, pending DB updates, config drift,
# status-report errors, recent log errors and cron.
#
# Usage: scripts/verify-upgrade.sh [--expect-major 11]
# Examples:
#   DRUSH="ddev drush" scripts/verify-upgrade.sh
#   DRUSH="terminus drush mysite.dev --" scripts/verify-upgrade.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

EXPECT_MAJOR=11
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect-major) EXPECT_MAJOR="${2:?missing value}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

resolve_drush
info "Drush: ${DRUSH_CMD[*]}"

# Treat empty output or an empty JSON array as "nothing pending".
is_empty() { local t; t="$(printf '%s' "$1" | tr -d '[:space:]')"; [[ -z "$t" || "$t" == "[]" || "$t" == "{}" ]]; }

section "Bootstrap"
bootstrap="$(drush_quiet status --field=bootstrap)"
if [[ "$bootstrap" == Successful* ]]; then pass "Drupal bootstrap: $bootstrap"
else fail "Drupal bootstrap: ${bootstrap:-failed}"; fi

version="$(drush_quiet status --field=drupal-version)"
if [[ "${version%%.*}" == "$EXPECT_MAJOR" ]]; then pass "Drupal $version"
else fail "Drupal ${version:-unknown}, expected major $EXPECT_MAJOR"; fi

php_v="$(drush_quiet status --field=php-version)"
if [[ -n "$php_v" ]] && version_ge "$php_v" 8.3; then pass "PHP $php_v"
else fail "PHP ${php_v:-unknown} (Drupal 11 needs 8.3+)"; fi

section "Database updates"
pending="$(drush_quiet updatedb:status --format=json)"
if is_empty "$pending"; then pass "No pending database updates"
else fail "Pending database updates; run 'drush updatedb -y'"; printf '%s\n' "$pending" | head -n 20; fi

section "Configuration"
if cfg="$(run_drush config:status --format=json 2>/dev/null | tr -d '\r')"; then
  if is_empty "$cfg"; then pass "Active configuration matches the sync directory"
  else
    n="$(printf '%s\n' "$cfg" | grep -c '"state"' || true)"
    warn "$n configuration items differ from the sync directory (review: drush config:status)"
    printf '%s\n' "$cfg" | awk -F'"' '/"name"/ { printf "       %s", $4 } /"state"/ { printf " (%s)\n", $4 }' | head -n 10
  fi
else
  warn "config:status failed (is config_sync_directory set?)"
fi

section "Status report"
errors="$(drush_quiet core:requirements --severity=2 --format=tsv --fields=title,value)"
if [[ -z "$errors" ]]; then pass "No status-report errors"
else fail "Status report errors:"; printf '%s\n' "$errors" | sed 's/^/       /'; fi
warnings="$(drush_quiet core:requirements --severity=1 --format=tsv --fields=title,severity | grep -ci warning || true)"
if [[ "${warnings:-0}" -gt 0 ]]; then warn "$warnings status-report warnings (drush core:requirements --severity=1)"; fi

section "Logs"
if logs="$(run_drush watchdog:show --severity=Error --count=10 --format=tsv --fields=date,type,message 2>/dev/null | tr -d '\r')"; then
  if [[ -z "$logs" ]]; then pass "No recent error-level log entries"
  else warn "Recent error-level log entries:"; printf '%s\n' "$logs" | sed 's/^/       /'; fi
else
  info "watchdog:show unavailable (dblog disabled?); check syslog or platform logs"
fi

section "Cron"
last="$(drush_quiet state:get system.cron_last)"
if [[ "$last" =~ ^[0-9]+$ ]]; then
  age=$(( $(date +%s) - last ))
  if [[ "$age" -lt 86400 ]]; then pass "Cron last ran $((age / 60)) minutes ago"
  else warn "Cron last ran $((age / 3600)) hours ago"; fi
else
  warn "Cron has no recorded run"
fi

summary
