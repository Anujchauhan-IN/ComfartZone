begin;

-- ComfartZone Phase 1A: structural schema only.
-- Supabase must expose only the api schema through PostgREST. The app and
-- private schemas are intentionally not client-facing.
-- Unresolved policy durations/catalog values are represented as nullable data
-- or unseeded catalogs; this migration does not invent them.

create schema if not exists extensions;
create schema if not exists app;
create schema if not exists private;
create schema if not exists api;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create type app.account_state as enum ('active', 'restricted', 'deletion_pending', 'deleted');
create type app.deletion_mode as enum ('delete_contributions', 'preserve_anonymously');
create type app.post_format as enum ('regular', 'confession', 'petty_court', 'am_i_weird', 'hot_take');
create type app.identity_mode as enum ('attributed', 'anonymous');
create type app.post_state as enum ('active', 'locked', 'archived', 'expired_archived', 'deletion_pending', 'deleted', 'moderation_removed');
create type app.expiry_action as enum ('archive_private', 'delete_permanently');
create type app.media_status as enum ('staged', 'validated', 'attached', 'quarantined', 'deletion_pending', 'deleted');
create type app.comment_state as enum ('active', 'tombstone', 'deletion_pending', 'deleted', 'moderation_removed');
create type app.reaction_kind as enum ('funny', 'love', 'annoying', 'same', 'ouch', 'wild');
create type app.vote_choice as enum ('guilty', 'not_guilty', 'me_too', 'just_you', 'agree', 'disagree');
create type app.report_target as enum ('post', 'comment');
create type app.report_state as enum ('open', 'triaged', 'resolved_actioned', 'resolved_dismissed', 'appealed', 'closed');
create type app.moderation_action_kind as enum ('lock', 'unlock', 'remove', 'restore', 'restrict_account', 'unrestrict_account', 'dismiss_report', 'record_authorship_access', 'apply_hold', 'release_hold');
create type app.appeal_state as enum ('submitted', 'under_review', 'upheld', 'overturned', 'rejected');
create type app.job_kind as enum ('expire_post', 'delete_post', 'delete_media', 'delete_account', 'purge_signals', 'purge_evidence', 'purge_staging');
create type app.job_state as enum ('pending', 'running', 'succeeded', 'retryable', 'failed', 'cancelled');
create type app.signal_kind as enum ('impression', 'open', 'comment', 'reaction', 'vote', 'share');

create table private.accounts (
  user_id uuid primary key references auth.users(id) on delete restrict,
  state app.account_state not null default 'active',
  verified_email boolean not null default false,
  verified_phone boolean not null default false,
  last_username_change_at timestamptz not null default statement_timestamp(),
  personalization_opt_out boolean not null default false,
  restricted_until timestamptz,
  restriction_reason_code text,
  deletion_mode app.deletion_mode,
  deletion_requested_at timestamptz,
  deletion_execute_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint accounts_deletion_fields_check check (
    (state = 'deletion_pending' and deletion_mode is not null and deletion_requested_at is not null)
    or (state = 'deleted' and deleted_at is not null)
    or (state not in ('deletion_pending', 'deleted') and deletion_mode is null and deletion_requested_at is null and deletion_execute_at is null and deleted_at is null)
  ),
  constraint accounts_restriction_fields_check check (
    state = 'restricted' or (restricted_until is null and restriction_reason_code is null)
  )
);

create index accounts_state_idx on private.accounts (state);
create index accounts_deletion_execute_idx on private.accounts (deletion_execute_at) where state = 'deletion_pending';
create index accounts_restricted_until_idx on private.accounts (restricted_until) where restricted_until is not null;

create table app.avatar_catalog (
  avatar_id uuid primary key default gen_random_uuid(),
  key text not null unique,
  asset_path text not null unique,
  alt_label text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint avatar_key_check check (key ~ '^[a-z0-9][a-z0-9_-]{0,63}$'),
  constraint avatar_asset_path_check check (length(btrim(asset_path)) > 0),
  constraint avatar_alt_label_check check (length(btrim(alt_label)) > 0)
);

create table app.public_profiles (
  profile_id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references private.accounts(user_id) on delete cascade,
  username text not null,
  normalized_username text not null unique,
  avatar_id uuid references app.avatar_catalog(avatar_id) on delete restrict,
  show_post_history boolean not null default true,
  show_comment_history boolean not null default true,
  is_discoverable boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint profile_username_storage_check check (
    char_length(username) between 3 and 96
    and octet_length(username) <= 384
    and username = btrim(username)
  ),
  constraint profile_normalized_username_check check (
    length(normalized_username) between 3 and 384
    and normalized_username = btrim(normalized_username)
  )
);

do $migration$
declare
  trigram_schema name;
begin
  select n.nspname into trigram_schema
  from pg_catalog.pg_opclass o
  join pg_catalog.pg_am am on am.oid = o.opcmethod
  join pg_catalog.pg_namespace n on n.oid = o.opcnamespace
  where o.opcname = 'gin_trgm_ops' and am.amname = 'gin';

  if trigram_schema is null then
    raise exception 'pg_trgm gin_trgm_ops is unavailable';
  end if;

  execute format(
    'create index public_profiles_discoverable_username_trgm_idx on app.public_profiles using gin (normalized_username %I.gin_trgm_ops) where is_discoverable',
    trigram_schema
  );
end;
$migration$;

create table private.reserved_username_catalog (
  normalized_username text primary key,
  reason text not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint reserved_username_value_check check (normalized_username = btrim(normalized_username) and length(normalized_username) >= 1)
);

create table private.username_claims (
  normalized_username text primary key,
  current_user_id uuid references private.accounts(user_id) on delete restrict,
  claimed_at timestamptz,
  released_at timestamptz,
  reserved_until timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint username_claim_state_check check (
    (current_user_id is not null and claimed_at is not null and released_at is null)
    or (current_user_id is null and released_at is not null)
  ),
  constraint username_claim_reservation_check check (reserved_until is null or released_at is not null)
);

create unique index username_claims_active_user_uidx on private.username_claims (current_user_id) where current_user_id is not null;
create index username_claims_reserved_until_idx on private.username_claims (reserved_until) where reserved_until is not null;

create table private.username_history (
  history_id bigint generated always as identity primary key,
  user_id uuid not null references private.accounts(user_id) on delete restrict,
  previous_username text,
  previous_normalized_username text,
  new_username text not null,
  new_normalized_username text not null,
  changed_at timestamptz not null default statement_timestamp(),
  reserved_until timestamptz,
  change_source text not null default 'user',
  constraint username_history_new_value_check check (length(btrim(new_username)) > 0 and length(btrim(new_normalized_username)) > 0),
  constraint username_history_previous_pair_check check ((previous_username is null) = (previous_normalized_username is null))
);

create index username_history_user_changed_idx on private.username_history (user_id, changed_at desc, history_id desc);
create index username_history_previous_normalized_idx on private.username_history (previous_normalized_username) where previous_normalized_username is not null;

create table app.topics (
  topic_id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint topic_slug_check check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint topic_label_check check (length(btrim(label)) between 1 and 80),
  constraint topic_description_check check (description is null or char_length(description) <= 500)
);

create unique index topics_label_lower_uidx on app.topics (lower(label));
create index topics_active_sort_idx on app.topics (is_active, sort_order, topic_id);
do $migration$
declare
  trigram_schema name;
begin
  select n.nspname into trigram_schema
  from pg_catalog.pg_opclass o
  join pg_catalog.pg_am am on am.oid = o.opcmethod
  join pg_catalog.pg_namespace n on n.oid = o.opcnamespace
  where o.opcname = 'gin_trgm_ops' and am.amname = 'gin';

  if trigram_schema is null then
    raise exception 'pg_trgm gin_trgm_ops is unavailable';
  end if;

  execute format(
    'create index topics_label_trgm_idx on app.topics using gin (label %I.gin_trgm_ops)',
    trigram_schema
  );
end;
$migration$;

create table app.posts (
  post_id uuid primary key default gen_random_uuid(),
  format app.post_format not null default 'regular',
  body text not null default '',
  topic_id uuid references app.topics(topic_id) on delete restrict,
  identity_mode app.identity_mode not null default 'attributed',
  public_author_profile_id uuid references app.public_profiles(profile_id) on delete set null,
  state app.post_state not null default 'active',
  is_account_deleted_author boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz,
  expiry_action app.expiry_action,
  locked_at timestamptz,
  archived_at timestamptz,
  deleted_at timestamptz,
  moderated_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  search_document tsvector not null default ''::tsvector,
  constraint post_body_storage_check check (
    char_length(body) <= 1024
    and octet_length(body) <= 4096
    and body = btrim(body)
  ),
  constraint post_identity_check check (
    (identity_mode = 'anonymous' and public_author_profile_id is null)
    or (identity_mode = 'attributed' and public_author_profile_id is not null and not is_account_deleted_author)
  ),
  constraint post_expiry_pair_check check ((expires_at is null) = (expiry_action is null)),
  constraint post_expiry_exact_check check (expires_at is null or expires_at = created_at + interval '24 hours'),
  constraint post_locked_state_check check (state <> 'locked' or locked_at is not null),
  constraint post_archived_state_check check (state not in ('archived', 'expired_archived') or archived_at is not null),
  constraint post_deleted_state_check check (state <> 'deleted' or deleted_at is not null),
  constraint post_moderated_state_check check (state <> 'moderation_removed' or moderated_at is not null)
);

create index posts_latest_public_idx on app.posts (created_at desc, post_id desc) where state in ('active', 'locked');
create index posts_expiry_worker_idx on app.posts (expires_at, post_id) where expires_at is not null and state in ('active', 'locked');
create index posts_topic_public_idx on app.posts (topic_id, created_at desc, post_id desc) where state in ('active', 'locked');
create index posts_format_public_idx on app.posts (format, created_at desc, post_id desc) where state in ('active', 'locked');
create index posts_author_public_idx on app.posts (public_author_profile_id, created_at desc, post_id desc) where state in ('active', 'locked') and public_author_profile_id is not null;
create index posts_search_document_idx on app.posts using gin (search_document) where state in ('active', 'locked');

create table private.post_owners (
  post_id uuid primary key references app.posts(post_id) on delete cascade,
  owner_user_id uuid not null references private.accounts(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp()
);

create index post_owners_owner_created_idx on private.post_owners (owner_user_id, created_at desc, post_id desc);

create table private.post_quota_events (
  event_id bigint generated always as identity primary key,
  post_id uuid not null unique,
  owner_user_id uuid not null references private.accounts(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp()
);

create index post_quota_events_owner_created_idx on private.post_quota_events (owner_user_id, created_at desc, event_id desc);

create table private.media_assets (
  media_id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references private.accounts(user_id) on delete restrict,
  post_id uuid unique references app.posts(post_id) on delete set null,
  status app.media_status not null default 'staged',
  bucket text not null,
  object_key text not null unique,
  processed_key text unique,
  declared_mime text not null,
  detected_mime text,
  byte_size bigint not null check (byte_size between 1 and 2097152),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  frame_count integer check (frame_count is null or frame_count >= 1),
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  sha256 bytea not null,
  alt_text text,
  validated_at timestamptz,
  attached_at timestamptz,
  expires_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint media_owner_lifecycle_check check (
    owner_user_id is not null
    or (status = 'attached' and post_id is not null)
    or status in ('deletion_pending', 'deleted')
  ),
  constraint media_bucket_check check (length(btrim(bucket)) > 0),
  constraint media_object_key_check check (length(btrim(object_key)) >= 16),
  constraint media_processed_key_check check (processed_key is null or length(btrim(processed_key)) >= 16),
  constraint media_detected_mime_check check (detected_mime is null or detected_mime in ('image/jpeg', 'image/png', 'image/webp', 'image/gif')),
  constraint media_alt_text_check check (alt_text is null or (char_length(alt_text) <= 300 and alt_text = btrim(alt_text))),
  constraint media_attached_state_check check (status <> 'attached' or (post_id is not null and attached_at is not null and validated_at is not null)),
  constraint media_validated_state_check check (status not in ('validated', 'attached') or (detected_mime is not null and validated_at is not null)),
  constraint media_deleted_state_check check (status <> 'deleted' or deleted_at is not null)
);

create index media_assets_owner_created_idx on private.media_assets (owner_user_id, created_at desc, media_id);
create index media_assets_status_expiry_idx on private.media_assets (status, expires_at) where expires_at is not null;
create index media_assets_sha256_idx on private.media_assets (sha256);

create table app.comments (
  comment_id uuid primary key default gen_random_uuid(),
  post_id uuid not null references app.posts(post_id) on delete cascade,
  parent_comment_id uuid references app.comments(comment_id) on delete restrict,
  public_author_profile_id uuid references app.public_profiles(profile_id) on delete set null,
  body text not null,
  state app.comment_state not null default 'active',
  is_account_deleted_author boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  deleted_at timestamptz,
  moderated_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint comment_body_storage_check check (char_length(body) <= 1024 and octet_length(body) <= 4096),
  constraint comment_body_state_check check (
    (state = 'active' and length(btrim(body)) > 0)
    or (state = 'tombstone' and body = '')
    or state in ('deletion_pending', 'deleted', 'moderation_removed')
  ),
  constraint comment_author_check check (public_author_profile_id is not null or is_account_deleted_author),
  constraint comment_deleted_state_check check (state <> 'deleted' or deleted_at is not null),
  constraint comment_moderated_state_check check (state <> 'moderation_removed' or moderated_at is not null)
);

create index comments_post_thread_idx on app.comments (post_id, created_at, comment_id);
create index comments_parent_thread_idx on app.comments (parent_comment_id, created_at, comment_id) where parent_comment_id is not null;
create index comments_author_public_idx on app.comments (public_author_profile_id, created_at desc, comment_id desc) where state = 'active' and public_author_profile_id is not null;

create table private.comment_owners (
  comment_id uuid primary key references app.comments(comment_id) on delete cascade,
  owner_user_id uuid not null references private.accounts(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp()
);

create index comment_owners_owner_created_idx on private.comment_owners (owner_user_id, created_at desc, comment_id desc);

create table private.post_reactions (
  post_id uuid not null references app.posts(post_id) on delete cascade,
  user_id uuid not null references private.accounts(user_id) on delete cascade,
  reaction app.reaction_kind not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  primary key (post_id, user_id)
);

create index post_reactions_post_reaction_idx on private.post_reactions (post_id, reaction);
create index post_reactions_user_updated_idx on private.post_reactions (user_id, updated_at desc);

create table private.post_votes (
  post_id uuid not null references app.posts(post_id) on delete cascade,
  user_id uuid not null references private.accounts(user_id) on delete cascade,
  choice app.vote_choice not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  primary key (post_id, user_id)
);

create index post_votes_post_choice_idx on private.post_votes (post_id, choice);
create index post_votes_user_updated_idx on private.post_votes (user_id, updated_at desc);

create table private.report_reason_catalog (
  reason_code text primary key,
  label text not null,
  allowed_targets app.report_target[] not null default array['post'::app.report_target, 'comment'::app.report_target],
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint report_reason_code_check check (reason_code ~ '^[a-z0-9][a-z0-9_-]{0,63}$'),
  constraint report_reason_label_check check (length(btrim(label)) between 1 and 120),
  constraint report_reason_targets_check check (cardinality(allowed_targets) >= 1)
);

create table private.reports (
  report_id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references private.accounts(user_id) on delete restrict,
  target_type app.report_target not null,
  post_id uuid,
  comment_id uuid,
  reason_code text not null references private.report_reason_catalog(reason_code) on delete restrict,
  detail text,
  state app.report_state not null default 'open',
  assigned_moderator_user_id uuid references private.accounts(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  version integer not null default 1 check (version > 0),
  constraint report_target_xor_check check (num_nonnulls(post_id, comment_id) = 1),
  constraint report_detail_check check (detail is null or char_length(detail) <= 2000),
  constraint report_resolution_check check (state not in ('resolved_actioned', 'resolved_dismissed', 'closed') or resolved_at is not null)
);

create unique index reports_open_post_reason_uidx on private.reports (reporter_user_id, post_id, reason_code) where post_id is not null and state in ('open', 'triaged', 'appealed');
create unique index reports_open_comment_reason_uidx on private.reports (reporter_user_id, comment_id, reason_code) where comment_id is not null and state in ('open', 'triaged', 'appealed');
create index reports_queue_idx on private.reports (state, created_at, report_id);
create index reports_post_target_idx on private.reports (post_id, created_at desc) where post_id is not null;
create index reports_comment_target_idx on private.reports (comment_id, created_at desc) where comment_id is not null;
create index reports_assignee_idx on private.reports (assigned_moderator_user_id, state, created_at) where assigned_moderator_user_id is not null;
create index reports_reporter_created_idx on private.reports (reporter_user_id, created_at desc);

create table private.moderator_roles (
  moderator_role_id bigint generated always as identity primary key,
  user_id uuid not null references private.accounts(user_id) on delete restrict,
  role_key text not null,
  granted_by uuid references private.accounts(user_id) on delete restrict,
  granted_at timestamptz not null default statement_timestamp(),
  revoked_at timestamptz,
  constraint moderator_role_key_check check (role_key in ('reviewer', 'admin')),
  constraint moderator_role_revoke_check check (revoked_at is null or revoked_at >= granted_at)
);

create unique index moderator_roles_active_uidx on private.moderator_roles (user_id, role_key) where revoked_at is null;
create index moderator_roles_active_user_idx on private.moderator_roles (user_id) where revoked_at is null;

create table private.moderation_cases (
  case_id uuid primary key default gen_random_uuid(),
  category text not null,
  status text not null default 'open',
  severity smallint not null default 1 check (severity between 1 and 5),
  post_id uuid,
  comment_id uuid,
  account_user_id uuid references private.accounts(user_id) on delete restrict,
  assigned_moderator_user_id uuid references private.accounts(user_id) on delete restrict,
  opened_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  evidence_delete_at timestamptz,
  legal_hold boolean not null default false,
  legal_hold_reason text,
  legal_hold_applied_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint moderation_case_target_check check (num_nonnulls(post_id, comment_id, account_user_id) <= 1),
  constraint moderation_case_category_check check (length(btrim(category)) between 1 and 80),
  constraint moderation_case_status_check check (length(btrim(status)) between 1 and 40),
  constraint moderation_case_resolution_check check (resolved_at is null or resolved_at >= opened_at),
  constraint moderation_case_hold_check check (
    (not legal_hold and legal_hold_reason is null and legal_hold_applied_at is null)
    or (legal_hold and legal_hold_reason is not null and legal_hold_applied_at is not null)
  )
);

create unique index moderation_cases_active_post_uidx on private.moderation_cases (post_id, category) where post_id is not null and resolved_at is null;
create unique index moderation_cases_active_comment_uidx on private.moderation_cases (comment_id, category) where comment_id is not null and resolved_at is null;
create unique index moderation_cases_active_account_uidx on private.moderation_cases (account_user_id, category) where account_user_id is not null and resolved_at is null;
create index moderation_cases_queue_idx on private.moderation_cases (status, severity desc, opened_at, case_id);
create index moderation_cases_assignee_idx on private.moderation_cases (assigned_moderator_user_id, status, opened_at) where assigned_moderator_user_id is not null;
create index moderation_cases_evidence_delete_idx on private.moderation_cases (evidence_delete_at) where evidence_delete_at is not null and not legal_hold;

create table private.moderation_actions (
  action_id bigint generated always as identity primary key,
  case_id uuid not null references private.moderation_cases(case_id) on delete restrict,
  moderator_user_id uuid not null references private.accounts(user_id) on delete restrict,
  action_kind app.moderation_action_kind not null,
  reason_code text not null,
  notes text,
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default statement_timestamp(),
  constraint moderation_action_reason_check check (length(btrim(reason_code)) between 1 and 120),
  constraint moderation_action_notes_check check (notes is null or char_length(notes) <= 4000),
  constraint moderation_action_state_shape_check check (
    (before_state is null or jsonb_typeof(before_state) = 'object')
    and (after_state is null or jsonb_typeof(after_state) = 'object')
  )
);

create index moderation_actions_case_created_idx on private.moderation_actions (case_id, created_at, action_id);
create index moderation_actions_moderator_created_idx on private.moderation_actions (moderator_user_id, created_at desc);

create table private.moderation_evidence (
  evidence_id uuid primary key default gen_random_uuid(),
  case_id uuid not null references private.moderation_cases(case_id) on delete restrict,
  evidence_type text not null,
  restricted_reference text,
  content_hash bytea,
  captured_at timestamptz not null default statement_timestamp(),
  delete_at timestamptz,
  legal_hold boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint moderation_evidence_type_check check (length(btrim(evidence_type)) between 1 and 80),
  constraint moderation_evidence_payload_check check (num_nonnulls(restricted_reference, content_hash) >= 1),
  constraint moderation_evidence_delete_check check (delete_at is null or delete_at >= captured_at)
);

create index moderation_evidence_case_idx on private.moderation_evidence (case_id, captured_at, evidence_id);
create index moderation_evidence_delete_idx on private.moderation_evidence (delete_at) where delete_at is not null and not legal_hold;

create table private.appeals (
  appeal_id uuid primary key default gen_random_uuid(),
  case_id uuid not null references private.moderation_cases(case_id) on delete restrict,
  appellant_user_id uuid not null references private.accounts(user_id) on delete restrict,
  statement text not null,
  state app.appeal_state not null default 'submitted',
  reviewer_user_id uuid references private.accounts(user_id) on delete restrict,
  submitted_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  resolution_reason text,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check (version > 0),
  constraint appeal_statement_check check (char_length(btrim(statement)) between 1 and 4000),
  constraint appeal_resolution_check check (
    (state in ('submitted', 'under_review') and resolved_at is null and resolution_reason is null)
    or (state in ('upheld', 'overturned', 'rejected') and resolved_at is not null and resolution_reason is not null)
  )
);

create index appeals_case_submitted_idx on private.appeals (case_id, submitted_at desc, appeal_id);
create index appeals_appellant_submitted_idx on private.appeals (appellant_user_id, submitted_at desc);
create index appeals_review_queue_idx on private.appeals (state, submitted_at, appeal_id) where state in ('submitted', 'under_review');

create table private.recommendation_signals (
  signal_id bigint generated always as identity primary key,
  user_id uuid references private.accounts(user_id) on delete cascade,
  guest_session_hash bytea,
  post_id uuid not null references app.posts(post_id) on delete cascade,
  signal_kind app.signal_kind not null,
  surface text not null,
  position integer check (position is null or position >= 0),
  occurred_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  constraint recommendation_signal_actor_check check (num_nonnulls(user_id, guest_session_hash) = 1),
  constraint recommendation_signal_surface_check check (length(btrim(surface)) between 1 and 80)
);

create index recommendation_signals_user_time_idx on private.recommendation_signals (user_id, occurred_at desc) where user_id is not null;
create index recommendation_signals_post_time_idx on private.recommendation_signals (post_id, occurred_at desc);
create index recommendation_signals_expiry_idx on private.recommendation_signals (occurred_at);
create index recommendation_signals_guest_time_idx on private.recommendation_signals (guest_session_hash, occurred_at desc) where guest_session_hash is not null;

create table private.feed_preferences (
  user_id uuid primary key references private.accounts(user_id) on delete cascade,
  topic_scores jsonb not null default '{}'::jsonb,
  format_scores jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null,
  version integer not null default 1 check (version > 0),
  constraint feed_preferences_topic_shape_check check (jsonb_typeof(topic_scores) = 'object'),
  constraint feed_preferences_format_shape_check check (jsonb_typeof(format_scores) = 'object'),
  constraint feed_preferences_expiry_check check (expires_at > calculated_at)
);

create index feed_preferences_expiry_idx on private.feed_preferences (expires_at);

create table private.idempotency_keys (
  user_id uuid not null references private.accounts(user_id) on delete cascade,
  operation text not null,
  key uuid not null,
  request_hash bytea not null,
  response_code integer,
  response_json jsonb,
  state text not null default 'pending',
  created_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null,
  primary key (user_id, operation, key),
  constraint idempotency_operation_check check (operation ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
  constraint idempotency_state_check check (state in ('pending', 'completed', 'failed')),
  constraint idempotency_response_check check (
    (state = 'completed' and response_code is not null and response_json is not null)
    or state <> 'completed'
  ),
  constraint idempotency_expiry_check check (expires_at > created_at)
);

create index idempotency_expiry_idx on private.idempotency_keys (expires_at);

create table private.outbox_jobs (
  job_id bigint generated always as identity primary key,
  job_kind app.job_kind not null,
  deduplication_key text not null,
  target_id uuid,
  payload jsonb not null default '{}'::jsonb,
  target_version integer,
  run_after timestamptz not null default statement_timestamp(),
  state app.job_state not null default 'pending',
  attempts integer not null default 0 check (attempts >= 0),
  last_safe_error text,
  locked_at timestamptz,
  locked_by text,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  constraint outbox_dedupe_key_check check (length(btrim(deduplication_key)) between 1 and 200),
  constraint outbox_payload_shape_check check (jsonb_typeof(payload) = 'object'),
  constraint outbox_target_version_check check (target_version is null or target_version > 0),
  constraint outbox_completion_check check (state <> 'succeeded' or completed_at is not null)
);

create unique index outbox_jobs_active_dedupe_uidx on private.outbox_jobs (deduplication_key) where state in ('pending', 'running', 'retryable');
create index outbox_jobs_ready_idx on private.outbox_jobs (run_after, job_id) where state in ('pending', 'retryable');
create index outbox_jobs_locked_idx on private.outbox_jobs (locked_at) where state = 'running';

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create function private.set_versioned_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := statement_timestamp();
  new.version := old.version + 1;
  return new;
end;
$$;

create function private.prevent_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception '% is append-only', tg_table_schema || '.' || tg_table_name using errcode = '55000';
end;
$$;

create function private.enforce_profile_immutability()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.profile_id is distinct from old.profile_id or new.user_id is distinct from old.user_id then
    raise exception 'profile identity is immutable' using errcode = '55000';
  end if;
  return new;
end;
$$;

create function private.enforce_post_immutability()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  owner_account_state app.account_state;
  owner_deletion_mode app.deletion_mode;
begin
  if new.post_id is distinct from old.post_id
     or new.body is distinct from old.body
     or new.format is distinct from old.format
     or new.topic_id is distinct from old.topic_id
     or new.created_at is distinct from old.created_at
     or new.expires_at is distinct from old.expires_at then
    raise exception 'published post content and expiry timestamp are immutable' using errcode = '55000';
  end if;

  if new.identity_mode is distinct from old.identity_mode
     or new.public_author_profile_id is distinct from old.public_author_profile_id
     or new.is_account_deleted_author is distinct from old.is_account_deleted_author then
    if not (
      not old.is_account_deleted_author
      and new.is_account_deleted_author
      and new.identity_mode = 'anonymous'
      and new.public_author_profile_id is null
    ) then
      raise exception 'post identity is immutable outside account deletion' using errcode = '55000';
    end if;

    select a.state, a.deletion_mode
      into owner_account_state, owner_deletion_mode
    from private.post_owners owner
    join private.accounts a on a.user_id = owner.owner_user_id
    where owner.post_id = old.post_id;

    if not found
       or owner_account_state not in ('deletion_pending', 'deleted')
       or owner_deletion_mode <> 'preserve_anonymously' then
      raise exception 'post identity conversion requires preserve-anonymously account deletion' using errcode = '55000';
    end if;
  end if;

  return new;
end;
$$;

create function private.enforce_comment_immutability()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  owner_account_state app.account_state;
  owner_deletion_mode app.deletion_mode;
begin
  if new.comment_id is distinct from old.comment_id
     or new.post_id is distinct from old.post_id
     or new.parent_comment_id is distinct from old.parent_comment_id
     or new.created_at is distinct from old.created_at then
    raise exception 'comment structure is immutable' using errcode = '55000';
  end if;

  if new.body is distinct from old.body and not (new.state = 'tombstone' and new.body = '') then
    raise exception 'published comment body is immutable' using errcode = '55000';
  end if;

  if new.public_author_profile_id is distinct from old.public_author_profile_id
     or new.is_account_deleted_author is distinct from old.is_account_deleted_author then
    if not (
      not old.is_account_deleted_author
      and new.is_account_deleted_author
      and new.public_author_profile_id is null
    ) then
      raise exception 'comment author is immutable outside account deletion' using errcode = '55000';
    end if;

    select a.state, a.deletion_mode
      into owner_account_state, owner_deletion_mode
    from private.comment_owners owner
    join private.accounts a on a.user_id = owner.owner_user_id
    where owner.comment_id = old.comment_id;

    if not found
       or owner_account_state not in ('deletion_pending', 'deleted')
       or owner_deletion_mode <> 'preserve_anonymously' then
      raise exception 'comment attribution conversion requires preserve-anonymously account deletion' using errcode = '55000';
    end if;
  end if;

  return new;
end;
$$;

create function private.enforce_comment_parent()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, pg_temp
as $$
declare
  parent_post_id uuid;
  grandparent_id uuid;
  parent_state app.comment_state;
  target_post_state app.post_state;
  target_post_expires_at timestamptz;
begin
  select state, expires_at into target_post_state, target_post_expires_at
  from app.posts
  where post_id = new.post_id
  for update;

  if not found then
    raise exception 'comment post does not exist' using errcode = '23503';
  end if;
  if target_post_state <> 'active'
     or (target_post_expires_at is not null and target_post_expires_at <= statement_timestamp()) then
    raise exception 'comments require an active unexpired post' using errcode = '23514';
  end if;

  if new.parent_comment_id is null then
    return new;
  end if;

  select post_id, parent_comment_id, state
    into parent_post_id, grandparent_id, parent_state
  from app.comments
  where comment_id = new.parent_comment_id
  for update;

  if not found then
    raise exception 'parent comment does not exist' using errcode = '23503';
  end if;
  if parent_post_id <> new.post_id then
    raise exception 'parent comment belongs to a different post' using errcode = '23514';
  end if;
  if grandparent_id is not null then
    raise exception 'comments support one reply level only' using errcode = '23514';
  end if;
  if parent_state <> 'active' then
    raise exception 'cannot reply to an inactive comment' using errcode = '23514';
  end if;

  return new;
end;
$$;

create function private.refresh_post_search_document()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, pg_temp
as $$
declare
  topic_label text;
begin
  if new.topic_id is not null then
    select label into topic_label from app.topics where topic_id = new.topic_id;
  end if;
  new.search_document := to_tsvector('simple', concat_ws(' ', nullif(new.body, ''), topic_label));
  return new;
end;
$$;

create function private.refresh_topic_post_search_documents()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, pg_temp
as $$
begin
  if new.label is distinct from old.label then
    update app.posts
    set search_document = to_tsvector('simple', concat_ws(' ', nullif(body, ''), new.label))
    where topic_id = new.topic_id;
  end if;
  return new;
end;
$$;

create function private.assert_post_has_content(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  target_state app.post_state;
  target_body text;
begin
  if target_post_id is null then
    return;
  end if;

  select state, body into target_state, target_body
  from app.posts where post_id = target_post_id;

  if not found or target_state in ('deletion_pending', 'deleted', 'moderation_removed') then
    return;
  end if;

  if length(btrim(target_body)) = 0 and not exists (
    select 1 from private.media_assets
    where post_id = target_post_id
      and status = 'attached'
      and length(btrim(coalesce(alt_text, ''))) > 0
  ) then
    raise exception 'post requires text or an attached image with alt text' using errcode = '23514';
  end if;
end;
$$;

create function private.validate_post_has_content()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform private.assert_post_has_content(old.post_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and (tg_op = 'INSERT' or new.post_id is distinct from old.post_id) then
    perform private.assert_post_has_content(new.post_id);
  end if;
  return null;
end;
$$;

create function private.assert_post_ownership(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  target_identity app.identity_mode;
  target_profile_id uuid;
  target_deleted_author boolean;
  target_state app.post_state;
  owner_id uuid;
  profile_user_id uuid;
begin
  if target_post_id is null then
    return;
  end if;

  select identity_mode, public_author_profile_id, is_account_deleted_author, state
    into target_identity, target_profile_id, target_deleted_author, target_state
  from app.posts where post_id = target_post_id;

  if not found then
    return;
  end if;

  select owner_user_id into owner_id
  from private.post_owners where post_id = target_post_id;

  if not found then
    if not target_deleted_author and target_state <> 'deleted' then
      raise exception 'post requires a private owner mapping' using errcode = '23514';
    end if;
    if target_deleted_author and exists (
      select 1 from private.media_assets
      where post_id = target_post_id and owner_user_id is not null
    ) then
      raise exception 'account-deleted post media must not retain an owner identifier' using errcode = '23514';
    end if;
    return;
  end if;

  if target_deleted_author and not exists (
    select 1 from private.accounts a
    where a.user_id = owner_id
      and a.state in ('deletion_pending', 'deleted')
      and a.deletion_mode = 'preserve_anonymously'
  ) then
    raise exception 'retained account-deletion ownership requires preserve-anonymously lifecycle state' using errcode = '23514';
  end if;

  if target_identity = 'attributed' then
    select user_id into profile_user_id
    from app.public_profiles where profile_id = target_profile_id;
    if not found or profile_user_id <> owner_id then
      raise exception 'post attribution does not match private ownership' using errcode = '23514';
    end if;
  end if;

  if exists (
    select 1 from private.media_assets
    where post_id = target_post_id and owner_user_id is distinct from owner_id
  ) then
    raise exception 'post media owner does not match post owner' using errcode = '23514';
  end if;

  if not exists (
    select 1 from private.post_quota_events
    where post_id = target_post_id and owner_user_id = owner_id
  ) then
    raise exception 'post requires a matching immutable quota event' using errcode = '23514';
  end if;
end;
$$;

create function private.validate_post_ownership()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform private.assert_post_ownership(old.post_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and (tg_op = 'INSERT' or new.post_id is distinct from old.post_id) then
    perform private.assert_post_ownership(new.post_id);
  end if;
  return null;
end;
$$;

create function private.assert_comment_ownership(target_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  target_profile_id uuid;
  target_deleted_author boolean;
  target_state app.comment_state;
  owner_id uuid;
  profile_user_id uuid;
begin
  if target_comment_id is null then
    return;
  end if;

  select public_author_profile_id, is_account_deleted_author, state
    into target_profile_id, target_deleted_author, target_state
  from app.comments where comment_id = target_comment_id;

  if not found then
    return;
  end if;

  select owner_user_id into owner_id
  from private.comment_owners where comment_id = target_comment_id;

  if not found then
    if not target_deleted_author and target_state <> 'deleted' then
      raise exception 'comment requires a private owner mapping' using errcode = '23514';
    end if;
    return;
  end if;

  if target_deleted_author then
    if not exists (
      select 1 from private.accounts a
      where a.user_id = owner_id
        and a.state in ('deletion_pending', 'deleted')
        and a.deletion_mode = 'preserve_anonymously'
    ) then
      raise exception 'retained account-deletion ownership requires preserve-anonymously lifecycle state' using errcode = '23514';
    end if;
  else
    select user_id into profile_user_id
    from app.public_profiles where profile_id = target_profile_id;
    if not found or profile_user_id <> owner_id then
      raise exception 'comment attribution does not match private ownership' using errcode = '23514';
    end if;
  end if;
end;
$$;

create function private.validate_comment_ownership()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform private.assert_comment_ownership(old.comment_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and (tg_op = 'INSERT' or new.comment_id is distinct from old.comment_id) then
    perform private.assert_comment_ownership(new.comment_id);
  end if;
  return null;
end;
$$;

create function private.guard_owner_deletion_for_hold()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
begin
  if tg_table_name = 'post_owners' and exists (
    select 1
    from private.moderation_cases c
    where (c.post_id = old.post_id or c.account_user_id = old.owner_user_id)
      and (
        c.legal_hold
        or exists (
          select 1 from private.moderation_evidence e
          where e.case_id = c.case_id and e.legal_hold
        )
      )
  ) then
    raise exception 'post ownership is retained by a moderation or legal hold' using errcode = '55000';
  end if;

  if tg_table_name = 'comment_owners' and exists (
    select 1
    from private.moderation_cases c
    where (c.comment_id = old.comment_id or c.account_user_id = old.owner_user_id)
      and (
        c.legal_hold
        or exists (
          select 1 from private.moderation_evidence e
          where e.case_id = c.case_id and e.legal_hold
        )
      )
  ) then
    raise exception 'comment ownership is retained by a moderation or legal hold' using errcode = '55000';
  end if;

  return old;
end;
$$;

create function private.enforce_reaction_compatibility()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, pg_temp
as $$
declare
  post_format_value app.post_format;
begin
  select format into post_format_value from app.posts where post_id = new.post_id;
  if not found then
    raise exception 'post does not exist' using errcode = '23503';
  end if;

  if (post_format_value = 'regular' and new.reaction not in ('funny', 'love', 'annoying'))
     or (post_format_value = 'confession' and new.reaction not in ('same', 'ouch', 'wild'))
     or post_format_value in ('petty_court', 'am_i_weird', 'hot_take') then
    raise exception 'reaction is not valid for this post format' using errcode = '23514';
  end if;
  return new;
end;
$$;

create function private.enforce_vote_compatibility()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, pg_temp
as $$
declare
  post_format_value app.post_format;
begin
  select format into post_format_value from app.posts where post_id = new.post_id;
  if not found then
    raise exception 'post does not exist' using errcode = '23503';
  end if;

  if (post_format_value = 'petty_court' and new.choice not in ('guilty', 'not_guilty'))
     or (post_format_value = 'am_i_weird' and new.choice not in ('me_too', 'just_you'))
     or (post_format_value = 'hot_take' and new.choice not in ('agree', 'disagree'))
     or post_format_value in ('regular', 'confession') then
    raise exception 'vote is not valid for this post format' using errcode = '23514';
  end if;
  return new;
end;
$$;

create function private.enforce_report_target()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  reason_targets app.report_target[];
  reason_is_active boolean;
begin
  if (new.target_type = 'post' and (new.post_id is null or new.comment_id is not null))
     or (new.target_type = 'comment' and (new.comment_id is null or new.post_id is not null)) then
    raise exception 'report target type does not match target' using errcode = '23514';
  end if;

  if (new.target_type = 'post' and not exists (select 1 from app.posts where post_id = new.post_id))
     or (new.target_type = 'comment' and not exists (select 1 from app.comments where comment_id = new.comment_id)) then
    raise exception 'report target does not exist' using errcode = '23503';
  end if;

  select allowed_targets, is_active into reason_targets, reason_is_active
  from private.report_reason_catalog
  where reason_code = new.reason_code;

  if not found then
    raise exception 'report reason does not exist' using errcode = '23503';
  end if;
  if not reason_is_active or not (new.target_type = any(reason_targets)) then
    raise exception 'report reason is not active for this target type' using errcode = '23514';
  end if;

  return new;
end;
$$;

create function private.enforce_moderation_case_target()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
begin
  if new.post_id is not null and not exists (select 1 from app.posts where post_id = new.post_id) then
    raise exception 'moderation case post target does not exist' using errcode = '23503';
  end if;
  if new.comment_id is not null and not exists (select 1 from app.comments where comment_id = new.comment_id) then
    raise exception 'moderation case comment target does not exist' using errcode = '23503';
  end if;
  return new;
end;
$$;

create function private.guard_profile_deletion()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app, private, pg_temp
as $$
declare
  account_state_value app.account_state;
  deletion_mode_value app.deletion_mode;
begin
  select state, deletion_mode into account_state_value, deletion_mode_value
  from private.accounts
  where user_id = old.user_id
  for update;

  if not found
     or account_state_value not in ('deletion_pending', 'deleted')
     or deletion_mode_value is null then
    raise exception 'profile deletion requires an active account-deletion lifecycle' using errcode = '55000';
  end if;

  if exists (select 1 from app.posts where public_author_profile_id = old.profile_id)
     or exists (select 1 from app.comments where public_author_profile_id = old.profile_id) then
    raise exception 'profile contributions must be converted or deleted before profile deletion' using errcode = '55000';
  end if;

  if deletion_mode_value = 'preserve_anonymously' and (
    exists (
      select 1 from private.post_owners owner
      join app.posts post on post.post_id = owner.post_id
      where owner.owner_user_id = old.user_id and not post.is_account_deleted_author
    )
    or exists (
      select 1 from private.comment_owners owner
      join app.comments comment on comment.comment_id = owner.comment_id
      where owner.owner_user_id = old.user_id and not comment.is_account_deleted_author
    )
  ) then
    raise exception 'preserved contributions must be marked as account-deleted before profile deletion' using errcode = '55000';
  end if;

  if deletion_mode_value = 'delete_contributions' and (
    exists (
      select 1 from private.post_owners owner
      join app.posts post on post.post_id = owner.post_id
      where owner.owner_user_id = old.user_id
        and post.state not in ('deletion_pending', 'deleted', 'moderation_removed')
    )
    or exists (
      select 1 from private.comment_owners owner
      join app.comments comment on comment.comment_id = owner.comment_id
      where owner.owner_user_id = old.user_id
        and comment.state not in ('deletion_pending', 'deleted', 'moderation_removed')
    )
  ) then
    raise exception 'owned contributions must enter deletion before profile deletion' using errcode = '55000';
  end if;

  if exists (select 1 from private.post_reactions where user_id = old.user_id)
     or exists (select 1 from private.post_votes where user_id = old.user_id)
     or exists (select 1 from private.recommendation_signals where user_id = old.user_id)
     or exists (select 1 from private.feed_preferences where user_id = old.user_id) then
    raise exception 'interactions and recommendation data must be purged before profile deletion' using errcode = '55000';
  end if;

  return old;
end;
$$;

create function app.is_post_public(
  target_post_id uuid,
  post_state_value app.post_state,
  post_expires_at timestamptz,
  account_deleted_author boolean
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private, pg_temp
as $$
  select post_state_value in ('active', 'locked')
     and (post_expires_at is null or post_expires_at > statement_timestamp())
     and (
       account_deleted_author
       or exists (
         select 1
         from private.post_owners owner
         join private.accounts account on account.user_id = owner.owner_user_id
         where owner.post_id = target_post_id
           and account.state = 'active'
           and (account.restricted_until is null or account.restricted_until <= statement_timestamp())
       )
     );
$$;

create function app.is_comment_public(
  target_comment_id uuid,
  comment_state_value app.comment_state,
  account_deleted_author boolean
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private, pg_temp
as $$
  select comment_state_value in ('active', 'tombstone')
     and (
       account_deleted_author
       or exists (
         select 1
         from private.comment_owners owner
         join private.accounts account on account.user_id = owner.owner_user_id
         where owner.comment_id = target_comment_id
           and account.state = 'active'
           and (account.restricted_until is null or account.restricted_until <= statement_timestamp())
       )
     );
$$;

create function app.is_profile_public(profile_user_id uuid, profile_is_discoverable boolean)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private, pg_temp
as $$
  select profile_is_discoverable
     and exists (
       select 1 from private.accounts a
       where a.user_id = profile_user_id
         and a.state = 'active'
         and (a.restricted_until is null or a.restricted_until <= statement_timestamp())
     );
$$;

create trigger accounts_set_updated_at before update on private.accounts for each row execute function private.set_versioned_updated_at();
create trigger avatars_set_updated_at before update on app.avatar_catalog for each row execute function private.set_updated_at();
create trigger profiles_set_updated_at before update on app.public_profiles for each row execute function private.set_versioned_updated_at();
create trigger username_claims_set_updated_at before update on private.username_claims for each row execute function private.set_updated_at();
create trigger topics_set_updated_at before update on app.topics for each row execute function private.set_updated_at();
create trigger posts_set_updated_at before update on app.posts for each row execute function private.set_versioned_updated_at();
create trigger media_set_updated_at before update on private.media_assets for each row execute function private.set_versioned_updated_at();
create trigger comments_set_updated_at before update on app.comments for each row execute function private.set_versioned_updated_at();
create trigger reactions_set_updated_at before update on private.post_reactions for each row execute function private.set_updated_at();
create trigger votes_set_updated_at before update on private.post_votes for each row execute function private.set_updated_at();
create trigger report_reasons_set_updated_at before update on private.report_reason_catalog for each row execute function private.set_updated_at();
create trigger reports_set_updated_at before update on private.reports for each row execute function private.set_versioned_updated_at();
create trigger moderation_cases_set_updated_at before update on private.moderation_cases for each row execute function private.set_versioned_updated_at();
create trigger moderation_evidence_set_updated_at before update on private.moderation_evidence for each row execute function private.set_updated_at();
create trigger appeals_set_updated_at before update on private.appeals for each row execute function private.set_versioned_updated_at();
create trigger outbox_set_updated_at before update on private.outbox_jobs for each row execute function private.set_updated_at();

create trigger profiles_immutable before update on app.public_profiles for each row execute function private.enforce_profile_immutability();
create trigger posts_immutable before update on app.posts for each row execute function private.enforce_post_immutability();
create trigger comments_immutable before update on app.comments for each row execute function private.enforce_comment_immutability();
create trigger comments_parent_invariant before insert or update of post_id, parent_comment_id on app.comments for each row execute function private.enforce_comment_parent();
create trigger posts_search_document before insert or update of body, topic_id on app.posts for each row execute function private.refresh_post_search_document();
create trigger topics_refresh_post_search after update of label on app.topics for each row execute function private.refresh_topic_post_search_documents();
create constraint trigger posts_content_invariant after insert or update on app.posts deferrable initially deferred for each row execute function private.validate_post_has_content();
create constraint trigger media_post_content_invariant after insert or update or delete on private.media_assets deferrable initially deferred for each row execute function private.validate_post_has_content();
create constraint trigger posts_owner_invariant after insert or update or delete on app.posts deferrable initially deferred for each row execute function private.validate_post_ownership();
create constraint trigger post_owners_invariant after insert or update or delete on private.post_owners deferrable initially deferred for each row execute function private.validate_post_ownership();
create constraint trigger post_quota_owner_invariant after insert on private.post_quota_events deferrable initially deferred for each row execute function private.validate_post_ownership();
create constraint trigger media_owner_invariant after insert or update or delete on private.media_assets deferrable initially deferred for each row execute function private.validate_post_ownership();
create constraint trigger comments_owner_invariant after insert or update or delete on app.comments deferrable initially deferred for each row execute function private.validate_comment_ownership();
create constraint trigger comment_owners_invariant after insert or update or delete on private.comment_owners deferrable initially deferred for each row execute function private.validate_comment_ownership();
create trigger post_owners_hold_guard before delete on private.post_owners for each row execute function private.guard_owner_deletion_for_hold();
create trigger comment_owners_hold_guard before delete on private.comment_owners for each row execute function private.guard_owner_deletion_for_hold();
create trigger reactions_format_invariant before insert or update of post_id, reaction on private.post_reactions for each row execute function private.enforce_reaction_compatibility();
create trigger votes_format_invariant before insert or update of post_id, choice on private.post_votes for each row execute function private.enforce_vote_compatibility();
create trigger reports_target_invariant before insert or update of target_type, post_id, comment_id, reason_code on private.reports for each row execute function private.enforce_report_target();
create trigger moderation_cases_target_invariant before insert or update of post_id, comment_id on private.moderation_cases for each row execute function private.enforce_moderation_case_target();
create trigger profiles_guard_delete before delete on app.public_profiles for each row execute function private.guard_profile_deletion();

create trigger username_history_immutable before update on private.username_history for each row execute function private.prevent_mutation();
create trigger quota_events_immutable before update on private.post_quota_events for each row execute function private.prevent_mutation();
create trigger moderation_actions_immutable before update on private.moderation_actions for each row execute function private.prevent_mutation();

create view api.public_profiles
with (security_barrier = true)
as
select
  p.profile_id,
  p.username,
  a.key as avatar_key,
  a.asset_path as avatar_asset_path,
  a.alt_label as avatar_alt_label
from app.public_profiles p
join private.accounts account on account.user_id = p.user_id and account.state = 'active'
left join app.avatar_catalog a on a.avatar_id = p.avatar_id
where p.is_discoverable;

create view api.public_topics
with (security_barrier = true)
as
select topic_id, slug, label, description, sort_order
from app.topics
where is_active;

create view api.public_posts
with (security_barrier = true)
as
select
  p.post_id,
  p.format::text as format,
  p.body,
  p.topic_id,
  t.slug as topic_slug,
  t.label as topic_label,
  p.identity_mode::text as identity_mode,
  case when p.identity_mode = 'attributed' then p.public_author_profile_id end as author_profile_id,
  case when p.identity_mode = 'attributed' then prof.username end as author_username,
  case when p.identity_mode = 'attributed' then av.key end as author_avatar_key,
  p.state::text as state,
  p.created_at,
  p.expires_at,
  m.media_id,
  m.detected_mime as media_mime,
  m.width as media_width,
  m.height as media_height,
  m.alt_text as media_alt_text
from app.posts p
left join app.topics t on t.topic_id = p.topic_id
left join app.public_profiles prof on prof.profile_id = p.public_author_profile_id
left join app.avatar_catalog av on av.avatar_id = prof.avatar_id
left join private.media_assets m on m.post_id = p.post_id and m.status = 'attached'
where app.is_post_public(p.post_id, p.state, p.expires_at, p.is_account_deleted_author);

create view api.public_comments
with (security_barrier = true)
as
select
  c.comment_id,
  c.post_id,
  c.parent_comment_id,
  case when not c.is_account_deleted_author then c.public_author_profile_id end as author_profile_id,
  case when c.is_account_deleted_author then 'Deleted user' else p.username end as author_username,
  case when c.state = 'tombstone' then '' else c.body end as body,
  c.state::text as state,
  c.created_at
from app.comments c
join app.posts post on post.post_id = c.post_id
left join app.public_profiles p on p.profile_id = c.public_author_profile_id
where app.is_comment_public(c.comment_id, c.state, c.is_account_deleted_author)
  and app.is_post_public(post.post_id, post.state, post.expires_at, post.is_account_deleted_author);

create view api.post_interaction_totals
with (security_barrier = true)
as
select
  r.post_id,
  'reaction'::text as interaction_type,
  r.reaction::text as selection,
  count(*)::bigint as selection_count,
  sum(count(*)) over (partition by r.post_id)::bigint as participant_count
from private.post_reactions r
join app.posts p on p.post_id = r.post_id
where app.is_post_public(p.post_id, p.state, p.expires_at, p.is_account_deleted_author)
group by r.post_id, r.reaction
union all
select
  v.post_id,
  'vote'::text as interaction_type,
  v.choice::text as selection,
  count(*)::bigint as selection_count,
  sum(count(*)) over (partition by v.post_id)::bigint as participant_count
from private.post_votes v
join app.posts p on p.post_id = v.post_id
where app.is_post_public(p.post_id, p.state, p.expires_at, p.is_account_deleted_author)
group by v.post_id, v.choice;

alter table app.avatar_catalog enable row level security;
alter table app.public_profiles enable row level security;
alter table app.topics enable row level security;
alter table app.posts enable row level security;
alter table app.comments enable row level security;

alter table private.accounts enable row level security;
alter table private.reserved_username_catalog enable row level security;
alter table private.username_claims enable row level security;
alter table private.username_history enable row level security;
alter table private.post_owners enable row level security;
alter table private.post_quota_events enable row level security;
alter table private.media_assets enable row level security;
alter table private.comment_owners enable row level security;
alter table private.post_reactions enable row level security;
alter table private.post_votes enable row level security;
alter table private.report_reason_catalog enable row level security;
alter table private.reports enable row level security;
alter table private.moderator_roles enable row level security;
alter table private.moderation_cases enable row level security;
alter table private.moderation_actions enable row level security;
alter table private.moderation_evidence enable row level security;
alter table private.appeals enable row level security;
alter table private.recommendation_signals enable row level security;
alter table private.feed_preferences enable row level security;
alter table private.idempotency_keys enable row level security;
alter table private.outbox_jobs enable row level security;

create policy avatars_public_read on app.avatar_catalog for select to anon, authenticated using (is_active);
create policy profiles_public_read on app.public_profiles for select to anon, authenticated using (app.is_profile_public(user_id, is_discoverable));
create policy topics_public_read on app.topics for select to anon, authenticated using (is_active);
create policy posts_public_read on app.posts for select to anon, authenticated using (
  app.is_post_public(post_id, state, expires_at, is_account_deleted_author)
);
create policy comments_public_read on app.comments for select to anon, authenticated using (
  app.is_comment_public(comment_id, state, is_account_deleted_author)
  and exists (
    select 1 from app.posts p
    where p.post_id = comments.post_id
      and app.is_post_public(p.post_id, p.state, p.expires_at, p.is_account_deleted_author)
  )
);

revoke all on schema app from public, anon, authenticated;
revoke all on schema private from public, anon, authenticated;
revoke all on schema api from public, anon, authenticated;
revoke all on all tables in schema app from public, anon, authenticated;
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all tables in schema api from public, anon, authenticated;
revoke all on all sequences in schema app from public, anon, authenticated;
revoke all on all sequences in schema private from public, anon, authenticated;
revoke all on all functions in schema app from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
revoke all on all functions in schema api from public, anon, authenticated;

alter default privileges in schema app revoke all on tables from public, anon, authenticated;
alter default privileges in schema private revoke all on tables from public, anon, authenticated;
alter default privileges in schema api revoke all on tables from public, anon, authenticated;
alter default privileges in schema app revoke execute on functions from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public, anon, authenticated;
alter default privileges in schema api revoke execute on functions from public, anon, authenticated;
alter default privileges in schema app revoke usage, select on sequences from public, anon, authenticated;
alter default privileges in schema private revoke usage, select on sequences from public, anon, authenticated;

grant usage on schema api to anon, authenticated;
grant execute on function app.is_post_public(uuid, app.post_state, timestamptz, boolean) to anon, authenticated;
grant execute on function app.is_comment_public(uuid, app.comment_state, boolean) to anon, authenticated;
grant execute on function app.is_profile_public(uuid, boolean) to anon, authenticated;
grant select on api.public_profiles to anon, authenticated;
grant select on api.public_topics to anon, authenticated;
grant select on api.public_posts to anon, authenticated;
grant select on api.public_comments to anon, authenticated;
grant select on api.post_interaction_totals to anon, authenticated;

comment on schema api is 'Allowlisted public API projections. Configure Supabase PostgREST to expose this schema only.';
comment on schema app is 'RLS-protected product records. No direct client grants.';
comment on schema private is 'Private ownership, moderation, signals, and operational records. Never expose through PostgREST.';
comment on table private.report_reason_catalog is 'Unseeded until report reasons receive product and policy approval.';
comment on column private.username_claims.reserved_until is 'Reservation duration remains an approval decision and is set by a future trusted workflow.';
comment on column private.accounts.deletion_execute_at is 'Recovery-window deadline remains an approval decision and is set by a future trusted workflow.';
comment on table private.appeals is 'Schema only; appeal eligibility and submission window remain policy decisions.';
comment on table private.recommendation_signals is 'Signals are private and must be purged after 90 days; guest signal collection requires privacy approval.';
comment on table private.moderation_actions is 'Append-only audit data; long-term retention requires legal/privacy approval.';

commit;
