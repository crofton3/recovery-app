-- Syncs WHOOP twice a day (13:00 and 23:00 UTC) by calling the whoop-sync edge function.
-- Replace <ANON_KEY> with the project's anon (publishable) key before running this file elsewhere.
create extension if not exists pg_net;
create extension if not exists pg_cron;

select cron.schedule(
  'whoop-sync-twice-daily',
  '0 13,23 * * *',
  $$ select net.http_post(
       url := 'https://pvnpwnphmmkfcivpftbm.supabase.co/functions/v1/whoop-sync',
       headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer <ANON_KEY>'),
       body := '{"days":3}'::jsonb
     ) $$
);
