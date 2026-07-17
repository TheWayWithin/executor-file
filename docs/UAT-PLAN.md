# UAT plan — v0.3 "Executor Release"

Two tracks. Track 1 is Jamie as a real owner (his actual register — this
produces Gate 2, the fire drill). Track 2 is recruited testers as
executors (**example register only, always** — this produces Gate 1, the
Windows dry run). Both gates live in RELEASE-CHECKLIST.md; the v0.3.0 tag
waits for them.

**The iron rule for tester sessions:** testers only ever touch the
example register and shares generated from it. Jamie's real shares and
real `.age` file never enter a tester session. The real fire drill is
Jamie plus (optionally) one of his actual share holders.

---

## Track 1 — owner dogfood (Jamie, real register)

Four sessions. Each is self-contained; stop between them freely. Log
every stumble, wording confusion, or surprise as a repo issue the moment
it happens — a stumble by the author predicts a wall for everyone else.

### Session A — build the real register (60–90 min, deep-work block)
1. `scripts/doctor.sh` — fix anything it flags before starting.
2. `cp examples/estate.example.yaml estate.yaml` (repo root — it is
   git-ignored; machine must be FileVault-encrypted, folder not synced).
3. Work through `docs/discovery-checklist.md` category by category.
   Don't chase completeness — capture what you know, mark the rest
   `last_confirmed: unknown`. 80% today beats 100% never.
4. Fill `contacts` (including three `share-holder` roles — see the
   decision below) and `documents` (will location, plus two
   "Executor File copy" entries for where the .age copies will live).
5. `scripts/validate.sh --strict` until clean.

**Decision needed during A:** the three share holders. Criteria: unlikely
to collude improperly, likely to outlive you or be replaceable, reachable
by your executor, capable of keeping one sheet of paper for years.
Classic trio: spouse/partner, sibling or close friend, solicitor.

### Session B — seal and print (45–60 min)
1. `scripts/setup.sh` — full ceremony, hand-copy the three shares (or
   `scripts/share-sheets.sh` on the home printer).
2. Passphrase into the password manager as "Executor File passphrase".
3. `scripts/make-guide.sh` — print both pages; also print
   `docs/WINDOWS-RECOVERY.md`.
4. Store `estate.yaml.age` + `.sha256` in the two documented locations;
   `scripts/verify-copies.sh` across them.
5. Delete the plaintext per the closing checklist; close the terminal.

### Session C — distribute (elapsed days, not desk time)
Hand each share to its holder in person with the one-minute explanation
(the share sheet carries it). Store the printed guide with the will.

### Session D — **Gate 2: the fire drill** (30 min)
`scripts/test-recovery.sh` with two genuinely printed shares — at least
one physically fetched back from its holder (or read out on a call).
Then re-run `make-guide.sh`, re-print, re-store. Tick Gate 2 in
RELEASE-CHECKLIST.md.

---

## Track 2 — executor dry runs (recruited testers, example register)

### Tester profile
Non-technical adults who have never seen this project: comfortable using
a computer for email and documents, would not call themselves "good with
computers", and ideally in the age range of a plausible executor. Two or
three people. Do NOT brief them beyond the recruiting script — priming
invalidates the test.

### Recruiting script (verbatim is fine)
> "I've built a tool that helps families find someone's accounts and
> assets after they die. Before I recommend it to anyone real, I need to
> watch a normal person follow the printed instructions with no help
> from me. It takes about an hour, nothing you do can break anything,
> and you'd be doing me a genuine favour — dinner's on me. Interested?"

### Session kit (prepare fresh per tester, from the EXAMPLE register)
1. On any machine: `cp examples/estate.example.yaml estate.yaml &&
   scripts/setup.sh` — hand-copy the three shares onto paper (part of
   the drill: testers must read real handwriting).
2. Copy `estate.yaml.age` to a USB stick. Delete local plaintext + .age.
3. Print: the filled guide (`scripts/make-guide.sh` on the example) and,
   for Windows sessions, `docs/WINDOWS-RECOVERY.md`.
4. Hand the tester: USB stick, TWO of the three paper shares, the
   printed pages. Nothing else.

### Session order
- **Dry run M (Mac, 1 tester, ~45 min)** — cheap rehearsal of the docs
  and the observation protocol before spending the Windows hour.
  Not a formal gate; catches wording problems early.
- **Dry run W (Windows 10/11, 1–2 testers) — Gate 1, THE release gate.**
  Real Windows machine with admin rights (WSL needs admin + a restart —
  the tester's own laptop is ideal and matches reality; note Jamie owns
  no Windows machine, so the tester's machine or a borrowed one must be
  arranged when recruiting).

### Observation protocol (both dry runs)
- Sit behind, watch silently, and keep a timestamped log: every
  hesitation over ~15s, every re-read, every mistype, every wrong turn,
  every look-to-you-for-help.
- Do not help. If they are truly stuck (>5 min, visibly frustrated),
  note WHERE and WHY — that is a documentation failure and the session's
  most valuable data — then unblock them and continue.
- Success = they are reading `estate.yaml` in a text editor unaided.
- Debrief (5 min): where did you feel least sure? what did you almost do
  wrong? what word or step made no sense? would you trust this if it
  were real?
- Afterwards: file each stumble as a repo issue; fold fixes into the
  docs; if changes were substantive, run one more tester on the revised
  docs.

### Session hygiene
Testers use example data only; wipe the USB stick afterwards; shares
from tester kits are torn up at session end (they open only the example
register, but tidy habits are the product).

---

## Results capture
- Stumbles → repo issues (one per stumble, tagged `uat`).
- Session summaries → append to this file under a "Results" heading
  (date, tester profile — no names needed, outcome, top 3 stumbles).
- Gates ticked → RELEASE-CHECKLIST.md → tag v0.3.0.

## Sequence and effort
A (90m, solo, anytime) → B (60m, solo) → C (days, ambient) → M (45m + a
tester) → W (60–90m + tester + Windows machine) → D (30m) → tag.
A–B can happen this week with no dependencies. Recruiting for M/W can
start immediately — the kit takes 15 minutes to prepare on session day.
