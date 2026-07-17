#!/usr/bin/env bash
# test-recovery.sh — the fire drill: prove the PAPER works.
#
# Usage:
#   scripts/test-recovery.sh [FILE.age]     (default: estate.yaml.age)
#
# This simulates a real recovery using two of the physically held,
# printed shares — not values from your password manager, not a copy
# on disk. Go and get two actual share sheets first (yours plus one
# borrowed back from a holder, or two holders on a call reading
# theirs out). The drill proves:
#
#   printed paper -> ssss-combine -> passphrase -> age decrypt -> OK
#
# On success it appends a line to recovery-tests.log (date + who
# tested — no secrets), which make-guide.sh prints on the Executor
# Instructions as "Last successful recovery test" — the line that
# tells a future executor this process is known to work.
#
# Nothing is modified; the decrypted check-copy lives in a private
# temp folder and is removed. Run it once a year, and after every
# rotate. Exit codes: 0 = drill passed, 1 = failed, 2 = can't run.
set -euo pipefail
umask 077

IN="${1:-estate.yaml.age}"
case "$IN" in -h|--help) sed -n '2,22p' "$0"; exit 0 ;; esac

for tool in age ssss-combine; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: '$tool' is not installed." >&2
    echo "  macOS:         brew install age ssss" >&2
    echo "  Debian/Ubuntu: sudo apt install age ssss" >&2
    exit 2
  }
done
if [ ! -f "$IN" ]; then
  echo "error: encrypted register not found: $IN" >&2
  exit 2
fi

# Same mechanism logic as setup.sh (needed only to feed age the
# reconstructed passphrase non-interactively; the crypto is stock).
MECH="${EXECUTOR_FILE_MECH:-}"
if [ -z "$MECH" ]; then
  if command -v age-plugin-batchpass >/dev/null 2>&1; then MECH=batchpass
  elif command -v expect >/dev/null 2>&1; then MECH=expect
  else
    echo "error: need either age-plugin-batchpass (age >= 1.3.0) or 'expect'." >&2
    exit 2
  fi
fi
decrypt_file() { # $1=ciphertext $2=plaintext; passphrase in $PASS
  if [ "$MECH" = batchpass ]; then
    AGE_PASSPHRASE="$PASS" age -d -j batchpass -o "$2" "$1"
  else
    PASS="$PASS" INFILE="$1" OUTFILE="$2" expect <<'EOF' >/dev/null
set timeout 120
spawn age -d -o $env(OUTFILE) $env(INFILE)
expect "Enter passphrase*"
send -- "$env(PASS)\r"
expect eof
catch wait result
exit [lindex $result 3]
EOF
  fi
}

echo "FIRE DRILL — testing recovery of $IN from printed shares."
echo
echo "Fetch TWO physical share sheets now (not your password manager,"
echo "not a file). Any two of the three will do. This is exactly what"
echo "your executor will have to do — so do it the way they would."
echo
printf 'Who is running this test? (your name): '
read -r TESTED_BY
[ -n "$TESTED_BY" ] || { echo "error: a name is needed for the printed record." >&2; exit 2; }
echo
echo "Type the two shares exactly as printed, including the estate-N- prefix."
printf 'Share A: '
read -r SHARE_A
printf 'Share B: '
read -r SHARE_B
[ -n "$SHARE_A" ] && [ -n "$SHARE_B" ] || { echo "error: two shares are needed." >&2; exit 2; }
echo

PASS="$(printf '%s\n%s\n' "$SHARE_A" "$SHARE_B" | ssss-combine -t 2 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
if [ -z "$PASS" ]; then
  echo "DRILL FAILED at share reconstruction: ssss-combine produced no secret." >&2
  echo "A share was mistyped or the sheets are damaged. The long part uses" >&2
  echo "only 0-9 and a-f; the estate-N- prefix is part of the share." >&2
  echo "THIS IS THE FAILURE THE DRILL EXISTS TO CATCH — fix it now, while" >&2
  echo "you are alive: re-print the bad sheet (or rotate-shares.sh for a" >&2
  echo "fresh set), then run this drill again." >&2
  exit 1
fi

WORK="$(mktemp -d)"
chmod 700 "$WORK"
trap 'rm -rf "$WORK"' EXIT

if ! decrypt_file "$IN" "$WORK/check.yaml"; then
  echo "DRILL FAILED at decryption: the shares reconstructed a secret, but" >&2
  echo "it does not open $IN." >&2
  echo "Either a share was mistyped (ssss cannot tell — it just yields the" >&2
  echo "wrong answer) or these shares belong to an older passphrase than" >&2
  echo "this copy of the file. Re-type carefully; try a different pair; if" >&2
  echo "it still fails, treat the share set as broken and run" >&2
  echo "scripts/rotate-shares.sh, then drill again." >&2
  exit 1
fi

LINES="$(wc -l < "$WORK/check.yaml" | tr -d ' ')"
TODAY="$(date +%Y-%m-%d)"
LOG_DIR="$(dirname "$IN")"
printf '%s — %s\n' "$TODAY" "$TESTED_BY" >> "$LOG_DIR/recovery-tests.log"

echo "DRILL PASSED."
echo
echo "  Two printed shares reconstructed the passphrase, and it decrypted"
echo "  $IN ($LINES lines) successfully. The temp copy was removed."
echo
echo "  Recorded in recovery-tests.log:  $TODAY — $TESTED_BY"
echo
echo "Finish the drill:"
echo "  1. Update the printed Executor Instructions: re-run"
echo "     scripts/make-guide.sh and re-print, or hand-write"
echo "     \"$TODAY — $TESTED_BY\" on the 'Last successful recovery test' line."
echo "  2. Return any borrowed share sheet to its holder."
echo "  3. Book the next drill: about a year from now (review.sh's"
echo "     calendar file includes it)."