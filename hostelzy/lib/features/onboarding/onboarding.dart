part of '../../state.dart';

// F14 onboarding
mixin _OnboardingData {

  /// Days since each owner confirmed their free beds.
  final Map<String, int> confirmed = Map.of(seedConfirmed);

  /// F24 Wave 4d (F03): when each owner last confirmed their rates (the
  /// oldest rate card on the server); sample dates in the demo only.
  final Map<String, DateTime> ratesConfirmedAt = {
    if (AppState.samples)
      for (final e in seedRatesConfirmed.entries) e.key: appToday.subtract(Duration(days: e.value)),
  };

  /// Real hostels whose rates the server tracks but the owner never confirmed.
  final Set<String> ratesNeverConfirmed = {};

  /// "Visited by Hostelzy" dates.
  final Map<String, String> visited = Map.of(seedVisited);

  /// The signed-in owner's hostels (switcher), and floors without beds.
  final List<String> ownerHostels = ['anjani'];
  final Map<String, List<String>> emptyFloors = {};

  /// Managers: they run beds, residents, enquiries, complaints and food.
  final List<({String name, String phone, bool joined})> managers = [];
  String mgrName = '', mgrPhone = '';

  /// Add hostel wizard (Hostelzy admin mode on the visit).
  HostelDraft draft = HostelDraft();
  int addStep = 1;
  String resName = '', resPhone = '', resBed = '', resPaste = '';
  bool resPasteMode = false;

  /// Onboarding tracker.
  /// F24 item 29: from the server in the real app; sample leads only in the demo.
  final List<Lead> leads = AppState.samples ? seedLeads() : [];
  int trackCl = -1;

  /// Tracker tab (F22 Area 4): 0 Lead, 1 Visited, 2 Signed up (and data
  /// complete), 3 Live (live, trial, paying).
  int trackTab = 0;

  /// F24 Wave 4c (board `aPin`): the map under the fixed pin while the team
  /// places it, whether they moved it or used their location, and a bump to
  /// recentre the map.
  (double, double)? pinNow;
  bool pinTouched = false;
  int pinFocus = 0;
}

extension OnboardingActions on AppState {

  /// Unknown (no confirmation yet) is not called stale: we just don't say.
  bool stale(String hid) => (confirmed[hid] ?? 0) >= staleAfterDays;
  /// Every 3 days; a real hostel that was never confirmed asks right away.
  bool needsConfirm(String hid) {
    final d = confirmed[hid];
    if (d == null) return onServer && !isSeedHostel(hid);
    return d >= confirmEveryDays;
  }

  /// "Yes, all free": saved on the server for a real hostel (F24 item 9), so
  /// tenants see "confirmed by the owner today".
  void confirmBeds(String hid) {
    if (onServer && !isSeedHostel(hid)) {
      _write(() => data.confirmBeds(hid)).then((ok) {
        if (!ok) return;
        update(() => confirmed[hid] = 0);
        toastMsg('Thanks. Tenants see your free beds as confirmed today.');
      });
      return;
    }
    update(() => confirmed[hid] = 0);
    toastMsg('Thanks. Tenants see your free beds as confirmed today.');
  }

  /// F03: days since the owner last confirmed the rates; null when unknown.
  int? ratesDays(String hid) {
    final at = ratesConfirmedAt[hid];
    return at == null ? null : daysSince(at);
  }

  /// Tenants see "Not confirmed in over a month" after 31 days.
  bool ratesStale(String hid) => (ratesDays(hid) ?? 0) > ratesStaleAfterDays;

  /// Owner Today asks monthly ("Are your rates still right?"). Rates are the
  /// owner's (Wave 3a): never a manager.
  bool needsRatesConfirm(String hid) {
    if (managerOf.contains(hid)) return false;
    if (ratesNeverConfirmed.contains(hid)) return true;
    final d = ratesDays(hid);
    return d != null && d >= ratesConfirmEvery;
  }

  /// "Rates still right": saved on the server for a real hostel (the server
  /// stores its own time), so tenants see "Confirmed by the owner" with today's date.
  void confirmRates(String hid) {
    void done() {
      update(() {
        ratesConfirmedAt[hid] = appToday;
        ratesNeverConfirmed.remove(hid);
      });
      toastMsg('Thanks. Tenants see your rates as confirmed today.');
    }

    if (onServer && !isSeedHostel(hid)) {
      _write(() => data.confirmRates(hid)).then((ok) {
        if (ok) done();
      });
      return;
    }
    done();
  }

  void addManager() {
    final ph = mgrPhone.replaceAll(RegExp(r'\D'), '');
    if (mgrName.trim().isEmpty || ph.length != 10) return toastMsg('Add a name and a 10-digit number.');
    if (onServer) {
      // S8: a one-time code from the server, sent to the manager on WhatsApp.
      final name = mgrName.trim(), hid = ownHid;
      data.managerInvite(hid, name, ph).then((code) {
        update(() {
          managers.add((name: name, phone: ph, joined: false));
          mgrName = '';
          mgrPhone = '';
          sheet = null;
        });
        whatsapp(ph, 'Hi $name, you’re invited to manage ${hostelById(hid).name} on Hostelzy. Open this link, sign in with Google, and you’re in: ${inviteLink(code)} (code $code, works once, for 7 days)');
        toastMsg('WhatsApp opened with ${name.split(' ')[0]}’s invite. They join once they open it and sign in.');
      }, onError: (Object e) {
        toastMsg('$e'.contains('only the owner') ? 'Only the owner adds managers.' : 'Couldn’t make the invite. Check your internet and try again.');
      });
      return;
    }
    update(() {
      managers.add((name: mgrName.trim(), phone: ph, joined: false));
      mgrName = '';
      mgrPhone = '';
      sheet = null;
    });
    // No backend yet: the invite is pending until the manager signs in.
    toastMsg('Invite pending. The manager joins by signing in with this number.');
  }

  /// Residents step: "Type one" or "Paste a list" (name, phone, bed per line).
  void addDraftResident() {
    final ph = resPhone.replaceAll(RegExp(r'\D'), '');
    if (resName.trim().isEmpty || ph.length != 10 || resBed.trim().isEmpty) return toastMsg('Name, 10-digit phone and bed.');
    update(() {
      draft.residents.add((name: resName.trim(), phone: ph, bed: resBed.trim().toUpperCase()));
      resName = '';
      resPhone = '';
      resBed = '';
    });
  }

  void pasteDraftResidents() {
    var n = 0;
    update(() {
      for (final line in resPaste.split('\n')) {
        final parts = line.split(',').map((x) => x.trim()).toList();
        if (parts.length < 3) continue;
        final ph = parts[1].replaceAll(RegExp(r'\D'), '');
        if (parts[0].isEmpty || ph.length != 10) continue;
        draft.residents.add((name: parts[0], phone: ph, bed: parts[2].toUpperCase()));
        n++;
      }
      resPaste = '';
    });
    toastMsg(n == 0 ? 'One per line: name, phone, bed.' : 'Added $n residents.');
  }

  /// Go live: the draft becomes a listing tenants can see (in this app
  /// session; stored for real with the backend, F13).
  List<String> get goLiveLeft {
    final d = draft;
    return [
      if (d.floors.every((f) => f.noBeds || f.rooms.isEmpty)) 'At least one room with beds',
      if (!d.ownerVerified) 'Owner phone checked by a call',
      if (!d.fairPlay) 'Fair Play rules accepted',
      if (!d.ownerLinked) 'Owner account linked',
      if (draftPhotos < HostelDraft.minPhotos) 'At least ${HostelDraft.minPhotos} photos',
      if (d.missingPrices.isNotEmpty) 'Every room type priced',
      if (!d.bedsChecked) 'Bed status checked on the visit',
      if (!d.pinChecked || d.pin == null) 'Map pin dropped at the gate',
    ];
  }

  /// Photos of the draft: real uploads on the server, ticked slots in the demo.
  int get draftPhotos => onServer && draft.serverId != null ? (photosOf[draft.serverId] ?? const []).length : draft.photoCount;

  /// F24: the draft as the server's save_hostel wants it. Rooms are numbered
  /// floor × 100 + position, like the listing made at go-live.
  Map<String, dynamic> draftPayload() {
    final d = draft;
    final rs = <Map<String, dynamic>>[];
    for (var fi = 0; fi < d.floors.length; fi++) {
      final f = d.floors[fi];
      if (f.noBeds) continue;
      for (var i = 0; i < f.rooms.length; i++) {
        final dr = f.rooms[i];
        final n = fi * 100 + i + 1;
        rs.add({'number': n, 'label': dr.label == '$n' ? null : dr.label, 'floor': fi, 'share': dr.share, 'ac': dr.ac, 'rent': d.prices[rateKey(dr.ac, dr.share)] ?? 0, 'bath': 'Attached'});
      }
    }
    final ll = d.pin;
    return {
      'name': d.name.trim(),
      'gender': d.gender,
      'area': d.area,
      'owner_name': d.ownerName.trim(),
      'owner_phone': d.ownerPhone,
      'food': d.food != 'No food',
      'ac': rs.any((r) => r['ac'] == true),
      'only_ac': rs.isNotEmpty && rs.every((r) => r['ac'] == true),
      'tags': [if (d.food != 'No food') '${d.food} a day', ...d.amenities],
      'amenities': d.amenities.toList(),
      'terms': {'advance': d.advance, 'maintenance': d.kept, 'noticeDays': d.notice, 'dueOnJoining': d.dueOnJoining, 'electricityExtra': true},
      'rules': [for (final r in draftRules) {'k': r.k, 'v': r.v}],
      if (d.ownerWa.length == 10) 'owner_whatsapp': d.ownerWa,
      // F24 Wave 4c: only the pin the team dropped at the gate, never the area's centre.
      if (ll != null) ...{'lat': ll.$1, 'lng': ll.$2},
      'rates': [for (final e in d.prices.entries) if (e.value > 0) {'ac': e.key.startsWith('ac'), 'share': int.parse(e.key.replaceFirst(RegExp('^(ac|non)'), '')), 'rent': e.value}],
      'rooms': rs,
    };
  }

  Terms get draftTerms => Terms(advance: draft.advance, maintenance: draft.kept, noticeDays: draft.notice, dueOnJoining: draft.dueOnJoining);

  /// House rules from the visit: the gate time and visitors typed in Basics,
  /// the rest from the rate card's terms (the owner edits them later).
  List<Rule> get draftRules => [
    for (final r in blankRules(draftTerms))
      switch (r.k) {
        'Gate closes' => Rule(r.k, draft.gate.trim()),
        'Visitors' => Rule(r.k, draft.visitors.trim()),
        _ => r,
      },
  ];

  /// F24 Wave 4c (board `aPin`): opens the map with the pin where it was
  /// dropped, else on the area (to be moved to the gate).
  void openPin() => update(() {
    final d = draft;
    pinNow = d.pin ?? areaLatLng[d.area] ?? landmarkLatLng['Hitec City']!;
    pinTouched = d.pin != null;
    pinFocus++;
    hist = [...hist, screen];
    screen = 'aPin';
  });

  /// The team moved the map under the pin.
  void pinPanned((double, double) c) {
    pinNow = c;
    if (!pinTouched) update(() => pinTouched = true);
  }

  /// "Use my location": standing at the gate, the phone's GPS.
  Future<void> locatePin() async {
    final (pos, fail) = await locator.locate(exact: true);
    if (pos != null) {
      update(() {
        pinNow = pos;
        pinTouched = true;
        pinFocus++;
      });
      return toastMsg('Pin moved to where you are. Check it sits on the gate.');
    }
    toastMsg(switch (fail) {
      LocateFail.off => 'Location is switched off on this phone. Move the map instead.',
      LocateFail.never => 'Location is blocked for Hostelzy. Allow it in Settings → Apps → Hostelzy, or move the map.',
      LocateFail.unavailable => 'Location works in the Android app. Move the map instead.',
      _ => 'Couldn’t find your location. Move the map instead.',
    });
  }

  /// Saves the pin where the map is. Only after the team moved it or used
  /// their location, so it's never just the area's centre.
  void savePin() {
    final c = pinNow;
    if (!pinTouched || c == null) return toastMsg('Move the map so the pin sits on the gate, or use your location.');
    update(() {
      draft
        ..pin = c
        ..pinChecked = true;
    });
    back();
  }

  /// Server words → the team's.
  String _onboardWords(Object e) {
    final m = '$e';
    for (final k in const ['add the hostel name', 'add a price for', 'link the owner', 'add 8 photos', 'add at least one room', 'has someone in it', 'already has an owner', 'drop the map pin', 'isn\'t in Hyderabad', 'needs 10 digits']) {
      if (m.contains(k)) {
        final i = m.indexOf(k);
        final end = m.indexOf(RegExp(r'[,}\n]'), i);
        final w = m.substring(i, end < 0 ? m.length : end).trim();
        return '${w[0].toUpperCase()}${w.substring(1)}.';
      }
    }
    return 'Couldn’t save it. Check your internet and try again.';
  }

  /// F24: saves the draft on the server (the team, in the real app) and loads
  /// it back, so photos and residents can go on it. True in the demo.
  Future<bool> saveDraftLive() async {
    if (!onServer) return true;
    try {
      final id = await data.saveHostel(draft.serverId, draftPayload());
      draft.serverId = id;
      await refreshListings();
      return true;
    } catch (e) {
      debugPrint('save hostel: $e');
      toastMsg(_onboardWords(e));
      return false;
    }
  }

  /// Residents typed on the visit become stays on the server (the beds show
  /// as taken); each is saved once.
  Future<bool> saveDraftResidents() async {
    final id = draft.serverId;
    if (!onServer || id == null) return true;
    for (final r in draft.residents) {
      final k = '${r.bed}|${r.phone}';
      if (draft.savedResidents.contains(k)) continue;
      final b = findBed(id, r.bed);
      if (b.b == null) {
        toastMsg('Bed ${r.bed} isn’t in the rooms.');
        return false;
      }
      try {
        // F24 #18: residents typed on the visit, before go-live, lived there
        // before Hostelzy.
        await data.addStay(hid: id, bedKey: b.b!.key, name: r.name, phone: r.phone, rent: b.r!.rent, advance: draft.advance, joinedOn: appToday, before: !hostels.any((h) => h.id == id && h.live));
        draft.savedResidents.add(k);
      } catch (e) {
        debugPrint('draft resident: $e');
        toastMsg('Couldn’t save ${r.name}. Check your internet and try again.');
        return false;
      }
    }
    return true;
  }

  /// The wizard's Next: saves to the server after the rate card and after
  /// the residents.
  Future<void> nextAddStep() async {
    if (addStep == 3 && !await saveDraftLive()) return;
    if (addStep == 5 && !await saveDraftResidents()) return;
    update(() => addStep++);
    if (addStep == 4 && draft.serverId != null) unawaited(loadPhotos(draft.serverId!, again: true));
  }

  /// Photos for the draft: the owners' Photos screen, for this hostel.
  void openDraftPhotos() {
    final id = draft.serverId;
    if (id == null) return;
    update(() {
      photoFor = id;
      photoAlbum = 'Hostel';
      hist = [...hist, screen];
      screen = 'oPhotos';
    });
    loadPhotos(id, again: true);
  }

  /// F24 (board `aAddOwner`): a one-time sign-in link for the owner on WhatsApp.
  Future<void> sendOwnerLink() async {
    final d = draft;
    if (d.ownerName.trim().length < 2) return toastMsg('Add the owner’s name.');
    if (d.ownerPhone.length != 10) return toastMsg('Enter the owner’s 10-digit phone.');
    if (!onServer) {
      update(() => d.ownerLinked = true);
      return toastMsg('Sample data: the owner shows as linked.');
    }
    if (!await saveDraftLive()) return;
    try {
      final code = d.ownerCode.isNotEmpty ? d.ownerCode : await data.ownerInvite(d.serverId!, d.ownerName.trim(), d.ownerPhone);
      update(() => d.ownerCode = code);
      whatsapp(d.ownerChat, 'Hi ${d.ownerName.trim().split(' ').first}, ${d.name.trim()} is on Hostelzy. Open this link, sign in with Google and pick “I run a PG” to run it from your phone: ${inviteLink(code)} (works once, for 7 days).');
    } catch (e) {
      debugPrint('owner invite: $e');
      toastMsg(_onboardWords(e));
    }
  }

  /// Checks whether the owner has signed in with their code.
  Future<void> checkOwnerLinked() async {
    final id = draft.serverId;
    if (!onServer || id == null) return;
    try {
      final ok = await data.ownerLinked(id);
      update(() => draft.ownerLinked = ok);
      toastMsg(ok ? '${draft.ownerName.trim()} is linked.' : 'Not yet. Ask ${draft.ownerName.trim()} to open the link and sign in.');
    } catch (e) {
      toastMsg('Couldn’t check. Check your internet and try again.');
    }
  }

  void goLive() {
    if (goLiveLeft.isNotEmpty) return toastMsg('${goLiveLeft.length} things left.');
    if (onServer) {
      _goLiveServer();
      return;
    }
    final d = draft;
    var id = d.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    while (hostels.any((h) => h.id == id)) {
      id = '${id}x';
    }
    final spot = areaSpot[d.area] ?? areaSpot['Madhapur']!;
    final taken = {for (final r in d.residents) r.bed};
    final rs = <Room>[];
    for (var fi = 0; fi < d.floors.length; fi++) {
      final f = d.floors[fi];
      if (f.noBeds) continue;
      for (var i = 0; i < f.rooms.length; i++) {
        final dr = f.rooms[i];
        final n = fi * 100 + i + 1;
        rs.add(
          Room(
            n: n,
            floor: fi,
            share: dr.share,
            ac: dr.ac,
            rent: d.prices[rateKey(dr.ac, dr.share)]!,
            bath: 'Attached',
            name: dr.label == '$n' ? null : dr.label,
            beds: [
              for (var k = 0; k < dr.share; k++)
                Bed(id: '${dr.label}-${'ABCD'[k]}', letter: 'ABCD'[k], room: n, floor: fi, spot: spots[dr.share]![k], state: taken.contains('${dr.label}-${'ABCD'[k]}') ? 'booked' : 'free', soon: ''),
            ],
          ),
        );
      }
    }
    final h = Hostel(
      id: id,
      name: d.name,
      gender: d.gender,
      area: d.area,
      from: rs.isEmpty ? 0 : rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b),
      rating: 0,
      reviews: 0,
      food: d.food != 'No food',
      ac: rs.any((r) => r.ac),
      instant: false,
      owner: d.ownerName,
      reply: 0,
      mins: spot.mins,
      x: spot.x,
      y: spot.y,
      tags: [if (d.food != 'No food') '${d.food} a day', ...d.amenities.take(3)],
      terms: draftTerms,
      onlyAc: rs.every((r) => r.ac),
    );
    update(() {
      hostels.add(h);
      ownerPhones[id] = d.ownerPhone;
      if (d.ownerWa.length == 10) ownerWhatsApps[id] = d.ownerWa;
      if (d.pin != null) livePos[id] = d.pin!;
      hostelRules[id] = draftRules;
      rooms[id] = rs;
      rates[id] = {...seedRates(h), ...d.prices};
      stats[id] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
      emptyFloors[id] = [for (final f in d.floors) if (f.noBeds) f.name];
      visited[id] = '${dayMon(appToday)} ${appToday.year}';
      ownerHostels.add(id);
      leads.add(Lead(d.name, d.area, 'Trial ends ${dayMon(appToday.add(const Duration(days: 30)))}', 5, hid: id));
      screen = 'aTrack';
      trackTab = 3;
      hist = [];
    });
    toastMsg('${d.name} is live. The 30-day trial starts today.');
  }

  /// F24: saves once more, then the server checks and puts it live (with the
  /// 30-day trial and "Visited by Hostelzy" today).
  Future<void> _goLiveServer() async {
    final d = draft;
    if (!await saveDraftLive()) return;
    try {
      await data.goLive(d.serverId!);
      await refreshListings();
      update(() {
        screen = 'aTrack';
        trackTab = 3;
        hist = [];
      });
      toastMsg('${d.name.trim()} is live. The 30-day trial starts today.');
      await loadTeam();
    } catch (e) {
      debugPrint('go live: $e');
      toastMsg(_onboardWords(e));
    }
  }

  void switchHostel(String hid) => update(() {
    ownHid = hid;
    rules = hostelRules[hid] != null ? List.of(hostelRules[hid]!) : isSeedHostel(hid) ? rules : blankRules(hostelById(hid).terms);
    // Drafts belong to the hostel they were opened on.
    rateDraft = null;
    acDraft = null;
    dealDraft = null;
    sheet = null;
    screen = 'oToday';
    hist = [];
  });

  void openAddHostel() => update(() {
    draft = AppState.samples ? HostelDraft() : HostelDraft.blank();
    addStep = 1;
    hist = [...hist, screen];
    screen = 'aAdd';
    sheet = null;
  });
}
