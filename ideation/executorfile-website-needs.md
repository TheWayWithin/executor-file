# executorfile.com — website needs analysis

Drafted 17 Jul 2026 in the executor-file session. Purpose: promote the tool
and help non-GitHub users adopt it, with a content area for related articles.
Standing decision (product card, 2026-07-17): separate repo
(`executor-file-site`), static, Netlify/Vercel; the tool repo stays canonical
for all technical docs — the site links or pulls at build time, never
hand-copies.

## 1. The structural rule: three zones, different ethics

The site serves five visitor types, one of whom is recently bereaved. That
forces a zoning rule stronger than normal marketing-site practice:

- **Promote zone** (home, how-it-works, why-trust-this): persuasion allowed,
  honesty mandatory — the tool's credibility IS the product.
- **Use zone** (get-started, download, FAQ, /recover): zero persuasion, zero
  ads, zero affiliate links, minimal-to-no analytics. /recover in particular
  may be read by a grieving executor holding the printed page.
- **Content zone** (blog): SEO and affiliate revenue live here, disclosed on
  every page that uses them, never bleeding into the use zone.

## 2. Audiences and jobs

1. **Owner-curious** (prompted by a death, a news piece, a friend): understand
   the idea in two minutes; believe it is trustworthy; hear "no subscription,
   no service that can die, your file". Primary conversion: download / start.
2. **Owner-doing** (committed, may be non-technical): obtain the tool without
   a GitHub account; follow a friendlier presentation of the quickstart (one
   command per step — same ergonomics as the README); troubleshoot via FAQ.
3. **Executor in crisis**: a calm /recover page that mirrors the printed
   Executor Instructions exactly (build-pulled), plus the Windows sheet.
   No commerce, no tracking, big type, print-friendly.
4. **Technical validator** (the sceptical friend asked to vet it): threat
   model in plain English, honest-limits section (mirrors SECURITY.md),
   "read the scripts — they are short on purpose", link to repo.
5. **Search visitor** (researching estate admin generally): blog answers
   real questions and introduces the tool contextually.

## 3. Helping non-GitHub users — what it actually takes

- **Anonymous download:** GitHub serves release tarballs without login. A
  Download button → the v0.3.0+ tagged release, with its SHA-256 shown.
  Consequence: **site launches after the v0.3.0 tag** (gates first).
- **Honesty about the CLI floor:** the GUI is deliberately parked. The site
  lowers the understanding barrier, not the Terminal requirement. Frame:
  "an hour at the computer, one command at a time, and a printed page your
  executor can follow forever." No pretending.
- **No-drift doc mirroring:** any site copy of EXECUTOR-INSTRUCTIONS,
  WINDOWS-RECOVERY, or the quickstart is pulled from the repo at build time.
  Drifted recovery instructions are the failure the tool exists to prevent.
- **Prerequisite honesty:** age + ssss still install via brew/apt; the
  get-started page presents that plainly per OS, reusing doctor.sh's checks
  as prose.

## 4. Page inventory

**MVP (launch):**
- Home — the two-artefact story (encrypted file + printed page), who it's
  for, what it refuses to do (no credentials, no service, no hosting).
- How it works — diagram, 2-of-3 shares explained for humans, threat model
  in plain English.
- Get started — friendly quickstart (one copyable command per step),
  download with checksum, prerequisites per OS.
- /recover — executor emergency path; mirrors printed page; Windows variant;
  print-friendly; commercially silent.
- Why trust this — security page from SECURITY.md: defended vs explicitly
  not defended; "no maintainer can recover a lost passphrase" as a feature;
  open source, MIT, tests, CI.
- FAQ — passphrase loss, holder death, "why not just a spreadsheet/vault
  service", lawyer questions, GDPR-ish privacy answer (nothing leaves your
  machine).
- Blog scaffold + 3 launch articles.
- About + affiliate-disclosure + privacy pages.

**Later:** testimonials once real dry-runs exist; "for solicitors" page;
comparison pages (vs Everplans-type services, vs password-manager legacy
features); newsletter if the blog earns it.

## 5. Content strategy (blog)

- SEO clusters: executor duties ("what does an executor actually do"),
  digital estate planning, crypto inheritance, password-manager emergency
  access (1Password/Bitwarden/Apple/Google legacy features), RUFADAA and
  platform legacy tools, "dead man's switch" alternatives, discovery
  checklists (the repo doc is a ready seed).
- Voice: jamie-voice skill; production via jamie-content; publish via
  jamie-publish. British English, no corporate speak, no em-dashes in
  published prose.
- Affiliate fits (disclosed, content zone only): password managers,
  fireproof document safes, home printers/scanners, will-writing and estate
  services, relevant books. Display ads: deferred — trust cost likely
  exceeds revenue at launch traffic.

## 6. Technical needs

- **Stack:** Astro (content collections, markdown, fast static output,
  zero server) on Netlify from GitHub — matches the standard stack; no DB,
  no auth. jamiewatters.work's Next+Prisma shape is NOT needed here.
- Build-time fetch of repo docs (git submodule or fetch script) with the
  repo as the only source of truth.
- RSS, sitemap, OG images, dark/light, print stylesheet for /recover.
- Analytics: privacy-respecting (Plausible-class); none on /recover.
- Search (client-side, e.g. Pagefind) once the blog has volume.
- Domains: executorfile.com primary; executor-file.com 301s to it.

## 7. Metrics

Release downloads; get-started page depth/completion proxy; organic entries
to blog posts; affiliate CTR; repo stars as a trailing trust signal. Not
raw pageviews.

## 8. Risks and open decisions

- **Tone risk:** death-adjacent marketing can curdle. Values filter: truth
  over image, usefulness over vanity — the site should read like the README
  speaks.
- **Support surface:** a public site invites email/questions. Decide where
  they land (GitHub issues with the never-paste warning vs a contact
  address) before launch.
- **Claims discipline:** until the Windows dry run passes, no "tested with
  real executors" claim. The site's claims inherit the repo's honesty bar.
- **Open:** newsletter or not at launch; whether /recover gets its own
  short memorable URL on the printed page in a future guide revision
  (would create a permanent-URL commitment — decide deliberately).

## 9. Sequencing

1. v0.3 gates pass → tag v0.3.0 (prerequisite for a Download button).
2. Turn this analysis into the site spec / goal prompt (bounded enough for
   goal-first, same as the v0.3 build and the jamiewatters.work handoff).
3. Scaffold `executor-file-site`, build MVP pages + 3 articles, launch.
4. Add executorfile.com URL to the jamiewatters.work product row (replacing
   the GitHub URL as `url`) once live.
