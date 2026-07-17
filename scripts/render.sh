#!/bin/sh
# render.sh — turn the decrypted register into the executor's triage
# report: what to do first, what is bleeding money, and what I wanted
# done with everything — in plain English, ordered for a stressed
# reader. The YAML stays the source of truth; this report is the
# interface.
#
# Usage:
#   scripts/render.sh [FILE]         (default FILE: estate.yaml)
#
# Writes, next to FILE:
#   executor-report.md      readable in any text editor
#   executor-report.html    the same report, printable (open in a
#                           browser, then File > Print)
#
# Pure POSIX sh + awk — no dependencies, so it runs on the same
# trusted machine the recovery just happened on. Understands format 3
# and format 2 registers.
#
# HANDLE THE REPORT LIKE THE REGISTER ITSELF: it is the full map of
# the estate. Don't email it unencrypted, don't upload it anywhere,
# don't paste it into AI tools.
#
# Exit codes: 0 = written, 1 = register unreadable, 2 = usage.
set -u

IN="${1:-estate.yaml}"
case "$IN" in
  -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
esac

if [ ! -f "$IN" ]; then
  echo "error: register not found: $IN" >&2
  echo "hint: decrypt your Executor File first (age -d -o estate.yaml estate.yaml.age)" >&2
  exit 2
fi

DIR=$(dirname "$IN")
MD="$DIR/executor-report.md"
HTML="$DIR/executor-report.html"
TODAY="$(date +%Y-%m-%d)"

render() { # $1 = md|html
awk -v fmt="$1" -v today="$TODAY" '
# ── tiny format layer ───────────────────────────────────────────────
function esc(s,   t) {
    if (fmt != "html") return s
    t = s
    gsub(/&/, "\\&amp;", t); gsub(/</, "\\&lt;", t); gsub(/>/, "\\&gt;", t)
    return t
}
function H(level, text) {
    if (fmt == "html") print "<h" level ">" esc(text) "</h" level ">"
    else { print ""; print substr("######", 1, level) " " text; print "" }
}
function P(text) {
    if (fmt == "html") print "<p>" esc(text) "</p>"
    else { print text; print "" }
}
function OPEN_ENTRY()  { if (fmt == "html") print "<div class=\"entry\">" }
function CLOSE_ENTRY() { if (fmt == "html") print "</div>" }
function LINE1(text) {
    if (fmt == "html") print "<p class=\"e1\"><strong>" esc(text) "</strong></p>"
    else print "- **" text "**"
}
function SUB(label, text) {
    if (text == "") return
    if (fmt == "html") print "<p class=\"e2\"><em>" esc(label) ":</em> " esc(text) "</p>"
    else print "  - " label ": " text
}

# ── constrained-YAML parsing (same subset as validate.sh) ───────────
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
function flush_asset(   f) {
    if (!in_asset) return
    for (f in asset) A[asset_n, f] = asset[f]
    delete asset; in_asset = 0
}
function flush_item(   f) {
    if (!in_item) return
    for (f in item) I[cursec, item_n[cursec], f] = item[f]
    delete item; in_item = 0
}

# ── report helpers ──────────────────────────────────────────────────
function prio_rank(p) {
    if (p == "critical") return 0
    if (p == "high")     return 1
    if (p == "low")      return 3
    return 2
}
function cycle_rank(c) {
    if (c == "monthly") return 0
    if (c == "annual")  return 1
    if (c == "one-off") return 2
    return 3
}
function is_active(n) { return A[n, "status"] != "closed" }
function months_old(d,   y, m, ty, tm) {
    if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-/) return -1
    y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0
    ty = substr(today, 1, 4) + 0; tm = substr(today, 6, 2) + 0
    return (ty * 12 + tm) - (y * 12 + m)
}
function is_stale(n,   lc) {
    lc = A[n, "last_confirmed"]
    if (lc == "" || lc == "unknown") return 1
    return months_old(lc) > 18
}
function headline(n,   s, v) {
    s = A[n, "id"] " · " A[n, "provider"] " — " A[n, "identifier"]
    s = s " (" A[n, "type"]
    if (A[n, "ownership"] != "") s = s ", " A[n, "ownership"]
    if (A[n, "priority"] != "")  s = s ", priority " A[n, "priority"]
    s = s ")"
    v = A[n, "approx_value"]
    if (v != "") s = s " — " v
    return s
}
function dep_line(n,   out, deps, d, nd, ref, s) {
    s = A[n, "depends_on"]
    if (s == "" || s !~ /^\[.*\]$/) return ""
    gsub(/[][ ]/, "", s)
    nd = split(s, deps, ",")
    out = ""
    for (d = 1; d <= nd; d++) {
        ref = deps[d]
        if (ref in id_row)
            out = out ((out == "") ? "" : "; ") "deal with " ref " (" A[id_row[ref], "provider"] ") first"
        else
            out = out ((out == "") ? "" : "; ") "deal with " ref " first (not found in this register!)"
    }
    return out
}
function action_text(n,   a, t) {
    a = A[n, "preferred_action"]
    if (a == "liquidate") t = "liquidate — sell/withdraw the value into the estate"
    else if (a == "cancel") t = "cancel the service or charge"
    else if (a == "transfer") {
        t = "transfer to " ((A[n, "beneficiary"] != "") ? A[n, "beneficiary"] : "— NO BENEFICIARY NAMED — check the will and notes")
    }
    else if (a == "delete") t = "close the account and erase the contents"
    else if (a == "notify-only") t = "notify the provider; nothing else expected"
    else if (a == "settle") t = "settle — pay off from the estate"
    else if (a == "preserve") t = "preserve — keep it alive and intact"
    else t = a
    return t
}
function emit(n) {
    OPEN_ENTRY()
    LINE1(headline(n))
    SUB("First", A[n, "first_step"])
    SUB("Order", dep_line(n))
    SUB("What I want done", action_text(n))
    if (A[n, "billing_cycle"] != "") SUB("Bills", A[n, "billing_cycle"])
    SUB("Notes", A[n, "action_notes"])
    SUB("Where the login lives", A[n, "access_pointer"])
    if (is_stale(n)) {
        lc = A[n, "last_confirmed"]
        SUB("Freshness", (lc == "" || lc == "unknown") ? "never confirmed — verify this entry still exists before spending time on it" : "last confirmed " lc " — old; verify before spending time on it")
    }
    CLOSE_ENTRY()
}
# selection-sort rows[1..cnt] by key K[row]
function sort_rows(cnt,   i, j, min, t) {
    for (i = 1; i < cnt; i++) {
        min = i
        for (j = i + 1; j <= cnt; j++)
            if (SK[rows[j]] < SK[rows[min]]) min = j
        t = rows[i]; rows[i] = rows[min]; rows[min] = t
    }
}
function pad(x) { return sprintf("%04d", x) }

BEGIN { section = ""; asset_n = 0; item_n["platform_legacy_tools"] = 0; item_n["contacts"] = 0; item_n["documents"] = 0 }

/^[ \t]*(#|$)/ { next }

collecting != "" {
    if (match($0, /^[ ]+/) && RLENGTH >= collect_indent) {
        line = $0; sub(/^[ ]+/, "", line); sub(/[ \t]+$/, "", line)
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
    next
}
section == "meta" && /^  [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    meta[k] = v
    if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "meta"; collect_indent = 4; meta[k] = "" }
    next
}
section == "assets" && /^  - / {
    flush_asset(); in_asset = 1; asset_n++
    k = key_of($0); v = value_of($0)
    if (k != "") asset[k] = v
    if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "asset"; collect_indent = 6; asset[k] = "" }
    next
}
section == "assets" && in_asset && /^    [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    asset[k] = v
    if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "asset"; collect_indent = 6; asset[k] = "" }
    next
}
section ~ /^(platform_legacy_tools|contacts|documents)$/ && /^  - / {
    flush_item(); in_item = 1; cursec = section; item_n[cursec]++
    k = key_of($0); v = value_of($0)
    if (k != "") item[k] = v
    if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "item"; collect_indent = 6; item[k] = "" }
    next
}
section ~ /^(platform_legacy_tools|contacts|documents)$/ && in_item && /^    [a-zA-Z_]+:/ {
    k = key_of($0); v = value_of($0)
    item[k] = v
    if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "item"; collect_indent = 6; item[k] = "" }
    next
}
{ next }

END {
    flush_asset(); flush_item()

    for (i = 1; i <= asset_n; i++)
        if (A[i, "id"] != "") id_row[A[i, "id"]] = i
    # which assets are depended upon by an active asset?
    for (i = 1; i <= asset_n; i++) {
        if (!is_active(i)) continue
        s = A[i, "depends_on"]
        if (s == "" || s !~ /^\[.*\]$/) continue
        gsub(/[][ ]/, "", s)
        nd = split(s, deps, ",")
        for (d = 1; d <= nd; d++)
            if (deps[d] in id_row) depended[id_row[deps[d]]] = 1
    }
    n_active = 0; n_closed = 0
    for (i = 1; i <= asset_n; i++) { if (is_active(i)) n_active++; else n_closed++ }

    # ── document head ───────────────────────────────────────────────
    if (fmt == "html") {
        print "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">"
        print "<title>Executor report — " esc(meta["owner"]) "</title>"
        print "<style>"
        print "body{font-family:Georgia,serif;max-width:50rem;margin:2rem auto;padding:0 1rem;color:#111;line-height:1.45}"
        print "h1{font-size:1.6rem;border-bottom:2px solid #111;padding-bottom:.3rem}"
        print "h2{font-size:1.2rem;margin-top:1.6rem;border-bottom:1px solid #999;padding-bottom:.2rem;page-break-after:avoid}"
        print ".entry{margin:.7rem 0;padding:.4rem .6rem;border-left:3px solid #bbb;page-break-inside:avoid}"
        print ".e1{margin:0}"
        print ".e2{margin:.15rem 0 0 .8rem;font-size:.95rem}"
        print ".note{background:#f5f5f0;padding:.6rem .8rem;border:1px solid #ddd}"
        print "@media print{body{margin:0 auto;font-size:11pt}}"
        print "</style></head><body>"
    }

    H(1, "Executor report — the estate of " meta["owner"])
    P("Generated " today " from the register last reviewed " meta["updated"] ". " \
      n_active " active entries, " n_closed " closed (recorded for the trail; no action needed). " \
      "The register file itself (estate.yaml) is the source of truth — this report just puts it in working order.")
    if (fmt == "html") print "<div class=\"note\">"
    P("How to work: PRESERVE BEFORE YOU DISPOSE. Secure devices, recovery material, and anything a business depends on first; understand your legal authority (probate, joint ownership, beneficiary designations) before moving anything; then stop money bleeding out; then the rest. Nothing here overrides the will. For any provider, searching \"<provider name> bereavement\" usually finds their process. Treat this report exactly like the register: never email it unencrypted, never upload it, never paste it into AI tools.")
    if (fmt == "html") print "</div>"

    # ── 1. do first ─────────────────────────────────────────────────
    H(2, "Do first — secure, do not dispose")
    cnt = 0
    for (i = 1; i <= asset_n; i++) {
        if (!is_active(i)) continue
        if (A[i, "first_step"] != "" || depended[i] || A[i, "priority"] == "critical") {
            rows[++cnt] = i
            SK[i] = (depended[i] ? "0" : "1") pad(prio_rank(A[i, "priority"])) A[i, "id"]
        }
    }
    if (cnt == 0) P("(Nothing needs securing before the general order below.)")
    sort_rows(cnt)
    for (i = 1; i <= cnt; i++) emit(rows[i])

    # ── 2. money bleeding out ───────────────────────────────────────
    H(2, "Money bleeding out — recurring charges and debts")
    cnt = 0
    for (i = 1; i <= asset_n; i++) {
        if (!is_active(i)) continue
        if (A[i, "type"] == "liability" || A[i, "type"] == "subscription" || A[i, "billing_cycle"] != "") {
            rows[++cnt] = i
            SK[i] = pad(cycle_rank(A[i, "billing_cycle"])) pad(prio_rank(A[i, "priority"])) A[i, "id"]
        }
    }
    if (cnt == 0) P("(No recurring charges or debts recorded.)")
    sort_rows(cnt)
    for (i = 1; i <= cnt; i++) emit(rows[i])

    # ── 3-7. by disposition ─────────────────────────────────────────
    n_secs = split("liquidate settle transfer preserve rest", secs, " ")
    sec_title["liquidate"] = "Assets to liquidate"
    sec_title["settle"]    = "Debts to settle"
    sec_title["transfer"]  = "To transfer"
    sec_title["preserve"]  = "To preserve — keep these alive"
    sec_title["rest"]      = "To cancel, delete, or just notify"
    for (sx = 1; sx <= n_secs; sx++) {
        a = secs[sx]
        H(2, sec_title[a])
        cnt = 0
        for (i = 1; i <= asset_n; i++) {
            if (!is_active(i)) continue
            act = A[i, "preferred_action"]
            hit = (a == "rest") ? (act == "cancel" || act == "delete" || act == "notify-only") : (act == a)
            if (hit) { rows[++cnt] = i; SK[i] = pad(prio_rank(A[i, "priority"])) A[i, "id"] }
        }
        if (cnt == 0) { P("(None.)"); continue }
        sort_rows(cnt)
        for (i = 1; i <= cnt; i++) emit(rows[i])
    }

    # ── 8. stale or unconfirmed ─────────────────────────────────────
    H(2, "Stale or unconfirmed entries — verify these exist before spending time")
    cnt = 0
    for (i = 1; i <= asset_n; i++)
        if (is_active(i) && is_stale(i)) { rows[++cnt] = i; SK[i] = pad(prio_rank(A[i, "priority"])) A[i, "id"] }
    if (cnt == 0) P("(Every active entry was confirmed recently. Trust the register.)")
    else P("These entries were not confirmed recently (or ever). They may have been closed or moved since — check before acting.")
    sort_rows(cnt)
    for (i = 1; i <= cnt; i++) {
        OPEN_ENTRY()
        lc = A[rows[i], "last_confirmed"]
        LINE1(headline(rows[i]))
        SUB("Last confirmed", (lc == "" || lc == "unknown") ? "never" : lc)
        CLOSE_ENTRY()
    }

    # ── 9. incomplete legacy tools ──────────────────────────────────
    H(2, "Platform legacy settings — incomplete ones first")
    tn = item_n["platform_legacy_tools"]
    if (tn == 0) {
        P("(No platform legacy tools recorded. If there are Apple/Google/Meta accounts, their own legacy settings — or their absence — control access, and under US law (RUFADAA) they outrank the will.)")
    } else {
        P("These platform settings legally outrank the will in the US (RUFADAA). Coordinate with the people named; where a tool was never configured, expect the standard bereavement process of that provider instead.")
        for (i = 1; i <= tn; i++) {
            OPEN_ENTRY()
            conf = I["platform_legacy_tools", i, "configured"]
            s = I["platform_legacy_tools", i, "platform"] " — " I["platform_legacy_tools", i, "tool"]
            s = s ((conf == "true") ? ": configured" : ": NOT CONFIGURED")
            LINE1(s)
            SUB("Named contact", I["platform_legacy_tools", i, "contact"])
            CLOSE_ENTRY()
        }
    }

    # ── contacts + documents ────────────────────────────────────────
    if (item_n["contacts"] > 0) {
        H(2, "People to call")
        for (i = 1; i <= item_n["contacts"]; i++) {
            OPEN_ENTRY()
            LINE1(I["contacts", i, "name"] " (" I["contacts", i, "role"] ")")
            SUB("Reach", I["contacts", i, "pointer"])
            SUB("Note", I["contacts", i, "note"])
            CLOSE_ENTRY()
        }
    }
    if (item_n["documents"] > 0) {
        H(2, "Where the paper lives")
        for (i = 1; i <= item_n["documents"]; i++) {
            OPEN_ENTRY()
            LINE1(I["documents", i, "name"] " — " I["documents", i, "location"])
            SUB("Note", I["documents", i, "note"])
            CLOSE_ENTRY()
        }
    }

    P("— end of report. Delete this file and the register when the estate is settled; until then, they stay on this computer only.")
    if (fmt == "html") print "</body></html>"
}
' "$IN"
}

render md   > "$MD"   || { rm -f "$MD" "$HTML"; echo "error: could not render $IN" >&2; exit 1; }
render html > "$HTML" || { rm -f "$HTML"; echo "error: could not render HTML" >&2; exit 1; }

echo "Wrote:"
echo "  $MD    (read in any text editor)"
echo "  $HTML  (open in a browser, then File > Print for paper)"
echo
echo "Handle both files like the register itself: full estate map,"
echo "this computer only, never emailed unencrypted, never uploaded,"
echo "never pasted into AI tools."
