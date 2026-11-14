# ComfartZone — Product and Engineering Specification

**Domain:** comfartzone.com  
**Status:** Pre-implementation specification  
**Source of truth:** This document governs product behavior, architecture, security, and delivery. `design.md` governs visual and interaction details.  
**Development:** Android / Acode / Termux / Codex; project directory `~/Projects/Webpages/ComfartZone`.

## 1. Product charter

ComfartZone is an anonymous, humor-driven social website for sharing confessions, minor disputes, unusual habits, and provocative everyday opinions. Reading alone must be entertaining. Visitors may participate without conventional accounts, usernames, public profiles, followers, private messages, or notifications.

The voice is witty, dry, playful, occasionally sarcastic, and recognizably human. Content spans social awkwardness, relationships, family, work, petty grievances, hypocrisy, harmless embarrassment, and everyday absurdity. It is **not** a therapy service, advice engine, AI chat, or productivity tool. Avoid generic startup slogans, repetitive laziness jokes, fake engagement, and decorative copy that competes with posts.

**Primary homepage prompt:** “What ruined your day today?”  
**Primary posting CTA:** “Spill it”

### Product principles
1. Content first: the homepage opens on a real feed, not a marketing landing page.
2. Anonymous but accountable: no registration friction, yet ownership, rate limits, and moderation are enforced.
3. Unified content model: post *types* differ from optional *topics*.
4. Mobile first, desktop deliberate: compact, responsive, readable, accessible.
5. No fake functionality, fabricated activity, or premature launch claims.
6. Build a complete, tested product before public release; payments and AI APIs are not required.

## 2. Final product decisions

These are implementation defaults, not claims about existing code:

- **Public visibility:** approved public posts and comments are readable without signing in and may be indexed by search engines. Do not index drafts, moderation views, deleted content, or low-quality filtered pages.
- **Participation:** create an anonymous Supabase Auth identity on first write/vote/report, not on first page view. Retain its session securely. Anonymous identity is browser/device-specific and cannot be recovered after session loss unless a future recovery mechanism is introduced.
- **Ownership:** author may soft-delete their own post or comment while the session remains valid. Moderators can remove or restore according to policy. No public edit history. For simplicity, **no editing published posts or comments** in v1; delete and repost instead.
- **Language:** English UI; accept Unicode posts in other languages. No automated translation or language-specific feeds initially. UI copy and moderation rules should be written in English.
- **Audience:** general audience; no adult-only branding. Prohibit sexual exploitation, explicit pornography, threats, doxxing, hate, harassment, and illegal content. Profanity and mature discussion may be permitted within rules. Apply appropriate age and legal review before launch.
- **Content:** text only at launch; no uploads, rich text, HTML, links rendered as embeds, polls beyond defined vote types, or private messages.
- **Post length:** 20–1,000 Unicode characters after trimming; comments 1–500; optional report explanation 0–500. Enforce on server; client mirrors constraints.
- **Topics:** one optional topic per post; no custom user-created topics at launch.
- **Voting:** one active binary vote per authenticated anonymous visitor per poll post; switching choices allowed; voting on one's own post allowed. Display totals and percentages. On Confessions, use one selected reaction from a fixed set per visitor, switchable/removable.
- **Comments:** one-level replies (root + direct replies), no deeper nesting. Authors can delete their comments. Sort oldest/newest, default oldest within a thread.
- **Post visibility:** new posts are public immediately unless blocked by deterministic abuse rules or manually hidden. Do not claim automatic AI moderation.
- **Moderation:** reports are private; moderator dashboard requires a separately provisioned authenticated moderator account and server-enforced role. Reports do not automatically remove content solely by volume.
- **Search:** no full-text search at launch; feed filtering and sorting suffice. Avoid empty search UI.
- **Notifications:** none. No email collection from anonymous participants.
- **Localization:** English interface, international audience, UTC storage and user-local display. No geo-specific features.
- **Analytics:** privacy-conscious aggregate usage metrics only if needed, with transparent disclosure; no invasive advertising trackers by default.

## 3. Post types and topics

| Type (DB enum) | Public label | Binary interaction | Sample |
|---|---|---|---|
| `confession` | Confessions | Reaction: `same`, `ouch`, `wild` | “I've pretended not to recognize my neighbour for three years.” |
| `petty_court` | Petty Court | `guilty` / `not_guilty` | “I changed the Wi-Fi password after my roommate ate my leftovers.” |
| `am_i_weird` | Am I Weird? | `me_too` / `just_you` | “I rehearse arguments in the shower and still lose.” |
| `hot_take` | Hot Takes | `agree` / `disagree` | “Office birthday celebrations are compulsory hostage situations.” |

**Topic slugs:** `relationships`, `family`, `work`, `social-awkwardness`, `friends`, `everyday-life`, `food-habits`, `internet-technology`, `random`. Store slugs, not display labels. Topic is optional and orthogonal to type.

### User journeys

1. **Reader:** opens `/`, sees server-rendered real posts, switches type/topic, changes sort, opens post, reads comments, shares URL.
2. **First-time participant:** taps vote/react/comment/Spill it; anonymous session initializes; action proceeds once; clear retry state on failure.
3. **Poster:** opens composer, selects type and optional topic, writes text, validates, submits once, sees published post and permalink.
4. **Voter:** selects a binary choice, sees selected state and authoritative totals; can switch choice; repeated clicks cannot create duplicates.
5. **Commenter:** comments or replies one level deep; can delete their own text; sees deleted placeholders where thread structure requires them.
6. **Reporter:** reports a post/comment with reason and optional details; gets confirmation; cannot inspect moderation outcome or other reports.
7. **Moderator:** signs in using provisioned credentials, reviews reports, hides/restores/locks content, records reasons and audit entries.
8. **Session loss:** old anonymous contributions remain but ownership controls are no longer available. Explain plainly in Settings.

## 4. Navigation and routes

| Route | Behavior |
|---|---|
| `/` | Unified feed, default `fresh` |
| `/confessions` | Filter by confession |
| `/petty-court` | Filter by petty_court |
| `/am-i-weird` | Filter by am_i_weird |
| `/hot-takes` | Filter by hot_take |
| `/post/[id]` | Canonical post, votes/reactions, comments, share, report |
| `/rules` | Community rules |
| `/about` | Brief product explanation |
| `/privacy` | Privacy and data practices |
| `/terms` | Terms of use |
| `/settings` | Anonymous identity/session explanation, preferences and local data controls |
| `/moderator/login` | Moderator authentication |
| `/moderator` | Protected report queue and actions |
| `/404` | Branded not-found state |

Use query parameters `?topic=<slug>&sort=fresh|popular|controversial&cursor=<opaque>` for shareable feed state. Invalid filters fall back safely; invalid cursors return controlled errors. Server API endpoints live under `/api/`, use appropriate HTTP methods, return consistent JSON errors, and never trust client-supplied ownership or role fields.

## 5. Technical architecture

### Chosen stack

- **Language:** TypeScript (strict mode).
- **Web framework:** Astro with SSR/hybrid output as appropriate, using the maintained Node adapter for Vercel-compatible hosting.
- **Interactive UI:** React islands only for composer, vote/reaction controls, comments, menus and other stateful interactions.
- **Styles:** Tailwind CSS v4 plus global CSS variables and a small number of reusable component styles; no UI kit that overrides the brand.
- **Database:** Supabase PostgreSQL, versioned SQL migrations, constraints, indexes and RLS.
- **Identity:** Supabase Auth anonymous users for participants; separately managed authenticated moderator accounts. SSR session handling with secure cookies and request-scoped clients.
- **Validation:** Zod at every mutation boundary, plus DB constraints.
- **Icons:** Lucide, imported selectively.
- **Testing:** Vitest, Playwright, and SQL/database authorization tests.
- **Hosting:** Vercel Astro SSR + Supabase; Cloudflare may provide DNS. Confirm runtime compatibility before deployment. No Docker requirement.
- **Dependencies:** keep minimal; no Redux, GraphQL, WebSockets, AI APIs, heavy component libraries, or unneeded state framework.

### Rendering and boundaries

- Server-render public feeds and post pages for performance and crawlability.
- Hydrate only islands that require interaction; avoid sending privileged data to client.
- Use server-only repositories/services for queries and mutations.
- Supabase client is request-scoped; never use shared mutable session state across requests.
- Browser receives only public/publishable credentials. Service-role key, if used for narrowly controlled administrative tasks, stays server-side and must never be trusted as a replacement for explicit authorization.
- No client writes directly to unrestricted tables. Apply RLS and server-side authorization even when using RPCs.
- Use parameterized queries or Supabase query builders; render content as text, never raw HTML.
- Prefer stable IDs and opaque cursors; timestamps in UTC.

### Suggested repository layout

```text
ComfartZone/
├── README.md
├── design.md
├── architecture.md              # created during foundation phase
├── roadmap.md                   # implementation status, not speculative claims
├── .env.example
├── .gitignore
├── package.json
├── astro.config.mjs
├── tsconfig.json
├── public/
│   ├── favicon.svg
│   └── assets/
├── src/
│   ├── pages/
│   │   ├── index.astro
│   │   ├── post/[id].astro
│   │   ├── api/
│   │   └── ...
│   ├── layouts/
│   ├── components/
│   │   ├── shell/
│   │   ├── feed/
│   │   ├── post/
│   │   └── interactive/
│   ├── styles/
│   ├── lib/
│   │   ├── domain/
│   │   ├── validation/
│   │   ├── server/
│   │   └── supabase/
│   └── middleware.ts
├── supabase/
│   ├── migrations/
│   └── tests/
└── tests/
    ├── unit/
    └── e2e/
```

Do not create empty placeholder folders/files merely to match this tree; add as features are built.

## 6. Database model and invariants

Use UUID keys, UTC `timestamptz`, foreign keys, indexes, explicit status enums/checks, and migrations. Design actual SQL after inspecting the environment.

### `posts`
`id`, `author_id` (auth user UUID), `type`, `topic` nullable, `content`, `status` (`published`, `hidden`, `deleted`), `locked_at` nullable, `created_at`, `updated_at`, `deleted_at` nullable. Author immutable after creation. Deletion hides text from public APIs, while preserving required audit/relationship integrity.

### `comments`
`id`, `post_id`, `author_id`, `parent_id` nullable, `content`, `status`, `created_at`, `deleted_at`. Parent must belong to same post and must be root; enforce depth at trusted server/database boundary. No comments on locked, hidden or deleted posts. Preserve minimal deleted placeholders for thread context where necessary.

### `votes`
`post_id`, `voter_id`, `choice`, `created_at`, `updated_at`; unique `(post_id, voter_id)`. Only on the three poll types; choices validated against post type in trusted transaction/RPC. Upsert atomically; switching choice does not increase voter count. Votes on hidden/deleted/locked posts prohibited.

### `reactions`
`post_id`, `visitor_id`, `reaction_type`, `created_at`, `updated_at`; unique `(post_id, visitor_id)`. Only Confessions; allow change/removal.

### `reports`
`id`, `reporter_id`, `target_kind` (`post`, `comment`), `target_id`, `reason`, `description`, `status` (`open`, `reviewed`, `dismissed`, `actioned`), `created_at`, `reviewed_at`, `reviewed_by`. Validate polymorphic targets in trusted code/RPC. Rate limit and prevent repeat submissions by same visitor for same target where appropriate. Never expose reports publicly.

### `moderator_roles`
`user_id`, `role` (`moderator`, `admin`), `granted_at`, `granted_by`. Provision securely out of band. Ordinary anonymous users cannot grant roles, and client-visible metadata is not authoritative.

### `moderation_actions`
`id`, `moderator_id`, `target_kind`, `target_id`, `action`, `reason`, `created_at`, optional metadata. Append-only to ordinary app paths; auditable.

### DB policy and consistency

- Explicit RLS on all application tables; default deny and narrowly scoped policies.
- Anonymous Auth users are authenticated principals, not the Postgres `anon` role. Differentiate them carefully.
- Public read returns only published, non-deleted content and safe aggregate counts.
- Owners may only delete their own content; moderation privileges are checked server-side and in database policy/RPC.
- Atomic voting and concurrency safety enforced in DB, not inferred from UI.
- Never expose author UUIDs, session tokens, IPs, reports or moderator-only metadata on public post payloads.
- Use indexes for feed order, post type/topic, comments by post, votes/reactions by post, reports by status.
- Use keyset pagination; never offset-scan indefinitely.
- Counters may be computed or transactionally maintained; document tradeoffs and test consistency. Do not create independently mutable public counters.
- Backup and migration rollback/recovery strategy required before production.

## 7. Ranking, filtering and pagination

- **Fresh:** `created_at DESC, id DESC` for published posts.
- **Popular:** time-decayed score derived from reactions/votes/comments and age, with a documented formula, anti-gaming safeguards and stable tie-breaks. Do not let a single vote dominate small samples. Scope initially to recent 30 days, with fallback to fresh if sparse.
- **Controversial:** for binary poll types only, prioritize balanced opposing votes with a minimum participation threshold; exclude Confessions or place them after eligible poll posts with an explicit rule. Do not equate zero votes with controversy.
- Use server-side filtering and opaque keyset cursors; initial page size 20, max 50. Never trust client-supplied sort expressions.
- When votes change, return authoritative updated totals and viewer choice. Percentages round to 100% using a deterministic remainder rule.
- Public feeds should have appropriate short-lived caching or no-store for viewer-specific data. Do not leak per-visitor state through shared caches.

## 8. Posting, comments, votes, and reports

### Posting
Select type (required), topic (optional), write 20–1,000 characters, see count, submit once, navigate to canonical permalink. Reject empty, overlong, unsupported, abusive spam-pattern or malformed input with clear messages. Avoid silently discarding user drafts; preserve while modal remains open and on recoverable errors. Do not persist sensitive drafts to third-party analytics.

### Voting
Show choices and totals; before first vote, totals may be visible but percentages should not obscure choices. Optimistic UI only if reversible and reconciled with server response. Disable duplicate requests; allow switch. Own votes are allowed. Lock/hidden/deleted posts cannot accept votes.

### Reactions
Confessions only: `Same`, `Ouch`, `Wild`. One active reaction per visitor; clicking selected reaction removes it. Return counts and viewer selection.

### Comments
Plain text, 1–500 characters, root and one reply level, default oldest first. Paginate root comments and fetch bounded replies. Delete own comments, show placeholder only if necessary for replies. Do not allow replying to deleted comments. Rate limit new comments.

### Reporting
Reasons: harassment/hate, threats, private information, sexual exploitation, spam, other. Optional details. Reports visible only to moderators. Report UI does not promise automatic removal. Duplicate/repeated reports blocked or throttled.

### Sharing
Native share sheet where available, otherwise copy canonical post URL. No fake social share counters.

## 9. Security, trust and safety

- Server-side Zod validation and database constraints on every mutation.
- Supabase SSR session verification; secure cookies, appropriate SameSite, HttpOnly where supported, and HTTPS in production.
- CSRF protection for cookie-authenticated mutations; verify origin and use framework-appropriate defenses.
- XSS protection: escaped text rendering, CSP, safe URL handling; no `innerHTML` for untrusted content.
- Parameterized database operations; never interpolate user input into SQL.
- Request-size limits, rate limits, spam heuristics, and abuse controls for session creation, posts, comments, votes and reports. Define thresholds as configuration and test enforcement. Use a durable/shared limiter in production, not process-local memory alone.
- IP-derived controls, if necessary, must be privacy-reviewed and not exposed publicly. Document retention.
- Moderator login protected, roles checked on every request, sensitive actions audited; require strong credentials and consider MFA.
- Never expose service-role keys, private env vars, stack traces or raw database errors.
- Maintain a community policy for harassment, threats, doxxing, hateful abuse, sexual exploitation, illegal content, and spam. Allow disagreement and harmless sarcasm.
- Provide functional abuse reporting and a moderation workflow before launch; do not assume automatic detection solves moderation.
- Establish content removal, appeal/contact, privacy deletion, and legal escalation procedures before production. No invented compliance claims.

## 10. Accessibility, SEO and performance

- Semantic HTML, logical heading hierarchy, visible keyboard focus, proper labels, accessible dialogs, keyboard navigation, contrast at least WCAG AA where applicable, reduced motion, and screen-reader announcements for vote updates.
- Test 320, 360, 390, 430, 768, 1024, 1440 px; no horizontal overflow, no tiny tap targets, no keyboard-obscured composer.
- Public post pages have canonical URLs, unique titles/descriptions, Open Graph metadata, sitemap inclusion when eligible, robots directives, and correct 404/410 handling as appropriate. Filter/sort variants canonicalize to base feed; moderator and session routes noindex.
- Avoid automatically indexing unmoderated abusive or near-empty pages. Create no SEO doorway pages.
- SSR content, selective hydration, paginated queries, indexed DB reads, minimal JS, optimized fonts/SVG, stable layout, accessible loading states.
- Respect user privacy; no invasive analytics by default. Document cookies/session data and retention.

## 11. Operational requirements

- `.env.example` lists variables without secrets; distinguish server-only from public values.
- Separate development/test/production Supabase projects and credentials; never point tests at production.
- Version SQL migrations, document deployment order and database recovery procedures.
- Provide health/error logging without logging post bodies or tokens unnecessarily; sanitize logs.
- Backups, retention, restore drill, monitoring, rate-limit visibility, and moderation access must be ready before production.
- Implement a clear maintenance/error page and graceful handling of database outages.
- Cloudflare DNS is separate from Vercel hosting; configure HTTPS, domain, redirects, and canonical `https://comfartzone.com` (redirect `www` to apex) when deploying.
- Verify Astro adapter, Node version, Supabase auth SSR and hosting compatibility during foundation. Do not assume configuration is correct without tests.

## 12. Android development workflow

- Work in Termux private filesystem: `~/Projects/Webpages/ComfartZone`; avoid npm installs under `/sdcard` due to symlink/permission constraints.
- Acode and Codex must be verified to open **the same** files. The Acode drawer showing a similarly named folder is not proof.
- Termux commands: `pwd`, `ls -la`, `git status`, `npm install`, `npm run dev -- --host 0.0.0.0` (if the chosen script supports this). Use `127.0.0.1:<port>` on the device to preview.
- No mandatory Docker, desktop Chrome or laptop. Use Android browser checks locally; automated Playwright browser binaries may require a supported CI runner. Do not claim full cross-browser tests were run on Android if they were not.
- Use Git commits per phase. Keep secrets and generated build files ignored.
- Codex should inspect only relevant files, make narrow changes, run focused tests, and report actual results briefly. Do not use broad audits or repeated full builds unnecessarily.

## 13. Delivery roadmap and exit gates

### Phase 0 — Environment verification
Confirm Acode/Codex filesystem identity, Node/npm versions, Git state, Android preview path, and Astro compatibility. **Gate:** same test file visible in editor and terminal; dev server reachable.

### Phase 1 — Foundation and design system
Initialize Astro + TypeScript + React + Tailwind; base layouts, tokens, responsive shell, component primitives, lint/typecheck/test scripts, `.env.example`, `architecture.md`, `roadmap.md`. **Gate:** responsive shell and tests run; no placeholder buttons pretending to work.

### Phase 2 — Frontend experience
Implement feed, four post types, topic/sort controls, post page, composer, votes/reactions, comments, report flow, empty/loading/error states using explicitly labeled fixtures. **Gate:** realistic interactive prototype, mobile/desktop review, accessible flows.

### Phase 3 — Database and anonymous sessions
Migrations, RLS, server repositories, anonymous identity/session, test isolation, post creation/read/deletion. **Gate:** cross-user authorization and persistence tests pass.

### Phase 4 — Community interactions
Atomic votes, reactions, comments, sorting, keyset pagination, sharing, post locking and ownership behavior. **Gate:** concurrency, duplicate-vote and end-to-end tests pass.

### Phase 5 — Moderation and hardening
Reports, moderator roles/dashboard, audit actions, rate limits, CSRF/XSS controls, security headers, abuse and failure paths. **Gate:** unauthorized access fails; reports/actions work; meaningful abuse controls are enforced.

### Phase 6 — Production readiness
Legal/community pages, SEO, accessibility, performance, observability, backup/restore, deployment, mobile and desktop cross-browser tests, smoke tests against production configuration. **Gate:** all essential features functional and verified; no fake counters, broken actions, missing policies or known critical security issues.

**No public launch merely to call it an MVP.** Track unimplemented work honestly. Payments, user profiles, DMs, images, AI moderation and notifications are out of scope unless the owner explicitly changes the specification.

## 14. Acceptance checklist

- [ ] Acode and Codex access the exact same project files.
- [ ] Mobile-first layouts are polished at all target widths.
- [ ] Feed and post pages render real persisted content.
- [ ] Four post types behave according to their distinct rules.
- [ ] Topics and sorts work with stable pagination.
- [ ] Anonymous sessions survive reload and cannot impersonate others.
- [ ] Authors can delete their own content but not anyone else's.
- [ ] Votes/reactions remain unique and correct under concurrency.
- [ ] Comments/replies obey depth, ownership and moderation rules.
- [ ] Reporting and moderator-only actions work and are audited.
- [ ] Rate limiting, input validation, CSRF/XSS protections and RLS are tested.
- [ ] No secrets or privileged data reach the client.
- [ ] Loading, error, empty, offline and deleted states are handled.
- [ ] Legal, privacy and community-rule pages reflect actual operations.
- [ ] Accessibility, performance, SEO and responsive tests are completed.
- [ ] Database backups, migration recovery and production monitoring are prepared.
- [ ] Deployment, HTTPS, canonical domain and smoke tests are verified.

## 15. Instructions for Codex

1. Treat `README.md` and `design.md` as binding project references. If they conflict, explain the conflict and ask rather than silently guessing.
2. Inspect existing files before creating or replacing anything. Never overwrite the specifications without explicit permission.
3. First task: verify environment, assess stack compatibility, initialize foundation **only**, and create a short `architecture.md` plus progress-oriented `roadmap.md`.
4. Do not implement the entire product in one prompt. Work in narrow phases with real tests and concise completion notes.
5. Never claim a feature, deployment, migration or test passed unless verified.
6. Surface consequential architecture, security, moderation or product changes before proceeding.
7. Keep UI copy compact and natural. Do not generate generic startup marketing prose.
