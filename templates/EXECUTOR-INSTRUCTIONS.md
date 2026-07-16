# Instructions for my executor: the digital estate register

**Owner:** `[YOUR FULL NAME]`
**Last updated:** `[DATE — update this every time you re-encrypt]`

**Print this page and store it with the will.** Fill in every `[bracketed blank]` before printing. This page contains no secrets, so it is safe for anyone to read — on its own it opens nothing.

---

## What this is

I keep a single encrypted file listing **every account, asset, and liability I own**, with what I want done about each one. It is called `estate.yaml.age`.

- It contains **no passwords**. Logins live in my password manager: `[e.g. "1Password — its printed Emergency Kit is in the fireproof box"]`.
- It is encrypted. The key was split into **three "shares"**, held by three people. **Any two shares open it; one alone opens nothing.** That is deliberate: no single person could read it while I was alive, and losing one share loses nothing.

## What you need

1. **This page.**
2. **The encrypted file** `estate.yaml.age`, stored at:
   - `[LOCATION 1 — e.g. USB stick in the fireproof box at home]`
   - `[LOCATION 2 — e.g. attached to the will at the solicitor's / cloud drive folder]`
3. **Any two of these three people** — each holds one printed share:

   | Share | Held by | Contact |
   |---|---|---|
   | `estate-1-…` | `[NAME, relationship]` | `[phone / email]` |
   | `estate-2-…` | `[NAME, relationship]` | `[phone / email]` |
   | `estate-3-…` | `[NAME, relationship]` | `[phone / email]` |

4. **A Mac or Linux computer** — any will do, including a borrowed one. If you only have Windows, use its "WSL/Ubuntu" feature or, simpler, ask any of the share-holders or a technically comfortable friend to sit with you at a Mac. The whole process is three commands.

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

Every entry has an `action` field — that is what I want done:

| action | meaning |
|---|---|
| `liquidate` | Sell / withdraw the value into the estate account |
| `cancel` | Stop the service or recurring charge |
| `transfer` | Pass it to the person named in the notes |
| `delete` | Close the account and erase the contents |
| `notify-only` | Just inform the provider; nothing else expected |

Work in this order:

1. **`crypto` entries first.** Cryptocurrency is **unrecoverable** if keys are lost or moved wrongly — do not rush, do not type any recovery words into any website, and get trusted technical help before touching it.
2. **Subscriptions and other recurring charges** — every month costs the estate money.
3. **Banks, brokers, insurers** — these follow their normal bereavement process (death certificate etc.); the register tells you they exist and what I want done.
4. Everything else.

## Two things to know

- **Apple, Google, and Facebook are handled separately.** Their own "legacy" settings (listed at the bottom of the register) name who gets access, and under US law (RUFADAA) those settings **override the will**. Coordinate with the people named there rather than fighting the platforms.
- **Passwords** for individual accounts are in my password manager — the register tells you where each login lives and how you get emergency access. The register itself never contains them.

## If something goes wrong

- **The "Resulting secret" looks like gibberish (random symbols), or you see `WARNING: binary data detected`:** one share was mistyped. This tool cannot tell a wrong share from a right one — it just quietly produces the wrong answer. Re-type both shares carefully; the long part uses only `0-9` and `a-f`.
- **The passphrase is rejected by `age`:** same cause — a share was mis-typed or mis-printed. Re-enter carefully, and if it still fails, try a **different pair** of shares to rule out one damaged printout.
- **You can't reach two share-holders:** `[FALLBACK — e.g. "my solicitor holds a sealed copy of share 3 in the deeds packet"]`.
- **Still stuck:** any competent IT person can follow this page with you in under half an hour. The tools are standard: `age` (age-encryption.org) and `ssss` (Shamir's Secret Sharing). Nothing about this file needs special software from me.

---

*This register was made with the open-source Digital Estate Register tooling: `[REPO URL]`. The tooling is only a convenience — the file above opens with the two standard commands on this page, forever.*
