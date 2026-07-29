# 1Password import — spec (EF-ISS-8)

**One line:** seed the register from the owner's 1Password vault — titles,
categories, and URLs only, never secrets — then triage in the browser editor,
either one item at a time (wizard) or all at once (bulk), before sealing.

Status: **P1 BUILT 2026-07-29** (pull + mapper + tests; findings in §11).
P2-P4 still spec. Written 2026-07-28. Owner: Jamie. Register row: EF-ISS-8.

---

## 1. Why this is worth building

The single most painful step in creating an Executor File is *remembering what
you own*. The discovery checklist exists because manual enumeration is slow and
leaky. But a 1Password user has already done the enumeration: every account
they can log into is an item in their vault. That item list IS the map the
register wants — and the register explicitly stores pointers
("1Password > HSBC"), never credentials, so the vault's *metadata* is exactly
the right raw material and its *secrets* are exactly what we must never touch.

Secondary win: 1Password is already load-bearing in this design (it holds the
owner's passphrase and the executor's emergency access route). Importing from
it deepens a dependency that already exists rather than adding a new one.

## 2. The hard security boundary (non-negotiable)

1. **Metadata only.** The importer may read item **title, category, URLs,
   vault name, and timestamps**. It must never request, read, store, or
   display a password, one-time code, or any concealed field. No `--reveal`,
   no field-level reads of concealed types, anywhere in the code. A CI grep
   test enforces the absence of these flags.
2. **CLI, never export.** Use the official `op` CLI (`op item list
   --format=json`). Never use 1Password's CSV/1PUX export — export writes
   secrets to disk, which is the exact leak pattern this repo's rules exist to
   prevent. The docs must say this out loud.
3. **Nothing written to disk** except what the owner accepts into
   `estate.yaml` (which is then handled by the existing plaintext rules:
   git-ignored, sealed, deleted). The raw `op` output is piped in memory,
   candidate lists live in the edit-server process and the browser tab, and
   both die with the session.
4. **Auth belongs to 1Password.** The CLI integrates with the desktop app;
   the first call triggers 1Password's own biometric/approval prompt. We never
   see or handle the vault password. If `op` is not installed or not signed
   in, the feature degrades to a clear message and the manual path — never a
   workaround.
5. **Validators are the backstop, not the control.** Both validator tiers
   already reject credential-shaped data before sealing. The importer must be
   correct anyway; the validators catch mistakes.
6. **Owner-side only.** This is optional owner tooling (Python + op are fine
   here). The executor recovery path gains no dependency and does not change.

## 3. Ergonomics — the design that makes it usable

### Entry point

One button in the browser editor: **"Pull from 1Password"**. It appears in
both create mode (`scripts/edit.sh`) and review mode (`scripts/review.sh`) —
first fill AND yearly top-up use the same muscle. No new script for the owner
to remember; the terminal-free journey stays terminal-free.

On click, the edit-server runs the pull. 1Password's own approval dialog
appears; the page says so ("Approve the request in 1Password — we read titles
and URLs only, never passwords"). Then the owner chooses a mode:

### Mode A — "One at a time" (wizard; the recommended default)

One decision per screen, nothing to hold in your head:

- A card shows: **title**, category badge, URL host, vault, and the
  pre-filled guess (type, priority, action). Three big actions:
  **Add** (accepts the guess, one tap; tweak the fields inline if wanted),
  **Skip**, **Stop here**.
- **Money first.** Candidates are sorted so bank accounts, credit cards, and
  crypto wallets come before generic logins, and generic logins before
  low-signal noise. The valuable decisions are front-loaded; quitting at item
  30 of 120 still captures most of the estate's weight.
- Progress is visible ("14 of 87 · 9 added · 5 skipped"), Skip is
  keyboard-reachable (n / a / s), and **Stop here** is honest: everything not
  reviewed is simply not added. No guilt state.
- Items the wizard adds are complete, validator-clean entries — the owner
  chose the action, so nothing sealed carries a placeholder.

### Mode B — "Add all as drafts" (bulk; for the impatient)

Everything importable lands in the asset list at once with pre-filled
guesses, each marked as imported in `action_notes`
("Imported from 1Password 2026-07-28 — confirm the action"). The owner edits
retrospectively in the normal editor.

- **Seal-time honesty gate:** the Seal button warns when imported defaults
  remain unconfirmed ("12 imported entries still carry a default action —
  seal anyway?"). It warns, it does not block: an imperfect sealed register
  beats a perfect unsealed one, but the owner decides knowingly.
- The existing review staleness flow then nags about these annually like
  everything else.

### Re-import at review time (the sleeper feature)

A year later, review.sh → "Pull from 1Password" again. Dedup (§5) means only
items **new since last time** are offered. The yearly review question stops
being "what did I forget?" and becomes "here are the 9 accounts you opened
this year — which matter?". This is where the feature pays rent forever.

### Noise handling

- **Vault picker first.** Before candidates are shown, the owner picks which
  vaults to pull (Personal yes; Shared/work vaults default off).
- Non-account categories (Secure Note, Identity, Password, Document, and
  similar) are excluded by default behind a "show everything" toggle.
- Archived items are excluded (confirmed: `op` excludes them by default, §9).

## 4. Mapping — 1Password category → register guess

| 1Password category | type | priority | default action |
|---|---|---|---|
| Bank Account | cash | high | notify-only |
| Credit Card | liability | high | notify-only |
| Crypto Wallet | crypto | high | preserve |
| Membership / Subscription-like | subscription | low | cancel |
| Email Account | other | high | preserve (email is the recovery hub) |
| Software Licence | other | low | cancel |
| Login (generic) | other | medium | notify-only |
| Secure Note / Identity / Password / Document | (excluded by default) | — | — |

Every field is a *guess presented for confirmation*, pre-filled never
auto-final in wizard mode. Other mapped fields:

- `provider` ← item title
- `access_pointer` ← `1Password > {title}` — the pointer style the design
  wants (and the exact example the editor already shows for this field).
  **Corrected in P1:** the first draft of this spec put the pointer in
  `identifier`, which is the field for a last-4 or a reference; the pointer
  belongs in `access_pointer`, and dedup (§5) is stronger there because the
  owner edits `identifier` (adding last-4 digits) and would break the key.
- `identifier` ← the URL host if the item has one, else the title. A
  searchable reference, never a number, never a path or query string.
- `priority` ← per the table; the schema's middle value is `normal`, not
  "medium". A finance heuristic hit (§9.5) raises it to `high`.
- `ownership` ← `sole` (the commonest case, and a required field — the
  wizard shows it for correction)
- `status` ← `active`; `last_confirmed` ← today (the owner is looking at it
  right now)
- `action_notes` ← wizard: owner-written or a sensible template; bulk: the
  imported-on marker (§3B)

Real category identifiers were pinned in the spike (§9): category is a hint,
not the engine — see the finance-heuristic ranking consequence there.

## 5. Dedup contract

- Match key: normalised `access_pointer` equal to `1Password > {title}`
  (case-insensitive, whitespace-collapsed). Already-present matches are
  filtered out of the candidate list before either mode shows anything.
  The importer also matches the key against existing `identifier` values,
  so registers written before this feature still dedup.
- Soft warning on near-misses: candidate title ≈ existing `provider`
  (exact match after normalisation) shows "possibly already listed as A007"
  instead of silently duplicating.
- **Title clashes (P1 finding, §11):** two vault items can carry the same
  title, and then they carry the same pointer — so next year's re-import
  would hide the second one. The mapper flags those candidates with
  `title_collisions: N`; the wizard (P2) must ask for something
  distinguishing in `identifier` (last 4 digits) rather than silently
  accepting twins. On a real vault this is not an edge case: 178 of 563.
- Dedup is what makes the review-time re-import (§3) work with zero extra
  machinery.

## 6. Architecture

Three small pieces, following the existing edit-server pattern:

1. **`scripts/import-1password.sh`** — the pull (BUILT). Checks `op` exists
   and is signed in, runs `op vault list --format=json` for the picker and
   `op item list --format=json` for the items, and pipes the result through
   the mapper to stdout. Nothing touches disk: the pull is held in memory,
   and a failed pull prints nothing rather than a truncated list. Exit
   codes carry the failure mode: 3 = op absent, 4 = no signed-in account,
   5 = the pull was refused, 6 = python3 missing.
   **`scripts/map-1password.py`** — the mapping (BUILT), split out because
   it is pure: JSON in, JSON out, no `op`, no network, so the whole mapping
   contract is testable from a fixture. It reads exactly five fields per
   item (title, category, urls, vault, updated_at) and drops the rest,
   including `additional_information`.
   The **candidate JSON** it emits:
   `{source, pulled, vaults:[{name, items}], counts:{items, candidates,
   shown_by_default, hidden, deduped, other_vaults}, candidates:[{title,
   category, url_host, vault, updated, rank, default_include,
   possible_duplicate_of?, title_collisions?, suggested:{provider, type,
   identifier, priority, ownership, status, last_confirmed,
   preferred_action, action_notes, access_pointer}}]}`.
   `rank` is the money-first ordering (0-3 accounts, 4-5 non-accounts) and
   `default_include` is the "show everything" toggle — non-accounts are
   emitted, not withheld, so the toggle needs no second pull.
   The manager-agnostic shape is deliberate: a future Bitwarden importer
   (`bw list items`) plugs in behind the same contract (parked, not built).
2. **`web/edit-server.py`** — one new endpoint, `GET /import/1password`
   (create and review modes): runs the script, subtracts dedup matches
   against the currently loaded register, returns candidates as JSON.
   Localhost-only like everything else; nothing cached, nothing written.
3. **`web/editor.html`** — the button, the vault picker, the mode chooser,
   the wizard cards, and bulk insertion into the existing asset-card list.
   No new persistence; accepted candidates become ordinary editor entries
   that flow through the existing Save → validate → Seal path untouched.

Failure modes, each with a plain-English message and no fallback trickery:
`op` not installed (say `brew install 1password-cli`, link the guide) · not
signed in / app integration off (point at 1Password settings) · approval
denied (say so, offer retry) · zero candidates after dedup ("nothing new
since last pull") · huge vaults (candidates render lazily; sorting §3 makes
the tail skippable).

## 7. Build phases

- **P0 — empirical spike. DONE 2026-07-29, findings in §9.**
- **P1 — pull + mapping. DONE 2026-07-29**, findings in §11.
  `import-1password.sh` + `map-1password.py`, candidate JSON contract,
  stub-`op` fixture, 38 tests. Drops `additional_information`, adds the
  finance-heuristic ranker (§9). The §2.1 grep guard landed here rather
  than in P4: a boundary is worth more from the moment the code exists.
- **P2 — editor integration.** Endpoint, vault picker, both modes, the
  wizard filter box (§9), seal-time honesty gate. Deterministic test via the
  existing edit-server harness with the stub `op` on PATH.
- **P3 — review-time re-import.** Same button in review mode, dedup against
  the decrypted register, "new since last pull" framing.
- **P4 — docs.** README + site get-started ("have 1Password? two minutes
  instead of twenty"), SECURITY.md boundary note (§2), AGENTS.md line, and
  the 1Password 8 + CLI-integration prerequisite (§9.7). The CI grep guard
  it used to own shipped with P1. Docs must state the boundary in plain
  English **without quoting the forbidden flags** — the guard is a literal
  grep, and it should stay dumb enough that nothing can talk it round.

Rough size: comparable to the browser-seal build (EF-ISS-7) — a day of
sessions.

## 8. Acceptance

1. From a signed-in 1Password Mac: click Pull → approve in 1Password →
   wizard through N real items → Save → Seal. The sealed register validates
   on both tiers and contains zero credential-shaped data.
2. `grep -r` proves no concealed-field access patterns in the codebase (CI).
3. Re-running Pull immediately offers zero candidates (dedup total).
4. With `op` absent, the editor's button explains and the manual path is
   unharmed; the full existing suite still passes untouched.
5. The executor recovery path is byte-for-byte unaffected.

## 9. P0 spike findings (2026-07-29, real vault, op 2.35.0, 1Password 8)

Run against Jamie's live vault (563 items, one Personal vault). Empirical
facts that now bind the design:

1. **Metadata-only confirmed.** `op item list --format=json` returns exactly:
   `id, title, category, urls (href/label/primary), vault, tags, favorite,
   version, created_at, updated_at, last_edited_by, additional_information`.
   **No `fields`, no `sections`, no concealed data** anywhere in list output.
   The §2 boundary holds without any filtering effort.
2. **BUT `additional_information` carries username/email hints** (present on
   552/563 items, 398 contain `@`). We do not need it; the importer must
   **drop it at the mapping stage** — data minimisation, it never enters the
   candidate JSON.
3. **Archived items are excluded by default** (563 vs 572 with
   `--include-archive`). Matches the spec; no flag needed.
4. **The category table (§4) barely applies to a real vault.** Jamie's
   categories: LOGIN 532 (94%), SECURE_NOTE 20, CREDIT_CARD 7, IDENTITY 3,
   API_CREDENTIAL 1. **Zero** Bank Account, Crypto Wallet, or Membership
   items — real users file everything as a Login. Category mapping is
   therefore a minor assist, not the engine.
5. **Ranking signals are thin:** favourites 2, tags 5, URLs on only 277/563.
   So the "money first" sort (§3) must come from a **built-in finance
   heuristic**: a small list of bank/finance/crypto domain fragments and
   title keywords (hsbc, barclays, amex, vanguard, coinbase, paypal, pension,
   bank…), with `updated_at` recency as tiebreaker. CREDIT_CARD items rank
   first outright.
6. **Scale check: 563 candidates.** Even fast triage is 30-45 minutes. This
   validates wizard essentials: front-loaded ranking, visible progress,
   **Stop here** with no guilt state — plus one addition: a **search/filter
   box** in the wizard so the owner can pull forward what they know matters
   ("hsbc", "aviva") before grinding the tail.
7. **App-version requirement is real:** 1Password 7 has no CLI integration
   (hit live — Jamie was on EOL v7 and upgraded). Docs must state: 1Password
   8+ desktop app with "Integrate with 1Password CLI" enabled, plus a
   1Password.com account (standalone vaults are unreachable by the CLI).

Consequences folded into the build: P1's mapper drops
`additional_information`, adds the finance-heuristic ranker, and treats
category as a hint; P2's wizard gains the filter box.

## 10. Out of scope (explicit)

- Writing anything back to 1Password.
- Reading any secret, ever, including "just the username" if a field turns
  out concealed-typed.
- CSV/1PUX export import (rejected: secrets on disk).
- Other password managers (Bitwarden etc.) — the candidate JSON contract is
  designed for them, but none are built now.
- Windows-native `op` flows (owner tooling is macOS/Linux/WSL, as today).

## 11. P1 build findings (2026-07-29)

Built `scripts/import-1password.sh` + `scripts/map-1password.py`, a stub
`op` (`tests/stub-op/op`) with fixtures, and 38 tests. Suite: 146 pass, 0
fail. Verified twice against the real 563-item vault, not only fixtures —
which is where three defects surfaced that fixtures never would have:

1. **Substring keyword matching is too loose.** "Readwise" matched the
   finance hint "wise" and ranked as money. Fixed: hints match from a word
   boundary (so "hargreaveslansdown.com" still hits), and the short
   ambiguous ones (isa, ira, irs, tax, wise, visa, loan) must match whole
   words. Real-vault rank-1 count went 48 → 40.
2. **Non-accounts could outrank accounts.** A secure note called "Trader-7
   Coinbase API" scored a finance hit and sorted above real accounts while
   being hidden by default. Fixed: accounts occupy ranks 0-3, non-accounts
   4-5 — so the "show everything" toggle appends to the list instead of
   reshuffling it.
3. **Title clashes are common, not rare: 178 of 563 items share a title**
   with another item (the same messy vault behind T-284). They would share
   a pointer, so re-import would hide the twin. Mapper now emits
   `title_collisions`; P2's wizard must act on it (§5).

Also confirmed live: the not-signed-in and approval-timeout paths are real
and exit cleanly (the vault session expired mid-session and the wrapper
said so in plain English, printing nothing on stdout). Real-vault shape:
563 items → 540 shown by default, 23 hidden, 7 at rank 0, 40 at rank 1,
493 generic. That 493 is the tail the wizard's filter box (§9.6) exists
for, and the strongest argument for P2 taking ergonomics seriously.

Deviations from the spec as written, both deliberate and both above:
`access_pointer` carries the pointer instead of `identifier` (§4), and the
grep guard shipped in P1 instead of P4 (§7).
