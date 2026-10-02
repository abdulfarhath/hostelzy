# F20 · Reminders (water, meals and my own tasks)

**Stage:** Spec ready · founder idea, 2026-10-02 · no design approval needed (standing approval).

## Problem
Students and working people in PGs forget simple things: drinking water, eating on time, paying
rent, laundry day. The founder wants **the Hostelzy app itself** to remind them, so the app is useful
every day, not only when searching for a hostel.

## Who
Everyone signed in (tenant, resident, owner). Works in the demo APK too.

## User stories
- **Water:** I turn on "Drink water", pick how often (every 20 / 30 / 45 / 60 / 90 / 120 min) and my
  awake hours (default 8 am – 10 pm). The phone reminds me: "💧 Time for a glass of water".
  I can tap **Done** (counts toward today's glasses) or **Snooze 10 min** from the notification.
- **My reminders:** I add my own: a name ("Take medicine"), a time, and repeat (once / every day /
  weekdays / pick days). Examples ready to add with one tap: Medicine, Lunch, Walk, Sleep on time,
  Call home.
- **Hostel reminders (residents, automatic, each can be turned off):**
  - Meal times from the hostel's food menu ("🍛 Lunch is served till 2 pm").
  - Rent due 3 days before and on the day (already in notifications, shown here too).
  - Laundry / cleaning day if the owner sets one (later).
- **Today card:** on the home screen, a small card: "💧 5 of 8 glasses · Next: Medicine at 9 pm".

## Rules
- **Runs on the phone** (local scheduled notifications), so it works offline, even every 20 minutes,
  and costs no server push. Reminders survive phone restarts.
- Uses the existing notification permission (F18/#48). If it's off, the screen says so and offers
  to turn it on.
- Quiet hours: nothing outside the awake hours the user chose.
- Saved on the phone; backed up to the user's profile when signed in so a new phone gets them back.
- No health claims. Wording stays friendly and short.
- Off by default; offered once after the first sign-in ("Want water reminders?") and in Me → Reminders.

## Screens
1. Me → **Reminders** list: Water (switch + "every 30 min, 8 am–10 pm"), My reminders, Hostel
   reminders.
2. Water settings sheet: interval chips, awake hours, daily goal (glasses).
3. Add reminder sheet: name, time, repeat, quick-pick examples.
4. Notification look: title, Done / Snooze actions.
5. Home "Today" card with glasses count and next reminder.
6. First-time offer card after sign-in.

## Build notes
- flutter_local_notifications (exact alarms where allowed; inexact fallback), timezone package,
  reschedule on boot and on app start. Android 13+ uses the existing POST_NOTIFICATIONS permission;
  ask for exact alarms only if needed and explain why.
- Flow test: turn water on → schedule count matches interval × hours; add/delete my reminder.
