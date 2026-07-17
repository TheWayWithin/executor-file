#!/usr/bin/env bash
# split-secret.sh — split your Executor File passphrase into Shamir
# shares (fixed 2-of-3). Prefer scripts/setup.sh, which encrypts,
# splits, and PROVES the chain in one command; this is the manual
# building block.
#
# Usage:
#   scripts/split-secret.sh [-w TOKEN]
#
# The scheme is fixed at 2-of-3 (any 2 of 3 shares reconstruct the
# passphrase; any single share reveals nothing) — the same scheme the
# proof stage, the tests, and the printed executor guide are verified
# around. To use a different scheme, fork the repo and re-verify the
# chain yourself.
#
# You will be prompted for the secret (the passphrase you gave age).
# Typing is hidden. Maximum length: 128 ASCII characters.
#
# Reconstruction later needs no repo and no script:  ssss-combine -t 2
set -euo pipefail

THRESHOLD=2
SHARES=3
TOKEN=estate

while getopts "w:h" opt; do
  case "$opt" in
    w) TOKEN="$OPTARG" ;;
    h) sed -n '2,19p' "$0"; exit 0 ;;
    *)
      echo "error: the share scheme is fixed at 2-of-3 — -t/-n were removed." >&2
      echo "usage: $0 [-w token]" >&2
      exit 2 ;;
  esac
done

if ! command -v ssss-split >/dev/null 2>&1; then
  echo "error: 'ssss-split' is not installed." >&2
  echo "  macOS:         brew install ssss" >&2
  echo "  Debian/Ubuntu: sudo apt install ssss" >&2
  exit 1
fi

echo "Splitting into $SHARES shares; any $THRESHOLD reconstruct the passphrase."
echo "Each share prints on its own line, prefixed '${TOKEN}-N-'."
echo

ssss-split -t "$THRESHOLD" -n "$SHARES" -w "$TOKEN"

echo
echo "Handle the shares like keys, because they are:"
echo "  • Copy each share onto its own sheet of paper BY HAND or print"
echo "    each one separately. The 'N-' prefix is part of the share —"
echo "    keep it. Double-check every character (0-9, a-f)."
echo "  • Give one share to each holder (e.g. executor, solicitor,"
echo "    family member) and tell them what it is and what it's for."
echo "  • Never store two shares in the same place, and never store"
echo "    any share in a file, photo, email, or cloud note."
echo "  • When done, CLOSE THIS TERMINAL WINDOW ENTIRELY — clearing the"
echo "    screen does not erase scrollback or terminal logs."
