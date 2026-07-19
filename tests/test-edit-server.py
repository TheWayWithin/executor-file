#!/usr/bin/env python3
"""Deterministic test for web/edit-server.py — the review-in-browser bridge.

Starts the server as a subprocess on an OS-assigned port, reads the real
port from its ready line, then drives /load, /save and /cancel over HTTP
with generous timeouts (no shell timing races, no curl dependency). Save
must overwrite the file and exit 0; cancel must leave it untouched and
exit 2.

Exit 0 = all good; prints a diagnostic and exits 1 on any failure.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER = os.path.join(ROOT, "web", "edit-server.py")
EXAMPLE = os.path.join(ROOT, "examples", "estate.example.yaml")
READY_TIMEOUT = 20.0
EXIT_TIMEOUT = 20.0

SAVE_BODY = (
    "meta:\n"
    "  format_version: 3\n"
    "  owner: 'Rev Tester'\n"
    "  updated: 2026-07-18\n"
    "  jurisdictions: [UK]\n"
    "  password_manager: 'Bitwarden'\n"
    "assets:\n"
    "  - id: A001\n"
    "    provider: 'Bank'\n"
    "    type: cash\n"
    "    identifier: 'a/c ...9'\n"
    "    priority: high\n"
    "    ownership: sole\n"
    "    status: active\n"
    "    last_confirmed: 2026-07-18\n"
    "    preferred_action: liquidate\n"
    "    action_notes: 'Edited in review.'\n"
)


def fail(msg, proc=None):
    print(f"FAIL: {msg}")
    if proc is not None:
        try:
            proc.kill()
        except OSError:
            pass
    sys.exit(1)


def start(target, mode=None):
    """Launch the server on an OS-assigned port; return (proc, base_url)."""
    cmd = [sys.executable, SERVER, target, "--port", "0"]
    if mode:
        cmd += ["--mode", mode]
    proc = subprocess.Popen(
        cmd, stderr=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True,
    )
    deadline = time.time() + READY_TIMEOUT
    while time.time() < deadline:
        line = proc.stderr.readline()
        if not line:
            if proc.poll() is not None:
                fail(f"server exited early (code {proc.returncode})")
            continue
        if "ready at" in line:
            url = line.split("ready at", 1)[1].strip()
            return proc, url
    fail("server never reported ready", proc)


def post(url, data=None):
    req = urllib.request.Request(url, data=(data.encode() if data else b""), method="POST")
    with urllib.request.urlopen(req, timeout=10) as r:
        return r.read().decode()


def wait_exit(proc, expected):
    try:
        code = proc.wait(timeout=EXIT_TIMEOUT)
    except subprocess.TimeoutExpired:
        fail(f"server did not exit (expected {expected})", proc)
    if code != expected:
        fail(f"server exit code {code}, expected {expected}")


def main():
    if not os.path.isfile(SERVER):
        fail(f"server not found at {SERVER}")

    with tempfile.TemporaryDirectory() as d:
        # ---- save path ----
        target = os.path.join(d, "estate.yaml")
        with open(EXAMPLE) as f:
            open(target, "w").write(f.read())
        proc, url = start(target)
        with urllib.request.urlopen(url + "load", timeout=10) as r:
            loaded = r.read().decode()
        if "format_version" not in loaded:
            fail("/load did not return the current register", proc)
        post(url + "save", SAVE_BODY)
        wait_exit(proc, 0)
        saved = open(target).read()
        if "Rev Tester" not in saved:
            fail("save did not overwrite the file")
        # the saved register must validate (baseline tier)
        vr = subprocess.run(
            ["sh", os.path.join(ROOT, "scripts", "validate.sh"), target],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if vr.returncode != 0:
            fail("the saved register did not validate")

        # ---- cancel path ----
        target2 = os.path.join(d, "estate2.yaml")
        with open(EXAMPLE) as f:
            original = f.read()
        open(target2, "w").write(original)
        proc2, url2 = start(target2)
        post(url2 + "cancel")
        wait_exit(proc2, 2)
        if open(target2).read() != original:
            fail("cancel changed the file")

        # ---- create + seal path (needs age + ssss) ----
        import shutil
        if shutil.which("age") and shutil.which("ssss-split") and shutil.which("ssss-combine"):
            target3 = os.path.join(d, "estate3.yaml")
            with open(EXAMPLE) as f:
                open(target3, "w").write(f.read())
            proc3, url3 = start(target3, mode="create")
            # /validate reports the register as valid
            with urllib.request.urlopen(url3 + "validate", timeout=15) as r:
                if not json.loads(r.read()).get("ok"):
                    fail("/validate said the example register is invalid", proc3)
            # save keeps the server up in create mode
            post(url3 + "save", open(target3).read())
            if proc3.poll() is not None:
                fail("create-mode save should NOT exit the server")
            # seal it
            sealed = json.loads(post(url3 + "seal", json.dumps({"overwrite": False})))
            if not sealed.get("ok"):
                fail(f"/seal failed: {sealed.get('error')}", proc3)
            shares = sealed["shares"]
            passphrase = sealed["passphrase"]
            if len(shares) != 3:
                fail("seal did not return three shares", proc3)
            if not os.path.exists(target3 + ".age"):
                fail("seal did not produce the .age file", proc3)
            # SECURITY-CRITICAL: two of the returned shares must reconstruct
            # the returned passphrase (the file setup.sh made was already
            # proof-chain verified before it emitted).
            combine = subprocess.run(
                ["ssss-combine", "-t", "2"],
                input=f"{shares[0]}\n{shares[1]}\n", capture_output=True, text=True,
            )
            recovered = ""
            for line in combine.stderr.splitlines():
                if line.startswith("Resulting secret: "):
                    recovered = line[len("Resulting secret: "):]
            if recovered != passphrase:
                fail("the shares from /seal do NOT reconstruct the passphrase")
            # finish
            post(url3 + "done")
            wait_exit(proc3, 0)
            print("ok: create+seal produced a valid file whose shares reconstruct the passphrase")
        else:
            print("note: create+seal path skipped (age/ssss not installed)")

    print("ok: edit-server load/save(exit0)/cancel(exit2) all correct")
    return 0


if __name__ == "__main__":
    sys.exit(main())
