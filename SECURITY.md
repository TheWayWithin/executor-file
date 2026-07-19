# Security policy

## Reporting a vulnerability

Use **GitHub's private vulnerability reporting** on this repository
(Security tab → "Report a vulnerability"). Please do not open a public
issue for anything security-sensitive. Reports get a response within a
week; fixes ship as fast as their severity deserves.

**Never include real estate data in a report** — no register contents,
shares, passphrases, or screenshots of any of them. Reproduce with the
example registers in `examples/`.

## Supported versions

The latest tagged release and `main`. There is no backporting; the
upgrade path is always "update the scripts, re-run the tests" — your
encrypted file needs no migration to benefit from script fixes
(schema migrations are separate, documented, and validator-guided).

## Threat model boundaries — what this design does and does not defend

Defended:

- **A leaked ciphertext.** `estate.yaml.age` alone is useless without
  the passphrase (age scrypt passphrase encryption).
- **A single compromised share or holder.** Any one share reveals
  nothing (Shamir 2-of-3, information-theoretic).
- **Credential theft via the register.** The register holds no
  credentials, and validators actively reject credential-shaped data.
- **A vanished maintainer.** Recovery needs only stock `age` + `ssss`.

Explicitly NOT defended — stated so nobody relies on it:

- **A compromised local machine.** Setup, review, rotation, and
  recovery all assume an uncompromised OS and user account. While a
  script runs, the passphrase lives in process memory and is passed to
  child processes via environment variables — visible to other
  processes of the same user (and root) on that machine, and never
  protected against a keylogger. No amount of in-memory care defeats
  local compromise; use a trusted, full-disk-encrypted machine.
- **Terminal history/scrollback.** The scripts clear the screen and
  say so honestly: scrollback, terminal logs, and session recorders
  are outside their control — closing the terminal window is part of
  the ceremony.
- **The optional browser flows (`scripts/edit.sh`, `scripts/review.sh`).**
  These run a web server bound to `127.0.0.1` only, on your machine, and
  the browser talks only to it — nothing reaches the network. But during
  the browser seal the passphrase and shares travel over that localhost
  connection and are shown in the browser tab, which is the same local
  trust boundary as the terminal ceremony (same-user processes, browser
  extensions, and a screen recorder can see them). They are never written
  to disk beyond the `.age` file, never stored in the browser, and shown
  one at a time; closing the tab when done is part of the ceremony. If you
  want the smallest possible surface, use the terminal path (`setup.sh`).
- **Two colluding share holders.** Any two shares open the file by
  design. Choose holders whose collusion you would consider
  authorised access.
- **Deleted plaintext forensics.** Deleting `estate.yaml` reduces
  exposure; it does not scrub SSDs, snapshots, or synced-folder
  history. The docs repeat this wherever it matters.
- **Printer spools.** Printed share sheets warn about them; a shop
  printer may retain what it printed.

## Two promises worth auditing

1. **No account credentials in the register** — enforced by both
   validator tiers (`scripts/validate.sh`, `scripts/validate.py`).
2. **No maintainer can recover a lost passphrase.** There is no back
   door, no escrow, no reset. Fewer than two shares plus no password-
   manager entry means the file stays sealed forever. That is the
   security property working as designed — protect the shares and the
   password-manager entry accordingly.
