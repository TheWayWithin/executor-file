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

# ── freshness summary before the editor opens ───────────────────────
# Per-record freshness (last_confirmed) and whole-file freshness
# (meta.updated) are different facts; this report never conflates
# them. staleness_report FILE MODE: MODE=summary prints the human
# lines; MODE=stale prints just the stale count.
staleness_report() { # $1=file $2=mode
  awk -v today="$(date +%Y-%m-%d)" -v mode="$2" '
    function months_old(d,   y, m) {
      if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-/) return -1
      y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0
      return (substr(today, 1, 4) * 12 + substr(today, 6, 2)) - (y * 12 + m)
    }
    /^[a-zA-Z_]+:/ { flush_a(); section = $0; sub(/:.*$/, "", section) }
    section == "assets" && /^  - / { flush_a(); in_a = 1 }
    section == "assets" && in_a && /^    status:/       { st = $0; sub(/^.*status:[ ]*/, "", st); sub(/[ ]+#.*$/, "", st) }
    section == "assets" && in_a && /^    last_confirmed:/ { lc = $0; sub(/^.*last_confirmed:[ ]*/, "", lc); sub(/[ ]+#.*$/, "", lc); gsub(/"/, "", lc) }
    section == "platform_legacy_tools" && /^    configured:[ ]*false/ { tools_off++ }
    function flush_a() {
      if (!in_a) return
      if (st != "closed") {
        active++
        if (lc == "" ) missing++
        else if (lc == "unknown") unknown++
        else if (months_old(lc) > 18) old++
      }
      in_a = 0; st = ""; lc = ""
    }
    END {
      flush_a()
      stale = missing + unknown + old
      if (mode == "stale") { print stale + 0; exit }
      printf "  %d active record(s)", active + 0
      if (old)     printf "; %d not confirmed in 18+ months", old
      if (missing) printf "; %d missing confirmation dates", missing
      if (unknown) printf "; %d marked unknown", unknown
      if (tools_off) printf "; %d legacy tool(s) unconfigured", tools_off
      printf "\n"
      if (stale) printf "  While the editor is open, re-check those and set their last_confirmed.\n"
    }
  ' "$1"
}
echo "Freshness before this review:"
staleness_report "$PLAIN" summary
echo

# ── edit + validate loop ────────────────────────────────────────────
# $VISUAL wins over $EDITOR (the long-standing Unix convention); values
# with arguments ("code --wait") work; unset falls back to nano (vi if
# nano is missing) with a clear message.
EDITOR_CMD="${VISUAL:-${EDITOR:-}}"
if [ -z "$EDITOR_CMD" ]; then
  if command -v nano >/dev/null 2>&1; then EDITOR_CMD="nano"; else EDITOR_CMD="vi"; fi
  echo "(\$VISUAL and \$EDITOR are unset — opening $EDITOR_CMD. To use your"
  echo " own editor next time: export EDITOR='code --wait' or similar.)"
fi
while :; do
  sh -c "$EDITOR_CMD \"\$1\"" sh "$PLAIN"
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
echo

# ── per-record freshness: only claim what actually happened ─────────
# "Yes" means every ACTIVE entry was verified today: all their
# last_confirmed dates move to today. "No" (the default) leaves every
# per-record date exactly as edited — the file is fresh, the records
# keep their own truth.
printf 'Did you verify ALL active entries are accurate today? [y/N] '
read -r verified_all || verified_all=n
case "$verified_all" in
  y|Y|yes|YES)
    tmp_lc="$WORK/estate.confirmed.yaml"
    awk -v today="$TODAY" '
      function flush_block(   i, had_lc, is_active) {
        if (nbuf == 0) return
        is_active = 1; had_lc = 0
        for (i = 1; i <= nbuf; i++) {
          if (buf[i] ~ /^    status:[ ]*closed([ ]|$)/) is_active = 0
          if (buf[i] ~ /^    last_confirmed:/) had_lc = 1
        }
        for (i = 1; i <= nbuf; i++) {
          if (is_active && buf[i] ~ /^    last_confirmed:/)
            buf[i] = "    last_confirmed: " today
          print buf[i]
          if (is_active && !had_lc && buf[i] ~ /^    status:/) {
            print "    last_confirmed: " today
            had_lc = 1
          }
        }
        nbuf = 0
      }
      /^[a-zA-Z_]+:/ { flush_block(); in_assets = ($0 ~ /^assets:/); print; next }
      in_assets && /^  - / { flush_block(); buf[++nbuf] = $0; next }
      in_assets && nbuf > 0 { buf[++nbuf] = $0; next }
      { print }
      END { flush_block() }
    ' "$PLAIN" > "$tmp_lc"
    mv "$tmp_lc" "$PLAIN"
    echo "All active entries: last_confirmed set to ${TODAY}."
    ;;
  *)
    STALE_LEFT="$(staleness_report "$PLAIN" stale)"
    if [ "${STALE_LEFT:-0}" -gt 0 ]; then
      echo "Kept individual confirmation dates: file edited today, but ${STALE_LEFT} record(s) remain stale."
      echo "(Confirm entries one by one by setting their last_confirmed as you check them.)"
    else
      echo "Kept individual confirmation dates — none are stale."
    fi
    ;;
esac

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

# Refresh the copy-comparison sidecar (used by scripts/verify-copies.sh
# to confirm stored copies are identical — recovery never needs it;
# age's authenticated encryption already proves integrity on decrypt).
if command -v shasum >/dev/null 2>&1; then
  (cd "$(dirname "$IN")" && shasum -a 256 "$(basename "$IN")") > "$IN.sha256"
else
  (cd "$(dirname "$IN")" && sha256sum "$(basename "$IN")") > "$IN.sha256"
fi

# ── calendar nudges: zero service dependency, just an .ics file ─────
ICS="$(dirname "$IN")/executor-file-reminders.ics"
awk -v today="$TODAY" '
  function plus_months(d, n,   y, m) {
    y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0
    m = m + n
    while (m > 12) { m -= 12; y++ }
    # day 15: every month has one, no clamping surprises
    return sprintf("%04d%02d15", y, m)
  }
  BEGIN {
    stamp = substr(today, 1, 4) substr(today, 6, 2) substr(today, 9, 2) "T000000Z"
    print "BEGIN:VCALENDAR"
    print "VERSION:2.0"
    print "PRODID:-//Executor File//review.sh//EN"
    n = split("6:Executor File — six-month quick check (scripts/review.sh)|12:Executor File — annual full review (scripts/review.sh)|13:Executor File — annual fire drill (scripts/test-recovery.sh with two printed shares)", ev, "|")
    for (i = 1; i <= n; i++) {
      split(ev[i], p, ":")
      print "BEGIN:VEVENT"
      print "UID:executor-file-" p[1] "m-" stamp "@local"
      print "DTSTAMP:" stamp
      print "DTSTART;VALUE=DATE:" plus_months(today, p[1] + 0)
      print "SUMMARY:" p[2]
      print "END:VEVENT"
    }
    print "END:VCALENDAR"
  }
' > "$ICS"

echo
echo "Review complete. $IN re-encrypted with the same passphrase —"
echo "the shares your holders hold are still valid. The .sha256 sidecar"
echo "was refreshed alongside it."
echo
echo "Calendar nudges written to $ICS —"
echo "double-click it (or import into any calendar) to book the"
echo "six-month quick check, next annual review, and annual fire drill."
echo
echo "Remaining hand-work:"
echo "  • Refresh every stored copy of $IN (USB sticks, private cloud)"
echo "    with this new version AND its new .sha256 sidecar — old copies"
echo "    are now out of date (scripts/verify-copies.sh will spot this)."
echo "  • If you confirmed individual entries are still accurate, set"
echo "    their last_confirmed to ${TODAY} next time you edit."
echo
echo "The working plaintext was removed with its temp folder. Deleting"
echo "plaintext reduces exposure; it does not erase history — which is"
echo "why review.sh never wrote it anywhere but a private temp folder."
