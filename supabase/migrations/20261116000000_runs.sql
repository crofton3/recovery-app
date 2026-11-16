-- GPS-tracked runs (return to run). One row per finished run, written by the iOS app.
-- The id comes from the phone so a retried save is an upsert, not a duplicate.
-- segments: [{"kind": "run" | "walk" | "cooldown", "meters": 482.8, "seconds": 186}, ...] in order.
-- route:    [[latitude, longitude], ...], thinned to a few hundred points.
create table if not exists public.runs (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  started_at timestamptz not null,
  duration_s integer not null,
  distance_m numeric not null,
  run_m numeric not null default 0,
  walk_m numeric not null default 0,
  run_s integer not null default 0,
  plan_run_m numeric,
  plan_walk_m numeric,
  plan_rounds integer,
  rounds_done integer not null default 0,
  pain integer check (pain between 0 and 10),
  notes text,
  segments jsonb not null default '[]'::jsonb,
  route jsonb not null default '[]'::jsonb,
  created_at timestamptz default now()
);
create index if not exists runs_started_at_idx on public.runs (started_at desc);

alter table public.runs enable row level security;

-- Single-user, no login yet (same pattern as the other tables).
create policy "anon_all_runs" on public.runs for all to anon using (true) with check (true);
create policy "auth_all_runs" on public.runs for all to authenticated using (true) with check (true);
