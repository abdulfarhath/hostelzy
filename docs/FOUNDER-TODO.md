# Founder to-do (manual steps)

One step per line. Tick them off. Updated 2026-10-02 by the Ideas chat.

## Done
- [x] Supabase project created
- [x] Supabase database setup (SQL ran: "Success")
- [x] Firebase project + Android app + google-services.json
- [x] Firebase → Google sign-in enabled
- [x] Supabase → Third-party Auth → Firebase (`hostelzy`)
- [x] UPI ID `9059790014@axl`, support WhatsApp `9059790014`
- [x] Firebase SHA-1 / SHA-256 added, new google-services.json
- [x] GitHub secrets HZ_TEST_KEYSTORE_BASE64 / HZ_TEST_KEYSTORE_PASSWORD
- [x] Firebase key locked to the Android app
- [x] Supabase v2 SQL (firebase ids)
- [x] Push notifications tested end to end on a real phone, app open and closed (apk-46, 2026-10-02)
- [x] Team console setup (4b): console SQL, FIREBASE_SERVICE_ACCOUNT, Team member add, web app, farhath.me domain, browser key locked; delete-account SQL (4c) (founder, 2026-10-02)
- [x] SQL: B6 realtime, B7 photos, B7 console (checked 2026-10-02)
- [x] B5: pg_cron + pg_net, server rules SQL, FCM key, push secret, SUPABASE_ACCESS_TOKEN

## Now
1. **Test the F18 APK** (back button, stay logged in, own name/phone, map: my location + area picker,
   owner layout editing). Tell the Ideas chat ✅ / ❌ with screenshots.
2. ~~Google login in the demo APK~~ (done 2026-10-02; in the app via PR #38).
3. ~~Server rules (B5)~~ (done 2026-10-02).
4. ~~Push notifications (B5)~~ (done 2026-10-02; old leaked key aeaa9d98 deleted, new key in Supabase only).
4a. **Live updates (B6)**: Supabase → **SQL Editor** → **New query** → paste `supabase/migrations/20261002040000_b6_realtime.sql` (Copy raw file) → **Run** → "Success".
4e. **Hostel photos (B7)**: Supabase → SQL Editor → paste `supabase/migrations/20261002050000_b7_photos.sql` → **Run** → "Success".

5b. **Support email** (optional): the web pages offer WhatsApp only. Send the Build chat an email address if you want one listed too.

4b. **Team accounts and the team console (B7)**:
   - Supabase → SQL Editor → paste `supabase/migrations/20261002060000_b7_console.sql` → **Run** → "Success".
   - GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**: `FIREBASE_SERVICE_ACCOUNT` = the same Firebase .json text as in step 4 (generate a new key if you deleted it).
   - Sign in to the Hostelzy app once with your Google account.
   - GitHub repo → **Actions** → **Team member** → **Run workflow** → your Gmail address, **add** → Run. (Same steps to add or remove anyone on the team.)
   - In the app: **Me → Settings → Hostelzy team → Open team tools** (no passcode any more).
   - Firebase → ⚙ **Project settings** → **Your apps** → **Add app** → **Web** (`</>`) → nickname `team console` → **Register app**.
   - Copy the `firebaseConfig = { … }` block it shows and send it to the Build chat (it's public, not a secret).
   - Firebase → **Authentication** → **Settings** → **Authorized domains** → **Add domain** → `farhath.me`.
   - Then the console works at https://farhath.me/hostelzy/app/console/ (config added by Build 2026-10-02).
   - Google Cloud → APIs & Services → Credentials → the new **Browser key** (team console) → Application restrictions: **Websites** → add `https://farhath.me/*` and `https://hostelzy.firebaseapp.com/*` → API restrictions: **Identity Toolkit API** and **Token Service API** → Save.
4c. **Account deletion (C)**: Supabase → SQL Editor → paste `supabase/migrations/20261002070000_c_delete_account.sql` → **Run** → "Success".
4d. **Resident invites (C)**: Supabase → SQL Editor → paste `supabase/migrations/20261002080000_c_invites.sql` → **Run** → "Success".
4f. **Live sign-up list (C)** (after 4d): Supabase → SQL Editor → paste `supabase/migrations/20261002090000_c_signups_realtime.sql` → **Run** → "Success".
4g. **Holds and bookings on the server (S1)** (after 4f): Supabase → SQL Editor → paste `supabase/migrations/20261002100000_s1_holds.sql` → **Run** → "Success".
4h. **Resident list on the server (S2)** (after 4g): Supabase → SQL Editor → paste `supabase/migrations/20261002110000_s2_residents.sql` → **Run** → "Success".
4i. **Plan invoices in the app (S7)** (after 4h): Supabase → SQL Editor → paste `supabase/migrations/20261002120000_s7_invoices.sql` → **Run** → "Success".

## Soon (before real hostels)
5. ~~**Lock the Firebase key**~~ (done) (stops others using it):
   - console.cloud.google.com → project hostelzy → APIs & Services → Credentials
   - Click "Android key (auto created by Firebase)"
   - Application restrictions → Android apps → Add → package `app.hostelzy.hostelzy` + SHA-1 → Save
6. **Make the GitHub repo private** (founder: do it at the end, once the app is production-ready and before the first real users; hides the code):
   - Repo → Settings → scroll to Danger Zone → Change visibility → Private
   - Note: new APK downloads then need you logged in to GitHub.
7. **Domain** (`hostelzy.in`, about ₹800/year; Hostinger/GoDaddy accept UPI):
   - Buy it → tell the Ideas chat → Build sets up the privacy policy and delete-account pages.

## Later (launch)
8. **Play Console account** ($25 one time) at play.google.com/console. Needs an international card.
9. **Play upload key**: Build creates it; you store it as another GitHub secret + keep a backup offline.
10. **Map key**: Google Maps needs a card in Google Cloud (same card issue). If it still fails, we use
    MapTiler (free tier, no card) instead. Tell the Ideas chat which.
11. **SMS OTP login**: when a card works, Firebase → Upgrade to Blaze → Authentication → Phone → Enable.
12. ~~Push sending key~~: now step 4 above.

## Never
- Never share the Supabase **service_role** key or any private key file in chat or GitHub.
