-- S4: reviews from the app. The app asks "Is the room layout accurate?" with
-- Yes / Mostly / No, so the check allows Mostly too. Safe to run again.

alter table public.reviews drop constraint if exists reviews_layout_check;
alter table public.reviews add constraint reviews_layout_check check (layout in ('Yes', 'Mostly', 'No'));
