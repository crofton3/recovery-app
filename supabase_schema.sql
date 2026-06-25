-- Achilles Recovery Tracker — full schema.
-- Paste into Supabase SQL Editor and Run to set up a fresh project.

create table if not exists public.user_settings (
  id uuid primary key default gen_random_uuid(),
  surgery_date date,
  calorie_target integer default 2550,
  protein_target integer default 190,
  carbs_target integer default 285,
  fat_target integer default 75,
  water_target_oz integer default 110,
  created_at timestamptz default now()
);

create table if not exists public.daily_logs (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  item_name text not null,
  calories integer default 0,
  protein integer default 0,
  carbs integer default 0,
  fat integer default 0,
  created_at timestamptz default now()
);
create index if not exists daily_logs_date_idx on public.daily_logs (date);

create table if not exists public.daily_status (
  id uuid primary key default gen_random_uuid(),
  date date unique not null,
  water_oz integer default 0,
  collagen_taken boolean default false,
  meals_checked jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  body_weight numeric,
  waist numeric,
  energy integer,
  pt_recovery integer,
  hunger integer,
  sleep integer,
  swelling integer,
  notes text,
  created_at timestamptz default now()
);
create index if not exists checkins_date_idx on public.checkins (date);

-- Row Level Security
alter table public.user_settings enable row level security;
alter table public.daily_logs enable row level security;
alter table public.daily_status enable row level security;
alter table public.checkins enable row level security;

-- Single-user app (no auth yet): allow the anon + authenticated roles full access.
-- Replace these with auth.uid()-scoped policies when you add login.
create policy "anon_all_user_settings" on public.user_settings for all to anon using (true) with check (true);
create policy "anon_all_daily_logs"   on public.daily_logs   for all to anon using (true) with check (true);
create policy "anon_all_daily_status" on public.daily_status for all to anon using (true) with check (true);
create policy "anon_all_checkins"     on public.checkins     for all to anon using (true) with check (true);

create policy "auth_all_user_settings" on public.user_settings for all to authenticated using (true) with check (true);
create policy "auth_all_daily_logs"    on public.daily_logs    for all to authenticated using (true) with check (true);
create policy "auth_all_daily_status"  on public.daily_status  for all to authenticated using (true) with check (true);
create policy "auth_all_checkins"      on public.checkins      for all to authenticated using (true) with check (true);
