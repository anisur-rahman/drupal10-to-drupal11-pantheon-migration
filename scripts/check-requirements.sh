#!/usr/bin/env bash
set -euo pipefail
for tool in git php composer docker ddev terminus; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'PASS %-12s %s
' "$tool" "$(command -v "$tool")"
  else
    printf 'MISSING %s
' "$tool"
  fi
done
