# shellcheck shell=bash disable=SC2034
# Shared helpers for the migration scripts. Source this file; do not execute it.
# SC2034 disabled: variables here are used by the scripts that source this file.
# Compatible with bash 3.2 (macOS default) and later.

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
  C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''; C_RESET=''
fi

pass()    { PASS_COUNT=$((PASS_COUNT + 1)); printf '%sPASS%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { WARN_COUNT=$((WARN_COUNT + 1)); printf '%sWARN%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail()    { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '%sFAIL%s %s\n' "$C_RED" "$C_RESET" "$*"; }
info()    { printf '     %s\n' "$*"; }
section() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_RESET"; }
die()     { printf '%sERROR%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Print totals; returns non-zero when any check failed.
summary() {
  printf '\n%sSummary:%s %d passed, %d warnings, %d failed\n' \
    "$C_BOLD" "$C_RESET" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
  [[ "$FAIL_COUNT" -eq 0 ]]
}

# version_ge ACTUAL MINIMUM -> success when ACTUAL >= MINIMUM (numeric dotted compare).
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, "."); k = (n > m ? n : m)
    for (i = 1; i <= k; i++) { xi = x[i] + 0; yi = y[i] + 0
      if (xi > yi) exit 0; if (xi < yi) exit 1 }
    exit 0 }'
}

# Extract the first dotted version number from a string ("ddev version v1.24.1" -> 1.24.1).
# Never fails, so it is safe under set -e / pipefail.
extract_version() {
  printf '%s\n' "$1" | awk 'match($0, /[0-9]+(\.[0-9]+)+/) { print substr($0, RSTART, RLENGTH); exit }'
}

# Print the last non-empty line of stdin (drush sql:query ends with a blank line).
last_line() { awk 'NF { l = $0 } END { print l }'; }

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve how to call Drush into the DRUSH_CMD array.
# Override with DRUSH, e.g. DRUSH="ddev drush" or DRUSH="terminus drush mysite.dev --".
resolve_drush() {
  if [[ -n "${DRUSH:-}" ]]; then
    read -r -a DRUSH_CMD <<< "$DRUSH"
  elif [[ -x vendor/bin/drush ]]; then
    DRUSH_CMD=(vendor/bin/drush)
  elif [[ -d .ddev ]] && have ddev; then
    DRUSH_CMD=(ddev drush)
  else
    die "Cannot find Drush. Run from a Drupal project root or set DRUSH (e.g. DRUSH='ddev drush')."
  fi
}

run_drush() { "${DRUSH_CMD[@]}" "$@"; }

# Drush output with stderr dropped and carriage returns removed; never fails the script.
drush_quiet() { run_drush "$@" 2>/dev/null | tr -d '\r' || true; }

# Same idea for Composer: COMPOSER_CMD="ddev composer" or plain composer.
resolve_composer() {
  if [[ -n "${COMPOSER_CMD:-}" ]]; then
    read -r -a COMPOSER_RUN <<< "$COMPOSER_CMD"
  elif [[ -d .ddev ]] && have ddev; then
    COMPOSER_RUN=(ddev composer)
  elif have composer; then
    COMPOSER_RUN=(composer)
  else
    COMPOSER_RUN=()
  fi
}

sha256_file() {
  if have sha256sum; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

# Strip query strings so signed URLs (which carry credentials) are never printed.
redact_url() { printf '%s' "${1%%\?*}"; }

# Drupal core modules deprecated in 10.x and removed from core in Drupal 11.
# Format: machine_name:replacement
D11_REMOVED_MODULES="action:drupal/action book:drupal/book forum:drupal/forum statistics:drupal/statistics tour:drupal/tour tracker:drupal/tracker help_topics:merged-into-core-help"
