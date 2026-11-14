# ComfartZone — Product Specification

**Status:** Consolidated planning baseline for approval. This document governs product behavior and privacy. It does not authorize backend implementation or migrations.

## 1. Product intent

ComfartZone is a playful, pseudonymous social platform for everyday annoyances, confessions, petty disputes, weird habits, hot takes and humor. Public browsing is open. Participation requires an authenticated account with a confirmed email address **or** confirmed mobile number. Ordinary profanity, sarcasm, disagreement and unpopular opinions are not violations by themselves; safety and anti-spam rules still apply.

The visual and interaction contract is defined by `design.md` and the approved reference images. Product behavior in this document takes precedence when visual examples are incomplete.

## 2. Accounts, verification and public identity

- Guests may browse public feeds, posts, comments, topics, public profiles and search results.
- Posting, commenting, replying, voting, reacting, uploading and reporting require authentication plus at least one server-confirmed email address or mobile number. Verification is checked on every write. There is no public verification badge.
- Incomplete or unverified signups may exist temporarily but cannot participate.
- Signup proposes a unique username which the user may change before completion. Usernames are case-insensitively unique.
- After signup, a username may be changed at most once in any rolling 30-day period. Concurrent changes must not bypass the cooldown.
- Users select a curated avatar or use their username initial. Real names are not required.
- Public activity is pseudonymous by default. A post may instead be marked anonymous.
- Anonymous posts expose no public author linkage and never appear on a public profile. They remain accessible to their owner privately and to narrowly authorized moderators through audited access.
- Users may hide attributed post history from their public profile. Hiding profile history does not remove those posts from feeds or search and does not make them anonymous.
- Private account management shows the owner's retained attributed, anonymous, archived and pending-expiry posts.
- Authentication contacts, private ownership mappings and internal account identifiers must never appear in public DTOs, search indexes, storage paths, object metadata, analytics or recommendation outputs.

## 3. Content model

### Posts

- Formats are: **Regular** (default), **Confession**, **Petty Court**, **Am I Weird?**, and **Hot Take**.
- Poll choices are fixed by format: Petty Court = Guilty/Not Guilty; Am I Weird? = Me Too/Just You; Hot Take = Agree/Disagree.
- A post has zero or one topic. Formats and topics are independent. No hashtags.
- Post text is limited to **256 Unicode grapheme clusters**, including whitespace, punctuation and emoji after trimming outer whitespace. Client and server use the same segmentation policy.
- Published posts cannot be edited. Owners may archive or permanently delete them according to lifecycle rules.

### Media

- A post may contain at most **one** image or GIF, maximum **2 MB**.
- The server validates actual file type and byte size before publication, strips unsafe metadata and prevents ownership leakage through filenames, paths or metadata.
- Comments and replies are text/emoji only; no comment media in the initial product.

### Comments and replies

- Comments and replies are limited to **256 Unicode grapheme clusters** after trimming.
- Threads support roots and one reply level only. Replies cannot receive replies.
- Comments cannot be created on expired, archived, deleted, removed or locked posts.

### Reactions and votes

- At most one active reaction per user per eligible post. Changing a reaction replaces the previous reaction; removing it is allowed.
- At most one active vote per user per eligible poll post. Choices must match the post format.
- Votes and reactions are separate interaction types. Aggregate results never expose participant identities.

### Posting quota

- A verified account may create at most **three posts in any rolling 24-hour window**, calculated from authoritative creation timestamps.
- Deleted, archived, removed and expired posts still consume their original quota slot until the 24-hour window passes.
- Quota enforcement is atomic; simultaneous requests cannot exceed it. Rejections return the actual earliest retry time.
- Separate rate limits are required for signup/verification, uploads, comments, votes, reactions, reports, search and username changes.

## 4. Post lifecycle

- Regular posts remain active until archived, permanently deleted, moderated or affected by account lifecycle.
- A post may optionally expire exactly 24 hours after creation.
- The default expiry action is **archive privately**. The author may explicitly choose permanent deletion instead and may change the pending action before expiry.
- At expiry, the post, comments, interactions and media become immediately unavailable through every public feed, search result, profile, detail route and public storage path, even if cleanup jobs have not run.
- A private archive is readable only by its verified owner and authorized moderators. Archived content cannot receive public interactions.
- Permanent deletion removes public access immediately and schedules irreversible content/media cleanup, subject only to approved moderation, security or legal retention.
- Locked posts may remain publicly readable when otherwise eligible but reject new comments, votes and reactions with a clear reason.
- Cleanup and expiry operations must be idempotent and must not resurrect content.

## 5. Feed, discovery and search

- **For You** is the default feed. It combines eligibility, freshness, topic/format preferences, engagement quality, diversity and controlled exploration without treating outrage as quality.
- **Latest** is an available chronological alternative with stable cursor ordering.
- Guests and new accounts receive a diverse cold-start feed of eligible content.
- Initial ranking uses transparent PostgreSQL/application scoring; no ML infrastructure is assumed.
- Search covers eligible posts, public usernames and topics.
- Search and feeds exclude expired, archived, deleted, removed and restricted content and never reveal anonymous ownership or hidden profile listings.
- Only necessary first-party recommendation signals may be stored. Retention and user controls require approval before signal collection is enabled.
- No hashtags, fabricated trends or fake engagement.

## 6. Moderation, reporting and abuse prevention

- Reporting is available only to verified participants. Reports are private and do not automatically remove content based on volume.
- Prohibited content includes spam/scams, coordinated flooding, credible threats, doxxing, sustained targeted harassment, exploitation/CSAM and serious illegal or dangerous content.
- Ordinary disagreement, profanity, satire and unpopular opinions are not removed solely for offensiveness.
- Moderators require separately provisioned roles. Every private-authorship lookup and moderation action is authorized and audited.
- Moderation supports content restrictions, account restrictions, review status, reasons and append-only action history.
- Duplicate-content controls, rate limits and abuse scoring supplement verification; email/phone confirmation does not prove unique personhood.
- Final policy text, appeals, evidence retention and legal escalation procedures must be approved before launch.

## 7. Privacy and data handling

- Public APIs use explicit allowlisted DTOs and never return private owner IDs, contact information, verification metadata, security flags, reports or moderator data.
- Anonymous ownership must not be inferable from joins, counts, errors, timing, media paths, caches, analytics or recommendation signals.
- Public profiles show username, chosen avatar and only the activity permitted by the user's profile-history setting.
- Publicly attributed posts remain attributed and searchable even when profile history is hidden.
- Data minimization, retention, account deletion and recovery must be documented before production.

## 8. Non-goals

No follower system, direct messages, notifications, hashtags, real-name requirement, prestige verification badge, payments or AI moderation are included unless separately approved.

## 9. Proposed implementation defaults requiring approval

The following are recommended defaults, not silently approved product rules:

1. **Username syntax:** 3–24 grapheme clusters; letters, numbers and underscore; Unicode NFKC normalization plus case-folded uniqueness; reserved-name list; previous names not immediately reusable. Approve exact syntax, reassignment delay and rename-history visibility.
2. **Authentication and recovery:** launch with Supabase email magic-link/OTP and phone OTP; recovery requires control of a verified contact. Approve enabled methods, mobile OTP budget, contact-change rules and inactive-signup cleanup.
3. **Post minimum:** require at least one non-whitespace grapheme or one valid attachment. Attachment-only posts require useful alt text. Approve minimum text and alt-text policy.
4. **Media allowlist:** JPEG, PNG, WebP and GIF; reject SVG and ambiguous/polyglot files; re-encode static images and strip metadata. Approve exact MIME list, GIF processing and animation controls.
5. **Comments:** no editing after publication; owners may delete; a deleted root with live replies becomes a neutral tombstone. Approve this policy and retention duration.
6. **Votes:** allow switching and removal before the post becomes ineligible. Approve final vote-change/removal behavior.
7. **Reactions:** use a controlled lookup rather than a database enum until the final taxonomy and eligible formats are approved. Proposed initial behavior is reactions on Regular and Confession posts, poll votes on the three poll formats.
8. **Comment identity:** comments are pseudonymous only in the initial release; anonymous comments are deferred. Public comment history follows a separate profile-visibility setting. Approve both decisions.
9. **Recommendation signals:** proposed 90-day rolling retention with opt-out and deletion on account deletion unless security retention applies. Approve retention, controls and ranking weights.
10. **Moderation evidence:** proposed restricted retention of 180 days after resolution, extendable only for documented legal/safety reasons. Approve periods, appeals and legal requirements.
11. **Account deletion:** immediately disable participation and public profile; remove or anonymize attributed content according to an approved user choice while retaining only justified security/moderation records. Approve exact behavior.
12. **Navigation and Explore:** final destinations remain a design/product approval item and do not affect the core post schema.

## 10. Change control and implementation gate

Unresolved approval items are not permission to invent behavior. No schema freeze, SQL migration or backend implementation may begin until the ERD, lifecycle/retention rules, RLS matrix, storage design, endpoint contracts and remaining product decisions are reviewed and explicitly approved.
