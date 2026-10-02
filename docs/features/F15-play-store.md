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
**Shipped 2026-10-02** · branch `feature/f15-play-store` (Build chat).

- **Settings** (Me → Settings; board 1): name and phone, Appearance Light / Dark / **Phone setting** (follows the phone), notification switches (hold updates, rent reminders, new free beds), Language (English), Privacy policy and Terms (open the web pages), Fair Play rules (owners), Help on WhatsApp, Log out, Delete account, version line.
- **Delete account** (boards 2–4): what is deleted vs kept, optional reason → **blocked** with the reason while a hold is open ("Go to my hold") or an owner's plan is unpaid ("Open invoice") → confirm with the 6-digit code → "Your account is deleted". With no backend yet it clears the account's data on this phone; with F13 it deletes it on the server too. The web deletion link is shown (Google Play requires one).
- **Permission explainers** (board 5): notifications (from Settings), location (from the map's my-location button; "Pick an area instead" opens search), camera. Android's own prompt comes with the feature that needs it (push with F13, location and photos later); nothing is switched on behind the user's back, and the toast says so.
- **Consent line** on the phone screen (board 6): shipped with F17.
- **Update / maintenance** (board 7): `GateScreen`, triggered by `minSupportedBuild` / `maintenanceUntil` in `lib/app_config.dart` (from the backend later; never triggers today).
- **One config file** `lib/app_config.dart`: version, Privacy / Terms / delete-account URLs (PLACEHOLDER `hostelzy.in` until the domain is live), support WhatsApp number (PLACEHOLDER, empty), update / maintenance switches.
- Test: `Play Store: settings, delete account (blocked, code, done), permission explainer (F15)`.

**For the founder (outside the app):**
- **Package name:** `app.hostelzy.hostelzy`.
- **SHA-1 fingerprint** (for restricting a Google Maps / Firebase key): run `cd hostelzy/android && ./gradlew signingReport` (or `keytool -list -v -keystore <your-upload-keystore>.jks -alias <alias>`), and after the first upload copy the **App signing key** SHA-1 from Play Console → Setup → App integrity. Add both SHA-1s to the key.
- **Release signing:** `android/app/build.gradle.kts` still signs release builds with the debug key. Before the first Play upload: create an upload keystore, keep it safe (never in git), and switch `signingConfig` to it (Build can do this once you have the keystore; CI needs it as a secret).
- Still to do outside the app: Google Play developer account (₹2,100), the domain + privacy / terms / delete-account pages, the support WhatsApp number, Data Safety form, closed test with 12 testers for 14 days.
