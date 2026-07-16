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

1. `SPEC-v1.md` — the staged build spec (v0.2 reliability → v0.3 executor
   usability → v0.4 ecosystem → v1.0 acceptance test). Work from this.
2. `digital-estate-roadmap.md` — the four-review synthesis behind SPEC-v1;
   its arbitrations (§1, §5) are binding.
3. `SPEC.md` — the original MVP control spec. Historical record; do not edit.

## Current state (16 Jul 2026)

- MVP complete and verified: crypto round-trip proven byte-identical, gitignore
  + history clean, validator catches planted defects, executor walkthrough done.
- Next work: **v0.2 (SPEC-v1 §5)**. First task is the §5.1 spike: verify
  whether `age-plugin-batchpass` output decrypts with stock interactive
  `age -d`; that decides setup.sh's mechanism (batchpass vs expect).
- Consolidation (§2): GitHub rename done, local folder renamed. Still pending:
  archive the old `digital-estate` repo (Arm A) with a pointer README — needs
  Jamie.

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
