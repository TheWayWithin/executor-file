# Contributing

Small project, hard rules. Everything here exists because a defect in
this tool surfaces during someone's bereavement.

## Invariants — a PR that breaks one is rejected regardless of merit

1. **The executor recovery path is stock `age` + `ssss` only.** No
   repo scripts, no Python, no wrappers, no reimplementations of
   either tool. The printed page must keep working if this repo
   vanishes. Owner-side tooling may have optional dependencies;
   executor-side may not.
2. **No account credentials in the register — ever.** The schema holds
   pointers; the validators reject credential-shaped data. Nothing may
   weaken that scan (the contacts phone-number allowance is the one
   deliberate, documented exception).
3. **Validate before encrypt.** Every path that seals a register runs
   the baseline validator first, and the baseline tier (POSIX sh +
   awk) must never require Python.
4. **The share scheme is fixed at 2-of-3.** The proof stage, tests,
   and printed guide are built around it. Configurable cryptography
   shipped a real defect once; it does not come back.
5. **`estate.yaml` and `*.age` are never committed.** The gitignore
   test enforces it; keep it green.
6. **Honesty over comfort in every user-facing string.** No claiming
   deletion erases, no claiming `clear` wipes history, no security
   theatre. If a promise cannot be kept mechanically, the docs say so.

## Tests

- `tests/run-tests.sh` must pass under **both** mechanisms:
  `EXECUTOR_FILE_MECH=batchpass` and `EXECUTOR_FILE_MECH=expect`.
- Every new script ships with tests in the same PR — including at
  least one failure-mode test (what happens on wrong input is the
  product here).
- `shellcheck -S warning scripts/*.sh tests/run-tests.sh` stays clean.
- Validator changes need fixture coverage in `tests/fixtures/` for
  both tiers, and the tiers must agree on pass/fail for every fixture
  (the suite asserts it).

## Schema changes

- `schema/estate.schema.json` is the single source of truth;
  `schema/estate.schema.yaml` is its annotated documentation.
  `tests/schema-agreement.py` fails CI if they diverge — update both,
  never one.
- Any breaking change bumps `format_version`, and both validators must
  accept the previous format for one version with a precise,
  copy-paste-able migrate message. Additive fields need: both schema
  files, both validators, the example registers, the renderer, and
  fixtures.
- Schema growth is rationed deliberately (see the v0.3 spec's
  rejected list): a field ships only if it serves the executor under
  stress, the annual review, or the safety of the recovery chain.

## Documentation changes

Docs that face the executor (`templates/`, `docs/WINDOWS-RECOVERY.md`,
anything render.sh or make-guide.sh emits) must be **tested on a
human**: someone who did not write the text follows it, and observed
stumbles get folded back in. Say in the PR who read it and what they
tripped on. Wording changes are product changes here.

## Never paste estate data

Not in issues, PRs, commit messages, or test fixtures: no real
register contents, shares, passphrases, or screenshots of them.
Reproduce everything with `examples/` data.
