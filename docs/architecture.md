# ComfartZone — Architecture Blueprint (Pre-implementation)

**Status:** Consolidated design draft. No schema or migration is approved. This document translates `docs/product-spec.md` into technical boundaries; approval items remain blockers where noted.

## 1. Stack and trust boundaries

- Frontend: Astro, strict TypeScript, React islands and Tailwind CSS v4.
- Planned backend: Supabase Auth, PostgreSQL, Row Level Security, Supabase Storage, Astro server endpoints and narrowly scoped transactional PostgreSQL functions.
- Expose a dedicated API schema or explicit server DTOs. Internal account, ownership, moderation and operational records must not be directly exposed through PostgREST.
- Use one authoritative write path per operation. Prefer server-mediated writes; database constraints and RLS remain independent defenses.
- Never ship service-role credentials or trust client-supplied user IDs, verification flags, roles, ownership, timestamps, counters or visibility states.

## 2. Logical domains and invariants

| Domain | Candidate records | Required invariants |
|---|---|---|
| Accounts | auth identities, private accounts, public profiles, username history, avatar catalog | verified contact for writes; normalized unique username; rolling 30-day rename cooldown |
| Posts | post content, format, optional single topic, visibility/lifecycle, anonymous presentation, private ownership | five formats; 256 graphemes; immutable creation; no post edits; no anonymous owner leak |
| Media | staged upload, one published attachment, cleanup/outbox | one image/GIF; <=2 MB; validated bytes/type; metadata stripped; no orphan public object |
| Discussion | comments, replies, private ownership | 256 graphemes; text only; parent belongs to same post; depth <=1 |
| Interactions | reaction selections, poll votes, safe aggregates | one active reaction/vote per user/post; valid format-specific choice; transactional replacement |
| Safety | reports, moderation cases/actions, account/content restrictions, audit trail | default-private; role-enforced access; no takedown by report count alone |
| Discovery | topics, search documents, feed impressions/signals/preferences | eligibility before ranking; minimized retention; no anonymous linkage |
| Operations | posting quota ledger, idempotency records, expiry/cleanup outbox, rate limits | atomic rolling quota; deterministic retries; idempotent workers |

Final table names and columns belong in the reviewed ERD, not this blueprint.

## 3. Identity, verification and profile boundaries

- Supabase Auth is the identity provider. A request may participate only when its session is valid and at least one linked email or phone is server-confirmed.
- Verification eligibility is derived from trusted auth state on every mutation. Revoked/expired sessions or removed confirmation immediately block writes.
- Username/avatar selection may occur during signup, but profile activation and participation occur only after verification and a transactionally successful username claim.
- Normalize usernames before uniqueness checks. Serialize claims and renames; store the last successful rename timestamp and append username history.
- Separate:
  1. private auth/account/contact data;
  2. public profile projection;
  3. private post/comment ownership mappings;
  4. public content projections.
- Public pseudonymous content references a safe public profile identifier. Anonymous public projections contain no profile or owner key. Private ownership remains available only to the owner and audited moderators.
- Hiding profile history affects profile-listing queries only. It does not alter attributed feed/search results.
- Moderator author-unmasking requires a specific privilege, reason and append-only audit event.

## 4. Content and validation boundaries

- Formats: regular, confession, petty_court, am_i_weird and hot_take. Topic cardinality is zero or one.
- Validate 256 grapheme clusters in shared application/server code using a pinned Unicode-capable segmentation implementation. Database checks provide a conservative byte/code-point ceiling but are not the sole grapheme validator.
- Trim outer whitespace and reject content that fails the approved minimum rule. Render text escaped; never store or render user HTML.
- Posts are immutable after publication except lifecycle controls such as archive/delete and pending expiry action.
- Comments/replies are text only and enforce one-level depth at a trusted transactional boundary. A parent must be a root comment on the same post.
- Poll choices are validated against post format inside the vote transaction. Reaction eligibility and taxonomy come from approved configuration/lookup records.

## 5. Media lifecycle

1. A verified user requests a short-lived staged-upload authorization.
2. Storage uses opaque random object keys with no user, username or post identity.
3. The server verifies byte size, actual MIME/content, dimensions/decodability and malware/abuse checks; strips metadata and applies approved image/GIF processing.
4. Create-post atomically associates at most one validated staged object. A failed post does not publish an object.
5. Abandoned staging objects expire through an idempotent cleanup job.
6. Public delivery must support immediate eligibility revocation for archive, expiry, deletion and moderation. Cache TTL and signed/public URL strategy must be approved before implementation.
7. Deletion/retention jobs remove derivatives and originals unless a specifically approved moderation/legal hold applies.

## 6. Transactional write workflows

### Signup/profile activation

Verify email or phone, normalize and claim username, select avatar, activate public profile and record initial username history in one trusted workflow. Collisions return a safe retry error without leaking private account data.

### Create post

- Require authenticated verified identity and idempotency key.
- Validate graphemes, format, optional topic, identity mode, optional media and optional expiry action.
- Serialize quota checks per account using a row lock or transaction-scoped advisory lock.
- Count authoritative creation timestamps in `(now() - 24 hours, now()]`; immutable quota history survives archive/deletion.
- Insert post, private ownership, optional public attribution, media association, expiry/outbox and quota event atomically.
- An idempotency-key replay returns the original safe result and cannot consume an additional quota slot.

### Comments/replies

Require verified identity; validate active/unlocked post eligibility, grapheme length, parent/post/depth and rate limit in one transaction. Reject media.

### Reactions/votes

Use unique keys on user+post and transactional upsert/removal. Lock or otherwise serialize the active selection, validate eligibility and return authoritative aggregates. Never accept client-supplied counters.

### Archive/delete/expiry

- Author or authorized moderator only.
- Update eligibility synchronously before asynchronous cleanup.
- Expiry reads always require `expires_at > database_now()`; jobs are not the visibility boundary.
- Lock the post when changing a pending expiry action or applying expiry so worker/action races have one outcome.
- Outbox jobs are idempotent, retryable and state/version aware; no stale job may resurrect or apply an obsolete action.
- Child comments/interactions/media inherit post visibility. Permanent cleanup follows the approved retention matrix.

### Reports/moderation

Verified reporters submit against an existing eligible target with separate rate and duplicate controls. Reports and reporter identities are private. Moderator decisions require role checks, reasons and append-only audit records. Report volume alone never changes public visibility.

## 7. Lifecycle and status model

Model lifecycle explicitly rather than inferring it from nullable timestamps. The reviewed ERD should distinguish at least:

- active/public;
- locked/public-readable;
- pending expiry;
- expired and privately archived;
- author archived;
- deleted/pending cleanup;
- moderation restricted/removed;
- legal or safety hold where approved.

Every public feed, search, profile, detail, comment, interaction and media query applies the same centralized eligibility rule. Cleanup state is not public visibility state.

## 8. RLS and grants baseline

- Default deny on every exposed table, view and function.
- Guests: read only explicitly eligible public DTOs and safe aggregates.
- Unverified authenticated users: same public reads; no participation writes.
- Verified users: narrowly scoped write functions plus own private account/activity reads.
- Owners: archive/delete their content and read retained private/anonymous content; cannot update published text or privileged fields.
- Other users: no private ownership, reports, signals or moderation data.
- Moderators: separately provisioned role checked on every request; minimum necessary private access; all sensitive reads/actions audited.
- Public DTOs omit auth UUIDs, contacts, private ownership, verification data, reports, restrictions, recommendation signals and moderation metadata.
- Harden every `SECURITY DEFINER` function with a fixed `search_path`, explicit grants, trusted auth-derived identity, validation and safe error mapping.
- Test both intended APIs and direct Supabase table/function calls.

## 9. Search and feed architecture

- Eligibility filtering precedes search and ranking.
- For You uses configurable transparent scoring with freshness decay, topic/format affinity, quality, diversity and exploration. Do not treat interaction volume as endorsement.
- Latest orders by authoritative `created_at DESC, id DESC` with opaque keyset cursors.
- Search indexes eligible post text, public usernames and topic labels. Anonymous posts contain no searchable author key; hidden profile history affects profile listings, not attributed post search.
- Impression/interaction signals are private, minimized and excluded from public DTOs. Do not collect them until retention, opt-out and deletion rules are approved.
- Stable cursor contracts, tie-breakers and maximum page sizes must be specified before endpoint implementation.

## 10. Rate limits, spam and idempotency

- Database transaction enforces the three-post rolling quota; durable shared rate limiting handles other endpoints.
- Define per-account and, where privacy-reviewed, network-level thresholds for signup/verification, upload, comments, votes/reactions, reports, search and username claims.
- Duplicate-content heuristics and abuse scores may restrict actions but require explainable statuses and moderator review paths.
- Idempotency records bind operation, account, normalized request hash and result; define TTL per operation. Reuse with a different request is rejected.
- Failed validation does not consume post quota. A committed post consumes quota even if later archived, deleted, expired or removed.

## 11. Errors, logging and operations

- Use structured, stable error codes without exposing existence of private records, ownership, verification internals or moderation state.
- Logs exclude tokens, contacts, private author mappings and unnecessary post bodies. Sensitive moderator access is auditable.
- Store UTC `timestamptz`; database time controls cooldowns, rolling quotas and expiry.
- Backups, restore drills, monitoring, storage cleanup, moderation escalation and privacy/legal retention are launch requirements.

## 12. Required reviewed artifacts before migration

1. Final ERD and data-classification catalog.
2. Complete constraints, foreign keys, deletion/retention matrix, indexes and expected query plans.
3. RLS/grants matrix for guest, unverified, verified, owner, other user and moderator.
4. Endpoint and transactional-function contracts, idempotency and structured errors.
5. Storage buckets, validation pipeline, cache/revocation and cleanup design.
6. Feed/search ranking, signal minimization, retention and opt-out design.
7. Threat model and adversarial test matrix.
8. Approved values for all items in product-spec section 9 that affect schema, privacy or lifecycle.

**Stop condition:** Do not generate or apply SQL migrations until these artifacts are reviewed and explicitly approved.
