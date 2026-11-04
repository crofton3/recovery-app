-- Pending WHOOP OAuth states (8 characters, valid 10 minutes). Service role only: RLS on, no policies.
create table if not exists public.whoop_oauth_state (
  state text primary key,
  created_at timestamptz not null default now()
);
alter table public.whoop_oauth_state enable row level security;
