#!/usr/bin/env bash
# review.sh — the annual review of your Executor File, in one command.
#
# Usage:
#   scripts/review.sh [FILE.age]      (default: estate.yaml.age)
#
# Flow: asks for your passphrase (it is in your password manager as
# "Executor File passphrase") → decrypts into a private temp folder →
# opens your editor → validates (looping back into the editor on
# errors) → bumps meta.updated → re-encrypts with the SAME passphrase,
# so the shares your holders already have STAY VALID → verifies the
# result byte-for-byte → removes the working plaintext.
#
# Your plaintext never touches the repo folder or any synced folder.
# To change the passphrase itself (holder lost/estranged/compromised),
# use rotate-shares, not review — new shares must then be redistributed.
set -euo pipefail
umask 077

IN="${1:-estate.yaml.age}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

command -v age >/dev/null 2>&1 || {
  echo "error: 'age' is not installed." >&2
  echo "  macOS:         brew install age" >&2
  echo "  Debian/Ubuntu: sudo apt install age" >&2
  exit 2
}

# Same mechanism logic as setup.sh: batchpass preferred, expect fallback.
MECH="${EXECUTOR_FILE_MECH:-}"
if [ -z "$MECH" ]; then
  if command -v age-plugin-batchpass >/dev/null 2>&1; then
    MECH=batchpass
  elif command -v expect >/dev/null 2>&1; then
    MECH=expect
  else
    echo "error: need either age-plugin-batchpass (age >= 1.3.0) or 'expect'." >&2
    exit 2
  fi
fi

if [ ! -f "$IN" ]; then
  echo "error: encrypted register not found: $IN" >&2
  echo "hint: if you have not created your Executor File yet, run scripts/setup.sh" >&2
  exit 2
fi

encrypt_file() {
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
decrypt_file() {
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

# ── private working dir, never in a synced folder ───────────────────
WORK="$(mktemp -d)"
chmod 700 "$WORK"
RESOLVED="$(cd "$WORK" && pwd -P)"
case "$RESOLVED" in
  *Dropbox*|*"Mobile Documents"*|*iCloud*|*"Google Drive"*|*GoogleDrive*|*OneDrive*|*Syncthing*)
    rm -rf "$WORK"
    echo "error: your temp directory resolves inside a synced folder:" >&2
    echo "  $RESOLVED" >&2
    echo "Editing plaintext there would upload it. Point TMPDIR somewhere" >&2
    echo "local (e.g. TMPDIR=/tmp scripts/review.sh) and re-run." >&2
    exit 2
    ;;
esac
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ── decrypt ─────────────────────────────────────────────────────────
printf 'Passphrase for %s (hidden; it is in your password manager): ' "$IN"
read -rs PASS; echo
PLAIN="$WORK/estate.yaml"
if ! decrypt_file "$IN" "$PLAIN"; then
  echo "error: decryption failed — wrong passphrase, or a corrupted file." >&2
  echo "$IN was not modified." >&2
  exit 1
fi
echo "Decrypted into a private temp folder (mode 700, auto-removed)."
echo

# ── edit + validate loop ────────────────────────────────────────────
EDITOR_CMD="${EDITOR:-vi}"
while :; do
  "$EDITOR_CMD" "$PLAIN"
  if "$SCRIPT_DIR/validate.sh" "$PLAIN"; then
    break
  fi
  echo
  printf 'Validation failed. Press Enter to reopen the editor and fix it (Ctrl-C aborts; %s stays untouched): ' "$IN"
  read -r _
done
echo

# ── bump meta.updated ───────────────────────────────────────────────
TODAY="$(date +%Y-%m-%d)"
tmp_sed="$WORK/estate.updated.yaml"
sed -E "s/^(  updated:[[:space:]]*).*/\1${TODAY}/" "$PLAIN" > "$tmp_sed"
mv "$tmp_sed" "$PLAIN"
echo "meta.updated set to ${TODAY}."

# ── re-encrypt with the SAME passphrase, verify, then replace ───────
NEWOUT="$WORK/register.age"
encrypt_file "$PLAIN" "$NEWOUT"
CHECK="$WORK/check.yaml"
decrypt_file "$NEWOUT" "$CHECK"
cmp -s "$PLAIN" "$CHECK" || {
  echo "error: verification failed — the re-encrypted file did not decrypt" >&2
  echo "back to your edited register. $IN was NOT replaced." >&2
  exit 1
}
mv -f "$NEWOUT" "$IN"

if command -v shasum >/dev/null 2>&1; then
  CHECKSUM="$(shasum -a 256 "$IN" | cut -d' ' -f1)"
else
  CHECKSUM="$(sha256sum "$IN" | cut -d' ' -f1)"
fi

echo
echo "Review complete. $IN re-encrypted with the same passphrase —"
echo "the shares your holders hold are still valid."
echo
echo "  New SHA-256:  $CHECKSUM"
echo
echo "Remaining hand-work:"
echo "  • The printed Executor Instructions carry the file's SHA-256 —"
echo "    update it there (the content changed, so the checksum did)."
echo "  • Refresh every stored copy of $IN (USB sticks, private cloud)"
echo "    with this new version."
echo "  • If you confirmed individual entries are still accurate, set"
echo "    their last_confirmed to ${TODAY} next time you edit."
echo
echo "The working plaintext was removed with its temp folder. Deleting"
echo "plaintext reduces exposure; it does not erase history — which is"
echo "why review.sh never wrote it anywhere but a private temp folder."
