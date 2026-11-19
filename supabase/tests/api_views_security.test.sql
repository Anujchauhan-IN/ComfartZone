begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, pg_catalog;
select * from no_plan();

-- Deterministic local fixtures; every change is rolled back.
insert into auth.users (id, email) values
  ('71111111-1111-4111-8111-111111111111', 'view-user-a@example.test'),
  ('72222222-2222-4222-8222-222222222222', 'view-user-b@example.test'),
  ('73333333-3333-4333-8333-333333333333', 'view-deleted-user@example.test');

insert into private.accounts (
  user_id, state, verified_email, deletion_mode, deletion_requested_at
) values
  ('71111111-1111-4111-8111-111111111111', 'active', true, null, null),
  ('72222222-2222-4222-8222-222222222222', 'active', true, null, null),
  ('73333333-3333-4333-8333-333333333333', 'deletion_pending', true, 'preserve_anonymously', statement_timestamp());

insert into app.avatar_catalog (
  avatar_id, key, asset_path, alt_label, is_active, sort_order
) values
  ('74444444-4444-4444-8444-444444444441', 'active-avatar', '/avatars/active.svg', 'Active avatar', true, 1),
  ('74444444-4444-4444-8444-444444444442', 'retired-avatar', '/avatars/retired.svg', 'Retired avatar', false, 2);

insert into app.public_profiles (
  profile_id, user_id, username, normalized_username, avatar_id
) values
  ('7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '71111111-1111-4111-8111-111111111111', 'View Alpha', 'view-alpha', '74444444-4444-4444-8444-444444444442'),
  ('7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', '72222222-2222-4222-8222-222222222222', 'View Beta', 'view-beta', '74444444-4444-4444-8444-444444444441'),
  ('7ccccccc-cccc-4ccc-8ccc-ccccccccccc3', '73333333-3333-4333-8333-333333333333', 'Deleted Author', 'deleted-author', null);

insert into app.topics (topic_id, slug, label, description, is_active, sort_order) values
  ('75555555-5555-4555-8555-555555555551', 'active-topic', 'Active Topic', 'Visible topic', true, 1),
  ('75555555-5555-4555-8555-555555555552', 'retired-topic', 'Retired Topic', 'Hidden topic', false, 2);

insert into app.posts (
  post_id, format, body, topic_id, identity_mode, public_author_profile_id,
  state, created_at, expires_at, expiry_action
) values
  ('71000000-0000-4000-8000-000000000001', 'regular', 'Attributed post with retired metadata', '75555555-5555-4555-8555-555555555552', 'attributed', '7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null),
  ('71000000-0000-4000-8000-000000000002', 'regular', 'Anonymous post', '75555555-5555-4555-8555-555555555551', 'anonymous', null, 'active', statement_timestamp(), null, null),
  ('72000000-0000-4000-8000-000000000003', 'regular', 'Attributed post with active metadata', '75555555-5555-4555-8555-555555555551', 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null),
  ('72000000-0000-4000-8000-000000000004', 'regular', 'Expiring post', null, 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp() - interval '24 hours' + interval '5 seconds', statement_timestamp() + interval '5 seconds', 'archive_private'),
  ('72000000-0000-4000-8000-000000000005', 'regular', 'Post entering deletion', null, 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null),
  ('72000000-0000-4000-8000-000000000006', 'confession', 'Post entering moderation removal', null, 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null),
  ('72000000-0000-4000-8000-000000000007', 'regular', 'Post for comment presentation', null, 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null),
  ('72000000-0000-4000-8000-000000000008', 'petty_court', 'Post for vote aggregation', null, 'attributed', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null);

-- Create the historical comment while its parent is still unexpired. Later
-- assertions run after the exact expiry boundary without disabling triggers.
insert into app.comments (
  comment_id, post_id, public_author_profile_id, body
) values (
  '73000000-0000-4000-8000-000000000008', '72000000-0000-4000-8000-000000000004',
  '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Historical comment on expired post'
);

insert into private.post_owners (post_id, owner_user_id) values
  ('71000000-0000-4000-8000-000000000001', '71111111-1111-4111-8111-111111111111'),
  ('71000000-0000-4000-8000-000000000002', '71111111-1111-4111-8111-111111111111'),
  ('72000000-0000-4000-8000-000000000003', '72222222-2222-4222-8222-222222222222'),
  ('72000000-0000-4000-8000-000000000004', '72222222-2222-4222-8222-222222222222'),
  ('72000000-0000-4000-8000-000000000005', '72222222-2222-4222-8222-222222222222'),
  ('72000000-0000-4000-8000-000000000006', '72222222-2222-4222-8222-222222222222'),
  ('72000000-0000-4000-8000-000000000007', '72222222-2222-4222-8222-222222222222'),
  ('72000000-0000-4000-8000-000000000008', '72222222-2222-4222-8222-222222222222');

insert into private.post_quota_events (post_id, owner_user_id)
select post_id, owner_user_id from private.post_owners
where post_id::text like '71000000-%' or post_id::text like '72000000-%';

insert into app.comments (
  comment_id, post_id, public_author_profile_id, body
) values
  ('73000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', '7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Visible attributed comment'),
  ('73000000-0000-4000-8000-000000000002', '72000000-0000-4000-8000-000000000005', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Comment on deletion target'),
  ('73000000-0000-4000-8000-000000000003', '72000000-0000-4000-8000-000000000006', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Comment on moderation target'),
  ('73000000-0000-4000-8000-000000000004', '72000000-0000-4000-8000-000000000007', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Comment becoming tombstone'),
  ('73000000-0000-4000-8000-000000000005', '72000000-0000-4000-8000-000000000007', '7ccccccc-cccc-4ccc-8ccc-ccccccccccc3', 'Comment from deleted account'),
  ('73000000-0000-4000-8000-000000000006', '72000000-0000-4000-8000-000000000007', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Comment becoming deleted'),
  ('73000000-0000-4000-8000-000000000007', '72000000-0000-4000-8000-000000000007', '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Comment becoming moderated');

insert into private.comment_owners (comment_id, owner_user_id) values
  ('73000000-0000-4000-8000-000000000001', '71111111-1111-4111-8111-111111111111'),
  ('73000000-0000-4000-8000-000000000002', '72222222-2222-4222-8222-222222222222'),
  ('73000000-0000-4000-8000-000000000003', '72222222-2222-4222-8222-222222222222'),
  ('73000000-0000-4000-8000-000000000004', '72222222-2222-4222-8222-222222222222'),
  ('73000000-0000-4000-8000-000000000005', '73333333-3333-4333-8333-333333333333'),
  ('73000000-0000-4000-8000-000000000006', '72222222-2222-4222-8222-222222222222'),
  ('73000000-0000-4000-8000-000000000007', '72222222-2222-4222-8222-222222222222'),
  ('73000000-0000-4000-8000-000000000008', '72222222-2222-4222-8222-222222222222');

set constraints all immediate;

update app.comments
set public_author_profile_id = null, is_account_deleted_author = true
where comment_id = '73000000-0000-4000-8000-000000000005';

insert into private.post_reactions (post_id, user_id, reaction) values
  ('72000000-0000-4000-8000-000000000003', '71111111-1111-4111-8111-111111111111', 'funny'),
  ('72000000-0000-4000-8000-000000000003', '72222222-2222-4222-8222-222222222222', 'love'),
  ('72000000-0000-4000-8000-000000000004', '72222222-2222-4222-8222-222222222222', 'funny'),
  ('72000000-0000-4000-8000-000000000005', '71111111-1111-4111-8111-111111111111', 'love'),
  ('72000000-0000-4000-8000-000000000006', '71111111-1111-4111-8111-111111111111', 'same');

insert into private.post_votes (post_id, user_id, choice) values
  ('72000000-0000-4000-8000-000000000008', '71111111-1111-4111-8111-111111111111', 'guilty'),
  ('72000000-0000-4000-8000-000000000008', '72222222-2222-4222-8222-222222222222', 'not_guilty');

-- API visibility uses statement_timestamp(), which advances between statements.
-- Wait only until this fixture's immutable expiry boundary has passed.
do $fixture$
declare
  target_expiry timestamptz;
begin
  select expires_at into strict target_expiry
  from app.posts
  where post_id = '72000000-0000-4000-8000-000000000004';

  perform pg_sleep_until(target_expiry + interval '10 milliseconds');
end
$fixture$;

-- Exact API surface and grants.
select set_eq(
  $$select c.relname::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'api' and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')$$,
  $$values ('post_interaction_totals'), ('public_comments'), ('public_posts'), ('public_profiles'), ('public_topics')$$,
  'api exposes exactly the five approved views'
);

select columns_are('api', 'public_profiles', array['profile_id', 'username', 'avatar_key', 'avatar_asset_path', 'avatar_alt_label']::name[], 'public_profiles has the approved output columns');
select columns_are('api', 'public_topics', array['topic_id', 'slug', 'label', 'description', 'sort_order']::name[], 'public_topics has the approved output columns');
select columns_are('api', 'public_posts', array['post_id', 'format', 'body', 'topic_id', 'topic_slug', 'topic_label', 'identity_mode', 'author_profile_id', 'author_username', 'author_avatar_key', 'state', 'created_at', 'expires_at', 'media_id', 'media_mime', 'media_width', 'media_height', 'media_alt_text']::name[], 'public_posts has the approved output columns');
select columns_are('api', 'public_comments', array['comment_id', 'post_id', 'parent_comment_id', 'author_profile_id', 'author_username', 'body', 'state', 'created_at']::name[], 'public_comments has the approved output columns');
select columns_are('api', 'post_interaction_totals', array['post_id', 'interaction_type', 'selection', 'selection_count', 'participant_count']::name[], 'post_interaction_totals has the approved output columns');

select set_eq(
  $$select role_name || ':' || c.relname
    from (values ('anon'), ('authenticated')) roles(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'api' and c.relkind = 'v'
      and has_table_privilege(role_name, c.oid, 'SELECT')$$,
  $$values
    ('anon:post_interaction_totals'), ('anon:public_comments'),
    ('anon:public_posts'), ('anon:public_profiles'), ('anon:public_topics'),
    ('authenticated:post_interaction_totals'), ('authenticated:public_comments'),
    ('authenticated:public_posts'), ('authenticated:public_profiles'), ('authenticated:public_topics')$$,
  'anon and authenticated receive SELECT on every API view'
);
select ok(
  not exists (
    select 1
    from (values ('anon'), ('authenticated')) roles(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'api' and c.relkind = 'v'
      and (
        has_table_privilege(role_name, c.oid, 'INSERT')
        or has_table_privilege(role_name, c.oid, 'UPDATE')
        or has_table_privilege(role_name, c.oid, 'DELETE')
        or has_table_privilege(role_name, c.oid, 'TRUNCATE')
        or has_table_privilege(role_name, c.oid, 'REFERENCES')
        or has_table_privilege(role_name, c.oid, 'TRIGGER')
      )
  ),
  'client roles have no non-SELECT privileges on API views'
);
select ok(
  not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    where n.nspname = 'api' and c.relkind = 'v'
      and acl.grantee in (
        (select oid from pg_roles where rolname = 'anon'),
        (select oid from pg_roles where rolname = 'authenticated')
      )
      and acl.is_grantable
  ),
  'client SELECT grants on API views cannot be re-granted'
);
select ok(
  not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    where n.nspname = 'api' and c.relkind = 'v' and acl.grantee = 0
  ),
  'PUBLIC receives no privileges on API views'
);

select ok(
  not exists (
    select 1
    from (values ('anon'), ('authenticated')) roles(role_name)
    cross join (values
      ('app.avatar_catalog'), ('app.public_profiles'), ('app.topics'), ('app.posts'), ('app.comments'),
      ('private.accounts'), ('private.media_assets'), ('private.post_owners'), ('private.comment_owners'),
      ('private.post_reactions'), ('private.post_votes')
    ) relations(relation_name)
    where has_table_privilege(role_name, relation_name, 'SELECT')
       or has_table_privilege(role_name, relation_name, 'INSERT')
       or has_table_privilege(role_name, relation_name, 'UPDATE')
       or has_table_privilege(role_name, relation_name, 'DELETE')
       or has_table_privilege(role_name, relation_name, 'TRUNCATE')
       or has_table_privilege(role_name, relation_name, 'REFERENCES')
       or has_table_privilege(role_name, relation_name, 'TRIGGER')
  ),
  'client roles have no direct privileges on API source tables'
);
select ok(not has_schema_privilege('anon', 'app', 'USAGE') and not has_schema_privilege('anon', 'private', 'USAGE'), 'anon has no app or private schema usage');
select ok(not has_schema_privilege('authenticated', 'app', 'USAGE') and not has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated has no app or private schema usage');
select ok(has_schema_privilege('anon', 'api', 'USAGE') and not has_schema_privilege('anon', 'api', 'CREATE'), 'anon has API usage without API create permission');
select ok(has_schema_privilege('authenticated', 'api', 'USAGE') and not has_schema_privilege('authenticated', 'api', 'CREATE'), 'authenticated has API usage without API create permission');
select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'api'), 0::bigint, 'api exposes no functions outside the approved views');

set local role anon;
select lives_ok(
  $$select
      (select count(*) from api.public_profiles),
      (select count(*) from api.public_topics),
      (select count(*) from api.public_posts),
      (select count(*) from api.public_comments),
      (select count(*) from api.post_interaction_totals)$$,
  'anon can execute all five owner-context API views'
);
reset role;

set local role authenticated;
select lives_ok(
  $$select
      (select count(*) from api.public_profiles),
      (select count(*) from api.public_topics),
      (select count(*) from api.public_posts),
      (select count(*) from api.public_comments),
      (select count(*) from api.post_interaction_totals)$$,
  'authenticated can execute all five owner-context API views'
);
reset role;

select ok(
  not exists (
    select 1
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'api' and c.relkind = 'v'
      and (
        not ('security_barrier=true' = any(coalesce(c.reloptions, array[]::text[])))
        or 'security_invoker=true' = any(coalesce(c.reloptions, array[]::text[]))
        or pg_get_userbyid(c.relowner) in ('anon', 'authenticated')
      )
  ),
  'all API views preserve owner context, security barriers, and non-client ownership'
);

-- Inactive catalog metadata falls back safely without hiding eligible content.
select is(
  (select row(avatar_key, avatar_asset_path, avatar_alt_label)::text
   from api.public_profiles where profile_id = '7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
  '(,,)'::text,
  'inactive profile avatars use the null default presentation'
);
select is(
  (select author_avatar_key from api.public_posts where post_id = '71000000-0000-4000-8000-000000000001'),
  null::text,
  'inactive post-author avatars use the null default presentation'
);
select is(
  (select row(topic_slug, topic_label)::text from api.public_posts where post_id = '71000000-0000-4000-8000-000000000001'),
  '(,)'::text,
  'inactive topic labels and slugs are hidden without hiding the post'
);
select is((select topic_id from api.public_posts where post_id = '71000000-0000-4000-8000-000000000001'), '75555555-5555-4555-8555-555555555552'::uuid, 'inactive topic identity remains attached to the eligible post');
select is((select avatar_key from api.public_profiles where profile_id = '7bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'), 'active-avatar', 'active profile avatars remain visible');
select is((select row(topic_slug, topic_label)::text from api.public_posts where post_id = '72000000-0000-4000-8000-000000000003'), '(active-topic,"Active Topic")'::text, 'active topic presentation remains visible');
select is((select count(*) from api.public_profiles where profile_id = '7ccccccc-cccc-4ccc-8ccc-ccccccccccc3'), 0::bigint, 'non-active account profiles are excluded from discovery');
select is(
  (select row(selection_count, participant_count)::text
   from api.post_interaction_totals
   where post_id = '72000000-0000-4000-8000-000000000003'
     and interaction_type = 'reaction' and selection = 'funny'),
  '(1,2)'::text,
  'reaction totals distinguish selection counts from total participants'
);
select set_eq(
  $$select selection || ':' || selection_count || ':' || participant_count
    from api.post_interaction_totals
    where post_id = '72000000-0000-4000-8000-000000000008' and interaction_type = 'vote'$$,
  $$values ('guilty:1:2'), ('not_guilty:1:2')$$,
  'vote totals expose both selections and the authoritative participant count'
);

-- Discovery controls do not rewrite attribution on existing attributed content.
update app.public_profiles set is_discoverable = false where profile_id = '7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
select is((select count(*) from api.public_profiles where profile_id = '7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'), 0::bigint, 'undiscoverable profiles are excluded from profile discovery');
select is(
  (select row(author_profile_id, author_username, author_avatar_key)::text
   from api.public_posts where post_id = '71000000-0000-4000-8000-000000000001'),
  '(7aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1,"View Alpha",)'::text,
  'existing attributed posts preserve identity for undiscoverable profiles'
);
select is(
  (select row(author_profile_id, author_username, author_avatar_key)::text
   from api.public_posts where post_id = '71000000-0000-4000-8000-000000000002'),
  '(,,)'::text,
  'anonymous posts remain unattributed regardless of profile discovery settings'
);

-- Tombstones and account-deleted authors use neutral public presentation.
update app.comments set state = 'tombstone', body = '' where comment_id = '73000000-0000-4000-8000-000000000004';
select is(
  (select row(body, state)::text from api.public_comments where comment_id = '73000000-0000-4000-8000-000000000004'),
  '("",tombstone)'::text,
  'tombstone comments expose an empty body and tombstone state'
);
select is(
  (select row(author_profile_id, author_username)::text from api.public_comments where comment_id = '73000000-0000-4000-8000-000000000005'),
  '(,"Deleted user")'::text,
  'account-deleted comments expose no profile ID and use Deleted user presentation'
);

-- Individual deleted and moderated comments disappear while their post remains public.
update app.comments set state = 'deleted', deleted_at = statement_timestamp() where comment_id = '73000000-0000-4000-8000-000000000006';
update app.comments set state = 'moderation_removed', moderated_at = statement_timestamp() where comment_id = '73000000-0000-4000-8000-000000000007';
select is((select count(*) from api.public_comments where comment_id = '73000000-0000-4000-8000-000000000006'), 0::bigint, 'deleted comments are excluded');
select is((select count(*) from api.public_comments where comment_id = '73000000-0000-4000-8000-000000000007'), 0::bigint, 'moderation-removed comments are excluded');

-- Expired, deleted, and moderation-removed posts suppress associated comments
-- and aggregate interactions.
select is((select count(*) from api.public_posts where post_id = '72000000-0000-4000-8000-000000000004'), 0::bigint, 'expired posts are excluded');
select is((select count(*) from api.public_comments where post_id = '72000000-0000-4000-8000-000000000004'), 0::bigint, 'comments on expired posts are excluded');
select is((select count(*) from api.post_interaction_totals where post_id = '72000000-0000-4000-8000-000000000004'), 0::bigint, 'interaction totals for expired posts are excluded');

update app.posts set state = 'deleted', deleted_at = statement_timestamp() where post_id = '72000000-0000-4000-8000-000000000005';
select is((select count(*) from api.public_posts where post_id = '72000000-0000-4000-8000-000000000005'), 0::bigint, 'deleted posts are excluded');
select is((select count(*) from api.public_comments where post_id = '72000000-0000-4000-8000-000000000005'), 0::bigint, 'comments on deleted posts are excluded');
select is((select count(*) from api.post_interaction_totals where post_id = '72000000-0000-4000-8000-000000000005'), 0::bigint, 'interaction totals for deleted posts are excluded');

update app.posts set state = 'moderation_removed', moderated_at = statement_timestamp() where post_id = '72000000-0000-4000-8000-000000000006';
select is((select count(*) from api.public_posts where post_id = '72000000-0000-4000-8000-000000000006'), 0::bigint, 'moderation-removed posts are excluded');
select is((select count(*) from api.public_comments where post_id = '72000000-0000-4000-8000-000000000006'), 0::bigint, 'comments on moderation-removed posts are excluded');
select is((select count(*) from api.post_interaction_totals where post_id = '72000000-0000-4000-8000-000000000006'), 0::bigint, 'interaction totals for moderation-removed posts are excluded');

select * from finish();
rollback;
