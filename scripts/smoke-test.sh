#!/usr/bin/env bash
set -euo pipefail
url="${1:?Usage: smoke-test.sh https://example.org}"
code="$(curl -L -sS --max-time 30 -o /dev/null -w '%{http_code}' "$url")"
printf 'URL: %s | HTTP: %s
' "$url" "$code"
[[ "$code" == '200' ]] || exit 1
