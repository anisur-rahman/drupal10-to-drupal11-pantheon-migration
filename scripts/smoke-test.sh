#!/usr/bin/env bash
# HTTP smoke test for a Drupal site: status codes, response time, Drupal/PHP
# error text in responses, a 404 check and HTTP -> HTTPS redirect.
#
# Usage: scripts/smoke-test.sh BASE_URL [PATHS_FILE]
#   PATHS_FILE lines: <path> <expected_status> [text that must appear]
#   (see examples/smoke-paths.example; '#' starts a comment)
#
# Environment:
#   SMOKE_TIMEOUT  seconds per request (default 30)
#   SMOKE_SLOW     warn when slower than this many seconds (default 3)
#   SMOKE_AUTH     user:password for environments locked with HTTP basic auth
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in -h|--help|'') sed -n '2,12p' "$0"; [[ -n "${1:-}" ]]; exit $? ;; esac
BASE="${1%/}"
PATHS_FILE="${2:-}"
[[ "$BASE" == http://* || "$BASE" == https://* ]] || die "BASE_URL must start with http:// or https://"
have curl || die "curl not found"

TIMEOUT="${SMOKE_TIMEOUT:-30}"
SLOW="${SMOKE_SLOW:-3}"
CURL=(curl -sS --max-time "$TIMEOUT" -A "drupal-migration-smoke-test/1.0")
[[ -n "${SMOKE_AUTH:-}" ]] && CURL+=(-u "$SMOKE_AUTH")

ERROR_PATTERN='The website encountered an unexpected error|PDOException|Fatal error|Uncaught .*Exception|Allowed memory size'
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

check() {
  local path="$1" expected="$2" needle="${3:-}" result code t
  result="$("${CURL[@]}" -L -o "$BODY" -w '%{http_code} %{time_total}' "$BASE$path" 2>&1)" || {
    fail "$path -> request failed: $result"; return; }
  code="${result%% *}"; t="${result##* }"
  if [[ "$code" != "$expected" ]]; then
    fail "$path -> HTTP $code (expected $expected, ${t}s)"
  elif grep -Eq "$ERROR_PATTERN" "$BODY"; then
    fail "$path -> HTTP $code but the page contains PHP/Drupal error text"
  elif [[ -n "$needle" ]] && ! grep -Fq "$needle" "$BODY"; then
    fail "$path -> HTTP $code but missing expected text: $needle"
  elif awk -v t="$t" -v s="$SLOW" 'BEGIN { exit !(t > s) }'; then
    warn "$path -> HTTP $code, slow (${t}s > ${SLOW}s)"
  else
    pass "$path -> HTTP $code (${t}s)"
  fi
}

section "Smoke test: $BASE"
if [[ -n "$PATHS_FILE" ]]; then
  [[ -f "$PATHS_FILE" ]] || die "Paths file not found: $PATHS_FILE"
  while read -r path expected needle; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    check "$path" "$expected" "$needle"
  done < "$PATHS_FILE"
else
  check / 200
  check /user/login 200 'user-login-form'
  check /robots.txt 200
fi
check "/smoke-test-missing-$RANDOM$RANDOM" 404

if [[ "$BASE" == https://* ]]; then
  section "HTTPS redirect"
  http_url="http://${BASE#https://}/"
  result="$("${CURL[@]}" -o /dev/null -w '%{http_code} %{redirect_url}' "$http_url" 2>/dev/null || true)"
  code="${result%% *}"; target="${result#* }"
  case "$code" in
    301|302|307|308)
      if [[ "$target" == https://* ]]; then pass "HTTP redirects to HTTPS ($code)"
      else warn "HTTP redirects ($code) but not to HTTPS: $target"; fi ;;
    *) warn "HTTP request returned ${code:-no response}; HTTPS is not enforced" ;;
  esac
fi

summary
