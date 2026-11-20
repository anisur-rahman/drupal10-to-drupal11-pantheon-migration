#!/usr/bin/env bash
# Check workstation prerequisites for the Drupal 10 -> 11 / Pantheon migration lab.
# Read-only: installs nothing and changes nothing.
#
# Usage: scripts/check-requirements.sh [--local-only]
#   --local-only   skip Terminus and Pantheon SSH checks
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

LOCAL_ONLY=0
case "${1:-}" in
  --local-only) LOCAL_ONLY=1 ;;
  -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
  '') ;;
  *) die "Unknown option: $1" ;;
esac

MIN_PHP=8.3        # Drupal 11 minimum
MIN_COMPOSER=2.7   # Drupal 11 minimum
MIN_TERMINUS=3.0

section "Core tools"
for tool in git curl; do
  if have "$tool"; then pass "$tool $(extract_version "$("$tool" --version 2>&1 | head -n1)")"
  else fail "$tool not found"; fi
done
if have jq; then pass "jq $(extract_version "$(jq --version)")"
else warn "jq not found (optional; useful for parsing composer.json)"; fi

section "Containers and DDEV"
if have docker; then
  if docker info >/dev/null 2>&1; then pass "Docker daemon is running"
  else fail "Docker is installed but the daemon is not reachable (start Docker Desktop, OrbStack or Colima)"; fi
else
  fail "docker not found"
fi
if have ddev; then pass "ddev $(extract_version "$(ddev --version)")"
else fail "ddev not found (brew install ddev/ddev/ddev)"; fi

section "Host PHP and Composer (optional when using ddev composer / ddev drush)"
if have php; then
  php_v="$(php -r 'echo PHP_VERSION;')"
  if version_ge "$php_v" "$MIN_PHP"; then pass "php $php_v"
  else warn "php $php_v is below $MIN_PHP; use DDEV's PHP for Drupal 11 work"; fi
else
  warn "php not on host; DDEV container PHP will be used"
fi
if have composer; then
  c_v="$(extract_version "$(composer --version 2>/dev/null)")"
  if version_ge "$c_v" "$MIN_COMPOSER"; then pass "composer $c_v"
  else warn "composer $c_v is below $MIN_COMPOSER (run: composer self-update)"; fi
else
  warn "composer not on host; use 'ddev composer'"
fi

if [[ "$LOCAL_ONLY" -eq 0 ]]; then
  section "Pantheon"
  if have terminus; then
    t_v="$(extract_version "$(terminus --version 2>/dev/null)")"
    if version_ge "$t_v" "$MIN_TERMINUS"; then pass "terminus $t_v"
    else fail "terminus $t_v is below $MIN_TERMINUS"; fi
    who="$(terminus auth:whoami 2>/dev/null || true)"
    if [[ -n "$who" ]]; then pass "terminus authenticated as $who"
    else warn "terminus is not authenticated (run: terminus auth:login --machine-token=...)"; fi
  else
    fail "terminus not found (see https://docs.pantheon.io/terminus/install)"
  fi
  if ls "$HOME"/.ssh/id_*.pub >/dev/null 2>&1; then
    pass "SSH public key present (confirm it is added in the Pantheon dashboard)"
  else
    warn "No SSH public key in ~/.ssh; Pantheon Git and Drush over SSH need one"
  fi
fi

section "Current directory"
if [[ -f composer.json ]]; then
  pass "composer.json found in $(pwd)"
  if [[ -f composer.lock ]]; then
    core="$(grep -A3 '"name": "drupal/core"' composer.lock | grep -Eo '"version": "[^"]+"' | head -n1 | cut -d'"' -f4 || true)"
    if [[ -n "$core" ]]; then info "drupal/core in composer.lock: $core"; fi
  else
    warn "composer.lock missing; installs will not be reproducible"
  fi
else
  info "Not a Composer project root (fine if you are only checking tools)"
fi

summary
