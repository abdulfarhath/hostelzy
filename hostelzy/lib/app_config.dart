// F15: app-wide settings the founder fills in before launch. Keep keys and
// links here, never scattered in the code.

/// Shown in Settings. Keep in step with `version:` in pubspec.yaml.
const appVersion = '1.0.0', appBuild = 1;

/// Hostelzy's public web pages (repo `app/`, GitHub Pages). DECISIONS
/// 2026-10-02 "Web address for now": switching to hostelzy.in is this line.
const webBase = 'https://farhath.me/hostelzy/app';

/// Web pages required by Google Play.
const privacyUrl = '$webBase/privacy/';
const termsUrl = '$webBase/terms/';
const deleteAccountUrl = '$webBase/delete-account/';

/// Shareable links: an enquiry's HZ code, and a hostel's resident invite.
String enquiryLink(String hz) => '$webBase/r/?c=${Uri.encodeQueryComponent(hz)}';
String inviteLink(String code) => '$webBase/j/?c=${Uri.encodeQueryComponent(code)}';

/// A link as people read it: no https://.
String shortLink(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

/// Hostelzy's WhatsApp support number, 10 digits (the +91 is added when the
/// link opens). DECISIONS 2026-10-02 "Payments contact + login SMS".
const supportWhatsApp = '9059790014';

/// Hostelzy's own UPI ID: owners pay their plan invoices here (F10).
const hostelzyUpiId = '9059790014@axl';

/// Remote switches (from the backend, F13). Until then they never trigger in
/// the Play Store build: the oldest supported build, and maintenance mode.
const minSupportedBuild = 0;

/// TEMPORARY: unlocks the Hostelzy team tools (Settings → Hostelzy team) until
/// F13 adds real admin accounts. Change it before sharing builds widely.
const teamPasscode = '2580';
const maintenanceUntil = ''; // e.g. '6:30 pm'; empty = no maintenance

/// F13 backend: Supabase (Mumbai). The anon key is public by design: it can
/// only do what the Row Level Security rules in `supabase/migrations/` allow.
/// NEVER put the service_role key in the app or the repo. Override per build:
/// `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://oafiaczotlilomlvhphp.supabase.co');
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hZmlhY3pvdGxpbG9tbHZocGhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5MTk4NjMsImV4cCI6MjEwNjQ5NTg2M30.pG_zORLu3ww6vxVNl4aNNekNirwGAWVC0KTRYAipKYo',
);

/// Where the app's data comes from: `sample` (default: the built-in sample
/// hostels, works offline and in tests) or `supabase` (live hostels from the
/// database; `--dart-define=DATA=supabase`). Stays `sample` until real
/// hostels are in the database and phone login works (F13 part 2).
const dataSource = String.fromEnvironment('DATA', defaultValue: 'sample');

/// F13 login: Sign in with Google (Firebase Auth, free plan). SMS codes need
/// Firebase billing, so the phone/OTP screens stay off until then
/// (DECISIONS 2026-10-02 "Payments contact + login SMS").
const phoneOtpLogin = false;
