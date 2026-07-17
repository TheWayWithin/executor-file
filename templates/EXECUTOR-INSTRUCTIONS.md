# Executor Instructions: opening my Executor File

**Owner:** `[YOUR FULL NAME]`
**Last updated:** `[DATE — update this every time you re-encrypt]`

**Print this page and store it with the will.** Fill in every `[bracketed blank]` before printing. This page contains no secrets, so it is safe for anyone to read — on its own it opens nothing.

---

## What this is

I keep a single encrypted file — my **Executor File** — listing **every account, asset, and liability I own**, with what I want done about each one. The file is called `estate.yaml.age`.

- It contains **no passwords**. Logins live in my password manager: `[e.g. "1Password — its printed Emergency Kit is in the fireproof box"]`.
- It is encrypted. The key was split into **three "shares"**, held by three people. **Any two shares open it; one alone opens nothing.** That is deliberate: no single person could read it while I was alive, and losing one share loses nothing.

## What you need

1. **This page.**
2. **The encrypted file** `estate.yaml.age`, stored at:
   - `[LOCATION 1 — e.g. USB stick in the fireproof box at home]`
   - `[LOCATION 2 — e.g. attached to the will at the solicitor's / cloud drive folder]`

   (You may find a small `estate.yaml.age.sha256` file next to it — that exists only for comparing stored copies to each other. You do not need it: if decryption succeeds in Step 3, the file was intact.)
3. **Any two of these three people** — each holds one printed share:

   | Share | Held by | Contact |
   |---|---|---|
   | `estate-1-…` | `[NAME, relationship]` | `[phone / email]` |
   | `estate-2-…` | `[NAME, relationship]` | `[phone / email]` |
   | `estate-3-…` | `[NAME, relationship]` | `[phone / email]` |

4. **A trusted computer.** This process briefly exposes two shares, the reconstructed passphrase, and the full decrypted register — so do it only on a computer belonging to **you, the solicitor, or another person authorised in the estate**, preferably one with full-disk encryption (FileVault on a Mac, BitLocker on Windows — both are usually on by default). **Never** use a public, workplace, hotel, or casually borrowed machine. A Mac or Linux computer needs nothing special; on Windows, follow the separate Windows sheet stored with this page (or ask a technically comfortable, trusted person to sit with you — the whole process is three commands).

## Step 1 — install the two small tools (5 minutes)

Open the **Terminal** app and type one line:

- **Mac:** `brew install age ssss`
  (If it says `brew` is not found, first install Homebrew from https://brew.sh, then repeat.)
- **Ubuntu / Debian Linux:** `sudo apt install age ssss`

Both tools are free, open-source, and widely used — nothing here depends on any company or service of mine still existing.

## Step 2 — rebuild the passphrase from two shares

Collect the printed shares from any **two** of the three holders. In Terminal, type:

```
ssss-combine -t 2
```

It will ask for `Share [1/2]:` and then `Share [2/2]:`. Type each share **exactly as printed, including the beginning like `estate-1-`**. You will see what you type — that's fine, a share is useless on its own — and the order doesn't matter. The line

```
Resulting secret: …
```

is the passphrase. It should look like: `[FILL IN — e.g. "eight lowercase English words separated by dashes"]`. If it instead looks like random symbols and dots, a share was mistyped — see "If something goes wrong". Keep the Terminal window open.

*(A `WARNING: couldn't get memory lock` message is harmless — ignore it.)*

## Step 3 — decrypt the register

Put `estate.yaml.age` in your home folder (tip: you can type `age -d -o estate.yaml ` and then **drag the file from Finder into the Terminal window** — it fills in the path for you), then press Enter on:

```
age -d -o estate.yaml estate.yaml.age
```

When it asks `Enter passphrase:`, type (or paste) the "Resulting secret" from Step 2. This creates a readable file called **`estate.yaml`** — open it with any text editor (double-click usually works, or TextEdit / Notepad). It is a plain list; you cannot break anything by reading it.

## Step 4 — act on it, in this order

Every entry has a `preferred_action` field — what I want done, subject always to the will, beneficiary designations, ownership rights, provider terms, and the law. The will wins if they ever disagree.

| preferred_action | meaning |
|---|---|
| `liquidate` | Sell / withdraw the value into the estate account |
| `cancel` | Stop the service or recurring charge |
| `transfer` | Pass it to the person named in the notes |
| `delete` | Close the account and erase the contents |
| `notify-only` | Just inform the provider; nothing else expected |

Work in this order — **preserve before you dispose**. Nothing on this list has to happen today, but things stop being recoverable when they lapse or move:

1. **Secure, don't dispose.** Find and secure devices, recovery material, and anything other entries depend on (the register says what depends on what). For cryptocurrency: locate the device and seed backup and lock them away — **move no funds**, type no recovery words into any website or app, and get trusted technical help before touching them. Keep anything a business depends on (domains, hosting, payment processing) **running** for now — a lapsed domain or hosting bill can destroy value in days.
2. **Understand your authority before moving anything.** Joint accounts, beneficiary designations, and trusts pass outside the will; selling or transferring assets can have tax consequences. Confirm with the solicitor what you may lawfully do first.
3. **Stop money bleeding out.** Cancel subscriptions and recurring charges that nothing depends on — every month costs the estate money.
4. **Then the rest, by `priority`.** Banks, brokers, and insurers follow their normal bereavement process (death certificate etc.); the register tells you they exist and what I want done.

## After it is open — handling the file safely

The decrypted `estate.yaml` is the complete map of the estate. Treat it like the will itself:

- **Keep it on this computer only**, in your home folder or Documents — not on a USB stick that travels, not in a shared or public folder.
- **Never email it unencrypted**, and never paste its contents into a chat, an online form, or an **AI tool** (ChatGPT, Claude, Copilot or similar) — you cannot take that back.
- **To share it with the solicitor**, print it and hand it over, or take this file to them and open it together. If it must go electronically, ask the solicitor for their secure document upload — most firms have one.
- **When you finish a session**, close the text editor and close the Terminal window entirely.
- **When the estate is settled**, delete `estate.yaml` and empty the trash — knowing honestly that deletion hides the file but does not scrub the disk; that is another reason to use a trusted, disk-encrypted computer from the start.
- **Knowing an account exists — even where its password lives — does not make it yours to log into.** Use each provider's bereavement process; that is what it exists for, and logging in as the deceased can breach provider terms and, in some places, the law.

## Two things to know

- **Apple, Google, and Facebook are handled separately.** Their own "legacy" settings (listed at the bottom of the register) name who gets access, and under US law (RUFADAA) those settings **override the will**. Coordinate with the people named there rather than fighting the platforms.
- **Passwords** for individual accounts are in my password manager — the register tells you where each login lives and how you get emergency access. The register itself never contains them.

## If something goes wrong

- **The "Resulting secret" looks like gibberish (random symbols), or you see `WARNING: binary data detected`:** one share was mistyped. This tool cannot tell a wrong share from a right one — it just quietly produces the wrong answer. Re-type both shares carefully; the long part uses only `0-9` and `a-f`.
- **The passphrase is rejected by `age`:** same cause — a share was mis-typed or mis-printed. Re-enter carefully, and if it still fails, try a **different pair** of shares to rule out one damaged printout.
- **You can't reach two share-holders:** `[FALLBACK — e.g. "my solicitor holds a sealed copy of share 3 in the deeds packet"]`.
- **Still stuck:** any competent IT person can follow this page with you in under half an hour. The tools are standard: `age` (age-encryption.org) and `ssss` (Shamir's Secret Sharing). Nothing about this file needs special software from me.

---

*This Executor File was made with the open-source Executor File tooling: `[REPO URL]`. The tooling is only a convenience — the file above opens with the two standard commands on this page, forever.*
