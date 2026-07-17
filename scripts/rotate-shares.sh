#!/usr/bin/env bash
# rotate-shares.sh — new passphrase, fresh shares, old shares dead.
#
# Usage:
#   scripts/rotate-shares.sh [--own] [FILE.age]   (default: estate.yaml.age)
#
#   --own    type the new passphrase yourself (default: generated)
#
# When to rotate: a share holder dies or becomes estranged, a printed
# share is lost or might have been photographed, you suspect the
# passphrase leaked, or the executor changes. Rotation is the
# deliberate act review.sh is not: everything re-keys.
#
# What it does, with both passphrases held in memory only:
#   1. decrypts FILE.age with the CURRENT passphrase (from your
#      password manager)
#   2. generates a NEW passphrase, re-encrypts, splits it 2-of-3
#   3. PROVES the new chain (shares -> passphrase -> byte-identical
#      decrypt) before replacing anything
#   4. replaces FILE.age + its .sha256 sidecar atomically, then
#      PROVES the old passphrase no longer opens the new file
#
# The old shares open NOTHING after this — but only for copies you
# refresh. Every stored copy of the old file remains openable by the
# old shares until you overwrite it: refreshing copies IS the point.
set -euo pipefail
umask 077

THRESHOLD=2
NSHARES=3
OWN=0
IN=""

while [ $# -gt 0 ]; do
  case "$1" in
    --own) OWN=1 ;;
    -t|-n)
      echo "error: the share scheme is fixed at 2-of-3 — $1 was removed (see setup.sh)." >&2
      exit 2 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) IN="$1" ;;
  esac
  shift
done
IN="${IN:-estate.yaml.age}"

IS_TTY=0
if [ -t 0 ] && [ -t 1 ]; then IS_TTY=1; fi

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
if [ ! -f "$IN" ]; then
  echo "error: encrypted register not found: $IN" >&2
  exit 2
fi

MECH="${EXECUTOR_FILE_MECH:-}"
if [ -z "$MECH" ]; then
  if command -v age-plugin-batchpass >/dev/null 2>&1; then MECH=batchpass
  elif command -v expect >/dev/null 2>&1; then MECH=expect
  else
    echo "error: need either age-plugin-batchpass (age >= 1.3.0) or 'expect'." >&2
    exit 2
  fi
fi
case "$MECH" in batchpass|expect) ;; *)
  echo "error: EXECUTOR_FILE_MECH must be batchpass or expect." >&2; exit 2 ;;
esac

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

# Same generator as setup.sh: honest entropy, 256-word fallback.
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
rand_index() { echo $(( ($(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % $1) + 1 )); }
gen_passphrase() {
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

# ── step 1: decrypt with the current passphrase ─────────────────────
WORK="$(mktemp -d)"
chmod 700 "$WORK"
trap 'rm -rf "$WORK"' EXIT

echo "Step 1/4 — decrypting $IN with the CURRENT passphrase"
printf 'Current passphrase (hidden; it is in your password manager): '
read -rs OLD_PASS; echo
PASS="$OLD_PASS"
PLAIN="$WORK/estate.yaml"
if ! decrypt_file "$IN" "$PLAIN"; then
  echo "error: decryption failed — wrong passphrase, or a corrupted file." >&2
  echo "$IN was not modified." >&2
  exit 1
fi
echo

# ── step 2: new passphrase ──────────────────────────────────────────
echo "Step 2/4 — new passphrase"
if [ "$OWN" -eq 1 ]; then
  printf 'Enter NEW passphrase (hidden, max 128 ASCII characters): '
  read -rs NEW_PASS; echo
  printf 'Confirm NEW passphrase: '
  read -rs NEW2; echo
  [ "$NEW_PASS" = "$NEW2" ] || { echo "error: passphrases do not match." >&2; exit 1; }
  unset NEW2
  [ -n "$NEW_PASS" ] || { echo "error: empty passphrase." >&2; exit 1; }
  [ "${#NEW_PASS}" -le 128 ] || { echo "error: over 128 characters — ssss cannot split it." >&2; exit 1; }
  case "$NEW_PASS" in
    *[![:ascii:]]*) echo "error: passphrase must be ASCII only (ssss limitation)." >&2; exit 1 ;;
  esac
else
  NEW_PASS="$(gen_passphrase)"
  echo "Generated a strong new passphrase (save it to your password manager"
  echo "at the end, replacing the old one)."
fi
[ "$NEW_PASS" != "$OLD_PASS" ] || { echo "error: the new passphrase equals the old one — that is not a rotation." >&2; exit 1; }
echo

# ── step 3: re-encrypt, split, prove the new chain ──────────────────
echo "Step 3/4 — re-encrypting and proving the NEW chain (mechanism: $MECH)"
NEWOUT="$WORK/new.age"
PASS="$NEW_PASS"
encrypt_file "$PLAIN" "$NEWOUT"
SHARES="$(printf '%s\n' "$NEW_PASS" | ssss-split -t "$THRESHOLD" -n "$NSHARES" -w estate -q)"
n_issued="$(printf '%s\n' "$SHARES" | wc -l | tr -d ' ')"
[ "$n_issued" -eq "$NSHARES" ] || { echo "error: expected $NSHARES shares, got $n_issued." >&2; exit 1; }
S1="$(printf '%s\n' "$SHARES" | sed -n '1p')"
S2="$(printf '%s\n' "$SHARES" | sed -n '2p')"
S3="$(printf '%s\n' "$SHARES" | sed -n '3p')"
RECOVERED="$(printf '%s\n%s\n' "$S1" "$S2" | ssss-combine -t "$THRESHOLD" 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
[ "$RECOVERED" = "$NEW_PASS" ] || {
  echo "error: reconstructed passphrase does not match. Nothing was replaced." >&2
  exit 1
}
PASS="$RECOVERED"
decrypt_file "$NEWOUT" "$WORK/check.yaml" || { echo "error: test-decrypt failed. Nothing was replaced." >&2; exit 1; }
cmp -s "$PLAIN" "$WORK/check.yaml" || { echo "error: check copy not byte-identical. Nothing was replaced." >&2; exit 1; }
echo "New chain verified: two of the new shares reconstruct the new"
echo "passphrase, and it decrypts back to a byte-identical register."
echo

# ── step 4: replace, then prove the old passphrase is dead ──────────
echo "Step 4/4 — replacing $IN and confirming the old key is dead"
mv -f "$NEWOUT" "$IN"
if command -v shasum >/dev/null 2>&1; then
  (cd "$(dirname "$IN")" && shasum -a 256 "$(basename "$IN")") > "$IN.sha256"
else
  (cd "$(dirname "$IN")" && sha256sum "$(basename "$IN")") > "$IN.sha256"
fi
PASS="$OLD_PASS"
if decrypt_file "$IN" "$WORK/old-check.yaml" 2>/dev/null; then
  echo "error: the OLD passphrase still decrypts $IN — rotation did not take." >&2
  echo "Do not distribute the new shares; investigate before trusting this file." >&2
  exit 1
fi
unset OLD_PASS
echo "Confirmed: the old passphrase no longer opens $IN."
echo

show_share() {
  echo "  NEW share $1 of $NSHARES — copy it onto its own sheet of paper BY HAND:"
  echo
  echo "      $2"
  echo
  echo "  The 'estate-$1-' prefix is PART of the share. Double-check every"
  echo "  character (the long part uses only 0-9 and a-f)."
}

if [ "$IS_TTY" -eq 1 ]; then
  echo "The $NSHARES NEW shares will now be shown ONE AT A TIME. Before continuing:"
  echo "  • Make sure nobody can see your screen."
  echo "  • Stop any screen recording, screen sharing, or video call."
  echo "  • Have $NSHARES sheets of paper and a pen ready."
  echo
  printf 'Press Enter to show new share 1 of %s... ' "$NSHARES"
  read -r _
  i=0
  for share in "$S1" "$S2" "$S3"; do
    i=$((i+1))
    printf '\033[2J\033[3J\033[H'
    show_share "$i" "$share"
    echo
    printf 'Press Enter once share %s is copied and checked — the screen clears... ' "$i"
    read -r _
  done
  printf '\033[2J\033[3J\033[H'
  if [ "$OWN" -eq 0 ]; then
    echo "The new passphrase — REPLACE the old entry in your password manager now:"
    echo
    echo "      $NEW_PASS"
    echo
    printf 'Press Enter once it is saved — the screen clears... '
    read -r _
    printf '\033[2J\033[3J\033[H'
  fi
else
  echo "The $NSHARES NEW shares — any $THRESHOLD open the file, fewer open nothing:"
  echo
  i=0
  for share in "$S1" "$S2" "$S3"; do
    i=$((i+1))
    echo "  Share $i:  $share"
  done
  echo
  if [ "$OWN" -eq 0 ]; then
    echo "  REPLACE the passphrase in your password manager. The new one is:"
    echo
    echo "       $NEW_PASS"
    echo
  fi
fi

echo "Rotation complete. Now the physical part — none of it optional:"
echo "  1. COLLECT AND DESTROY every old printed share. Until destroyed,"
echo "     an old share plus an OLD COPY of the file still opens that copy."
echo "  2. Hand-copy and distribute the new shares (scripts/share-sheets.sh"
echo "     prints proper cover sheets). One holder per share, never two"
echo "     shares in one place."
echo "  3. REPLACE the passphrase entry in your password manager."
echo "  4. Overwrite EVERY stored copy of the file (USB sticks, private"
echo "     cloud) with the new $IN and its new .sha256 sidecar —"
echo "     old copies still open with old shares until overwritten."
echo "     (scripts/verify-copies.sh confirms they all match.)"
echo "  5. Re-run scripts/make-guide.sh and re-print the Executor"
echo "     Instructions if holders changed, then run"
echo "     scripts/test-recovery.sh with two of the NEW printed shares."
echo
echo "When done: CLOSE THIS TERMINAL WINDOW ENTIRELY — clearing the"
echo "screen does not erase scrollback or terminal logs."