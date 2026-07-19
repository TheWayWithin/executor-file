#!/bin/sh
# edit.sh — fill in your register as a browser form, then seal it, all on
# this machine. Opens a local, private editor in your web browser: no
# server on the network, no account, nothing sent anywhere. You fill in
# the form, click Save, then Seal, and it encrypts the file and splits the
# key, walking you through writing the shares down. Owner-side tooling
# (Python is fine here); your executor's recovery path never uses it.
#
# Usage:  scripts/edit.sh [FILE]        (default: estate.yaml)
set -u
DIR=$(cd "$(dirname "$0")/.." && pwd)
SERVER="$DIR/web/edit-server.py"
TARGET="${1:-estate.yaml}"

if command -v python3 >/dev/null 2>&1 && [ -f "$SERVER" ]; then
  echo "Opening the register editor in your browser."
  echo "  (it runs only on this machine; nothing you type is sent anywhere)"
  exec python3 "$SERVER" "$TARGET" --mode create --open
fi

# Fallback when python3 is unavailable: the static editor (download flow,
# and you seal separately with scripts/setup.sh).
PAGE="$DIR/web/editor.html"
[ -f "$PAGE" ] || { echo "error: editor not found at $PAGE" >&2; exit 1; }
echo "python3 was not found, so opening the basic editor."
echo "Fill it in and Save; then seal with:  scripts/setup.sh"
if command -v open >/dev/null 2>&1; then open "$PAGE"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$PAGE"
else echo "Open this file in your browser: $PAGE"; fi
