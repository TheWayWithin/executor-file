# Executor File v0.3 — goal prompt

Generated 17 Jul 2026 by /goal-prompt from `executor-file-v0.3-release-spec.md`.

**Suitability verdict:** good fit for goal-first — bounded repo, single CLI toolset,
spec pre-arbitrates its conflicts (§0) and lists binding rejections (§6). The two
human-gated acceptance items (Windows dry run, physical fire drill) are scoped as
"prepare the kit, leave the human step on the checklist"; the release tag waits for
them. Run on the strongest model available (Fable 5).

**How to run:** fresh Claude Code session inside
`/Users/jamiewatters/DevProjects/executor-file`, paste the block below after `/goal`.
Log wall-clock, cost, and interventions if comparing against a spec-first arm.

---

```
Read /Users/jamiewatters/DevProjects/executor-file/ideation/executor-file-v0.3-release-spec.md in full before touching anything — it is the single source of truth for this build, its §0 arbitrations and §6 rejections are binding, and nothing in it may be re-litigated or re-scoped. Your job is to ship v0.3 "Executor Release" of Executor File: the release that closes every gap between "works for its author" and the v1.0 acceptance test — a non-technical person on a trusted machine, using only the printed guide and two shares, recovering and safely handling the file without help. The stakes are real: every defect that survives this release surfaces during someone's bereavement, and this is the release that decides whether the tool is safe to recommend to real families. Excellent looks like this: a stressed, grieving, non-technical executor follows the printed page without a single wrong turn, and every script refuses — loudly and kindly — to let anyone do something unsafe.

You are working in /Users/jamiewatters/DevProjects/executor-file (a live git repo). Available: the existing scripts, schema, tests/run-tests.sh and fixtures, GitHub Actions CI (gh CLI is authenticated), age 1.3.1 with age-plugin-batchpass, ssss, expect, and a PyYAML+jsonschema venv you may recreate in the scratchpad for the strict tier. SPEC-v1.md and the repo CLAUDE.md give you history and hard rules — the executor recovery path stays stock age + ssss only, the real estate.yaml and any .age file must never be committed, and tool behaviour is verified by running it, never from memory. Go hunt for what you need: read the spec, the git history, and the existing tests; search the web for age Windows binaries and the real options for ssss on Windows before writing that doc.

Within the spec's WHAT, the HOW is entirely yours: report layout, share-sheet wording, the 256-word fallback dictionary, script structure, migration mechanics, test design. Make every one of those calls yourself and do not defer back to me. Follow the spec's own sequencing discipline: verify the threshold defect empirically before removing the flags, and fix P0 before building P1.

Before calling anything done, prove it: extend tests/run-tests.sh to cover every new script and every P0 regression, run the full suite under both mechanisms, render the triage report from both example registers and read it as an executor would, plant defects to confirm the validators and the new drift test catch them, grep-verify that every corrected claim is gone from every file, and push in reviewable commits — you have my explicit authorisation to commit and push to main for this build — confirming CI green on macOS and Ubuntu after each push. Leave a scripted test for everything that ships.

Deliverables land in the repo on main. The two acceptance items that need another human — the Windows dry run and the physical fire drill — are prepared as ready-to-run kits (step-by-step docs plus test-recovery.sh) and listed in a RELEASE-CHECKLIST.md as the only remaining gates; do not tag the release until they pass. Update the repo CLAUDE.md current-state section, and finish with one paragraph summarising what you built and every judgement call you made.

Goal: ship everything in the v0.3 release spec that can be completed alone at a desk, tested and CI-green on main, with the two human-gated acceptance items packaged and waiting. Work autonomously — do not ask me for anything until it is all done — and parallelise independent work across sub-agents where it helps.
```
