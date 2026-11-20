#!/usr/bin/env bash
# Capture or compare content counts so source and target sites can be reconciled
# (nodes by type, users, files, terms, media, comments, aliases, redirects,
# webform submissions and the highest IDs, which reveal writes after a freeze).
# Read-only. MySQL/MariaDB only; assumes no table prefix.
#
# Usage:
#   DRUSH="ddev drush" scripts/reconcile-counts.sh > counts-source.tsv
#   DRUSH="terminus drush mysite.live --" scripts/reconcile-counts.sh > counts-target.tsv
#   scripts/reconcile-counts.sh --compare counts-source.tsv counts-target.tsv
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

compare() {
  [[ -f "$1" && -f "$2" ]] || die "Both files must exist"
  awk -F'\t' '
    NR == FNR { a[$1] = $2; next }
    { b[$1] = $2 }
    END {
      diffs = 0
      for (k in a) { if (!(k in b)) { printf "ONLY-IN-A  %-40s %s\n", k, a[k]; diffs++ }
                     else if (a[k] != b[k]) { printf "DIFFERENT  %-40s %s -> %s\n", k, a[k], b[k]; diffs++ } }
      for (k in b) if (!(k in a)) { printf "ONLY-IN-B  %-40s %s\n", k, b[k]; diffs++ }
      if (diffs == 0) print "MATCH      all metrics identical"
      exit (diffs > 0)
    }' "$1" "$2" | sort
}

if [[ "${1:-}" == "--compare" ]]; then
  compare "${2:?first file}" "${3:?second file}"
  exit $?
fi
case "${1:-}" in -h|--help) sed -n '2,11p' "$0"; exit 0 ;; esac

resolve_drush

q() { drush_quiet sql:query "$1"; }
has_table() { [[ -n "$(q "SHOW TABLES LIKE '$1'")" ]]; }

# One "metric<TAB>value" line per scalar query.
scalar() { printf '%s\t%s\n' "$1" "$(q "$2" | last_line)"; }

# Grouped query returning "key<TAB>count" rows, prefixed with a metric name.
grouped() { q "$2" | awk -F'\t' -v p="$1" 'NF >= 2 { printf "%s:%s\t%s\n", p, $1, $2 }'; }

{
  if has_table node_field_data; then
    grouped node "SELECT type, COUNT(*) FROM node_field_data WHERE default_langcode = 1 GROUP BY type ORDER BY type"
    scalar node:published "SELECT COUNT(*) FROM node_field_data WHERE status = 1 AND default_langcode = 1"
    scalar node:max_nid "SELECT COALESCE(MAX(nid), 0) FROM node"
  fi
  scalar user:total "SELECT COUNT(*) FROM users_field_data WHERE uid > 0"
  scalar user:active "SELECT COUNT(*) FROM users_field_data WHERE uid > 0 AND status = 1"
  scalar user:max_uid "SELECT COALESCE(MAX(uid), 0) FROM users"
  if has_table file_managed; then
    scalar file:total "SELECT COUNT(*) FROM file_managed"
    scalar file:private "SELECT COUNT(*) FROM file_managed WHERE uri LIKE 'private://%'"
    scalar file:max_fid "SELECT COALESCE(MAX(fid), 0) FROM file_managed"
  fi
  has_table taxonomy_term_field_data && grouped term "SELECT vid, COUNT(*) FROM taxonomy_term_field_data WHERE default_langcode = 1 GROUP BY vid ORDER BY vid"
  has_table media_field_data && grouped media "SELECT bundle, COUNT(*) FROM media_field_data WHERE default_langcode = 1 GROUP BY bundle ORDER BY bundle"
  has_table comment_field_data && scalar comment:total "SELECT COUNT(*) FROM comment_field_data WHERE default_langcode = 1"
  has_table path_alias && scalar path_alias:total "SELECT COUNT(*) FROM path_alias"
  has_table redirect && scalar redirect:total "SELECT COUNT(*) FROM redirect"
  has_table menu_link_content_data && scalar menu_link:total "SELECT COUNT(*) FROM menu_link_content_data"
  if has_table webform_submission; then
    grouped webform "SELECT webform_id, COUNT(*) FROM webform_submission GROUP BY webform_id ORDER BY webform_id"
    scalar webform:max_sid "SELECT COALESCE(MAX(sid), 0) FROM webform_submission"
  fi
} | sort
