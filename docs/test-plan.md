# ComfartZone — Test and Acceptance Plan

**Status:** Architecture-aligned pre-implementation test design. No backend tests or migrations exist yet. Product behavior comes from `docs/product-spec.md`; visual behavior comes from `design.md`.

## 1. Evidence levels and release gates

Reports must distinguish document review, static inspection, SQL tests, endpoint integration, automated browser interaction, screenshots and human visual review. Do not claim a category that was not performed.

Release requires:

- clean-database migration and rollback rehearsal after migrations are separately approved;
- constraints, indexes, RLS/grants, RPC and storage-policy tests;
- concurrency and idempotency tests against PostgreSQL, not mocks alone;
- production-like endpoint, worker, backup/restore and abuse testing;
- real-browser accessibility and screenshot review at 320, 360, 390, 430, 768, 1024 and 1440 CSS px;
- at least 80% qualitative visual fidelity to both approved references, confirmed by human review.

## 2. Requirement traceability matrix

| Area | Required acceptance |
|---|---|
| Browsing/sharing | Guests can read and share only eligible public content; sharing never bypasses eligibility |
| Participation | Every write requires valid auth, trusted email/phone verification and an active unrestricted account |
| Identity | Pseudonymous attribution is safe; anonymous post ownership never leaks; comments remain pseudonymous |
| Usernames | Approved syntax/normalization, atomic uniqueness and rolling 30-day cooldown |
| Formats | Exact reaction/vote compatibility; comments, replies, sharing and reporting on all formats |
| Content | 256 graphemes, approved minimum, one optional topic, immutable publication |
| Media | One JPEG/PNG/WebP/GIF <=2 MB, validated bytes, safe metadata/storage/delivery/cleanup |
| Quota | Three posts per rolling 24 hours, atomic under concurrency, no deletion refund |
| Lifecycle | Immediate eligibility removal; private archive default for optional 24-hour posts |
| Accounts | Recovery/contact controls and both approved account-deletion contribution modes |
| Moderation | Private reports, case-bound actions/authorship access, appeals and 180-day evidence retention |
| Discovery | Eligible search, stable Latest and privacy-safe personalized For You with 90-day signals |
| Security | Default-deny access, narrow RPC grants, safe DTOs/errors/logs and service-role isolation |

## 3. Schema, migration and constraint tests

When SQL is approved and implemented:

- Create the database from zero and verify every enum value, table, FK, unique key, check constraint, partial index, search index and grant matches the reviewed architecture.
- Verify `private` is not an exposed PostgREST schema and `anon`/`authenticated` have no privileges on it.
- Reject invalid post state/timestamp combinations, mismatched expiry columns and expiry times other than exactly creation +24h.
- Reject anonymous posts with public author IDs and attributed posts without required author presentation.
- Reject more than one media row per post and media over 2,097,152 bytes.
- Reject reaction/vote duplicate keys and report target rows with zero or two targets.
- Verify immutable post/comment content and quota timestamps cannot be changed through direct SQL roles or APIs.
- Confirm FK deletion behavior cannot orphan ownership, media, comments, reports or moderation records.
- Use representative query volumes to inspect plans for Latest, topic/format feeds, profiles, expiry scans, comments, search, moderation queues and owner activity.

## 4. Authentication, verification and account lifecycle

- Activate with verified email only, phone only and both; reject signed-out, expired-session and unverified activation.
- Confirm incomplete auth records cannot reserve usernames or participate.
- Remove/change a confirmed contact and verify eligibility follows current trusted auth state.
- Require recent re-authentication/verified-contact control for sensitive contact changes and account deletion.
- Revoke sessions and confirm writes stop immediately.
- Restrict an account and attempt every RPC/direct table path; reads and writes match restriction policy.
- Request each account deletion mode; immediately disable participation/profile discovery and revoke sessions.
- Cancel deletion only within the approved recovery window after re-verification.
- Execute `delete_contributions`: remove all owned posts/comments/media/interactions and signals, subject only to holds.
- Execute `preserve_anonymously`: convert attributed posts safely, show `Deleted user` on retained comments, remove selections/profile/signals and eventually remove private ownership.
- Verify existing anonymous posts remain author-neutral and no deleted account can be reconstructed from public data.

## 5. Username and profile tests

- Accept 3–24 grapheme usernames containing approved letters/numbers/underscore; reject whitespace, punctuation, reserved names, unsafe normalization and over-limit values.
- Test NFKC and case-fold collisions, combining forms, confusables covered by policy and concurrent claims; only one claim succeeds.
- Race two renames and claim/release operations using deterministic locks.
- Reject rename at 29d 23h 59m; allow at 30 rolling days using database time.
- Verify prior-name reservation for the approved period and no public username-history endpoint.
- Test avatar retirement: existing profiles render it; new selection rejects it.
- Hide post and comment histories independently. Eligible attributed content remains visible in feeds/search/detail but not the hidden profile list.

## 6. Content, formats and Unicode

- Create all five formats; Regular is default and topic cardinality is zero or one.
- Count grapheme clusters consistently for ASCII, combining marks, flags, ZWJ families, skin tones and normalized variants.
- Accept exactly 256 graphemes and reject 257, whitespace-only posts/comments and oversized byte payloads.
- Accept text-only and valid attachment-only posts; require useful alt text for attachment-only posts.
- Reject attempts to edit body, format, topic, identity or media after publication through endpoints, RPCs and direct access.
- Verify exact interaction matrix:
  - Regular: Funny/Love/Annoying only;
  - Confession: Same/Ouch/Wild only;
  - Petty Court: Guilty/Not Guilty only;
  - Am I Weird?: Me Too/Just You only;
  - Hot Take: Agree/Disagree only.
- Reject reactions on all poll formats, votes on Regular/Confession and every cross-format value.
- Verify comments, one-level replies, canonical sharing and reporting on every format.

## 7. Comments and replies

- Create a root and one reply; reject reply-to-reply, cross-post parent and nonexistent parent.
- Reject comments on locked, expired, archived, deleted or moderation-removed posts.
- Ensure comment body and author cannot be edited.
- Delete a root with live replies and verify neutral tombstone with no original body; delete an unthreaded comment and verify removal.
- Race reply creation against root deletion; produce one valid serialized outcome.
- Reject comment media and rapid duplicate submissions; confirm idempotency and rate-limit errors are recoverable.
- Verify hidden comment history and account-deletion `Deleted user` presentation without ownership leakage.

## 8. Reactions, votes and aggregates

- Signed-out/unverified/restricted users cannot interact through UI, endpoint, RPC or table paths.
- Create one valid selection, change it and remove it; at most one active row exists per user/post.
- Race parallel changes/removal; the final row and aggregate are consistent.
- Validate aggregate counts and poll percentages from real active rows, including zero-selection state and rounding.
- Ensure aggregate views never expose participant IDs or permit filtering that reveals them.
- Lock/archive/expire/delete/moderate a post and reject all new or changed selections immediately.
- Verify account deletion removes the user's reaction/vote rows and reconciles totals.

## 9. Posting quota, idempotency and concurrency

- Create three posts across midnight and reject the fourth until the oldest event exits the rolling 24-hour window.
- Race many creates at the boundary; commit no more than three quota events.
- Verify deleted, archived, expired and moderated posts still consume their slot.
- Failed validation/upload association consumes no slot; a committed post does.
- Return the correct earliest retry timestamp.
- Replay the same create request/idempotency key and receive the original safe response without another post, media association or quota event.
- Reuse a key with a different normalized request and receive `IDEMPOTENCY_CONFLICT`.
- Verify idempotency cleanup does not expire create-post protection before its defined retention.

## 10. Media and storage security

- Accept valid JPEG, PNG, WebP and GIF bytes; reject spoofed MIME/extensions, SVG, polyglots, malformed decoders and unsupported formats.
- Reject zero-byte, >2 MB, excessive-dimension, excessive-frame/duration and decompression-bomb inputs according to approved limits.
- Verify static image re-encoding and metadata stripping; verify GIF metadata processing and reduced-motion behavior.
- Confirm storage keys/metadata contain no user, username, profile or post identifiers.
- Stage only for verified eligible owners; bind authorization to media ID, size/type expectation and expiry.
- Reject attaching another user's, expired, unvalidated, quarantined or already attached media.
- Fail create-post after upload and ensure no object becomes public; purge abandoned staging idempotently.
- Request media for active, locked, anonymous, archived, expired, deleted and removed posts. Only eligible public or authorized owner/private requests succeed.
- Verify no public bucket, enumerable object URL or long-lived cache exposes content after eligibility changes.
- Re-run/out-of-order cleanup jobs and confirm originals/derivatives are removed once with no resurrection.

## 11. Expiry, archive, deletion and workers

- At exact database-time expiry, exclude the post from For You, Latest, search, profile, detail, comments, interactions, share metadata and media before the worker runs.
- Confirm 24-hour posts default to `archive_private`; explicitly select permanent deletion.
- Owner reads private archive; guests and other users cannot enumerate it.
- Change expiry action while the worker runs; row lock/version produces one outcome and stale jobs cancel safely.
- Archive/delete concurrently with expiry and moderation; immediate eligibility and final state remain coherent.
- Retry failed jobs with `FOR UPDATE SKIP LOCKED`; verify deduplication, target-version checks and terminal failure monitoring.
- Apply legal/evidence hold and confirm it prevents physical evidence deletion without restoring public access.

## 12. RLS, grants and anonymous privacy

Test every exposed view/function and every base table as guest, unverified user, verified owner, other verified user and moderator.

- Attempt direct writes bypassing Astro; grants and RLS deny them.
- Forge user IDs, profile IDs, verification flags, moderator roles, timestamps, counters, ownership, state, expiry and storage keys.
- Query/filter/order/count public DTOs to infer anonymous owners; no owner-correlated identifiers or row-existence side channels appear.
- Probe ownership through errors, timing, pagination cursors, search documents, media paths, cache headers, logs, analytics and recommendation signals.
- Owners can retrieve only their own private/anonymous/archive activity through safe functions.
- Moderator authorship access requires active role, case/reason and append-only audit row.
- Revoke moderator role mid-session; subsequent sensitive calls fail.
- Audit all `SECURITY DEFINER` functions for fixed `search_path`, explicit grants, trusted `auth.uid()` and safe exceptions.
- Confirm service-role credentials never appear in client bundles, endpoint responses or logs.

## 13. Endpoint contract tests

- Validate methods, content types, body/query limits, CSRF/origin policy and structured error mapping.
- Exercise feed/search/detail/profile/topic/media reads with valid, malformed and stale opaque cursors.
- Verify stable pagination while new posts arrive and content becomes ineligible.
- Require `Idempotency-Key` on duplicate-sensitive writes and version/`If-Match` on race-sensitive changes.
- Return uniform safe not-found responses for private/nonexistent targets where enumeration matters.
- Verify canonical share pages and metadata disappear with content eligibility.
- Confirm endpoints call the authoritative RPC/read layer and cannot weaken database authorization.

## 14. Search, feeds and recommendation signals

- Latest orders exactly by `created_at DESC, post_id DESC` with no duplicates/skips across pages.
- Search eligible post text, public usernames and topics; exclude archives, expiry, deletion, removal, private profile listings and anonymous author linkage.
- Hidden history changes profile lists only; attributed posts remain searchable.
- For You excludes ineligible content before scoring and enforces freshness, diversity and exploration.
- Report volume/outrage is never a positive ranking signal.
- Guests, new accounts and opted-out users receive a useful cold-start feed without fabricated activity.
- Collect only approved minimal signals; verify no contacts, owner IDs or raw network identifiers.
- Opt out and verify collection stops and existing signals/preferences purge. Account deletion does the same.
- Expire signals and derived preferences at 90 days and test delayed/retried purge jobs.
- Attempt signal manipulation, repeated refreshes and coordinated interactions; abuse controls prevent simple ranking takeover.

## 15. Reporting, moderation and appeals

- Submit reports for posts/comments on every format using each approved reason; reject invalid target/reason combinations and duplicate/rate-limited reports safely.
- Flood reports against ordinary disagreement; content remains until an authorized moderation decision.
- Provision moderator roles only through the approved administrative path; ordinary users cannot self-escalate.
- Open/assign/resolve cases, lock/remove/restore content, restrict accounts and append immutable actions.
- Verify every action records moderator, case, reason, timestamp and safe before/after state.
- Test appeals once the catalog/window is approved: eligibility, duplicate prevention, reviewer separation and uphold/overturn effects.
- Resolve a case and purge restricted evidence after 180 days; extend only with documented legal/safety hold.
- Verify audit and security retention follows the final legal policy and cannot be altered by ordinary application roles.

## 16. Error, logging and resilience tests

- Map each architecture error code to safe HTTP status/UI guidance without stack traces or private existence clues.
- Inspect logs for tokens, contacts, post ownership, reports, raw bodies, storage keys and raw network identifiers.
- Simulate database/storage/worker timeout, duplicate delivery, partial failure and restart; transactions roll back or jobs retry without duplicate effects.
- Monitor expiry lag, stuck jobs, storage orphans, failed signal/evidence purge and moderation queue age.
- Back up and restore a production-like dataset; recheck RLS, ownership isolation, search indexes, jobs and media references afterward.

## 17. Visual and accessibility acceptance

- Verify CZ-only branding, one profile/sign-in entry, compact composer and no duplicate format navigation.
- Verify prompt “What ruined your day today?”, CTA “Spill it”, Regular default, optional topic, identity toggle, one-file media control and private-archive expiry default.
- Show exact format interactions and accessible selected/removal states without color-only meaning.
- Test keyboard order, visible focus, dialog trap/Escape/restoration, announcements and practical 44×44 targets.
- Test 200% zoom, large OS text, long Unicode, Android keyboard, safe-area insets and reduced motion/GIF controls.
- Use real screenshots and human comparison; do not infer visual fidelity from code inspection.

## 18. End-to-end journeys

1. Guest browses/searches/shares, then receives sign-in/verification guidance on attempted participation.
2. User verifies email or phone, atomically claims username/avatar and creates an attributed Regular post with a valid reaction flow.
3. User creates a Confession and exercises Same/Ouch/Wild; no poll vote is accepted.
4. User creates each poll format and changes/removes only its valid binary vote.
5. User creates an anonymous attachment-only post with alt text; ownership stays private across every surface.
6. User comments/replies/reports on every format, then deletes a root with retained replies.
7. User reaches the rolling quota and receives the real retry time despite deleting a prior post.
8. A 24-hour post privately archives by default; another permanently deletes exactly at expiry.
9. User hides profile histories, opts out of personalization and verifies feed/search/privacy behavior.
10. User completes each account-deletion mode and retention cleanup.
11. Moderator reviews genuine abuse, audits an anonymous authorship access, handles an appeal and dismisses false mass reports.

## 19. Remaining test blockers

Test cases cannot be finalized for these unresolved decisions:

1. Previous-username reservation duration.
2. Account-deletion recovery window.
3. Report-reason catalog, appeal eligibility/window and legal escalation procedure.
4. GIF frame/duration/dimension and reduced-motion limits.
5. Long-term moderation-audit and security-log retention.

Release is blocked by any anonymous identity leak, unverified write, quota bypass, invalid format interaction, publicly available expired/private content, unsafe media path, RLS/grant gap, unaudited moderation access, retention failure, unstable feed/search pagination, failed backup/restore or failed visual/accessibility gate.