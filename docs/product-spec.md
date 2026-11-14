# ComfartZone — Product Specification

**Status:** Finalized product baseline for backend architecture review. This document governs product behavior and privacy. It does not authorize migrations, backend implementation or deployment.

## 1. Product intent

ComfartZone is a playful pseudonymous social platform for everyday annoyances, confessions, petty disputes, weird habits, hot takes and humor. Public browsing and sharing are open. Participation requires an authenticated account with a server-confirmed email address or mobile number. Ordinary profanity, sarcasm, disagreement and unpopular opinions are not violations by themselves; safety and anti-spam rules still apply.

`design.md` and the approved references govern visual design and interaction. This document governs product behavior when examples are incomplete or stale.

## 2. Accounts, verification and identity

- Guests may browse and share eligible feeds, posts, comments, topics, public profiles and search results.
- Posting, commenting, replying, voting, reacting, uploading and reporting require a valid authenticated session and at least one confirmed email address or mobile number. Verification is checked server-side on every write. There is no public verification badge.
- Launch authentication supports Supabase email magic-link/OTP and phone OTP. Recovery and contact changes require control of a verified contact and re-authentication for sensitive changes.
- Incomplete or unverified signups cannot participate. They do not reserve a public username until verified profile activation succeeds.
- Signup proposes a username that may be changed before completion. Usernames are 3–24 Unicode grapheme clusters, contain letters, numbers or underscore only, use NFKC normalization and case-folded uniqueness, and reject a maintained reserved-name list.
- A username may be changed at most once in any rolling 30-day period. Claims and renames are serialized. Previous names remain privately recorded and temporarily unavailable for reassignment; the exact reservation period remains an approval item.
- Username history is private to the account owner and authorized moderators; it is not shown publicly.
- Users select a curated avatar or use their username initial. Real names are not required.
- Public posts are pseudonymous by default. A post may instead be anonymous.
- Comments and replies are pseudonymous only; anonymous comments are not included initially.
- Anonymous posts expose no public author linkage and never appear on public profiles. They remain privately available to their owner and narrowly authorized moderators through audited access.
- Users control public attributed-post history and public comment history independently. Hiding history affects profile listings only; it does not remove otherwise eligible content from feeds, detail pages or search.
- Private account management shows the owner's retained attributed, anonymous, archived and pending-expiry posts.
- Authentication contacts, private ownership mappings and internal account identifiers must never enter public DTOs, search documents, storage paths, object metadata, analytics or recommendation outputs.

## 3. Posts and formats

- Formats are **Regular** (default), **Confession**, **Petty Court**, **Am I Weird?**, and **Hot Take**.
- A post has zero or one topic. Format and topic are independent. Hashtags are not a product feature.
- Post text is limited to **256 Unicode grapheme clusters** after trimming outer whitespace. Client and server use the same pinned segmentation policy.
- A post requires at least one non-whitespace grapheme or one valid attachment. An attachment-only post requires useful alt text.
- Published post text, format, topic, identity mode and media cannot be edited. Owners may only change the pending expiry action, archive, or permanently delete according to lifecycle rules.

### Format interactions

| Format | Allowed primary interaction |
|---|---|
| Regular | `Funny`, `Love`, `Annoying` reactions |
| Confession | `Same`, `Ouch`, `Wild` reactions |
| Petty Court | `Guilty`, `Not Guilty` vote |
| Am I Weird? | `Me Too`, `Just You` vote |
| Hot Take | `Agree`, `Disagree` vote |

- A user may have at most one active reaction or vote per post. It may be changed or removed while the post remains eligible.
- Poll formats do not accept reactions or any interactions beyond their two defined vote choices.
- Regular and Confession do not accept poll votes or reactions outside their format-specific sets.
- Aggregate counts and percentages are based only on real active selections and never expose participant identities.
- Comments, one-level replies, sharing and reporting are available on every format, subject to eligibility, authentication and moderation rules. Sharing produces a public canonical link and does not bypass content eligibility.

## 4. Media

- A post may contain at most one JPEG, PNG, WebP or GIF, maximum 2 MB by authoritative byte count.
- SVG, ambiguous/polyglot, malformed or unsupported files are rejected even if their extension or declared MIME appears allowed.
- The server verifies actual type and decodability, applies dimension and abuse limits, re-encodes static images, strips unsafe metadata and prevents ownership leakage through filenames, paths or metadata.
- GIFs may remain animated after validation and metadata stripping. The interface must respect reduced-motion requirements and provide an approved motion-control treatment.
- Attachment-only posts require useful alt text. Alt text is optional when adjacent post text already provides an equivalent description, but the composer must support it.
- Comments and replies are text/emoji only.

## 5. Comments and replies

- Comments and replies contain 1–256 Unicode grapheme clusters after trimming.
- Threads support root comments and one reply level only. Replies cannot receive replies.
- Comments are immutable after publication. Owners may delete their comments.
- A deleted root with retained live replies becomes a neutral tombstone; otherwise it is removed from public presentation.
- Comments cannot be created on locked, expired, archived, deleted, removed or otherwise ineligible posts.
- Public comment history follows the user's comment-history visibility setting. Comment ownership and internal account identifiers remain private.

## 6. Quotas and abuse controls

- A verified account may create at most three posts in any rolling 24-hour window, calculated from authoritative database creation timestamps.
- Deleted, archived, removed and expired posts consume their original slot until it leaves the window.
- Enforcement is atomic and concurrency-safe. A rejection returns the earliest actual retry time.
- Separate rate limits apply to signup/verification, username claims, uploads, comments/replies, reactions/votes, reports, search and account-sensitive operations.
- Duplicate-content detection and abuse scoring supplement verification. Email/phone confirmation does not prove unique personhood.

## 7. Post lifecycle

- A normal post remains active until archived, permanently deleted, moderated or affected by account lifecycle.
- A post may optionally expire exactly 24 hours after creation.
- The default expiry action is **archive privately**. The author may explicitly select permanent deletion and may change the pending action before expiry.
- At expiry, the post, comments, interactions and media immediately become unavailable through all public feeds, search, profiles, detail routes and media delivery, regardless of cleanup-job status.
- Private archives are readable only by the verified owner and authorized moderators and cannot receive interactions.
- Permanent deletion removes public access immediately and schedules irreversible content and media cleanup, except for narrowly retained moderation, security or legal evidence.
- Locked posts may remain publicly readable when otherwise eligible but reject new comments, votes and reactions with a clear reason.
- Expiry, archival, deletion and cleanup operations are idempotent and must never resurrect content.

## 8. Account deletion

- A deletion request immediately disables participation, signs out active sessions and removes the public profile from profile discovery.
- The user chooses one of two modes:
  1. **Delete contributions:** remove all owned posts, comments, media and interactions through the normal deletion pipeline.
  2. **Preserve anonymously:** convert eligible attributed posts to anonymous presentation, replace retained comment attribution with `Deleted user`, remove reactions/votes and delete the public profile.
- Existing anonymous posts remain anonymous in preserve mode. Private ownership is retained only during the deletion/recovery window and for approved moderation/legal holds, then removed.
- Account deletion removes recommendation signals and nonessential private data. Security and moderation evidence may remain only for its documented retention period.
- The exact deletion recovery window is unresolved and must be approved before migration.

## 9. Feed, discovery and recommendation signals

- **For You** is the default feed and combines eligibility, freshness, topic/format preference, engagement quality, diversity and controlled exploration without treating outrage or report volume as quality.
- **Latest** is a chronological alternative with stable cursor ordering.
- Guests, opted-out users and new accounts receive a diverse cold-start feed.
- Initial ranking uses transparent PostgreSQL/application scoring; no ML infrastructure is required.
- Search covers eligible post text, public usernames and topics.
- Search and feeds exclude expired, archived, deleted, removed and restricted content and never reveal anonymous ownership or hidden profile listings.
- Necessary first-party impression and interaction signals are retained for 90 rolling days. Users may opt out of personalized signal collection; existing signals are deleted on opt-out or account deletion unless independently required for security.
- Ranking weights are configurable operational values and must be documented and reviewed before launch.
- No fabricated trends, posts, votes, reactions or engagement.

## 10. Moderation, reports and appeals

- Verified participants may report eligible posts or comments on every format. Reports and reporter identities are private.
- Report volume alone never automatically removes content.
- Prohibited content includes spam/scams, coordinated flooding, credible threats, doxxing, sustained targeted harassment, exploitation/CSAM and serious illegal or dangerous content.
- Ordinary disagreement, profanity, satire and unpopular opinions are not removed solely for offensiveness.
- Moderators are separately provisioned. Private-authorship access and every moderation action require authorization, a reason and append-only audit history.
- Moderation supports review queues, content locks/removal, account restrictions, reasons, evidence and appeals.
- Restricted moderation evidence is retained for 180 days after case resolution and extended only for documented legal or safety reasons.
- The final report-reason catalog, appeal eligibility/window and legal escalation procedure remain policy approval items.

## 11. Privacy and security requirements

- Public APIs expose explicit allowlisted DTOs and never return auth UUIDs, contacts, verification metadata, private ownership, reports, security flags, recommendation signals or moderator data.
- Anonymous ownership must not be inferable through joins, identifiers, counts, errors, timing, media paths, caches, analytics or recommendations.
- Public profiles show username, avatar and only activity allowed by the user's history settings.
- Attributed posts remain attributed and searchable when profile history is hidden.
- Service-role credentials are server-only. Authorization is enforced independently by API checks, database constraints, grants and RLS.

## 12. Non-goals

No follower system, direct messages, notifications, hashtags, real-name requirement, prestige verification badge, payments or AI moderation are included unless separately approved.

## 13. Remaining approval decisions

The following are unresolved and must not be silently assumed:

1. Exact previous-username reservation/reassignment period.
2. Account-deletion recovery window.
3. Final report reasons, appeal eligibility/window and legal escalation procedure.
4. Final GIF reduced-motion interaction and maximum animation/dimension limits.
5. Long-term moderation-audit and security-log retention after legal/privacy review.
6. Final navigation/Explore destinations; this does not block the core database model.

## 14. Implementation gate

The product behavior above is approved except for section 13. No SQL migration or backend implementation may begin until the architecture, ERD, lifecycle/retention matrix, RLS/grants, storage design, endpoint contracts and remaining schema-affecting decisions are reviewed and explicitly approved.