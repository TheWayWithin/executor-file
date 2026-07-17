#!/bin/sh
# verify-copies.sh — confirm every stored copy of your Executor File
# is the same, current file.
#
# Usage:
#   scripts/verify-copies.sh FILE.age [MORE-COPIES.age ...]
#
# Example (a USB stick and a private cloud copy against the local one):
#   scripts/verify-copies.sh estate.yaml.age \
#       /Volumes/BackupUSB/estate.yaml.age \
#       ~/PrivateCloud/estate.yaml.age
#
# What it checks:
#   • each copy against its .sha256 sidecar, when one sits next to it
#     (setup.sh and review.sh write the sidecar; copy it with the file)
#   • every copy byte-for-byte against the FIRST file you name
#
# What this is for: catching a stale or corrupted STORED COPY after a
# review — not recovery. Your executor never needs this script or the
# sidecar: age is authenticated encryption, so successful decryption
# already proves the file is intact.
#
# Exit codes: 0 = all copies identical, 1 = a mismatch, 2 = usage.
set -u

if [ $# -lt 1 ]; then
  sed -n '2,22p' "$0"
  exit 2
fi

if command -v shasum >/dev/null 2>&1; then
  hash_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  hash_of() { sha256sum "$1" | cut -d' ' -f1; }
fi

REF="$1"
PROBLEMS=0
CHECKED=0

if [ ! -f "$REF" ]; then
  echo "error: not found: $REF" >&2
  exit 2
fi
REF_HASH="$(hash_of "$REF")"

for copy in "$@"; do
  CHECKED=$((CHECKED + 1))
  if [ ! -f "$copy" ]; then
    echo "  MISSING  $copy — not found"
    PROBLEMS=$((PROBLEMS + 1))
    continue
  fi
  h="$(hash_of "$copy")"
  # Sidecar check, when a sidecar travels with this copy.
  if [ -f "$copy.sha256" ]; then
    want="$(cut -d' ' -f1 < "$copy.sha256")"
    if [ "$h" = "$want" ]; then
      side="sidecar ok"
    else
      side="SIDECAR MISMATCH"
    fi
  else
    side="no sidecar"
  fi
  # Cross-copy check against the first file named.
  if [ "$h" = "$REF_HASH" ]; then
    if [ "$side" = "SIDECAR MISMATCH" ]; then
      echo "  WARN     $copy — matches the reference file, but its own .sha256 sidecar is stale. Refresh the sidecar with the file next time you copy."
      PROBLEMS=$((PROBLEMS + 1))
    else
      echo "  ok       $copy ($side)"
    fi
  else
    echo "  DIFFERS  $copy — NOT the same file as $REF ($side)"
    PROBLEMS=$((PROBLEMS + 1))
  fi
done

echo
if [ "$PROBLEMS" -gt 0 ]; then
  echo "$PROBLEMS of $CHECKED cop(ies) need attention. A DIFFERS copy is"
  echo "stale (an old version from before a review) or corrupted — replace"
  echo "it with a fresh copy of the current file AND its .sha256 sidecar."
  exit 1
fi
echo "All $CHECKED cop(ies) are identical. Nothing to do."
exit 0
