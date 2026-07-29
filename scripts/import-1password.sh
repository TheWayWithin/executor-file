#!/usr/bin/env bash
# import-1password.sh — seed the register from your 1Password vault:
# titles, categories and web addresses only, never passwords (EF-ISS-8).
#
# Usage:
#   scripts/import-1password.sh [OPTIONS] > candidates.json
#
# Options:
#   --vaults-only     list your vaults and stop (for the editor's picker)
#   --vault NAME      only include items from this vault (repeatable)
#   --existing FILE   JSON {"assets":[{id, provider, access_pointer}]} of the
#                     register being edited, so items already listed are
#                     dropped from the result
#   --today DATE      override today's date (YYYY-MM-DD; tests)
#
# WHAT THIS READS: `op item list` returns item titles, categories, web
# addresses, vault names and timestamps — it does NOT return passwords,
# one-time codes, or any other concealed field, and this script never asks
# for one. It makes exactly two read-only calls (the vault list and the item
# list) and never fetches an individual item or asks 1Password to unmask
# anything; a CI test greps the whole repo to keep it that way. The
# 1Password CSV/1PUX export is deliberately NOT used: exporting writes your
# secrets to disk, which is exactly what this project exists to avoid.
#
# Nothing is written to disk: the pull is piped straight into the mapper and
# the candidate list goes to stdout. The browser editor holds it in the tab
# until you accept entries into the register.
#
# Needs: the 1Password CLI (`op`) signed in — 1Password 8+ desktop app with
# "Integrate with 1Password CLI" turned on, and a 1password.com account
# (standalone vaults are not reachable by the CLI). This is owner-side
# tooling; the executor recovery path gains no dependency from it.
#
# Exit codes: 0 = candidates written, 2 = usage, 3 = op not installed,
# 4 = op installed but no account / not signed in, 5 = the pull failed
# (approval denied, app locked, …), 6 = python3 missing.
set -u
set -o pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MAPPER="$HERE/map-1password.py"

VAULTS_ONLY=0
MAP_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
    --vaults-only) VAULTS_ONLY=1; shift ;;
    --vault)   [ $# -ge 2 ] || { echo "error: --vault needs a name" >&2; exit 2; }
               MAP_ARGS+=(--vault "$2"); shift 2 ;;
    --existing) [ $# -ge 2 ] || { echo "error: --existing needs a file" >&2; exit 2; }
               MAP_ARGS+=(--existing "$2"); shift 2 ;;
    --today)   [ $# -ge 2 ] || { echo "error: --today needs a date" >&2; exit 2; }
               MAP_ARGS+=(--today "$2"); shift 2 ;;
    *) echo "error: unknown option: $1" >&2; echo "try: $0 --help" >&2; exit 2 ;;
  esac
done

if ! command -v op >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: the 1Password command-line tool (op) is not installed.

  macOS:   brew install 1password-cli
  other:   https://developer.1password.com/docs/cli/get-started/

Then, in the 1Password 8 app: Settings > Developer > "Integrate with
1Password CLI". You can also skip this and type your accounts in by hand —
the importer only ever saves you typing.
EOF
  exit 3
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is needed to map the pull (owner-side tooling only)." >&2
  exit 6
fi
if [ ! -f "$MAPPER" ]; then
  echo "error: mapper not found at $MAPPER" >&2
  exit 6
fi

ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT

# Vault list first: it is small, it is what the picker needs, and it is the
# call that surfaces "not signed in" before we ask for anything else.
if ! VAULTS_JSON="$(op vault list --format=json 2>"$ERR")"; then
  MSG="$(cat "$ERR")"
  case "$MSG" in
    *"no account"*|*"not signed in"*)
      cat >&2 <<'EOF'
error: op is installed but no 1Password account is available to it.

  1. Open the 1Password 8 app and unlock it.
  2. Settings > Developer > tick "Integrate with 1Password CLI".
  3. Sign in to a 1password.com account (standalone vaults cannot be
     reached by the CLI).
EOF
      echo "op said: $MSG" >&2
      exit 4 ;;
    *)
      echo "error: 1Password refused the request." >&2
      echo "op said: $MSG" >&2
      echo "If an approval dialog appeared, approve it and run this again." >&2
      exit 5 ;;
  esac
fi

if [ "$VAULTS_ONLY" -eq 1 ]; then
  printf '[]' | python3 "$MAPPER" --vaults-json "$VAULTS_JSON" ${MAP_ARGS[@]+"${MAP_ARGS[@]}"}
  exit $?
fi

# The pull itself. Piped straight into the mapper and held in memory: the
# raw list never touches disk, and `additional_information` (username and
# email hints) is dropped there rather than carried into the candidate
# JSON. Held rather than streamed so a failed pull prints nothing at all on
# stdout — a half-written candidate list would look like a short vault.
if ! CANDIDATES="$(op item list --format=json 2>"$ERR" |
     python3 "$MAPPER" --vaults-json "$VAULTS_JSON" ${MAP_ARGS[@]+"${MAP_ARGS[@]}"})"; then
  MSG="$(cat "$ERR")"
  echo "error: could not read your item list." >&2
  [ -n "$MSG" ] && echo "op said: $MSG" >&2
  echo "If 1Password asked for approval, approve it and run this again." >&2
  exit 5
fi
printf '%s\n' "$CANDIDATES"
