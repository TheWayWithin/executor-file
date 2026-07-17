# Executor File — v0.3 "Executor Release" Spec

**Status:** draft for build, 17 July 2026
**Input:** five independent reviews (scores 8.5–9.1; consensus: production-ready for technical owners, not yet for real executors)
**Release goal:** close every gap between "works for Jamie" and the v1.0 acceptance test — a non-technical person, on a trusted Windows or Mac machine, using only the printed guide and two shares, recovers, understands, and safely handles the file without help.
**Filter applied:** an improvement ships only if it serves the executor under stress, the owner's annual review, or the safety of the recovery chain. Everything else is rejected or parked below, with reasons.

---

## 0. Arbitrated conflicts (read first)

Three points where the reviews contradict each other or prior decisions:

**1. Share thresholds: one review says `-t/-n` is broken, another says promote it.** The detailed review found that `setup.sh`'s proof stage always reconstructs from exactly two shares (S1, S2), so a 3-of-5 configuration can never pass its own verification; the executor instructions are also hard-coded to 2-of-3. Another review suggested documenting 3-of-5 more prominently. **Ruling: verify the defect first in Claude Code; assuming it's as described, remove `-t` and `-n` entirely and lock the product to 2-of-3.** One deeply tested scheme beats configurable cryptography. Document 3-of-5 as a "fork it if you need it" note only. This is P0.

**2. The printed SHA-256: my own earlier roadmap got this wrong.** The checksum-on-the-executor-page idea creates a fragile obligation: every review re-encrypts, changes the hash, and silently invalidates the printed page — making a perfectly good file look corrupted to a stressed executor. And `age` is authenticated encryption; successful decryption already proves integrity. **Ruling: drop the printed checksum. Replace with a `.sha256` sidecar written next to every encrypted copy (its job is comparing copies, not gatekeeping recovery), and a new `verify-copies.sh` that checks all stored copies match. The printed page stops carrying anything that rots on routine review.**

**3. LLM-ready executor export: one review proposes it, another warns against exactly that.** The Gemini suggestion (compile the decrypted register into `llms.txt` so the executor can draft provider letters with an AI) collides with the safety guidance in the strongest review: instruct executors *not* to upload the decrypted register to consumer AI tools. **Ruling: park the executor-side export.** The renderer (below) solves the same problem without teaching grieving non-technical people to paste their full estate into a chatbot. Owner-side AI assistance (`AGENTS.md`) is different — it's the owner's own data, with guardrails — and stays in.

---

## 1. P0 — Defects and safety-critical doc fixes (ship before anything else)

1. **Fix or remove the threshold flags** per ruling above. Add a regression test: setup with any flags other than defaults must fail loudly, not silently mis-verify.
2. **Correct the "no secrets at rest" claim.** The system deliberately has secrets at rest (passphrase in the password manager, shares on paper). Replace with the accurate, still-strong promise: **"No account credentials in the register."** Sweep README, CLAUDE.md, and executor instructions for the old phrasing.
3. **Kill the "borrowed computer" advice.** Recovery exposes two shares, the reconstructed passphrase, and the full decrypted estate. Replace with: use a trusted computer belonging to the executor, solicitor, or another authorised person, preferably full-disk encrypted; never a public, workplace, hotel, or casually borrowed machine.
4. **Add post-recovery handling to the executor instructions:** where to keep the decrypted file, don't email it unencrypted, don't upload it to AI tools, how to share with a solicitor, close the terminal when done, remove working copies (with the honest caveat that deletion isn't erasure), and that possessing credentials does not license bypassing provider bereavement processes.
5. **Fix the secret-display ceremony in `setup.sh`.** Warn before displaying; prompt to disable screen recording/sharing; show one share at a time with confirm-and-clear between each; stop claiming `clear && history -c` erases anything (it doesn't touch scrollback, session recording, or the parent shell's history); tell the user to close the terminal window at the end.
6. **Fix `$EDITOR` handling** in the quickstart and `review.sh`: support `VISUAL`, tolerate values with arguments (`code --wait`), fall back to `nano` with a clear message when unset. The current single-token invocation breaks on the most common real-world configs.
7. **Honest entropy reporting.** The "8 words ≈ 120+ bits" comment is only true for large dictionaries. The script already counts eligible words — compute and print the actual figure ("14,382 eligible words ≈ 110 bits"), or drop the number.
8. **Hardcode a 256-word fallback dictionary** in `setup.sh`. The current fallback (30 random alphanumerics) is secure but hostile to a human writing it down, and minimal Debian/CI images lack `/usr/share/dict/words`.
9. **CI hygiene:** pin CI and any autonomous-agent runs to `EXECUTOR_FILE_MECH=batchpass` and non-interactive paths so `read -rs` and `expect` prompts can't hang pipelines.

## 2. P1 — The executor experience (the release's centrepiece)

1. **`render.sh` — the triage report.** From decrypted YAML, emit `executor-report.md` (and printable HTML) with plain-English sections: **Do first** (secure, don't yet dispose — see below), **Money bleeding out** (liabilities and subscriptions sorted by billing cycle and cost), **Assets to liquidate**, **To settle**, **To transfer** (with beneficiary), **To cancel/delete/notify**, plus **Stale or unconfirmed entries** and **Incomplete legacy tools** so gaps are visible. Dependency-aware: "Retrieve A006 (safe deposit box) before attempting A004 (hardware wallet)." YAML stays the source of truth; the report is the interface.
2. **Fix the triage doctrine itself.** Replace "crypto first, subscriptions second, banks third" with *preserve before dispose*: secure devices, recovery material, renewing domains, hosting, and payment processing first; understand legal authority and tax treatment before moving anything. `first_step` (schema, below) carries this per-asset.
3. **Two-page printed guide.** Page one entirely human: you don't have to finish today; confirm your authority; locate the will; protect the encrypted file; contact any two shareholders; use a trusted computer; this file guides, it doesn't override the will. Page two: the technical procedure, what success looks like, and what to do when a command fails. Generate it filled from `meta` rather than hand-editing placeholders; validator warns on leftover `[BRACKETS]`.
4. **Tested Windows recovery path.** Executed on a real Windows machine, mistakes observed and folded back into the instructions. Official `age` binaries exist; solving and documenting `ssss-combine` on Windows is the work. "Use WSL" remains only as the documented fallback it currently pretends not to be.
5. **`test-recovery.sh` — the fire drill.** Simulates full recovery using genuinely held physical shares (not in-memory setup values), reports success plainly, and records `last_recovery_test` / `tested_by` on the printed page — the "last successful test" line that gives a future executor confidence the process works.
6. **Print-ready share sheets.** Per-holder cover page: owner, share number, purpose, who may request it, when to release, "one share alone is useless," "never photograph or email this." Generated into a private temp dir, printed, removed — with an explicit warning about printer spool files.
7. **`rotate-shares.sh`.** New passphrase, re-encrypt, fresh share set, old shares dead. Handles: holder dies, estrangement, lost paper, suspected compromise, executor change. Referenced in `review.sh` comments today but missing; three reviews flagged it.

## 3. P2 — Owner ergonomics and staleness (the research-validated killer)

1. **`doctor.sh`.** Pre-flight: OS, `age`/`ssss` presence and versions, batchpass/expect mechanism, Python availability for strict tier, whether the working directory is inside a synced folder, whether `estate.yaml` is git-ignored, whether an encrypted output already exists.
2. **Review flow that actually fights staleness.** Before opening the editor: "12 active records; 4 not confirmed in 18+ months; 2 missing confirmation dates; 1 legacy tool unconfigured." After editing: "Did you verify all active entries today?" — yes updates all `last_confirmed`; no preserves individual dates and prints "file edited today, but 6 records remain stale." Global freshness and per-record freshness never conflated.
3. **`last_confirmed` required for `status: active`** (with `unknown` allowed as an explicit value). A missing freshness signal is itself a defect the validator should surface, not silence.
4. **`.ics` review reminder** emitted at the end of every `review.sh` run: six-month quick check, annual full review, annual fire drill. Calendar nudge, zero service dependency.
5. **Discovery checklist** (`docs/discovery-checklist.md`): banks, pensions, workplace benefits, investments, insurance, mortgages/loans, tax accounts, utilities, subscriptions, domains, hosting, SaaS, app stores, email, cloud storage, GitHub, payment processors, crypto, loyalty balances, physical storage, IP, overseas assets. Doubles as the `AGENTS.md` interview list.
6. **`AGENTS.md`** — owner-side AI authoring contract: interview by category, hard refusals (never ask for or record passwords, seeds, full account numbers; redirect if pasted), AI emits YAML only, everything passes `validate` before encryption, the human alone runs encrypt and split.

## 4. P3 — Schema v3 (capped: six field changes, two new sections)

Accepted because each one either powers the renderer or fixes a factual modelling gap. Everything else proposed across five reviews is rejected below.

**Per-record fields:**
1. `preferred_action` enum gains **`settle`** (debts — the Amex example currently mislabelled `notify-only` proves the gap) and **`preserve`** (data, creative work, running businesses).
2. **`first_step`** (optional, free text): what to do *now*, decoupled from the eventual disposition. "Secure the device and recovery material. Do not transfer yet." Chosen over `urgency`/`legal_stage` enums — one honest sentence beats modelling probate law.
3. **`depends_on`** (optional, list of record IDs): structured version of what the examples already say in prose; powers dependency-aware rendering.
4. **`beneficiary`** (optional): recipient of `transfer` actions, out of `action_notes` and into a sortable field.
5. **`billing_cycle`** (`monthly | annual | one-off`, optional, for liabilities/subscriptions): lets the renderer sort by burn rate.
6. **`meta.jurisdictions`** becomes an array (with optional `domicile` / `residence`), replacing the primary/secondary pair that can't model NY + UK + an online business incorporated elsewhere.

**New top-level sections:**
7. **`contacts`** — solicitor, accountant, adviser, business partner, technically trusted helper: role, name, pointer, note ("holds original will"). Pointers, not sensitive contents.
8. **`documents`** — will, deeds, insurance schedules, statements: name + location. Discovery, not probate automation.

**Migration:** `format_version: 3`, with a migration note and a `validate.py` upgrade path from v2 (additive fields, one meta rename). Renderer and validator understand both for one version.

**Schema drift (Gemini's closing question):** single source of truth becomes `estate.schema.json`; the annotated YAML schema is documentation. A CI drift test validates both example registers against the JSON Schema and diffs the field inventory between the two schema files — failing the build on divergence. No hand-maintained duplicates.

## 5. P4 — Project hygiene

1. **SECURITY.md:** private vulnerability reporting, supported versions, threat boundaries, "no maintainer can recover a lost passphrase," never paste estate data into issues.
2. **Issue templates** opening with the never-paste warning (register, shares, passphrase, identifiers, screenshots of any of them).
3. **CONTRIBUTING.md:** the invariants (no dependencies in the executor recovery path, no credentials in the register, validate-before-encrypt), test expectations, schema migration rules, and the requirement that doc changes be tested on a human.
4. **Tagged releases:** version, schema version, platforms tested, `age`/`ssss` versions tested, checksums, migration notes.
5. **Document the local-machine trust boundary:** in-memory passphrase handling assumes an uncompromised OS and user account; env-var passing to child processes is visible to same-user processes. State it rather than implying memory-only handling defeats local compromise.

## 6. Rejected or parked (and why)

- **Executor-side `llms.txt` export** — parked per arbitration §0.3; contradicts the "don't upload the register to AI tools" safety line.
- **`urgency` + `legal_stage` enums** — rejected; `first_step` covers the need without modelling probate.
- **`provider_bereavement_url` (+ `checked` date)** — rejected; URLs decay and add a maintenance obligation to every entry. The renderer can say "search '<provider> bereavement'".
- **`currency`, `monthly_cost`, `confidence` fields** — rejected; `approx_value` + `billing_cycle` + `last_confirmed` carry the load. Schema stays fillable in an afternoon.
- **Three-way pointer split (`access`/`document`/`physical`)** — rejected at record level; the `documents` section absorbs the real need, `access_pointer` stays one field.
- **Password-manager export comparison** — stays v0.4. Highest-value staleness feature after this release, but this release is already the largest the project has shipped.
- **Video walkthrough, Homebrew tap, Docker helper, offline binary recovery kit** — parked; revisit after the Windows dry run shows what executors actually stumble on.
- **GUI of any kind** — still parked pending dry-run evidence the guided CLI fails real people. Standing decision holds.
- **Solicitor packet** — parked; the render report shared appropriately covers 90% of it.

## 7. Release acceptance criteria

- [ ] Threshold defect confirmed, flags removed, regression test in place.
- [ ] All five P0 doc/safety fixes merged; old claims absent from every file (grep-verified).
- [ ] `render.sh` produces the triage report from both example registers; dependency lines correct.
- [ ] Fire drill run with real printed shares; date recorded on the printed page.
- [ ] Share rotation executed end-to-end once; old shares verified dead.
- [ ] Windows recovery completed by someone who is not Jamie, on a real Windows machine, from the printed instructions alone; observed failures folded back into the docs.
- [ ] Schema v3 examples validate on both tiers; CI drift test green; v2→v3 migration documented and tested.
- [ ] SECURITY.md, CONTRIBUTING.md, issue templates, first tagged release published.

The Windows dry run is the release gate. Everything else can be done alone at a desk; that one requires another human and a borrowed hour, and it is the single item that moves the tool from "excellent for its author" to "safe to recommend."
