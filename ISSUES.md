# executor-file — Issue & Project Register

**This is the single source of truth for what is open in this repo.** One row per
issue/project. Detail lives in the linked doc; this file is the index the Mission
Control reconcile (`repo-reconcile.py`) reads and mirrors to the cockpit.

## ID convention (collision-safe)

Mission Control owns the bare `ISS-`/`PRJ-`/`T-` namespaces. **Every executor-file ID
carries the `EF-` prefix** so it can never collide with a Mission-Control-native
ID or another repo's. Raise issues here with `python3 ~/shared/scripts/repo-issue.py`.

---

## Open

| ID | Title | Status | Severity | Detail | MC-SYNC |
|----|-------|--------|----------|--------|---------|
| EF-ISS-4 | Editing the register in a terminal editor (nano) is a hard wall for non-technical owners: dry-run tester could not use nano, accidental ^V wrote junk, could not exit. This is the dry-run evidence the parked GUI/editing-interface decision (SPEC-v1 §9) was explicitly waiting for. Needs a humane edit path (GUI or form/web editor) before the tool is usable by its target audience. | Open | critical | — | pending |
| EF-ISS-3 | Onboarding requires holding instructions across multiple pages — violates the product's own 'you don't have to hold it in your head' principle; non-technical owners should be funnelled to executorfile.com/get-started, not raw GitHub | Open | high | — | pending |
| EF-ISS-2 | GitHub release page is a dead-end for non-technical users: no 'download this / do this next', assets collapsed under Assets, and competing with GitHub's auto Source-code downloads; install instructions are stranded back on the README (can't be recalled on the release page) | Open | high | — | pending |
| EF-ISS-1 | README quickstart assumes the repo is already on disk: no download/unpack/cd step for tarball users | Open | low | — | pending |

## Recently closed

| ID | Title | Status | Commit | Detail |
|----|-------|--------|--------|--------|
