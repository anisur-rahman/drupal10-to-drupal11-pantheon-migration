#!/usr/bin/env bash
set -euo pipefail
if [[ -x vendor/bin/drush ]]; then
  vendor/bin/drush status
  vendor/bin/drush updatedb:status
else
  echo 'Run from a Composer-managed Drupal project with vendor/bin/drush' >&2
  exit 1
fi
