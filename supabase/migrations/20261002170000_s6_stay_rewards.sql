-- S6: Stay Rewards on the server (F09, DECISIONS "Stay Rewards (F09)" and
-- "Design follow-ups" F09). Amounts are DECISIONS', not new ones:
--   * Member: a first stay through Hostelzy (a confirmed "Via Hostelzy" stay)
--     makes the tenant a Member and gives ₹100 off the next Hostelzy hostel's
--     first month. The next owner gives it at move-in; Hostelzy credits that
--     ₹100 on the owner's next invoice (owner_plans.credit). No cash moves.
--   * Referral: ₹100 each, to the friend and to the one who referred them,
--     after the friend's first month at a Hostelzy hostel.
-- Guardrails (Ideas chat, 2026-10-02):
--   * grants only from these server functions and triggers; the app never writes;
--   * an append-only ledger (who, what, why, source, when): no updates or deletes;
--   * each event is granted once (unique event key);
--   * no cash-out: a tenant's credit only comes off a Hostelzy move-in, and an
--     owner's credit only off a Hostelzy invoice;
--   * the team sees every entry and can reverse one (a reversal row).
-- Safe to run again.

alter table public.profiles add column if not exists referred_by text;
alter table public.profiles add column if not exists member_since timestamptz;

create table if not exists public.reward_ledger (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  kind text not null check (kind in ('member', 'referral_friend', 'referral_referrer', 'spend', 'owner_credit', 'reversal')),
  user_id text,                                   -- the tenant whose balance this is
  hostel_id uuid references public.hostels (id) on delete set null,   -- an owner credit
  amount int not null,                            -- + earned / credited, − spent / reversed
  reason text not null default '',
  source_stay uuid,
  source_user text,
  reverses uuid unique references public.reward_ledger (id),
  created_by text default public.uid(),
  created_at timestamptz not null default now()
);

alter table public.reward_ledger enable row level security;
drop policy if exists "read own rewards" on public.reward_ledger;
create policy "read own rewards" on public.reward_ledger for select
  using (user_id = public.uid() or (hostel_id is not null and public.is_staff(hostel_id)) or public.is_team());
-- No insert/update/delete policies: only the functions below write.

create or replace function public.ledger_append_only() returns trigger
language plpgsql set search_path = ''
as $$ begin raise exception 'the rewards ledger is append-only; reverse an entry instead'; end $$;
drop trigger if exists ledger_append_only on public.reward_ledger;
create trigger ledger_append_only before update or delete on public.reward_ledger
for each row execute function public.ledger_append_only();

-- Members and referral codes are still earned, not self-set: only these
-- functions (hz.rewards) and the team change them.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or current_setting('hz.rewards', true) = 'on' then return new; end if;
  if new.id <> old.id or new.member <> old.member or new.ref_code is distinct from old.ref_code or new.phone_verified <> old.phone_verified
     or new.referred_by is distinct from old.referred_by or new.member_since is distinct from old.member_since then
    raise exception 'not allowed';
  end if;
  return new;
end $$;

-- A tenant's reward balance (₹): earned minus spent and reversed.
create or replace function public.reward_balance(u text) returns int
language sql stable security definer set search_path = ''
as $$ select coalesce(sum(amount), 0)::int from public.reward_ledger where user_id = u $$;

-- Adds [amt] to the owner's next invoice credit.
create or replace function public.credit_owner(h uuid, amt int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.owner_plans (hostel_id, credit) values (h, greatest(amt, 0))
  on conflict (hostel_id) do update set credit = greatest(public.owner_plans.credit + amt, 0);
end $$;

-- A confirmed stay through Hostelzy: spend what the tenant has (₹100 off this
-- first month, credited to this owner), then make them a Member (₹100 for the
-- next stay) if this is their first.
create or replace function public.rewards_on_stay() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bal int;
begin
  if new.user_id is null or not new.confirmed or new.via <> 'hz' or (tg_op = 'UPDATE' and old.confirmed and old.via = 'hz') then
    return new;
  end if;
  perform set_config('hz.rewards', 'on', true);
  bal := public.reward_balance(new.user_id);
  if bal > 0 then
    insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, created_by)
    values ('spend:' || new.id, 'spend', new.user_id, -bal, 'Off the first month at a Hostelzy hostel', new.id, 'server')
    on conflict (event_key) do nothing;
    if found then
      insert into public.reward_ledger (event_key, kind, hostel_id, amount, reason, source_stay, source_user, created_by)
      values ('credit:' || new.id, 'owner_credit', new.hostel_id, bal, 'Member reward given at move-in', new.id, new.user_id, 'server');
      perform public.credit_owner(new.hostel_id, bal);
    end if;
  end if;
  insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, created_by)
  values ('member:' || new.user_id, 'member', new.user_id, 100, 'Member: first stay through Hostelzy', new.id, 'server')
  on conflict (event_key) do nothing;
  update public.profiles set member = true, member_since = coalesce(member_since, now()) where id = new.user_id and not member;
  perform set_config('hz.rewards', 'off', true);
  return new;
end $$;

drop trigger if exists rewards_on_stay on public.stays;
create trigger rewards_on_stay after insert or update of confirmed, via, user_id on public.stays
for each row execute function public.rewards_on_stay();

-- The caller's referral code ("ASHA-4K7Q"), made once.
create or replace function public.my_referral_code() returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; nm text; base text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select ref_code, name into c, nm from public.profiles where id = public.uid();
  if c is not null then return c; end if;
  if nm is null then raise exception 'add your name first'; end if;
  -- "ASHA-4K7Q": up to 5 letters of the first name.
  base := upper(regexp_replace(split_part(nm, ' ', 1), '[^A-Za-z]', '', 'g'));
  base := left(case when length(base) < 3 then rpad(base, 3, 'X') else base end, 5);
  loop
    c := base || '-';
    for i in 1..4 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.profiles where ref_code = c);
  end loop;
  perform set_config('hz.rewards', 'on', true);
  update public.profiles set ref_code = c where id = public.uid();
  perform set_config('hz.rewards', 'off', true);
  return c;
end $$;

-- A new tenant enters a friend's code, before their first stay. Returns the
-- friend's first name.
create or replace function public.use_referral_code(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare r record; me text := public.uid();
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select id, name into r from public.profiles where ref_code = upper(trim(p_code));
  if r.id is null then raise exception 'that code isn''t valid'; end if;
  if r.id = me then raise exception 'that''s your own code'; end if;
  if exists (select 1 from public.profiles where id = me and referred_by is not null) then raise exception 'you already used a code'; end if;
  if exists (select 1 from public.stays where user_id = me and confirmed) then raise exception 'codes are for your first stay'; end if;
  perform set_config('hz.rewards', 'on', true);
  update public.profiles set referred_by = r.id where id = me;
  perform set_config('hz.rewards', 'off', true);
  if not found then raise exception 'add your name first'; end if;
  return split_part(r.name, ' ', 1);
end $$;

-- Daily (pg_cron): referral rewards once the friend's first month at a
-- Hostelzy hostel is done. Returns how many referrals were rewarded.
create or replace function public.referral_sweep() returns int
language plpgsql security definer set search_path = ''
as $$
declare p record; n int := 0;
begin
  for p in
    select pr.id, pr.referred_by, min(s.id::text)::uuid as stay
    from public.profiles pr join public.stays s on s.user_id = pr.id
    where pr.referred_by is not null and s.confirmed and s.via = 'hz' and s.joined_on <= current_date - 30
      and not exists (select 1 from public.reward_ledger l where l.event_key = 'ref-friend:' || pr.id)
    group by pr.id, pr.referred_by
  loop
    insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, source_user, created_by) values
      ('ref-friend:' || p.id, 'referral_friend', p.id, 100, 'Referral: your first month is done', p.stay, p.referred_by, 'server'),
      ('ref-referrer:' || p.id, 'referral_referrer', p.referred_by, 100, 'Referral: your friend finished their first month', p.stay, p.id, 'server')
    on conflict (event_key) do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Team: reverse one entry (a new row with the opposite amount). An owner
-- credit also comes off the owner's next invoice credit.
create or replace function public.reverse_reward(p_id uuid, p_why text) returns void
language plpgsql security definer set search_path = ''
as $$
declare e record;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team reverses rewards'; end if;
  if length(trim(coalesce(p_why, ''))) < 3 then raise exception 'say why'; end if;
  select * into e from public.reward_ledger where id = p_id;
  if e.id is null then raise exception 'no such entry'; end if;
  if e.kind = 'reversal' then raise exception 'a reversal can''t be reversed'; end if;
  insert into public.reward_ledger (event_key, kind, user_id, hostel_id, amount, reason, source_stay, source_user, reverses)
  values ('reverse:' || e.id, 'reversal', e.user_id, e.hostel_id, -e.amount, 'Reversed: ' || trim(p_why), e.source_stay, e.source_user, e.id);
  if e.kind = 'owner_credit' then perform public.credit_owner(e.hostel_id, -e.amount); end if;
end $$;

revoke execute on function public.reward_balance(text), public.credit_owner(uuid, int), public.referral_sweep() from public, anon, authenticated;
revoke execute on function public.my_referral_code(), public.use_referral_code(text), public.reverse_reward(uuid, text) from public, anon;
grant execute on function public.my_referral_code(), public.use_referral_code(text), public.reverse_reward(uuid, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-referral-sweep', '20 3 * * *', 'select public.referral_sweep()');
  end if;
end $$;
