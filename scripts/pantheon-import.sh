#!/usr/bin/env bash
# Guarded import of an upgraded Drupal 11 database (and optionally files) into a
# Pantheon environment. DESTRUCTIVE: overwrites the target database/files.
#
# Usage: scripts/pantheon-import.sh SITE.ENV --db-url URL [--files-url URL] [options]
#   --db-url URL      short-lived HTTPS URL to a .sql.gz dump (never commit it)
#   --files-url URL   short-lived HTTPS URL to a .tar.gz of the files directory contents
#   --skip-backup     do not take a Pantheon backup first (not recommended)
#   --dry-run         print the plan only
#
# Importing into live additionally requires ALLOW_LIVE=yes in the environment.
# Signed URLs are redacted in all output.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

TARGET="${1:-}"
[[ "$TARGET" == -h || "$TARGET" == --help ]] && { sed -n '2,13p' "$0"; exit 0; }
[[ "$TARGET" == *.* ]] || die "First argument must be SITE.ENV (e.g. mysite.dev)"
shift
DB_URL=""; FILES_URL=""; SKIP_BACKUP=0; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-url) DB_URL="${2:?missing value}"; shift 2 ;;
    --files-url) FILES_URL="${2:?missing value}"; shift 2 ;;
    --skip-backup) SKIP_BACKUP=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "Unknown option: $1" ;;
  esac
done
[[ -n "$DB_URL" ]] || die "--db-url is required"
[[ "$DB_URL" == https://* ]] || die "--db-url must be HTTPS"
[[ -z "$FILES_URL" || "$FILES_URL" == https://* ]] || die "--files-url must be HTTPS"

ENV_NAME="${TARGET##*.}"
if [[ "$ENV_NAME" == "live" && "${ALLOW_LIVE:-}" != "yes" ]]; then
  die "Refusing to import into live without ALLOW_LIVE=yes (and an approved change record)"
fi

have terminus || die "terminus not found"
who="$(terminus auth:whoami 2>/dev/null || true)"
[[ -n "$who" ]] || die "terminus is not authenticated"

section "Plan"
info "Account:  $who"
info "Target:   $TARGET"
info "Backup:   $([[ "$SKIP_BACKUP" -eq 1 ]] && echo SKIPPED || echo 'terminus backup:create --element=all')"
info "Database: $(redact_url "$DB_URL")"
info "Files:    $([[ -n "$FILES_URL" ]] && redact_url "$FILES_URL" || echo 'not imported')"
info "After:    drush updatedb -y, drush cr, verify-upgrade.sh"
[[ "$DRY_RUN" -eq 1 ]] && { info "Dry run: nothing changed."; exit 0; }

printf '\nThis OVERWRITES data on %s. Type the target to continue: ' "$TARGET"
read -r answer
[[ "$answer" == "$TARGET" ]] || die "Confirmation did not match; aborted."

if [[ "$SKIP_BACKUP" -eq 0 ]]; then
  section "Backup"
  terminus backup:create "$TARGET" --element=all --keep-for=30
  pass "Backup created (terminus backup:list $TARGET)"
fi

section "Import database"
terminus import:database "$TARGET" "$DB_URL" --yes
pass "Database import workflow finished"

if [[ -n "$FILES_URL" ]]; then
  section "Import files"
  terminus import:files "$TARGET" "$FILES_URL" --yes
  pass "Files import workflow finished"
fi

section "Post-import"
terminus drush "$TARGET" -- updatedb -y
terminus drush "$TARGET" -- cache:rebuild
DRUSH="terminus drush $TARGET --" "$SCRIPT_DIR/verify-upgrade.sh"
