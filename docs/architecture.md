# ComfartZone — Backend Architecture Design

**Status:** Complete pre-migration design for review. It translates `docs/product-spec.md` into a PostgreSQL/Supabase architecture. It is not authorization to create SQL, configure production resources or begin backend integration.

## 1. Platform and trust boundaries

- Frontend/server: Astro, strict TypeScript, React islands and Tailwind CSS v4.
- Backend: Supabase Auth, PostgreSQL, Row Level Security and private Supabase Storage.
- API: Astro server endpoints call narrowly scoped PostgreSQL RPCs. Public reads use explicit API views/functions, never broad base-table serialization.
- PostgreSQL schemas:
  - `api`: exposed safe views and RPCs only.
  - `app`: product records protected by RLS; not granted for direct client writes.
  - `private`: contacts, ownership, moderation, signals and operations; never exposed through PostgREST.
- The browser receives only the anon key. Service-role credentials remain server-only.
- Trusted identity, verification, role and timestamps come from Supabase Auth/database state, never request payloads.
- All times are UTC `timestamptz` using database time.

## 2. Required extensions and conventions

- `pgcrypto` for UUID generation and hashes.
- `pg_trgm` for reviewed username/post search indexes.
- PostgreSQL full-text search for post text and topics.
- Primary keys are UUIDs unless a compact `bigint` operational key is noted.
- Mutable records include `updated_at`; race-sensitive records include integer `version`.
- User text is stored as plain text and escaped at render time. HTML is never accepted.
- Exact Unicode grapheme validation occurs in a pinned server implementation. Database checks add conservative `char_length` and `octet_length` ceilings but do not pretend to count grapheme clusters exactly.

## 3. Enum and catalog definitions

### PostgreSQL enums

| Enum | Values |
|---|---|
| `account_state` | `active`, `restricted`, `deletion_pending`, `deleted` |
| `deletion_mode` | `delete_contributions`, `preserve_anonymously` |
| `post_format` | `regular`, `confession`, `petty_court`, `am_i_weird`, `hot_take` |
| `identity_mode` | `attributed`, `anonymous` |
| `post_state` | `active`, `locked`, `archived`, `expired_archived`, `deletion_pending`, `deleted`, `moderation_removed` |
| `expiry_action` | `archive_private`, `delete_permanently` |
| `media_status` | `staged`, `validated`, `attached`, `quarantined`, `deletion_pending`, `deleted` |
| `comment_state` | `active`, `tombstone`, `deletion_pending`, `deleted`, `moderation_removed` |
| `reaction_kind` | `funny`, `love`, `annoying`, `same`, `ouch`, `wild` |
| `vote_choice` | `guilty`, `not_guilty`, `me_too`, `just_you`, `agree`, `disagree` |
| `report_target` | `post`, `comment` |
| `report_state` | `open`, `triaged`, `resolved_actioned`, `resolved_dismissed`, `appealed`, `closed` |
| `moderation_action_kind` | `lock`, `unlock`, `remove`, `restore`, `restrict_account`, `unrestrict_account`, `dismiss_report`, `record_authorship_access`, `apply_hold`, `release_hold` |
| `appeal_state` | `submitted`, `under_review`, `upheld`, `overturned`, `rejected` |
| `job_kind` | `expire_post`, `delete_post`, `delete_media`, `delete_account`, `purge_signals`, `purge_evidence`, `purge_staging` |
| `job_state` | `pending`, `running`, `succeeded`, `retryable`, `failed`, `cancelled` |
| `signal_kind` | `impression`, `open`, `comment`, `reaction`, `vote`, `share` |

Report reasons are a private catalog table rather than an enum because the final policy catalog is unresolved. Avatar and topic values are catalogs so they can be retired without migrations.

### Fixed interaction compatibility

Database RPCs enforce this matrix; clients cannot supply arbitrary values. Invariant constraint triggers also reject incompatible rows if a privileged internal path bypasses an RPC.

| Format | Reactions | Votes |
|---|---|---|
| `regular` | `funny`, `love`, `annoying` | none |
| `confession` | `same`, `ouch`, `wild` | none |
| `petty_court` | none | `guilty`, `not_guilty` |
| `am_i_weird` | none | `me_too`, `just_you` |
| `hot_take` | none | `agree`, `disagree` |

## 4. Entity and relationship design

### 4.1 Accounts and profiles

#### `private.accounts`

| Column | Type / constraint |
|---|---|
| `user_id` | `uuid` PK, FK `auth.users(id)` `ON DELETE RESTRICT` |
| `state` | `account_state` not null default `active` |
| `verified_email` | `boolean` not null, synchronized from trusted auth state |
| `verified_phone` | `boolean` not null, synchronized from trusted auth state |
| `last_username_change_at` | `timestamptz` not null |
| `personalization_opt_out` | `boolean` not null default false |
| `restricted_until` | nullable `timestamptz` |
| `restriction_reason_code` | nullable `text` |
| `deletion_mode` | nullable `deletion_mode` |
| `deletion_requested_at`, `deletion_execute_at`, `deleted_at` | nullable `timestamptz` |
| `created_at`, `updated_at` | `timestamptz` not null |

Participation requires `state = active`, no active restriction and `verified_email OR verified_phone`. Auth contact values remain only in Supabase Auth, not duplicated here.

Indexes: `(state)`, `(deletion_execute_at) WHERE state='deletion_pending'`, `(restricted_until) WHERE restricted_until IS NOT NULL`.

#### `app.avatar_catalog`

`avatar_id uuid PK`, stable `key text UNIQUE`, accessible asset reference, alt label, `is_active boolean`, display order and timestamps. Clients may select only active entries; retired avatars remain renderable.

#### `app.public_profiles`

| Column | Type / constraint |
|---|---|
| `profile_id` | `uuid` PK default `gen_random_uuid()` |
| `user_id` | `uuid UNIQUE` FK `private.accounts` through trusted creation only |
| `username` | `text` not null |
| `normalized_username` | `text` not null UNIQUE |
| `avatar_id` | nullable FK `app.avatar_catalog` |
| `show_post_history` | `boolean` not null default true |
| `show_comment_history` | `boolean` not null default true |
| `is_discoverable` | `boolean` not null default true |
| `created_at`, `updated_at` | timestamps |

Checks: username 3–24 grapheme clusters in server code; database `char_length(username) BETWEEN 3 AND 96`, `octet_length(username) <= 384`; normalized value must equal the trusted normalization result supplied by the RPC. No direct update grants.

Indexes: unique B-tree on `normalized_username`; trigram index on normalized username restricted to discoverable profiles; `(user_id)` unique.

#### `private.username_history`

`history_id bigint PK`, `user_id`, prior and new display/normalized username, `changed_at`, `reserved_until nullable`, and change source. Unique partial reservation on normalized names is implemented through a separate claim table.

#### `private.username_claims`

`normalized_username text PK`, current `user_id nullable`, `claimed_at`, `released_at nullable`, `reserved_until nullable`. A transactional claim function locks the candidate row. A released name cannot be reassigned before `reserved_until`; the exact interval is the remaining product decision.

### 4.2 Topics

#### `app.topics`

`topic_id uuid PK`, unique stable `slug`, unique display `label`, optional description, `is_active`, sort order and timestamps. Posts may reference zero or one topic. Retiring a topic prevents new selection but does not invalidate old posts.

Indexes: unique `slug`, `(is_active, sort_order)`.

### 4.3 Posts and ownership

#### `app.posts`

| Column | Type / constraint |
|---|---|
| `post_id` | `uuid` PK |
| `format` | `post_format` not null default `regular` |
| `body` | `text` not null default empty string |
| `topic_id` | nullable FK `app.topics` `ON DELETE RESTRICT` |
| `identity_mode` | `identity_mode` not null |
| `public_author_profile_id` | nullable FK `app.public_profiles` `ON DELETE SET NULL` |
| `state` | `post_state` not null default `active` |
| `is_account_deleted_author` | `boolean` not null default false |
| `created_at` | `timestamptz` not null immutable |
| `expires_at` | nullable `timestamptz` |
| `expiry_action` | nullable `expiry_action` |
| `locked_at`, `archived_at`, `deleted_at`, `moderated_at` | nullable timestamps |
| `version` | integer not null default 1 |
| `search_document` | maintained `tsvector` containing eligible post text/topic only |

Constraints:

- conservative `char_length(body) <= 1024` and `octet_length(body) <= 4096`; exact 256 graphemes in RPC;
- `identity_mode='attributed'` requires `public_author_profile_id`, except preserved account-deletion records explicitly converted to anonymous;
- `identity_mode='anonymous'` requires `public_author_profile_id IS NULL`;
- `expires_at` and `expiry_action` are both null or both non-null; `expires_at = created_at + interval '24 hours'` for expiring posts;
- state/timestamp consistency checks;
- body may be empty only when one attached valid media row and approved alt text exist, enforced transactionally;
- immutable content columns are not update-granted and an invariant trigger rejects changes outside trusted lifecycle RPCs.

Indexes:

- public Latest: `(created_at DESC, post_id DESC) WHERE state IN ('active','locked')`;
- expiry worker: `(expires_at, post_id) WHERE expires_at IS NOT NULL AND state IN ('active','locked')`;
- topic feed: `(topic_id, created_at DESC, post_id DESC)` partial on public states;
- format feed: `(format, created_at DESC, post_id DESC)` partial on public states;
- public author history: `(public_author_profile_id, created_at DESC, post_id DESC)` partial on public states;
- GIN on `search_document` partial on public states.

All public reads additionally require `expires_at IS NULL OR expires_at > statement_timestamp()`; worker completion is never the visibility boundary.

#### `private.post_owners`

`post_id uuid PK FK app.posts ON DELETE CASCADE`, `owner_user_id uuid FK private.accounts ON DELETE RESTRICT`, `created_at`. Index `(owner_user_id, created_at DESC, post_id DESC)`. This table is never joined into public views.

#### `private.post_quota_events`

`event_id bigint PK`, unique `post_id`, `owner_user_id`, immutable `created_at`. Index `(owner_user_id, created_at DESC)`. Rows survive content deletion until outside operational retention so deletion never refunds quota.

### 4.4 Media

#### `private.media_assets`

| Column | Type / constraint |
|---|---|
| `media_id` | `uuid` PK |
| `owner_user_id` | FK private account |
| `post_id` | nullable UNIQUE FK post `ON DELETE SET NULL` |
| `status` | `media_status` not null |
| `bucket` | fixed private bucket identifier |
| `object_key`, `processed_key` | opaque random text, globally unique |
| `declared_mime`, `detected_mime` | text |
| `byte_size` | bigint check `1..2097152` |
| `width`, `height`, `frame_count`, `duration_ms` | validated nonnegative integers |
| `sha256` | bytea not null |
| `alt_text` | nullable text with conservative ceiling |
| `validated_at`, `attached_at`, `expires_at`, `deleted_at` | timestamps |
| `created_at`, `updated_at` | timestamps |

Allowed detected MIME values are `image/jpeg`, `image/png`, `image/webp`, `image/gif`. One media per post is guaranteed by unique `post_id`. Staged objects expire quickly; exact staging TTL is operational configuration. Hash indexes support duplicate/abuse review without making hashes public.

Storage has no public bucket. Media is delivered through an eligibility-checking server endpoint with opaque identifiers and `Cache-Control: private, no-store` for revocable content. Object paths and metadata contain no user/profile/post identifiers. Original and processed objects are deleted together unless an evidence hold applies.

### 4.5 Comments and ownership

#### `app.comments`

`comment_id uuid PK`, `post_id FK app.posts ON DELETE CASCADE`, nullable `parent_comment_id FK app.comments ON DELETE RESTRICT`, `public_author_profile_id FK app.public_profiles ON DELETE SET NULL`, `body text`, `state comment_state`, `is_account_deleted_author boolean`, immutable `created_at`, lifecycle timestamps and `version`.

Constraints and transaction rules:

- 1–256 grapheme clusters in RPC; conservative database byte/code-point ceiling;
- parent, when present, is an active root on the same post;
- no reply to a reply;
- an invariant constraint trigger independently enforces same-post parentage and maximum depth;
- author profile is required while the account exists; retained account-deletion comments use `Deleted user` presentation;
- body immutable; a tombstone contains no original body;
- create only when the parent post is public, unexpired and unlocked.

Indexes: `(post_id, created_at, comment_id)` for threads; `(parent_comment_id, created_at, comment_id)`; `(public_author_profile_id, created_at DESC)` partial on active comments.

#### `private.comment_owners`

`comment_id uuid PK`, `owner_user_id`, `created_at`; private index `(owner_user_id, created_at DESC)`.

Deletion RPC locks the root and checks live children. It writes a neutral tombstone when children remain; otherwise transitions to deletion and schedules cleanup.

### 4.6 Reactions, votes and aggregates

#### `private.post_reactions`

`post_id`, `user_id`, `reaction reaction_kind`, `created_at`, `updated_at`; PK `(post_id, user_id)`. The RPC locks the post and existing selection, validates format compatibility, then inserts, replaces or removes. No reaction row may exist for a poll format.

#### `private.post_votes`

`post_id`, `user_id`, `choice vote_choice`, timestamps; PK `(post_id, user_id)`. The RPC enforces the fixed format/choice matrix. No vote row may exist for Regular or Confession.

#### Aggregates

`api.post_interaction_totals` exposes grouped counts by allowed choice plus total participants, never user IDs. It may initially be a security-barrier view over indexed tables. If performance requires counters, a transactionally maintained aggregate table may replace it only with reconciliation jobs and tests; client-supplied counters are never accepted.

### 4.7 Reports, moderation, evidence and appeals

#### `private.report_reason_catalog`

Stable `reason_code text PK`, label, target compatibility, active flag and sort order. Values await policy approval.

#### `private.reports`

`report_id uuid PK`, `reporter_user_id`, `target_type`, exactly one of `post_id`/`comment_id`, `reason_code`, optional detail with length limit, `state`, timestamps and `assigned_moderator_user_id nullable`.

Constraints: target XOR check; one open report per reporter/target/reason; target must exist at submission. Indexes on `(state, created_at)`, target columns, reporter/rate-limit queries and assignee.

#### `private.moderator_roles`

`user_id`, `role_key` (`reviewer` or `admin`), `granted_by`, `granted_at`, nullable `revoked_at`; active unique membership. Roles are provisioned only by an out-of-band admin process, never self-service claims.

#### `private.moderation_cases`

`case_id uuid PK`, optional target post/comment/account, status, severity, assigned moderator, opened/resolved timestamps, `evidence_delete_at`, nullable legal-hold metadata. A target may have multiple historical cases but at most one active case per target/category where required.

#### `private.moderation_actions`

Append-only `action_id bigint PK`, `case_id`, moderator, `moderation_action_kind`, reason code, limited notes, before/after state JSON containing no auth contacts, and `created_at`. No application update/delete grants.

#### `private.moderation_evidence`

`evidence_id uuid PK`, case, evidence type, encrypted/restricted reference or content hash, captured timestamp, `delete_at`, legal-hold flag and timestamps. Default deletion is 180 days after case resolution.

#### `private.appeals`

`appeal_id uuid PK`, case, appellant user, statement with size limit, `appeal_state`, reviewer, submitted/resolved timestamps and resolution reason. Eligibility and timing await policy approval; no migration should freeze those values prematurely.

Every private-authorship lookup writes a `record_authorship_access` audit action with moderator, target, case/reason and timestamp.

### 4.8 Recommendation signals and preferences

#### `private.recommendation_signals`

`signal_id bigint PK`, nullable `user_id`, session-scoped pseudonymous identifier for guests only if privacy-approved, `post_id`, `signal_kind`, occurred timestamp, minimal context such as feed surface and position. No IP address, auth contact, anonymous ownership or post-owner identifier is stored. Partition by month or maintain an indexed `occurred_at`; delete after 90 days.

Signal writes are disabled for opted-out authenticated users. Opt-out/account deletion schedules immediate user-signal purge. Security/rate-limit records are separate and are not used for personalization.

#### `private.feed_preferences`

Optional derived per-user topic/format scores, versioned calculation timestamp and expiry. These are rebuildable, private, deleted on opt-out/account deletion and never exposed directly.

For You scoring is transparent configuration combining eligibility, freshness decay, topic/format affinity, quality, author/topic diversity and exploration. Report count and outrage are not positive signals. Latest remains independent.

### 4.9 Idempotency, outbox and rate limiting

#### `private.idempotency_keys`

`user_id`, `operation text`, `key uuid`, request hash, response code/safe response JSON, state, `created_at`, `expires_at`; PK `(user_id, operation, key)`. Same hash returns the stored result; a different hash returns `IDEMPOTENCY_CONFLICT`. Create-post keys remain at least as long as the posting quota window.

#### `private.outbox_jobs`

`job_id bigint PK`, `job_kind`, deduplication key, target UUID, payload JSON, target version, `run_after`, state, attempts, last safe error, locked timestamp/worker and timestamps. Unique active deduplication key prevents duplicate effects. Workers use `FOR UPDATE SKIP LOCKED`, exponential retry and target-version checks.

#### Rate limiting

Durable shared rate limiting is required for multi-instance deployment. Product limits live in database transactions where correctness matters; burst controls may use a shared edge/Redis service. Network identifiers must be one-way keyed hashes with short retention and privacy review. Rate-limit responses include stable codes and retry times without revealing account existence.

## 5. Public and private projections

### Public API projections

- `api.public_profiles`: profile ID, username, avatar presentation only for active/discoverable profiles.
- `api.public_posts`: eligible post fields, safe author presentation, topic, format, lifecycle indicators and aggregate counts. Anonymous rows contain no profile key.
- `api.public_comments`: eligible comments with safe attributed or `Deleted user` presentation.
- `api.public_topics`: active topic metadata.
- feed/search functions return the same DTO shape rather than raw tables.

Public views are security-barrier views with explicit columns and reviewed invoker/definer behavior; no `SELECT *` projections are permitted.

### Owner projections

Authenticated owner functions return owned attributed/anonymous posts, private archives, pending expiry action, media state and deletion status. They may include post IDs but never moderator notes or unrelated private data.

### Moderator projections

Separate audited RPCs expose only case-relevant reports, targets, evidence and authorship. Moderator data is never included in ordinary API views.

A public DTO must never contain auth UUIDs, ownership-row existence, contacts, verification flags, username history, reports, restrictions, signals, private storage keys or moderator metadata.

## 6. Authentication and account lifecycle

1. Supabase Auth verifies email magic-link/OTP or phone OTP.
2. `activate_profile` rechecks trusted verification, normalizes and atomically claims the username, creates private account/public profile/history and selects an active avatar.
3. Every mutation rechecks account state, restriction and current trusted verification.
4. `change_username` locks account and claim rows, checks the rolling 30-day cooldown, reserves the prior claim and commits profile/history atomically.
5. Sensitive contact changes and account deletion require a recent authenticated session and verified-contact confirmation.
6. `request_account_deletion` sets `deletion_pending`, revokes sessions, removes profile discovery and schedules execution after the unresolved recovery window.
7. `cancel_account_deletion` is allowed only inside that window after re-verification.
8. `execute_account_deletion` applies the chosen contribution mode, purges signals/private data, respects evidence holds and finally removes or irreversibly de-identifies the auth account.

## 7. Transactional RPC contracts

All mutation RPCs are `SECURITY DEFINER`, have fixed `search_path`, derive `auth.uid()`, validate verification/account state, use explicit grants and return safe DTOs/errors.

| RPC | Core contract |
|---|---|
| `activate_profile(username, avatar_id)` | Verify auth contact; normalize/claim username; create account/profile/history atomically |
| `change_username(username, expected_version)` | Lock account/claims; enforce 30 days and reservation; update history/profile |
| `update_profile_settings(...)` | Owner-only avatar/history/opt-out changes; no username bypass |
| `create_media_upload(mime, bytes, alt_text, idempotency_key)` | Create short-lived private staged authorization after eligibility/rate checks |
| `confirm_media_upload(media_id)` | Verify object bytes/type/decoding/metadata processing; mark validated or quarantine |
| `create_post(request, idempotency_key)` | Lock account quota, validate content/media/topic/format/expiry, create ownership/quota/outbox atomically |
| `set_expiry_action(post_id, action, expected_version)` | Owner-only, before expiry; lock/version post |
| `archive_post(post_id, expected_version)` | Owner-only immediate public ineligibility; preserve private record |
| `delete_post(post_id, expected_version)` | Owner/moderator path; immediate ineligibility and idempotent cleanup job |
| `create_comment(post_id, parent_id, body, idempotency_key)` | Validate post eligibility, depth, graphemes and rate limits; create ownership atomically |
| `delete_comment(comment_id, expected_version)` | Owner/moderator; tombstone root if live replies remain, otherwise cleanup |
| `set_reaction(post_id, reaction_or_null)` | Eligible Regular/Confession only; upsert/change/remove one active selection |
| `set_vote(post_id, choice_or_null)` | Eligible poll format only; upsert/change/remove one active vote |
| `submit_report(target, reason, detail, idempotency_key)` | Verified reporter; validate target/reason/duplicate/rate limit; private result |
| `request_account_deletion(mode)` | Re-authenticated owner; disable participation/discovery and schedule execution |
| `cancel_account_deletion()` | Re-verified owner within recovery window |
| moderator RPCs | Role/case/reason required; lock target, apply action and append audit atomically |

### Atomic posting quota

`create_post` takes a transaction-scoped advisory lock keyed by `auth.uid()` or locks a per-account quota row. It counts `private.post_quota_events` in `(database_now() - 24 hours, database_now()]`. At three, it returns `POST_QUOTA_EXCEEDED` plus the earliest retry timestamp. Otherwise it validates and inserts the post, owner, optional media association, quota event, expiry job and idempotency result in one transaction. Failed transactions consume no slot; committed posts always consume it.

### Concurrency rules

- Username claims: lock candidate/current claim rows in deterministic normalized-name order.
- Post state changes/expiry: lock post row and compare `version`; stale operations return `VERSION_CONFLICT`.
- Reaction/vote: PK `(post_id,user_id)` plus post lock/eligibility check.
- Comment deletion/reply creation: lock parent and post to avoid reply/tombstone races.
- Account deletion: lock account; workers verify deletion mode, state and target version.
- Outbox jobs are idempotent and never change a target whose version/state no longer matches.

## 8. Server endpoint contracts

Endpoints validate HTTP shape/size, session and CSRF/origin policy, then call the RPC/read function. They never implement weaker parallel authorization.

### Public reads

- `GET /api/feed?mode=for-you|latest&format=&topic=&cursor=`
- `GET /api/posts/:id`
- `GET /api/posts/:id/comments?cursor=`
- `GET /api/search?q=&type=posts|profiles|topics&cursor=`
- `GET /api/profiles/:profileId/posts?cursor=` and `/comments`
- `GET /api/topics`
- `GET /api/media/:mediaId` performs current eligibility check before streaming
- canonical post pages provide share metadata only for eligible posts

Use opaque keyset cursors, reviewed maximum page sizes and uniform not-found responses where privacy requires.

### Authenticated account/content endpoints

- profile activation/settings/username routes;
- media stage/confirm routes;
- post create/archive/delete/expiry-action routes;
- comment/reply create/delete routes;
- reaction/vote set-or-remove routes;
- report submission;
- private `GET /api/me/activity` and account deletion request/cancel.

Mutation requests carry `Idempotency-Key` where duplication is harmful and `If-Match`/version where races matter.

### Moderator endpoints

Protected queue, case detail, assignment, authorship-access, action, evidence and appeal-review routes call moderator-only RPCs and always append audit events.

## 9. RLS and grants matrix

Base policy is default deny. The client roles receive `USAGE` on `api` and `EXECUTE/SELECT` only on named safe functions/views. They receive no mutation grants on `app` or any access to `private`.

| Resource/action | Guest | Auth unverified | Verified user | Owner | Moderator |
|---|---:|---:|---:|---:|---:|
| Eligible public profiles/posts/comments/topics | Read | Read | Read | Read | Read |
| Public feeds/search/aggregates/media | Read | Read | Read | Read | Read |
| Activate profile | No | RPC after trusted verification | N/A | N/A | No |
| Post/comment/react/vote/upload/report | No | No | RPC | RPC | RPC only when acting as user; moderation separate |
| Own private activity/archive/settings | No | No | Own only | Own only | No ordinary access |
| Archive/delete own content | No | No | Own RPC | Own RPC | Moderation RPC with case/reason |
| Ownership mappings | No | No | No direct access | Safe owner RPC only | Audited case-bound RPC |
| Reports/evidence/signals/username history | No | No | Own limited report status/settings only | Own limited data | Case/role-limited audited access |
| Moderator roles/actions | No | No | No | No | Role-specific; actions append-only |
| Direct base-table writes | No | No | No | No | No; use RPCs |

RLS on `app` still protects accidental direct exposure: public rows require centralized eligibility; profile history requires visibility; owner policies derive `auth.uid()` through private ownership helper functions that reveal no rows. `private` is excluded from exposed schemas and revoked from `anon`/`authenticated` entirely.

## 10. Media security and cleanup

- Private staging and processed storage prefixes; no public bucket.
- Short-lived upload authorization is bound to owner, media ID, size/type expectation and expiry.
- Server-side inspection trusts bytes, not extension/MIME. Static images are decoded/re-encoded; GIFs are decoded, bounded and metadata-stripped.
- Only `validated` media owned by the caller can be attached, once, in the same post transaction.
- Delivery checks post eligibility on each request and prevents enumeration; no long-lived public URL.
- Staging purge, post deletion and account deletion use outbox jobs. Cleanup deletes all derivatives, verifies absence and marks the database row deleted.
- Evidence holds copy or reference only the minimum necessary artifact in restricted storage; ordinary media access remains revoked.

## 11. Expiry, archive and deletion lifecycle

- Public eligibility is a database predicate, not a worker result.
- Expiring posts are invisible at `expires_at <= statement_timestamp()`.
- Expiry workers lock the post and apply the current action/version:
  - `archive_private` -> `expired_archived`, retain owner-readable content/media privately;
  - `delete_permanently` -> `deletion_pending`, enqueue child/media cleanup.
- Author archive sets `archived` synchronously and remains privately readable.
- Permanent deletion synchronously removes eligibility, then deletes/tombstones children as policy requires, removes selections/signals and storage objects.
- Account deletion executes the selected mode from product spec section 8 and removes ownership after the recovery/hold period.
- Legal/safety holds prevent physical evidence deletion, never restore public visibility.

## 12. Search and personalized feeds

- `api.latest_feed` uses `(created_at DESC, post_id DESC)` keyset ordering.
- For You first applies the exact public-eligibility predicate, then a configurable score. Candidate generation uses recent eligible posts and optional topic/format affinities. Re-ranking enforces author/topic diversity and exploration.
- Anonymous posts can be ranked by post-level signals but recommendation storage never includes or exposes owner identity.
- Search parses bounded queries, uses FTS for posts/topics and trigram/prefix matching for public usernames. Results use stable rank/time/ID cursors.
- Hidden profile history affects profile-listing functions only. It does not suppress attributed posts from post search.
- Opted-out users and guests use cold-start ranking and do not receive persistent personalized profiles.
- Signals expire at 90 days and are purged on opt-out/account deletion.

## 13. Errors, logging and observability

Stable error codes include `AUTH_REQUIRED`, `VERIFICATION_REQUIRED`, `ACCOUNT_RESTRICTED`, `POST_QUOTA_EXCEEDED`, `RATE_LIMITED`, `INVALID_GRAPHEME_LENGTH`, `INVALID_FORMAT_INTERACTION`, `CONTENT_INELIGIBLE`, `VERSION_CONFLICT`, `IDEMPOTENCY_CONFLICT`, `MEDIA_INVALID` and `NOT_FOUND`.

Logs exclude tokens, contacts, post ownership, report details, unnecessary post bodies and raw network identifiers. Operational metrics use aggregate counts. Sensitive moderator reads/actions and ownership access are append-only audited. Monitoring covers RPC failures, quota conflicts, expiry lag, stuck jobs, storage orphans, moderation queue age, signal purge and backup/restore health.

## 14. Retention matrix

| Data | Retention/action |
|---|---|
| Public/archived content | Until owner action, expiry action, moderation or account deletion |
| Deleted post/comment/media | Immediate ineligibility; physical cleanup by retryable job |
| Post quota events | At least beyond rolling 24h window; operational purge afterward |
| Idempotency records | Operation-specific; create-post at least 24h |
| Recommendation signals/preferences | Maximum 90 days; immediate purge on opt-out/deletion |
| Staged uploads | Short operational TTL, then purge |
| Username history | Private account lifetime plus deletion processing/approved holds |
| Reports, cases and evidence | 180 days after resolution unless documented legal/safety hold |
| Moderation audit actions | Append-only for the approved compliance period; exact long-term audit period requires legal review |
| Rate-limit/security records | Minimum practical period defined in privacy review |

## 15. Remaining blockers and readiness

The entity model, privacy boundaries, interaction matrix, transactional workflows, endpoint surface and RLS strategy are ready for formal review. SQL migration design remains blocked by:

1. Exact previous-username reservation period.
2. Account-deletion recovery window.
3. Final report-reason catalog, appeal eligibility/window and legal escalation procedure.
4. Final GIF dimension/frame/duration and reduced-motion limits.
5. Legal approval of long-term moderation-audit and security-log retention.

Final navigation/Explore destinations do not block the core schema. Before migration, reviewers must approve this design, a generated ERD, exact SQL constraints/indexes, query plans for feed/search, the threat model and the completed test matrix. No migration may be created or applied from this document alone.