#!/usr/bin/env bash
set -euo pipefail
# Read this script before running; must be executed from authorized source project root.
[[ -x vendor/bin/drush ]] || { echo 'Missing vendor/bin/drush' >&2; exit 1; }
output="${1:?Usage: backup-drupal.sh /secure/backup/dir}"
mkdir -p "$output"
vendor/bin/drush sql:dump --gzip --result-file="$output/source.sql.gz"
if [[ -d web/sites/default/files ]]; then
  tar -czf "$output/public-files.tar.gz" -C web/sites/default/files .
fi
printf 'Backups created; verify restore and back up private files separately.
'
