# CLAUDE.md — Executor File

Context for Claude Code sessions in this repo.

## What this is

**Executor File** — an encrypted, self-hosted file that lets an executor find
every asset a person owns and know what to do with each one. No credentials
stored, no service dependency. Domains secured: executorfile.com,
executor-file.com. GitHub: TheWayWithin/executor-file.

History: built 16 Jul 2026 as PRJ-15 Arm B (goal-first build experiment, repo
then named `digital-estate-goal`); won the A/B against the agent-11 arm and
became the product repo.

## Source of truth, in order

All specs live in `ideation/` (moved from repo root, 17 Jul 2026):

1. `ideation/executor-file-v0.3-release-spec.md` — the v0.3 "Executor
   Release" spec (five-review synthesis; §0 arbitrations and §6 rejections
   binding). Current build target; run via
   `ideation/executor-file-v0.3-goal-prompt.md`.
2. `ideation/SPEC-v1.md` — the staged build spec (v0.2 reliability → v0.3
   executor usability → v0.4 ecosystem → v1.0 acceptance test).
3. `ideation/digital-estate-roadmap.md` — the four-review synthesis behind
   SPEC-v1; its arbitrations (§1, §5) are binding.
4. `ideation/SPEC.md` — the original MVP control spec. Historical record;
   do not edit.

## Current state (16 Jul 2026, evening)

- MVP complete and verified: crypto round-trip proven byte-identical, gitignore
  + history clean, validator catches planted defects, executor walkthrough done.
- **§5.1 spike RESOLVED: batchpass wins.** `age-plugin-batchpass` (ships with
  age 1.3.1) emits a standard `-> scrypt` stanza; its output decrypts
  byte-identically with stock interactive `age -d`, and the reverse holds.
  `setup.sh`/`review.sh` use batchpass, falling back to `expect` when the
  plugin is absent (e.g. Ubuntu's age 1.1); `EXECUTOR_FILE_MECH` forces one.
- **v0.2 SHIPPED** (commits d9b94a9 + b4725df on main, CI green on
  macOS + Ubuntu, tests 37/37 both mechanisms): schema v2
  (format_version, priority/ownership/status/last_confirmed,
  action→preferred_action) in YAML + JSON Schema + example; two-tier
  validation (validate.sh now pure POSIX sh+awk, `--strict` runs validate.py);
  setup.sh (chain-proof: split → recombine → test-decrypt → cmp); review.sh
  (same-passphrase re-encrypt, shares stay valid — verified); plaintext
  honesty + Executor File language sweep; tests/run-tests.sh + fixtures +
  schema-agreement check + GitHub Actions (macOS+Ubuntu, shellcheck).
- Next work: **v0.3 "Executor Release"** — run the goal prompt in
  `ideation/executor-file-v0.3-goal-prompt.md` in a fresh session. Its spec
  supersedes SPEC-v1 §6 where they differ (notably: printed SHA-256 dropped
  for a `.sha256` sidecar; 2-of-3 locked, threshold flags removed).
- Awaiting Jamie: consolidation §2 (archive the old `digital-estate` repo
  (Arm A) with a pointer README).
- Session learnings worth keeping: `expect -` treats the first argument as a
  script file, so heredoc expect scripts must take filenames via env vars,
  not argv; `tr < /dev/urandom | head` dies with SIGPIPE (141) under
  `set -o pipefail` — bound the read first (this killed setup.sh on Ubuntu
  CI, which has no /usr/share/dict/words).

## Locked decisions

- **Naming:** product-facing prose says "your Executor File" (the encrypted
  register) and "Executor Instructions" (the printed page). Internal artefact
  names never change: `estate.yaml`, `estate.yaml.age`, script names.
- **Owner passphrase model (SPEC-v1 §4):** owner keeps the passphrase in their
  own password manager; Shamir shares are the executor's path, not the owner's.
  `review` re-encrypts with the same passphrase so shares stay valid.
- **Two-tier validation (SPEC-v1 §3):** POSIX sh+awk baseline that always runs;
  Python strict tier optional. The Python path must never be the only path.
- Rejected/parked list in SPEC-v1 §9 is binding (no public ciphertext hosting,
  no GUI yet, no provider automation ever).

## Hard rules

- The real `estate.yaml` and any `*.age` file are git-ignored and must NEVER
  be committed. Verify before any commit touching `.gitignore`.
- The executor recovery path uses stock `age` + `ssss` only — no repo scripts,
  no Python. Owner-side tooling may have dependencies; executor-side may not.
- Verify tool syntax empirically (run it), not from memory — this repo's docs
  promise exact commands.
- Testing interactive crypto: drive `age -p` with `expect` (see git history of
  the verification pass); `ssss-split`/`ssss-combine` accept piped stdin, and
  `ssss-combine` prints the secret to **stderr**.
