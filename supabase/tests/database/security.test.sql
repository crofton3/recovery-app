-- Row Level Security checks. The app talks to PostgREST with the anon key, so these are what stand
-- between a public key and the WHOOP tokens.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select is_empty(
  $$ select tablename from pg_tables where schemaname = 'public' and not rowsecurity $$,
  'every public table has RLS enabled'
);

select is_empty(
  $$ select policyname from pg_policies where schemaname = 'public' and tablename in ('whoop_tokens', 'whoop_oauth_state') $$,
  'token tables have no policies, so only the service role can touch them'
);

insert into public.whoop_tokens (access_token, refresh_token, expires_at) values ('a', 'r', now() + interval '1 hour');
insert into public.whoop_oauth_state (state) values ('abcd1234');

set local role anon;
select is_empty($$ select * from public.whoop_tokens $$, 'anon cannot read WHOOP tokens');
select is_empty($$ select * from public.whoop_oauth_state $$, 'anon cannot read OAuth states');
select throws_ok(
  $$ insert into public.whoop_tokens (id, access_token, refresh_token, expires_at) values (1, 'x', 'y', now()) $$,
  '42501', null, 'anon cannot write WHOOP tokens'
);

-- The app has no login yet, so anon must still be able to use its own tables.
select lives_ok(
  $$ insert into public.exercises (name, category, unit) values ('CI squat', 'lower', 'lb') $$,
  'anon can add an exercise'
);
select isnt_empty($$ select * from public.exercises where name = 'CI squat' $$, 'anon can read exercises');

reset role;
set local role authenticated;
select is_empty($$ select * from public.whoop_tokens $$, 'signed-in users cannot read WHOOP tokens either');

select * from finish();
rollback;
