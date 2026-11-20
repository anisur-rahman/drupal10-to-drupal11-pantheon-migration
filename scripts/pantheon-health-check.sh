#!/usr/bin/env bash
set -euo pipefail
site="${1:?Usage: pantheon-health-check.sh SITE}"
env="${2:-dev}"
terminus site:info "$site"
terminus drush "$site.$env" -- status
terminus drush "$site.$env" -- updatedb:status
