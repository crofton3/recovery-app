-- Planned sets and reps per exercise for each scheduled workout.
-- Shape: [{"exercise_id": "<uuid>", "sets": 3, "reps": 10}, ...] in workout order.
alter table public.schedule_items add column if not exists plan jsonb not null default '[]'::jsonb;
