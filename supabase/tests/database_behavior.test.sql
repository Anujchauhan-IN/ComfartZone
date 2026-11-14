begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public, pg_catalog;
select * from no_plan();

-- Deterministic local-only identities. All fixture changes roll back at the end.
insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'db-user-a@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'db-user-b@example.test');

insert into private.accounts (user_id, verified_email) values
  ('11111111-1111-4111-8111-111111111111', true),
  ('22222222-2222-4222-8222-222222222222', true);

insert into app.public_profiles (profile_id, user_id, username, normalized_username) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111', 'User Alpha', 'user-alpha'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', '22222222-2222-4222-8222-222222222222', 'User Beta', 'user-beta');

insert into app.posts (
  post_id, format, body, identity_mode, public_author_profile_id,
  state, created_at, expires_at, expiry_action, locked_at
) values
  ('10000000-0000-4000-8000-000000000001', 'regular', 'Alpha regular post', 'attributed', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null, null),
  ('10000000-0000-4000-8000-000000000002', 'regular', 'Alpha anonymous post', 'anonymous', null, 'active', statement_timestamp(), null, null, null),
  ('10000000-0000-4000-8000-000000000003', 'confession', 'Alpha confession', 'attributed', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null, null),
  ('10000000-0000-4000-8000-000000000004', 'petty_court', 'Alpha petty court', 'attributed', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null, null),
  ('10000000-0000-4000-8000-000000000005', 'am_i_weird', 'Alpha weird poll', 'attributed', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null, null),
  ('10000000-0000-4000-8000-000000000006', 'hot_take', 'Alpha hot take', 'attributed', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active', statement_timestamp(), null, null, null),
  ('20000000-0000-4000-8000-000000000001', 'regular', 'Beta regular post', 'attributed', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp(), null, null, null),
  ('20000000-0000-4000-8000-000000000002', 'regular', 'Beta expired post', 'attributed', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'active', statement_timestamp() - interval '25 hours', statement_timestamp() - interval '1 hour', 'archive_private', null),
  ('20000000-0000-4000-8000-000000000003', 'regular', 'Beta locked post', 'attributed', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'locked', statement_timestamp(), null, null, statement_timestamp());

insert into private.post_owners (post_id, owner_user_id)
select post_id,
  case when post_id::text like '10000000-%'
    then '11111111-1111-4111-8111-111111111111'::uuid
    else '22222222-2222-4222-8222-222222222222'::uuid
  end
from app.posts
where post_id::text like '10000000-%' or post_id::text like '20000000-%';

insert into private.post_quota_events (post_id, owner_user_id, created_at)
select post_id, owner_user_id, statement_timestamp()
from private.post_owners
where post_id::text like '10000000-%' or post_id::text like '20000000-%';

insert into app.comments (comment_id, post_id, parent_comment_id, public_author_profile_id, body) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', null, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Alpha root comment'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Beta reply'),
  ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', null, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Beta root comment');

insert into private.comment_owners (comment_id, owner_user_id) values
  ('30000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111'),
  ('30000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222'),
  ('30000000-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222');

set constraints all immediate;

-- Simulated clients can read the same eligible public projection, but neither
-- identity can inspect private ownership mappings.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select is((select count(*) from api.public_posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'user A can read all eligible fixture posts');
select throws_ok('select * from private.post_owners', '42501', null, 'user A cannot read private post ownership');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
select is((select count(*) from api.public_posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'user B can read the same eligible fixture posts');
select throws_ok('select * from private.post_owners', '42501', null, 'user B cannot read private post ownership');
reset role;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from api.public_posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'unauthenticated readers can read eligible fixture posts');
select throws_ok('select * from private.post_owners', '42501', null, 'unauthenticated readers cannot inspect ownership');
select throws_ok($$insert into app.posts (body) values ('forbidden')$$, '42501', null, 'unauthenticated readers cannot create posts directly');
reset role;

select ok(has_schema_privilege('authenticated', 'api', 'USAGE'), 'authenticated has API schema usage');
select ok(not has_schema_privilege('authenticated', 'app', 'USAGE'), 'authenticated has no app schema usage');
select ok(not has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated has no private schema usage');
select ok(has_table_privilege('anon', 'api.public_posts', 'SELECT'), 'anon can select the public post view');
select ok(not has_table_privilege('authenticated', 'app.posts', 'INSERT'), 'authenticated cannot insert base posts');
select ok(not has_table_privilege('authenticated', 'app.comments', 'UPDATE'), 'authenticated cannot edit base comments');
select ok(not has_table_privilege('authenticated', 'private.post_reactions', 'INSERT'), 'authenticated cannot bypass reaction APIs');

-- Exercise RLS itself with transaction-local test grants. The grants are
-- revoked below and the whole test transaction is rolled back.
grant usage on schema app, private to anon, authenticated;
grant select on app.posts, private.post_owners to anon, authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
select is((select count(*) from app.posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'RLS lets user A read eligible base posts');
select is((select count(*) from private.post_owners), 0::bigint, 'RLS hides all ownership mappings from user A');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);
select is((select count(*) from app.posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'RLS lets user B read eligible base posts');
select is((select count(*) from private.post_owners), 0::bigint, 'RLS hides all ownership mappings from user B');
reset role;

set local role anon;
select is((select count(*) from app.posts where post_id::text like '10000000-%' or post_id::text like '20000000-%'), 8::bigint, 'RLS lets anon read eligible base posts');
select is((select count(*) from private.post_owners), 0::bigint, 'RLS hides all ownership mappings from anon');
reset role;

revoke select on app.posts, private.post_owners from anon, authenticated;
revoke usage on schema app, private from anon, authenticated;

select is(
  (select row(author_profile_id, author_username, author_avatar_key)::text
   from api.public_posts where post_id = '10000000-0000-4000-8000-000000000002'),
  '(,,)'::text,
  'anonymous public posts reveal no profile or avatar attribution'
);
select hasnt_column('api', 'public_posts', 'owner_user_id', 'public posts never expose owner user IDs');
select hasnt_column('api', 'public_comments', 'owner_user_id', 'public comments never expose owner user IDs');

-- Restricting an account removes its profile and content from public views.
update private.accounts
set state = 'restricted', restricted_until = statement_timestamp() + interval '1 hour', restriction_reason_code = 'test'
where user_id = '11111111-1111-4111-8111-111111111111';
select is((select count(*) from api.public_posts where post_id::text like '10000000-%'), 0::bigint, 'restricted owner posts are hidden');
select is((select count(*) from api.public_profiles where profile_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'), 0::bigint, 'restricted profiles are hidden');
update private.accounts
set state = 'active', restricted_until = null, restriction_reason_code = null
where user_id = '11111111-1111-4111-8111-111111111111';

-- Published post and comment content is immutable; tombstoning is the one
-- permitted comment-body transition.
select throws_ok($$update app.posts set body = 'edited' where post_id = '10000000-0000-4000-8000-000000000001'$$, '55000', null, 'published post bodies are immutable');
select throws_ok($$update app.posts set format = 'confession' where post_id = '10000000-0000-4000-8000-000000000001'$$, '55000', null, 'published post formats are immutable');
select throws_ok($$update app.posts set expires_at = statement_timestamp() + interval '24 hours', expiry_action = 'archive_private' where post_id = '10000000-0000-4000-8000-000000000001'$$, '55000', null, 'published post expiry timestamps are immutable');
select throws_ok($$update app.comments set body = 'edited' where comment_id = '30000000-0000-4000-8000-000000000001'$$, '55000', null, 'published comment bodies are immutable');
select throws_ok($$update app.comments set parent_comment_id = null where comment_id = '30000000-0000-4000-8000-000000000002'$$, '55000', null, 'comment thread structure is immutable');

-- Thread depth and post-state constraints.
select is((select count(*) from app.comments where post_id = '10000000-0000-4000-8000-000000000001'), 2::bigint, 'a root comment and one reply level are permitted');
select throws_ok(
  $$insert into app.comments (post_id, parent_comment_id, public_author_profile_id, body) values ('10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'too deep')$$,
  '23514', null, 'reply-to-reply nesting is rejected'
);
select throws_ok(
  $$insert into app.comments (post_id, parent_comment_id, public_author_profile_id, body) values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'cross post')$$,
  '23514', null, 'cross-post parent comments are rejected'
);
select throws_ok(
  $$insert into app.comments (post_id, public_author_profile_id, body) values ('20000000-0000-4000-8000-000000000003', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'locked reply')$$,
  '23514', null, 'locked posts reject new comments'
);
select throws_ok(
  $$insert into app.comments (post_id, public_author_profile_id, body) values ('20000000-0000-4000-8000-000000000002', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'expired reply')$$,
  '23514', null, 'expired posts reject new comments'
);
select lives_ok(
  $$update app.comments set state = 'tombstone', body = '' where comment_id = '30000000-0000-4000-8000-000000000001'$$,
  'root comments can become neutral tombstones'
);
select throws_ok(
  $$insert into app.comments (post_id, parent_comment_id, public_author_profile_id, body) values ('10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'reply to tombstone')$$,
  '23514', null, 'inactive parent comments reject replies'
);

-- Reactions and votes enforce one selection per user and format compatibility.
select lives_ok($$insert into private.post_reactions (post_id, user_id, reaction) values ('10000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'funny')$$, 'regular posts accept regular reactions');
select lives_ok($$update private.post_reactions set reaction = 'love' where post_id = '10000000-0000-4000-8000-000000000001' and user_id = '11111111-1111-4111-8111-111111111111'$$, 'a user can switch an existing reaction');
select throws_ok($$insert into private.post_reactions (post_id, user_id, reaction) values ('10000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'annoying')$$, '23505', null, 'duplicate reactions for one user and post are rejected');
select throws_ok($$insert into private.post_reactions (post_id, user_id, reaction) values ('10000000-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222', 'funny')$$, '23514', null, 'confessions reject regular-only reactions');
select lives_ok($$insert into private.post_reactions (post_id, user_id, reaction) values ('10000000-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222', 'same')$$, 'confessions accept confession reactions');
select throws_ok($$insert into private.post_reactions (post_id, user_id, reaction) values ('10000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'funny')$$, '23514', null, 'poll posts reject reactions');

select lives_ok($$insert into private.post_votes (post_id, user_id, choice) values ('10000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'guilty')$$, 'petty court accepts its valid vote choices');
select lives_ok($$update private.post_votes set choice = 'not_guilty' where post_id = '10000000-0000-4000-8000-000000000004' and user_id = '11111111-1111-4111-8111-111111111111'$$, 'a user can switch an existing vote');
select throws_ok($$insert into private.post_votes (post_id, user_id, choice) values ('10000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'agree')$$, '23514', null, 'petty court rejects another poll format choice');
select throws_ok($$insert into private.post_votes (post_id, user_id, choice) values ('10000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'agree')$$, '23514', null, 'regular posts reject votes');
select throws_ok($$insert into private.post_votes (post_id, user_id, choice) values ('10000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'guilty')$$, '23505', null, 'duplicate votes for one user and post are rejected');
select is((select participant_count from api.post_interaction_totals where post_id = '10000000-0000-4000-8000-000000000004' and selection = 'not_guilty'), 1::bigint, 'public vote totals expose authoritative aggregate counts');
select hasnt_column('api', 'post_interaction_totals', 'user_id', 'interaction totals never expose participant IDs');

-- Quota event records are immutable, but rolling-limit enforcement awaits the
-- trusted create_post RPC and remains a release blocker.
select throws_ok($$update private.post_quota_events set created_at = statement_timestamp() where post_id = '10000000-0000-4000-8000-000000000001'$$, '55000', null, 'post quota events are append-only');
select todo_start('RELEASE BLOCKER: create_post must atomically enforce three posts per rolling 24 hours');
select ok(
  (select count(*) <= 3 from private.post_quota_events where owner_user_id = '11111111-1111-4111-8111-111111111111' and created_at > statement_timestamp() - interval '24 hours'),
  'a fourth post in a rolling 24-hour window is rejected'
);
select todo_end();

-- Expiry and lifecycle states remove content immediately from public reads.
select throws_ok(
  $$insert into app.posts (body, identity_mode, public_author_profile_id, created_at, expires_at, expiry_action) values ('invalid expiry', 'attributed', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', statement_timestamp(), statement_timestamp() + interval '23 hours', 'archive_private')$$,
  '23514', null, 'post expiry must be exactly 24 hours after creation'
);
select is((select count(*) from api.public_posts where post_id = '20000000-0000-4000-8000-000000000002'), 0::bigint, 'expired posts are hidden before worker cleanup');
select lives_ok($$update app.posts set state = 'archived', archived_at = statement_timestamp() where post_id = '20000000-0000-4000-8000-000000000001'$$, 'posts can enter the archived lifecycle state');
select is((select count(*) from api.public_posts where post_id = '20000000-0000-4000-8000-000000000001'), 0::bigint, 'archived posts are not public');
select lives_ok($$update app.posts set state = 'deletion_pending' where post_id = '10000000-0000-4000-8000-000000000006'$$, 'posts can enter deletion pending');
select is((select count(*) from api.public_posts where post_id = '10000000-0000-4000-8000-000000000006'), 0::bigint, 'deletion-pending posts are not public');

insert into private.moderation_cases (
  case_id, category, post_id, legal_hold, legal_hold_reason, legal_hold_applied_at
) values (
  '40000000-0000-4000-8000-000000000001', 'ownership-retention',
  '10000000-0000-4000-8000-000000000002', true, 'test legal hold', statement_timestamp()
);
select throws_ok(
  $$delete from private.post_owners where post_id = '10000000-0000-4000-8000-000000000002'$$,
  '55000', null, 'legal holds prevent anonymous post ownership removal'
);

-- SECURITY DEFINER helpers must use fixed search paths and remain unreachable
-- to client roles except through the allowlisted API views and RLS policies.
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef and n.nspname in ('app', 'private')
      and not exists (
        select 1 from unnest(coalesce(p.proconfig, array[]::text[])) setting
        where setting like 'search_path=pg_catalog%'
          and setting not like '%public%'
          and setting not like '%$user%'
      )
  ),
  'all application SECURITY DEFINER functions use a pg_catalog-first fixed search_path without public or $user'
);
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'EXECUTE')
  ),
  'anon cannot execute private functions'
);
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  'authenticated users cannot execute private functions'
);
select set_eq(
  $$select p.oid::regprocedure::text
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.prosecdef
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')$$,
  $$values
    ('app.is_comment_public(uuid,app.comment_state,boolean)'),
    ('app.is_post_public(uuid,app.post_state,timestamp with time zone,boolean)'),
    ('app.is_profile_public(uuid,boolean)')$$,
  'only the three named public-eligibility SECURITY DEFINER helpers grant client execute'
);
select ok(
  not exists (
    select 1 from pg_proc p
    where p.prosecdef and pg_get_userbyid(p.proowner) in ('anon', 'authenticated')
  ),
  'client roles own no SECURITY DEFINER functions'
);
set local role authenticated;
select throws_ok(
  $$select app.is_post_public('10000000-0000-4000-8000-000000000002', 'active', null, false)$$,
  '42501', null, 'clients cannot directly probe ownership through eligibility helpers'
);
reset role;

select todo_start('RELEASE BLOCKER: trusted SECURITY DEFINER write RPCs are not implemented');
select ok(
  exists (select 1 from pg_proc where proname = 'create_post' and prosecdef),
  'a trusted create_post RPC derives identity and enforces authorization'
);
select todo_end();

select * from finish();
rollback;
