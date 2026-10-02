part of '../../state.dart';

// F14 onboarding
mixin _OnboardingData {

  /// Days since each owner confirmed their free beds.
  final Map<String, int> confirmed = Map.of(seedConfirmed);

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
  String resName = '', resPhone = '', resBed = '', resPaste = '', draftOtp = '';
  bool resPasteMode = false;

  /// Onboarding tracker.
  final List<Lead> leads = seedLeads();
  int trackCl = -1;
}

extension OnboardingActions on AppState {

  bool stale(String hid) => (confirmed[hid] ?? staleAfterDays) >= staleAfterDays;
  bool needsConfirm(String hid) => (confirmed[hid] ?? 0) >= confirmEveryDays;

  void confirmBeds(String hid) {
    update(() => confirmed[hid] = 0);
    toastMsg('Thanks. Tenants see your free beds as confirmed today.');
  }

  void addManager() {
    final ph = mgrPhone.replaceAll(RegExp(r'\D'), '');
    if (mgrName.trim().isEmpty || ph.length != 10) return toastMsg('Add a name and a 10-digit number.');
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
      if (d.photoCount < HostelDraft.minPhotos) 'At least ${HostelDraft.minPhotos} photos',
      if (d.missingPrices.isNotEmpty) 'Every room type priced',
      if (!d.bedsChecked) 'Bed status checked on the visit',
      if (!d.pinChecked) 'Map pin checked',
    ];
  }

  void goLive() {
    if (goLiveLeft.isNotEmpty) return toastMsg('${goLiveLeft.length} things left.');
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
      terms: Terms(advance: d.advance, maintenance: d.kept, noticeDays: d.notice, dueOnJoining: d.dueOnJoining),
      onlyAc: rs.every((r) => r.ac),
    );
    update(() {
      hostels.add(h);
      ownerPhones[id] = d.ownerPhone;
      rooms[id] = rs;
      rates[id] = {...seedRates(h), ...d.prices};
      stats[id] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
      emptyFloors[id] = [for (final f in d.floors) if (f.noBeds) f.name];
      visited[id] = '${dayMon(appToday)} ${appToday.year}';
      confirmed[id] = 0;
      ownerHostels.add(id);
      leads.add(Lead(d.name, d.area, 'Trial ends ${dayMon(appToday.add(const Duration(days: 30)))}', 5, hid: id));
      screen = 'aTrack';
      hist = [];
    });
    toastMsg('${d.name} is live. The 30-day trial starts today.');
  }
}
