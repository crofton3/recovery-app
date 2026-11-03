-- Recovery tracker v2: training, Achilles rehab, WHOOP, reminders.
-- Single-user app. The injured side is the LEFT Achilles.

-- ---------- settings ----------
alter table public.user_settings
  add column if not exists rehab_phase integer default 3,
  add column if not exists reminder_time time default '18:30',
  add column if not exists timezone text default 'America/New_York',
  add column if not exists injured_side text default 'L' check (injured_side in ('L', 'R'));

-- ---------- training ----------
create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text not null check (category in ('lower', 'upper', 'rehab', 'cardio')),
  unit text not null default 'lb',
  created_at timestamptz default now()
);

create table if not exists public.schedule_items (
  id uuid primary key default gen_random_uuid(),
  weekday smallint not null check (weekday between 0 and 6), -- 0 = Sunday
  title text not null,
  exercise_ids uuid[] not null default '{}', -- ordered
  reminder_time time,
  created_at timestamptz default now()
);
create index if not exists schedule_items_weekday_idx on public.schedule_items (weekday);

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  title text not null,
  schedule_item_id uuid references public.schedule_items(id) on delete set null,
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz default now()
);
create index if not exists workout_sessions_date_idx on public.workout_sessions (date);

create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  set_no smallint not null,
  weight numeric,
  reps integer,
  rpe numeric,
  done boolean not null default false,
  created_at timestamptz default now()
);
create index if not exists workout_sets_session_idx on public.workout_sets (session_id);
create index if not exists workout_sets_exercise_idx on public.workout_sets (exercise_id);

-- ---------- Achilles ----------
create table if not exists public.rehab_milestones (
  id uuid primary key default gen_random_uuid(),
  phase smallint not null check (phase between 1 and 5),
  title text not null,
  target_week smallint,
  done_at date,
  created_at timestamptz default now()
);

create table if not exists public.achilles_daily (
  id uuid primary key default gen_random_uuid(),
  date date unique not null,
  pain smallint not null check (pain between 0 and 10),
  swelling smallint not null check (swelling between 0 and 10),
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.rom_measurements (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  metric text not null check (metric in ('dorsiflexion', 'plantarflexion_strength', 'single_leg_heel_raise', 'double_leg_heel_raise', 'calf_girth')),
  side text not null check (side in ('L', 'R')),
  value numeric not null,
  created_at timestamptz default now()
);
create index if not exists rom_measurements_date_idx on public.rom_measurements (date);

create table if not exists public.pt_sessions (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  duration_min integer,
  exercises text[] default '{}',
  therapist_notes text,
  created_at timestamptz default now()
);
create index if not exists pt_sessions_date_idx on public.pt_sessions (date);

-- ---------- WHOOP ----------
create table if not exists public.whoop_daily (
  id uuid primary key default gen_random_uuid(),
  date date unique not null,
  recovery_score numeric,
  hrv numeric,
  rhr numeric,
  sleep_performance numeric,
  sleep_hours numeric,
  strain numeric,
  kilojoules numeric,
  synced_at timestamptz default now()
);

-- Tokens: RLS on, no policies for anon/authenticated. Only the service role (edge functions) can read or write.
create table if not exists public.whoop_tokens (
  id integer primary key default 1 check (id = 1),
  access_token text not null,
  refresh_token text not null,
  expires_at timestamptz not null,
  updated_at timestamptz default now()
);

-- ---------- push (APNs) ----------
create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  device_token text unique not null,
  environment text not null default 'development' check (environment in ('development', 'production')),
  created_at timestamptz default now()
);

-- ---------- Row Level Security ----------
alter table public.exercises enable row level security;
alter table public.schedule_items enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;
alter table public.rehab_milestones enable row level security;
alter table public.achilles_daily enable row level security;
alter table public.rom_measurements enable row level security;
alter table public.pt_sessions enable row level security;
alter table public.whoop_daily enable row level security;
alter table public.push_devices enable row level security;
alter table public.whoop_tokens enable row level security;

-- Single-user, no login yet (same pattern as the existing tables). Swap for auth.uid() policies when you add sign-in.
do $$
declare t text;
begin
  foreach t in array array['exercises','schedule_items','workout_sessions','workout_sets','rehab_milestones','achilles_daily','rom_measurements','pt_sessions','whoop_daily','push_devices']
  loop
    execute format('create policy "anon_all_%1$s" on public.%1$I for all to anon using (true) with check (true)', t);
    execute format('create policy "auth_all_%1$s" on public.%1$I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- ---------- seed: starter milestones (placeholders from the mockups; edit to match your PT's plan, none marked done) ----------
insert into public.rehab_milestones (phase, title, target_week, done_at) values
  (2, 'Out of the boot', 6, null),
  (3, 'Walk without a limp', 7, null),
  (3, 'Double-leg heel raise x 10', 6, null),
  (3, 'Single-leg balance 30 s', 8, null),
  (3, 'Double-leg heel raise x 25', 10, null),
  (3, 'Single-leg heel raise x 10', 12, null),
  (4, 'Cleared to start jogging', 14, null);
