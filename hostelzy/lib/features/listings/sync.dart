part of '../../state.dart';

// F13 backend
mixin _SyncData {

  String delReason = '';

  /// C: deleting (Google confirm + server) is in progress.
  bool deleting = false;

  /// C: the hostel this user lives in on the server (for complaints).
  String? myHostel;

  /// B6: Realtime subscription and its debounce.
  StreamSubscription<String>? _liveSub;
  Timer? _liveWait;

  /// S3: the owner's UPI ID is saved a moment after they stop typing.
  Timer? _upiWait;

  /// S8: hostels this user runs were missing from the listings once (e.g.
  /// loaded before sign-in); they were fetched again.
  bool _staffRefetched = false;
}

extension SyncActions on AppState {

  /// B6: the signed-in user's live holds, enquiries, payments and complaints
  /// replace the lists. Never mixed with samples: on Supabase the lists start
  /// empty (AppState.samples is false).
  void applyLive(LiveRows l) => update(() {
    // F24 item 13: the server's locked deal; before its SQL runs, what this
    // phone saw when booking.
    final perks = {for (final h in holds) if (h.perks.isNotEmpty) h.id: h.perks};
    holds = [for (final h in l.holds) h.perks.isNotEmpty || perks[h.id] == null ? h : h.withPerks(perks[h.id]!)];
    enquiries = l.enquiries;
    payments = l.payments;
    complaints = l.complaints;
    expiredHolds
      ..clear()
      ..addAll(l.expired);
    myHostel = l.myHostel;
    myStayRow = l.myStay;
    signups = l.signups;
    residents = l.residents;
    // S7: the plan comes from the server: real invoices only, and the owner's
    // newest one (or the trial, before the first is issued).
    invoices = l.invoices;
    cases = l.cases;
    // S6: Stay Rewards from the server.
    final rw = l.rewards;
    if (rw != null) {
      member = rw.member;
      memberSince = rw.since;
      rewardUsed = rw.used;
      friendsJoined = rw.friends;
      rewardBalance = rw.balance;
      referred = rw.referred;
      serverRefCode = rw.code ?? serverRefCode;
      ownerCredits
        ..clear()
        ..addAll(rw.ownerCredits);
    }
    fixes = l.fixes;
    fixMutes = l.mutes;
    // F24: notices, moves and refunds.
    moves = l.moves;
    refunds = l.refunds;
    myRefund = l.myRefund;
    // S8: the owner switcher lists the hostels this user runs on the server
    // (those whose rooms are loaded; missing ones are fetched once more).
    final known = [for (final h in l.myHostels) if (rooms.containsKey(h)) h];
    if (known.length < l.myHostels.length && !_staffRefetched) {
      _staffRefetched = true;
      Future.microtask(() async {
        await refreshListings();
        await refreshLive();
      });
    }
    if (known.isNotEmpty || ownerHostels.any((h) => !isSeedHostel(h))) {
      ownerHostels
        ..clear()
        ..addAll(known);
      if (ownerHostels.isNotEmpty && !ownerHostels.contains(ownHid)) {
        ownHid = ownerHostels.first;
        rules = hostelRules[ownHid] != null ? List.of(hostelRules[ownHid]!) : blankRules(hostelById(ownHid).terms);
      }
    }
    syncWalkIns();
    managers
      ..clear()
      ..addAll([for (final m in l.managers) if (m.hid == ownHid) (name: m.name, phone: m.phone, joined: m.joined)]);
    if (rooms[ownHid] != null) {
      final mine = l.invoices.where((i) => i.hid == ownHid).firstOrNull;
      final trial = l.trialEnds[ownHid];
      if (trial != null) planStart = trial.subtract(const Duration(days: trialDays));
      invoice = mine ?? Invoice(ref: 'First invoice', hid: ownHid, beds: planBeds, amt: planPrice, due: trialEnd.add(const Duration(days: 1)));
    }
    // F24: owners' numbers for the hostels this user holds at, asked or lives in.
    final want = {for (final h in l.holds) h.hid, for (final e in l.enquiries) if (e.phone == myPhone) e.hid, ?l.myHostel};
    if (want.any((h) => !ownerPhones.containsKey(h))) Future.microtask(() => loadOwnerPhones(want));
    // F24 item 14: don't ask "Did you join?" again about an answered hold.
    if (endedHold != null) Future.microtask(loadJoinAnswers);
  });

  /// F24: fetches owners' numbers the server lets this user see.
  Future<void> loadOwnerPhones(Iterable<String> hids) async {
    final ask = hids.toSet().toList();
    if (ask.isEmpty || !data.remote) return;
    try {
      final got = await data.ownerContacts(ask);
      if (got.isNotEmpty) {
        update(() {
          for (final e in got.entries) {
            if (e.value.phone.isNotEmpty) ownerPhones[e.key] = e.value.phone;
            if (e.value.wa.isNotEmpty) ownerWhatsApps[e.key] = e.value.wa;
          }
        });
      }
    } catch (e) {
      debugPrint('owner phone: $e');
    }
  }

  /// C: signed in on Supabase with live rows: actions write to the server.
  bool get onServer => _liveSub != null;

  /// Runs a server write, then refetches. False (and says why) if it failed.
  Future<bool> _write(Future<void> Function() f) async {
    try {
      await f();
      await refreshLive();
      return true;
    } catch (e) {
      debugPrint('write: $e');
      toastMsg('Couldn’t save it. Check your internet and try again.');
      return false;
    }
  }

  Future<void> refreshLive() async {
    try {
      final l = await data.live(me: account?.uid);
      if (l != null) {
        applyLive(l);
        // F24 #16, #25: the tenant's level and the resident's electricity.
        unawaited(loadLevel());
        unawaited(loadMyMeter(force: true));
        // F24 #17: the hostels this user only manages.
        if (l.myHostels.isNotEmpty) await loadManagerOf();
      }
      if (liveFailed) update(() => liveFailed = false);
    } catch (e) {
      debugPrint('live: $e');
      update(() => liveFailed = true);
    }
  }

  /// Signed in on Supabase: load the live rows, then refetch whenever one of
  /// them changes (Realtime), at most once per 400 ms.
  Future<void> startLive() async {
    if (account == null) return;
    await refreshLive();
    await _liveSub?.cancel();
    _liveSub = data.changes().listen((_) {
      _liveWait?.cancel();
      _liveWait = Timer(const Duration(milliseconds: 400), refreshLive);
    });
    // F24 #16, #25: now that this is live, the level and the electricity.
    // F24 #18: and whether this account agreed to the Fair Play rules.
    unawaited(loadFairAccepted());
    unawaited(loadLevel());
    unawaited(loadMyMeter(force: true));
  }

  /// C: a tenant's enquiry on the server; the HZ code comes back from it.
  Future<void> enquireLive(String hid, String body, {String? bed, required String from}) async {
    final me = myPhone;
    var ref = enquiries.where((x) => x.hid == hid && x.bed == bed && x.phone == me).firstOrNull?.ref;
    if (ref == null) {
      try {
        ref = await data.sendEnquiry(hid: hid, name: meName.isEmpty ? 'Hostelzy user' : meName, phone: me, bed: bed, source: from, msg: body.replaceFirst(RegExp(r'^Hi [^,]*, '), ''));
        await refreshLive();
      } catch (e) {
        debugPrint('enquiry: $e');
        // F24 4a: one open enquiry per bed on the server; use the one already there.
        if (!'$e'.contains('enquiries_one_open') && !'$e'.contains('23505')) return toastMsg('Couldn’t record your enquiry. Check your internet and try again.');
        await refreshLive();
        ref = enquiries.where((x) => x.hid == hid && x.bed == bed).firstOrNull?.ref;
        if (ref == null) return toastMsg('You already asked the owner about this bed.');
        toastMsg('You already asked about this bed, so it’s the same booking code: $ref.');
      }
    }
    // The enquiry is recorded, so the server now gives this owner's number.
    if (!ownerPhones.containsKey(hid)) await loadOwnerPhones([hid]);
    update(() {
      sheet = 'wa';
      waTo = hostelById(hid).owner;
      waPhone = ownerWa(hid);
      waMsg = body;
      waRef = ref;
      waHid = hid;
    });
  }

  Future<void> markContactedLive(String ref) => _write(() => data.markContacted(ref));
  Future<bool> sendUtrLive(Payment p, String utr) => _write(() => data.sendUtr(p.id, utr));
  Future<bool> confirmPaymentLive(Payment p, bool received) => _write(() => data.confirmPayment(p.id, received, holdId: p.holdId));

  /// S3: the owner types their UPI ID; on Supabase it is saved once it looks
  /// right and they pause.
  void setOwnerUpi(String id, String name) {
    update(() => ownerUpi[ownHid] = (id: id, name: name));
    if (!onServer) return;
    _upiWait?.cancel();
    if (!validUpiId(id)) return;
    final hid = ownHid;
    _upiWait = Timer(const Duration(milliseconds: 1200), () {
      _write(() => data.saveUpi(hid, id, name)).then((ok) {
        if (ok) toastMsg('UPI ID saved. Tenants pay you here.');
      });
    });
  }

  void stopLive() {
    _upiWait?.cancel();
    _liveSub?.cancel();
    _liveSub = null;
    _liveWait?.cancel();
  }

  /// Why the account can't be deleted yet, or null.
  ({String title, String body, String cta, VoidCallback go})? get deleteBlock {
    final h = holds.where((x) => const ['waiting', 'confirmed', 'held', 'paying'].contains(x.status)).firstOrNull;
    if (h != null) {
      return (title: 'You have an open hold', body: 'Your hold on bed ${h.bed} at ${hostelById(h.hid).name} is still open. Cancel it or let it end first.', cta: 'Go to my hold', go: () => update(() {
        holdId = h.id;
        hist = [...hist, screen];
        screen = 'hold';
      }));
    }
    if (role == 'owner' && (invoice.status == 'due' || invoice.status == 'missing')) {
      return (title: 'Your Hostelzy plan is unpaid', body: 'Owners: invoice ${invoice.ref} (${fmt(invoiceAmt)}) is due. Pay it or contact us, then delete.', cta: 'Open invoice', go: () => go('oInvoice'));
    }
    return null;
  }

  bool isDark(Brightness phone) => theme == 'dark' || (theme == 'system' && phone == Brightness.dark);

  /// C: delete account v2. Signed in with Google: confirm with Google, delete
  /// the server data, then the Firebase user. Either way, this phone forgets
  /// everything. Nothing is said to be deleted unless it was.
  Future<void> confirmDelete() async {
    if (deleting) return;
    if (account != null && signIn.available) {
      update(() => deleting = true);
      final fail = await signIn.reauth();
      if (fail != null) {
        update(() => deleting = false);
        return toastMsg(switch (fail) {
          SignInFail.cancelled => 'Not deleted. You closed Google.',
          SignInFail.otherAccount => 'That’s a different Google account. Pick ${account!.email}.',
          _ => 'Couldn’t check with Google. Check your internet and try again.',
        });
      }
      try {
        await data.deleteMyAccount();
        await forgetPushToken();
        await signIn.deleteUser();
      } catch (e) {
        update(() => deleting = false);
        final m = '$e';
        return toastMsg(m.contains('Owners:') ? 'Owners: ask Hostelzy to close or hand over your hostel first.' : 'Couldn’t delete it on the server. Check your internet and try again.');
      }
    }
    stopLive();
    final me = myPhone;
    update(() {
      enquiries = enquiries.where((e) => e.phone != me).toList();
      holds = [];
      saved.clear();
      member = false;
      monthsOnTime = 0;
      rewardUsed = false;
      phone = '';
      otp = '';
      signedIn = false;
      account = null;
      delReason = '';
      deleting = false;
      screen = 'delDone';
      hist = [];
      sheet = null;
    });
    unawaited(store.clear());
  }

  /// F18: logging out forgets everything this phone kept about the user.
  void logOut() {
    forgetPushToken().then((_) => signIn.signOut());
    stopLive();
    final me = phone;
    update(() {
      for (final h in holds.where((h) => h.status != 'released')) {
        if (hostels.any((x) => x.id == h.hid) && findBed(h.hid, h.bed).b?.mine == true) _freeBed(h.hid, h.bed);
      }
      holds = [];
      saved.clear();
      if (me.isNotEmpty) enquiries = enquiries.where((e) => e.phone != me).toList();
      account = null;
      myName = '';
      searchedAreas.clear();
      notif.addAll({'hold': true, 'rent': true, 'beds': false});
      role = 'tenant';
      screen = 'welcome';
      hist = [];
      phone = '';
      otp = '';
      signedIn = false;
      sheet = null;
    });
    store.clear();
    _saved = jsonEncode(snapshot());
  }

  /// Live hostels from the database replace the sample ones for tenants.
  void applyListings(Listings l) => update(() {
    liveListings = true;
    livePos.addAll(l.pos);
    for (final h in l.hostels) {
      hostels.removeWhere((x) => x.id == h.id);
      hostels.add(h);
      rooms[h.id] = l.rooms[h.id]!;
      rates[h.id] = l.rates[h.id]!;
      ownerUpi[h.id] = l.upi[h.id]!;
      stats[h.id] = statsOf(l.reviews[h.id] ?? const []);
      // F24 item 9: the owner's last confirmations on the server; unknown
      // (never "today") until there is one.
      if (h.bedsCheckedAt != null) {
        confirmed[h.id] = daysSince(h.bedsCheckedAt!);
      } else {
        confirmed.remove(h.id);
      }
      if (h.layoutsCheckedAt != null) {
        layoutConfirmed[h.id] = daysSince(h.layoutsCheckedAt!);
      } else {
        layoutConfirmed.remove(h.id);
      }
      // F24 Wave 4d (F03): the rates' last "confirmed by the owner".
      if (h.ratesCheckedAt != null) {
        ratesConfirmedAt[h.id] = h.ratesCheckedAt!;
      } else {
        ratesConfirmedAt.remove(h.id);
      }
      if (h.ratesTracked && h.ratesCheckedAt == null) {
        ratesNeverConfirmed.add(h.id);
      } else {
        ratesNeverConfirmed.remove(h.id);
      }
      layouts[h.id] = l.layouts[h.id] ?? {};
      deals[h.id] = l.deals[h.id] ?? const Deals();
      strikes[h.id] = l.strikes[h.id] ?? 0;
      if (l.standing[h.id] != null) {
        standing[h.id] = l.standing[h.id]!;
      } else {
        standing.remove(h.id);
      }
      if (l.checks[h.id] != null) layoutChecks[h.id] = l.checks[h.id]!;
      if (l.checkers[h.id] != null) hostelCheckers[h.id] = l.checkers[h.id]!;
      if (l.rules[h.id] != null) hostelRules[h.id] = l.rules[h.id]!;
      // F24: "Visited by Hostelzy" is the team's go-live date on the server.
      if (h.visitedOn.isNotEmpty) visited[h.id] = h.visitedOn;
    }
    // S4: the live hostels' reviews replace any earlier copy of them.
    final ids = {for (final h in l.hostels) h.id};
    reviews = [...reviews.where((r) => !ids.contains(r.hid)), for (final h in l.hostels) ...?l.reviews[h.id]];
    // F23: their floor and room things too.
    amenities = [...amenities.where((a) => !ids.contains(a.hid)), for (final h in l.hostels) ...?l.amenities[h.id]];
    // S3: the owner edits their own hostel's rules.
    if (hostelRules[ownHid] != null) {
      rules = List.of(hostelRules[ownHid]!);
    } else if (!isSeedHostel(ownHid) && ids.contains(ownHid)) {
      rules = blankRules(hostelById(ownHid).terms);
    }
    // F24 item 8: the server's walk-in holds on the owner's beds.
    syncWalkIns();
  });

  /// Remote switches: too-old builds must update; maintenance mode.
  void applySettings(RemoteSettings r) => update(() {
    maintUntil = r.maintenanceUntil;
    if (appBuild < r.minBuild || r.maintenanceUntil.isNotEmpty) {
      gateKind = appBuild < r.minBuild ? 'update' : 'maintenance';
      screen = 'gate';
      hist = [];
      sheet = null;
    }
  });
}
