-- S7: owner-plan invoices in the app.
--   1. The owner sends a UTR (due/missing → checking) but can't touch a paid
--      invoice; only the team (or the server's jobs) confirms one.
--   2. Invoices update live (Realtime; RLS decides who hears what).
-- Safe to run again.

create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if old.status = 'paid' then raise exception 'this invoice is paid'; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invoices') then
    alter publication supabase_realtime add table public.invoices;
  end if;
end $$;
