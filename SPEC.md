# Digital Estate Register — MVP Spec

**Status:** draft v0.1
**Owner:** Jamie Watters
**Licence:** open source (MIT or Apache-2.0, decide before first commit)
**One-line:** An encrypted, self-hosted file that lets a future executor find every asset and know what to do with each one, with no credentials stored and no dependence on any service staying alive.

---

## 1. Purpose and non-goals

**Purpose.** Enable an executor to (a) discover every account, asset, and liability, (b) know the intended disposition of each (liquidate / cancel / transfer / delete), and (c) access the record securely after death without any single person holding unilateral access while the owner is alive.

**Explicitly not in scope for MVP:**
- No credential or password storage. The register *points to* a password manager; it never holds secrets.
- No automated provider contact, no generated emails, no liquidation workflow.
- No provider API integration.
- No multi-user or executor login. It is a file, not an app.
- No web service, hosting, or account. Nothing to keep paid or patched.

The value is *discovery plus disposition*. Automation is where legal liability, provider terms, and per-jurisdiction rules bite, and it is deliberately excluded.

## 2. Design principles

1. **No single point of compromise or failure.** No one person can open the record alone while the owner lives; no one lost item is fatal.
2. **Survives the owner.** No dependency on a running service, a paid subscription, or the owner being reachable.
3. **Executor-readable with common tools.** The decrypted output is plain text an executor (or their solicitor) can read without bespoke software.
4. **Portable and inspectable.** Single file, open format, open-source tooling, no lock-in.
5. **No secrets at rest in scope.** Credentials live in a proper password manager; the register references it.

## 3. Architecture

Three artefacts, nothing more:

1. **`estate.yaml`** — the plaintext source record (never committed, never stored unencrypted long-term).
2. **`estate.yaml.age`** — the encrypted record, the only version that persists.
3. **`EXECUTOR-INSTRUCTIONS.md`** — a printed plaintext page stored with the will, telling the executor exactly how to get in.

**Encryption:** `age` (age-encryption.org), passphrase mode. One static binary, open source, actively maintained, no keyring complexity.

**Master secret:** one strong passphrase, never stored whole. Split with Shamir's Secret Sharing (`ssss`) into a 2-of-3 scheme. Any two of three shareholders reconstruct it; any one alone cannot.

**Shareholders (example):** executor, solicitor, one family member. Each holds one printed share.

```
estate.yaml  --age -p-->  estate.yaml.age        (the record, encrypted)
passphrase   --ssss-split-->  share1 / share2 / share3   (2-of-3)
```

## 4. Data schema (`estate.yaml`)

```yaml
meta:
  owner: Jamie Watters
  updated: 2026-07-16
  jurisdiction_primary: US-NY
  jurisdiction_secondary: UK
  password_manager: "1Password. Executor access via its Emergency Kit, held by [name]."
  notes: >
    This file lists assets and intended actions. It holds no passwords.
    Financial-institution credentials are in the password manager referenced above.

assets:
  - id: A001
    provider: "HSBC"
    type: cash            # cash | liability | subscription | holding | crypto | online-business | other
    identifier: "current a/c ...1234"   # last 4 or reference, never full credentials
    jurisdiction: UK
    approx_value: "£X"
    action: liquidate      # liquidate | cancel | transfer | delete | notify-only
    action_notes: "Sole account. Transfer balance to estate account, then close."
    access_pointer: "1Password > HSBC"   # where the executor finds login, NOT the login itself

  - id: A002
    provider: "Adobe Creative Cloud"
    type: subscription
    identifier: "billed to Amex ...5678"
    jurisdiction: US
    approx_value: "liability ~$60/mo"
    action: cancel
    action_notes: "Recurring charge. Cancel to stop billing to the estate."
    access_pointer: "1Password > Adobe"

  - id: A003
    provider: "[crypto exchange / wallet]"
    type: crypto
    identifier: "wallet label / exchange account ref"
    jurisdiction: US
    approx_value: "$X"
    action: transfer
    action_notes: >
      HIGH PRIORITY. Unrecoverable without keys. Seed phrase location:
      [pointer to sealed physical backup, NOT written here].
    access_pointer: "Hardware wallet in [location]; recovery via [pointer]"

platform_legacy_tools:
  - platform: Apple
    tool: Legacy Contact
    configured: true
    contact: "[name]"
  - platform: Google
    tool: Inactive Account Manager
    configured: true
  - platform: Meta
    tool: Legacy Contact
    configured: false      # to do
```

**Field notes:**
- `type` and `action` are the two load-bearing fields. `action` tells the executor *what you want done*; everything else supports finding it.
- `identifier` is last-4 or a reference only. Never a full account number, never a credential.
- `access_pointer` points at where the login lives (the password manager). It is a signpost, not a secret.
- `crypto` entries are flagged high-priority: per the research, a missed wallet is unrecoverable, not merely delayed. Seed-phrase *location* is referenced; the phrase itself never appears in this file.
- `platform_legacy_tools` is included because under RUFADAA-style hierarchies these settings legally outrank a will, so they must be set directly and recorded here for the executor's awareness.

## 5. Executor access flow

Encrypted at rest. On death, the executor:

1. Reads the printed `EXECUTOR-INSTRUCTIONS.md` stored with the will.
2. Contacts two of the three named shareholders and collects their shares.
3. Installs `age` and `ssss` (one line each, instructions provided).
4. Runs `ssss-combine` to reconstruct the passphrase from the two shares.
5. Runs `age -d estate.yaml.age > estate.yaml` to decrypt.
6. Reads a plain YAML list of every asset and its intended disposition, plus pointers to the password manager for any credentials needed.

No service, no login, no company. Three commands and two people.

## 6. Repository layout

```
digital-estate/
├── README.md                     # what this is, threat model, quickstart
├── LICENSE                       # MIT or Apache-2.0
├── schema/
│   └── estate.schema.yaml        # documented schema + field definitions
├── examples/
│   └── estate.example.yaml       # dummy data, safe to commit
├── templates/
│   └── EXECUTOR-INSTRUCTIONS.md   # the printable page, with blanks to fill
├── scripts/
│   ├── encrypt.sh                # age -p wrapper
│   ├── decrypt.sh                # age -d wrapper
│   ├── split-secret.sh           # ssss-split wrapper (2-of-3 default)
│   └── validate.sh               # lint estate.yaml against schema
└── .gitignore                    # MUST ignore estate.yaml and *.age
```

**Critical `.gitignore` rule:** the real `estate.yaml` and any `.age` file must never be committed. Only the schema, example, templates, and scripts are public. The register itself is private and lives outside the repo.

## 7. Threat model (brief)

| Threat | Mitigation |
|---|---|
| Single person opens record while owner alive | 2-of-3 Shamir split; no one holds the whole passphrase |
| One shareholder lost / unreachable / dies first | 2-of-3 tolerates one loss |
| Encrypted file leaks | `age` passphrase encryption; file alone is useless without 2 shares |
| Credentials exposed via this file | None stored; register only points to password manager |
| Service shutdown breaks access | No service. Static binary + local file |
| Wrongful/early access | Physical shares held by trusted parties; social + physical gate |
| Staleness (record decays) | Out of MVP scope. Mitigate operationally: calendar a review at each will review |

**Known residual risk:** staleness. The research names this as the killer of vault products. The MVP does not solve it technically; the mitigation is a recurring review discipline, not a feature.

## 8. MVP acceptance criteria

- [ ] `estate.yaml` populated with all known assets and a disposition for each.
- [ ] `estate.yaml.age` produced; plaintext source removed from persistent storage.
- [ ] Passphrase split 2-of-3; three shares physically distributed and each holder briefed on what it is.
- [ ] `EXECUTOR-INSTRUCTIONS.md` printed and stored with the will.
- [ ] A dry run: a second person, given two shares and the instructions, successfully decrypts on a clean machine.
- [ ] Platform legacy tools (Apple, Google, Meta) configured and recorded.
- [ ] Repo public with schema, example, templates, scripts; real data git-ignored and verified absent from history.

## 9. Build sequence

1. Scaffold repo, licence, `.gitignore` (verify real data is ignored before any commit).
2. Write `estate.schema.yaml` and `estate.example.yaml`.
3. Write the four scripts (thin wrappers around `age` and `ssss`).
4. Write `EXECUTOR-INSTRUCTIONS.md` template.
5. Populate the real `estate.yaml` locally.
6. Encrypt, split, distribute, brief shareholders.
7. Run the dry-run acceptance test.
8. Configure and record platform legacy tools.
9. Publish repo.

## 10. Deliberately deferred (post-MVP)

- AI-assisted freshness (permissioned email scan / password-manager import to catch new accounts). Genuinely new and testable, but carries the data-access trust cost the research flags. Not MVP.
- Executor tooling: generated provider emails, per-provider closure packs, status tracking. This is the hard, liability-heavy layer. Out.
- Death-certificate-triggered anything. Verification is the fraud surface; keep it human and physical for MVP.

---

**Provenance note:** the research you supplied recommends exactly this as the honest, zero-market-risk version of the concept: a personal continuity register in the vault, no credentials, platform legacy tools set first because they legally outrank the will. This spec is that register, made portable and open source.
