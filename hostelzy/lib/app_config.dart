// F15: app-wide settings the founder fills in before launch. Keep keys and
// links here, never scattered in the code.

/// Shown in Settings. Keep in step with `version:` in pubspec.yaml.
const appVersion = '1.0.0', appBuild = 1;

/// Web pages required by Google Play (needs the domain, F15 outside the app).
/// PLACEHOLDER until the pages are live.
const privacyUrl = 'https://hostelzy.in/privacy';
const termsUrl = 'https://hostelzy.in/terms';
const deleteAccountUrl = 'https://hostelzy.in/delete-account';

/// Hostelzy's WhatsApp support number (10 digits). PLACEHOLDER: empty until
/// the founder sets it.
const supportWhatsApp = '';

/// Remote switches (from the backend, F13). Until then they never trigger in
/// the Play Store build: the oldest supported build, and maintenance mode.
const minSupportedBuild = 0;

/// TEMPORARY: unlocks the Hostelzy team tools (Settings → Hostelzy team) until
/// F13 adds real admin accounts. Change it before sharing builds widely.
const teamPasscode = '2580';
const maintenanceUntil = ''; // e.g. '6:30 pm'; empty = no maintenance
