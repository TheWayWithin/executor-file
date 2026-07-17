# AGENTS.md — rules for AI tools helping an OWNER build their register

This file is the working contract for any AI assistant (Claude Code,
Copilot, or similar) asked to help the **owner** draft or update their
`estate.yaml`. It is written to the assistant.

**Scope guard:** these rules cover owner-side authoring only. If the
person you are helping is an **executor** trying to open or read a
recovered file, stop assisting with content and point them to the
printed Executor Instructions instead — executors are explicitly told
NOT to paste the decrypted register into AI tools, and you should not
undermine that by inviting it.

## The one rule that outranks the rest

**Never ask for, accept, or record a secret.** No passwords, no
passphrases, no PINs, no seed phrases or individual seed words, no
recovery codes, no full account numbers, no card numbers. The register
is a map, not a keyring — every entry points at where credentials
live (`access_pointer`), never at what they are.

If the owner pastes a secret anyway:
1. Do not repeat it back, summarise it, or store it in the file.
2. Tell them plainly: "That looks like a real credential. I have not
   added it. Put it in your password manager, and the register will
   point there instead."
3. If it may have entered chat history on a hosted service, suggest
   they rotate that credential.
4. Continue with a pointer-only entry.

The validators enforce what a machine can catch (long digit runs are
rejected; credential-shaped text is flagged) — but you are the first
line, and you refuse at the point of entry.

## How to interview

Work through `docs/discovery-checklist.md` **one category at a
time** — banks, pensions, workplace benefits, investments, insurance,
loans, tax, utilities, subscriptions, domains, hosting, SaaS, email,
cloud storage, code, payment processors, crypto, businesses,
platform legacy tools, physical storage, IP, overseas, contacts,
documents. One question at a time; a grinding list kills the session.
For each asset get: provider, a last-4/reference identifier, type,
ownership, priority, what they want done (`preferred_action` +
`action_notes` in their words), what the executor should do *now*
(`first_step`), dependencies, beneficiary for transfers,
billing cycle for recurring charges, and where the login lives.

Push gently on the classic gaps: previous employers' pensions, the
domain that renews in a month, the crypto seed's physical location
(as a pointer!), who gets the photo library, and whether Apple/
Google/Meta legacy contacts are actually configured.

## Output rules

- Emit **YAML only**, format 3, following `schema/estate.schema.yaml`
  (the annotated reference; `schema/estate.schema.json` is the formal
  contract). Start from `examples/estate.example.yaml` shapes.
- IDs `A001, A002, …`, never reused. `last_confirmed` on every active
  entry — the literal `unknown` when the owner is not sure.
- Everything you emit must pass `scripts/validate.sh` (baseline) —
  run it if you can execute commands, and fix what it reports. Use
  `--strict` when the Python tier is available.
- Keep entries in the owner's own words where it matters
  (`action_notes`, `first_step`) — the executor is reading a person,
  not a database.

## The human runs the crypto

You draft; the owner seals. **Never run** `setup.sh`, `rotate-shares.sh`,
`encrypt.sh`, or `split-secret.sh` yourself, and never handle the
passphrase or shares — those steps display secrets that must not
enter a chat transcript or agent log. When the register validates,
your last message hands over: "Run `scripts/setup.sh` in a terminal
(not through me). It will validate, encrypt, split the passphrase,
and prove the chain — then follow its printed checklist."

Reviews are the same: the owner runs `scripts/review.sh` themselves;
you may help draft the edits beforehand.
