part of '../../state.dart';

/// F30: verified hostel pages a guest can open on one phone before the
/// sign-in wall (T34). UNVERIFIED pages (T32) are always free.
const guestFreeHostels = 3;

// F21 W2: look around first. Sign-in is asked at the first hold or enquiry.
// F30: and after 3 verified hostel pages on this phone.
mixin _GuestData {

  /// App opens on this phone; the water-reminder offer waits for the 3rd.
  int opens = 0;

  /// F30: the verified hostels this guest opened on this phone (ids, oldest
  /// first); kept across restarts. Re-opening one of them is free.
  List<String> guestHostels = [];

  /// F30: the Explore hint "3 hostels free to open…" was dismissed.
  bool guestHintOff = false;

  /// What a guest was doing when sign-in was asked: hold | book | enquiry, or the
  /// role picked on Welcome (owner | resident).
  String? afterSignIn;
  void Function()? _afterAct;
  List<String> _afterHist = const [];
  String _afterScreen = 'explore';

  /// "Where?" typed text.
  String whereQ = '';

  /// Hostel page: House rules folded open.
  bool rulesOpen = false;

  /// F21 W4: hostels from the server: ready | loading | offline | cached
  /// (F24: the last list kept on this phone, from [cachedAt]). Never "No
  /// hostels" while loading or offline.
  String listState = 'ready';
  DateTime? cachedAt;

  /// F21 W4: the last refresh of your holds, payments and stay failed.
  bool liveFailed = false;

  /// Tries the server again (set by main.dart; null in tests and demo builds).
  Future<void> Function()? reconnect;

  /// F21 W4: the app's language (en | te | hi) and the checked strings bundled.
  String lang = 'en';
  Map<String, LangPack> langs = const {};
}

extension GuestActions on AppState {

  /// Languages the picker offers: English, plus any with checked strings.
  List<(String, String)> get langChoices => [('en', 'English'), for (final l in langs.values) if (l.strings.isNotEmpty) (l.code, l.label)];

  void pickLang(String code) => update(() {
    lang = code;
    sheet = null;
  });

  /// "You're offline · Retry".
  Future<void> retryListings() async {
    update(() => listState = 'loading');
    if (reconnect != null) return reconnect!();
    try {
      final l = await data.listings();
      if (l != null) applyListings(l);
      update(() => listState = 'ready');
    } catch (e) {
      update(() => listState = 'offline');
    }
  }

  /// Welcome → "Find a bed": Explore without signing in.
  void browse() => update(() {
    role = 'tenant';
    screen = 'explore';
    hist = [];
    sheet = null;
  });

  /// Welcome links: "I run a PG", "I live in a PG", "Sign in".
  void startSignIn([String? then]) {
    afterSignIn = then;
    _afterAct = null;
    go(phoneOtpLogin ? 'phone' : 'login');
  }

  /// True when signed in; otherwise shows "Sign in to hold this bed" and
  /// runs [act] once the name and phone are in.
  bool needSignIn(String why, void Function() act) {
    if (signedIn) return true;
    update(() {
      afterSignIn = why;
      _afterAct = act;
      _afterHist = [...hist];
      _afterScreen = screen;
      sheet = 'signIn';
    });
    return false;
  }

  /// After "About you": back to what the guest was doing. False when
  /// nothing was waiting (the role picker comes next).
  bool _finishSignIn() {
    final then = afterSignIn;
    if (then == null) return false;
    afterSignIn = null;
    signedIn = true;
    // F30: signed in, so no limit; the guest count is over.
    guestHostels = [];
    if (then == 'owner' || then == 'resident') {
      pickRole(then);
      return true;
    }
    final act = _afterAct;
    _afterAct = null;
    update(() {
      role = 'tenant';
      screen = _afterScreen;
      hist = _afterHist;
      sheet = null;
    });
    syncProfile();
    act?.call();
    return true;
  }

  /// Filters set beyond the defaults (sort is not a filter).
  int get filterCount => [fG != 'Any', fS != 'Any', fR != 'Any', fB != 'Any', fFood, fDeals, fVerified].where((x) => x).length + fAm.length;

  void clearFilters() => update(() {
    fG = 'Any';
    fS = 'Any';
    fR = 'Any';
    fB = 'Any';
    fFood = false;
    fDeals = false;
    fVerified = false;
    fAm = {};
  });

  // F30: guests see 3 verified hostels, then sign in.

  /// True when this phone may show [h]'s page: signed in, an UNVERIFIED page,
  /// one of the hostels already opened here, or still under the 3.
  bool canOpenHostel(Hostel h) => signedIn || h.listed || guestHostels.contains(h.id) || guestHostels.length < guestFreeHostels;

  /// T34 instead of the page: a guest's 4th verified hostel.
  bool wallFor(Hostel h) => !canOpenHostel(h);

  /// Counts a verified hostel page a guest opens (inside an [update]).
  void _countGuestHostel(String id) {
    if (signedIn || guestHostels.contains(id)) return;
    final h = hostels.where((x) => x.id == id).firstOrNull;
    if (h == null || h.listed || guestHostels.length >= guestFreeHostels) return;
    guestHostels = [...guestHostels, id];
  }

  /// Opens a hostel's page (S13; T32 when it is UNVERIFIED; T34 when a guest
  /// has used their 3) from a card, the map, Saved or a link.
  void openHostel(String id) => update(() {
    _countGuestHostel(id);
    hist = [...hist, screen];
    screen = 'detail';
    sheet = null;
    hid = id;
    dealAc = null;
    rulesOpen = false;
  });

  /// T34 "Continue with Google": after sign-in the user lands back on the
  /// hostel they tried to open. Builds without Google sign-in (the demo APK)
  /// take the existing sample path (About you on this phone).
  void wallContinue() {
    afterSignIn = 'wall';
    _afterAct = null;
    _afterHist = [...hist];
    _afterScreen = 'detail';
    if (signIn.available) {
      unawaited(continueWithGoogle());
    } else {
      continueOnPhone();
    }
  }

  /// T34 "Not now": back to Explore.
  void wallNotNow() => tab('explore');

  /// S8: the × on "3 hostels free to open, then sign in (free)".
  void dismissGuestHint() => update(() => guestHintOff = true);

  /// F22 Area 1: the nearest area that has hostels (for "Try Hitec City").
  String? get nearbyArea {
    final from = areaLatLng[mapArea] ?? areaCenter ?? myPos ?? landmarkLatLng[lm];
    final have = [for (final a in mapAreas) if (a != mapArea && browsable.any((h) => h.area == a && !removed(h.id))) a];
    if (have.isEmpty || from == null) return have.firstOrNull;
    have.sort((a, b) => kmBetween(areaLatLng[a] ?? from, from).compareTo(kmBetween(areaLatLng[b] ?? from, from)));
    return have.first;
  }

  /// What the "Where?" bar shows.
  String get whereLabel => mapArea ?? (areaCenter != null ? 'This area on the map' : myPos != null ? 'Near me' : 'Near $lm');

  void openWhere() => update(() {
    whereQ = '';
    hist = [...hist, screen];
    screen = 'where';
    sheet = null;
  });

  /// Where? → a landmark: distances from it, every area.
  void pickLandmark(String l) => update(() {
    lm = l;
    myPos = null;
    mapArea = null;
    areaCenter = null;
    mapMoved = false;
    mapFocus++;
    _whereDone();
  });

  /// Where? → an area (the map follows it too).
  void pickWhereArea(String a) => update(() {
    noteSearchedArea(a);
    mapArea = a;
    areaCenter = null;
    mapMoved = false;
    mapFocus++;
    _whereDone();
  });

  /// Where? → a hostel: its page (F30: counts for a guest).
  void pickWhereHostel(String id) => update(() {
    _countGuestHostel(id);
    hid = id;
    dealAc = null;
    rulesOpen = false;
    screen = 'detail';
    sheet = null;
  });

  /// Where? → Near me: back to the list, then the location explainer.
  void whereNearMe() => update(() {
    _whereDone();
    sheet = 'loc';
  });

  void _whereDone() {
    final h = List.of(hist);
    screen = h.isNotEmpty ? h.removeLast() : 'explore';
    hist = h;
    sheet = null;
  }

  /// After the first free hold: ask for notifications so the owner's reply
  /// reaches this phone (once; already allowed just saves the token).
  Future<void> askPushAfterHold() async {
    if (account == null) return;
    final ok = await push.allowed();
    update(() => osPushAllowed = ok);
    if (ok == true) {
      await syncPushToken();
      return;
    }
    if (ok == null || pushAsked) return;
    update(() {
      pushAsked = true;
      sheet = 'holdNotify';
    });
  }
}
