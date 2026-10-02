part of '../../state.dart';

// F21 W2: look around first. Sign-in is asked at the first hold or enquiry.
mixin _GuestData {

  /// App opens on this phone; the water-reminder offer waits for the 3rd.
  int opens = 0;

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
}

extension GuestActions on AppState {

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
  int get filterCount => [fG != 'Any', fS != 'Any', fR != 'Any', fB != 'Any', fFood].where((x) => x).length;

  void clearFilters() => update(() {
    fG = 'Any';
    fS = 'Any';
    fR = 'Any';
    fB = 'Any';
    fFood = false;
  });

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
    mapArea = a;
    areaCenter = null;
    mapMoved = false;
    mapFocus++;
    _whereDone();
  });

  /// Where? → a hostel: its page.
  void pickWhereHostel(String id) => update(() {
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
