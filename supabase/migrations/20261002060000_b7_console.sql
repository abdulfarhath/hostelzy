-- B7: data only the Hostelzy team console uses. Where each hostel is in
-- onboarding, and the owner's phone and visit time (private: the public
-- hostels table never shows them). Safe to run again.

create table if not exists public.hostel_leads (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  owner_phone text not null default '',
  visit_on timestamptz,
  stage text not null default 'lead' check (stage in ('lead', 'visited', 'signed_up', 'data_complete')),
  next_step text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.hostel_leads enable row level security;

drop policy if exists "team only" on public.hostel_leads;
create policy "team only" on public.hostel_leads for all using (public.is_team()) with check (public.is_team());
