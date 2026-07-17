#!/usr/bin/env bash
# setup.sh — create your Executor File in one verified command.
#
# Usage:
#   scripts/setup.sh [--own] [INPUT]
#
#   INPUT    plaintext register (default: estate.yaml)
#   --own    type your own passphrase (default: a strong one is
#            generated for you — recommended)
#
# The share scheme is FIXED at 2-of-3: three printed shares, any two
# reconstruct the passphrase, any one alone reveals nothing. It is
# fixed because this exact scheme is what the proof stage, the test
# suite, and the printed executor guide are built and verified
# around. If your family genuinely needs a different scheme, fork
# the repo, change THRESHOLD/NSHARES below, and re-verify the whole
# chain yourself — configurable cryptography is how shares that open
# nothing get issued.
#
# What it does, in one process, with the passphrase held in memory
# only and never written to disk:
#   1. validates the register (baseline tier — always runs)
#   2. obtains the passphrase ONCE
#   3. encrypts to INPUT.age (+ a .sha256 sidecar for comparing copies)
#   4. splits that same passphrase into three shares (ssss, 2-of-3)
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

usage() { sed -n '2,10p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --own) OWN=1 ;;
    -t|-n)
      echo "error: the share scheme is fixed at 2-of-3 — $1 was removed." >&2
      echo "A configurable scheme shipped a defect: the proof stage could" >&2
      echo "never verify anything but 2-of-3, so other schemes failed setup" >&2
      echo "every time. One deeply tested scheme beats configurable crypto." >&2
      echo "If you truly need a different scheme, fork the repo, edit" >&2
      echo "THRESHOLD/NSHARES in this script, and re-verify the whole chain." >&2
      exit 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) IN="$1" ;;
  esac
  shift
done
IN="${IN:-estate.yaml}"
OUT="${IN}.age"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Interactive terminal? Decides whether the share-display ceremony
# (one share at a time, screen cleared between) can run. Piped or
# redirected runs (tests, CI) get a plain printout instead.
IS_TTY=0
if [ -t 0 ] && [ -t 1 ]; then IS_TTY=1; fi

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
# Fallback word list for systems without /usr/share/dict/words:
# 256 short, common, distinct words. 12 words drawn from 256 give
# 12 x 8 = 96 bits — the honest figure, printed at generation time.
WORDS256="acid acorn agree alarm amber angle apple april arch arena
army aroma arrow atlas atom autumn award bacon badge baker
bamboo banjo barn basil basket beach bean bear beetle bell
belt bench berry bird bison blade blanket blast bloom blue
board boat bone book boot bottle brain brave bread brick
bridge broom brown brush bubble bucket bulb bull bundle cabin
cactus cake camel camp canal candle canoe canyon card cargo
carpet cart castle cat cave cedar cello chair chalk charm
chart cheese chef cherry chess chest chief child cider cinema
circle citrus city clam claw clay cliff clock cloud clover
coach coal coast cobra cocoa coin comet coral cord corn
cotton couch court cousin cove crab crane crater cream crest
crew cricket crown cube curtain curve cycle daisy dance dart
dawn deck deer delta desert desk dial diamond dice dime
dinner dish dock dog dolphin dome donkey door dove dragon
drum duck dune eagle earth east echo eel egg elbow
elder elk elm ember engine fabric falcon fall fang farm
feast feather fence fern ferry fiddle field fig finch fire
fish flag flame flash fleet flint float flock floor flour
flute foam fog forest fossil fox frame frost fruit galaxy
garden garlic gate gecko gem giant ginger glass globe glove
goat gold goose grain grape grass gravel green grove guitar
hammer harbor harp hawk hazel heron hill honey hoof horse
hotel house humor icicle igloo iron island ivory jacket jade
jaguar jelly jewel judge juice jungle kayak kettle king kite
kiwi koala ladder lagoon lake lantern"

rand_index() { # $1 = modulus; prints 1..modulus
  echo $(( ($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % $1) + 1 ))
}

gen_passphrase() {
  # Honest entropy: the real figure is computed from the real word
  # count and printed (to stderr — stdout carries the passphrase).
  # EXECUTOR_FILE_DICT overrides the dictionary path (tests use it).
  dict="${EXECUTOR_FILE_DICT:-/usr/share/dict/words}"
  if [ -r "$dict" ]; then
    words="$(LC_ALL=C grep -E '^[a-z]{3,8}$' "$dict")"
    n="$(printf '%s\n' "$words" | wc -l | tr -d ' ')"
    bits="$(awk -v n="$n" 'BEGIN { printf "%d", 8 * log(n) / log(2) }')"
    echo "Drawing 8 words from $n eligible dictionary words ≈ $bits bits of entropy." >&2
    out=""
    for _ in 1 2 3 4 5 6 7 8; do
      idx="$(rand_index "$n")"
      out="$out-$(printf '%s\n' "$words" | sed -n "${idx}p")"
    done
    printf '%s' "${out#-}"
  else
    echo "No system dictionary found — using the built-in 256-word list:" >&2
    echo "drawing 12 words from 256 = 96 bits of entropy." >&2
    out=""
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
      idx="$(rand_index 256)"
      # shellcheck disable=SC2086
      out="$out-$(printf '%s\n' $WORDS256 | sed -n "${idx}p")"
    done
    printf '%s' "${out#-}"
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
    rm -f "$OUT" "$OUT.sha256"
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
S3="$(printf '%s\n' "$SHARES" | sed -n '3p')"
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

# ── step 6: sidecar, ceremony, checklist ────────────────────────────
# The .sha256 sidecar exists to COMPARE STORED COPIES of the encrypted
# file (scripts/verify-copies.sh) — it is not needed for recovery.
# age is authenticated encryption: successful decryption already
# proves the file is intact. Nothing checksum-shaped belongs on the
# printed page, where it would rot at the next review.
if command -v shasum >/dev/null 2>&1; then
  (cd "$(dirname "$OUT")" && shasum -a 256 "$(basename "$OUT")") > "$OUT.sha256"
else
  (cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")") > "$OUT.sha256"
fi
FINALISED=1

echo "Step 6/6 — done. Your Executor File is sealed."
echo
echo "  Encrypted register:  $OUT"
echo "  Copy-check sidecar:  $OUT.sha256"
echo "     (keep it next to every stored copy of $OUT; scripts/verify-copies.sh"
echo "      uses it to confirm all your copies are identical)"
echo

show_share() { # $1 = share number, $2 = share value
  echo "  Share $1 of $NSHARES — copy it onto its own sheet of paper BY HAND:"
  echo
  echo "      $2"
  echo
  echo "  The 'estate-$1-' prefix is PART of the share. Double-check every"
  echo "  character (the long part uses only 0-9 and a-f)."
}

if [ "$IS_TTY" -eq 1 ]; then
  echo "The $NSHARES shares will now be shown ONE AT A TIME — any $THRESHOLD open the"
  echo "file, fewer open nothing. Before continuing:"
  echo
  echo "  • Make sure nobody can see your screen."
  echo "  • Stop any screen recording, screen sharing, or video call."
  echo "  • Have $NSHARES sheets of paper and a pen ready."
  echo
  printf 'Press Enter to show share 1 of %s... ' "$NSHARES"
  read -r _
  i=0
  for share in "$S1" "$S2" "$S3"; do
    i=$((i+1))
    printf '\033[2J\033[3J\033[H'
    show_share "$i" "$share"
    echo
    if [ "$i" -lt "$NSHARES" ]; then
      printf 'Press Enter once share %s is copied and checked — the screen clears, then share %s appears... ' "$i" "$((i+1))"
    else
      printf 'Press Enter once share %s is copied and checked — the screen clears... ' "$i"
    fi
    read -r _
  done
  printf '\033[2J\033[3J\033[H'
  if [ "$OWN" -eq 0 ]; then
    echo "Now the passphrase itself. Save it in your password manager as"
    echo "'Executor File passphrase' — it is YOUR way back in at review time;"
    echo "the shares are your executor's way."
    echo
    echo "      $PASS"
    echo
    printf 'Press Enter once it is saved in your password manager — the screen clears... '
    read -r _
    printf '\033[2J\033[3J\033[H'
  fi
else
  echo "The $NSHARES shares — any $THRESHOLD open the file, fewer open nothing:"
  echo
  i=0
  for share in "$S1" "$S2" "$S3"; do
    i=$((i+1))
    echo "  Share $i:  $share"
  done
  echo
  if [ "$OWN" -eq 0 ]; then
    echo "  SAVE THE PASSPHRASE IN YOUR PASSWORD MANAGER now, as e.g."
    echo "  'Executor File passphrase'. That is YOUR way back into the"
    echo "  file at the next review; the shares are your executor's way."
    echo "     The passphrase is:"
    echo
    echo "       $PASS"
    echo
  fi
fi

echo "Do these now, in order:"
echo "  1. Hand-copy done? Give one share to each holder and tell them"
echo "     what it is. Never store two shares in the same place; never"
echo "     in a file, photo, email, or cloud note."
echo "  2. Fill in and print templates/EXECUTOR-INSTRUCTIONS.md, and"
echo "     store it with the will."
echo "  3. Store $OUT (with its .sha256 sidecar) in at least two"
echo "     private places (USB sticks in separate locations, a private"
echo "     cloud copy). It is useless without two shares."
if [ "$OWN" -eq 1 ]; then
  echo "  4. SAVE YOUR PASSPHRASE IN YOUR PASSWORD MANAGER now, as e.g."
  echo "     'Executor File passphrase'. That is YOUR way back into the"
  echo "     file at the next review; the shares are your executor's way."
else
  echo "  4. Confirm the passphrase reached your password manager as"
  echo "     'Executor File passphrase' — without it, your next review"
  echo "     needs two of the shares you just handed out."
fi
echo "  5. About the plaintext $IN: deleting it reduces exposure but does"
echo "     NOT erase history — SSDs, synced folders, snapshots, and editor"
echo "     backups can retain copies. Work on a full-disk-encrypted"
echo "     machine, keep $IN out of synced folders, and prefer"
echo "     scripts/review.sh (which never leaves plaintext behind) for"
echo "     future edits. Then delete $IN and empty the trash."
echo
echo "When you are done: CLOSE THIS TERMINAL WINDOW ENTIRELY. Clearing"
echo "the screen does not erase scrollback, terminal logs, or your"
echo "shell's history file — closing the window discards this session's"
echo "scrollback, which is the part you can actually control."
