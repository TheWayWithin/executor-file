# Executor File

An encrypted, self-hosted file that lets your executor find every account, asset, and liability you own — and know exactly what you want done with each one — with **no credentials stored** and **no dependence on any service staying alive**.

It is a file, not an app. There is nothing to subscribe to, nothing to keep patched, and nothing here that can leak a password, because no password ever enters it.

Two artefacts carry everything:

- **Your Executor File** — the encrypted register (`estate.yaml.age`).
- **The Executor Instructions** — one printed page, stored with the will, that tells your executor how to open it.

## The promises this design keeps

A security-literate reader should be able to verify each of these directly from this repo:

1. **No account credentials in the register.** It stores *pointers* ("1Password > HSBC", "seed backup in deposit box …22") — never passwords, full account numbers, or seed phrases. The validators actively reject long digit runs and flag written-out credentials. (The system does deliberately hold two secrets *outside* the register: the passphrase in your password manager, and its shares on paper — that is the design, stated honestly, not an oversight.)
2. **No service dependency.** Encryption is [`age`](https://age-encryption.org) in passphrase mode; secret-splitting is [`ssss`](http://point-at-infinity.org/ssss/) (Shamir's Secret Sharing). Both are open-source, packaged everywhere, and operate on local files. If this repo and its author vanish, your Executor File still opens with two standard commands.
3. **No single point of compromise.** The passphrase is split 2-of-3: three people each hold one printed share. Any two reconstruct it; any one alone learns nothing (information-theoretically, not just computationally). While you are alive, no individual shareholder can open the record.
4. **No single point of failure.** One lost share, one dead shareholder, one lost backup of the `.age` file — none of them is fatal. The encrypted file is useless without two shares, so it can be backed up across private locations freely.
5. **Nothing private is committed.** [`.gitignore`](.gitignore) excludes `estate.yaml` and `*.age`. Only the schema, an example with dummy data, templates, and scripts belong in git.
6. **Validation with no dependencies.** The baseline validator is pure POSIX `sh` + `awk` — it runs on any Unix machine forever and is invoked automatically before anything is encrypted. A stricter Python tier is optional and clearly labelled; it is never the only path.

The scripts are thin, readable wrappers. Read them before trusting them; that is the point of them being short.

## How it works

```
estate.yaml  --setup.sh-->  estate.yaml.age  +  share1 / share2 / share3
                            (your Executor File)   (2-of-3, printed on paper)
```

On death, the executor reads the printed Executor Instructions, collects shares from two of the three holders, and runs three commands: install, `ssss-combine -t 2`, `age -d`. No account, no company, no login, no script of ours. The two-page walkthrough — written for a non-technical person under stress — is [`templates/EXECUTOR-INSTRUCTIONS.md`](templates/EXECUTOR-INSTRUCTIONS.md) (`scripts/make-guide.sh` fills it from your register); Windows recovery has [its own printed sheet](docs/WINDOWS-RECOVERY.md). After decrypting, [`scripts/render.sh`](scripts/render.sh) turns the register into a sorted, printable triage report — helpful, never required.

**Your own way back in is simpler:** the passphrase lives in your password manager, like every other credential you own. The shares exist so your *executor* can get in without you; they are not your access path. At review time you type the passphrase, not collect shares.

## Quickstart (you, the owner)

Requirements: `age` (≥ 1.3 recommended) and `ssss` — `brew install age ssss` on macOS, `sudo apt install age ssss` on Debian/Ubuntu.

```bash
# 0. Optional pre-flight: tools, versions, synced-folder hazards
scripts/doctor.sh

# 1. Start from an example and fill in your real assets
#    (examples/estate.minimal.yaml is the gentler starting point;
#     docs/discovery-checklist.md is the "what am I forgetting" list)
cp examples/estate.example.yaml estate.yaml
nano estate.yaml               # or your usual editor — estate.yaml is git-ignored

# 2. Check it — structure, allowed values, and the no-credentials rules
scripts/validate.sh

# 3. Seal it: validate → encrypt → split → PROVE the chain, one command.
#    It generates a strong passphrase, encrypts, splits the passphrase
#    2-of-3, then reconstructs it from two of the just-issued shares and
#    test-decrypts back to a byte-identical copy before reporting success.
scripts/setup.sh

# 4. Follow its printed checklist: hand-copy the shares (or print
#    per-holder cover sheets with scripts/share-sheets.sh), save the
#    passphrase in your password manager, and print the Executor
#    Instructions — scripts/make-guide.sh fills them from your register.

# 5. Prove the paper: the fire drill, with two printed shares
scripts/test-recovery.sh
```

For every future update, one command:

```bash
scripts/review.sh    # decrypt to a private temp dir → staleness summary →
                     # edit → validate → confirm freshness → re-encrypt with
                     # the SAME passphrase (shares stay valid) → verify →
                     # clean up + calendar nudges (.ics)
```

Changing the passphrase itself — holder died, share lost, suspected compromise, executor change — is `scripts/rotate-shares.sh`: new passphrase, fresh shares, and it proves the old passphrase dead before declaring success. `scripts/verify-copies.sh` confirms every stored copy of the `.age` file is the same, current one.

Then the physical part, which matters more than the software: put one printed share with each of three holders (e.g. executor, solicitor, family member) and tell them what it is; store `estate.yaml.age` in at least two private places; and set the platform legacy tools below.

Keep any self-chosen passphrase within 128 ASCII characters — `ssss` will not split more (generated ones fit comfortably). Changing the passphrase later is a deliberate act (new shares must be printed and redistributed, old `.age` copies destroyed) — that is a rotate, not a review.

## About the plaintext

Honesty over comfort: deleting `estate.yaml` **reduces exposure, it does not erase history**. `rm` does not scrub SSDs; synced folders, filesystem snapshots, and editor backups can all retain copies. So:

- Work on a machine with full-disk encryption (FileVault, LUKS).
- Never create or edit `estate.yaml` inside a synced folder (Dropbox, iCloud Drive, Google Drive, OneDrive).
- Prefer `scripts/review.sh` for edits — it works in a private temp directory and removes the plaintext when done.
- Then delete the plaintext and empty the trash, knowing what that does and does not achieve.

## What goes in the register

The formal schema is [`schema/estate.schema.json`](schema/estate.schema.json) (JSON Schema 2020-12, the single source of truth — any standard tool can validate a register without our scripts); [`schema/estate.schema.yaml`](schema/estate.schema.yaml) is its annotated human reference, and CI fails if the two ever disagree. Dummy registers: [`examples/estate.example.yaml`](examples/estate.example.yaml) (full) and [`examples/estate.minimal.yaml`](examples/estate.minimal.yaml) (the gentler start). Registers carry `format_version: 3` (format 2 still validates for this one version, with precise migrate steps). [`docs/discovery-checklist.md`](docs/discovery-checklist.md) is the "what am I forgetting" sweep, and [`AGENTS.md`](AGENTS.md) is the contract for AI-assisted authoring (hard rule: the AI never sees or stores a secret; you alone run the encryption).

The load-bearing fields per asset:

- **`type`** — `cash | liability | subscription | holding | crypto | online-business | other`.
- **`priority`** — `critical | high | normal | low`. The executor's triage order. Crypto belongs at critical or high: a missed wallet is unrecoverable, not merely delayed.
- **`ownership`** — `sole | joint | beneficiary-designated | trust | business-owned | unknown`. A joint account and a sole account cannot share a generic "liquidate"; ownership decides what an executor may lawfully do.
- **`status`** — `active | closed`. Closed accounts stay listed — a trail beats a vanishing.
- **`preferred_action`** — `liquidate | cancel | transfer | delete | notify-only | settle | preserve`, with `action_notes` saying it in your own words, `beneficiary` naming the recipient of a transfer, and `billing_cycle` letting the report sort recurring charges by burn rate. *Preferred actions are practical guidance, subject to the will, beneficiary designations, ownership rights, provider terms, and applicable law.* The register never overrides the will.
- **`first_step`** — what the executor should do *now*, decoupled from the eventual disposition ("Secure the device and recovery material. Do not transfer yet."). The triage doctrine is **preserve before dispose**.
- **`depends_on`** — record IDs to handle first (`[A006]` — the deposit box holding the wallet's seed); the report orders work with it, the validators check the references exist.
- **`last_confirmed`** — required on every active entry: a date, or the literal `unknown` as an honest signal. The strict validator warns past 18 months.

Top-level `contacts` (solicitor, accountant, share holders…) and `documents` (will, deeds, policy schedules — locations only) round out what an executor actually needs. `identifier` is a last-4 or reference only. `access_pointer` says where the login *lives* (your password manager), never what it is.

### Validation, two tiers

- `scripts/validate.sh` — **baseline, zero dependencies** (POSIX sh + awk). Runs everywhere, always; `setup.sh`, `review.sh`, and `encrypt.sh` call it automatically, so validation can never be silently skipped.
- `scripts/validate.sh --strict` — additionally runs the Python tier (`python3` + PyYAML; optionally the `jsonschema` package for a formal contract check): per-entry staleness, coverage checks, full type checking. If its dependencies are missing it says so and fails only the strict tier.

## Platform legacy tools come first

Under **RUFADAA** (the Revised Uniform Fiduciary Access to Digital Assets Act, enacted in nearly every US state), access to digital accounts follows a strict hierarchy: **(1) the platform's own online designation tool outranks (2) your will and estate documents, which outrank (3) the provider's terms of service.** A forgotten legacy-contact setting beats your will — so set these deliberately, keep them consistent with the will, and record them in the register:

| Platform | Tool | Where to set it |
|---|---|---|
| Apple | Legacy Contact | Settings > [your name] > Sign-In & Security > Legacy Contact. The contact later needs their **access key + your death certificate** at [digital-legacy.apple.com](https://digital-legacy.apple.com). Keychain passwords and licensed media are not included. |
| Google | Inactive Account Manager | [myaccount.google.com/inactive](https://myaccount.google.com/inactive). Timer-based (3–18 months of inactivity), up to 10 contacts, per-contact data selection. Also prevents Google's 2-year inactive-account deletion from surprising your estate. |
| Meta / Facebook | Legacy Contact | Settings > Memorialization settings — name a legacy contact (manages a memorialised profile; cannot read messages) or choose deletion on death. Instagram offers memorialisation only. |

In the UK there is no RUFADAA equivalent: executors have no statutory right of access, and each provider's terms plus data-protection law govern — which makes the platform tools and this register more important, not less.

**Example estate-document wording** (not legal advice — take it to whoever drafts the will):

> "I authorise my executor to access, manage, control, transfer, and dispose of my digital assets and digital accounts, and I expressly consent to the disclosure to my executor of the content of my electronic communications, to the fullest extent permitted by the Revised Uniform Fiduciary Access to Digital Assets Act or any similar applicable law."

## Threat model

| Threat | Mitigation |
|---|---|
| Someone opens the record while you're alive | 2-of-3 Shamir split; no shareholder holds the whole passphrase (you hold it in your password manager, like every other credential) |
| One shareholder lost / unreachable / dies first | 2-of-3 tolerates one loss |
| The encrypted file leaks | `age` scrypt passphrase encryption; the file alone is useless without the passphrase |
| Credentials exposed via this file | None stored; the register only points at your password manager |
| A service shuts down and breaks access | There is no service — static binaries and a local file |
| Wrongful or early access | Shares are physical and held by trusted parties; access requires two humans agreeing |
| Shares that open nothing (passphrase typo at setup) | `setup.sh` reconstructs the passphrase from the just-issued shares and test-decrypts before reporting success |
| The record goes stale | Not solved by software alone — `review.sh` makes the update loop one command, reports which entries are stale before you edit, and emits calendar nudges; `last_confirmed` is required on every active entry (`unknown` is an honest answer); the executor report lists stale entries so the reader knows what to double-check |
| Shares rot while nobody looks | `test-recovery.sh` drills the real printed shares yearly and stamps the result on the printed guide; `rotate-shares.sh` re-keys when a holder or share is lost |

## Repository layout

```
├── README.md                       what you're reading
├── LICENSE                         MIT
├── SECURITY.md                     reporting, threat boundaries, honest limits
├── CONTRIBUTING.md                 the invariants and test expectations
├── AGENTS.md                       contract for AI-assisted authoring
├── RELEASE-CHECKLIST.md            the two human-gated release steps
├── schema/estate.schema.json       formal contract (JSON Schema 2020-12) — source of truth
├── schema/estate.schema.yaml       annotated schema — the human reference
├── examples/estate.example.yaml    full dummy register, safe to commit
├── examples/estate.minimal.yaml    the gentler starting point
├── templates/EXECUTOR-INSTRUCTIONS.md  the two-page printed guide
├── docs/
│   ├── WINDOWS-RECOVERY.md         printed sheet for a Windows recovery (WSL)
│   └── discovery-checklist.md      what belongs in the register
├── scripts/
│   ├── doctor.sh                   pre-flight: tools, hazards, register state
│   ├── setup.sh                    create your Executor File: validate →
│   │                               encrypt → split → prove the chain
│   ├── review.sh                   the periodic review: staleness-aware,
│   │                               same passphrase, .ics nudges
│   ├── rotate-shares.sh            re-key: new passphrase, fresh shares,
│   │                               old ones proven dead
│   ├── test-recovery.sh            the fire drill, from printed shares
│   ├── render.sh                   decrypted YAML → executor triage report
│   ├── make-guide.sh               fill + print the Executor Instructions
│   ├── share-sheets.sh             per-holder printable share cover sheets
│   ├── verify-copies.sh            confirm stored copies are identical
│   ├── validate.sh                 baseline validator (sh+awk, no deps);
│   │                               --strict adds the Python tier
│   ├── validate.py                 strict tier (python3 + PyYAML)
│   ├── encrypt.sh                  manual building block: age -p wrapper
│   ├── decrypt.sh                  manual building block: age -d wrapper
│   └── split-secret.sh             manual building block: ssss-split wrapper
├── tests/run-tests.sh              the whole suite (run it: both mechanisms)
└── .gitignore                      excludes estate.yaml, *.age, and
                                    everything derived from them
```

Your executor never needs this repo — the printed Executor Instructions use `age` and `ssss` directly.

## Deliberately out of scope

No credential storage (that's your password manager's job). No provider APIs, generated emails, or liquidation automation (that's where legal liability and per-jurisdiction rules live). No hosted anything — public hosting of an encrypted register hands attackers an indefinite offline brute-force target. The value of this tool is *discovery plus disposition*; everything else is somebody's bereavement process.

## License

[MIT](LICENSE). Copyright © 2026 Jamie Watters.
