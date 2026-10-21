-- Pinpoint upgrade: usernames, friends, leagues
-- Run AFTER setup.sql. Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run more than once.

-- ============ Usernames ============
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  created_at  timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "See usernames"      on public.profiles;
drop policy if exists "Create own profile" on public.profiles;
drop policy if exists "Update own profile" on public.profiles;
create policy "See usernames"      on public.profiles for select to authenticated using (true);
create policy "Create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "Update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ============ Friends ============
create table if not exists public.friendships (
  id          uuid primary key default gen_random_uuid(),
  requester   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  addressee   uuid not null references auth.users (id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  check (requester <> addressee)
);
create unique index if not exists friendships_pair_idx
  on public.friendships (least(requester, addressee), greatest(requester, addressee));
alter table public.friendships enable row level security;
drop policy if exists "See own friendships"    on public.friendships;
drop policy if exists "Send friend request"    on public.friendships;
drop policy if exists "Accept friend request"  on public.friendships;
drop policy if exists "Remove friendship"      on public.friendships;
create policy "See own friendships"   on public.friendships for select to authenticated using (auth.uid() in (requester, addressee));
create policy "Send friend request"   on public.friendships for insert to authenticated with check (requester = auth.uid() and status = 'pending');
create policy "Accept friend request" on public.friendships for update to authenticated using (addressee = auth.uid()) with check (addressee = auth.uid() and status = 'accepted');
create policy "Remove friendship"     on public.friendships for delete to authenticated using (auth.uid() in (requester, addressee));

-- ============ Leagues ============
create table if not exists public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 2 and 50),
  code        text not null unique default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)),
  owner       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);
create table if not exists public.league_members (
  league_id   uuid not null references public.leagues (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  primary key (league_id, user_id)
);

-- Helper checks (security definer so the rules don't loop back on themselves)
create or replace function public.is_league_member(l uuid) returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from league_members where league_id = l and user_id = auth.uid()) $$;

create or replace function public.are_friends(other uuid) returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from friendships where status = 'accepted'
     and ((requester = auth.uid() and addressee = other) or (addressee = auth.uid() and requester = other))) $$;

alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
drop policy if exists "See my leagues"       on public.leagues;
drop policy if exists "Owner edits league"   on public.leagues;
drop policy if exists "Owner deletes league" on public.leagues;
create policy "See my leagues"       on public.leagues for select to authenticated using (owner = auth.uid() or public.is_league_member(id));
create policy "Owner edits league"   on public.leagues for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
create policy "Owner deletes league" on public.leagues for delete to authenticated using (owner = auth.uid());

drop policy if exists "See league members" on public.league_members;
drop policy if exists "Leave league"       on public.league_members;
create policy "See league members" on public.league_members for select to authenticated using (public.is_league_member(league_id));
create policy "Leave league"       on public.league_members for delete to authenticated
  using (user_id = auth.uid() or exists (select 1 from public.leagues l where l.id = league_id and l.owner = auth.uid()));

-- Create a league (and join it) in one step
create or replace function public.create_league(p_name text) returns public.leagues
  language plpgsql security definer set search_path = public as
$$
declare lg public.leagues;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  insert into leagues (name, owner) values (trim(p_name), auth.uid()) returning * into lg;
  insert into league_members (league_id, user_id) values (lg.id, auth.uid());
  return lg;
end $$;

-- Join a league with its invite code
create or replace function public.join_league(p_code text) returns public.leagues
  language plpgsql security definer set search_path = public as
$$
declare lg public.leagues;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select * into lg from leagues where code = upper(trim(p_code));
  if lg.id is null then raise exception 'No league found with that code'; end if;
  insert into league_members (league_id, user_id) values (lg.id, auth.uid()) on conflict do nothing;
  return lg;
end $$;

revoke all on function public.create_league(text) from anon;
revoke all on function public.join_league(text)   from anon;
grant execute on function public.create_league(text) to authenticated;
grant execute on function public.join_league(text)   to authenticated;

-- ============ Games: league tag + sharing ============
alter table public.games add column if not exists league_id uuid references public.leagues (id) on delete set null;
create index if not exists games_league_idx on public.games (league_id, played_on);

drop policy if exists "Read own games" on public.games;
drop policy if exists "Read own, friend and league games" on public.games;
create policy "Read own, friend and league games" on public.games for select to authenticated
  using (user_id = auth.uid() or public.are_friends(user_id) or (league_id is not null and public.is_league_member(league_id)));

drop policy if exists "Add own games"  on public.games;
drop policy if exists "Edit own games" on public.games;
create policy "Add own games"  on public.games for insert to authenticated
  with check (user_id = auth.uid() and (league_id is null or public.is_league_member(league_id)));
create policy "Edit own games" on public.games for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and (league_id is null or public.is_league_member(league_id)));
