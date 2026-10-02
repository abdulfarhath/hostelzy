part of '../../state.dart';

// F18 map
mixin _MapAreaData {

  /// "Use my location" ([NoLocator] in tests, web, desktop).
  Locator locator = const NoLocator();

  /// The user's own position, only after they allowed it. Never invented.
  (double, double)? myPos;

  /// Area picked on the map (null = all areas), or a panned-to centre from
  /// "Search this area".
  String? mapArea;
  (double, double)? areaCenter;

  /// Where the map is after the user panned it; shows "Search this area".
  (double, double)? mapNow;

  /// Area picker search text.
  String areaQ = '';
  bool mapMoved = false;

  /// Bumped to recentre the map (area picked, location found).
  int mapFocus = 0;

  /// Which honest "not yet" screen the role picker showed: owner | resident.
  String roleGate = 'resident';

  /// Owner gate: "Request a visit" form.
  String gateHostel = '', gateArea = '';

  /// F18: when Android back last showed "Press back again to exit" (ms).
  int _backAt = 0;
}

extension MapAreaActions on AppState {
  (double, double) get mapFocusPos => mapArea != null ? (areaLatLng[mapArea] ?? landmarkLatLng[lm]!) : areaCenter ?? myPos ?? landmarkLatLng[lm]!;

  /// Distance to a hostel: from you once location is on, else from the
  /// landmark searched.
  double kmFor(Hostel h) => myPos != null ? kmBetween(posOf(h), myPos!) : kmTo(h, lm);
  String get kmFrom => myPos != null ? 'from you' : 'from $lm';

  /// The map area filter (Explore follows it too).
  bool inMapArea(Hostel h) => (mapArea == null || h.area == mapArea) && (areaCenter == null || kmBetween(posOf(h), areaCenter!) <= searchRadiusKm);
  String get mapAreaLabel => mapArea ?? (areaCenter != null ? 'This area' : (myPos != null ? 'Near me' : 'All areas'));

  void mapPanned((double, double) c) {
    mapNow = c;
    if (!mapMoved) update(() => mapMoved = true);
  }

  /// After the location explainer: Android asks, then the map centres on you
  /// and hostels sort by distance from you.
  Future<void> useMyLocation() async {
    update(() => sheet = null);
    final (pos, fail) = await locator.locate();
    if (pos != null) {
      update(() {
        myPos = pos;
        mapArea = null;
        areaCenter = null;
        mapMoved = false;
        sortBy = 'near';
        mapFocus++;
      });
      return toastMsg('Showing hostels by distance from you.');
    }
    update(() => sheet = 'areas');
    toastMsg(switch (fail) {
      LocateFail.off => 'Location is switched off on this phone. Pick an area instead.',
      LocateFail.never => 'Location is blocked for Hostelzy. Allow it in Settings → Apps → Hostelzy, or pick an area.',
      LocateFail.denied => 'No problem. Pick an area instead.',
      LocateFail.unavailable => 'Location works in the Android app. Pick an area instead.',
      _ => 'Couldn’t find your location. Pick an area instead.',
    });
  }

  /// Owner screens: sample data in debug; in release only for the Hostelzy
  /// team (team mode) or hostels the team put live on a visit, until owner
  /// accounts come with the backend (F13 part 2).
  bool get canOwner => AppState.samples || teamUnlocked || ownerHostels.any((h) => !isSeedHostel(h));

  /// Resident screens need an owner to have added you (backend, F13 part 2).
  bool get canResident => AppState.samples;

  /// Sends the visit request to the Hostelzy team on WhatsApp (no backend yet).
  void requestVisit() {
    if (gateHostel.trim().length < 3) return toastMsg('Enter your hostel’s name.');
    if (gateArea.isEmpty) return toastMsg('Pick the area.');
    whatsapp(supportWhatsApp, 'Hi Hostelzy, please visit my hostel to list it.\nHostel: ${gateHostel.trim()}\nArea: $gateArea\nName: ${meName.isEmpty ? '-' : meName}\nPhone: ${phone.isEmpty ? '-' : '+91 ${phoneSpaced(phone)}'}');
  }

  /// Role picker: gated roles show how to get access instead of sample data.
  void pickRole(String r) {
    if ((r == 'owner' && !canOwner) || (r == 'resident' && !canResident)) {
      return update(() {
        roleGate = r;
        hist = [...hist, screen];
        screen = 'roleGate';
      });
    }
    update(() {
      role = r;
      // F07: a new owner accepts the Fair Play rules first.
      screen = r == 'owner' && !fairAccepted ? 'oRules' : homeOf[r]!;
      hist = [];
    });
    syncProfile();
  }

  /// Android back button: close a sheet → previous screen → the role's home
  /// tab → "Press back again to exit". Returns true when the app may close.
  bool handleBack() {
    if (sheet != null) {
      update(() => sheet = null);
      return false;
    }
    if (hist.isNotEmpty) {
      back();
      return false;
    }
    final home = signedIn ? homeOf[role]! : 'welcome';
    if (screen != home && screen != 'gate') {
      update(() {
        screen = home;
        hist = [];
      });
      return false;
    }
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t - _backAt < 2000) return true;
    _backAt = t;
    toastMsg('Press back again to exit');
    return false;
  }

  /// The tenant's verified number (the demo number until they log in).
  String get myPhone => phone.length == 10 ? phone : '';

  /// Records (or reuses) the tenant's enquiry for this hostel + bed.
  Enquiry _record(String hid, String body, {String? bed, required String from}) {
    final me = myPhone;
    var e = enquiries.where((x) => x.hid == hid && x.bed == bed && x.phone == me).firstOrNull;
    if (e == null) {
      e = Enquiry(ref: 'HZ-${_nextRef++}', name: meName.isEmpty ? 'Hostelzy user' : meName, phone: me, hid: hid, bed: bed, at: DateTime.now().millisecondsSinceEpoch, from: from, msg: body.replaceFirst(RegExp(r'^Hi [^,]*, '), ''));
      enquiries = [e, ...enquiries];
    }
    return e;
  }

  void _enquire(String hid, String body, {String? bed, required String from}) {
    final e = _record(hid, body, bed: bed, from: from);
    sheet = 'wa';
    waTo = hostelById(hid).owner;
    waPhone = ownerPhones[hid] ?? '';
    waMsg = body;
    waRef = e.ref;
    waHid = hid;
  }

  /// Full message the tenant sends: their text plus the ref line.
  String get waFull => waRef == null ? (waMsg ?? '') : '${waMsg ?? ''}\nRef $waRef';
}
