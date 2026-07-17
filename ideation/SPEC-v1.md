# Digital Estate Register — Spec v1.0 (evolution from MVP)

**Status:** draft v0.1, 16 July 2026
**Source:** `digital-estate-roadmap.md` (synthesis of four independent reviews). This spec turns that roadmap into buildable, testable requirements. Where the roadmap arbitrated a disagreement, the arbitration is binding here.
**Baseline:** this repo (the Arm B build) is the base. The MVP control spec (`SPEC.md`) stays untouched as the historical record.
**Done means:** the v1.0 acceptance test in section 8 passes. Nothing else counts as mature.

---

## 1. Non-negotiable invariants (unchanged from MVP)

Every phase below must preserve these. A change that violates one is wrong even if it ships a wanted feature.

1. `age` passphrase encryption; 2-of-3 `ssss` split of the passphrase (3-of-5 documented as an option, never the default).
2. No credentials, seeds, PINs, or full account numbers in the register — enforced by the validator, not just prose.
3. Real `estate.yaml` and any `*.age` file git-ignored, never committed.
4. The executor recovery path uses stock `age` + `ssss` only — no repo, no Python, no script of ours required to get in.
5. No service dependency, no hosting, no accounts. A file, not an app.
6. The register never reads as overriding the will. Disposition fields are guidance, subject to the will, beneficiary designations, ownership rights, provider rules, and law.

## 2. Repo consolidation and naming (do first)

1. **One repo forward: this one.** v2 is based on this repo's structure (schema-driven validator, executor doc, validate-before-encrypt), importing the sibling repo's zero-dependency validator stance (section 3).
2. **Product name: Executor File** (decided by Jamie, 16 Jul 2026). Repo renamed to `executor-file`; domains secured: executorfile.com and executor-file.com. GitHub renames preserve redirects.
3. **Naming convention (locked, flows through everything product-facing):**
   - The encrypted register is **"your Executor File"** in all user-facing prose (README, templates, script output, site copy).
   - The printed page is the **"Executor Instructions"**.
   - **Internal artefact names do not change:** `estate.yaml`, `estate.yaml.age`, schema files, script names stay as-is. Rationale: zero churn in commands and docs the executor must type, and the file a stressed executor holds keeps matching the commands on the page.
   - v0.2 carries a language sweep (5.6) applying this to every user-facing string.
4. **Archive `digital-estate`** (Arm A): mark archived on GitHub, README replaced with one paragraph pointing at `executor-file`. Keep it readable — it is the A/B experiment record.
4. **Immediate hygiene in `digital-estate` before archiving:** delete the plaintext `estate.yaml` sitting in its working tree (it is dummy/test data from the build, but plaintext-at-rest contradicts the design and sets a bad example). Its `encrypt.sh` overwrite/no-validate defects need no fix — the repo is being archived; the pointer README says "superseded, do not use the scripts here".

## 3. Two-tier validation (arbitration: shell AND Python, never Python-only)

The goal repo's Python validator failed on a stock Mac (no PyYAML). A tool whose pitch is "works forever, no dependencies" cannot fail that way.

1. **Tier 1 — baseline, zero-dependency.** `scripts/validate.sh` becomes pure POSIX sh + awk (port the Arm A validator). Runs on any Unix machine forever. Checks: YAML parses at the subset level we emit, required fields present, enum values legal, unique IDs, no digit-run ≥9, credential-pattern flags. This tier is what `encrypt.sh`/`setup` call — validation can never again be silently skipped.
2. **Tier 2 — strict, optional, clearly labelled.** `scripts/validate.py` stays, extended: validates against the real JSON Schema (section 5.5), duplicate IDs, per-entry staleness (`last_confirmed` older than N months → warning), coverage checks (e.g. crypto without `access_pointer`). Invoked as `validate.sh --strict`; if its dependencies are missing it says so and exits non-zero *only for the strict tier*, never blocking the baseline.
3. Both tiers agree on what is an ERROR vs a WARNING; a fixture-based test asserts they give the same verdict on the same good/bad examples.

## 4. Owner passphrase model (make the implicit explicit)

The MVP left a hole: the owner autogenerates a passphrase, splits it, distributes shares — and then cannot open their own register at the next annual review without collecting shares.

**Resolution:** the owner stores the register passphrase in their own password manager, alongside every other credential. The Shamir shares exist so the *executor* can get in without the owner; they are not the owner's own access path. This is consistent with the threat model (the password manager is the credential store; the register protects against outsiders and lone shareholders, not against its owner).

Consequences, to be documented in README and enforced by tooling:
- `setup` (5.1) tells the owner to save the passphrase in the password manager as its final step.
- `review` (5.2) prompts for the passphrase and re-encrypts **with the same one**, so existing shares stay valid.
- Changing the passphrase is a deliberate act: `rotate-shares` (6.5) — new passphrase, new split, redistribute, destroy old shares.

## 5. v0.2 — Reliability (build first, ~1 sprint)

### 5.1 `scripts/setup.sh` — one orchestrated command
Closes the passphrase-mismatch hole (today a typo between `encrypt.sh` and `split-secret.sh` produces three valid shares that open nothing).

Flow, all in one process, passphrase held in memory only, never written to disk:
1. Baseline-validate `estate.yaml` (abort on error).
2. Obtain the passphrase **once**: default = generate a diceware-style phrase in-script (≤128 ASCII chars, ssss's cap); `--own` lets the owner type one (twice, hidden).
3. Encrypt to `estate.yaml.age`.
4. Split that same in-memory passphrase 2-of-3 (`ssss-split` via stdin).
5. Prove the chain: reconstruct from two of the three just-issued shares (`ssss-combine` via stdin), test-decrypt to a temp file, byte-compare with the original (`cmp`).
6. Report success **only** if step 5 passes; otherwise clean up and abort loudly.
7. Print the shares + next steps (print/distribute, save passphrase to password manager, delete plaintext per section 5.4).

**Implementation constraint:** the `.age` output must remain decryptable by a stock interactive `age -d` — that is the executor path. Preferred mechanism for non-interactive encrypt/decrypt inside `setup` is `age-plugin-batchpass` (ships with age ≥1.3.0) **if and only if** its output is a standard scrypt stanza — verify this at build time by round-tripping batchpass-encrypted output through plain interactive `age -d`. If it is not, fall back to driving `age -p` with `expect` (present by default on macOS; `expect` becomes a documented owner-side dependency on Linux). Owner-side ergonomics may depend on such tools; the executor side never does.

### 5.2 `scripts/review.sh` — the maintenance loop in one command
Staleness is the stated residual risk; a five-step manual loop guarantees it happens never.

Flow: prompt for passphrase → decrypt into a `mktemp -d` working dir (mode 700, and warn+abort if `$TMPDIR` resolves inside a synced folder) → open `$EDITOR` → baseline-validate (loop back into the editor on error) → bump `meta.updated` → re-encrypt with the **same** passphrase → `cmp`-verify by test-decrypt → remove the working plaintext → remind about per-entry `last_confirmed`.

### 5.3 Schema v2 — additions (only these; ~15 proposed, rest rejected)
`schema/estate.schema.yaml` and both validators updated together:
- `meta.format_version: 2` — **required.** Old registers without it are treated as format 1 and get a clear migrate message, not silent misparse.
- Per asset:
  - `priority: critical | high | normal | low` (required; replaces "HIGH PRIORITY" prose — renderers and executors sort on it; validator warns if a `crypto` asset is below `high`).
  - `ownership: sole | joint | beneficiary-designated | trust | business-owned | unknown` (required; a joint account and a sole account cannot share a generic "liquidate").
  - `last_confirmed: <date>` (optional, recommended; per-item staleness).
  - `status: active | closed` (required, default guidance `active`; closed accounts leave a trail instead of vanishing).
- **Rename `action` → `preferred_action`.** Validator errors on the old name with a one-line fix hint. The schema doc and example carry the legal disclaimer verbatim: *preferred actions are practical guidance, subject to the will, beneficiary designations, ownership rights, provider terms, and applicable law.*
- `examples/estate.example.yaml` updated to v2 and stays the copy-this starting point.

### 5.4 Plaintext-handling honesty
Purge every "the .age file is now the only copy" claim. `rm` does not erase on SSDs, synced folders, snapshots, or editor backups. Replacement guidance (README + `setup` output): work on a full-disk-encrypted machine; never create `estate.yaml` inside a synced folder; prefer the `review` temp-dir flow; deleting the plaintext reduces exposure, it does not erase history.

### 5.5 Real JSON Schema
`schema/estate.schema.json` — valid JSON Schema (draft 2020-12, with `$id`), the formal contract. Standard tools and LLMs can validate a register without our scripts. The YAML schema file remains the annotated human reference; a CI check asserts the two agree on fields, enums, and requiredness.

### 5.6 Product-language sweep
Apply the section 2.3 naming convention across README, `templates/`, and every script's user-facing output: "your Executor File" for the encrypted register, "Executor Instructions" for the printed page. Internal filenames and commands unchanged. Acceptance: `grep -ri "digital estate register"` over user-facing files returns only historical documents (`SPEC.md`, roadmap).

### 5.7 Tests + CI
GitHub Actions, macOS + Ubuntu runners:
- Round-trip: encrypt → split → combine (each of the three 2-share pairs) → decrypt → byte-identical.
- Failure modes: one share fails; mistyped share yields non-matching secret; passphrase mismatch caught by `setup` step 5.
- Validators: good example passes both tiers; malformed fixtures fail with the expected errors; tier-agreement fixture test (3.3).
- `.gitignore` regression: planted `estate.yaml`/`*.age` invisible to git.
- Shell lint (`shellcheck`) on all scripts.

## 6. v0.3 — Executor usability (~1 sprint)

1. **`scripts/render.sh`** — from decrypted YAML, emit a printable Markdown triage report grouped by priority then preferred_action: do-first (critical/crypto/business continuity), liabilities bleeding money (sorted by billing cycle where stated), liquidations, cancellations, transfers, notify-only. YAML stays the source of truth; the report is the interface. Render is owner/helper tooling — it may use the Python tier; the executor can always read the raw YAML without it.
2. **Two-layer executor page** (`templates/EXECUTOR-INSTRUCTIONS.md` restructure). Page one, human: you don't have to do everything today; find the will; confirm your legal authority; contact any two shareholders; this file does not replace the will or legal advice. Page two, technical: exact commands, what success looks like, what failure looks like (including the silent-gibberish mistyped-share mode), and the **SHA-256 of the `.age` file** (stamped by `setup`) so the executor can confirm an uncorrupted copy.
3. **A tested Windows recovery path.** Research task with a hard acceptance bar: executed on a real Windows machine and documented step-by-step. `age` has official Windows binaries; `ssss` is the open problem (evaluate: native port, Cygwin/MSYS build, or a documented, verified WSL flow as last resort). "Use WSL" untested is not a path.
4. **Print-ready share sheets** — `setup` emits one cover page per holder: owner, share number, purpose, who may request it, when to release, "one share alone is useless", "never photograph or email this", `.age` checksum, date of last successful dry run.
5. **`scripts/rotate-shares.sh`** — new passphrase, re-encrypt, re-split, checklist for redistributing and destroying old shares. For holder death, estrangement, loss, or suspected compromise. Documents that old shares open the *old* ciphertext — destroy old `.age` copies too.
6. **`scripts/test-recovery.sh` + logged fire drill** — simulates full recovery (shares in, plaintext out, byte-compare) and prints a dated "last successful test: ___ by ___" line the owner writes onto the printed executor page. The dry run is the real acceptance test; make it visible on the artefact.

## 7. v0.4 — Ecosystem and discovery (optional, as energy allows)

1. **`AGENTS.md` + `llms.txt`** — the AI-assisted authoring contract: interview flow by asset category; hard guardrails (never ask for or record passwords, seeds, full account numbers; refuse and redirect if pasted); AI produces YAML only, which must pass `validate`; the human always runs `setup`. The validator is the enforcement layer behind any LLM.
2. **`docs/discovery-checklist.md`** — banks, pensions, insurance, utilities, domains, email, cloud storage, tax accounts, crypto, side businesses, loyalty points, recurring donations. Doubles as the AI interview question list.
3. **Password-manager export comparison** — local, read-only, generic CSV: report providers present in the manager but absent from the register. Names only, never credentials; delete the export after. Attacks staleness at its source.
4. **`.ics` review reminder** emitted by `review` — calendar nudge, no service dependency.
5. **Founder/operator example register** — domains, GitHub org, Stripe, hosting, registrar, support email.
6. **Open-source hygiene** — CONTRIBUTING.md; SECURITY.md with private vulnerability reporting; issue template warning ("never paste real identifiers, shares, or an estate file into a public issue"); tagged releases with checksums; GitHub topics (digital-legacy, age-encryption, shamir, self-hosted).

## 8. v1.0 acceptance test

> A non-technical person, on a Windows machine, using only the printed instructions and two shares, recovers and reads the triage report without help.

Run it as a real dry run with a real person. Until it passes, the project is not v1.0 regardless of feature count.

## 9. Explicitly rejected or parked (binding)

- **Public hosting of the encrypted register** — rejected: hands attackers an indefinite offline brute-force target and advertises the estate. Bit-rot is real; the fix is redundancy across *private* locations (two USB sticks in separate places + one private cloud copy, refreshed at each annual review).
- **GUI/Electron/Tauri app** — parked pending dry-run evidence that the guided CLI fails real non-technical users. The 80% fix first: numbered prompts, double-clickable wrappers (`.command` / `.bat`), official static `age` binaries.
- **age recipient-key mode as an alternative path** — parked: one recovery path executors can follow beats two they might mix up.
- **Bank-transaction CSV scanning** — parked: marginal over password-manager comparison, higher creep factor.
- **Provider email generation, APIs, death-certificate triggers, accounts, hosting, credential custody** — permanently out: they turn a durable record into a liability surface.

## 10. Sequencing and dependencies

1. §2 consolidation (needs Jamie: rename + archive) → everything else lands in one repo.
2. §3 two-tier validator and §5.3 schema v2 land together (validators encode the schema).
3. §5.1 `setup` depends on the batchpass-vs-expect verification; do that spike first — it is the only genuine unknown in v0.2.
4. §5.7 CI lands with v0.2, then gates every later phase.
5. v0.3 §6.3 Windows research can start any time; it gates v1.0, not v0.2.
