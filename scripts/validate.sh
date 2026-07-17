#!/bin/sh
# validate.sh — check a register before it goes into your Executor File.
#
# Usage:
#   scripts/validate.sh [--strict] [FILE]      (default FILE: estate.yaml)
#
# Baseline tier (this script): pure POSIX sh + awk, no dependencies,
# runs on any Unix machine forever. Checks the constrained YAML this
# toolkit emits: required fields, allowed enum values, unique IDs,
# date formats, cross-record depends_on references — and rejects
# anything that looks like a full account number or a written-out
# credential, because the register must never contain credentials.
#
# Understands format 3 (current) and format 2 (accepted this one
# version, with a migrate warning). Lists (jurisdictions, depends_on)
# use the inline [a, b] form — that is the constrained YAML subset
# this toolkit emits.
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
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
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
# ── record collection ───────────────────────────────────────────────
# Entries are collected while parsing and checked in END, once
# format_version is known (v2 and v3 rules differ) and every id has
# been seen (depends_on needs all of them).
function flush_asset(   f) {
    if (!in_asset) return
    for (f in asset) { A[asset_n, f] = asset[f]; AK[asset_n] = AK[asset_n] "|" f }
    delete asset; in_asset = 0
}
function flush_item(   f) {
    if (!in_item) return
    for (f in item) { I[cursec, item_n[cursec], f] = item[f]; IK[cursec, item_n[cursec]] = IK[cursec, item_n[cursec]] "|" f }
    delete item; in_item = 0
}
# ── helpers used at check time ──────────────────────────────────────
function alabel(n) { return (A[n, "id"] != "") ? "assets[" A[n, "id"] "]" : "assets[#" n "]" }
function ilabel(sec, n, keyf,   v) {
    v = I[sec, n, keyf]
    return (v != "") ? sec "[" v "]" : sec "[#" n "]"
}
function is_date(v) { return v ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ }
function err(msg)  { emsg[++errors] = msg }
function warn(msg) { wmsg[++warnings] = msg }
function aenum_check(n, f, allowed) {
    if (akey(n, f) && A[n, f] != "" && A[n, f] !~ ("^(" allowed ")$"))
        err(alabel(n) ": field \"" f "\" has invalid value \"" A[n, f] "\" (allowed: " gensub_pipe(allowed) ")")
}
function gensub_pipe(s,   t) { t = s; gsub(/\|/, ", ", t); return t }
function akey(n, f) { return index(AK[n] "|", "|" f "|") > 0 }
function ikey(sec, n, f) { return index(IK[sec, n] "|", "|" f "|") > 0 }

# ── no-secrets scan: same verdicts as the strict tier ──────────────
# A run of `limit`+ digits (allowing single spaces/dashes between
# them) is treated as a full account/card number: ERROR. The limit is
# 9 everywhere except the contacts section, where phone numbers are
# expected content: there it is 16 (longer than any phone number, and
# still short enough to catch card PANs and IBANs). Credential-shaped
# text ("password: x", "PIN = 1234"): WARNING.
function secret_scan(v, where, limit,   i, c, run, sep, lv) {
    if (limit == 0) limit = 9
    run = 0; sep = 0
    for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c >= "0" && c <= "9") {
            run++; sep = 0
            if (run == limit) {
                err(where ": contains a long digit run — looks like a full account/card number. Use last-4 or a reference only.")
                run = -9999  # report once per value
            }
        } else if ((c == " " || c == "-") && run > 0 && sep == 0) sep = 1
        else { run = 0; sep = 0 }
    }
    lv = tolower(v)
    if (lv ~ /(^|[^a-z])(password|passphrase|pin|private key|seed phrase|recovery phrase) *(is|=|:) *[^ ]/)
        warn(where ": looks like it may contain an actual credential (password/PIN/seed written out). The register must hold pointers only — double-check this value.")
}

# ── inline flow list "[a, b]" -> validated items ────────────────────
function flow_list(v, out,   s, n, i) {
    # returns count, fills out[1..n]; returns -1 if not [..] shaped
    if (v !~ /^\[.*\]$/) return -1
    s = substr(v, 2, length(v) - 2)
    gsub(/[ \t]/, "", s)
    if (s == "") return 0
    n = split(s, out, ",")
    return n
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
    section = ""; errors = 0; warnings = 0; asset_n = 0
    item_n["platform_legacy_tools"] = 0; item_n["contacts"] = 0; item_n["documents"] = 0
    known_meta3 = "|format_version|owner|updated|jurisdictions|domicile|residence|password_manager|notes|"
    known_meta2 = "|format_version|owner|updated|jurisdiction_primary|jurisdiction_secondary|password_manager|notes|"
    known_asset3 = "|id|provider|type|identifier|priority|ownership|status|last_confirmed|jurisdiction|approx_value|preferred_action|first_step|depends_on|beneficiary|billing_cycle|action_notes|access_pointer|"
    known_asset2 = "|id|provider|type|identifier|priority|ownership|status|last_confirmed|jurisdiction|approx_value|preferred_action|action_notes|access_pointer|"
    known_tool  = "|platform|tool|configured|contact|"
    known_contact = "|role|name|pointer|note|"
    known_document = "|name|location|note|"
    ACTIONS3 = "liquidate|cancel|transfer|delete|notify-only|settle|preserve"
    ACTIONS2 = "liquidate|cancel|transfer|delete|notify-only"
}

/^[ \t]*(#|$)/ { next }

collecting != "" {
    if (match($0, /^[ ]+/) && RLENGTH >= collect_indent) {
        line = $0; sub(/^[ ]+/, "", line)
        if (collect_target == "asset")     asset[collecting] = (asset[collecting] == "" ? line : asset[collecting] " " line)
        else if (collect_target == "item") item[collecting]  = (item[collecting]  == "" ? line : item[collecting]  " " line)
        else                               meta[collecting]  = (meta[collecting]  == "" ? line : meta[collecting]  " " line)
        next
    }
    collecting = ""
}

/^[a-zA-Z_]+:/ {
    flush_asset(); flush_item()
    section = $0; sub(/:.*$/, "", section)
    seen_section[section] = 1
    if (section !~ /^(meta|assets|contacts|documents|platform_legacy_tools)$/)
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
    AK[asset_n] = "|"
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

section ~ /^(platform_legacy_tools|contacts|documents)$/ && /^  - / {
    flush_item()
    in_item = 1; cursec = section; item_n[cursec]++
    IK[cursec, item_n[cursec]] = "|"
    k = key_of($0); v = value_of($0)
    if (k != "") item[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "item", 6); item[k] = "" }
    next
}
section ~ /^(platform_legacy_tools|contacts|documents)$/ && in_item && /^    [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    item[k] = v
    if (v ~ /^[>|]-?$/) { start_collect(k, "item", 6); item[k] = "" }
    next
}

# Anything else is outside the YAML subset this toolkit emits.
{ err("line " FNR ": not recognised — outside the constrained YAML this toolkit emits (check indentation; run --strict for a full YAML parse)") }

END {
    flush_asset(); flush_item()

    # ── format gate ─────────────────────────────────────────────────
    fmt = ("format_version" in meta) ? meta["format_version"] : ""
    v2 = 0
    if (!("meta" in seen_section)) {
        err("meta: missing required section")
    } else if (fmt == "") {
        err("meta: no format_version — this file is a format 1 register. To migrate: add \"format_version: 3\" under meta, rename every asset \"action:\" to \"preferred_action:\", add \"priority:\", \"ownership:\" and \"status:\" to each asset, replace the jurisdiction fields with \"jurisdictions: [...]\", and give active assets a last_confirmed (see examples/estate.example.yaml)")
    } else if (fmt == "2") {
        v2 = 1
        warn("meta: format_version is 2 — still accepted this version, but to migrate: set format_version: 3; replace jurisdiction_primary/jurisdiction_secondary with e.g. \"jurisdictions: [US-NY, UK]\"; give every active asset a last_confirmed (a date, or the literal unknown)")
    } else if (fmt != "3") {
        err("meta: format_version is \"" fmt "\" — this validator understands formats 2 (deprecated) and 3")
    }

    known_meta  = v2 ? known_meta2  : known_meta3
    known_asset = v2 ? known_asset2 : known_asset3
    ACTIONS     = v2 ? ACTIONS2     : ACTIONS3

    # ── meta ────────────────────────────────────────────────────────
    if ("meta" in seen_section) {
        if (v2) n = split("owner updated jurisdiction_primary password_manager", req, " ")
        else    n = split("owner updated jurisdictions password_manager", req, " ")
        for (f = 1; f <= n; f++)
            if (!(req[f] in meta) || meta[req[f]] == "")
                err("meta: missing required field \"" req[f] "\"")
        if (("updated" in meta) && meta["updated"] != "" && !is_date(meta["updated"]))
            err("meta.updated: expected a date (YYYY-MM-DD), got \"" meta["updated"] "\"")
        if (!v2 && ("jurisdictions" in meta) && meta["jurisdictions"] != "") {
            nj = flow_list(meta["jurisdictions"], jl)
            if (nj == -1)
                err("meta.jurisdictions: expected an inline list like [US-NY, UK], got \"" meta["jurisdictions"] "\"")
            else if (nj == 0)
                err("meta.jurisdictions: the list is empty — name at least one jurisdiction")
        }
        for (f in meta) {
            if (known_meta !~ ("\\|" f "\\|")) {
                if (!v2 && (f == "jurisdiction_primary" || f == "jurisdiction_secondary"))
                    err("meta: \"" f "\" was replaced in format 3 — fold it into \"jurisdictions: [...]\"")
                else
                    warn("meta: unknown field \"" f "\" (typo? not part of the schema)")
            }
            secret_scan(meta[f], "meta." f)
        }
    }

    # ── assets ──────────────────────────────────────────────────────
    if (!("assets" in seen_section)) err("assets: missing required section")
    else if (asset_n == 0)           err("assets: needs at least 1 entry")

    for (i = 1; i <= asset_n; i++)
        if (A[i, "id"] != "") ids[A[i, "id"]] = i

    n = split("id provider type identifier priority ownership status preferred_action action_notes", req, " ")
    for (i = 1; i <= asset_n; i++) {
        if (akey(i, "action"))
            err(alabel(i) ": field \"action\" was renamed in format 2 — change it to \"preferred_action\" (same values)")
        for (f = 1; f <= n; f++) {
            if (!akey(i, req[f]))
                err(alabel(i) ": missing required field \"" req[f] "\"")
            else if (A[i, req[f]] == "")
                err(alabel(i) ": required field \"" req[f] "\" is empty")
        }
        if (A[i, "id"] != "") {
            if (A[i, "id"] !~ /^A[0-9][0-9][0-9]+$/)
                err(alabel(i) ": id \"" A[i, "id"] "\" does not match pattern A001, A002, …")
            if (ids[A[i, "id"]] != i)
                err(alabel(i) ": duplicate id \"" A[i, "id"] "\" (also used by asset #" ids[A[i, "id"]] ")")
        }
        aenum_check(i, "type",             "cash|liability|subscription|holding|crypto|online-business|other")
        aenum_check(i, "priority",         "critical|high|normal|low")
        aenum_check(i, "ownership",        "sole|joint|beneficiary-designated|trust|business-owned|unknown")
        aenum_check(i, "status",           "active|closed")
        aenum_check(i, "preferred_action", ACTIONS)
        aenum_check(i, "billing_cycle",    "monthly|annual|one-off")
        lc = A[i, "last_confirmed"]
        if (akey(i, "last_confirmed") && lc != "" && lc != "unknown" && !is_date(lc))
            err(alabel(i) ": last_confirmed should be a date (YYYY-MM-DD) or the literal unknown, got \"" lc "\"")
        if (A[i, "status"] == "active" && (!akey(i, "last_confirmed") || lc == "")) {
            if (v2)
                warn(alabel(i) ": active entry without last_confirmed — required once you migrate to format 3 (a date, or the literal unknown)")
            else
                err(alabel(i) ": active entry must carry last_confirmed — a date, or the literal unknown if you honestly do not know")
        }
        if (akey(i, "depends_on") && A[i, "depends_on"] != "") {
            nd = flow_list(A[i, "depends_on"], dl)
            if (nd == -1)
                err(alabel(i) ": depends_on: expected an inline list like [A006], got \"" A[i, "depends_on"] "\"")
            else for (d = 1; d <= nd; d++) {
                if (dl[d] !~ /^A[0-9][0-9][0-9]+$/)
                    err(alabel(i) ": depends_on entry \"" dl[d] "\" is not a record ID (A001, A002, …)")
                else if (!(dl[d] in ids))
                    err(alabel(i) ": depends_on references \"" dl[d] "\", which does not exist in this register")
                else if (dl[d] == A[i, "id"])
                    err(alabel(i) ": depends_on references itself")
            }
        }
        if (A[i, "type"] == "crypto") {
            if (!akey(i, "access_pointer") || A[i, "access_pointer"] == "")
                warn(alabel(i) ": crypto asset without access_pointer — if the executor cannot find the keys, this asset is gone")
            if (akey(i, "priority") && A[i, "priority"] !~ /^(critical|high)$/)
                warn(alabel(i) ": crypto asset with priority \"" A[i, "priority"] "\" — a missed wallet is unrecoverable; critical or high is expected")
        }
        if (A[i, "preferred_action"] == "transfer" && (!akey(i, "beneficiary") || A[i, "beneficiary"] == ""))
            warn(alabel(i) ": preferred_action is transfer but no beneficiary is named — the executor has to guess the recipient")
        nf = split(AK[i], fl, "|")
        for (f = 1; f <= nf; f++) {
            if (fl[f] == "") continue
            if (fl[f] != "action" && known_asset !~ ("\\|" fl[f] "\\|")) {
                if (v2 && (fl[f] == "first_step" || fl[f] == "depends_on" || fl[f] == "beneficiary" || fl[f] == "billing_cycle"))
                    warn(alabel(i) ": field \"" fl[f] "\" is a format 3 field — set format_version: 3 to use it")
                else
                    warn(alabel(i) ": unknown field \"" fl[f] "\" (typo? not part of the schema)")
            }
            secret_scan(A[i, fl[f]], alabel(i) "." fl[f])
        }
    }

    # ── list sections: platform_legacy_tools, contacts, documents ───
    for (i = 1; i <= item_n["platform_legacy_tools"]; i++) {
        lab = ilabel("platform_legacy_tools", i, "platform")
        n = split("platform tool configured", req, " ")
        for (f = 1; f <= n; f++)
            if (!ikey("platform_legacy_tools", i, req[f]) || I["platform_legacy_tools", i, req[f]] == "")
                err(lab ": missing required field \"" req[f] "\"")
        if (ikey("platform_legacy_tools", i, "configured") && I["platform_legacy_tools", i, "configured"] !~ /^(true|false)$/)
            err(lab ": configured must be true or false, got \"" I["platform_legacy_tools", i, "configured"] "\"")
        nf = split(IK["platform_legacy_tools", i], fl, "|")
        for (f = 1; f <= nf; f++) {
            if (fl[f] == "") continue
            if (known_tool !~ ("\\|" fl[f] "\\|"))
                warn(lab ": unknown field \"" fl[f] "\" (typo? not part of the schema)")
            secret_scan(I["platform_legacy_tools", i, fl[f]], lab "." fl[f])
        }
    }
    for (i = 1; i <= item_n["contacts"]; i++) {
        lab = ilabel("contacts", i, "name")
        n = split("role name", req, " ")
        for (f = 1; f <= n; f++)
            if (!ikey("contacts", i, req[f]) || I["contacts", i, req[f]] == "")
                err(lab ": missing required field \"" req[f] "\"")
        nf = split(IK["contacts", i], fl, "|")
        for (f = 1; f <= nf; f++) {
            if (fl[f] == "") continue
            if (known_contact !~ ("\\|" fl[f] "\\|"))
                warn(lab ": unknown field \"" fl[f] "\" (typo? not part of the schema)")
            secret_scan(I["contacts", i, fl[f]], lab "." fl[f], 16)
        }
    }
    for (i = 1; i <= item_n["documents"]; i++) {
        lab = ilabel("documents", i, "name")
        n = split("name location", req, " ")
        for (f = 1; f <= n; f++)
            if (!ikey("documents", i, req[f]) || I["documents", i, req[f]] == "")
                err(lab ": missing required field \"" req[f] "\"")
        nf = split(IK["documents", i], fl, "|")
        for (f = 1; f <= nf; f++) {
            if (fl[f] == "") continue
            if (known_document !~ ("\\|" fl[f] "\\|"))
                warn(lab ": unknown field \"" fl[f] "\" (typo? not part of the schema)")
            secret_scan(I["documents", i, fl[f]], lab "." fl[f])
        }
    }
    if ((item_n["contacts"] > 0 || item_n["documents"] > 0) && v2)
        warn("contacts/documents: format 3 sections — set format_version: 3 to use them")

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
