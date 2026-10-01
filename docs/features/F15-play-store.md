# F15 · Play Store launch

**Stage:** Design approved · 2026-10-02 (founder: "approve all")

## Problem
A professional release on Google Play, which requires a privacy policy, account deletion, honest
permission requests and a closed test.

## What it does (in the app)
- **Settings** (from Me / Manage): account (name, phone), theme, notifications, language (English
  for now), Privacy policy, Terms, Fair Play rules (owners), Help / contact on WhatsApp, app version.
- **Delete account:** explains what is deleted and what is kept (stay records an owner must keep,
  reviews shown as "Former resident"); confirm by OTP; done screen. Blocked while a hold or an
  unpaid owner plan is open, with the reason shown.
- **Permission explainers** before the system prompt: notifications (hold updates, rent reminders),
  location (hostels near you; optional), camera/photos (complaints, owner photos).
- **First-run consent:** one line on the phone screen: "By continuing you agree to the Terms and
  Privacy policy."
- **Force update / maintenance** screen for old app versions.

## Outside the app (founder + Build, later)
Google Play developer account (₹2,100 one time), domain + web pages for the privacy policy and
account deletion, signed app bundle, Data Safety form, closed test with 12 testers for 14 days.

## Open questions
None for design.

## Design
Canvas https://claude.ai/artifact/PBCza1yUDPzNVc2QHDrAN4. **Design approved by the founder on 2026-10-02.**

1. **Settings** (from Me / Manage). Account (name, phone), Appearance (Light / Dark / Phone setting), notification switches (hold updates, rent reminders, new free beds), Language (English), Privacy policy, Terms, Help on WhatsApp, Log out, Delete account (red), version line. Owners also get "Fair Play rules" in the same list.
2. **Delete account: what happens.** Two columns. Deleted: name and phone, saved hostels, holds and enquiries, rewards. Kept: stay records the hostel must keep, reviews as "Former resident", Fair Play case records. Optional reason; Continue / Keep my account.
3. **Delete: confirm or blocked** (tweak Can delete / Blocked · open hold / Blocked · unpaid owner plan). OTP confirm, or a red "You can't delete your account yet" with the reason and a button to fix it.
4. **Delete: done.** What was removed, and that signing up again starts fresh.
5. **Permission explainers** (tweak Notifications / Location / Camera and photos). Shown before the system prompt: why, three plain uses, Allow / Not now ("Pick an area instead" for location); "You can change this in Settings".
6. **Phone screen with consent line.** The existing "Your mobile number" screen plus "By continuing you agree to the Terms and Privacy policy." under Send code.
7. **Force update / maintenance** (tweak). "Update Hostelzy to continue" (version too old, Update on Google Play, versions shown) or "Back in a few minutes" (data safe, expected time, WhatsApp).
- Dark mode: board "1 in dark mode". Every board has a Dark tweak.

## Build
_Not started._
