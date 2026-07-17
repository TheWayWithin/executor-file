#!/usr/bin/env python3
"""CI check (SPEC-v1 §5.5): the annotated YAML schema and the formal
JSON Schema must agree on fields, enums, and requiredness.

Exit 0 when they agree; prints each disagreement and exits 1 otherwise.
Needs PyYAML.
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


sections = ys["sections"]
check_fields("meta", sections["meta"]["fields"], js["properties"]["meta"])
check_fields("assets[]", sections["assets"]["item_fields"],
             js["properties"]["assets"]["items"])
check_fields("platform_legacy_tools[]",
             sections["platform_legacy_tools"]["item_fields"],
             js["properties"]["platform_legacy_tools"]["items"])

y_top_required = {name for name, spec in sections.items() if spec.get("required")}
j_top_required = set(js.get("required", []))
if y_top_required != j_top_required:
    problems.append(f"top-level requiredness disagrees "
                    f"(YAML {sorted(y_top_required)} vs JSON {sorted(j_top_required)})")

if problems:
    for p in problems:
        print(f"DISAGREEMENT: {p}")
    sys.exit(1)
print("schema agreement: estate.schema.yaml and estate.schema.json agree "
      "on fields, enums, and requiredness.")
