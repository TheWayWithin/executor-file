#!/usr/bin/env bash
# share-sheets.sh — print-ready cover sheets, one per share holder.
#
# Usage:
#   scripts/share-sheets.sh
#
# Prompts for the owner's name and the three shares (paste them from
# the setup/rotate screen, or type from paper), then writes three
# HTML sheets — share-1.html, share-2.html, share-3.html — into a
# PRIVATE TEMP FOLDER. Each sheet carries the share plus everything
# its holder needs to know: what it is, who may request it, when to
# release it, and why one share alone is useless.
#
# Print them, then return here and press Enter: the folder and the
# sheets are removed. The shares exist on disk only between those two
# moments, in a mode-700 temp folder.
#
# PRINTER WARNING — read before printing:
#   Printers spool what they print. A home printer on your own
#   network is fine; an office, hotel, or shop printer may retain
#   the document indefinitely — assume it does, and do not use one.
#   Hand-copying remains the zero-trace alternative.
set -euo pipefail
umask 077

case "${1:-}" in -h|--help) sed -n '2,23p' "$0"; exit 0 ;; esac

printf 'Owner name (as the holders know you): '
read -r OWNER
[ -n "$OWNER" ] || { echo "error: owner name needed." >&2; exit 2; }
printf 'Share 1: '
read -r SH1
printf 'Share 2: '
read -r SH2
printf 'Share 3: '
read -r SH3
[ -n "$SH1" ] && [ -n "$SH2" ] && [ -n "$SH3" ] || { echo "error: three shares needed." >&2; exit 2; }

WORK="$(mktemp -d)"
chmod 700 "$WORK"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

esc() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

sheet() { # $1 = number, $2 = share value
  n="$1"; share="$(esc "$2")"; owner="$(esc "$OWNER")"
  cat > "$WORK/share-$n.html" <<HTML
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Executor File share $n of 3 — $owner</title>
<style>
body{font-family:Georgia,serif;max-width:44rem;margin:2.5rem auto;padding:0 1rem;color:#111;line-height:1.5}
h1{font-size:1.5rem;border-bottom:2px solid #111;padding-bottom:.3rem}
.share{font-family:Menlo,Consolas,monospace;font-size:1.05rem;letter-spacing:.06em;word-break:break-all;background:#f2f2ee;border:2px solid #111;padding:1rem;margin:1.2rem 0}
ul li{margin:.4rem 0}
.foot{margin-top:1.6rem;font-style:italic}
@media print{body{margin:1rem auto}}
</style></head><body>
<h1>Executor File — share $n of 3</h1>
<p><strong>Owner:</strong> $owner &nbsp;·&nbsp; <strong>Issued:</strong> $(date +%Y-%m-%d)</p>
<p><strong>What this is.</strong> One of three printed key-shares to an encrypted
file listing ${owner}'s accounts, assets, and liabilities, kept so their
executor can settle the estate. <strong>Any two shares open that file.
This sheet alone opens nothing</strong> — mathematically nothing, not
merely "hard to use" — so holding it exposes neither ${owner}'s affairs
nor their passwords (the file contains no passwords at all).</p>
<p><strong>Keep it:</strong></p>
<ul>
<li>In a safe, private place with your own important papers.</li>
<li>On paper only — <strong>never photograph it, scan it, email it, or type
it into any file, note, or chat.</strong> A digital copy silently defeats
the whole design.</li>
<li>Away from the other holders' shares — never two shares in one place.</li>
</ul>
<p><strong>Release it only:</strong> when $owner has died or lost capacity,
and the person asking is the executor named in the will (or their
solicitor). Verify who is asking — call them back on a number you find
yourself. If in doubt, hand it to the solicitor rather than to anyone else.</p>
<p><strong>If circumstances change:</strong> tell $owner if this sheet is
ever lost, damaged, photographed, or if you no longer wish to hold it —
the shares can be reissued in minutes while they are alive.</p>
<div class="share">estate share $n of 3:<br><br>$share</div>
<p class="foot">If you find this sheet after $owner has died: it belongs
with their executor. It is useless alone, and vital together.</p>
</body></html>
HTML
}

sheet 1 "$SH1"
sheet 2 "$SH2"
sheet 3 "$SH3"

echo
echo "Three sheets written to a private temp folder:"
echo
echo "  $WORK/share-1.html"
echo "  $WORK/share-2.html"
echo "  $WORK/share-3.html"
echo
echo "Open each in a browser and print it (File > Print) — on a HOME"
echo "printer only; office/hotel/shop printers spool documents and may"
echo "retain them indefinitely. Print each sheet separately and keep the"
echo "three printouts apart from the start."
if command -v open >/dev/null 2>&1; then
  echo
  echo "  (macOS tip:  open $WORK  — opens the folder in Finder)"
fi
echo
printf 'Press Enter AFTER all three are printed — the folder and sheets are then removed... '
read -r _ || true
echo
echo "Removed. The shares now exist only on the printed sheets — hand"
echo "them to their holders and tell each what it is. When done, CLOSE"
echo "THIS TERMINAL WINDOW ENTIRELY (scrollback may hold the shares you"
echo "pasted)."