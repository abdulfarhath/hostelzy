-- F20 Reminders: a backup of the user's reminder settings on their profile,
-- so a new phone gets them back. The reminders themselves ring from the
-- phone; this is only the settings (water plan, my reminders, switches).
-- Users edit their own profile already ("edit own profile"); guard_profile
-- doesn't touch this column.

alter table public.profiles add column if not exists reminders jsonb;

alter table public.profiles drop constraint if exists reminders_small;
alter table public.profiles add constraint reminders_small
  check (reminders is null or (jsonb_typeof(reminders) = 'object' and octet_length(reminders::text) <= 16000));
