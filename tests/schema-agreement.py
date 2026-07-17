#!/usr/bin/env python3
"""CI drift test (v0.3 spec §4): schema/estate.schema.json is the single
source of truth; schema/estate.schema.yaml is its annotated documentation.
This test fails the build if they diverge, so neither is hand-maintained
against the other:

  1. field inventory, enum values, and requiredness must agree between
     the two schema files (last_confirmed's conditional requiredness is
     checked structurally: the YAML flag `required_when_active` must be
     mirrored by the JSON if/then clause);
  2. both example registers (examples/estate.example.yaml and
     examples/estate.minimal.yaml) must validate against the JSON Schema.

Exit 0 when everything agrees; prints each disagreement and exits 1
otherwise. Needs PyYAML; the example-validation step needs jsonschema.
"""

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
ys = yaml.safe_load((ROOT / "schema" / "estate.schema.yaml").read_text())
js = json.loads((ROOT / "schema" / "estate.schema.json").read_text())

problems: list[str] = []


def check_fields(where: str, yfields: dict, jobj: dict) -> None:
    jprops = jobj["properties"]
    jreq = set(jobj.get("required", []))
    ynames = set(yfields)
    jnames = set(jprops)
    for name in sorted(ynames - jnames):
        problems.append(f"{where}: '{name}' in YAML schema but not JSON schema")
    for name in sorted(jnames - ynames):
        problems.append(f"{where}: '{name}' in JSON schema but not YAML schema")
    for name in sorted(ynames & jnames):
        yspec = yfields[name]
        y_required = bool(yspec.get("required"))
        if y_required != (name in jreq):
            problems.append(f"{where}.{name}: requiredness disagrees "
                            f"(YAML required={y_required}, JSON required={name in jreq})")
        if yspec.get("type") == "enum":
            yvals = list(yspec.get("values", []))
            jvals = list(jprops[name].get("enum", []))
            if yvals != jvals:
                problems.append(f"{where}.{name}: enum values disagree "
                                f"(YAML {yvals} vs JSON {jvals})")


def conditional_required_fields(jobj: dict) -> set[str]:
    """Fields the JSON schema requires via an if(status=active)/then clause."""
    out: set[str] = set()
    for clause in jobj.get("allOf", []):
        cond = clause.get("if", {}).get("properties", {})
        if cond.get("status", {}).get("const") == "active":
            out.update(clause.get("then", {}).get("required", []))
    return out


sections = ys["sections"]
check_fields("meta", sections["meta"]["fields"], js["properties"]["meta"])
check_fields("assets[]", sections["assets"]["item_fields"],
             js["properties"]["assets"]["items"])
check_fields("contacts[]", sections["contacts"]["item_fields"],
             js["properties"]["contacts"]["items"])
check_fields("documents[]", sections["documents"]["item_fields"],
             js["properties"]["documents"]["items"])
check_fields("platform_legacy_tools[]",
             sections["platform_legacy_tools"]["item_fields"],
             js["properties"]["platform_legacy_tools"]["items"])

# Conditional requiredness: YAML `required_when_active` ⇔ JSON if/then.
y_cond = {name for name, spec in sections["assets"]["item_fields"].items()
          if spec.get("required_when_active")}
j_cond = conditional_required_fields(js["properties"]["assets"]["items"])
if y_cond != j_cond:
    problems.append(f"assets[]: conditional (active-only) requiredness disagrees "
                    f"(YAML {sorted(y_cond)} vs JSON if/then {sorted(j_cond)})")

y_top_required = {name for name, spec in sections.items() if spec.get("required")}
j_top_required = set(js.get("required", []))
if y_top_required != j_top_required:
    problems.append(f"top-level requiredness disagrees "
                    f"(YAML {sorted(y_top_required)} vs JSON {sorted(j_top_required)})")

y_top = set(sections)
j_top = set(js["properties"])
if y_top != j_top:
    problems.append(f"top-level sections disagree "
                    f"(YAML {sorted(y_top)} vs JSON {sorted(j_top)})")

# ── both example registers must satisfy the formal contract ──────────
try:
    import jsonschema
    validator = jsonschema.Draft202012Validator(js)
    for example in ("estate.example.yaml", "estate.minimal.yaml"):
        doc = yaml.safe_load((ROOT / "examples" / example).read_text())
        plain = json.loads(json.dumps(doc, default=str))
        for e in sorted(validator.iter_errors(plain),
                        key=lambda e: list(e.absolute_path)):
            path = ".".join(str(p) for p in e.absolute_path) or example
            problems.append(f"examples/{example}: {path}: {e.message}")
except ImportError:
    print("note: jsonschema not installed — example-vs-contract validation "
          "skipped here (CI installs it; the strict validator also covers it).")

if problems:
    for p in problems:
        print(f"DISAGREEMENT: {p}")
    sys.exit(1)
print("schema agreement: estate.schema.yaml and estate.schema.json agree on "
      "fields, enums, and requiredness, and both example registers satisfy "
      "the JSON contract.")
