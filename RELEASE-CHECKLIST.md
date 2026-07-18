# v0.3 "Executor Release" — release checklist

**Status update 2026-07-18:** `v0.3.0` was tagged and released AHEAD of
the two human gates, by deliberate owner decision — pre-launch, zero
traffic, and live end-to-end testing of the full pipeline (repo → tag →
site download) is easier against the real release. The release notes
state plainly which verification is machine-proven and which is
pending. **The two gates below are unchanged in substance and remain
open as post-release validation** — they now block the "safe to
recommend to real families" claim and v0.3.1, not the tag. Findings
fold into v0.3.1.

## Gate 1 — the Windows dry run (THE release gate)

Someone who is **not Jamie**, on a **real Windows 10/11 machine**,
recovers the example register from the printed instructions alone.

Ready-to-run kit:

1. Prepare on any machine with the repo:
   `cp examples/estate.example.yaml estate.yaml && scripts/setup.sh`
   — hand-copy the three shares onto paper as instructed (this is part
   of the drill), and copy `estate.yaml.age` onto a USB stick.
   Delete the local `estate.yaml*` afterwards.
2. Print `docs/WINDOWS-RECOVERY.md` and the filled guide from
   `scripts/make-guide.sh` (pages one and two).
3. Hand the tester: the USB stick, two of the three paper shares, the
   two printed documents. **Nothing else — no verbal help.** Watch
   silently and take notes on every hesitation, retype, and wrong turn.
4. Success = they are reading `estate.yaml` in Notepad unaided.
5. Fold every stumble back into `docs/WINDOWS-RECOVERY.md` /
   `templates/EXECUTOR-INSTRUCTIONS.md`, commit, and if the changes
   were substantive, run the dry run again with a fresh tester.

- [ ] Windows dry run passed by a non-author on a real machine
- [ ] Observed failures folded back into the docs

## Gate 2 — the physical fire drill

With the **real** register (not the example): run
`scripts/test-recovery.sh` using two genuinely held, physically
printed shares — at least one fetched back from its actual holder.
The script records the date and tester in `recovery-tests.log`;
re-run `scripts/make-guide.sh` and re-print so the guide carries the
"Last successful recovery test" line.

- [ ] Fire drill passed with real printed shares
- [ ] Date + tester recorded and visible on the re-printed guide

## Tagged (2026-07-18)

`v0.3.0` is live: https://github.com/TheWayWithin/executor-file/releases/tag/v0.3.0
— tarball + `.sha256` attached, release notes honest about the pending
gates. When both gates pass: fold findings into the docs, release
v0.3.1 with "Windows 10/11 (manual dry run — date)" added to platforms
tested, and update the site.

---

## Already verified (by CI and scripted tests on main)

- [x] Threshold defect confirmed empirically; `-t`/`-n` removed; regression tests refuse them loudly
- [x] All P0 safety/honesty fixes merged; grep sweep in the test suite keeps the corrected claims gone
- [x] `render.sh` produces the triage report from both example registers; dependency lines verified
- [x] Share rotation executed end-to-end in the suite; old shares proven dead against the rotated file
- [x] Schema v3 validates on both tiers; CI drift test green (and proven against planted defects); v2→v3 path documented and tested
- [x] SECURITY.md, CONTRIBUTING.md, issue templates in place
