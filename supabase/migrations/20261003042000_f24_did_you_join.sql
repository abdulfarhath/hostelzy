-- F24 item 14: "Did you join?" saved as a Fair Play signal.
-- After a hold ends the tenant answers Yes / Not yet / Still deciding.
--   join_answers   one answer per ended hold; the tenant may change it.
--       Written only through answer_joined(hold, answer), for the tenant's own
--       released or expired hold. Read by the Hostelzy team (console Fair Play,
--       next to the hostel's cases and reports) and by the tenant who wrote it
--       (so the app doesn't ask again). Owners and managers never see it.
-- Safe to run again.

create table if not exists public.join_answers (
  hold_id uuid primary key references public.holds (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  tenant_id text not null,
  answer text not null check (answer in ('yes', 'not_yet', 'deciding')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists join_answers_hostel on public.join_answers (hostel_id, updated_at desc);

alter table public.join_answers enable row level security;
drop policy if exists "team and own read join answers" on public.join_answers;
create policy "team and own read join answers" on public.join_answers for select
  using (public.is_team() or tenant_id = public.uid());
revoke all on table public.join_answers from public, anon, authenticated;
grant select on table public.join_answers to authenticated;

create or replace function public.answer_joined(p_hold uuid, p_answer text) returns void
language plpgsql security definer set search_path = ''
as $$
declare x record;
begin
  if p_answer not in ('yes', 'not_yet', 'deciding') then raise exception 'answer yes, not yet or still deciding'; end if;
  select h.hostel_id, h.tenant_id, h.status into x from public.holds h where h.id = p_hold;
  if not found or x.tenant_id is distinct from public.uid() then raise exception 'only the tenant of this hold answers'; end if;
  if x.status not in ('released', 'expired') then raise exception 'ask after the hold ends'; end if;
  insert into public.join_answers (hold_id, hostel_id, tenant_id, answer) values (p_hold, x.hostel_id, x.tenant_id, p_answer)
  on conflict (hold_id) do update set answer = excluded.answer, updated_at = now();
end $$;

revoke execute on function public.answer_joined(uuid, text) from public, anon;
grant execute on function public.answer_joined(uuid, text) to authenticated;

-- Account deletion detaches holds (tenant_id → 'deleted'); the answers follow.
create or replace function public.join_answers_follow() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.join_answers set tenant_id = new.tenant_id where hold_id = new.id;
  return new;
end $$;

drop trigger if exists join_answers_follow on public.holds;
create trigger join_answers_follow after update of tenant_id on public.holds
for each row when (new.tenant_id is distinct from old.tenant_id) execute function public.join_answers_follow();
revoke execute on function public.join_answers_follow() from public, anon, authenticated;
