#!/usr/bin/env python3
"""Strict-tier validator for an Executor File register (format 2).

Driven by schema/estate.schema.yaml so documentation and validator cannot
drift apart. Beyond the zero-dependency baseline (scripts/validate.sh),
this tier adds: type checking of every field, per-entry staleness
warnings (last_confirmed older than 18 months), coverage checks, and —
if the optional `jsonschema` package is installed — validation against
the formal contract in schema/estate.schema.json (JSON Schema 2020-12).

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

# A run of 9+ digits (ignoring single spaces/dashes between them) is
# treated as a full account/card number — those must never be in the register.
DIGIT_RUN = re.compile(r"(?:\d[ -]?){9,}")
# "password: xyz", "PIN = 1234", "seed phrase: word word …" — looks like an
# actual credential written down, not a pointer to one.
SECRET_HINT = re.compile(
    r"(?i)\b(password|passphrase|pin|private key|seed phrase|recovery phrase)\b\s*(is|=|:)\s*\S"
)

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
    return True


def scan_for_secrets(value, where: str) -> None:
    """Recursively scan values for things that must not be in the register."""
    if isinstance(value, str):
        if DIGIT_RUN.search(value):
            err(where, "contains a long digit run — looks like a full account/card "
                       "number. Use last-4 or a reference only.")
        if SECRET_HINT.search(value):
            warn(where, "looks like it may contain an actual credential "
                        "(password/PIN/seed written out). The register must hold "
                        "pointers only — double-check this value.")
    elif isinstance(value, dict):
        for k, v in value.items():
            scan_for_secrets(v, f"{where}.{k}")
    elif isinstance(value, list):
        for i, v in enumerate(value):
            scan_for_secrets(v, f"{where}[{i}]")


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
            err(where, f"field '{name}' should be a {ftype}, got: {value!r}")
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
    """Optional: validate against the formal JSON Schema contract."""
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
                         "(meta / assets / platform_legacy_tools).\n")
        return 1

    # Format gate first: a format-1 register gets a migrate message,
    # never a silent misparse or a wall of field errors.
    meta = doc.get("meta")
    if isinstance(meta, dict) and meta.get("format_version") is None:
        err("meta", "no format_version — this file is a format 1 register. "
            "To migrate: add \"format_version: 2\" under meta, rename every "
            "asset \"action:\" to \"preferred_action:\", and add \"priority:\", "
            "\"ownership:\" and \"status:\" to each asset "
            "(see examples/estate.example.yaml)")

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

    scan_for_secrets(doc, target.name)

    # Coverage and staleness (strict tier only).
    today = datetime.date.today()
    stale_before = today - datetime.timedelta(days=STALE_MONTHS * 30)
    for i, a in enumerate(doc.get("assets") or []):
        if not isinstance(a, dict):
            continue
        label = f"assets[{a.get('id', i)}]"
        if a.get("type") == "crypto":
            if not a.get("access_pointer"):
                warn(label, "crypto asset without access_pointer — if the executor "
                            "cannot find the keys, this asset is gone")
            if a.get("priority") not in (None, "critical", "high"):
                warn(label, f"crypto asset with priority \"{a.get('priority')}\" — "
                            "a missed wallet is unrecoverable; critical or high "
                            "is expected")
        lc = as_date(a.get("last_confirmed"))
        if lc is not None and lc < stale_before:
            warn(label, f"last_confirmed {lc.isoformat()} is over "
                        f"{STALE_MONTHS} months old — re-confirm this entry "
                        "at your next review")

    jsonschema_pass(doc, target)

    for w in warnings:
        print(f"  warning  {w}")
    for e in errors:
        print(f"  ERROR    {e}")

    n_assets = len(doc.get("assets") or []) if isinstance(doc.get("assets"), list) else 0
    if errors:
        print(f"\n[strict] {target}: {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"\n[strict] {target} is valid — {n_assets} asset(s), "
          f"{len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
