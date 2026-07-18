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
| EF-ISS-7 | Sealing a NEW register still needs a Terminal command (scripts/setup.sh): creating and maintaining register content are now terminal-free (browser editor + review-in-browser), but the first encrypt+split+prove-chain step isn't. Last terminal wall for a non-technical owner — consider a guided seal (double-click launcher wrapping setup.sh) or an editor 'seal' action shelling out to age/ssss locally. | Open | medium | — | pending |
| EF-ISS-5 | Register editor + schema help is thin on jurisdiction for cross-border users: editor v1 has no domicile/residence fields (schema supports them), and the 'jurisdictions' help doesn't explain it means every place you hold assets, nor domicile vs residence, nor 'if UK/US/FR-style cross-border, see a specialist solicitor'. Real UAT case: UK citizen, NY resident on E-2, assets in UK/US/FR — user could not tell what to enter. | Open | medium | — | pending |
| EF-ISS-3 | Onboarding requires holding instructions across multiple pages — violates the product's own 'you don't have to hold it in your head' principle; non-technical owners should be funnelled to executorfile.com/get-started, not raw GitHub | Open | high | — | pending |
| EF-ISS-2 | GitHub release page is a dead-end for non-technical users: no 'download this / do this next', assets collapsed under Assets, and competing with GitHub's auto Source-code downloads; install instructions are stranded back on the README (can't be recalled on the release page) | Open | high | — | pending |

## Recently closed

| ID | Title | Status | Commit | Detail |
|----|-------|--------|--------|--------|
| EF-ISS-6 | Yearly-review (maintenance) still hits the terminal wall: browser editor only handles plaintext to Downloads, but the kept file is estate.yaml.age and must be re-encrypted with the SAME passphrase (shares stay valid) — review.sh still uses a terminal editor. Build 'review in the browser': review.sh decrypts to a temp file, opens it in a local-only editor that reads/writes that file directly, then re-encrypts+verifies+shreds. Also make the editor loader handle folded '>' block scalars so example-style/hand-authored files open too. | Done | 7ca3113, f769193 | review-in-browser (edit-server.py + editor server mode + review.sh browser default) and block-scalar loader shipped; yearly review no longer needs a terminal editor. |
| EF-ISS-4 | Editing the register in a terminal editor (nano) is a hard wall for non-technical owners: dry-run tester could not use nano, accidental ^V wrote junk, could not exit. This is the dry-run evidence the parked GUI/editing-interface decision (SPEC-v1 §9) was explicitly waiting for. Needs a humane edit path (GUI or form/web editor) before the tool is usable by its target audience. | Done | fcfabda, 7ca3113 | humane edit path shipped: browser form editor for creating (editor.html) and for maintaining (review-in-browser). The parked GUI decision (SPEC-v1 §9) is resolved. Remaining terminal step (sealing) tracked as EF-ISS-7. |
| EF-ISS-1 | README quickstart assumes the repo is already on disk: no download/unpack/cd step for tarball users | Done | 8887f5d | README 'Get the tool' section added: tarball download + unpack + cd, git clone alternative, terminal-opening, Homebrew fallback. |
