#!/usr/bin/env bash
# Read-only health check of a Pantheon environment: account, site and environment
# info, connection mode, recent workflows, backups, domains/HTTPS (live), Drupal
# verification (verify-upgrade.sh) and an HTTP smoke test (smoke-test.sh).
#
# Usage: scripts/pantheon-health-check.sh SITE [ENV]   (ENV defaults to dev)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in -h|--help|'') sed -n '2,6p' "$0"; [[ -n "${1:-}" ]]; exit $? ;; esac
SITE="$1"
ENV_NAME="${2:-dev}"
TARGET="$SITE.$ENV_NAME"

section "Terminus"
have terminus || die "terminus not found"
who="$(terminus auth:whoami 2>/dev/null || true)"
[[ -n "$who" ]] || die "terminus is not authenticated"
pass "Authenticated as $who"

section "Site and environment"
terminus site:info "$SITE" --fields=name,framework,upstream,organization 2>/dev/null || fail "site:info failed for $SITE"
terminus env:info "$TARGET" 2>/dev/null || fail "env:info failed for $TARGET"
mode="$(terminus env:info "$TARGET" --field=connection_mode 2>/dev/null || true)"
case "$mode" in
  git) pass "Connection mode: git" ;;
  sftp) warn "Connection mode: sftp (uncommitted changes may exist; commit or discard, then switch to git)" ;;
  *) info "Connection mode: ${mode:-unknown}" ;;
esac

section "Recent workflows"
terminus workflow:list "$SITE" 2>/dev/null | head -n 12 || warn "Could not list workflows"

section "Recent code"
terminus env:code-log "$TARGET" 2>/dev/null | head -n 8 || warn "Could not read code log"

section "Backups"
backups="$(terminus backup:list "$TARGET" 2>/dev/null || true)"
if [[ -n "$backups" ]]; then pass "Backups exist for $TARGET"; printf '%s\n' "$backups" | head -n 8
else warn "No backups listed for $TARGET (terminus backup:create $TARGET --element=all)"; fi

if [[ "$ENV_NAME" == "live" ]]; then
  section "Domains and HTTPS"
  terminus domain:list "$TARGET" 2>/dev/null || warn "Could not list domains"
  terminus https:info "$TARGET" 2>/dev/null || info "https:info unavailable"
fi

section "Drupal"
DRUSH="terminus drush $TARGET --" "$SCRIPT_DIR/verify-upgrade.sh" || FAIL_COUNT=$((FAIL_COUNT + 1))

section "HTTP"
url="$(terminus env:view "$TARGET" --print 2>/dev/null || true)"
if [[ -n "$url" ]]; then
  "$SCRIPT_DIR/smoke-test.sh" "${url%/}" || FAIL_COUNT=$((FAIL_COUNT + 1))
else
  warn "Could not determine environment URL"
fi

printf '\nOverall: %s\n' "$([[ "$FAIL_COUNT" -eq 0 ]] && echo HEALTHY || echo 'ATTENTION NEEDED')"
[[ "$FAIL_COUNT" -eq 0 ]]
