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

  /// Push fix: Android's permission as last seen (null: no push here), the
  /// token the server has, and whether we already asked after sign-in.
  bool? osPushAllowed;
  String? _savedPushToken;
  bool pushAsked = false;
  StreamSubscription<String>? _tokenSub;

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
      syncPushToken();
      restoreRemFromServer();
      loadNotifyFromServer();
      return;
    }
    // Never hide why: the real code is shown and sent to Crashlytics.
    final why = signIn.lastError;
    if (fail != SignInFail.cancelled && why != null) push.report(Exception('Google sign-in failed: $why'), reason: 'sign-in');
    toastMsg(switch (fail) {
      SignInFail.cancelled => 'Sign-in cancelled.',
      SignInFail.notSetUp => why == null ? 'Google sign-in isn’t switched on yet. Use Hostelzy on this phone for now.' : 'Google sign-in isn’t set up for this app ($why). Use Hostelzy on this phone for now.',
      _ => why == null ? 'Couldn’t sign in. Check your internet and try again.' : 'Couldn’t sign in ($why). Try again.',
    });
  }

  void savePhone() {
    if (myName.trim().length < 2) return toastMsg('Enter your name.');
    if (phone.length != 10) return toastMsg('Enter all 10 digits.');
    if (!AppState.validPhone(phone)) return toastMsg('Mobile numbers start with 6, 7, 8 or 9.');
    myName = myName.trim();
    // F21 W2: a guest goes back to the hold or enquiry that asked for sign-in.
    if (_finishSignIn()) return;
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

  /// After the explainer (or the Settings switch): Android's own prompt,
  /// then the token goes to the server.
  Future<void> enablePush() async {
    update(() => pushAsked = true);
    final r = await push.ask();
    switch (r) {
      case PushAsk.allowed:
        update(() {
          osPushAllowed = true;
          notif.updateAll((k, v) => k == 'beds' ? v : true);
        });
        saveNotify();
        if (account == null) return toastMsg('Notifications allowed. Sign in with Google to get them.');
        if (!data.remote) return toastMsg('Notifications allowed. This demo has no server, so nothing is sent.');
        if (await syncPushToken(force: true)) toastMsg('Notifications are on for this phone.');
      case PushAsk.denied:
        update(() => osPushAllowed = false);
        toastMsg('Notifications are off. Turn them on in your phone’s settings → Apps → Hostelzy.');
      case PushAsk.unavailable:
        update(() => notif.updateAll((k, v) => k == 'beds' ? v : true));
        toastMsg('Saved. Notifications work in the Android app.');
    }
  }

  /// Push fix: on app start, after sign-in and on token refresh. If Android
  /// already allows notifications and there's an account, the server gets
  /// this phone's token. A failure is said out loud. True when it's saved.
  Future<bool> syncPushToken({bool force = false}) async {
    final ok = await push.allowed();
    update(() => osPushAllowed = ok);
    if (ok != true || account == null) return false;
    final t = await push.token();
    if (t == null) return false;
    pushToken = t;
    if (!force && t == _savedPushToken) return true;
    try {
      await data.savePushToken(t);
      _savedPushToken = t;
      return true;
    } catch (e) {
      debugPrint('Push token: $e');
      toastMsg('Couldn’t turn on notifications for this phone. Check your internet; we’ll try again when you open the app.');
      return false;
    }
  }

  /// Keeps the server's copy when FCM rotates the token.
  void watchPushToken() {
    _tokenSub?.cancel();
    _tokenSub = push.tokenRefresh.listen((t) async {
      if (account == null || osPushAllowed != true) return;
      try {
        await data.savePushToken(t);
        _savedPushToken = t;
        pushToken = t;
      } catch (e) {
        debugPrint('Push token refresh: $e');
      }
    });
  }

  /// Sign-out / account deleted: this phone stops getting their pushes.
  Future<void> forgetPushToken() async {
    final t = _savedPushToken ?? pushToken;
    _savedPushToken = null;
    pushToken = null;
    if (t == null) return;
    try {
      await data.removePushToken(t);
    } catch (e) {
      debugPrint('Push token remove: $e');
    }
    try {
      await push.deleteToken();
    } catch (_) {}
  }

  /// First time after a Google sign-in lands on a home screen: explain, then
  /// ask (once; "Not now" is remembered). Already allowed: just save the token.
  Future<void> offerPush() async {
    if (account == null) return;
    final ok = await push.allowed();
    update(() => osPushAllowed = ok);
    if (ok == true) {
      await syncPushToken();
      return;
    }
    if (ok == null || pushAsked) return;
    update(() => pushAsked = true);
    openPerm();
  }

  /// Settings switch: shows on only when Android allows it too.
  bool notifOn(String k) => notif[k]! && osPushAllowed != false;

  void toggleNotif(String k) {
    if (notifOn(k) || osPushAllowed == true) {
      update(() => notif[k] = !notifOn(k));
      saveNotify();
      return;
    }
    // Off at Android level: ask right away.
    enablePush().then((_) {
      if (osPushAllowed != true) return;
      update(() => notif[k] = true);
      saveNotify();
    });
  }

  /// F24 item 22: the switches are kept on the profile, so the server skips
  /// pushes of a kind switched off.
  Future<void> saveNotify() async {
    final a = account;
    if (!data.remote || a == null) return;
    try {
      await data.saveNotify(a.uid, Map.of(notif));
    } catch (e) {
      debugPrint('notify: $e');
    }
  }

  /// F24 item 22: signed in: the profile's switches come back to this phone,
  /// and the areas searched here and there are merged.
  Future<void> loadNotifyFromServer() async {
    final a = account;
    if (!data.remote || a == null) return;
    try {
      final r = await data.loadNotify(a.uid);
      if (r == null) return;
      final areas = [...searchedAreas, ...r.areas.where((x) => !searchedAreas.contains(x))].take(5).toList();
      update(() {
        for (final e in r.notify.entries) {
          if (notif.containsKey(e.key)) notif[e.key] = e.value;
        }
        searchedAreas
          ..clear()
          ..addAll(areas);
      });
      if (!listEquals(areas, r.areas)) await data.saveSearchedAreas(a.uid, areas);
    } catch (e) {
      debugPrint('notify load: $e');
    }
  }

  /// F24 item 22: an area picked in Where? or on the map, for "New free beds".
  void noteSearchedArea(String area) {
    final next = [area, ...searchedAreas.where((x) => x != area)].take(5).toList();
    if (listEquals(next, searchedAreas)) return;
    searchedAreas
      ..clear()
      ..addAll(next);
    final a = account;
    if (!data.remote || a == null) return;
    data.saveSearchedAreas(a.uid, next).catchError((Object e) => debugPrint('areas: $e'));
  }
}
