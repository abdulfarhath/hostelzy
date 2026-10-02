part of '../../state.dart';

// F06
extension ResidentsActions on AppState {

  /// Taken beds at Anjani with nobody added for them.
  List<String> get unassignedBeds => [
    for (final r in rooms['anjani']!)
      for (final b in r.beds)
        if (b.state == 'booked' && !residents.any((x) => x.bed == b.id)) b.id,
  ];

  /// Join time in ms for the add-resident sheet's "Joined on" choice.
  int get rJoinAt {
    final days = switch (rJoin) {
      'Today' => 0,
      'Yesterday' => 1,
      _ => rPickBack,
    };
    return now - days * 86400000;
  }

  String get rJoinLabel => dayName(appToday.subtract(Duration(days: switch (rJoin) {
    'Today' => 0,
    'Yesterday' => 1,
    _ => rPickBack,
  })));

  /// Joined via Hostelzy: this phone enquired about, held or booked a bed at
  /// Anjani on Hostelzy within [matchWindowDays] before joining.
  ({String ref, String what, int at})? matchFor(String phone, int joinAt) {
    if (phone.length != 10) return null;
    final from = joinAt - matchWindowDays * 86400000;
    bool inWin(int t) => t >= from && t <= joinAt + 86400000;
    final e = enquiries.where((e) => e.hid == 'anjani' && e.phone == phone && inWin(e.at)).firstOrNull;
    if (e != null) return (ref: e.ref, what: 'asked about your hostel', at: e.at);
    if (phone == myPhone) {
      final h = holds.where((h) => h.hid == 'anjani' && h.status != 'released' && inWin(h.start)).firstOrNull;
      if (h != null) return (ref: 'bed ${h.bed}', what: h.opt == 'book' ? 'booked a bed' : 'held a bed', at: h.start);
    }
    return null;
  }

  Resident _newResident(String name, String phone, String bed, int amt, int adv, int joinAt, {required bool confirmed}) {
    final m = matchFor(phone, joinAt);
    final b = findBed('anjani', bed).b;
    if (b != null) b.state = 'booked';
    final joined = dayMon(DateTime.fromMillisecondsSinceEpoch(joinAt));
    // F06: residents who came through Hostelzy are added within 3 days of
    // moving in. Later counts as a Fair Play signal (F07).
    final late = m != null ? ((now - joinAt) / 86400000).floor() : 0;
    final lateDays = late > addWithinDays ? late : 0;
    if (lateDays > 0) {
      final id = 'FP-0${143 + cases.length - AppState.seedCaseCount}';
      cases = [
        FairCase(openedAt: DateTime.now().millisecondsSinceEpoch, id: id, hid: 'anjani', title: '$name added $lateDays days after moving in', signal: 'Hostelzy resident (${m!.ref}) added after the 3-day limit', status: 'new', resident: bed, events: [CaseEvent(dayMon(DateTime.fromMillisecondsSinceEpoch(m.at)), 'On Hostelzy', 'Tenant ${m.what}'), CaseEvent(joined, 'Moved in', 'Bed $bed'), CaseEvent(dayMon(appToday), 'Added by the owner', '$lateDays days later', flag: true)]),
        ...cases,
      ];
    }
    return Resident(name: name, bed: bed, amt: amt, status: 'Paid', note: 'Paid at move-in', phone: phone, via: m != null ? 'hz' : 'direct', since: confirmed ? 'Joined $joined' : 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: confirmed, advance: adv, joinAt: joinAt, lateDays: lateDays);
  }

  /// "Add and send code": the resident is listed as Waiting OTP until they
  /// confirm with the WhatsApp code.
  void addResident() {
    final name = rName.trim();
    if (name.isEmpty || rPhone.length != 10 || rBed == null) return toastMsg('Add a name, a 10-digit number and a bed.');
    final res = _newResident(name, rPhone, rBed!, int.tryParse(rFee) ?? 0, int.tryParse(rAdv) ?? 0, rJoinAt, confirmed: false);
    update(() {
      residents = [res, ...residents];
      sheet = null;
      resF = 'All';
    });
    toastMsg(res.lateDays > 0 ? 'Added, ${res.lateDays} days after moving in: that’s past the 3-day limit and goes to Fair Play.' : 'Added as Waiting OTP. ${name.split(' ')[0]} confirms with the code once the app is online.');
  }

  /// Invite QR sign-ups signed in with Google; approving counts them.
  void approveSignup(Signup g) {
    final r = findBed('anjani', g.bed).r;
    final res = _newResident(g.name, g.phone, g.bed, r?.rent ?? 0, hostels[0].terms.advance, now, confirmed: true);
    update(() {
      signups = signups.where((x) => x.id != g.id).toList();
      residents = [res, ...residents];
    });
    toastMsg('${g.name.split(' ')[0]} is now a resident of bed ${g.bed}.');
  }

  void rejectSignup(Signup g) {
    update(() => signups = signups.where((x) => x.id != g.id).toList());
    toastMsg('Removed.');
  }

  /// The resident the confirm screen is for (the newest one waiting).
  Resident? get toConfirm => residents.where((r) => r.bed == cBed).firstOrNull ?? residents.where((r) => !r.confirmed).firstOrNull;

  void confirmStay() {
    final r = toConfirm;
    if (r == null) return;
    if (cOtp.length != 6) return toastMsg('Enter the 6-digit code.');
    update(() {
      cBed = r.bed;
      r.confirmed = true;
      r.since = 'Joined ${dayMon(r.joinAt != null ? DateTime.fromMillisecondsSinceEpoch(r.joinAt!) : appToday)}';
      cOtp = '';
    });
  }

  /// F16: cheapest rent and free beds for one room type at a hostel, or
  /// null when the hostel has no rooms of that type.
  ({int from, int free})? typeSummary(String hid, bool ac) {
    final rs = rooms[hid]!.where((r) => r.ac == ac).toList();
    if (rs.isEmpty) return null;
    return (from: rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b), free: rs.fold(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length));
  }

  /// Owner opens "Rooms and rent" with a draft copy of the rate card.
  void openRates() {
    rateDraft = Map.of(rates[ownHid]!);
    acDraft = {for (final r in rooms[ownHid]!) r.n: r.ac};
    final fs = floorsOf(rooms[ownHid]!);
    rcFloor = fs.isEmpty ? 1 : (fs.contains(2) ? 2 : fs.first);
    // Manage → Rates (DECISIONS 2026-10-02).
    screen = 'oMore';
    hist = [];
    sheet = null;
    moreTab = 'rates';
    update(() {});
  }

  void setRoomAc(Room r, bool ac) {
    if (ac && rateDraft![rateKey(true, r.share)] == null) return toastMsg('Add a ${r.share} sharing AC price first.');
    if (!ac && rateDraft![rateKey(false, r.share)] == null) return toastMsg('Add a ${r.share} sharing non-AC price first.');
    update(() => acDraft![r.n] = ac);
  }

  void saveRates() {
    final rs = rooms[ownHid]!;
    // F18 (D8): no ₹0 or blank prices on a room type that has rooms.
    for (final r in rs) {
      final v = rateDraft![rateKey(acDraft![r.n]!, r.share)];
      if (v == null || v < 1000) return toastMsg('Set a price for ${r.share} sharing ${acDraft![r.n]! ? 'AC' : 'non-AC'} (₹1,000 or more).');
    }
    final newAc = rs.where((r) => acDraft![r.n]! && !r.ac).length;
    update(() {
      rates[ownHid] = Map.of(rateDraft!);
      for (final r in rs) {
        r.ac = acDraft![r.n]!;
      }
      applyRates(ownHid);
    });
    toastMsg(newAc > 0 ? 'Saved. The Hostelzy team adds the AC unit to the layout within 48 hours.' : 'Rate card saved. Tenants see the new prices now.');
  }

  /// Rewrites every room's rent from the hostel's rate card.
  void applyRates(String hid) {
    final rc = rates[hid]!;
    for (final r in rooms[hid]!) {
      final v = rc[rateKey(r.ac, r.share)];
      if (v != null) r.rent = v;
    }
  }

  ({int f, int t}) freeOf(String id) {
    var f = 0, t = 0;
    for (final r in rooms[id]!) {
      for (final b in r.beds) {
        t++;
        if (b.state == 'free' && !b.mine) f++;
      }
    }
    return (f: f, t: t);
  }

  ({Bed? b, Room? r}) findBed(String hid, String? id) {
    for (final r in rooms[hid]!) {
      for (final b in r.beds) {
        if (b.id == id) return (b: b, r: r);
      }
    }
    return (b: null, r: null);
  }

  void openPicker() {
    final h = hostelById(hid);
    // F16: carry the Explore room filter into the picker when it applies.
    final f = h.ac && h.hasNon ? fR : 'Any';
    final rs = rooms[hid]!.where((r) => AppState.fits(r, f)).toList();
    final r = rs.where((r) => r.floor == 2 && r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs[0];
    update(() {
      pR = f;
      hist = [...hist, screen];
      screen = 'picker';
      sheet = null;
      floor = r.floor;
      room = r.n;
      bed = null;
    });
  }

  void pickBed(Bed b) {
    if ((b.state != 'free' && b.state != 'soon') || b.mine) {
      toastMsg(b.state == 'held' ? 'Someone is holding this bed right now.' : 'This bed is taken.');
      return;
    }
    update(() {
      bed = bed == b.id ? null : b.id;
      room = b.room;
      floor = b.floor;
    });
  }

  /// F04: the HZ code a booking of the selected bed will get (the tenant's
  /// enquiry code for this hostel and bed, if they already have one).
  String get peekRef => enquiries.where((x) => x.hid == hid && x.bed == bed && x.phone == myPhone).firstOrNull?.ref ?? 'HZ-$_nextRef';

  /// Perks locked into a booking, as shown on the locked-deal card.
  List<String> lockedPerks(DealQuote q, Hostel h) => [
    if (q.hzFee < q.fee) '${fmt(q.hzFee)} monthly',
    if (q.hzExit < q.exit) '${fmt(q.hzExit)} exit only',
    if (q.firstOffNow > 0) '${fmt(firstOff)} off first month',
    if (q.hzAdv < q.adv) '${fmt(q.hzAdv)} advance',
    if (q.join > 0) 'No joining fee',
    if (q.laundry) 'Free laundry weekly',
    '${h.terms.noticeDays} days notice',
  ];

  /// [opt]: `free` (1-hour hold) or `book` (advance paid to the owner, deal
  /// locked, HZ code recorded like an enquiry so F05/F06 see it).
  void placeHold([String? how]) {
    final b = findBed(hid, bed).b;
    if (b == null) return;
    if (activeHolds >= AppState.maxHolds) return toastMsg('You can hold ${AppState.maxHolds} beds at a time. Release one in Holds first.');
    final opt = how ?? holdOpt;
    final r = findBed(hid, bed).r!;
    final h0 = hostelById(hid);
    final q = quote(hid, r.ac, r.share);
    String? ref;
    if (opt == 'book') {
      ref = _record(hid, 'Booked bed ${b.id} with the advance.', bed: b.id, from: 'Book · Pay advance').ref;
    }
    // F17: a booking is "paying" until the owner confirms the advance arrived.
    _bedBefore['$hid|${b.id}'] = b.state;
    b.state = 'held';
    b.mine = true;
    final t = DateTime.now().millisecondsSinceEpoch;
    final id = 'h$t';
    final h = Hold(id: id, hid: hid, bed: b.id, room: b.room, opt: opt, start: t, status: opt == 'free' ? 'waiting' : 'paying', ref: ref, paid: opt == 'book' ? q.hzAdv : 0, perks: opt == 'book' && q.any ? lockedPerks(q, h0) : const []);
    final pay = opt == 'book' ? Payment(id: 'pay$t', kind: 'advance', hid: hid, who: meShort, what: 'Advance for bed ${b.id}', bed: b.id, amt: q.hzAdv, note: ref!, holdId: id) : null;
    update(() {
      holds = [...holds, h];
      if (pay != null) payments = [...payments, pay];
      holdId = id;
      bed = null;
      hist = [...hist, screen];
      screen = 'hold';
      sheet = pay != null ? 'payAdv' : null;
      payId = pay?.id;
    });
    if (pay == null) toastMsg('Hold placed on this phone. Tell ${h0.owner} on WhatsApp so they keep the bed.');
  }
}
