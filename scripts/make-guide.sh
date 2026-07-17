#!/bin/sh
# make-guide.sh — fill the printed Executor Instructions from your
# register, instead of hand-editing placeholders.
#
# Usage:
#   scripts/make-guide.sh [FILE]     (default FILE: estate.yaml)
#
# Reads the decrypted register and fills templates/EXECUTOR-INSTRUCTIONS.md:
#   owner, updated, password manager       from meta
#   share holders                          from contacts with role
#                                          containing "share"
#   will location                          from the documents entry whose
#                                          name contains "will"
#   encrypted-file locations               from documents entries whose
#                                          name contains "executor file"
#   last successful recovery test          from recovery-tests.log
#                                          (written by test-recovery.sh)
#
# Writes, next to FILE:
#   EXECUTOR-INSTRUCTIONS-filled.md
#   EXECUTOR-INSTRUCTIONS-filled.html   (print: two pages)
#
# Any [BRACKETED] blank it cannot fill is left in place and counted at
# the end — fill those by hand before printing.
#
# Pure POSIX sh + awk. The guide contains no secrets (share values are
# never in the register), but it names people and places — store it
# with the will, not on the fridge.
#
# Exit codes: 0 = written, 1 = could not fill, 2 = usage.
set -u

IN="${1:-estate.yaml}"
case "$IN" in -h|--help) sed -n '2,30p' "$0"; exit 0 ;; esac

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TEMPLATE="$SCRIPT_DIR/../templates/EXECUTOR-INSTRUCTIONS.md"
DIR=$(dirname "$IN")
OUT_MD="$DIR/EXECUTOR-INSTRUCTIONS-filled.md"
OUT_HTML="$DIR/EXECUTOR-INSTRUCTIONS-filled.html"
RECOVERY_LOG="$DIR/recovery-tests.log"

if [ ! -f "$IN" ]; then
  echo "error: register not found: $IN" >&2
  echo "hint: run this while the plaintext exists (e.g. right after setup," >&2
  echo "or from inside a review) — or decrypt first." >&2
  exit 2
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found: $TEMPLATE" >&2
  exit 2
fi

# Repo URL: from git if available, else the canonical home.
REPO_URL="https://github.com/TheWayWithin/executor-file"
if command -v git >/dev/null 2>&1; then
  u=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
  [ -n "$u" ] && REPO_URL="$u"
fi

LAST_TEST="not yet tested — run scripts/test-recovery.sh"
if [ -f "$RECOVERY_LOG" ]; then
  lt=$(tail -1 "$RECOVERY_LOG")
  [ -n "$lt" ] && LAST_TEST="$lt"
fi

awk -v template="$TEMPLATE" -v repo_url="$REPO_URL" -v last_test="$LAST_TEST" '
function value_of(line,   v) {
    v = line
    sub(/^[^:]*:[ ]*/, "", v)
    sub(/[ ]+#.*$/, "", v)
    if (v ~ /^".*"$/)      { sub(/^"/, "", v);  sub(/"$/, "", v) }
    else if (v ~ /^'"'"'.*'"'"'$/) { sub(/^'"'"'/, "", v); sub(/'"'"'$/, "", v) }
    return v
}
function key_of(line,   k) { k = line; sub(/^[ ]*(- )?/, "", k); sub(/:.*$/, "", k); return k }
# Escape a value for use as a gsub replacement (& and \ are magic there).
function repl(s,   t) { t = s; gsub(/\\/, "\\\\", t); gsub(/&/, "\\\\&", t); return t }
function flush_item() {
    if (!in_item) return
    if (cursec == "contacts" && tolower(item["role"]) ~ /share/) {
        nsh++
        sh[nsh] = item["name"]
        if (item["pointer"] != "") sh[nsh] = sh[nsh] " — " item["pointer"]
    }
    if (cursec == "documents") {
        if (tolower(item["name"]) ~ /will/ && will_loc == "")
            will_loc = item["location"]
        if (tolower(item["name"]) ~ /executor file/) {
            nloc++
            loc[nloc] = item["location"]
        }
    }
    delete item; in_item = 0
}

# ── pass 1: the register ────────────────────────────────────────────
NR == FNR {
    if ($0 ~ /^[ \t]*(#|$)/) next
    if (collecting != "") {
        if (match($0, /^[ ]+/) && RLENGTH >= collect_indent) {
            line = $0; sub(/^[ ]+/, "", line); sub(/[ \t]+$/, "", line)
            if (collect_target == "meta") meta[collecting] = (meta[collecting] == "" ? line : meta[collecting] " " line)
            else                          item[collecting] = (item[collecting] == "" ? line : item[collecting] " " line)
            next
        }
        collecting = ""
    }
    if ($0 ~ /^[a-zA-Z_]+:/) {
        flush_item()
        section = $0; sub(/:.*$/, "", section)
        next
    }
    if (section == "meta" && $0 ~ /^  [a-zA-Z_]+:/) {
        k = key_of($0); v = value_of($0)
        meta[k] = v
        if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "meta"; collect_indent = 4; meta[k] = "" }
        next
    }
    if (section ~ /^(contacts|documents)$/ && $0 ~ /^  - /) {
        flush_item(); in_item = 1; cursec = section
        k = key_of($0); v = value_of($0)
        if (k != "") item[k] = v
        if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "item"; collect_indent = 6; item[k] = "" }
        next
    }
    if (section ~ /^(contacts|documents)$/ && in_item && $0 ~ /^    [a-zA-Z_]+:/) {
        k = key_of($0); v = value_of($0)
        item[k] = v
        if (v ~ /^[>|]-?$/) { collecting = k; collect_target = "item"; collect_indent = 6; item[k] = "" }
        next
    }
    next
}

# ── pass 2: the template ────────────────────────────────────────────
FNR == 1 && NR != FNR { flush_item() }
{
    line = $0
    gsub(/\[OWNER FULL NAME\]/, repl(meta["owner"]), line)
    gsub(/\[LAST UPDATED\]/, repl(meta["updated"]), line)
    gsub(/\[PASSWORD MANAGER\]/, repl(meta["password_manager"]), line)
    gsub(/\[LAST RECOVERY TEST\]/, repl(last_test), line)
    gsub(/\[REPO URL\]/, repl(repo_url), line)
    if (nsh >= 1) gsub(/\[SHARE HOLDER 1\]/, repl(sh[1]), line)
    if (nsh >= 2) gsub(/\[SHARE HOLDER 2\]/, repl(sh[2]), line)
    if (nsh >= 3) gsub(/\[SHARE HOLDER 3\]/, repl(sh[3]), line)
    if (will_loc != "") gsub(/\[WILL LOCATION\]/, repl(will_loc), line)
    if (nloc >= 1) gsub(/\[LOCATION 1[^]]*\]/, repl(loc[1]), line)
    if (nloc >= 2) gsub(/\[LOCATION 2[^]]*\]/, repl(loc[2]), line)
    # Strip the how-to-fill sentence meant for the blank template.
    gsub(/`scripts\/make-guide\.sh` fills in every `\[bracketed blank\]` from your register \(or fill them by hand\)\. /, "", line)
    print line
}
' "$IN" "$TEMPLATE" > "$OUT_MD" || { rm -f "$OUT_MD"; echo "error: could not fill the guide" >&2; exit 1; }

# ── markdown -> printable HTML (our own constrained markdown only) ──
awk '
function esc(s,   t) { t = s; gsub(/&/, "\\&amp;", t); gsub(/</, "\\&lt;", t); gsub(/>/, "\\&gt;", t); return t }
function inline(s,   t) {
    t = esc(s)
    while (match(t, /\*\*[^*]+\*\*/)) {
        inner = substr(t, RSTART + 2, RLENGTH - 4)
        t = substr(t, 1, RSTART - 1) "<strong>" inner "</strong>" substr(t, RSTART + RLENGTH)
    }
    while (match(t, /`[^`]+`/)) {
        inner = substr(t, RSTART + 1, RLENGTH - 2)
        t = substr(t, 1, RSTART - 1) "<code>" inner "</code>" substr(t, RSTART + RLENGTH)
    }
    return t
}
function close_lists() {
    if (in_ul) { print "</ul>"; in_ul = 0 }
    if (in_ol) { print "</ol>"; in_ol = 0 }
    if (in_table) { print "</table>"; in_table = 0 }
}
BEGIN {
    print "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">"
    print "<title>Executor Instructions</title>"
    print "<style>"
    print "body{font-family:Georgia,serif;max-width:46rem;margin:2rem auto;padding:0 1rem;color:#111;line-height:1.4}"
    print "h1{font-size:1.5rem;border-bottom:2px solid #111;padding-bottom:.3rem}"
    print "h2{font-size:1.2rem;margin-top:1.4rem}"
    print "code{font-family:Menlo,Consolas,monospace;background:#f2f2ee;padding:0 .2rem}"
    print "pre{background:#f2f2ee;padding:.5rem .8rem;border:1px solid #ddd;font-family:Menlo,Consolas,monospace}"
    print "table{border-collapse:collapse;margin:.6rem 0}"
    print "td,th{border:1px solid #999;padding:.25rem .6rem;text-align:left}"
    print "ol li,ul li{margin:.35rem 0}"
    print "hr{border:none;margin:0;page-break-after:always}"
    print "@media print{body{margin:0 auto;font-size:10.5pt}}"
    print "</style></head><body>"
}
/^```/ { if (in_pre) { print "</pre>"; in_pre = 0 } else { close_lists(); print "<pre>"; in_pre = 1 }; next }
in_pre { print esc($0); next }
/^---[ \t]*$/ { close_lists(); print "<hr>"; next }
/^# /   { close_lists(); print "<h1>" inline(substr($0, 3)) "</h1>"; next }
/^## /  { close_lists(); print "<h2>" inline(substr($0, 4)) "</h2>"; next }
/^\|/ {
    if (!in_table) { close_lists(); print "<table>"; in_table = 1 }
    if ($0 ~ /^\|[ \t]*-/) next   # separator row
    line = $0; sub(/^\|/, "", line); sub(/\|[ \t]*$/, "", line)
    n = split(line, cells, "|")
    row = "<tr>"
    for (i = 1; i <= n; i++) {
        c = cells[i]; gsub(/^[ \t]+|[ \t]+$/, "", c)
        row = row "<td>" inline(c) "</td>"
    }
    print row "</tr>"
    next
}
/^[0-9]+\. / {
    if (in_table) { print "</table>"; in_table = 0 }
    if (in_ul) { print "</ul>"; in_ul = 0 }
    if (!in_ol) { print "<ol>"; in_ol = 1 }
    t = $0; sub(/^[0-9]+\. /, "", t)
    print "<li>" inline(t) "</li>"
    next
}
/^- / {
    if (in_table) { print "</table>"; in_table = 0 }
    if (in_ol) { print "</ol>"; in_ol = 0 }
    if (!in_ul) { print "<ul>"; in_ul = 1 }
    print "<li>" inline(substr($0, 3)) "</li>"
    next
}
/^[ \t]*$/ { close_lists(); next }
/^\*[^*].*[^*]\*$/ { close_lists(); print "<p><em>" inline(substr($0, 2, length($0) - 2)) "</em></p>"; next }
{
    # continuation of a list item or a plain paragraph
    if (in_ul || in_ol || in_table) { print inline($0) }
    else print "<p>" inline($0) "</p>"
}
END { close_lists(); if (in_pre) print "</pre>"; print "</body></html>" }
' "$OUT_MD" > "$OUT_HTML" || { rm -f "$OUT_HTML"; echo "error: could not write HTML" >&2; exit 1; }

echo "Wrote:"
echo "  $OUT_MD"
echo "  $OUT_HTML   (open in a browser; File > Print gives the two pages)"

LEFT=$(grep -c '\[[A-Z][A-Z]' "$OUT_MD" 2>/dev/null || true)
if [ "${LEFT:-0}" -gt 0 ]; then
  echo
  echo "$LEFT line(s) still carry [BRACKETED] blanks — fill these by hand"
  echo "before printing:"
  grep -n '\[[A-Z][A-Z]' "$OUT_MD" | sed 's/^/  /'
  echo
  echo "Tip: the generator can fill more of these from the register itself —"
  echo "add contacts with role \"share-holder\" (one per share), a documents"
  echo "entry whose name contains \"Will\", and documents entries named e.g."
  echo "\"Executor File copy (USB)\" for the storage locations."
fi
echo
echo "Print both pages, check every line reads true, and store them with"
echo "the will. Reprint whenever meta, holders, or locations change."
