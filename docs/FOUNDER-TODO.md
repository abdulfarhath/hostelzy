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
- [x] B5: pg_cron + pg_net, server rules SQL, FCM key, push secret, SUPABASE_ACCESS_TOKEN

## Now
1. **Test the F18 APK** (back button, stay logged in, own name/phone, map: my location + area picker,
   owner layout editing). Tell the Ideas chat ✅ / ❌ with screenshots.
2. ~~Google login in the demo APK~~ (done 2026-10-02; in the app via PR #38).
3. ~~Server rules (B5)~~ (done 2026-10-02).
4. ~~Push notifications (B5)~~ (done 2026-10-02; old leaked key aeaa9d98 deleted, new key in Supabase only).

## Soon (before real hostels)
5. ~~**Lock the Firebase key**~~ (done) (stops others using it):
   - console.cloud.google.com → project hostelzy → APIs & Services → Credentials
   - Click "Android key (auto created by Firebase)"
   - Application restrictions → Android apps → Add → package `app.hostelzy.hostelzy` + SHA-1 → Save
6. **Make the GitHub repo private** (founder: do it at the end, once the app is production-ready and before the first real users; hides the team passcode and code):
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
