begin;

-- Preserve owner-context API projections while preventing inactive catalog
-- metadata from bypassing the base-table public-read policies.
create or replace view api.public_profiles
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
left join app.avatar_catalog a on a.avatar_id = p.avatar_id and a.is_active
where p.is_discoverable;

create or replace view api.public_posts
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
left join app.topics t on t.topic_id = p.topic_id and t.is_active
left join app.public_profiles prof on prof.profile_id = p.public_author_profile_id
left join app.avatar_catalog av on av.avatar_id = prof.avatar_id and av.is_active
left join private.media_assets m on m.post_id = p.post_id and m.status = 'attached'
where app.is_post_public(p.post_id, p.state, p.expires_at, p.is_account_deleted_author);

commit;
