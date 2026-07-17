#!/bin/sh
# doctor.sh — pre-flight check: is this machine ready to create,
# review, and recover an Executor File?
#
# Usage:
#   scripts/doctor.sh
#
# Checks tools, versions, the encryption mechanism, the strict-tier
# Python, synced-folder hazards, and the state of any register in the
# current directory. Read-only: changes nothing.
#
# Exit codes: 0 = ready (warnings possible), 1 = something must be
# fixed before setup/review will work.
set -u

OKS=0; WARNS=0; FAILS=0
ok()   { OKS=$((OKS+1));   echo "  ok    $1"; }
note() { WARNS=$((WARNS+1)); echo "  note  $1"; }
bad()  { FAILS=$((FAILS+1)); echo "  FAIL  $1"; }

echo "Executor File doctor — $(date +%Y-%m-%d)"
echo

# ── OS ───────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?')" ;;
  Linux)  ok "Linux ($(uname -r))" ;;
  *)      note "untested OS: $(uname -s) — the tools are POSIX, it will probably work" ;;
esac

# ── core tools ───────────────────────────────────────────────────────
if command -v age >/dev/null 2>&1; then
  ok "age installed ($(age --version 2>/dev/null || echo 'version unknown'))"
else
  bad "age is NOT installed — macOS: brew install age; Debian/Ubuntu: sudo apt install age"
fi
if command -v ssss-split >/dev/null 2>&1 && command -v ssss-combine >/dev/null 2>&1; then
  ok "ssss installed (ssss-split + ssss-combine)"
else
  bad "ssss is NOT installed — macOS: brew install ssss; Debian/Ubuntu: sudo apt install ssss"
fi

# ── non-interactive mechanism (setup/review/rotate need one) ────────
HAVE_BP=0; HAVE_EXPECT=0
command -v age-plugin-batchpass >/dev/null 2>&1 && HAVE_BP=1
command -v expect >/dev/null 2>&1 && HAVE_EXPECT=1
if [ "$HAVE_BP" -eq 1 ]; then
  ok "mechanism: age-plugin-batchpass (preferred)"
elif [ "$HAVE_EXPECT" -eq 1 ]; then
  ok "mechanism: expect fallback (age-plugin-batchpass absent — fine; it ships with age >= 1.3)"
else
  bad "no mechanism: need age-plugin-batchpass (age >= 1.3) OR expect for setup/review/rotate"
fi

# ── passphrase dictionary ───────────────────────────────────────────
if [ -r "${EXECUTOR_FILE_DICT:-/usr/share/dict/words}" ]; then
  ok "system dictionary present (8-word passphrases)"
else
  note "no system dictionary — setup falls back to its built-in 256-word list (12 words, 96 bits): fine"
fi

# ── strict validation tier (optional) ───────────────────────────────
PYTHON="${PYTHON:-python3}"
if command -v "$PYTHON" >/dev/null 2>&1; then
  if "$PYTHON" -c 'import yaml' >/dev/null 2>&1; then
    if "$PYTHON" -c 'import jsonschema' >/dev/null 2>&1; then
      ok "strict tier ready: $PYTHON with PyYAML + jsonschema"
    else
      note "strict tier partial: PyYAML yes, jsonschema no (pip install jsonschema for the formal contract pass)"
    fi
  else
    note "strict tier unavailable: $PYTHON has no PyYAML (baseline validator always works regardless)"
  fi
else
  note "strict tier unavailable: no python3 (baseline validator always works regardless)"
fi

# ── synced-folder hazards ───────────────────────────────────────────
CWD_RESOLVED="$(pwd -P)"
case "$CWD_RESOLVED" in
  *Dropbox*|*"Mobile Documents"*|*iCloud*|*"Google Drive"*|*GoogleDrive*|*OneDrive*|*Syncthing*)
    bad "current directory is inside a SYNCED folder ($CWD_RESOLVED) — plaintext edited here gets uploaded. Work somewhere local." ;;
  *)
    ok "current directory is not a recognised synced folder" ;;
esac
TMP_RESOLVED="$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P || echo /tmp)"
case "$TMP_RESOLVED" in
  *Dropbox*|*"Mobile Documents"*|*iCloud*|*"Google Drive"*|*GoogleDrive*|*OneDrive*|*Syncthing*)
    bad "TMPDIR resolves inside a synced folder ($TMP_RESOLVED) — review.sh will refuse; point TMPDIR somewhere local" ;;
  *)
    ok "temp directory is local ($TMP_RESOLVED)" ;;
esac

# ── register state in this directory ────────────────────────────────
if [ -f estate.yaml ]; then
  note "plaintext estate.yaml present here — fine while editing; encrypt (setup.sh) and delete when done"
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git check-ignore -q estate.yaml; then
      ok "estate.yaml is git-ignored"
    else
      bad "estate.yaml is NOT git-ignored here — a commit could publish your estate. Fix .gitignore before anything else."
    fi
  fi
else
  ok "no plaintext register in this directory"
fi
if [ -f estate.yaml.age ]; then
  ok "encrypted register present (estate.yaml.age)"
  if [ -f estate.yaml.age.sha256 ]; then
    if command -v shasum >/dev/null 2>&1; then
      if shasum -c estate.yaml.age.sha256 >/dev/null 2>&1; then
        ok "sidecar matches (estate.yaml.age.sha256)"
      else
        note "sidecar does NOT match estate.yaml.age — refresh copies (a review updates it automatically)"
      fi
    elif sha256sum -c estate.yaml.age.sha256 >/dev/null 2>&1; then
      ok "sidecar matches (estate.yaml.age.sha256)"
    else
      note "sidecar does NOT match estate.yaml.age — refresh copies (a review updates it automatically)"
    fi
  else
    note "no .sha256 sidecar next to estate.yaml.age — the next review writes one"
  fi
else
  note "no encrypted register in this directory (run scripts/setup.sh when the plaintext is ready)"
fi
if [ -f recovery-tests.log ]; then
  ok "last recovery drill: $(tail -1 recovery-tests.log)"
else
  note "no recovery drill recorded yet — run scripts/test-recovery.sh with two printed shares"
fi

echo
if [ "$FAILS" -gt 0 ]; then
  echo "$FAILS blocker(s), $WARNS note(s). Fix the FAIL lines, then re-run."
  exit 1
fi
echo "Ready. $OKS check(s) ok, $WARNS note(s)."
exit 0
