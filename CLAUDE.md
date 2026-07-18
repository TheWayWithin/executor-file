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

## Current state (17 Jul 2026)

- **v0.3 "Executor Release" BUILT** (this session; see RELEASE-CHECKLIST.md
  for the two remaining human gates — Windows dry run + physical fire
  drill — which block the v0.3.0 tag). Everything scriptable is on main,
  tested under both mechanisms, CI green on macOS + Ubuntu.
- v0.3 highlights: threshold defect verified → **2-of-3 locked** (-t/-n
  removed everywhere, loud refusal); printed SHA-256 replaced by a
  `.sha256` sidecar + verify-copies.sh; share-display ceremony (one at a
  time, honest close-the-terminal advice); 256-word fallback dictionary +
  computed entropy figures; **schema v3** (settle/preserve, first_step,
  depends_on, beneficiary, billing_cycle, meta.jurisdictions array,
  contacts + documents; last_confirmed required for active, `unknown`
  allowed; estate.schema.json is the single source of truth with a CI
  drift test; v2 accepted this one version with migrate warnings);
  **render.sh** (triage report md+html, preserve-before-dispose,
  dependency-aware); **make-guide.sh** (fills the two-page
  EXECUTOR-INSTRUCTIONS from the register + recovery-tests.log);
  test-recovery.sh / rotate-shares.sh / share-sheets.sh / doctor.sh;
  review.sh staleness flow + .ics nudges; docs/WINDOWS-RECOVERY.md (WSL
  end-to-end — researched: no trustworthy native Windows ssss exists),
  docs/discovery-checklist.md, AGENTS.md, SECURITY.md, CONTRIBUTING.md,
  issue templates.
- **§5.1 spike RESOLVED: batchpass wins.** `age-plugin-batchpass` (ships with
  age 1.3.1) emits a standard `-> scrypt` stanza; its output decrypts
  byte-identically with stock interactive `age -d`, and the reverse holds.
  Owner scripts use batchpass, falling back to `expect` when the plugin is
  absent (e.g. Ubuntu's age 1.1); `EXECUTOR_FILE_MECH` forces one. CI runs
  expect against distro age first, then installs the official age 1.3.1
  build (checksum-pinned) on Ubuntu for the batchpass run.
- v0.2 history: commits d9b94a9 + b4725df (schema v2, two-tier validation,
  setup/review orchestration).
- **v0.3.0 TAGGED + RELEASED 18 Jul 2026** ahead of the two human gates,
  by deliberate owner decision (live end-to-end testing; zero traffic).
  Release notes state machine-verified vs pending honestly. The gates
  (UAT plan: docs/UAT-PLAN.md; tasks T-159..T-166) remain open as
  post-release validation blocking the "safe to recommend" claim;
  findings → v0.3.1. Consolidation done 17 Jul 2026: `digital-estate`
  (Arm A) archived on GitHub with a pointer README.
- Session learnings worth keeping: `expect -` treats the first argument as a
  script file, so heredoc expect scripts must take filenames via env vars,
  not argv; `tr < /dev/urandom | head` dies with SIGPIPE (141) under
  `set -o pipefail` — bound the read first; expect's one-line
  `expect { "pat" { act } timeout { act } }` treats the whole brace group
  as ONE pattern — multi-pattern expect blocks must be written across
  multiple lines; `&` in awk gsub/sub replacements means "the match" —
  escape register-derived values before substituting them into templates;
  passing an UNSET array element as a function argument crashes gawk 5.x
  ("Node_val" internal error) though BSD awk/mawk tolerate it — force a
  string with `"" A[...]` at call sites; never `git checkout --` a file
  whose only copy of new work is the working tree.

## Locked decisions

- **Naming:** product-facing prose says "your Executor File" (the encrypted
  register) and "Executor Instructions" (the printed page). Internal artefact
  names never change: `estate.yaml`, `estate.yaml.age`, script names.
- **Share scheme locked at 2-of-3** (v0.3 spec §0.1 ruling, defect verified
  empirically): no `-t`/`-n` anywhere; scripts refuse them loudly; 3-of-5 is
  a fork-it-yourself note only.
- **No checksum on the printed page** (v0.3 spec §0.2): age is authenticated
  encryption; the `.sha256` sidecar compares stored copies, never gates
  recovery.
- **Executor-side AI export parked** (v0.3 spec §0.3): executors are told not
  to paste the register into AI tools; render.sh serves that need instead.
  Owner-side AI authoring is governed by AGENTS.md.
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
