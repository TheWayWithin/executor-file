#!/usr/bin/env python3
"""map-1password.py — turn `op item list --format=json` output into the
manager-agnostic candidate JSON the register editor triages (EF-ISS-8 P1).

Pure and deterministic: JSON in, JSON out, no network, no `op`, no secrets.
scripts/import-1password.sh does the talking to 1Password and pipes the
result through here; tests drive this file directly with a fixture.

METADATA ONLY. This mapper reads exactly five fields per item — title,
category, urls, vault, updated_at — and deliberately drops everything else
`op` volunteers, including `additional_information` (which carries username
and email hints on most real items). Nothing concealed is read, requested,
or emitted, here or anywhere upstream; a CI test greps the repo to prove
the unmasking flags and per-item fetches appear nowhere.

Usage:
  op item list --format=json | scripts/map-1password.py [OPTIONS]
  scripts/map-1password.py [OPTIONS] ITEMS.json

Options:
  --vaults-json JSON  `op vault list --format=json` output, for the picker
  --vault NAME        only map items from this vault (repeatable)
  --existing FILE     JSON {"assets":[{id, provider, access_pointer,
                      identifier}]} — the register already being edited, so
                      already-listed items are deduped out
  --today YYYY-MM-DD  override today's date (tests)

Output (stdout):
  {source, pulled, vaults:[{name, items}], counts:{...}, candidates:[...]}

Every candidate carries a `suggested` block of register fields — a guess
presented for confirmation, never an answer. `default_include` is false for
categories that are not accounts (secure notes, identities, documents…);
they are still emitted so the editor's "show everything" toggle needs no
second pull.

Exit codes: 0 = mapped, 2 = bad input.
"""

import argparse
import datetime
import json
import re
import sys
from urllib.parse import urlsplit

SOURCE = "1password"

# 1Password category -> (type, priority, preferred_action). Category is a
# hint, not the engine: 94% of a real vault is a generic Login (spec §9.4),
# which is why the finance heuristic below does the ranking work.
CATEGORY_MAP = {
    "BANK_ACCOUNT":     ("cash",         "high",   "notify-only"),
    "CREDIT_CARD":      ("liability",    "high",   "notify-only"),
    "CRYPTO_WALLET":    ("crypto",       "high",   "preserve"),
    "MEMBERSHIP":       ("subscription", "low",    "cancel"),
    "REWARD_PROGRAM":   ("other",        "low",    "notify-only"),
    "EMAIL_ACCOUNT":    ("other",        "high",   "preserve"),
    "SOFTWARE_LICENSE": ("other",        "low",    "cancel"),
    "API_CREDENTIAL":   ("other",        "low",    "notify-only"),
    "SERVER":           ("other",        "low",    "notify-only"),
    "DATABASE":         ("other",        "low",    "notify-only"),
    "LOGIN":            ("other",        "normal", "notify-only"),
}
DEFAULT_MAP = ("other", "normal", "notify-only")  # unknown//future categories

# Not accounts. Emitted, but off by default behind the editor's toggle.
NOT_ACCOUNTS = {
    "SECURE_NOTE", "IDENTITY", "PASSWORD", "DOCUMENT", "DRIVER_LICENSE",
    "PASSPORT", "SOCIAL_SECURITY_NUMBER", "MEDICAL_RECORD",
    "OUTDOOR_LICENSE", "SSH_KEY", "WIRELESS_ROUTER",
}

MONEY_CATEGORIES = {"BANK_ACCOUNT", "CREDIT_CARD", "CRYPTO_WALLET"}

# The "money first" signal (spec §9.5), matched against the lowercased
# title and URL host. Matching starts at a word boundary but may run into a
# longer word, so "hargreaveslansdown.com" hits and "Readwise" does not hit
# "wise" — a real false positive from the first run against a 563-item
# vault. False positives only reorder the wizard, never change what an
# entry means, so the list still leans generous.
FINANCE_HINTS = (
    "hsbc", "barclays", "lloyds", "natwest", "santander", "halifax",
    "nationwide", "monzo", "starling", "revolut", "chase", "citibank",
    "wells fargo", "amex", "american express", "mastercard", "paypal",
    "stripe", "venmo", "vanguard", "fidelity", "schwab", "etrade",
    "hargreaves", "aj bell", "interactive brokers", "ibkr", "robinhood",
    "freetrade", "trading212", "nutmeg", "moneybox", "wealthify",
    "coinbase", "binance", "kraken", "ledger", "trezor", "metamask",
    "bitcoin", "ethereum", "crypto", "wallet", "bank", "building society",
    "credit union", "mortgage", "pension", "sipp", "401k", "brokerage",
    "invest", "insurance", "aviva", "legal & general", "scottish widows",
    "standard life", "prudential", "hmrc", "treasury", "premium bonds",
    "ns&i",
)
# Short and ambiguous: whole word only, or they match half the vault
# ("Lisa" is not an ISA, "taxi" is not tax, "Wise" is not Readwise).
FINANCE_WORDS = ("isa", "ira", "irs", "tax", "wise", "visa", "loan")

FINANCE_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(h) for h in FINANCE_HINTS) + r")"
    r"|\b(?:" + "|".join(FINANCE_WORDS) + r")\b"
)

IMPORT_MARKER = "Imported from 1Password"


def normalise(value):
    """Dedup key: casefolded, whitespace-collapsed, stripped."""
    return re.sub(r"\s+", " ", (value or "")).strip().casefold()


def url_host(item):
    """Host of the primary URL, or "" — never a path, never a query string."""
    urls = item.get("urls") or []
    chosen = ""
    for u in urls:
        href = (u or {}).get("href") or ""
        if not href:
            continue
        if not chosen:
            chosen = href
        if (u or {}).get("primary"):
            chosen = href
            break
    if not chosen:
        return ""
    if "//" not in chosen:
        chosen = "//" + chosen
    host = urlsplit(chosen).netloc
    host = host.rsplit("@", 1)[-1]          # drop any userinfo
    host = host.rsplit(":", 1)[0] if host.count(":") == 1 else host  # drop port
    host = host.strip("/").lower()
    return host[4:] if host.startswith("www.") else host


def rank_of(category, title, host):
    """Lower sorts first. Accounts occupy 0-3 (money, finance-looking,
    email, the rest); the non-accounts always sort last, at 4-5, so the
    editor's "show everything" list appends to the end rather than
    reshuffling it — finance-looking ones first within that group."""
    money = FINANCE_RE.search((title + " " + host).lower()) is not None
    if category in NOT_ACCOUNTS:
        return 4 if money else 5
    if category in MONEY_CATEGORIES:
        return 0
    if money:
        return 1
    if category == "EMAIL_ACCOUNT":
        return 2
    return 3


def map_item(item, today):
    title = re.sub(r"\s+", " ", (item.get("title") or "")).strip()
    category = (item.get("category") or "").strip().upper()
    host = url_host(item)
    vault = ((item.get("vault") or {}).get("name") or "").strip()
    updated = (item.get("updated_at") or "")[:10]

    a_type, priority, action = CATEGORY_MAP.get(category, DEFAULT_MAP)
    rank = rank_of(category, title, host)
    if rank <= 1 and priority == "normal":
        # Looks money-related: worth the executor's attention early. Type
        # stays whatever the category supports — priority is a triage
        # signal, not a claim about what the account is.
        priority = "high"

    return {
        "title": title,
        "category": category,
        "url_host": host,
        "vault": vault,
        "updated": updated,
        "rank": rank,
        "default_include": category not in NOT_ACCOUNTS,
        "suggested": {
            "provider": title,
            "type": a_type,
            "identifier": host or title,
            "priority": priority,
            "ownership": "sole",
            "status": "active",
            "last_confirmed": today,
            "preferred_action": action,
            "action_notes": f"{IMPORT_MARKER} {today} — confirm the action.",
            "access_pointer": f"1Password > {title}" if title else "1Password",
        },
    }


def load_existing(path):
    """-> (set of normalised pointers already in the register,
           {normalised provider: asset id})"""
    if not path:
        return set(), {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    assets = data.get("assets", []) if isinstance(data, dict) else data
    pointers, providers = set(), {}
    for a in assets:
        if not isinstance(a, dict):
            continue
        # Registers written before this feature may carry the pointer in
        # `identifier`; match on both so dedup never silently duplicates.
        for key in ("access_pointer", "identifier"):
            if a.get(key):
                pointers.add(normalise(a[key]))
        if a.get("provider"):
            providers.setdefault(normalise(a["provider"]), a.get("id", ""))
    return pointers, providers


def main(argv=None):
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("items", nargs="?", default="-")
    p.add_argument("--vaults-json", default="")
    p.add_argument("--vault", action="append", default=[])
    p.add_argument("--existing", default="")
    p.add_argument("--today", default="")
    p.add_argument("-h", "--help", action="store_true")
    args = p.parse_args(argv)
    if args.help:
        sys.stdout.write(__doc__)
        return 0

    today = args.today or datetime.date.today().isoformat()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", today):
        sys.stderr.write("error: --today must be YYYY-MM-DD\n")
        return 2

    try:
        raw = sys.stdin.read() if args.items == "-" else open(
            args.items, encoding="utf-8").read()
        items = json.loads(raw or "[]")
        vaults_in = json.loads(args.vaults_json) if args.vaults_json else []
        pointers, providers = load_existing(args.existing)
    except (OSError, ValueError) as e:
        sys.stderr.write(f"error: could not read the input: {e}\n")
        return 2
    if not isinstance(items, list):
        sys.stderr.write("error: expected a JSON array of 1Password items\n")
        return 2

    wanted = {v.strip().casefold() for v in args.vault if v.strip()}
    candidates, deduped, skipped_vault = [], 0, 0
    for item in items:
        if not isinstance(item, dict):
            continue
        cand = map_item(item, today)
        if wanted and cand["vault"].casefold() not in wanted:
            skipped_vault += 1
            continue
        if normalise(cand["suggested"]["access_pointer"]) in pointers:
            deduped += 1
            continue
        dup = providers.get(normalise(cand["title"]))
        if dup:
            cand["possible_duplicate_of"] = dup
        candidates.append(cand)

    # Two vault items can share a title ("Mastercard" twice is normal), and
    # they would then share a pointer — which would make next year's
    # re-import hide the second one. Flag the clash so the editor can ask
    # for something distinguishing (last 4 digits) in the identifier.
    seen_titles = {}
    for cand in candidates:
        key = normalise(cand["title"])
        seen_titles[key] = seen_titles.get(key, 0) + 1
    for cand in candidates:
        n = seen_titles[normalise(cand["title"])]
        if n > 1:
            cand["title_collisions"] = n

    # Money first, then most recently touched, then alphabetical — stable
    # and reproducible, so the same vault always triages in the same order.
    candidates.sort(key=lambda c: (c["rank"], _neg_date(c["updated"]),
                                   c["title"].casefold()))

    vaults = [
        {"name": (v or {}).get("name", ""), "items": (v or {}).get("items", 0)}
        for v in vaults_in if isinstance(v, dict)
    ]
    out = {
        "source": SOURCE,
        "pulled": today,
        "vaults": vaults,
        "counts": {
            "items": len(items),
            "candidates": len(candidates),
            "shown_by_default": sum(1 for c in candidates if c["default_include"]),
            "hidden": sum(1 for c in candidates if not c["default_include"]),
            "deduped": deduped,
            "other_vaults": skipped_vault,
        },
        "candidates": candidates,
    }
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
    sys.stdout.write("\n")
    return 0


def _neg_date(d):
    """Sort key that puts the most recent date first without reversing the
    whole tuple (empty dates sort last)."""
    return tuple(-int(x) for x in d.split("-")) if re.match(
        r"^\d{4}-\d{2}-\d{2}$", d or "") else (0, 0, 0)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        sys.exit(1)
