part of '../../state.dart';

// F06
extension ResidentsActions on AppState {

  /// Taken beds at the owner's hostel with nobody added for them.
  List<String> get unassignedBeds => [
    for (final r in rooms[ownHid] ?? const <Room>[])
      for (final b in r.beds)
        if (b.state == 'booked' && !residents.any((x) => x.bed == b.id)) b.id,
  ];

  /// F25: days from today on the one "Add a resident" date field
  /// (negative = joined in the past, positive = moves in later).
  int get rDays => switch (rJoin) {
    'Today' => 0,
    'Yesterday' => -1,
    'Tomorrow' => 1,
    _ => -rPickBack,
  };

  /// F25: a future date is a booking ("Moves in"); today or past is "Joined on".
  bool get rFuture => rDays > 0;

  /// Join (or move-in) time in ms for the add-resident sheet's date.
  int get rJoinAt => now + rDays * 86400000;

  /// Joined via Hostelzy: this phone enquired about, held or booked a bed at
  /// the owner's hostel on Hostelzy within [matchWindowDays] before joining.
  /// (On Supabase the server decides; this is the preview.)
  ({String ref, String what, int at})? matchFor(String phone, int joinAt) {
    if (phone.length != 10) return null;
    final from = joinAt - matchWindowDays * 86400000;
    bool inWin(int t) => t >= from && t <= joinAt + 86400000;
    final e = enquiries.where((e) => e.hid == ownHid && e.phone == phone && inWin(e.at)).firstOrNull;
    if (e != null) return (ref: e.ref, what: 'asked about your hostel', at: e.at);
    if (phone == myPhone) {
      final h = holds.where((h) => h.hid == ownHid && h.status != 'released' && inWin(h.start)).firstOrNull;
      if (h != null) return (ref: 'bed ${h.bed}', what: h.opt == 'book' ? 'booked a bed' : 'held a bed', at: h.start);
    }
    return null;
  }

  Resident _newResident(String name, String phone, String bed, int amt, int adv, int joinAt, {required bool confirmed, bool before = false}) {
    final m = matchFor(phone, joinAt);
    final b = findBed(ownHid, bed).b;
    if (b != null) b.state = 'booked';
    final joined = dayMon(DateTime.fromMillisecondsSinceEpoch(joinAt));
    // F06: residents who came through Hostelzy are added within 3 days of
    // moving in. Later counts as a Fair Play signal (F07).
    final late = m != null ? ((now - joinAt) / 86400000).floor() : 0;
    final lateDays = late > addWithinDays ? late : 0;
    if (lateDays > 0) {
      final id = 'FP-0${143 + cases.length - AppState.seedCaseCount}';
      cases = [
        FairCase(openedAt: DateTime.now().millisecondsSinceEpoch, id: id, hid: ownHid, title: '$name added $lateDays days after moving in', signal: 'Hostelzy resident (${m!.ref}) added after the 3-day limit', status: 'new', resident: bed, events: [CaseEvent(dayMon(DateTime.fromMillisecondsSinceEpoch(m.at)), 'On Hostelzy', 'Tenant ${m.what}'), CaseEvent(joined, 'Moved in', 'Bed $bed'), CaseEvent(dayMon(appToday), 'Added by the owner', '$lateDays days later', flag: true)]),
        ...cases,
      ];
    }
    return Resident(name: name, bed: bed, amt: amt, status: 'Paid', note: 'Paid at move-in', phone: phone, via: m != null ? 'hz' : before ? 'before' : 'direct', since: confirmed ? 'Joined $joined' : 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: confirmed, advance: adv, joinAt: joinAt, lateDays: lateDays);
  }

  /// F25 "Add a resident" (the "+" tab and Residents › Add): the resident is
  /// listed as Not confirmed until they confirm with the invite code. A date
  /// in the future is a booking (moves in later).
  void addResident() {
    final name = rName.trim();
    if (name.length < 2) return toastMsg('Add the resident’s name.');
    if (rPhone.length != 10) return toastMsg('Add their 10-digit WhatsApp number.');
    if (!AppState.validPhone(rPhone)) return toastMsg('That mobile number doesn’t look right (10 digits, 6–9 first).');
    final f = rBed == null ? null : findBed(ownHid, rBed);
    if (f?.b == null) return toastMsg('Pick a bed.');
    if (f!.b!.state == 'booked' && residents.any((x) => x.bed == rBed)) return toastMsg('Bed $rBed is already taken.');
    final future = rFuture;
    final fee = int.tryParse(rFee) ?? 0, adv = int.tryParse(rAdv) ?? 0;
    final before = !future && rBefore && canMarkBefore;
    if (onServer) {
      addStayLive(name, rPhone, rBed!, fee, adv, DateTime.fromMillisecondsSinceEpoch(rJoinAt), booking: future, before: before);
      return;
    }
    final res = _newResident(name, rPhone, rBed!, fee, adv, rJoinAt, confirmed: false, before: before);
    if (future) {
      res.status = 'Due';
      res.note = 'Moves in ${dayMon(appToday.add(Duration(days: rDays)))}';
    }
    update(() {
      residents = [res, ...residents];
      sheet = null;
      resF = 'All';
    });
    toastMsg(res.lateDays > 0
        ? 'Added, ${res.lateDays} days after moving in: that’s past the 3-day limit and goes to Fair Play.'
        : future
        ? 'Booked bed ${res.bed}. Send them a welcome on WhatsApp.'
        : 'Added. ${name.split(' ')[0]} confirms by joining with your invite code.');
  }

  /// Invite QR sign-ups signed in with Google; approving counts them.
  void approveSignup(Signup g) {
    // C: on Supabase the server makes the stay; the list refreshes from it.
    if (onServer) {
      _write(() => data.decideSignup(g.id, true)).then((ok) {
        if (ok) toastMsg('${g.name.split(' ')[0]} is now a resident here.');
      });
      return;
    }
    final r = findBed(ownHid, g.bed).r;
    final res = _newResident(g.name, g.phone, g.bed, r?.rent ?? 0, hostelById(ownHid).terms.advance, now, confirmed: true);
    update(() {
      signups = signups.where((x) => x.id != g.id).toList();
      residents = [res, ...residents];
    });
    toastMsg('${g.name.split(' ')[0]} is now a resident of bed ${g.bed}.');
  }

  void rejectSignup(Signup g) {
    if (onServer) {
      _write(() => data.decideSignup(g.id, false)).then((ok) {
        if (ok) toastMsg('Removed.');
      });
      return;
    }
    update(() => signups = signups.where((x) => x.id != g.id).toList());
    toastMsg('Removed.');
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
    // F24 item 19: an AC room needs an AC unit in its layout (DECISIONS 2026-10-02).
    if (ac && !r.ac && acMissing(ownHid, r)) return toastMsg(acMissingMsg(r));
    update(() => acDraft![r.n] = ac);
  }

  /// F24 item 19: the room's published layout has no AC unit, so it can't be
  /// made AC yet. A room with no layout can (publishing it then needs one).
  bool acMissing(String hid, Room r) {
    final l = liveLayout(hid, r.n);
    return l != null && l.ac == null;
  }

  String acMissingMsg(Room r) => 'Room ${r.label}’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC.';

  void saveRates() {
    final rs = rooms[ownHid]!;
    // F18 (D8): no ₹0 or blank prices on a room type that has rooms.
    for (final r in rs) {
      final v = rateDraft![rateKey(acDraft![r.n]!, r.share)];
      if (v == null || v < 1000) return toastMsg('Set a price for ${r.share} sharing ${acDraft![r.n]! ? 'AC' : 'non-AC'} (₹1,000 or more).');
    }
    // F24 item 19: checked again on saving (and by the server).
    final noUnit = rs.where((r) => acDraft![r.n]! && !r.ac && acMissing(ownHid, r)).firstOrNull;
    if (noUnit != null) return toastMsg(acMissingMsg(noUnit));
    final newAc = rs.where((r) => acDraft![r.n]! && !r.ac).length;
    final msg = newAc > 0 ? 'Saved. When you draw the room’s layout, add its AC unit.' : 'Rate card saved. Tenants see the new prices now.';
    if (onServer) {
      // S3: saved on the server first; the phone follows only if it worked.
      final draft = Map.of(rateDraft!), ac = Map.of(acDraft!), hid = ownHid;
      Future<bool> save() async {
        try {
          await data.saveRates(hid, draft, {for (final r in rs) r.n: (ac: ac[r.n]!, rent: draft[rateKey(ac[r.n]!, r.share)]!)});
        } catch (e) {
          debugPrint('rates: $e');
          // The server's own words for its two rules; anything else is the usual "couldn't save".
          final m = '$e';
          final room = RegExp(r'room (\S+): an AC room needs an AC unit').firstMatch(m)?.group(1);
          toastMsg(room != null
              ? 'Room $room’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC.'
              : m.contains('only the owner')
              ? 'Only the owner can change rates and AC rooms.'
              : 'Couldn’t save it. Check your internet and try again.');
          return false;
        }
        await refreshLive();
        return true;
      }

      save().then((ok) {
        if (!ok) return;
        update(() {
          rates[hid] = draft;
          for (final r in rs) {
            r.ac = ac[r.n]!;
          }
          applyRates(hid);
        });
        toastMsg(msg);
      });
      return;
    }
    update(() {
      rates[ownHid] = Map.of(rateDraft!);
      for (final r in rs) {
        r.ac = acDraft![r.n]!;
      }
      applyRates(ownHid);
    });
    toastMsg(msg);
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
      // F23 (founder): the room plan comes first; the floor view is one tap
      // away. Guests and rooms without a drawn layout start on the floor view.
      mode = signedIn && liveLayout(hid, r.n) != null ? 'room' : 'plan';
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
  List<String> lockedPerks(DealQuote q, Hostel h) => dealPerks(q, h.terms.noticeDays);

  /// [opt]: `free` (1-hour hold) or `book` (advance paid to the owner, deal
  /// locked, HZ code recorded like an enquiry so F05/F06 see it).
  void placeHold([String? how]) {
    final b = findBed(hid, bed).b;
    if (b == null) return;
    // F21 W2: guests sign in here, then the hold goes ahead.
    final opt = how ?? holdOpt;
    if (!needSignIn(opt == 'book' ? 'book' : 'hold', () => placeHold(opt))) return;
    if (activeHolds >= AppState.maxHolds) return toastMsg('You can hold ${AppState.maxHolds} beds at a time. Release one in Holds first.');
    // F24 #16: a bed that just turned free is for Trusted tenants for an hour.
    final first = onServer ? firstLookBlock(b) : null;
    if (first != null) return toastMsg(first);
    final r = findBed(hid, bed).r!;
    final h0 = hostelById(hid);
    final q = quote(hid, r.ac, r.share);
    if (onServer) {
      _placeHoldLive(b, opt, opt == 'book' ? q.hzAdv : 0, opt == 'book' && q.any ? lockedPerks(q, h0) : const [], h0);
      return;
    }
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
    if (pay == null) {
      toastMsg('Hold placed on this phone. Tell ${h0.owner} on WhatsApp so they keep the bed.');
      askPushAfterHold();
    }
  }

  /// S2: the owner adds a resident (or a booking) on the server; the list,
  /// the bed and any Fair Play case come back from it.
  /// F24 #18: the owner may mark "Lived here before Hostelzy" only while the
  /// hostel isn't live yet (the server checks the same).
  bool get canMarkBefore => !hostelById(ownHid).live;

  Future<bool> addStayLive(String name, String phone, String bedLabel, int rent, int advance, DateTime joinedOn, {bool booking = false, bool before = false}) async {
    final b = findBed(ownHid, bedLabel).b;
    if (b?.key == null) {
      toastMsg('Bed $bedLabel isn’t on the server. Pull down to refresh and try again.');
      return false;
    }
    ({String via, int lateDays})? res;
    try {
      res = await data.addStay(hid: ownHid, bedKey: b!.key, name: name, phone: phone, rent: rent, advance: advance, joinedOn: joinedOn, before: before);
    } catch (e) {
      debugPrint('add stay: $e');
      // F24 #18: the server's reason when "before Hostelzy" isn't allowed.
      toastMsg('$e'.contains('joined before Hostelzy')
          ? 'Your hostel is live now, so only the Hostelzy team can mark someone as joined before Hostelzy. Message the team.'
          : 'Couldn’t save it. Check your internet and try again.');
      return false;
    }
    await refreshLive();
    update(() {
      b.state = 'booked';
      sheet = null;
      resF = 'All';
    });
    final first = name.split(' ')[0];
    toastMsg(res.lateDays > 0
        ? 'Added, ${res.lateDays} days after moving in: that’s past the 3-day limit and goes to Fair Play.'
        : booking
        ? 'Booked bed $bedLabel. Send them a welcome on WhatsApp.'
        : 'Added${res.via == 'hz' ? ' (came through Hostelzy)' : res.via == 'before' ? ' as joined before Hostelzy' : ''}. $first confirms by joining with your invite code.');
    return true;
  }

  /// S2: the owner confirms a tenant's free hold.
  void confirmHoldReq(HoldRequest r) {
    final first = r.name.split(' ')[0];
    if (r.hold != null && onServer) {
      _write(() => data.setHoldStatus(r.hold!, 'held')).then((ok) {
        if (ok) toastMsg('Hold confirmed. The tenant sees it in Hostelzy.');
      });
      return;
    }
    if (r.hold != null) {
      setHold(r.hold!, 'confirmed');
    } else {
      update(() => reqs = reqs.where((x) => x.id != r.id).toList());
    }
    toastMsg('Hold confirmed. Let $first know on WhatsApp.');
  }

  /// S2: the owner declines a hold request; the bed is free again.
  void declineHoldReq(HoldRequest r) {
    final h = r.hold == null ? null : holds.where((x) => x.id == r.hold).firstOrNull;
    if (h != null && onServer) return releaseHold(h, msg: 'Declined. Bed ${r.bed} is free again.');
    final b = findBed(ownHid, r.bed).b;
    if (b != null) {
      b.state = 'free';
      b.mine = false;
    }
    if (r.hold != null) {
      setHold(r.hold!, 'released');
    } else {
      update(() => reqs = reqs.where((x) => x.id != r.id).toList());
    }
    toastMsg('Declined. Bed ${r.bed} is free again.');
  }

  /// S1: on Supabase the server places the hold (bed free, at most 2, HZ code)
  /// and a booking starts its advance payment; then the lists are refetched.
  Future<void> _placeHoldLive(Bed b, String opt, int advance, List<String> perks, Hostel h0) async {
    final key = b.key;
    if (key == null) return toastMsg('This bed isn’t on the server. Pull down to refresh and try again.');
    final hostel = hid;
    final ({String id, String ref, String? payId}) res;
    try {
      res = await data.placeHold(hid: hostel, bedKey: key, opt: opt, advance: advance);
    } catch (e) {
      final m = '$e';
      return toastMsg(m.contains('not free any more')
          ? 'Someone just took this bed. Pick another one.'
          : m.contains('2 beds at a time')
          ? 'You can hold ${AppState.maxHolds} beds at a time. Release one in Holds first.'
          : m.contains('Trusted tenants get the first hour')
          ? '${m.substring(m.indexOf('Trusted tenants')).split(RegExp(r'[,}\n]')).first.trim()}.'
          : 'Couldn’t place the hold. Check your internet and try again.');
    }
    await refreshLive();
    update(() {
      // If the refetch failed, show what the server just made.
      if (!holds.any((x) => x.id == res.id)) {
        holds = [...holds, Hold(id: res.id, hid: hostel, bed: b.id, room: b.room, opt: opt, start: DateTime.now().millisecondsSinceEpoch, status: opt == 'free' ? 'waiting' : 'paying', ref: res.ref, paid: opt == 'book' ? advance : 0)];
        if (res.payId != null) payments = [...payments, Payment(id: res.payId!, kind: 'advance', hid: hostel, who: meShort, what: 'Advance for bed ${b.id}', bed: b.id, amt: advance, note: res.ref, holdId: res.id)];
      }
      if (perks.isNotEmpty) holds = [for (final x in holds) x.id == res.id ? x.withPerks(perks) : x];
      b.state = 'held';
      b.mine = true;
      holdId = res.id;
      bed = null;
      hist = [...hist, screen];
      screen = 'hold';
      sheet = res.payId != null ? 'payAdv' : null;
      payId = res.payId;
    });
    if (res.payId == null) {
      toastMsg('Hold placed. ${h0.owner} sees it in Hostelzy and gets a notification.');
      unawaited(askPushAfterHold());
    }
  }

  /// Resident: raise a complaint (C: saved on the server when live).
  Future<void> raiseComplaint() async {
    if (cText.trim().isEmpty) return toastMsg('Tell us what is wrong first.');
    final text = cText.trim();
    final photo = cPhoto;
    if (onServer) {
      final h = myHostel;
      if (h == null) return toastMsg('Your owner hasn’t added you yet. Complaints open once you’re a resident here.');
      final uid = account?.uid;
      final ok = await _write(() async {
        // F21 W3: the photo goes up first, then the complaint points at it.
        final path = photo != null && uid != null ? await data.uploadComplaintPhoto(h, uid, photo) : null;
        await data.raiseComplaint(hid: h, bed: myBedLabel, cat: cCat, body: text, photo: path);
      });
      if (!ok) return;
      update(() {
        cText = '';
        cPhoto = null;
      });
      await refreshLive();
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch;
    update(() {
      complaints = [...complaints, Complaint(id: id, by: '$meShort · 204', cat: cCat, text: text, status: 'Open', date: dayMon(appToday), note: 'Saved on this phone · tell $stayOwner on WhatsApp too', mine: true, at: id)];
      if (photo != null) complaintPhotosLocal[id] = photo;
      cText = '';
      cPhoto = null;
    });
  }

  /// Help: one photo for the complaint (compressed like hostel photos).
  Future<void> pickComplaintPhoto() async {
    final raw = await picker.pick();
    if (raw == null) return;
    final jpg = prepPhoto(raw, 'free');
    if (jpg == null) return toastMsg('That photo didn’t open. Try another one.');
    update(() => cPhoto = jpg);
  }

  /// Owner: open a complaint's photo (a short-lived private link on the server).
  Future<void> openComplaintPhoto(Complaint c) async {
    final local = complaintPhotosLocal[c.id];
    if (local != null) {
      return update(() {
        cPhotoView = c.id;
        sheet = 'cPhoto';
      });
    }
    final path = c.photo;
    if (path == null) return;
    final url = await data.complaintPhotoUrl(path);
    if (url == null) return toastMsg('Couldn’t open the photo. Check your internet and try again.');
    unawaited(openLink(Uri.parse(url), 'the photo'));
  }

  /// Owner: Open → In progress → Resolved (C: saved on the server when live).
  Future<void> advanceComplaint(Complaint c) async {
    const nxs = {'Open': 'In progress', 'In progress': 'Resolved'};
    final next = nxs[c.status];
    if (next == null) return;
    final note = next == 'Resolved' ? 'Fixed by the owner' : 'Owner is on it';
    update(() => complaints = complaints.map((x) => x.id == c.id ? x.copyWith(status: next, note: note) : x).toList());
    if (onServer && c.key != null) await _write(() => data.updateComplaint(c.key!, status: next, note: note));
  }

  /// The resident's bed as shown on complaints (live: not known yet → '').
  // F21 W3: on the server, the resident's own bed (complaints and layout fixes said none).
  String get myBedLabel => onServer ? (myStay?.bed ?? '') : '204';

  /// F25: the one "Add a resident" sheet, from the "+" tab, Residents › Add
  /// or a free bed's "Add tenant to this bed" ([bed] picked for them).
  void openAddResident({String? bed}) => update(() {
    final free = unassignedBeds;
    rName = '';
    rPhone = '';
    rJoin = 'Today';
    rBefore = false;
    rBed = bed ?? (free.isNotEmpty ? free.first : null);
    final r = rBed != null ? findBed(ownHid, rBed).r : null;
    rFee = r != null ? '${r.rent}' : '';
    rAdv = '${hostelById(ownHid).terms.advance}';
    sheet = 'addR';
  });

  void pickResidentBed(String id) => update(() {
    rBed = id;
    final r = findBed(ownHid, id).r;
    if (r != null) rFee = '${r.rent}';
  });
}
