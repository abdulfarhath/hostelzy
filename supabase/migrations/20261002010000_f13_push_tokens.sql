-- Hostelzy F13 · push tokens (Firebase Cloud Messaging). One row per phone.
-- The app saves its token once phone login works; the send-push Edge
-- Function reads them with the service role (server side only).

create table public.push_tokens (
  token text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

-- Each user sees and manages only their own phones' tokens.
create policy "own tokens" on public.push_tokens for select using (user_id = auth.uid());
create policy "save token" on public.push_tokens for insert with check (user_id = auth.uid() and public.is_verified());
create policy "refresh token" on public.push_tokens for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "remove token" on public.push_tokens for delete using (user_id = auth.uid());

do $$
declare missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if missing is not null then
    raise exception 'Row Level Security is off on: %', missing;
  end if;
end $$;
