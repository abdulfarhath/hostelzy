part of '../../state.dart';

// F13 login
mixin _LoginData {

  /// Google sign-in (Firebase on Android; [NoSignIn] in tests, web, desktop).
  SignIn signIn = const NoSignIn();

  /// Where data is saved: sample (on this phone) or Supabase.
  HostelRepo data = const SampleRepo();

  /// The signed-in Google account; null when using Hostelzy on this phone only.
  Account? account;
  bool signingIn = false;

  /// F13 push: Firebase on Android ([NoPush] in tests, web, desktop).
  Push push = const NoPush();

  /// This phone's FCM token once notifications are allowed. Saved to the
  /// backend (`push_tokens`) once phone login works.
  String? pushToken;

  /// Permission explainer shown: notifications | location | camera.
  String permKind = 'notifications';

  /// Update / maintenance screen: update | maintenance.
  String gateKind = 'update';

  /// F15 maintenance message ("6:30 pm"), from the backend once online.
  String maintUntil = maintenanceUntil;
}

extension LoginActions on AppState {

  /// The typed phone number is never verified until SMS checks exist.
  bool get phoneVerified => false;

  Future<void> continueWithGoogle() async {
    if (signingIn) return;
    if (!signIn.available) return toastMsg('Google sign-in works in the Android app. Use Hostelzy on this phone for now.');
    update(() => signingIn = true);
    final (a, fail) = await signIn.google();
    update(() => signingIn = false);
    if (a != null) {
      update(() {
        account = a;
        // F18: the Google name is only a starting point; the user can change it.
        if (myName.trim().isEmpty) myName = a.name;
        hist = [...hist, screen];
        screen = 'phone';
        sheet = null;
      });
      startLive();
      return;
    }
    toastMsg(switch (fail) {
      SignInFail.cancelled => 'Sign-in cancelled.',
      SignInFail.notSetUp => 'Google sign-in isn’t switched on yet. Use Hostelzy on this phone for now.',
      _ => 'Couldn’t sign in. Check your internet and try again.',
    });
  }

  void savePhone() {
    if (myName.trim().length < 2) return toastMsg('Enter your name.');
    if (phone.length != 10) return toastMsg('Enter all 10 digits.');
    if (!AppState.validPhone(phone)) return toastMsg('Mobile numbers start with 6, 7, 8 or 9.');
    myName = myName.trim();
    update(() {
      signedIn = true;
      hist = [...hist, screen];
      screen = 'role';
    });
  }

  /// Saves name, phone (not verified) and role once signed in with Google.
  Future<void> syncProfile() async {
    final a = account;
    if (a == null) return;
    try {
      await data.saveProfile(name: a.name, email: a.email, phone: phone, role: role);
    } catch (e) {
      debugPrint('Profile: $e');
    }
  }

  /// After the explainer: Android's own prompt, then the token.
  Future<void> enablePush() async {
    final r = await push.ask();
    switch (r) {
      case PushAsk.allowed:
        pushToken = await push.token();
        final t = pushToken;
        if (t != null && account != null) {
          try {
            await data.savePushToken(t);
          } catch (e) {
            debugPrint('Push token: $e');
          }
        }
        update(() => notif.updateAll((k, v) => k == 'beds' ? v : true));
        toastMsg('Notifications allowed. Hostelzy starts sending them once your account is online.');
      case PushAsk.denied:
        toastMsg('Notifications are off. Turn them on in your phone’s settings → Apps → Hostelzy.');
      case PushAsk.unavailable:
        update(() => notif.updateAll((k, v) => k == 'beds' ? v : true));
        toastMsg('Saved. Notifications work in the Android app.');
    }
  }
}
