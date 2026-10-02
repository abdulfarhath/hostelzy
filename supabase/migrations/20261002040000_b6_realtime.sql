-- B6: Realtime for holds, enquiries, payments and complaints, so owner and
-- tenant phones stay in sync. Realtime checks each change against the same
-- RLS policies before sending it, so nobody hears about rows they can't read.
-- Safe to run again.

do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  foreach t in array array['holds', 'enquiries', 'payments', 'complaints'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
