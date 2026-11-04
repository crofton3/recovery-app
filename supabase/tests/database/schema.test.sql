-- Run with `supabase test db` after `supabase db start`. CI runs this on every PR.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

-- Every table the app uses exists.
select has_table('public', t, t || ' exists')
from unnest(array['user_settings','daily_logs','daily_status','checkins']) as t;

select has_table('public', 'schedule_items', 'schedule_items exists');
select col_not_null('public', 'schedule_items', 'plan', 'schedule_items.plan is not null');
select is(
  (select column_default from information_schema.columns
   where table_schema = 'public' and table_name = 'schedule_items' and column_name = 'plan'),
  '''[]''::jsonb',
  'schedule_items.plan defaults to an empty list'
);

select is(
  (select count(*)::int from pg_extension where extname in ('pg_cron', 'pg_net')),
  2,
  'pg_cron and pg_net are installed for the WHOOP sync job'
);

select ok(
  exists (select 1 from cron.job where jobname = 'whoop-sync-twice-daily'),
  'WHOOP sync cron job is scheduled'
);

select * from finish();
rollback;
