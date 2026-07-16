#!/usr/bin/env bash
# validate.sh — lint a register against schema/estate.schema.yaml.
#
# Usage:
#   scripts/validate.sh [FILE]      (default: estate.yaml)
#
# Checks required fields, allowed type/action values, unique IDs — and
# rejects anything that looks like a full account number or a written-out
# credential, because this register must never contain secrets.
#
# Needs python3 with PyYAML (validator only — encryption does not).
# If your python3 lacks PyYAML, point PYTHON at one that has it:
#   PYTHON=.venv/bin/python3 scripts/validate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="${PYTHON:-python3}"

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "error: python3 not found (needed only for validation)." >&2
  echo "  macOS:         brew install python3" >&2
  echo "  Debian/Ubuntu: sudo apt install python3 python3-yaml" >&2
  exit 2
fi

exec "$PYTHON" "$SCRIPT_DIR/validate.py" "$@"
