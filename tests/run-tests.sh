#!/usr/bin/env bash
# run-tests.sh — the v0.2 test suite (SPEC-v1 §5.7).
#
# Usage:  tests/run-tests.sh
#
# Covers: validator fixtures on both tiers + tier agreement (§3.3),
# the full crypto round-trip through every 2-share pair, failure
# modes (mistyped share, wrong passphrase), setup.sh and review.sh
# end-to-end, and the .gitignore regression.
#
# Needs: age, ssss. The strict-tier and tier-agreement checks run
# when $PYTHON (default python3) has PyYAML, and are SKIPPED with a
# note otherwise. Set EXECUTOR_FILE_MECH=expect to force the expect
# mechanism.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_N=0; FAIL_N=0; SKIP_N=0
ok()   { PASS_N=$((PASS_N+1)); echo "  ok    $1"; }
fail() { FAIL_N=$((FAIL_N+1)); echo "  FAIL  $1"; }
skip() { SKIP_N=$((SKIP_N+1)); echo "  skip  $1"; }
check() { # $1=description, $2=expected rc, actual rc in $3
  if [ "$3" -eq "$2" ]; then ok "$1"; else fail "$1 (expected rc=$2, got rc=$3)"; fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
PYTHON="${PYTHON:-python3}"
HAVE_STRICT=0
if command -v "$PYTHON" >/dev/null 2>&1 && "$PYTHON" -c 'import yaml' >/dev/null 2>&1; then
  HAVE_STRICT=1
fi

echo "== validator fixtures (baseline tier) =="
run_base() { sh "$ROOT/scripts/validate.sh" "$1" >/dev/null 2>&1; }
run_base "$ROOT/tests/fixtures/good-v2.yaml";     check "good-v2 passes baseline" 0 $?
run_base "$ROOT/tests/fixtures/warn-crypto.yaml"; check "warn-crypto passes baseline (warnings only)" 0 $?
run_base "$ROOT/tests/fixtures/bad-format1.yaml"; check "bad-format1 fails baseline" 1 $?
run_base "$ROOT/tests/fixtures/bad-secrets.yaml"; check "bad-secrets fails baseline" 1 $?
run_base "$ROOT/tests/fixtures/bad-enum.yaml";    check "bad-enum fails baseline" 1 $?

sh "$ROOT/scripts/validate.sh" "$ROOT/tests/fixtures/bad-format1.yaml" 2>/dev/null | grep -q "format 1 register" \
  && ok "bad-format1 gets the migrate message" || fail "bad-format1 missing migrate message"
sh "$ROOT/scripts/validate.sh" "$ROOT/tests/fixtures/bad-format1.yaml" 2>/dev/null | grep -q 'renamed in format 2' \
  && ok "old 'action' name gets the rename hint" || fail "old 'action' name: no rename hint"

echo "== validator fixtures (strict tier + tier agreement, §3.3) =="
if [ "$HAVE_STRICT" -eq 1 ]; then
  for f in good-v2 warn-crypto bad-format1 bad-secrets bad-enum; do
    sh "$ROOT/scripts/validate.sh" "$ROOT/tests/fixtures/$f.yaml" >/dev/null 2>&1; base_rc=$?
    "$PYTHON" "$ROOT/scripts/validate.py" "$ROOT/tests/fixtures/$f.yaml" >/dev/null 2>&1; strict_rc=$?
    if [ "$base_rc" -eq "$strict_rc" ]; then
      ok "tier agreement on $f (both rc=$base_rc)"
    else
      fail "tier DISAGREEMENT on $f (baseline rc=$base_rc, strict rc=$strict_rc)"
    fi
  done
else
  skip "strict tier: $PYTHON has no PyYAML (baseline already covered above)"
fi

echo "== .gitignore regression (§5.7) =="
git -C "$ROOT" check-ignore -q estate.yaml            && ok "estate.yaml is ignored"          || fail "estate.yaml NOT ignored"
git -C "$ROOT" check-ignore -q scripts/estate.yaml    && ok "nested estate.yaml is ignored"   || fail "nested estate.yaml NOT ignored"
git -C "$ROOT" check-ignore -q estate.yaml.age        && ok "estate.yaml.age is ignored"      || fail "estate.yaml.age NOT ignored"
git -C "$ROOT" check-ignore -q backups/anything.age   && ok "*.age is ignored anywhere"       || fail "*.age NOT ignored anywhere"
git -C "$ROOT" check-ignore -q my-share-2.txt         && ok "share-named .txt is ignored"     || fail "share .txt NOT ignored"

echo "== crypto round-trip: all three 2-share pairs (§5.7) =="
PASSPHRASE='round-trip-test-passphrase-for-ci'
cp "$ROOT/examples/estate.example.yaml" "$T/estate.yaml"

# Encrypt with the same mechanism selection setup.sh uses.
if [ "${EXECUTOR_FILE_MECH:-}" = expect ] || ! command -v age-plugin-batchpass >/dev/null 2>&1; then
  if ! command -v expect >/dev/null 2>&1; then
    fail "neither age-plugin-batchpass nor expect available"; exit 1
  fi
  PASS="$PASSPHRASE" INFILE="$T/estate.yaml" OUTFILE="$T/estate.yaml.age" expect <<'EOF' >/dev/null
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
  check "encrypt via expect" 0 $?
else
  AGE_PASSPHRASE="$PASSPHRASE" age -e -j batchpass -o "$T/estate.yaml.age" "$T/estate.yaml"
  check "encrypt via batchpass" 0 $?
fi

SHARES="$(printf '%s\n' "$PASSPHRASE" | ssss-split -t 2 -n 3 -w estate -q 2>/dev/null)"
[ "$(printf '%s\n' "$SHARES" | wc -l | tr -d ' ')" = 3 ] && ok "ssss-split issued 3 shares" || fail "ssss-split share count wrong"
S1="$(printf '%s\n' "$SHARES" | sed -n 1p)"
S2="$(printf '%s\n' "$SHARES" | sed -n 2p)"
S3="$(printf '%s\n' "$SHARES" | sed -n 3p)"

pair_i=0
for pair in "$S1 $S2" "$S1 $S3" "$S2 $S3"; do
  pair_i=$((pair_i+1))
  a="${pair%% *}"; b="${pair#* }"
  SECRET="$(printf '%s\n%s\n' "$a" "$b" | ssss-combine -t 2 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
  [ "$SECRET" = "$PASSPHRASE" ] && ok "pair $pair_i reconstructs the passphrase" || fail "pair $pair_i reconstruction mismatch"
done

# Executor-path decrypt: stock interactive age -d (no plugin), driven by
# expect where available; otherwise batchpass decrypt as the fallback proof.
if command -v expect >/dev/null 2>&1; then
  PASS="$PASSPHRASE" INFILE="$T/estate.yaml.age" OUTFILE="$T/rt.yaml" expect <<'EOF' >/dev/null
set timeout 120
spawn age -d -o $env(OUTFILE) $env(INFILE)
expect "Enter passphrase*"
send -- "$env(PASS)\r"
expect eof
catch wait result
exit [lindex $result 3]
EOF
  check "stock interactive age -d decrypts" 0 $?
else
  AGE_PASSPHRASE="$PASSPHRASE" age -d -j batchpass -o "$T/rt.yaml" "$T/estate.yaml.age"
  check "batchpass decrypts (expect unavailable for interactive proof)" 0 $?
fi
cmp -s "$T/estate.yaml" "$T/rt.yaml" && ok "round-trip byte-identical" || fail "round-trip NOT byte-identical"

echo "== failure modes (§5.7) =="
# Mistyped share: flip the final hex digit of share 2.
S2_BASE="${S2%?}"
case "$S2" in *0) MUT="${S2_BASE}1" ;; *) MUT="${S2_BASE}0" ;; esac
BAD_SECRET="$(printf '%s\n%s\n' "$S1" "$MUT" | ssss-combine -t 2 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
[ "$BAD_SECRET" != "$PASSPHRASE" ] && ok "mistyped share yields a non-matching secret" || fail "mistyped share produced the REAL secret"

# One share alone must not reconstruct.
printf '%s\n' "$S1" | ssss-combine -t 2 >/dev/null 2>&1
[ $? -ne 0 ] && ok "a single share reconstructs nothing" || fail "single share reconstructed something"

# Wrong passphrase must not decrypt.
if command -v age-plugin-batchpass >/dev/null 2>&1; then
  AGE_PASSPHRASE='wrong-passphrase' age -d -j batchpass -o "$T/nope.yaml" "$T/estate.yaml.age" 2>/dev/null
  [ $? -ne 0 ] && ok "wrong passphrase is rejected" || fail "wrong passphrase decrypted"
else
  skip "wrong-passphrase check needs batchpass"
fi

echo "== setup.sh end-to-end (§5.1) =="
mkdir -p "$T/setup"
cp "$ROOT/examples/estate.example.yaml" "$T/setup/estate.yaml"
( cd "$T/setup" && "$ROOT/scripts/setup.sh" > setup.log 2>&1 )
check "setup.sh succeeds on the example register" 0 $?
[ -f "$T/setup/estate.yaml.age" ] && ok "setup produced estate.yaml.age" || fail "no estate.yaml.age produced"
grep -q "Chain verified" "$T/setup/setup.log" && ok "setup proved the share->decrypt chain" || fail "setup did not prove the chain"
[ -f "$T/setup/estate.yaml.age.sha256" ] && ok "setup wrote the .sha256 sidecar" || fail "setup wrote no .sha256 sidecar"
if command -v shasum >/dev/null 2>&1; then
  ( cd "$T/setup" && shasum -c estate.yaml.age.sha256 >/dev/null 2>&1 )
else
  ( cd "$T/setup" && sha256sum -c estate.yaml.age.sha256 >/dev/null 2>&1 )
fi
check "sidecar verifies with stock shasum/sha256sum -c" 0 $?

mkdir -p "$T/setupbad"
printf 'meta:\n  owner: x\n' > "$T/setupbad/estate.yaml"
( cd "$T/setupbad" && "$ROOT/scripts/setup.sh" > setup.log 2>&1 )
[ $? -ne 0 ] && ok "setup aborts on an invalid register" || fail "setup sealed an invalid register"
[ ! -f "$T/setupbad/estate.yaml.age" ] && ok "no partial .age left behind" || fail "partial .age left behind"

echo "== review.sh end-to-end (§5.2) =="
SETUP_PASS="$(awk '/The passphrase is:/{f=1;next} f && NF {print $1; exit}' "$T/setup/setup.log")"
if [ -z "$SETUP_PASS" ]; then
  fail "could not parse generated passphrase from setup output"
else
  ( cd "$T/setup" && printf '%s\n' "$SETUP_PASS" | EDITOR=true "$ROOT/scripts/review.sh" estate.yaml.age > review.log 2>&1 )
  check "review.sh succeeds with the correct passphrase" 0 $?
  grep -q "same passphrase" "$T/setup/review.log" && ok "review kept the same passphrase" || fail "review output missing same-passphrase confirmation"
  # The original shares must still open the reviewed file.
  RS1="$(sed -n 's/^  Share 1:  //p' "$T/setup/setup.log")"
  RS2="$(sed -n 's/^  Share 2:  //p' "$T/setup/setup.log")"
  REC="$(printf '%s\n%s\n' "$RS1" "$RS2" | ssss-combine -t 2 2>&1 >/dev/null | sed -n 's/^Resulting secret: //p')"
  [ "$REC" = "$SETUP_PASS" ] && ok "original shares still reconstruct after review" || fail "shares no longer reconstruct after review"
  ( cd "$T/setup" && printf '%s\n' 'wrong-passphrase' | EDITOR=true "$ROOT/scripts/review.sh" estate.yaml.age > review-bad.log 2>&1 )
  [ $? -ne 0 ] && ok "review rejects a wrong passphrase" || fail "review accepted a wrong passphrase"

  # Sidecar refreshed by review: must match the re-encrypted file.
  if command -v shasum >/dev/null 2>&1; then
    ( cd "$T/setup" && shasum -c estate.yaml.age.sha256 >/dev/null 2>&1 )
  else
    ( cd "$T/setup" && sha256sum -c estate.yaml.age.sha256 >/dev/null 2>&1 )
  fi
  check "review refreshed the .sha256 sidecar" 0 $?
fi

echo "== P0 regression: the share scheme is locked at 2-of-3 =="
mkdir -p "$T/lock"
cp "$ROOT/examples/estate.example.yaml" "$T/lock/estate.yaml"
( cd "$T/lock" && "$ROOT/scripts/setup.sh" -t 3 -n 5 estate.yaml > lock.log 2>&1 < /dev/null )
check "setup.sh -t 3 -n 5 fails loudly" 2 $?
grep -q "fixed at 2-of-3" "$T/lock/lock.log" && ok "refusal explains the 2-of-3 lock" || fail "refusal lacks the 2-of-3 explanation"
[ ! -f "$T/lock/estate.yaml.age" ] && ok "no .age produced by refused flags" || fail "refused flags still produced an .age"
( cd "$T/lock" && "$ROOT/scripts/setup.sh" -n 5 estate.yaml > lock2.log 2>&1 < /dev/null )
check "setup.sh -n alone also fails loudly" 2 $?
( "$ROOT/scripts/split-secret.sh" -t 3 > "$T/lock/split.log" 2>&1 < /dev/null )
check "split-secret.sh -t fails loudly" 2 $?
grep -q "fixed at 2-of-3" "$T/lock/split.log" && ok "split-secret refusal explains the lock" || fail "split-secret refusal lacks explanation"

echo "== P0 regression: fallback dictionary + honest entropy =="
mkdir -p "$T/dict"
cp "$ROOT/examples/estate.example.yaml" "$T/dict/estate.yaml"
( cd "$T/dict" && EXECUTOR_FILE_DICT=/nonexistent-dictionary "$ROOT/scripts/setup.sh" > setup.log 2>&1 < /dev/null )
check "setup succeeds with no system dictionary (256-word fallback)" 0 $?
grep -q "96 bits" "$T/dict/setup.log" && ok "fallback reports its honest 96-bit figure" || fail "fallback entropy figure missing"
FB_PASS="$(awk '/The passphrase is:/{f=1;next} f && NF {print $1; exit}' "$T/dict/setup.log")"
FB_WORDS="$(printf '%s\n' "$FB_PASS" | awk -F- '{print NF}')"
[ "$FB_WORDS" = 12 ] && ok "fallback passphrase draws 12 words" || fail "fallback passphrase has $FB_WORDS words, wanted 12"
if [ -r /usr/share/dict/words ]; then
  grep -Eq "from [0-9]+ eligible dictionary words ≈ [0-9]+ bits" "$T/setup/setup.log" \
    && ok "dictionary path reports computed entropy, not a slogan" || fail "dictionary path entropy figure missing"
else
  skip "no system dictionary on this host — computed-entropy wording covered by fallback test"
fi

echo "== P0 regression: editor handling in review.sh =="
if [ -n "${SETUP_PASS:-}" ]; then
  cat > "$T/ed-args.sh" <<'EOS'
#!/bin/sh
# fake editor: requires its flag AND the file to exist, then touches a marker
[ "$1" = "--flag" ] || exit 9
[ -f "$2" ] || exit 9
touch "${ED_MARKER:?}"
EOS
  chmod +x "$T/ed-args.sh"
  ( cd "$T/setup" && printf '%s\n' "$SETUP_PASS" | ED_MARKER="$T/ed-args-ran" EDITOR="$T/ed-args.sh --flag" "$ROOT/scripts/review.sh" estate.yaml.age > review-ed.log 2>&1 )
  check "review.sh works with EDITOR containing arguments" 0 $?
  [ -f "$T/ed-args-ran" ] && ok "argument-carrying EDITOR was actually invoked" || fail "argument-carrying EDITOR never ran"
  ( cd "$T/setup" && printf '%s\n' "$SETUP_PASS" | VISUAL=true EDITOR=false "$ROOT/scripts/review.sh" estate.yaml.age > review-vis.log 2>&1 )
  check "VISUAL wins over EDITOR (EDITOR=false would abort)" 0 $?
else
  skip "editor tests need the setup.sh passphrase from earlier"
fi

echo "== verify-copies.sh =="
if [ -f "$T/setup/estate.yaml.age" ]; then
  mkdir -p "$T/copies"
  cp "$T/setup/estate.yaml.age" "$T/copies/copy1.age"
  cp "$T/setup/estate.yaml.age" "$T/copies/copy2.age"
  "$ROOT/scripts/verify-copies.sh" "$T/setup/estate.yaml.age" "$T/copies/copy1.age" "$T/copies/copy2.age" > "$T/copies/ok.log" 2>&1
  check "identical copies pass verify-copies" 0 $?
  printf 'corruption' >> "$T/copies/copy2.age"
  "$ROOT/scripts/verify-copies.sh" "$T/setup/estate.yaml.age" "$T/copies/copy1.age" "$T/copies/copy2.age" > "$T/copies/bad.log" 2>&1
  check "a corrupted copy fails verify-copies" 1 $?
  grep -q "DIFFERS" "$T/copies/bad.log" && ok "corrupted copy is named as DIFFERS" || fail "corrupted copy not flagged"
else
  skip "verify-copies tests need the setup.sh output from earlier"
fi

echo "== P0 regression: interactive share ceremony (one at a time) =="
if command -v expect >/dev/null 2>&1; then
  mkdir -p "$T/cer"
  cp "$ROOT/examples/estate.example.yaml" "$T/cer/estate.yaml"
  CER_DIR="$T/cer" SETUP_BIN="$ROOT/scripts/setup.sh" expect > "$T/cer/cer.log" 2>&1 <<'EOF'
set timeout 120
cd $env(CER_DIR)
spawn $env(SETUP_BIN) estate.yaml
expect {
  "Press Enter to show share 1" { send -- "\r" }
  timeout { exit 10 }
}
expect {
  "Share 1 of 3" {}
  timeout { exit 11 }
}
expect {
  "Press Enter once share 1" { send -- "\r" }
  timeout { exit 12 }
}
expect {
  "Share 2 of 3" {}
  timeout { exit 13 }
}
expect {
  "Press Enter once share 2" { send -- "\r" }
  timeout { exit 14 }
}
expect {
  "Share 3 of 3" {}
  timeout { exit 15 }
}
expect {
  "Press Enter once share 3" { send -- "\r" }
  timeout { exit 16 }
}
expect {
  "password manager" {}
  timeout { exit 17 }
}
expect {
  "Press Enter once it is saved" { send -- "\r" }
  timeout { exit 18 }
}
expect {
  "Do these now" {}
  timeout { exit 19 }
}
expect eof
catch wait result
exit [lindex $result 3]
EOF
  check "ceremony walks shares one at a time on a tty" 0 $?
  [ -f "$T/cer/estate.yaml.age" ] && ok "ceremony run still sealed the file" || fail "ceremony run produced no .age"
else
  skip "ceremony test needs expect"
fi

echo "== corrected claims stay gone (grep sweep) =="
sweep() { # $1=pattern $2=label
  if git -C "$ROOT" grep -il -e "$1" -- ':!ideation' ':!tests' >/dev/null 2>&1; then
    fail "$2 crept back in: $(git -C "$ROOT" grep -il -e "$1" -- ':!ideation' ':!tests' | tr '\n' ' ')"
  else
    ok "$2 absent everywhere"
  fi
}
sweep "no secrets at rest"       "'no secrets at rest' claim"
sweep "history -c"               "'history -c' erasure claim"
sweep "including a borrowed one" "borrowed-computer advice"
sweep "crypto entries first"     "crypto-first triage doctrine"

echo
echo "passed: $PASS_N   failed: $FAIL_N   skipped: $SKIP_N"
[ "$FAIL_N" -eq 0 ]
