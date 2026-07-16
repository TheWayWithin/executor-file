# Digital Estate Register — Roadmap to v1.0

**Status:** draft v0.1, synthesized from four independent reviews (16 July 2026)
**Decision rule applied:** the Claude Code review is weighted highest on factual findings because it alone read and executed the code. The others are weighted on design judgement.

---

## 0. Fix immediately, before any feature work

These came from the only review with filesystem access. They are defects, not improvements.

1. **Plaintext `estate.yaml` is sitting in the digital-estate working tree.** Git-ignored, but plaintext at rest contradicts the design. Encrypt or remove it today.
2. **`encrypt.sh` silently overwrites an existing `.age` file and does not validate first.** The goal repo does both correctly. Fix before anyone else uses it.
3. **Merge the repos rather than choosing.** Base v2 on digital-estate-goal's structure (schema-driven validator, better executor doc, validate-before-encrypt) with digital-estate's zero-dependency stance. The goal repo's Python validator failed on a stock Mac for lack of PyYAML; a tool whose pitch is "works forever, no dependencies" cannot fail that way. Keep one repo going forward; archive the other with a pointer.

## 1. Arbitration: where the reviews disagreed

**Shell vs Python.** Resolved as two-tier. A pure-POSIX validator (the existing awk one) is the guaranteed baseline that runs on any machine forever. A fuller Python validator (real JSON Schema conformance, duplicate IDs, staleness, coverage checks) is optional and clearly labelled as such. Never let the Python path be the only path.

**Public cloud storage of the encrypted file.** One review recommended a public GitHub Gist or public cloud link to beat USB bit-rot. **Rejected.** The bit-rot concern is right; the fix is wrong. Publishing the ciphertext hands every future attacker an indefinite offline brute-force target and advertises that the estate exists. Passphrase entropy is user-chosen and therefore not guaranteed. Correct mitigation: redundancy across private locations — two USB sticks in separate places plus one private cloud copy (iCloud/Drive), refreshed at each annual review. Same durability, no public attack surface.

**GUI application.** Two reviews want a cross-platform GUI or Electron/Tauri app. **Deferred.** The 80% fix is cheaper: a guided CLI with numbered prompts, double-clickable wrapper files (`.command` on macOS, `.bat` on Windows), and pointing executors at the official static `age` binaries. A GUI is a maintenance surface that contradicts "a file, not an app". Revisit only if dry-runs with real non-technical people fail on the guided CLI.

**Share scheme.** Keep 2-of-3 as the default. Document 3-of-5 as an option for larger estates, and add the geographic/social separation guidance (don't give two shares to people in the same house). Don't make the default more complex.

**Schema growth.** The reviews collectively propose ~15 new fields. Accept the load-bearing ones (below), reject the rest for now. A schema that tries to model probate law stops being fillable in an afternoon, and "fillable in an afternoon" is the adoption constraint.

## 2. v0.2 — Reliability (do first, ~1 sprint)

The single highest-impact item, named by all four reviews in different words:

1. **One orchestrated `setup` command** that closes the passphrase-mismatch hole: validate → take passphrase once (never written to disk) → encrypt → split that same in-memory passphrase → reconstruct from two shares → test-decrypt → byte-compare with the original → report success only if the full chain works. Today the user manually carries the secret between two scripts; a typo produces three valid shares that open nothing.
2. **One `review` command** for the maintenance loop: decrypt to a controlled temp dir → open `$EDITOR` → validate → bump `meta.updated` → re-encrypt → remove working plaintext. Staleness is the stated residual risk; a five-step manual loop guarantees it. One command makes annual reviews happen.
3. **Schema additions (only these):**
   - `priority: critical|high|normal|low` (replaces "HIGH PRIORITY" prose; renderers and executors sort on it)
   - `ownership: sole|joint|beneficiary-designated|trust|business-owned|unknown` (a joint account and a sole account cannot share a generic "liquidate")
   - `last_confirmed` per entry (per-item staleness, not just global `meta.updated`)
   - `status: active|closed` (closed accounts leave a trail instead of vanishing)
   - `format_version` in `meta` (without it, future schema changes make old encrypted registers ambiguous)
   - Rename `action` to `preferred_action` and add the legal disclaimer: actions are practical guidance subject to the will, beneficiary designations, ownership rights, provider rules, and applicable law. The YAML must never read as overriding the will.
4. **Plaintext-handling honesty.** Replace "the .age file is now the only copy" wording: `rm` does not securely erase on SSDs, synced folders, snapshots, or editor backups. Guidance: full-disk-encrypted machine, never create the plaintext inside a synced folder, use the `review` command's temp-dir flow.
5. **Ship a real JSON Schema** (`estate.schema.json`, valid draft with `$id`), so standard tools and LLMs can validate without the project's own scripts.
6. **Tests + CI:** round-trip encrypt/decrypt, 2-of-3 combinations, failure with one share, passphrase mismatch, validator against good and malformed examples, macOS + Ubuntu runners.

## 3. v0.3 — Executor usability (~1 sprint)

1. **`render` command:** from decrypted YAML, emit a printable Markdown/HTML triage report grouped by priority and action: do-first (crypto, business continuity), liabilities bleeding money (sorted by billing cycle), assets to liquidate, services to cancel, transfers. ~50 lines of script; transforms the executor's first 48 hours. The YAML stays the source of truth; the report is the interface.
2. **Two-layer executor page.** Page one is human: you don't have to do everything today; find the will; confirm legal authority; contact any two shareholders; this file does not replace the will or legal advice. Page two is the technical fallback: exact commands, what success looks like, what to do when a command fails, plus the SHA-256 of the `.age` file so the executor can confirm an uncorrupted copy.
3. **A tested Windows recovery path.** Written, executed on a real Windows machine, and documented. `age` has official Windows binaries; `ssss` is the sticking point to solve and document. "Use WSL" is not a tested path.
4. **Print-ready share sheets:** per-holder cover page generated by `setup` — owner, share number, purpose, who may request it, when to release, "one share alone is useless", "never photograph or email this", checksum, dry-run date.
5. **Share rotation:** `rotate-shares` command and documented procedure for holder death, estrangement, loss, or suspected compromise.
6. **Dry-run helper + logged fire drill:** a `test` command simulating full recovery, and a dated "last successful test: ___ by ___" line on the printed executor page. The dry run is the real acceptance test; make it visible on the artefact.

## 4. v0.4 — Ecosystem and discovery (optional, as energy allows)

1. **`AGENTS.md` + `llms.txt` in the repo.** The AI-assisted authoring contract: interview flow by asset category, hard guardrails (never ask for or record passwords, seeds, or full account numbers; refuse and redirect if pasted), and the rule that AI produces YAML only, which must pass `validate`; the human always runs encrypt and split. The validator becomes the enforcement layer behind any LLM. Cheap to write, and it makes "any Claude can help you build your register" true.
2. **Discovery checklist** (`docs/discovery-checklist.md`): banks, pensions, insurance, utilities, domains, email, cloud storage, tax accounts, crypto, side businesses, loyalty points, recurring donations. Doubles as the AI interview question list.
3. **Password-manager export comparison** (local, read-only, generic CSV): report providers present in the manager but absent from the register. Names only, never credentials, delete the export after. This attacks staleness at its source.
4. **`.ics` review reminder** emitted by `review` — a calendar nudge with no service dependency.
5. **Founder/operator example register:** domains, GitHub org, Stripe, hosting, registrar, support email — the profile the current schema holds but doesn't showcase.
6. **Open-source hygiene:** CONTRIBUTING.md, SECURITY.md with private vulnerability reporting, issue-template warning ("never paste real identifiers, shares, or an estate file into a public issue"), tagged releases with checksums, GitHub topics (digital-legacy, age-encryption, shamir, self-hosted).

## 5. Explicitly rejected or parked

- Public hosting of the encrypted register (rejected: offline attack surface)
- GUI/Electron app (parked pending dry-run evidence the guided CLI fails)
- age recipient-key mode as an alternative path (parked: one recovery path executors can follow beats two they might mix up)
- Bank-transaction CSV scanning (parked: marginal over password-manager comparison, higher creep factor)
- Provider email generation, APIs, death-certificate triggers, accounts, hosting, credential custody (permanently out: these turn a durable record into a liability surface)

## 6. Acceptance test for v1.0

A non-technical person, on a Windows machine, using only the printed instructions and two shares, recovers and reads the triage report without help. Until that passes, nothing else counts as mature.
