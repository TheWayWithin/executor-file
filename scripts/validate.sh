#!/bin/sh
# validate.sh — check a register before it goes into your Executor File.
#
# Usage:
#   scripts/validate.sh [--strict] [FILE]      (default FILE: estate.yaml)
#
# Baseline tier (this script): pure POSIX sh + awk, no dependencies,
# runs on any Unix machine forever. Checks the constrained YAML this
# toolkit emits: required fields, allowed enum values, unique IDs,
# date formats — and rejects anything that looks like a full account
# number or a written-out credential, because the register must never
# contain secrets.
#
# Strict tier (--strict): additionally runs scripts/validate.py
# (needs python3 + PyYAML) for schema-driven checks, per-entry
# staleness warnings, and coverage checks. If its dependencies are
# missing it says so and fails the strict tier only — the baseline
# above never needs them.
#
# Exit codes: 0 = valid, 1 = validation errors, 2 = couldn't run.
set -u

STRICT=0
IN=""

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    -*) echo "error: unknown option: $arg" >&2; exit 2 ;;
    *) IN="$arg" ;;
  esac
done
IN="${IN:-estate.yaml}"

if [ ! -f "$IN" ]; then
  echo "error: register not found: $IN" >&2
  echo "hint: copy examples/estate.example.yaml to estate.yaml and edit it." >&2
  exit 2
fi

awk '
# ── entry flush + checks ────────────────────────────────────────────
function flush_asset(   f, n, req, lv) {
    if (!in_asset) return
    if ("action" in asset)
        err(alabel() ": field \"action\" was renamed in format 2 — change it to \"preferred_action\" (same values)")
    n = split("id provider type identifier priority ownership status preferred_action action_notes", req, " ")
    for (f = 1; f <= n; f++) {
        if (!(req[f] in asset))
            err(alabel() ": missing required field \"" req[f] "\"")
        else if (asset[req[f]] == "")
            err(alabel() ": required field \"" req[f] "\" is empty")
    }
    if (("id" in asset) && asset["id"] != "") {
        if (asset["id"] !~ /^A[0-9][0-9][0-9]+$/)
            err(alabel() ": id \"" asset["id"] "\" does not match pattern A001, A002, …")
        if (asset["id"] in seen_id)
            err(alabel() ": duplicate id \"" asset["id"] "\" (also used by asset #" seen_id[asset["id"]] ")")
        seen_id[asset["id"]] = asset_n
    }
    enum_check("type",             "cash|liability|subscription|holding|crypto|online-business|other")
    enum_check("priority",         "critical|high|normal|low")
    enum_check("ownership",        "sole|joint|beneficiary-designated|trust|business-owned|unknown")
    enum_check("status",           "active|closed")
    enum_check("preferred_action", "liquidate|cancel|transfer|delete|notify-only")
    if (("last_confirmed" in asset) && asset["last_confirmed"] != "" && !is_date(asset["last_confirmed"]))
        err(alabel() ": last_confirmed should be a date (YYYY-MM-DD), got \"" asset["last_confirmed"] "\"")
    if (asset["type"] == "crypto") {
        if (!("access_pointer" in asset) || asset["access_pointer"] == "")
            warn(alabel() ": crypto asset without access_pointer — if the executor cannot find the keys, this asset is gone")
        if (("priority" in asset) && asset["priority"] !~ /^(critical|high)$/)
            warn(alabel() ": crypto asset with priority \"" asset["priority"] "\" — a missed wallet is unrecoverable; critical or high is expected")
    }
    for (f in asset) {
        if (f != "action" && known_asset !~ ("\\|" f "\\|"))
            warn(alabel() ": unknown field \"" f "\" (typo? not part of the schema)")
        secret_scan(asset[f], alabel() "." f)
    }
    delete asset; in_asset = 0
}
function flush_tool(   f, n, req) {
    if (!in_tool) return
    n = split("platform tool configured", req, " ")
    for (f = 1; f <= n; f++)
        if (!(req[f] in tool) || tool[req[f]] == "")
            err(tlabel() ": missing required field \"" req[f] "\"")
    if (("configured" in tool) && tool["configured"] !~ /^(true|false)$/)
        err(tlabel() ": configured must be true or false, got \"" tool["configured"] "\"")
    for (f in tool) {
        if (known_tool !~ ("\\|" f "\\|"))
            warn(tlabel() ": unknown field \"" f "\" (typo? not part of the schema)")
        secret_scan(tool[f], tlabel() "." f)
    }
    delete tool; in_tool = 0
}
function alabel() { return ("id" in asset && asset["id"] != "") ? "assets[" asset["id"] "]" : "assets[#" asset_n "]" }
function tlabel() { return ("platform" in tool && tool["platform"] != "") ? "platform_legacy_tools[" tool["platform"] "]" : "platform_legacy_tools[#" tool_n "]" }
function enum_check(f, allowed) {
    if ((f in asset) && asset[f] != "" && asset[f] !~ ("^(" allowed ")$"))
        err(alabel() ": field \"" f "\" has invalid value \"" asset[f] "\" (allowed: " allowed ")")
}
function is_date(v) { return v ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ }
function err(msg)  { emsg[++errors] = msg }
function warn(msg) { wmsg[++warnings] = msg }

# ── no-secrets scan: same verdicts as the strict tier ──────────────
# A run of 9+ digits (allowing single spaces/dashes between them) is
# treated as a full account/card number: ERROR. Credential-shaped
# text ("password: x", "PIN = 1234"): WARNING.
function secret_scan(v, where,   i, c, run, sep, lv) {
    run = 0; sep = 0
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c >= "0" && c <= "9") {
            run++; sep = 0
            if (run == 9) {
                err(where ": contains a long digit run — looks like a full account/card number. Use last-4 or a reference only.")
                run = -999  # report once per value
            }
        } else if ((c == " " || c == "-") && run > 0 && sep == 0) sep = 1
        else { run = 0; sep = 0 }
    }
    lv = tolower(v)
    if (lv ~ /(^|[^a-z])(password|passphrase|pin|private key|seed phrase|recovery phrase) *(is|=|:) *[^ ]/)
        warn(where ": looks like it may contain an actual credential (password/PIN/seed written out). The register must hold pointers only — double-check this value.")
}

# ── constrained-YAML line parsing ───────────────────────────────────
function value_of(line,   v) {
    v = line
    sub(/^[^:]*:[ ]*/, "", v)
    sub(/[ ]+#.*$/, "", v)
    if (v ~ /^".*"$/)      { sub(/^"/, "", v);  sub(/"$/, "", v) }
    else if (v ~ /^'"'"'.*'"'"'$/) { sub(/^'"'"'/, "", v); sub(/'"'"'$/, "", v) }
    return v
}
function key_of(line,   k) {
    k = line
    sub(/^[ ]*(- )?/, "", k)
    sub(/:.*$/, "", k)
    return k
}
function start_collect(k, target, indent) { collecting = k; collect_target = target; collect_indent = indent }

BEGIN {
    section = ""; errors = 0; warnings = 0; asset_n = 0; tool_n = 0
    known_meta  = "|format_version|owner|updated|jurisdiction_primary|jurisdiction_secondary|password_manager|notes|"
    known_asset = "|id|provider|type|identifier|priority|ownership|status|last_confirmed|jurisdiction|approx_value|preferred_action|action_notes|access_pointer|"
    known_tool  = "|platform|tool|configured|contact|"
}

/^[ \t]*(#|$)/ { next }

collecting != "" {
    if (match($0, /^[ ]+/) && RLENGTH >= collect_indent) {
        line = $0; sub(/^[ ]+/, "", line)
        if (collect_target == "asset")     asset[collecting] = (asset[collecting] == "" ? line : asset[collecting] " " line)
        else if (collect_target == "tool") tool[collecting]  = (tool[collecting]  == "" ? line : tool[collecting]  " " line)
        else                               meta[collecting]  = (meta[collecting]  == "" ? line : meta[collecting]  " " line)
        next
    }
    collecting = ""
}

/^[a-zA-Z_]+:/ {
    flush_asset(); flush_tool()
    section = $0; sub(/:.*$/, "", section)
    seen_section[section] = 1
    if (section !~ /^(meta|assets|platform_legacy_tools)$/)
        warn(section ": unknown top-level section (typo? not part of the schema)")
    next
}

section == "meta" && /^  [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    meta[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "meta", 4); meta[k] = "" }
    next
}

section == "assets" && /^  - / {
    flush_asset()
    in_asset = 1; asset_n++
    k = key_of($0); v = value_of($0)
    if (k != "") asset[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "asset", 6); asset[k] = "" }
    next
}
section == "assets" && in_asset && /^    [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    asset[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "asset", 6); asset[k] = "" }
    next
}

section == "platform_legacy_tools" && /^  - / {
    flush_tool()
    in_tool = 1; tool_n++
    k = key_of($0); v = value_of($0)
    if (k != "") tool[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "tool", 6); tool[k] = "" }
    next
}
section == "platform_legacy_tools" && in_tool && /^    [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    tool[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "tool", 6); tool[k] = "" }
    next
}

# Anything else is outside the YAML subset this toolkit emits.
{ err("line " FNR ": not recognised — outside the constrained YAML this toolkit emits (check indentation; run --strict for a full YAML parse)") }

END {
    flush_asset(); flush_tool()

    if (!("meta" in seen_section)) err("meta: missing required section")
    else {
        if (!("format_version" in meta) || meta["format_version"] == "") {
            err("meta: no format_version — this file is a format 1 register. To migrate: add \"format_version: 2\" under meta, rename every asset \"action:\" to \"preferred_action:\", and add \"priority:\", \"ownership:\" and \"status:\" to each asset (see examples/estate.example.yaml)")
        } else if (meta["format_version"] != "2") {
            err("meta: format_version is \"" meta["format_version"] "\" — this validator understands format 2 only")
        }
        n = split("owner updated jurisdiction_primary password_manager", req, " ")
        for (f = 1; f <= n; f++)
            if (!(req[f] in meta) || meta[req[f]] == "")
                err("meta: missing required field \"" req[f] "\"")
        if (("updated" in meta) && meta["updated"] != "" && !is_date(meta["updated"]))
            err("meta.updated: expected a date (YYYY-MM-DD), got \"" meta["updated"] "\"")
        for (f in meta) {
            if (known_meta !~ ("\\|" f "\\|"))
                warn("meta: unknown field \"" f "\" (typo? not part of the schema)")
            secret_scan(meta[f], "meta." f)
        }
    }
    if (!("assets" in seen_section)) err("assets: missing required section")
    else if (asset_n == 0)           err("assets: needs at least 1 entry")

    for (i = 1; i <= warnings; i++) print "  warning  " wmsg[i]
    for (i = 1; i <= errors; i++)   print "  ERROR    " emsg[i]

    if (errors > 0) {
        printf "\n[baseline] %s: %d error(s), %d warning(s).\n", FILENAME, errors, warnings
        exit 1
    }
    printf "\n[baseline] %s is valid — %d asset(s), %d warning(s).\n", FILENAME, asset_n, warnings
}
' "$IN"
BASE_RC=$?

[ "$STRICT" -eq 0 ] && exit "$BASE_RC"

# ── strict tier ──────────────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PYTHON="${PYTHON:-python3}"

if ! command -v "$PYTHON" >/dev/null 2>&1 || ! "$PYTHON" -c 'import yaml' >/dev/null 2>&1; then
  echo "" >&2
  echo "[strict] cannot run: needs python3 with PyYAML." >&2
  echo "  quick fix:  python3 -m pip install --user pyyaml" >&2
  echo "  or a venv:  python3 -m venv .venv && .venv/bin/pip install pyyaml" >&2
  echo "              then: PYTHON=.venv/bin/python3 scripts/validate.sh --strict" >&2
  echo "The baseline check above already ran — only the strict tier is failing." >&2
  exit 2
fi

echo ""
"$PYTHON" "$SCRIPT_DIR/validate.py" "$IN"
STRICT_RC=$?

[ "$BASE_RC" -ne 0 ] && exit "$BASE_RC"
exit "$STRICT_RC"
