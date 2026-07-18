# executorfile.com: Website Strategy and Build Spec

**Drafted:** 17 July 2026, Cowork session (repo review + best-practice research)
**Inputs:** executor-file repo (README, SECURITY.md, EXECUTOR-INSTRUCTIONS, v0.3 release spec, roadmap), `ideation/executorfile-website-needs.md`, Vision & Mission v4.2, Positioning Statement v2.0, Client Success Blueprint v2.0, Brand Style Guide v2.1, plus two research passes: 23 open-source promotional sites analysed, and the estate-tech competitive/monetisation/SEO landscape.
**Status:** strategy locked per Jamie's three calls (founding story told plainly on its own page; own brand with Jamie as named maker; deliverable is strategy plus buildable spec). Site launch remains gated on the v0.3.0 tag.

---

## 1. Decisions this document locks in

1. **Own brand.** executorfile.com gets its own calm identity. The Jamie Watters dark/Proof Gold "honest AI lab" system stays on jamiewatters.work; a grieving executor should never land on an instrument panel. Jamie appears as the named, real maker on the Story and Why-trust-this pages, linking to jamiewatters.work. Reputation flows both ways without forcing one aesthetic onto the other.
2. **The founding story is a first-class page**, told plainly in first person, linked from the homepage in one quiet line. It never appears on task pages (/recover, get-started).
3. **Three zones, plus two doors.** The needs analysis zoning (promote / use / content) stands. On top of it, the homepage adopts the two-door pattern from bereavement content design: "Putting your affairs in order" and "Someone has died" are separated within the first screen, and the bereaved door leads straight to /recover with zero marketing en route.
4. **No display ads, ever, stated as policy.** Affiliate links live in the content zone only, disclosed Wirecutter-style. Google itself treats bereavement as a sensitive ad category; a site whose core argument is "nothing extractive, nothing that can die" cannot run AdSense without refuting itself.
5. **Sell by absence.** The lead message across the site is the absence list: no accounts, no servers, no subscription, no credentials stored, no company that can fold. Research confirmed this is the winning pattern for trust-sensitive open source (KeePassXC, Syncthing, Signal) and that the durability argument is wide open in the estate niche: no competitor leads with it because none of them can.
6. **Claims discipline inherits the repo's honesty bar.** Until the Windows dry run passes, no "tested with real executors" claim anywhere. The site launches after v0.3.0 tags (the Download button needs a tagged release with its SHA-256).

---

## 2. Positioning: the marketing physics

### Overt benefit

**When you are gone, your executor can find everything.**

The pain is documented and quotable: Empathy's Cost of Dying research puts settling affairs at 15 months on average (18 when acting as executor), roughly $12,616 in family cost, with 92% of executors reporting the work affected their job. Verify each figure against the current report edition before publishing. Use burden-on-family numbers, never fear-of-death numbers; the whole category converged on love-and-practicality framing because fear fails here.

### Dramatic difference

**It is a file, not a service.** Everything else in the category is a hosted account: Everplans (sold twice, now owned by a funeral-sales company, $99.99/yr), Cake (acquired by a funeral-home operator), Farewill (sold to Dignity for less than it raised), Lantern (retired; users given a support email and a deadline to extract their own end-of-life plans), Deathswitch (dead), Legacy Locker (absorbed, gone), Beyond (its domain now serves a rival's content). The service graveyard is executor-file's single most credible marketing asset, and no competitor can publish it because they are all candidates for it.

The absence list, as site copy:

> No account. No server. No subscription. No credentials stored. No company that can shut down. Your family keeps a file and one printed page. That is the whole product.

### Real reasons to believe

Every one of these is verifiable from the repo today; the site's job is to surface them, not embellish them:

1. **Read the scripts.** They are short on purpose: thin, readable wrappers around two standard tools. Stronger than Plausible's "verify what we collect" because the whole recovery path fits in one sitting.
2. **Recovery needs no software of Jamie's.** Stock `age` (Filippo Valsorda's audited, formally specified format with independent implementations) plus `ssss` (Shamir's Secret Sharing, information-theoretic). If the repo and its author vanish, the file still opens with two commands. This is the answer to the single-maintainer objection: built by one person, designed so it does not need him.
3. **No credentials, enforced.** The validators actively reject credential-shaped data. The register stores pointers, not passwords.
4. **2-of-3 shares.** Nobody could read it while you were alive; one lost share loses nothing.
5. **The chain proves itself.** `setup.sh` reconstructs from the just-issued shares and test-decrypts before reporting success; `test-recovery.sh` is a yearly fire drill from the real printed paper, with the date stamped on the printed guide.
6. **Honest limits, published.** SECURITY.md's "explicitly NOT defended" list and "no maintainer can recover a lost passphrase" stance. Research finding: in this category, stated limits are the strongest trust signal there is (Vaultwarden's liability disclaimer, Syncthing's process-over-promises security page).
7. **MIT, tests, CI**, and a maker who was an executor with nothing to go on. The story is the reason the tool exists; the repo is the evidence it works.

### One-line pitch candidates (test on the homepage, in this order)

1. "Everything your executor will need, in one encrypted file." (current tagline; plain, complete)
2. "A file your family keeps. Not a service that can die."
3. "Your executor will need a map. Leave one."

---

## 3. Audiences: two doors, five visitors

The needs analysis names five visitor types. The research adds the structural answer: different audiences need different pages, not one compromised page.

| Visitor | Door | Lands on | Job of the page |
|---|---|---|---|
| Owner-curious | Door 1 | Home → How it works | Understand in two minutes; believe it is trustworthy |
| Owner-doing | Door 1 | Get started | Obtain and follow without a GitHub account |
| Executor in crisis | Door 2 | /recover | Open the file. Nothing else. |
| Technical validator | Either | Why trust this → GitHub | Threat model in plain English; "read the scripts" |
| Search visitor | Content | Learn (blog) | A real answer, then a contextual introduction to the tool |

Door 2 is deliberately quiet: one plain link on the first screen ("Someone has died and you have the printed page → Open the Executor File"), styled calm, never a marketing banner. The bereaved visitor should reach instructions in one click and never see commerce on the way.

---

## 4. Brand and voice

### Visual identity (new, standalone)

- **Light-first, paper-and-ink.** The product's proudest artefact is a printed page stored with a will. Lean into that: warm off-white ground, near-black ink, generous type, one restrained accent (a deep green or slate blue; explicitly not Proof Gold, not Visionary Purple, not the JW dark base). Feels like a well-set document, not a dashboard.
- **Typography:** one humanist sans for UI and headings (Inter is fine and already licensed in the ecosystem), a monospace only where commands appear. Big type and 1.6 line-height as defaults; /recover gets larger still.
- **Imagery:** the real artefacts. A photographed or faithfully rendered printed Executor Instructions page, a redacted triage report, an actual terminal session. No stock photography of hands and sunsets, no candles. NN/g's credibility research: show the whole process, not the mood.
- **Calm is the aesthetic.** Every strong exemplar sells safety without selling dread. No countdowns, no urgency mechanics, no exclamation marks anywhere on the site.

### Jamie's presence

"Built by Jamie Watters" appears on the Story page and Why-trust-this page with a one-line bio (38 years in corporate technology; builds open tools in public) and a link to jamiewatters.work. The blog byline is Jamie. Nowhere does the site adopt the AI-lab framing; here he is the maker who needed this tool and built it.

### Voice rules (bake into the site style guide and every content brief)

From DWP Digital, Content Design London, and hospice-sector guidance:

- Say **"died"** and **"death"** in instructional content. Never "passed away", "loss", "the departed" in navigation, headings or instructions.
- No condolence boilerplate in flows. Not everyone is grieving; some relationships were complicated. Brevity is the sympathy.
- State upfront how long a task takes and what is needed ("30 to 60 minutes, three commands, two printed shares").
- One action per step; short chunks; everything pausable and printable.
- "When you're ready", never "Start now!".
- British English base (organise, solicitor) with per-market vocabulary handled in content (see §8). No em-dashes in published prose; no leverage/seamless/robust/unlock/empower/ecosystem/delve/utilize, no navigate-as-metaphor.
- The one exception to plain register: quoting a person's own gentler language in testimonials, if those ever exist.

---

## 5. The founding story

**Page:** `/story` (nav label "Story" or "Why this exists").

**Treatment.** First person, plain, unadorned, using "died". Two experiences, told in the order they happened:

1. Executor of his father's estate with nothing to go on: no register, no list, months of detective work, and no way to ever know what was missed. Possibly thousands lost; the not-knowing is the permanent part.
2. His son died recently. Beyond some paper statements found afterwards, there was no record of his online accounts, and a long tail of direct debits and mandates kept firing into the silence.

Then one paragraph of turn: this tool is the thing Jamie needed twice and nobody had built in a durable form. It stores where things are and what you wanted done, in a file the family keeps.

**Rules.**

- One quiet line on the homepage links to it: "Built by someone who has been the executor with nothing to go on. Read the story." No more than that above the fold.
- The story never appears on /recover or Get started. DWP research is blunt: sympathy-padding measurably hurts usability for grieving users. Task pages stay task-only.
- The story explains why the tool exists; it is never presented as evidence the tool works. Evidence lives on Why-trust-this.
- Jamie writes this page himself (jamie-voice skill), and it does not go through SEO optimisation. It ends with the same two-door choice as the homepage.

---

## 6. Site architecture and page-by-page spec

**Primary nav (6 items):** How it works · Get started · For executors · Why trust this · Story · Learn
**Footer:** GitHub · FAQ · Security · How this site makes money · Privacy · About
**Zone map:** Promote = Home, How it works, Why trust this, Story. Use = Get started, For executors (/recover), FAQ. Content = Learn.

### 6.1 Home (promote zone)

- **Hero.** H1: "Everything your executor will need, in one encrypted file." Sub: "Executor File is a free, open-source register of every account, asset and liability you own, and one printed page that tells your executor how to open it. A file your family keeps. Not a service that can die."
- **CTA ladder** (research: graduated CTAs beat a single one): primary "See a sample Executor File" (the rendered sample: triage report + printed page + redacted register, viewable before any download); secondary outlined "Get started"; tertiary text link "Read the code".
- **Door 2**, same screen, visually quiet: "Someone has died and you have the printed page? Open the Executor File →" straight to /recover.
- **The two artefacts**, illustrated with the real things: the encrypted file and the printed page.
- **The absence list** as the differentiator block (copy in §2).
- **How it works in three steps** (write it, seal it, print it), linking to the full page.
- **Reasons-to-believe strip:** open source, MIT · recovery uses two standard tools, forever · no credentials, enforced · honest limits, published.
- **The one quiet story line** (§5).
- **What it refuses to do**, stated on the homepage (mirrors "Deliberately out of scope"): no credential storage, no provider APIs, no hosted anything. Upfront disclosure is a measured credibility factor.

### 6.2 How it works (promote zone)

- The diagram from the README (estate.yaml → setup.sh → .age + three shares).
- **2-of-3 for humans**, using the key-and-map register: "Three people each hold one printed share. Any two open the file; one alone opens nothing. Nobody could read it while you were alive. Losing one share loses nothing." Cryptomator's civilian techniques apply: one familiar analogy, explicit friction denial ("no account to create, no configuration"), a reassurance check-in.
- **Threat model in plain English:** the README table translated, defended and not-defended both. Include "what happens if I lose the passphrase AND two shares: the file stays sealed forever. That is the design working" (Vaultwarden lesson: publish the failure modes, unhidden).
- **Platform legacy tools come first** section: Apple/Google/Meta settings outrank the will under RUFADAA; the register records what you set.

### 6.3 Get started (use zone: no persuasion, no commerce, no affiliate links)

- **The honesty paragraph up top:** "This takes about an hour at the computer, one command at a time, in the Terminal. If you can copy and paste, you can do this. The result is an encrypted file and a printed page your executor can follow forever." The site lowers the understanding barrier, not the Terminal requirement. No pretending.
- **Prerequisites per OS**, plainly: age and ssss via brew/apt, with doctor.sh's checks rendered as prose.
- **Quickstart mirrored from the README at build time** (one copyable command per step, same ergonomics). Never hand-copied: drifted instructions are the failure the tool exists to prevent.
- **Download button** → the v0.3.0+ tagged release tarball (no GitHub account needed), SHA-256 shown beside it.
- Anonymous-download note and "your executor never needs this repo".

### 6.4 /recover: For executors (use zone, strictest rules)

- Mirrors the printed EXECUTOR-INSTRUCTIONS exactly, pulled from the repo at build time. Page one human (you do not have to finish today; confirm your authority; the will decides), page two the three commands.
- Windows sheet as a clearly-marked variant.
- Big type, print stylesheet, works perfectly with CSS off and on paper.
- **Commercially silent and analytically silent:** no ads, no affiliate links, no analytics at all, no cookie anything, no nav clutter. A grieving person holding the printed page may be reading this; the page's only job is to help them open the file.
- Decision recommended now rather than deferred: **commit to executorfile.com/recover as the permanent short URL** and print it on the guide from the next revision. The domain is the brand; a permanent-URL commitment is exactly the kind of promise this product should be seen making. Add a redirect test to CI so it can never 404.

### 6.5 Why trust this (promote zone, technical validator's landing page)

- Structured from SECURITY.md, mirrored at build time: defended / explicitly not defended.
- "**No maintainer can recover a lost passphrase**" presented as the feature it is.
- "**Read the scripts: they are short on purpose.**" Link straight into the repo tree, with a line count.
- "**Built by one person, designed so it does not need him**": stock age + ssss, independent implementations, the printed page names the tools not the project.
- The Syncthing security-page pattern: how to report a vulnerability (GitHub private reporting), what is supported, no promises the project cannot keep. Show a real terminal recovery transcript including the harmless ssss memory-lock warning, so what the executor will see matches what the page shows.
- Repo facts strip: MIT · 115 scripted tests on macOS and Ubuntu CI · schema is standard JSON Schema, validatable without our scripts. (Verify the test count against the repo at build time; numbers on this page are pulled, not typed.)

### 6.6 Built to last (promote zone; the category-king page nobody else can write)

- The longevity essay, signed by Jamie: plain YAML + stock age + ssss + paper, chosen so the file outlives the tool, the company that does not exist, and the maker. Obsidian's "file over app" and Standard Notes' "100 years" pages are the models; an estate tool has more right to this argument than either.
- **The service graveyard table:** Lantern, Deathswitch, Legacy Locker, Beyond, Farewill, Everplans, Cake, each with one factual line and a source link. Framing line: "Every service on this list promised to be there when your family needed it. This is why Executor File is a file."
- Keep the table factual and sourced; no gloating. Acquisitions are stated as ownership changes, not failures.

### 6.7 FAQ (use zone)

Seed set: What if I lose the passphrase? What if a share holder dies? Why not just a spreadsheet or a vault service? Why is there no app? What does my solicitor need to know? Does anything leave my machine? (Nothing; there is no server.) What about Windows? Can I use 3-of-5? (No: one deeply tested scheme, fork if you need it.) Is this legal advice? (No; the will decides.)

### 6.8 Learn (content zone: the only place SEO and affiliate revenue live)

Blog scaffold with three launch articles (§8), category and per-market tagging, disclosure line at the top of any page with affiliate links.

### 6.9 About / How this site makes money / Privacy

- **How this site makes money** is a real page, Wirecutter-style: recommendations are chosen before monetisation is considered; some links pay a commission and are marked; several recommended things pay nothing (FreeWill, Bitwarden's free tier, a DIY safe) and are recommended anyway; no display ads as policy; the tool itself is free forever and unconnected to any of it.
- **Privacy:** privacy-respecting analytics (Plausible-class), none on /recover; no cookies requiring a banner; nothing leaves your machine when you use the tool because there is no server.

---

## 7. Monetisation

**Principle:** monetisation lives in the content zone only, is disclosed on every page that uses it, and every recommendation must survive the test "would this line survive Jamie recommending it on camera". The credibility of the paying links depends on visibly recommending non-paying options.

**The stack, in trust order (all verified to exist, July 2026; confirm rates on signup):**

1. **Password managers: the anchor.** 1Password affiliates (Impact network): $2 per trial plus 25% of first-year subscription. NordPass and Dashlane report up to ~$150/sale through directories. The editorial fit is honest by construction: executor-file explicitly stores no credentials, so "use a password manager alongside it; this file is the map, that is the keys" is real advice the README already gives.
2. **Will-writing (US):** Trust & Will affiliate programme, 20% per sale, ~$80 average. Pair it with **FreeWill recommended free** in the same articles (it pays nothing; that is the point). UK: paid will-writing affiliates are thin post-consolidation; recommend the charity Free Wills Network route editorially.
3. **Amazon Associates:** fireproof document safes (3%), home printers (2.5%), the Nokbox (as the respected physical cousin), Nolo's Executor's Guide and similar books (4.5%). Low rates, high intent on "where do I keep the printed page" content.
4. **Display ads: never.** Stated as policy on the money page. The niche's programmatic record is grim (funeral-scam ads, grief-content stalking), Google restricts bereavement targeting anyway, and one AdSense unit would refute the site's whole argument.

**Disclosure pattern:** one plain line above the fold on any page with affiliate links ("If you buy through links on this page, we earn a commission. It never changes what we recommend."), plus the full money page (§6.9). FTC and ASA both require disclosure before the links, not in a footer.

**Expectation setting:** at launch traffic this is coffee money. The affiliate stack is built now so the content architecture is right, not because it funds anything soon. Downloads and trust are the launch metrics (§10).

---

## 8. Content and SEO strategy

**The wedge.** Skip head terms: GOV.UK owns "what to do when someone dies" in the UK; Nolo, FindLaw and the banks own US executor checklists. Own the underserved pain queries where the product is the honest answer:

- "how to find all accounts of a deceased person" / "dad died no record of accounts" (weak, listicle-grade competition today; the founding story is literally this query)
- "digital estate inventory", "digital executor" (everyone ranking ends with "make a list"; executor-file IS the list)
- password-manager legacy features (1Password Emergency Kit, Bitwarden Emergency Access, Apple Legacy Contact, Google Inactive Account Manager): comparison content that is also the affiliate anchor
- per-market money questions: what happens to superannuation (AU) / KiwiSaver (NZ) / 401(k)s and TOD accounts (US) / pensions and direct debits (UK) when you die
- "dead man's switch" alternatives; RUFADAA explainers

**Launch articles (three, per the needs analysis):**

1. **"How to find every account someone owned: a working checklist."** Seeded from `docs/discovery-checklist.md`, expanded with per-market sections. Targets the highest-pain query family. Tool introduced at the end as "the version of this checklist you fill in before it is needed".
2. **"Password managers hold the keys. Your executor needs the map."** The 1Password/Bitwarden/Apple/Google legacy-feature comparison, honest about what each does and does not hand over. Affiliate anchor, fully disclosed.
3. **"The digital legacy graveyard: five services that promised forever."** The §6.6 graveyard research in article form: Lantern's retirement notice, Deathswitch, Legacy Locker, Beyond, the Everplans and Farewill ownership changes. The article version can be more narrative than the evergreen table.

**Per-market discipline.** Localisation is vocabulary, not just spelling. The table the site's content must respect:

| Concept | US | UK | CA | AU | NZ |
|---|---|---|---|---|---|
| Role | executor / personal representative | executor (administrator if no will) | executor / estate trustee (ON) | executor | executor |
| Court grant | letters testamentary / probate | grant of probate; letters of administration | certificate of appointment (ON) | grant of probate (state courts) | probate (High Court) |
| Lawyer | attorney | solicitor | lawyer / notary (QC) | solicitor | lawyer |
| Recurring payments | auto-pay | direct debits, standing orders | pre-authorised debits | direct debits | automatic payments |
| Retirement | 401(k), IRA | pension (workplace/SIPP/state) | RRSP/RRIF, TFSA | superannuation + binding nomination (sits outside the will) | KiwiSaver (small estates can bypass letters of administration) |
| Notification | agency by agency | Tell Us Once | Service Canada | Australian Death Notification Service | varies |
| Digital-assets law | RUFADAA | none (contract + data protection) | UADAA (some provinces) | none | none |

Also: "estate" reads as "wealthy people" to many UK/AU readers; "sorting out someone's affairs" is the vernacular. "Executor File" as a name works in all five markets because "executor" is the one common term.

**Production pipeline:** jamie-content for drafting, jamie-voice rules enforced (British English, no em-dashes, banned-word list), jamie-publish for shipping. Blog cadence follows energy, not a calendar; the three launch articles plus the evergreen pages are the launch bar.

---

## 9. Technical spec

- **Stack:** Astro content collections + markdown, static output, zero server, deployed to Netlify from the new `executor-file-site` repo. No DB, no auth. (jamiewatters.work's Next+Prisma shape is explicitly not needed.)
- **No-drift doc mirroring:** EXECUTOR-INSTRUCTIONS.md, WINDOWS-RECOVERY.md, the quickstart steps, SECURITY.md content and the discovery checklist are pulled from the tool repo at build time by a **fetch script pinned to the release tag** (chosen over a git submodule: explicit pinning, no submodule state to drift, and bumping the tag is a one-line reviewable change). The tool repo stays the single source of truth; the site renders, never copies. CI fails the site build if a pulled file is missing or does not byte-match the tag.
- **Download:** button links the tagged GitHub release tarball (anonymous download works), SHA-256 displayed from the release assets.
- **Per-page requirements:** RSS, sitemap, OG images, light-first with dark mode, print stylesheet for /recover (and FAQ), Pagefind client-side search once the blog has volume.
- **Analytics:** Plausible-class only; excluded entirely from /recover. No consent banner needed by design.
- **Domains:** both registered at Namecheap. executorfile.com primary; executor-file.com 301s to it. Recommended DNS setup: point both domains' nameservers to Netlify DNS at Namecheap (Domain List → Manage → Nameservers → Custom DNS), so Netlify manages records, HTTPS certificates, and the cross-domain redirect in one place and the only registrar action ever needed is that one nameserver swap per domain. /recover redirect permanence tested in CI (§6.4).
- **Accessibility:** WCAG AA minimum; /recover targets large type and high contrast beyond AA. The likely reader is older, stressed, and printing.

---

## 10. Metrics

Per the needs analysis, not pageviews: release downloads; get-started depth/completion proxy; organic entries to blog posts; affiliate CTR (content zone only); repo stars as a trailing trust signal. Add: /recover should show near-zero traffic and that is correct; do not optimise it, only keep it alive.

---

## 11. Risks and open decisions

- **Tone risk.** Death-adjacent marketing curdles fast. The values filter stands: the site should read like the README speaks. Every page draft gets checked against §4's voice rules before publish.
- **Claims discipline.** Until the Windows dry run passes: no "tested with real executors", no testimonials, no dry-run claims. The site's claims inherit the repo's honesty bar, and the repo currently says "production-ready for technical owners, not yet proven for real executors". Say that if asked; it is a trust asset, not a weakness.
- **Support surface (decide before launch; recommendation follows).** Recommend: GitHub issues as the canonical channel, with the never-paste warning, plus a plain contact email for people without GitHub accounts, forwarded and answered on a best-effort basis. A public site will generate email from the recently bereaved; the FAQ and /recover troubleshooting section should absorb most of it.
- **Newsletter:** not at launch. Revisit when the blog has ten posts and organic traffic to justify it.
- **The /recover permanent URL** is recommended as a launch commitment (§6.4) rather than an open question. If accepted, the printed guide template gains the URL at its next revision and the CI redirect test ships with the site.

---

## 12. Sequencing

1. v0.3 gates pass → tag v0.3.0 (prerequisite for the Download button and the "115 tests green" strip).
2. Scaffold `executor-file-site` (Astro, Netlify) with the build-time repo pull.
3. Build MVP pages in this order: /recover (the conscience of the site; get it perfect first) → Home → Get started → How it works → Why trust this → Built to last → Story → FAQ → money/privacy pages → Learn scaffold + three articles.
4. Launch. Add executorfile.com to the jamiewatters.work product row (replacing the GitHub URL) once live.
5. Post-launch: article cadence per §8; testimonials page only after real dry-runs exist; "for solicitors" page and comparison pages later.

---

## 13. Build goal prompt (bounded, ready for a goal-first session)

### Agreed architecture (locked 17 Jul 2026)

1. **Repo:** new public repo `TheWayWithin/executor-file-site`, MIT for the site code; article content remains © Jamie. The build session creates it via `gh`.
2. **Mirroring:** fetch script pinned to the v0.3.0 tag (§9), not a submodule.
3. **Styling:** Astro with vanilla CSS design tokens (custom properties), no Tailwind, no UI framework. Fewest dependencies on a site whose argument is longevity; the design system is one file.
4. **CI:** GitHub Actions running the drift test (pulled docs byte-match the pinned tag), internal-link check, and the /recover resolution test; Netlify builds from main with deploy previews on PRs.
5. **Analytics:** Plausible from launch (confirmed; Jamie already has an account), script excluded from /recover at the layout level.

### Pre-flight (one-time, on your Mac, before running the prompt)

The prompt can create the GitHub repo and the Netlify site itself. It cannot log in for you or touch your registrar. In order:

1. **Tag v0.3.0** in executor-file (the existing release gates). The Download button, the pinned fetch, and the stats strip all depend on it.
2. **Commit this document** to `executor-file/ideation/executorfile-website-strategy.md` and push: the prompt references it by path.
3. Open Terminal and run `gh auth status`: confirm it shows TheWayWithin. (Already true if the jamiewatters.work sessions work.)
4. Run `npm install -g netlify-cli && netlify login` so the session can create and link the Netlify site non-interactively.
5. In your existing Plausible account, add executorfile.com as a site, so the snippet's domain is live at deploy time.
6. Have your Namecheap login to hand. After the first deploy the session gives you the Netlify nameservers; at Namecheap set them on both executorfile.com and executor-file.com (Domain List → Manage → Nameservers → Custom DNS). That is your only registrar action; the session then verifies HTTPS and the 301 itself. (Propagation can take up to an hour or two; the session should poll, not fail.)

Run in a fresh Claude Code session after the pre-flight. Paste after `/goal`:

```
Read this whole prompt before touching anything. Your job: create the executor-file-site repo and ship executorfile.com, a static Astro site on Netlify, to the spec in ideation/executorfile-website-strategy.md in the executor-file repo (§6 page inventory, §4 voice rules, §9 technical requirements). Excellent looks like: a bereaved person holding the printed page reaches working recovery instructions in one click with zero commerce or analytics on the path; an owner understands the two-artefact idea in two minutes and can download the tagged release with its SHA-256 without a GitHub account; and every technical claim on the site is pulled from or verified against the executor-file repo at build time, never hand-copied.

Hard constraints. (1) Stack: create the public repo TheWayWithin/executor-file-site via gh; Astro content collections, static output, vanilla CSS design tokens (no Tailwind, no UI framework), no DB, no auth; create the Netlify site via the already-authenticated netlify CLI and deploy from GitHub. (2) No-drift mirroring via a fetch script pinned to the v0.3.0 tag (not a submodule): /recover renders templates/EXECUTOR-INSTRUCTIONS.md and docs/WINDOWS-RECOVERY.md from the tool repo; the get-started steps mirror the README quickstart the same way; the build fails if a pulled file is missing or does not byte-match the tag. (3) /recover: big type, print stylesheet, no analytics, no affiliate links, no marketing, and a CI test that the URL resolves. (4) Analytics elsewhere: Plausible only, excluded from /recover at the layout level. (5) Voice: British English, "died" never "passed away", no em-dashes, no urgency mechanics, and the banned-word list from the strategy doc. (6) Zones: affiliate links and disclosures exist only under /learn; the three launch articles ship as drafts for Jamie's review, not auto-published. (7) No claims of executor testing, no testimonials, no invented numbers; every stat on Why-trust-this is computed from the repo at build time or omitted. (8) The founding-story page ships as a placeholder with layout only; Jamie writes its copy himself. (9) Infrastructure split: you create the repo, the Netlify site, and configure both domains in Netlify (executorfile.com primary, executor-file.com 301, Netlify DNS for both); the registrar is Namecheap and Jamie's only manual step is pointing both domains' nameservers at the Netlify nameservers you give him. When the first deploy is green, hand him those nameservers with the exact Namecheap click-path, wait for his confirmation, then poll until HTTPS is issued and executor-file.com 301s to executorfile.com; verify both yourself before proceeding. Plausible: Jamie's existing account, site executorfile.com; the snippet ships in the base layout with /recover excluded.

Within that, the HOW is yours: component structure, OG image generation, design tokens within the light-first paper-and-ink direction (one accent colour, not gold, not purple). Make every call yourself, with ONE exception: show Jamie the homepage hero copy and the accent colour choice together, once, before the production deploy, and get a yes.

Before calling it done, prove it: build clean; every internal link resolves; /recover prints correctly to two pages (generate the PDF and attach it); Lighthouse accessibility ≥ 95 on /recover and Home; the pulled docs byte-match their source files at the pinned tag; the Netlify deploy is green; and executor-file.com 301s to executorfile.com.
```

---

## Appendix A: exemplar shortlist (what to study before building)

Ranked for this project's needs, from the 23-site research pass:

1. **Syncthing** (syncthing.net): the one-sentence declarative hero; the security page as process-over-promises with real command output shown.
2. **Standard Notes** (standardnotes.com/longevity): the only site selling decades-scale longevity; the model for Built to last.
3. **Obsidian** (obsidian.md + stephango.com/file-over-app): the signed philosophical essay as the deepest marketing artefact; "Your X is yours" copy skeleton.
4. **KeePassXC** (keepassxc.org): the absence list as headline value prop.
5. **Cryptomator** (cryptomator.org): making encryption friendly to civilians; analogy + friction denial + reassurance check-ins.
6. **Signal** (signal.org): incentive-structure trust ("no one profits from your data"); two-word emotional hero.
7. **Actual Budget** (actualbudget.org): the graduated CTA ladder for mixed-capability audiences.
8. **age** (github.com/FiloSottile/age): single-maintainer crypto credibility via externalised trust; constraints marketed as features.
9. **Plausible** (plausible.io): "verify exactly what it does" copy; team-size honesty.
10. **Vaultwarden**: honest failure modes as credibility. Anti-models: VeraCrypt (trust artifacts without approachability), Nextcloud/Bitwarden enterprise drift.

## Appendix B: key research sources

Bereaved-audience content design: DWP Digital "Designing content for people dealing with a death"; Content Design London "Designing for death and bereavement"; St Barnabas / Martlets hospice language guides; GOV.UK bereavement journey. Competitive: Everplans (everplans.com, Precoa acquisition via kates-boylston.com), Cake (foundationpartners.com announcement), Farewill (TechCrunch Oct 2024), Lantern retirement (wellthy.com/lantern), Deathswitch (Wikipedia), Legacy Locker (TechCrunch 2013), Nokbox (thenokbox.com). Stats: Empathy Cost of Dying reports (verify edition before quoting). Monetisation: 1password.com/affiliate, trustandwill.com/affiliate-program, Amazon Associates rate card, Wirecutter "How We Make Money" coverage (affiversemedia.com, digitalcontentnext.org). Landing-page practice: Evil Martians 100-devtool-landing-pages study (2025); NN/g trustworthy-design credibility factors; freeCodeCamp docs-as-marketing.

