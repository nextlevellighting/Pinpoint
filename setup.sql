-- Pinpoint database setup
-- Paste this whole file into Supabase → SQL Editor → New query, then click Run.
-- Safe to run more than once.

create table if not exists public.games (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  score       integer not null check (score between 0 and 300),
  played_on   date not null default current_date,
  note        text check (char_length(note) <= 80),
  frames      text[] check (frames is null or array_length(frames, 1) = 10),
  created_at  timestamptz not null default now()
);

create index if not exists games_user_played_idx on public.games (user_id, played_on, created_at);

-- Row Level Security: every bowler can only see and change their own games.
alter table public.games enable row level security;

drop policy if exists "Read own games"   on public.games;
drop policy if exists "Add own games"    on public.games;
drop policy if exists "Edit own games"   on public.games;
drop policy if exists "Delete own games" on public.games;

create policy "Read own games"   on public.games for select to authenticated using (user_id = auth.uid());
create policy "Add own games"    on public.games for insert to authenticated with check (user_id = auth.uid());
create policy "Edit own games"   on public.games for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Delete own games" on public.games for delete to authenticated using (user_id = auth.uid());
