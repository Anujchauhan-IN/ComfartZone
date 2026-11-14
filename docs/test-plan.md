# ComfartZone — Test and Acceptance Plan

**Status:** Planning baseline. Tests are not yet implemented or executed. Product behavior comes from `docs/product-spec.md`; visual/interaction acceptance comes from `design.md`.

## 1. Visual and accessibility gate

- Compare real browser screenshots against both approved references at 320, 360, 390, 430, 768, 1024 and 1440 CSS px. Human review must confirm at least 80% qualitative fidelity and document discrepancies.
- Test 200% zoom, large OS text, long Unicode content, safe-area insets and Android keyboard-open composer behavior.
- Verify CZ-only header branding, one profile/sign-in entry, compact text-first composer, no duplicate format navigation and no obscured content.
- Verify prompt “What ruined your day today?”, CTA “Spill it”, Regular default, identity toggle, one-file media control, clock toggle and private-archive default.
- Keyboard-test focus order, visible focus, dialog trap/Escape/restoration, announcements, 44×44 targets where practical, non-color selected states and reduced motion.
- Verify GIF motion handling according to the approved media accessibility policy.

## 2. Core acceptance matrix

| Area | Must pass |
|---|---|
| Public browsing | Guests can view eligible For You/Latest feeds, detail, comments, profiles, topics and search |
| Verification | Signed-out and unverified accounts cannot post, comment, reply, vote, react, upload or report through UI, API, RPC or direct table access |
| Signup | Generated username can be changed before completion; activation requires verified email or phone and an atomic unique username claim |
| Username changes | Rolling 30-day cooldown, normalization and uniqueness survive concurrent requests |
| Identity/privacy | Attributed content shows safe pseudonym/avatar; anonymous ownership never leaks; owner retains authorized private access |
| Profile history | Hidden attributed posts remain feed/search-visible but are absent from profile history; anonymous posts never appear publicly on profiles |
| Composer | Regular default; optional single topic, anonymity, one attachment and optional 24h expiry; 256-grapheme validation |
| Quota | Fourth post in rolling 24h is rejected with retry time; deletion/archive/expiry does not refund; concurrency cannot bypass |
| Media | Exactly zero or one allowed image/GIF; <=2 MB; true-type validation, metadata stripping, safe serving and cleanup |
| Interactions | One active eligible reaction/vote per user/post; transactional replacement/removal according to approved policy; correct aggregates |
| Comments | 256 graphemes, text only, one reply level, ownership, rate limits and active/unlocked-post checks |
| Expiry | Exact public disappearance across every read surface; private archive default or selected permanent deletion applied safely |
| Deletion/archive | Immediate eligibility removal, authorized owner/moderator action, no orphan media, approved child/evidence retention |
| Moderation | Private reports, abuse controls, audited role checks/actions and no automatic removal from report volume |
| Search | Eligible posts, public usernames and topics only; no hidden/expired/private ownership leakage |
| Feed | For You default, diverse cold start, Latest chronological alternative, stable cursors and no ineligible content |
| Recovery/deletion | Approved recovery and account-deletion behavior preserves privacy and justified retention only |

## 3. Identity, verification and username tests

- Verify with email only, phone only and both; remove/change a confirmed contact and confirm eligibility follows trusted auth state.
- Revoke/expire sessions and confirm writes fail immediately.
- Ensure incomplete signups cannot reserve participation indefinitely; test approved cleanup behavior.
- Test username normalization, case-insensitive collisions, reserved names, minimum/maximum length and unsafe Unicode.
- Race concurrent claims and renames; at most one succeeds.
- Reject rename at 29d 23h 59m; allow at 30 rolling days using database time.
- Verify rename attribution/URL/history behavior matches the approved policy.
- Exercise recovery and account deletion after their approval, including loss of one contact method.

## 4. Content and Unicode tests

- Exercise all five formats; Regular is default and only poll formats accept their defined choices.
- Test zero and one topic; reject multiple topics, hashtags-as-feature fields and unsupported topic IDs.
- Count grapheme clusters consistently for ASCII, combining marks, ZWJ emoji, skin tones, flags and mixed normalization forms.
- Reject whitespace-only content and inputs above 256 graphemes; enforce a conservative byte ceiling.
- Verify post text cannot be edited after publication.
- Test approved attachment-only/minimum-text and alt-text rules once finalized.
- Comments and replies reject media, content above 256 graphemes, cross-post parents and nesting deeper than one reply.
- Test comment deletion/tombstone behavior after approval.

## 5. Media and storage tests

- Accept each approved image/GIF type; reject spoofed MIME, SVG, polyglots, malformed files and unsupported formats.
- Reject files over 2 MB and a second attachment before publication.
- Verify dimensions/decoding, metadata stripping, opaque object keys and no contact/owner data in metadata or URLs.
- Ensure failed or abandoned staging uploads expire and never become public.
- Retry create-post with the same idempotency key; create one post and one attachment only.
- Archive, expire, delete or moderate a post and verify storage access/cache behavior immediately and after cleanup.
- Re-run cleanup jobs and process them out of order; no duplicate deletion or resurrection.
- Test GIF animation controls and reduced-motion behavior after policy approval.

## 6. Quota, concurrency and idempotency tests

- Create three posts across midnight and reject the fourth until the oldest creation exits the rolling window.
- Race parallel creates at the quota boundary; never commit more than three eligible quota events.
- Confirm archived, deleted, expired and moderated posts still consume their original window slot.
- Failed validation/staging does not consume quota; committed posts do.
- Reusing an idempotency key with the same request returns the original result; different payload is rejected.
- Race username claims, expiry-action changes, archive/delete and expiry workers under row locks/version checks.

## 7. Interaction and discussion tests

- Reject reactions/votes from guests, unverified accounts and ineligible/restricted accounts.
- Reject votes on Regular/Confession and invalid choices on poll formats.
- Verify approved reaction taxonomy and eligible formats before release.
- Concurrent reaction/vote selection never creates duplicate active rows or incorrect aggregates.
- Test replacement and removal only according to the approved vote/reaction policy.
- Reject every write to locked, expired, archived, deleted or moderation-removed posts with a safe reason.
- Prevent rapid duplicate comments/replies and enforce separate write limits.
- Verify deleted-root placeholder behavior after policy approval.

## 8. Expiry, archive and deletion tests

- At the exact database-time expiry boundary, remove the post from feed, Latest, search, profile, detail, comments, interactions and media access before cleanup executes.
- Default a 24-hour post to private archive; verify an explicit permanent-delete selection.
- Change the pending expiry action while a worker runs; one locked/versioned outcome wins.
- Owners can read private archives; other users and guests cannot enumerate them.
- Stale detail URLs, cursors, caches and signed media URLs do not expose ineligible content.
- Repeated/delayed workers remain idempotent and cannot resurrect content.
- Verify account deletion and moderation/legal holds against the approved retention matrix.

## 9. Privacy, RLS and adversarial tests

- Exercise every table/view/function as guest, unverified user, verified owner, other verified user and moderator.
- Attempt direct Supabase writes bypassing Astro endpoints; default-deny RLS and grants still protect data.
- Forge user IDs, ownership, verification flags, moderator roles, timestamps, expiry actions, media paths and counters.
- Probe anonymous authorship through columns, joins, filters, counts, timing, errors, storage paths, metadata, caches, analytics, search and recommendation outputs.
- Verify moderator unmasking requires the dedicated role, reason and an immutable audit record.
- Ensure owners can read only their own anonymous/private content and cannot expose ownership through crafted filters.
- Audit `SECURITY DEFINER` functions for fixed `search_path`, minimal grants and auth-derived identity.
- Test XSS-safe rendering, malformed Unicode, request-size limits and structured errors without stack/private-data leakage.

## 10. Moderation, spam and reporting tests

- Report eligible posts/comments using every approved reason; reject invalid, duplicate or rate-limited reports safely.
- Flood reports against ordinary disagreement; content is not automatically removed solely by volume.
- Test duplicate posts, coordinated posting, signup/verification abuse and separate endpoint limits.
- Restricted accounts cannot bypass controls with direct calls or stale sessions.
- Moderator provisioning and role escalation are not available to ordinary users.
- Audit logs are append-only to application paths and record sensitive authorship access and moderation actions.
- Test evidence retention, appeals and legal/safety holds after policy approval.

## 11. Search and feed tests

- For You is the default; Latest uses deterministic `created_at DESC, id DESC` keyset ordering.
- Guest/new-account cold start is eligible, diverse and useful without fabricated activity.
- Search finds eligible post text, public usernames and topics; it excludes private profile listings, expired/archived/deleted/removed content and anonymous author linkage.
- Hidden profile history changes profile results only; attributed posts remain discoverable.
- Verify ranking does not treat raw outrage/report volume as quality and enforces author/topic diversity.
- Test pagination stability while new posts arrive and while content becomes ineligible.
- After approval, test signal opt-out, retention expiry, account deletion and anti-manipulation controls.

## 12. Functional journeys

1. Guest browses/searches, attempts participation and receives a clear signup/verification path.
2. User verifies email or phone, finalizes generated username/avatar and creates an attributed Regular post.
3. User creates an anonymous post; it appears author-neutral publicly, absent from public profile, and present privately.
4. User hides public profile history without hiding attributed content from feeds/search.
5. User posts one valid image/GIF and is prevented from adding a second or oversized file.
6. User creates a 24-hour post with default private archive and another with permanent deletion; observe exact expiry.
7. User reaches the rolling quota and sees the actual retry time.
8. User votes/reacts according to approved policies, comments and replies one level.
9. User archives/deletes content; stale public routes/search/media stop exposing it.
10. Moderator reviews genuine abuse, audits anonymous ownership access and dismisses false mass reports without automatic takedown.
11. For You adapts using approved signals while Latest remains stable and controllable.

## 13. Evidence and release gates

- During design: requirement traceability, ERD review, lifecycle/retention matrix, RLS/grants review, threat model and query-plan estimates.
- During implementation: clean-database migrations, SQL constraints/RLS, concurrency, storage lifecycle and endpoint integration tests.
- During frontend integration: component tests, real-browser E2E, accessibility and visual regression.
- Before deployment: production-like staging rehearsal, backup/restore drill, rate-limit/abuse exercise and privacy review.
- Reports distinguish document review, static code inspection, HTTP checks, automated interactions and actual screenshots.

Release is blocked by unresolved schema/privacy decisions, anonymous identity leakage, unverified writes, quota bypass, invalid interactions, public expired content, unsafe uploads, uncontrolled abuse, missing moderation workflow, broken deletion/expiry, failed visual/accessibility gates or untested recovery/restore assumptions.
