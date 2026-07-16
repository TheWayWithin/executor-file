#!/usr/bin/env python3
"""Validate an estate register against schema/estate.schema.yaml.

Checks structure (required fields, types, enums, unique IDs) and — because
the register's core promise is "no secrets stored" — rejects values that
look like full account numbers and flags values that look like credentials.

Exit codes: 0 = valid, 1 = validation errors, 2 = couldn't run.
"""

import datetime
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "error: this validator needs the PyYAML library.\n"
        "  quick fix:  python3 -m pip install --user pyyaml\n"
        "  or a venv:  python3 -m venv .venv && .venv/bin/pip install pyyaml\n"
        "              then: PYTHON=.venv/bin/python3 scripts/validate.sh\n"
        "(Only the validator needs Python. Encrypt/decrypt/split do not,\n"
        "and your executor never needs any of this.)\n"
    )
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "estate.schema.yaml"

# A run of 9+ digits (ignoring spaces/dashes between them) is treated as a
# full account/card number — those must never be in the register.
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


def type_ok(value, expected: str) -> bool:
    if expected == "string" or expected == "enum":
        return isinstance(value, str) and value.strip() != ""
    if expected == "bool":
        return isinstance(value, bool)
    if expected == "date":
        if isinstance(value, datetime.date):
            return True
        if isinstance(value, str):
            try:
                datetime.date.fromisoformat(value)
                return True
            except ValueError:
                return False
        return False
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
        if "pattern" in spec and isinstance(value, str):
            if not re.fullmatch(spec["pattern"], value):
                err(where, f"field '{name}' value '{value}' does not match "
                           f"pattern {spec['pattern']}")
    for name in data:
        if name not in field_specs:
            warn(where, f"unknown field '{name}' (typo? not part of the schema)")


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
            check_fields(sec, sec_spec["fields"], sec_name)
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

    # Nudge: a crypto asset without an access pointer is a wallet the
    # executor may never find.
    for i, a in enumerate(doc.get("assets") or []):
        if isinstance(a, dict) and a.get("type") == "crypto":
            if not a.get("access_pointer"):
                warn(f"assets[{a.get('id', i)}]",
                     "crypto asset without access_pointer — if the executor "
                     "can't find the keys, this asset is gone.")

    for w in warnings:
        print(f"  warning  {w}")
    for e in errors:
        print(f"  ERROR    {e}")

    n_assets = len(doc.get("assets") or []) if isinstance(doc.get("assets"), list) else 0
    if errors:
        print(f"\n✗ {target}: {len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"\n✓ {target} is valid — {n_assets} asset(s), "
          f"{len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
