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
4j. **Reviews from the app (S4)** (after 4i): Supabase → SQL Editor → paste `supabase/migrations/20261002130000_s4_reviews.sql` → **Run** → "Success".
4k. **Fair Play from the app (S5)** (after 4j): Supabase → SQL Editor → paste `supabase/migrations/20261002140000_s5_fair_play.sql` → **Run** → "Success".
4l. **Managers (S8)** (after 4k): Supabase → SQL Editor → paste `supabase/migrations/20261002150000_s8_managers.sql` → **Run** → "Success".
4m. **Residents fix room layouts (F19)** (after 4l): Supabase → SQL Editor → paste `supabase/migrations/20261002160000_f19_layout_fixes.sql` → **Run** → "Success".

4n. **Demo APK sign-in** (likely cause of "Couldn't sign in" in the demo; the real APK works):
   - console.cloud.google.com → project hostelzy → APIs & Services → Credentials → "Android key (auto created by Firebase)".
   - Under Application restrictions → Android apps, the list has only `app.hostelzy.hostelzy`. **Add** `app.hostelzy.hostelzy.demo` with the same SHA-1 (`46:55:BE:52:35:50:49:2A:E0:A4:AF:CA:26:09:78:5F:08:BD:AA:24`) → Save.
   - The next APK's toast shows the real code (for example "firebase: … blocked") if it is still something else.

4o. **Stay Rewards on the server (S6)** (after 4l; run it after 4m if F19 is merged first, the order doesn't matter): Supabase → SQL Editor → paste `supabase/migrations/20261002170000_s6_stay_rewards.sql` → **Run** → "Success".

4p. **Reminders backup (F20)** (any time after 4a): Supabase → SQL Editor → paste `supabase/migrations/20261002180000_f20_reminders.sql` → **Run** → "Success". Until then reminders still work; they just stay on the phone.
4q. **Layout fix extras (F19)** (after 4m): Supabase → SQL Editor → paste `supabase/migrations/20261002190000_f19_extras.sql` → **Run** → "Success". It adds quick fixes, the private `fix-photos` bucket, repairs and muting. Until then, the app's quick fix and mute buttons say they couldn’t save.
4r. **Hold replies reach the tenant (F21)** (after 4a): Supabase → SQL Editor → paste `supabase/migrations/20261002200000_f21_hold_reply_push.sql` → **Run** → "Success". The tenant then gets a notification when the owner keeps or declines their free hold. Until then the hold still works; only that notification is missing.
4s. **Complaint photos (F21)** (after 4a): Supabase → SQL Editor → paste `supabase/migrations/20261002210000_f21_complaint_photo.sql` → **Run** → "Success". It adds a private `complaint-photos` bucket and a photo on each complaint. Until then, complaints with a photo say they couldn’t be sent; complaints without one work as before.
4t. **Check Telugu wording with a native speaker (F21)** (any time): the strings to translate are in `docs/i18n/te-review.md`; translations go into `hostelzy/assets/l10n/app_te.arb`. No machine translation goes into the app, so until someone writes and checks them the app stays in English. Once a native speaker has checked the file, set `"@@reviewed": true` and the language picker drops “beta”.
4u. **Floor amenities (F23)** (after 4q): Supabase → SQL Editor → paste `supabase/migrations/20261002220000_f23_amenities.sql` → **Run** → "Success". It adds the list of shared things on each floor and in rooms (fridge, washing machine, RO water, a geyser in the room washroom…), lets owners, managers and residents add or change them, tells the owner when a resident does, and keeps a log of who changed what. Until it runs, hostels still load in the new app, but the shared-things lists stay empty and adding one says it couldn’t save.
4v. **Food menu (F24 item 4)**: Supabase → SQL Editor → paste `supabase/migrations/20261002230000_food_menu.sql` → **Run** → "Success". It lets tenants see a live hostel's food menu on its page and saves residents' Good / Okay / Poor for breakfast (owners see only the counts, never names). Until it runs, owners can still save the menu and residents still see it, but tenants don't see the menu peek and rating breakfast says it couldn’t save.
4w. **Owner's number (F24 item 1)**: Supabase → SQL Editor → paste `supabase/migrations/20261002231000_f24_owner_phone.sql` → **Run** → "Success". After a tenant holds a bed or enquires, and for residents, the app gets the owner's real number: the phone the owner typed in About you, else the number the team noted at onboarding. Until it runs, those WhatsApp buttons open WhatsApp without a number filled in.
4x. **Onboard real hostels (F24 items 2 and 3)** (after 4w): Supabase → SQL Editor → paste `supabase/migrations/20261002232000_f24_onboard.sql` → **Run** → "Success". The team's Add hostel wizard then saves the hostel on Hostelzy as you go: rooms, rates, real photos, residents, and the owner's sign-in link on WhatsApp. Go live also starts the 30-day trial. Owners' room and floor changes are saved too. Until it runs, Add hostel in the real app says it couldn't save, and room changes don't stick.
4y. **Notice, moves and refunds (F24 item 5)** (after 4x): Supabase → SQL Editor → paste `supabase/migrations/20261002233000_f24_moves.sql` → **Run** → "Success". Residents' notice and "move to another bed" go to the owner, who accepts them in Today. "Moved out" frees the bed and opens the advance refund. The owner marks the refund with the UPI reference, and the former resident confirms it arrived. Until it runs, notice and move requests say they couldn't send, and owners use WhatsApp.
4z. **Real reply time and ranking (F24 item 6)**: Supabase → SQL Editor → paste `supabase/migrations/20261002233500_f24_values.sql` → **Run** → "Success". The server records when owners reply to enquiries and holds. Hostel pages then show "Usually replies in ~N min" once there are 3 replies, and the ranking uses real complaint, photo and layout counts. Until it runs, pages say "Replies through Hostelzy" and the ranking uses reviews only.
4zu. **Electricity by meter, Trusted tenant, case photos (F24 Wave 1)** (after 4s and 4y): Supabase → SQL Editor → paste `supabase/migrations/20261003020000_f24_wave1.sql` → **Run** → "Success". Owners type each room's meter in Rent › Electricity and residents see their share on their rent (and pay it with the rent). The server works out who is a Trusted tenant: owners see "Trusted tenant" on their hold requests, and for 1 hour after a bed turns free only Trusted tenants can hold it. Owners can add a photo to a Fair Play reply (private `case-photos` bucket). Until it runs, Electricity says it starts after the next server update and rent shows "Electricity · Not added yet"; nobody shows as Trusted, every free bed can be held by anyone, and a reply with a photo says it couldn't save (replies without one work). Laundry day needs no SQL: it is saved with the house rules.
4zk. **Room shapes and "Ask Hostelzy to draw it" (F24 item 11)**: Supabase → SQL Editor → paste `supabase/migrations/20261003010000_f24_shapes.sql` → **Run** → "Success". Layouts keep their room shape (L, T, U, angled corner, narrow end, alcove or custom), and the server checks every bed is inside the walls. Owners' requests to have a room drawn reach the team console's Layout help, and the team's drawing comes back to the owner to publish. Until it runs, owners can still draw any shape and publish it, but the shape shows as a rectangle after the app restarts; "Send request" says it couldn't send.
4zz1. **Working / Not working (F24 item 7)** (after 4z): Supabase → SQL Editor → paste `supabase/migrations/20261003030000_f24_item_working.sql` → **Run** → "Success". When an owner marks a fan, the AC or a window Not working, tenants see it on the room ("AC under repair. Complaint raised 3 Oct") and a complaint is raised for the hostel; Working again closes it. A geyser, fridge or other shared thing marked not working raises one too. Until it runs, the mark shows only on the owner's phone and says it couldn't save.
4zz2. **Hold for a walk-in (F24 item 8)** (after 4zz1): Supabase → SQL Editor → paste `supabase/migrations/20261003031000_f24_walk_in.sql` → **Run** → "Success". "Hold for a walk-in" then keeps the bed for 1 hour on Hostelzy: every tenant sees it held, and the server frees it after the hour (with pg_cron on, as in step 3). Until it runs, the hold is only on the owner's phone and says it couldn't save.
4zz3. **Notification switches and New free beds (F24 item 22)** (after 4zz2): Supabase → SQL Editor → paste `supabase/migrations/20261003032000_f24_notify_switches.sql` → **Run** → "Success". Settings → Notifications is then kept on each person's account: the server skips holds/bookings or rent notifications they switched off, and never notifies someone about their own action. "New free beds": when a bed turns free in an area a tenant searched, tenants with that switch on get one notification, at most one a day. The send-push function already checks the switches; it updates itself when this branch reaches `main`. Until it runs, every notification is sent as today and no free-bed alerts go out.
4zz4. **Team tracker and members (F24 item 29)** (after 4zz3): Supabase → SQL Editor → paste `supabase/migrations/20261003033000_f24_team.sql` → **Run** → "Success". Team mode's Onboarding tracker then lists every real hostel with its stage, and Team members lists the real team: each team account shows as Active once it opens team tools (adding someone to the team is still GitHub → Actions → Team member). Until it runs, the tracker and team list are empty in the real app.
4zr1. **Enquiries and reviews rules (F24 Wave 4a)** (after 4z): Supabase → SQL Editor → paste `supabase/migrations/20261003060000_f24_enquiries_reviews.sql` → **Run** → "Success". One open enquiry per tenant per bed (asking again reuses the HZ code), one review of each kind per stay, the 30-day review opens after 30 days of a confirmed stay, residents can change their review, owners reply once, "Report abuse" sends a review to the team console (Reported reviews → Hide / Keep), and a review that says the room layout is wrong flags that room for the owner. Old duplicate enquiries and reviews are kept, not deleted (older duplicate reviews are hidden). Until it runs, enquiries and reviews work as before, reports say they couldn't send, and the owner doesn't see the "layout is wrong" flag.

4zy1. **"Still N free beds?" saved (F24 item 9)**: Supabase → SQL Editor → paste `supabase/migrations/20261003040000_f24_confirm_beds.sql` → **Run** → "Success". The owner's "Yes, all free" and "All still correct" (layouts) are stored with the server's time, tenants' hostel pages say "N free beds · confirmed by the owner X days ago", and every morning at 10 the server reminds owners and managers who haven't confirmed their free beds for 3 days (and layouts after 3 months). Until it runs, "Yes, all free" still saves, but "All still correct" says it couldn't save and no reminders are sent.
4zy2. **"Your price is fixed" kept on the server (F24 item 13)**: Supabase → SQL Editor → paste `supabase/migrations/20261003041000_f24_locked_deal.sql` → **Run** → "Success". A booking with the advance stores the rent and deal perks of that moment; the tenant's booking page, the owner's resident list and bed sheet show them, and nobody can change them later. Until it runs, the perks show only on the phone that booked.
4zy3. **"Did you join?" answers (F24 item 14)**: Supabase → SQL Editor → paste `supabase/migrations/20261003042000_f24_did_you_join.sql` → **Run** → "Success". Tenants' Yes / Not yet / Still deciding after a hold ends is saved for the Hostelzy team only (console › Fair Play shows it per hostel; owners never see it). Until it runs, answering says it couldn't save and the card stays.
4zx1. **Owner-only areas, AC rooms, featured spot, paused deals and money reminders (F24 items 17, 19, 20, 21)** (after 4zu, 4zz4 and 4zy3): Supabase → SQL Editor → paste `supabase/migrations/20261003050000_f24_server_rules.sql` → **Run** → "Success". Managers can then no longer change rates or deals or see the Hostelzy plan, invoices or Fair Play checks; a room can't be made AC while its published layout has no AC unit; hostels with more than 80 beds get their featured spot at the top of Recommended; a hostel whose plan is 15+ days late shows walk-in prices only to tenants; owners get a notification for each new invoice and when the plan is 5 and 15 days late, and residents get "Rent due today" on their due day (9 am, honouring their Rent switch). Until it runs, the app already hides those rows from managers, but the server still lets them through, nothing is featured, deals never pause for tenants and none of these notifications go out.
4zf1. **Fair Play hardening (F24 item 18)** (after 4zy3 and 4zx1): Supabase → SQL Editor → paste `supabase/migrations/20261003080000_f24_fair_play.sql` → **Run** → "Success". The owner's Fair Play "I agree" is kept on the server (not asked again on a new phone); "Joined before Hostelzy" only before go-live (after it, the team only); strike 2 hides deals for 30 days, then they come back; strike 3 hides the hostel from tenants on the server and stops its plan; 3 fixes in 6 months = 1 warning; console › Fair Play shows the six signals, tenant reports (Open a case / No case · close) and lets the team attach the tenant's photo. Until it runs, the app works as before: strike 2 keeps deals hidden, strike 3 hides the hostel only in the app, and the console says reports and signals show after this step.

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

### Play Store and staging (F24 Wave C)
6a. **Play Store upload key** (👤 once, keep it forever; losing it means a new Play listing):
   - On your computer: `keytool -genkeypair -v -keystore hostelzy-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. Pick a strong password and keep the file and the password somewhere safe (not in the repo, not in chat).
   - `base64 -w0 hostelzy-upload.jks` → GitHub repo → **Settings** → **Secrets and variables** → **Actions** → New secret `HZ_UPLOAD_KEYSTORE_BASE64` = that text. Also add `HZ_UPLOAD_KEYSTORE_PASSWORD` (the password) and `HZ_UPLOAD_KEY_ALIAS` = `upload`.
   - Then **Actions** → **Play Store build** → Run workflow → production. It makes `app-release.aab` to upload in Play Console. Until the secret exists it stops with "No HZ_UPLOAD_KEYSTORE_BASE64 secret yet".
6b. **Staging backend** (optional, for trying changes without touching real data): make a second Supabase project (Mumbai), run every file in `supabase/migrations/` on it in order, then add the GitHub secrets `HZ_STAGING_SUPABASE_URL` and `HZ_STAGING_SUPABASE_ANON_KEY` (Project Settings → API; the anon key is public). **Play Store build** → staging then makes a build whose Settings says "STAGING".
6c. **Links open the app directly** (after 6a): Play Console → your app → **Setup** → **App signing** → copy the **SHA-256** of the app signing key. Put this file at `https://farhath.me/.well-known/assetlinks.json` (the root of your farhath.me site, not this repo): `[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":"app.hostelzy.hostelzy","sha256_cert_fingerprints":["<SHA-256>"]}}]`. Until then, tapping a hostelzy link asks "Open with" instead of opening the app straight away.
