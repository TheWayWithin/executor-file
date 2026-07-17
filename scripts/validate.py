#!/usr/bin/env python3
"""Strict-tier validator for an Executor File register (format 3;
format 2 accepted for this one version, with a migrate warning).

Driven by schema/estate.schema.yaml so documentation and validator cannot
drift apart (the formal single source of truth is estate.schema.json —
CI keeps the two in agreement). Beyond the zero-dependency baseline
(scripts/validate.sh), this tier adds: type checking of every field,
per-entry staleness warnings (last_confirmed older than 18 months),
depends_on reference checks, coverage checks, and — if the optional
`jsonschema` package is installed — validation against the formal
contract in schema/estate.schema.json (JSON Schema 2020-12).

Both tiers agree on what is an ERROR vs a WARNING; a fixture test in CI
asserts it. This tier needs python3 + PyYAML; the baseline needs nothing.
Invoke via:  scripts/validate.sh --strict

Exit codes: 0 = valid, 1 = validation errors, 2 = couldn't run.
"""

import datetime
import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "error: this strict-tier validator needs the PyYAML library.\n"
        "  quick fix:  python3 -m pip install --user pyyaml\n"
        "  or a venv:  python3 -m venv .venv && .venv/bin/pip install pyyaml\n"
        "              then: PYTHON=.venv/bin/python3 scripts/validate.sh --strict\n"
        "(Only this strict tier needs Python. The baseline validator,\n"
        "encryption, and your executor's recovery path do not.)\n"
    )
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "estate.schema.yaml"
JSON_SCHEMA_PATH = REPO_ROOT / "schema" / "estate.schema.json"

# Entries not re-confirmed for this long draw a staleness warning.
STALE_MONTHS = 18

MIGRATE_V2_STEPS = (
    "to migrate: set format_version: 3; replace jurisdiction_primary/"
    "jurisdiction_secondary with e.g. \"jurisdictions: [US-NY, UK]\"; give "
    "every active asset a last_confirmed (a date, or the literal unknown)"
)

# A run of 9+ digits (ignoring single spaces/dashes between them) is
# treated as a full account/card number — those must never be in the
# register. In the contacts section, where phone numbers are expected
# content, the threshold rises to 16 digits (longer than any phone
# number, still short enough to catch card PANs and IBANs).
DIGIT_RUN = re.compile(r"(?:\d[ -]?){9,}")
DIGIT_RUN_CONTACTS = re.compile(r"(?:\d[ -]?){16,}")
# "password: xyz", "PIN = 1234", "seed phrase: word word …" — looks like an
# actual credential written down, not a pointer to one.
SECRET_HINT = re.compile(
    r"(?i)\b(password|passphrase|pin|private key|seed phrase|recovery phrase)\b\s*(is|=|:)\s*\S"
)

ID_PATTERN = re.compile(r"^A[0-9]{3,}$")

errors: list[str] = []
warnings: list[str] = []


def err(where: str, msg: str) -> None:
    errors.append(f"{where}: {msg}")


def warn(where: str, msg: str) -> None:
    warnings.append(f"{where}: {msg}")


def as_date(value):
    """Return a datetime.date if value parses as one, else None."""
    if isinstance(value, datetime.date):
        return value
    if isinstance(value, str):
        try:
            return datetime.date.fromisoformat(value)
        except ValueError:
            return None
    return None


def type_ok(value, expected: str) -> bool:
    if expected == "string" or expected == "enum":
        return isinstance(value, str) and value.strip() != ""
    if expected == "bool":
        return isinstance(value, bool)
    if expected == "int":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "date":
        return as_date(value) is not None
    if expected == "date_or_unknown":
        return value == "unknown" or as_date(value) is not None
    if expected == "list_of_strings":
        return (isinstance(value, list) and len(value) > 0
                and all(isinstance(v, str) and v.strip() != "" for v in value))
    if expected == "list_of_ids":
        return (isinstance(value, list)
                and all(isinstance(v, str) and ID_PATTERN.fullmatch(v) for v in value))
    return True


def scan_for_secrets(value, where: str, digit_run=DIGIT_RUN) -> None:
    """Recursively scan values for things that must not be in the register."""
    if isinstance(value, str):
        if digit_run.search(value):
            err(where, "contains a long digit run — looks like a full account/card "
                       "number. Use last-4 or a reference only.")
        if SECRET_HINT.search(value):
            warn(where, "looks like it may contain an actual credential "
                        "(password/PIN/seed written out). The register must hold "
                        "pointers only — double-check this value.")
    elif isinstance(value, dict):
        for k, v in value.items():
            scan_for_secrets(v, f"{where}.{k}", digit_run)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            scan_for_secrets(v, f"{where}[{i}]", digit_run)


def check_fields(data: dict, field_specs: dict, where: str) -> None:
    for name, spec in field_specs.items():
        if name not in data or data[name] is None:
            if spec.get("required"):
                err(where, f"missing required field '{name}'")
            elif spec.get("recommended"):
                warn(where, f"recommended field '{name}' is missing")
            continue
        value = data[name]
        ftype = spec.get("type", "string")
        if not type_ok(value, ftype):
            hint = ""
            if ftype == "date_or_unknown":
                hint = " (a YYYY-MM-DD date, or the literal unknown)"
            elif ftype == "list_of_strings":
                hint = " (a non-empty list, e.g. [US-NY, UK])"
            elif ftype == "list_of_ids":
                hint = " (a list of record IDs, e.g. [A006])"
            err(where, f"field '{name}' should be a {ftype}{hint}, got: {value!r}")
            continue
        if ftype == "enum" and value not in spec.get("values", []):
            allowed = ", ".join(spec.get("values", []))
            err(where, f"field '{name}' has invalid value '{value}' "
                       f"(allowed: {allowed})")
        if ftype == "int" and "values_int" in spec and value not in spec["values_int"]:
            allowed = ", ".join(str(v) for v in spec["values_int"])
            err(where, f"field '{name}' has invalid value {value} "
                       f"(allowed: {allowed})")
        if "pattern" in spec and isinstance(value, str):
            if not re.fullmatch(spec["pattern"], value):
                err(where, f"field '{name}' value '{value}' does not match "
                           f"pattern {spec['pattern']}")
    for name in data:
        if name not in field_specs:
            if name == "action" and "preferred_action" in field_specs:
                err(where, "field \"action\" was renamed in format 2 — change it "
                           "to \"preferred_action\" (same values)")
            else:
                warn(where, f"unknown field '{name}' (typo? not part of the schema)")


def jsonschema_pass(doc, target: Path) -> None:
    """Optional: validate against the formal JSON Schema contract (format 3)."""
    try:
        import jsonschema
    except ImportError:
        print("  note     jsonschema package not installed — skipping the formal "
              "JSON-Schema pass (python3 -m pip install --user jsonschema). "
              "All schema rules above were still enforced.")
        return
    contract = json.loads(JSON_SCHEMA_PATH.read_text())
    # YAML dates arrive as datetime.date; the JSON contract expects strings.
    plain = json.loads(json.dumps(doc, default=str))
    validator = jsonschema.Draft202012Validator(contract)
    for e in sorted(validator.iter_errors(plain), key=lambda e: list(e.absolute_path)):
        path = ".".join(str(p) for p in e.absolute_path) or target.name
        err(f"[json-schema] {path}", e.message)


def main() -> int:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("estate.yaml")

    if not SCHEMA_PATH.is_file():
        sys.stderr.write(f"error: schema not found at {SCHEMA_PATH}\n")
        return 2
    if not target.is_file():
        sys.stderr.write(
            f"error: register not found: {target}\n"
            "hint: copy examples/estate.example.yaml to estate.yaml and edit it.\n"
        )
        return 2

    schema = yaml.safe_load(SCHEMA_PATH.read_text())
    try:
        doc = yaml.safe_load(target.read_text())
    except yaml.YAMLError as e:
        sys.stderr.write(f"error: {target} is not valid YAML:\n{e}\n")
        return 1

    if not isinstance(doc, dict):
        sys.stderr.write(f"error: {target} must be a YAML mapping "
                         "(meta / assets / contacts / documents / "
                         "platform_legacy_tools).\n")
        return 1

    # Format gate first: a format-1 register gets a migrate message,
    # never a silent misparse or a wall of field errors. Format 2 is
    # accepted for this one version and normalised in memory.
    meta = doc.get("meta")
    fmt = meta.get("format_version") if isinstance(meta, dict) else None
    if isinstance(meta, dict) and fmt is None:
        err("meta", "no format_version — this file is a format 1 register. "
            "To migrate: add \"format_version: 3\" under meta, rename every "
            "asset \"action:\" to \"preferred_action:\", add \"priority:\", "
            "\"ownership:\" and \"status:\" to each asset, replace the "
            "jurisdiction fields with \"jurisdictions: [...]\", and give "
            "active assets a last_confirmed "
            "(see examples/estate.example.yaml)")
    v2_compat = fmt == 2
    if v2_compat:
        warn("meta", "format_version is 2 — still accepted this version, "
             f"but {MIGRATE_V2_STEPS}")
        # One rename: primary/secondary jurisdictions become the array.
        meta = dict(meta)
        juris = [j for j in (meta.pop("jurisdiction_primary", None),
                             meta.pop("jurisdiction_secondary", None)) if j]
        if juris:
            meta["jurisdictions"] = juris
        meta["format_version"] = 3
        doc = dict(doc)
        doc["meta"] = meta
    elif isinstance(meta, dict) and fmt is not None and fmt not in (2, 3):
        err("meta", f"format_version is \"{fmt}\" — this validator understands "
            "formats 2 (deprecated) and 3")

    sections = schema["sections"]

    for sec_name, sec_spec in sections.items():
        if sec_name not in doc or doc[sec_name] is None:
            if sec_spec.get("required"):
                err(sec_name, "missing required section")
            continue
        sec = doc[sec_name]
        if sec_spec["kind"] == "map":
            if not isinstance(sec, dict):
                err(sec_name, "should be a mapping of fields")
                continue
            specs = sec_spec["fields"]
            if sec_name == "meta" and sec.get("format_version") is None:
                specs = {k: v for k, v in specs.items() if k != "format_version"}
            check_fields(sec, specs, sec_name)
        elif sec_spec["kind"] == "list":
            if not isinstance(sec, list):
                err(sec_name, "should be a list of entries")
                continue
            if len(sec) < sec_spec.get("min_items", 0):
                err(sec_name, f"needs at least {sec_spec['min_items']} entry")
            seen_ids: dict[str, int] = {}
            for i, item in enumerate(sec):
                label = f"{sec_name}[{i}]"
                if isinstance(item, dict) and isinstance(item.get("id"), str):
                    label = f"{sec_name}[{item['id']}]"
                if not isinstance(item, dict):
                    err(label, "each entry should be a mapping of fields")
                    continue
                check_fields(item, sec_spec["item_fields"], label)
                for fname, fspec in sec_spec["item_fields"].items():
                    if fspec.get("unique") and isinstance(item.get(fname), str):
                        v = item[fname]
                        if v in seen_ids:
                            err(label, f"duplicate {fname} '{v}' (also used by "
                                       f"entry {seen_ids[v]})")
                        seen_ids[v] = i

    for sec_name in doc:
        if sec_name not in sections:
            warn(sec_name, "unknown top-level section (typo? not part of the schema)")

    for sec_name, sec in doc.items():
        run = DIGIT_RUN_CONTACTS if sec_name == "contacts" else DIGIT_RUN
        scan_for_secrets(sec, f"{target.name}.{sec_name}", run)

    # Cross-record checks, staleness, and coverage (strict tier only).
    assets = doc.get("assets") if isinstance(doc.get("assets"), list) else []
    all_ids = {a.get("id") for a in assets if isinstance(a, dict)}
    today = datetime.date.today()
    stale_before = today - datetime.timedelta(days=STALE_MONTHS * 30)
    for i, a in enumerate(assets):
        if not isinstance(a, dict):
            continue
        label = f"assets[{a.get('id', i)}]"
        # Freshness contract: every active record carries last_confirmed.
        if a.get("status") == "active" and a.get("last_confirmed") is None:
            if v2_compat:
                warn(label, "active entry without last_confirmed — required "
                            "once you migrate to format 3 (a date, or the "
                            "literal unknown)")
            else:
                err(label, "active entry must carry last_confirmed — a date, "
                           "or the literal unknown if you honestly don't know")
        if a.get("type") == "crypto":
            if not a.get("access_pointer"):
                warn(label, "crypto asset without access_pointer — if the executor "
                            "cannot find the keys, this asset is gone")
            if a.get("priority") not in (None, "critical", "high"):
                warn(label, f"crypto asset with priority \"{a.get('priority')}\" — "
                            "a missed wallet is unrecoverable; critical or high "
                            "is expected")
        if a.get("preferred_action") == "transfer" and not a.get("beneficiary"):
            warn(label, "preferred_action is transfer but no beneficiary is "
                        "named — the executor has to guess the recipient")
        for dep in (a.get("depends_on") or []):
            if isinstance(dep, str) and dep not in all_ids:
                err(label, f"depends_on references '{dep}', which does not "
                           "exist in this register")
            elif dep == a.get("id"):
                err(label, "depends_on references itself")
        lc = a.get("last_confirmed")
        if lc == "unknown":
            warn(label, "last_confirmed is unknown — honest, but worth "
                        "confirming at your next review")
        else:
            lc_date = as_date(lc)
            if lc_date is not None and lc_date < stale_before:
                warn(label, f"last_confirmed {lc_date.isoformat()} is over "
                            f"{STALE_MONTHS} months old — re-confirm this entry "
                            "at your next review")

    if not v2_compat and fmt == 3:
        jsonschema_pass(doc, target)

    for w in warnings:
        print(f"  warning  {w}")
    for e in errors:
        print(f"  ERROR    {e}")

    n_assets = len(assets)
    if errors:
        print(f"\n[strict] {target}: {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"\n[strict] {target} is valid — {n_assets} asset(s), "
          f"{len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
