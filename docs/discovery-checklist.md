# Discovery checklist — what belongs in your Executor File

Work through this once when building the register, and skim it at every annual review. The question for every line is the same: **if you died tomorrow, would your executor find this on their own?** If the answer is no — or finding it late would cost the estate money — it gets an entry.

This list doubles as the interview script for AI-assisted authoring (see `AGENTS.md`): each heading is a question to be asked one at a time.

## Money

- **Current / checking accounts** — every bank, every currency.
- **Savings accounts** — including fixed-term deposits and the account you opened for one good rate in 2019.
- **Pensions** — workplace pensions (every previous employer!), personal pensions, SIPPs, IRAs, 401(k)s. Old workplace pensions are the single most commonly lost asset.
- **Workplace benefits** — death-in-service life cover, share schemes (ESPP/RSUs), health cash plans. These often pay out only if claimed.
- **Investments** — brokerages, index funds, ISAs, robo-advisers, employee share accounts.
- **Insurance** — life, income protection, critical illness; then home, contents, vehicle (paid-up value and refunds matter too). Note WHERE the policy schedules live (`documents` section).
- **Mortgages and loans** — mortgage(s), personal loans, car finance, student loans, private lending between family members (both directions).
- **Credit cards** — every card, including the retail one used twice a year (`settle`).
- **Tax accounts** — HMRC/IRS online accounts, accountant's details, outstanding returns.
- **Cash and safes** — physical cash, safe deposit boxes (and where keys live), home safes (and who can open them).

## Recurring charges (the money bleeding out)

- **Utilities** — power, water, broadband, phone contracts.
- **Subscriptions** — streaming, news, apps, cloud storage, software, gyms, clubs, charities with recurring gifts. Check a year of bank statements for anything that repeats: that is the honest discovery method.
- **App-store subscriptions** — Apple/Google subscriptions hide inside the platform account, not on obvious statements.

## Digital infrastructure

- **Email accounts** — every one; the main inbox is where every other account resets, so it usually deserves `preserve` until the estate is settled.
- **Password manager** — the keystone entry: which one, and exactly how the executor gets emergency access (emergency kit, family organiser, emergency contact).
- **Domains** — every registrar. Domains lapse and get bought by squatters; renewal dates matter (`first_step: keep renewing`).
- **Hosting and servers** — web hosts, VPSs, cloud accounts (AWS/GCP/Azure) — things that bill monthly AND break things when they lapse.
- **SaaS you run a business on** — accounting, CRM, mailing list, analytics.
- **GitHub / GitLab** — code, private repos, Pages sites others depend on.
- **Cloud storage** — Dropbox, Drive, iCloud, OneDrive: what is in there that exists nowhere else?
- **Payment processors** — Stripe, PayPal, Wise, Revolut: often hold real balances.

## Businesses and income

- **Online businesses** — each one: what it is, what it earns, what it runs on, who could take it over, what dies if hosting lapses (`preserve` or `transfer`, with `first_step`).
- **Company shareholdings / partnerships** — paperwork location, co-owners' contacts, any shareholder agreement with death provisions.
- **Royalties and licensing** — books, music, stock photos, app-store income.
- **Intellectual property** — trademarks, patents, registered designs.

## Crypto (unrecoverable if missed — every entry `critical` or `high`)

- **Hardware wallets** — where the device is, where the seed backup is (usually two different places; use `depends_on`).
- **Exchange accounts** — balances on exchanges are accounts, not wallets; they have bereavement processes.
- **Staked / DeFi positions** — anything that needs active unwinding.

## Platform legacy settings (they outrank the will in the US)

- **Apple Legacy Contact** · **Google Inactive Account Manager** · **Meta/Facebook Legacy Contact** — set them deliberately, keep them consistent with the will, record them in `platform_legacy_tools`.

## Physical and sentimental

- **Physical storage** — storage units, lock-ups, items lent to or held by others.
- **Loyalty balances** — airline miles and hotel points can be worth real money and are usually claimable by estates.
- **Photo libraries and personal archives** — where they live, and what should happen (`preserve`, and a beneficiary).
- **Devices** — phones/laptops that gate two-factor codes for everything else; note PIN location (`access_pointer`, pointer only).

## Cross-border

- **Overseas assets** — foreign accounts, property, pensions from working abroad. List every country in `meta.jurisdictions`; note per-asset `jurisdiction` where it differs.

## People and paper (the `contacts` and `documents` sections)

- **Contacts** — solicitor, accountant, financial adviser, business partners, technically trusted helper, and the three share holders.
- **Documents** — will (original!), deeds, insurance schedules, pension statements, birth/marriage certificates, and where the encrypted Executor File copies themselves live.
