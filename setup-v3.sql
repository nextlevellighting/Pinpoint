-- Pinpoint: turn on live updates
-- Run AFTER setup.sql and setup-v2.sql. Paste into Supabase → SQL Editor → New query → Run.
-- Safe to run more than once. Live updates follow the same privacy rules as everything else:
-- people only get changes for games they're allowed to see.

do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['games', 'friendships', 'leagues', 'league_members'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
