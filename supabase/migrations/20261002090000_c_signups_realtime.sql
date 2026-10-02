-- C: the owner's "Waiting for you" list (invite sign-ups) updates live too.
-- RLS still decides who hears each change. Safe to run again.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invite_signups') then
    alter publication supabase_realtime add table public.invite_signups;
  end if;
end $$;
