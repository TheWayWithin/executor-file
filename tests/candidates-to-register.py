#!/usr/bin/env python3
"""candidates-to-register.py — test helper: accept every candidate from
scripts/map-1password.py and write the register a triage session would
produce, so the suite can prove imported entries are validator-clean.

The browser editor (EF-ISS-8 P2) does this same job in JavaScript; this is
the headless equivalent used by tests/run-tests.sh.

Usage:  candidates-to-register.py CANDIDATES.json > estate.yaml
"""

import json
import sys

FIELD_ORDER = [
    "provider", "type", "identifier", "priority", "ownership", "status",
    "last_confirmed", "preferred_action", "action_notes", "access_pointer",
]


def scalar(value):
    # JSON strings are valid YAML 1.2 double-quoted scalars, so this handles
    # quotes, accents and ampersands in item titles without hand-rolling
    # YAML escaping.
    return json.dumps(value, ensure_ascii=False)


def main():
    if len(sys.argv) != 2:
        sys.stderr.write(__doc__)
        return 2
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    accepted = [c for c in data["candidates"] if c.get("default_include")]
    if not accepted:
        sys.stderr.write("error: no candidates to accept\n")
        return 2

    out = [
        "meta:",
        "  format_version: 3",
        "  owner: \"Alex Example\"",
        f"  updated: \"{data['pulled']}\"",
        "  jurisdictions: [\"UK\"]",
        "  password_manager: \"1Password (my.1password.com); executor route in "
        "the printed instructions\"",
        "assets:",
    ]
    for i, cand in enumerate(accepted, start=1):
        s = cand["suggested"]
        out.append(f"  - id: \"A{i:03d}\"")
        for field in FIELD_ORDER:
            if s.get(field):
                out.append(f"    {field}: {scalar(s[field])}")
    sys.stdout.write("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
