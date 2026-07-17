# Opening the Executor File on Windows

**Print this sheet and store it with the Executor Instructions.** It replaces Page two of the main guide when the only trusted computer available runs Windows 10 or 11. Expect 45–90 minutes including installs; the actual recovery is still three commands.

**Why Windows needs its own sheet, honestly:** the second tool in the recovery chain, `ssss` (Shamir's Secret Sharing), has **no trustworthy native Windows build** — the one old port that exists describes itself as outdated and insecure, and we will not put that in front of you. Windows instead runs the same trusted Linux tools inside Microsoft's built-in "WSL" feature. That needs administrator rights and one restart — that is the honest cost, and it is a Microsoft-supported feature, not a workaround. *(An earlier version of this project quietly said "use WSL" as if it were a footnote; it is in fact the main path, so here it is written out properly.)*

**If at any point this feels wrong:** stop and use any trusted Mac or Linux computer instead — on those, the main guide's Page two works as-is with no installs beyond the two small tools. A technically comfortable, trusted person can also sit with you here; nothing on this sheet needs more than following it exactly.

**Use a trusted machine only** — yours, the solicitor's, or another person authorised in the estate; BitLocker disk encryption on (it usually is by default). Never a public, workplace, hotel, or casually borrowed PC.

---

## Step 1 — install WSL (administrator + one restart)

1. Click **Start**, type `powershell`, right-click **Windows PowerShell** → **Run as administrator** (say yes to the prompt).
2. Type exactly:

   ```
   wsl --install
   ```

3. Wait for it to finish (it downloads a few GB), then **restart the computer** when asked.
4. After the restart, an **Ubuntu** window opens by itself (if not: Start → type `Ubuntu` → open it). It asks you to create a **username and password** — these are new, belong only to this Linux environment, and are unrelated to every other password involved. Pick something simple and **write both down**; the password prompt shows nothing while you type (not even dots) — that is normal.

*If `wsl --install` errors: the PC may be too old (needs Windows 10 version 2004 or later) or virtualisation may be disabled. That is the moment to switch to a trusted Mac/Linux machine rather than fight it.*

## Step 2 — install the two tools inside Ubuntu

In the Ubuntu window, type (it will ask for the Linux password you just created):

```
sudo apt update && sudo apt install -y ssss age
```

Both tools are free, open-source, standard Ubuntu packages.

## Step 3 — rebuild the passphrase from two shares

Still in the Ubuntu window:

```
ssss-combine -t 2
```

It asks for `Share [1/2]:` then `Share [2/2]:`. Type each printed share **exactly, including the beginning like `estate-1-`** (order does not matter; you will see what you type — that is fine, one share alone is useless). The line `Resulting secret: …` is the passphrase. Keep the window open. *(A `WARNING: couldn't get memory lock` message is harmless.)*

## Step 4 — decrypt the register

First put `estate.yaml.age` somewhere findable in Windows — your **Downloads** folder is easiest (copy it there from the USB stick in File Explorer). Then, in the Ubuntu window:

```
ls /mnt/c/Users/
```

shows the Windows user folders — note the one that is yours (it can differ from the name on the login screen). Then, replacing `YOURNAME`:

```
age -d -o estate.yaml /mnt/c/Users/YOURNAME/Downloads/estate.yaml.age
```

At `Enter passphrase:` type the `Resulting secret` from Step 3.

**Success looks like:** a readable file. Show it with:

```
cp estate.yaml /mnt/c/Users/YOURNAME/Downloads/estate.yaml
```

then open **Downloads** in File Explorer and open `estate.yaml` with **Notepad**. It is a plain list of accounts with instructions — you cannot break anything by reading it. Start with entries marked `critical` and read each `first_step` line.

## If something goes wrong

- **`age: incorrect passphrase`** — a share was mistyped or misprinted (the tools cannot tell a wrong share from a right one; they just produce a wrong answer). Re-run Steps 3–4, typing carefully — the long part of each share uses only `0-9` and `a-f`. Still failing? Try a different pair of shares to rule out one damaged printout.
- **Anything else** — any competent IT person can follow this sheet with you in half an hour. The tools are standard: `age` (age-encryption.org) and `ssss` (Shamir's Secret Sharing).

## After it is open

Follow **"After it is open"** on the main Executor Instructions — it applies unchanged: this computer only, never email it unencrypted, never paste it into AI tools, share with the solicitor on paper or via their secure upload, close windows when done, and use each provider's bereavement process rather than logging in as the deceased.

---

### Appendix (technical helper notes — not needed for the main path)

- Official **Windows builds of age exist** (code-signed): https://github.com/FiloSottile/age/releases, asset `age-vX.Y.Z-windows-amd64.zip`, or `winget install FiloSottile.age`. Useful **only for the decrypt half** (Step 4) if the passphrase was already reconstructed elsewhere — there is still no acceptable native `ssss-combine`, so shares always need WSL or a Mac/Linux machine. In PowerShell, run the extracted binary as `.\age.exe` from its folder (it is not on PATH).
- Do **not** substitute browser-based or third-party Shamir reimplementations for `ssss-combine` — this file's shares are `ssss` shares, and the project's recovery guarantee is stock tools only.
- WSL's Ubuntu ships `ssss 0.5` and an `age` recent enough for these files; both live in Ubuntu's standard `universe` repository.
