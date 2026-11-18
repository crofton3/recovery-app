-- Treadmill runs: logged by hand from the treadmill's display, no GPS route or interval split.
-- Existing rows are GPS runs.
alter table public.runs add column if not exists source text not null default 'gps';
alter table public.runs drop constraint if exists runs_source_check;
alter table public.runs add constraint runs_source_check check (source in ('gps', 'treadmill'));
