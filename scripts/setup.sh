#!/usr/bin/env bash
# setup.sh — create your Executor File in one verified command.
#
# Usage:
#   scripts/setup.sh [--own] [-t THRESHOLD] [-n SHARES] [INPUT]
#
#   INPUT    plaintext register (default: estate.yaml)
#   --own    type your own passphrase (default: a strong one is
#            generated for you — recommended)
#   -t / -n  share scheme (default 2-of-3; 3-of-5 is the documented
#            alternative for larger families)
#
# What it does, in one process, with the passphrase held in memory
# only and never written to disk:
#   1. validates the register (baseline tier — always runs)
#   2. obtains the passphrase ONCE
#   3. encrypts to INPUT.age
#   4. splits that same passphrase into shares (ssss, 2-of-3)
#   5. PROVES the chain: reconstructs the passphrase from two of the
#      just-issued shares and test-decrypts the .age file back to a
#      byte-identical copy
#   6. reports success only if step 5 passed — a typo anywhere in the
#      chain aborts loudly instead of leaving you with shares that
#      open nothing
#
# The .age file stays decryptable by a stock interactive `age -d` —
# that is your executor's path, and nothing here changes it.
set -euo pipefail
umask 077

THRESHOLD=2
NSHARES=3
OWN=0
IN=""

usage() { sed -n '2,15p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --own) OWN=1 ;;
    -t) THRESHOLD="${2:?-t needs a value}"; shift ;;
    -n) NSHARES="${2:?-n needs a value}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) IN="$1" ;;
  esac
  shift
done
IN="${IN:-estate.yaml}"
OUT="${IN}.age"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── preflight ────────────────────────────────────────────────────────
missing=""
for tool in age ssss-split ssss-combine; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  echo "error: missing tool(s):$missing" >&2
  echo "  macOS:         brew install age ssss" >&2
  echo "  Debian/Ubuntu: sudo apt install age ssss" >&2
  exit 2
fi

# Non-interactive age mechanism: age-plugin-batchpass (ships with
# age >= 1.3.0; verified to emit a standard scrypt stanza that stock
# interactive `age -d` opens). Fallback: driving `age -p` with expect.
# EXECUTOR_FILE_MECH forces one mechanism (used by the test suite).
MECH="${EXECUTOR_FILE_MECH:-}"
if [ -z "$MECH" ]; then
  if command -v age-plugin-batchpass >/dev/null 2>&1; then
    MECH=batchpass
  elif command -v expect >/dev/null 2>&1; then
    MECH=expect
  else
    echo "error: need either age-plugin-batchpass (age >= 1.3.0) or 'expect'." >&2
    echo "  macOS:         brew upgrade age    (expect is preinstalled)" >&2
    echo "  Debian/Ubuntu: sudo apt install age expect" >&2
    exit 2
  fi
fi
case "$MECH" in batchpass|expect) ;; *)
  echo "error: EXECUTOR_FILE_MECH must be batchpass or expect." >&2; exit 2 ;;
esac

if [ ! -f "$IN" ]; then
  echo "error: register not found: $IN" >&2
  echo "hint: copy examples/estate.example.yaml to estate.yaml and edit it." >&2
  exit 2
fi
if [ "$THRESHOLD" -gt "$NSHARES" ]; then
  echo "error: threshold ($THRESHOLD) cannot exceed share count ($NSHARES)." >&2
  exit 2
fi
if [ -e "$OUT" ]; then
  printf '%s already exists. Overwrite it (and make any old shares useless)? [y/N] ' "$OUT"
  read -r reply
  case "$reply" in y|Y|yes|YES) ;; *) echo "Aborted."; exit 1 ;; esac
fi

# ── passphrase-mechanism helpers (passphrase via environment only) ──
encrypt_file() { # $1=plaintext $2=ciphertext; passphrase in $PASS
  if [ "$MECH" = batchpass ]; then
    AGE_PASSPHRASE="$PASS" age -e -j batchpass -o "$2" "$1"
  else
    PASS="$PASS" INFILE="$1" OUTFILE="$2" expect <<'EOF' >/dev/null
set timeout 120
spawn age -p -o $env(OUTFILE) $env(INFILE)
expect "Enter passphrase*"
send -- "$env(PASS)\r"
expect "Confirm passphrase*"
send -- "$env(PASS)\r"
expect eof
catch wait result
exit [lindex $result 3]
EOF
  fi
}
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

# ── step 1: validate (can never be skipped) ─────────────────────────
echo "Step 1/6 — validating $IN"
"$SCRIPT_DIR/validate.sh" "$IN" || {
  echo "error: validation failed — fix the register before sealing it." >&2
  exit 1
}
echo

# ── step 2: obtain the passphrase once ──────────────────────────────
gen_passphrase() {
  # 8 random dictionary words ≈ 120+ bits; fallback: 30 random chars.
  # Well inside ssss's 128-ASCII cap either way.
  dict=/usr/share/dict/words
  if [ -r "$dict" ]; then
    words="$(LC_ALL=C grep -E '^[a-z]{3,8}$' "$dict")"
    n="$(printf '%s\n' "$words" | wc -l | tr -d ' ')"
    out=""
    for _ in 1 2 3 4 5 6 7 8; do
      idx=$(( ($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % n) + 1 ))
      out="$out-$(printf '%s\n' "$words" | sed -n "${idx}p")"
    done
    printf '%s' "${out#-}"
  else
    LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 30 |
      sed 's/.\{5\}/&-/g; s/-$//'
  fi
}

echo "Step 2/6 — passphrase"
if [ "$OWN" -eq 1 ]; then
  printf 'Enter passphrase (hidden, max 128 ASCII characters): '
  read -rs PASS; echo
  printf 'Confirm passphrase: '
  read -rs PASS2; echo
  [ "$PASS" = "$PASS2" ] || { echo "error: passphrases do not match." >&2; exit 1; }
  unset PASS2
  [ -n "$PASS" ] || { echo "error: empty passphrase." >&2; exit 1; }
  if [ "${#PASS}" -gt 128 ]; then
    echo "error: passphrase is ${#PASS} characters — ssss can split at most 128." >&2
    exit 1
  fi
  case "$PASS" in
    *[![:ascii:]]*) echo "error: passphrase must be ASCII only (ssss limitation)." >&2; exit 1 ;;
  esac
else
  PASS="$(gen_passphrase)"
  echo "Generated a strong passphrase (you will save it to your password"
  echo "manager at the end — you never need to memorise it)."
fi
echo

# ── cleanup on any failure past this point ──────────────────────────
WORK="$(mktemp -d)"
chmod 700 "$WORK"
FINALISED=0
cleanup() {
  rm -rf "$WORK"
  if [ "$FINALISED" -ne 1 ]; then
    rm -f "$OUT"
    echo >&2
    echo "SETUP FAILED — nothing was finalised. The partial $OUT was removed;" >&2
    echo "your plaintext $IN is untouched. Nothing about this failure wrote" >&2
    echo "your passphrase to disk. Fix the error above and re-run." >&2
  fi
}
trap cleanup EXIT

# ── step 3: encrypt ─────────────────────────────────────────────────
echo "Step 3/6 — encrypting to $OUT (mechanism: $MECH)"
encrypt_file "$IN" "$OUT"
echo

# ── step 4: split the same in-memory passphrase ─────────────────────
echo "Step 4/6 — splitting the passphrase ${THRESHOLD}-of-${NSHARES}"
SHARES="$(printf '%s\n' "$PASS" | ssss-split -t "$THRESHOLD" -n "$NSHARES" -w estate -q)"
n_issued="$(printf '%s\n' "$SHARES" | wc -l | tr -d ' ')"
if [ "$n_issued" -ne "$NSHARES" ]; then
  echo "error: expected $NSHARES shares, got $n_issued." >&2
  exit 1
fi
echo

# ── step 5: prove the whole chain before reporting anything ─────────
echo "Step 5/6 — proving the chain: shares -> passphrase -> decrypt -> byte-compare"
S1="$(printf '%s\n' "$SHARES" | sed -n '1p')"
S2="$(printf '%s\n' "$SHARES" | sed -n '2p')"
RECOVERED="$(printf '%s\n%s\n' "$S1" "$S2" | ssss-combine -t "$THRESHOLD" 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
if [ "$RECOVERED" != "$PASS" ]; then
  echo "error: passphrase reconstructed from the shares does not match the" >&2
  echo "one used to encrypt. Nothing was finalised — re-run setup." >&2
  exit 1
fi
PASS="$RECOVERED"
decrypt_file "$OUT" "$WORK/check.yaml" || {
  echo "error: test-decrypt with the reconstructed passphrase failed." >&2
  exit 1
}
cmp -s "$IN" "$WORK/check.yaml" || {
  echo "error: decrypted copy is not byte-identical to $IN." >&2
  exit 1
}
echo "Chain verified: two of the issued shares reconstruct the passphrase,"
echo "and it decrypts $OUT back to a byte-identical register."
echo

# ── step 6: report ──────────────────────────────────────────────────
if command -v shasum >/dev/null 2>&1; then
  CHECKSUM="$(shasum -a 256 "$OUT" | cut -d' ' -f1)"
else
  CHECKSUM="$(sha256sum "$OUT" | cut -d' ' -f1)"
fi
FINALISED=1

echo "Step 6/6 — done. Your Executor File is sealed."
echo
echo "  Encrypted register:  $OUT"
echo "  SHA-256:             $CHECKSUM"
echo "     (write this on the printed Executor Instructions so your"
echo "      executor can confirm an uncorrupted copy)"
echo
echo "The $NSHARES shares — any $THRESHOLD open the file, fewer open nothing:"
echo
i=0
printf '%s\n' "$SHARES" | while IFS= read -r share; do
  i=$((i+1))
  echo "  Share $i:  $share"
done
echo
echo "Do these now, in order:"
echo "  1. Copy each share onto its own sheet of paper BY HAND (or print"
echo "     each separately). The 'estate-N-' prefix is part of the share."
echo "     Double-check every character (0-9, a-f)."
echo "  2. Give one share to each holder and tell them what it is. Never"
echo "     store two shares in the same place; never in a file, photo,"
echo "     email, or cloud note."
echo "  3. Fill in templates/EXECUTOR-INSTRUCTIONS.md (including the"
echo "     SHA-256 above), print it, store it with the will."
echo "  4. Store $OUT in at least two private places (USB sticks in"
echo "     separate locations, a private cloud copy). It is useless"
echo "     without two shares."
echo "  5. SAVE THE PASSPHRASE IN YOUR PASSWORD MANAGER now, as e.g."
echo "     'Executor File passphrase'. That is YOUR way back into the"
echo "     file at the next review; the shares are your executor's way."
if [ "$OWN" -eq 0 ]; then
  echo "     The passphrase is:"
  echo
  echo "       $PASS"
  echo
fi
echo "  6. About the plaintext $IN: deleting it reduces exposure but does"
echo "     NOT erase history — SSDs, synced folders, snapshots, and editor"
echo "     backups can retain copies. Work on a full-disk-encrypted"
echo "     machine, keep $IN out of synced folders, and prefer"
echo "     scripts/review.sh (which never leaves plaintext behind) for"
echo "     future edits. Then delete $IN and empty the trash."
echo
echo "  Then clear this terminal:  clear && history -c"
