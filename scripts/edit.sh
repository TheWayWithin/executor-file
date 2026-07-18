#!/bin/sh
# edit.sh — open the friendly register editor in your web browser.
#
# Fill your register in as a form (dropdowns, plain-English help) instead
# of hand-editing YAML. It runs entirely in your browser on this machine:
# no server, no network, nothing sent anywhere. When you click Save it
# writes estate.yaml to your Downloads folder; then seal it once with
# scripts/setup.sh.
#
# Usage:  scripts/edit.sh
set -u
DIR=$(cd "$(dirname "$0")/.." && pwd)
PAGE="$DIR/web/editor.html"
[ -f "$PAGE" ] || { echo "error: editor not found at $PAGE" >&2; exit 1; }
echo "Opening the register editor in your browser…"
echo "  (it runs locally — nothing you type is sent anywhere)"
if command -v open >/dev/null 2>&1; then open "$PAGE"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$PAGE"
else echo "Open this file in your browser: $PAGE"; fi
