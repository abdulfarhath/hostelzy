# Founder to-do (manual steps)

One step per line. Tick them off. Updated 2026-10-02 by the Ideas chat.

## Done
- [x] Supabase project created
- [x] Supabase database setup (SQL ran: "Success")
- [x] Firebase project + Android app + google-services.json
- [x] Firebase → Google sign-in enabled
- [x] Supabase → Third-party Auth → Firebase (`hostelzy`)
- [x] UPI ID `9059790014@axl`, support WhatsApp `9059790014`

## Now
1. **Build chat: send the 2 answers** (approve placeholder edit; signing key as a GitHub secret).
2. **GitHub secret** (Build gives you the value):
   - github.com/abdulfarhath/hostelzy → Settings → Secrets and variables → Actions
   - New repository secret → paste the name and value Build gives you → Add secret
   - Tell Build "done".
3. **Firebase fingerprints** (Ideas chat gives you SHA-1 and SHA-256):
   - Firebase → ⚙ Project settings → General → Your apps → Android
   - Add fingerprint → paste SHA-1 → Save
   - Add fingerprint → paste SHA-256 → Save
4. **Test the new APK**: install it, tap "Continue with Google", tell the Ideas chat what happens.

## Soon (before real hostels)
5. **Lock the Firebase key** (stops others using it):
   - console.cloud.google.com → project hostelzy → APIs & Services → Credentials
   - Click "Android key (auto created by Firebase)"
   - Application restrictions → Android apps → Add → package `app.hostelzy.hostelzy` + SHA-1 → Save
6. **Make the GitHub repo private** (hides the team passcode and code):
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
12. **Push sending key**: Firebase → ⚙ Project settings → Service accounts → Generate new private key
    → give it to Build **as a Supabase secret** (never in chat or GitHub). Build will show you where.

## Never
- Never share the Supabase **service_role** key or any private key file in chat or GitHub.
