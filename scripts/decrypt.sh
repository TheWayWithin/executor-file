#!/usr/bin/env bash
# decrypt.sh — decrypt your Executor File with age.
#
# Usage:
#   scripts/decrypt.sh [INPUT] [OUTPUT]
#
#   INPUT   encrypted register        (default: estate.yaml.age)
#   OUTPUT  where to write plaintext  (default: stdout — nothing
#           touches the disk unless you say so)
#
# You will be prompted for the passphrase (owners: it is in your
# password manager). An executor reconstructs it from any two shares
# with:  ssss-combine -t 2
#
# (Executors don't need this script — the printed Executor
# Instructions use the age command directly. This is a convenience
# for the owner; for editing, prefer scripts/review.sh, which never
# leaves plaintext behind.)
set -euo pipefail

IN="${1:-estate.yaml.age}"
OUT="${2:-}"

if ! command -v age >/dev/null 2>&1; then
  echo "error: 'age' is not installed." >&2
  echo "  macOS:         brew install age" >&2
  echo "  Debian/Ubuntu: sudo apt install age" >&2
  exit 1
fi

if [ ! -f "$IN" ]; then
  echo "error: encrypted file not found: $IN" >&2
  exit 1
fi

if [ -n "$OUT" ]; then
  age --decrypt -o "$OUT" "$IN"
  echo "Decrypted to: $OUT" >&2
  echo "Remember: this is plaintext. Delete it when you're done" >&2
  echo "(it is git-ignored, but the disk is your responsibility)." >&2
else
  age --decrypt "$IN"
fi
