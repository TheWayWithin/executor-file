# Executor Instructions: opening my Executor File

**Owner:** `[OWNER FULL NAME]` · **Last updated:** `[LAST UPDATED]` · **Last successful recovery test:** `[LAST RECOVERY TEST]`

**Print both pages and store them with the will.** `scripts/make-guide.sh` fills in every `[bracketed blank]` from your register (or fill them by hand). This page contains no secrets — on its own it opens nothing, so it is safe for anyone to read.

## Page one — read this first. No computer needed yet.

**If you are reading this, I have died or lost the capacity to manage my own affairs. Thank you for doing this. This page and the next are everything you need.**

1. **You do not have to finish today.** Nothing on this page expires this week. The file you are about to open lists what is genuinely urgent and what can wait — you do not have to hold that in your head.

2. **Confirm your authority first.** The will names the executor. If that is not you, hand these pages to the person it names. Acting without authority can create real legal problems, even with good intentions.

3. **The will is here:** `[WILL LOCATION]`

4. **What I have left you is a single encrypted file** — my **Executor File**, `estate.yaml.age` — listing every account, asset, and liability I own, with what I want done about each one. It contains **no passwords**. Logins live in my password manager: `[PASSWORD MANAGER]`. Copies of the encrypted file are stored:
   - `[LOCATION 1 — e.g. USB stick in the fireproof box at home]`
   - `[LOCATION 2 — e.g. attached to the will at the solicitor's]`

5. **The file opens with two "shares."** Its key was split into three printed shares held by three people. **Any two open it; one alone opens nothing.** That is deliberate — no single person could read it while I was alive, and losing one share loses nothing. Contact any two:

   | Share | Held by |
   |---|---|
   | 1 | `[SHARE HOLDER 1]` |
   | 2 | `[SHARE HOLDER 2]` |
   | 3 | `[SHARE HOLDER 3]` |

6. **Use a trusted computer.** Opening the file briefly exposes the shares, the reconstructed passphrase, and the full decrypted register. Do it only on a computer belonging to **you, the solicitor, or another person authorised in the estate** — preferably with full-disk encryption (FileVault on Mac, BitLocker on Windows; both usually on by default). **Never** a public, workplace, hotel, or casually borrowed machine.

7. **This file guides — the will decides.** Everything inside is my practical guidance, subject to the will, beneficiary designations, ownership rights, provider terms, and the law. If they ever disagree, the will wins.

---

## Page two — the technical procedure (30–60 minutes, three commands)

**You need:** a trusted Mac or Linux computer (for Windows, use the separate Windows sheet stored with this page), the encrypted file `estate.yaml.age`, and two printed shares.

**Step 1 — install the two small tools.** Open the **Terminal** app and type one line:

- Mac: `brew install age ssss` (if it says `brew` not found, first install it from https://brew.sh, then repeat)
- Ubuntu/Debian Linux: `sudo apt install age ssss`

Both are free, open-source, and widely used. Nothing depends on any service of mine still existing.

**Step 2 — rebuild the passphrase from the two shares.** Type:

```
ssss-combine -t 2
```

It asks for `Share [1/2]:` then `Share [2/2]:`. Type each share **exactly as printed, including the beginning like `estate-1-`** (order does not matter; you will see what you type — that is fine, one share alone is useless). The line `Resulting secret: …` is the passphrase. Keep this Terminal window open. *(A `WARNING: couldn't get memory lock` message is harmless.)*

**Step 3 — decrypt the register.** Put `estate.yaml.age` in your home folder, then run:

```
age -d -o estate.yaml estate.yaml.age
```

(Tip: type `age -d -o estate.yaml ` and drag the file from Finder into the Terminal window to fill in its path.) At `Enter passphrase:` type or paste the Resulting secret from Step 2.

**Success looks like:** a new file **`estate.yaml`** in your home folder that opens in any text editor (double-click, or TextEdit/Notepad) as a readable list of accounts with instructions. You cannot break anything by reading it. Start with the entries marked `critical`, and read the `first_step` lines — the register's own advice on what to do now. *(If the tooling repo is to hand, `scripts/render.sh` turns the file into a sorted, printable report — helpful, but never required.)*

**If something goes wrong:**

- **`age: incorrect passphrase`** — a share was mistyped or misprinted; the tools cannot tell a wrong share from a right one, they just produce the wrong answer. Re-enter both shares carefully (the long part uses only `0-9` and `a-f`). Still failing? Try a **different pair** of shares to rule out one damaged printout.
- **`Share [2/2]:` never appears / errors** — the whole share line was not entered; include the `estate-N-` prefix.
- **You cannot reach two share holders:** `[FALLBACK — e.g. "my solicitor holds a sealed copy of share 3 in the deeds packet"]`
- **Still stuck:** any competent IT person can follow this page with you in half an hour. The tools are standard: `age` (age-encryption.org) and `ssss` (Shamir's Secret Sharing). Nothing needs software of mine.

**After it is open — handle it like the will itself:**

- Keep `estate.yaml` on this computer only; not on a travelling USB stick, not in a shared folder.
- **Never** email it unencrypted, and never paste it into a chat, online form, or **AI tool** (ChatGPT, Claude, Copilot or similar).
- Share it with the solicitor by printing it, or opening it together — or via the firm's secure document upload.
- Close the editor and the Terminal window when you finish a session.
- When the estate is settled, delete it and empty the trash — knowing honestly that deletion hides a file but does not scrub a disk (another reason for a trusted, disk-encrypted computer).
- Knowing an account exists — even where its password lives — does not make it yours to log into. Use each provider's bereavement process; logging in as the deceased can breach provider terms and, in some places, the law.
- Apple, Google, and Facebook run their own legacy-access schemes; the register's `platform_legacy_tools` section says what was set up and who was named. Under US law (RUFADAA) those settings **override the will** — coordinate with the named people rather than fighting the platforms.

---

*Made with the open-source Executor File tooling: `[REPO URL]`. The tooling is a convenience — this file opens with the two standard commands above, forever.*
