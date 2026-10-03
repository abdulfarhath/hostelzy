part of '../../state.dart';

// F18 on this phone
mixin _OnPhoneData {

  /// Where the user's own data is kept between launches ([NoStore] in tests).
  Store store = const NoStore();
  String _saved = '';

  /// The user's own name: typed by them (the Google name is only a hint).
  String myName = '';

  /// F24 item 23: Settings › Name, what's typed in the sheet (starts empty).
  String nameDraft = '';

  /// F24 Wave 4c: an owner's WhatsApp number when it isn't their phone
  /// ('' = same as the phone), and what's typed in its sheet.
  String myWa = '', waDraft = '';

  /// F21 W4: the toast's Undo, while it shows.
  VoidCallback? toastUndo;
}

extension OnPhoneActions on AppState {

  /// Display names from the user's own name; never a sample person.
  String get meName => myName.trim();
  String get meFirst => meName.isEmpty ? '' : meName.split(RegExp(r'\s+')).first;

  /// F24 item 23: Settings › Name opens the sheet with an empty field.
  void editName() => update(() {
    nameDraft = '';
    sheet = 'name';
  });

  /// Saves the new name on this phone and, when signed in, on the server.
  Future<void> saveName() async {
    final n = nameDraft.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.length < 2) {
      toastMsg('Enter your name.');
      return;
    }
    final a = account;
    if (a != null && onServer) {
      try {
        await data.saveName(a.uid, n);
      } catch (e) {
        debugPrint('Name: $e');
        toastMsg('Couldn’t save your name. Check your internet and try again.');
        return;
      }
    }
    update(() {
      myName = n;
      nameDraft = '';
      sheet = null;
    });
    toastMsg('Name saved.');
  }

  /// F24 Wave 4c: Settings › WhatsApp (owners): the number tenants and
  /// residents message, when it isn't the phone they call.
  void editWa() => update(() {
    waDraft = myWa;
    sheet = 'waNum';
  });

  /// Saves it on this phone and, when signed in, on the server; '' clears it
  /// (WhatsApp then uses the phone number).
  Future<void> saveWa({bool clear = false}) async {
    final n = clear ? '' : waDraft.replaceAll(RegExp(r'\D'), '');
    if (n.isNotEmpty && n.length != 10) return toastMsg('Enter all 10 digits.');
    final a = account;
    if (a != null && onServer) {
      try {
        await data.saveWhatsApp(a.uid, n == myPhone ? '' : n);
      } catch (e) {
        debugPrint('WhatsApp number: $e');
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
    }
    update(() {
      myWa = n == myPhone ? '' : n;
      waDraft = '';
      sheet = null;
    });
    toastMsg(myWa.isEmpty ? 'WhatsApp uses your phone number.' : 'Saved. Tenants and residents message you on +91 ${phoneSpaced(myWa)}.');
  }

  /// "Asha K." for reviews and payment lines.
  String get meShort {
    final w = meName.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return 'You';
    return w.length == 1 ? w.first : '${w.first} ${w.last[0]}.';
  }

  /// What is remembered on this phone. Sample data never goes in here.
  Map<String, dynamic> snapshot() => {
    'v': 1,
    'signedIn': signedIn,
    'role': role,
    'theme': theme,
    'lang': lang,
    'name': myName,
    'phone': phone,
    'wa': myWa,
    if (account != null) 'account': {'uid': account!.uid, 'name': account!.name, 'email': account!.email},
    'saved': [for (final e in saved.entries) if (e.value) e.key],
    'holds': [
      for (final h in holds) {'id': h.id, 'hid': h.hid, 'bed': h.bed, 'room': h.room, 'opt': h.opt, 'start': h.start, 'status': h.status, 'ref': h.ref, 'paid': h.paid, 'perks': h.perks},
    ],
    'enquiries': [
      for (final e in enquiries.where((e) => phone.isNotEmpty && e.phone == phone)) {'ref': e.ref, 'name': e.name, 'phone': e.phone, 'hid': e.hid, 'bed': e.bed, 'at': e.at, 'from': e.from, 'msg': e.msg},
    ],
    'fairAccepted': fairAccepted,
    'pushAsked': pushAsked,
    'camAsked': camAsked,
    'opens': opens,
    // F24 item 22: the Settings switches and searched areas (also on the profile).
    'notif': notif,
    'areas': searchedAreas,
    // F20: reminders ring from this phone.
    'rem': remJson(),
    // F18 (F5): the owner's house rules stay on the phone; a menu only until it is saved.
    'rules': [for (final r in rules) [r.k, r.v]],
    if (menuDirty ? menuDraft : phoneMenu case final m?) 'menu': [for (final d in m) [d.b, d.l, d.n]],
    // F19: layout fix drafts stay on this phone until they are sent.
    'fixDrafts': {
      for (final e in fixDrafts.entries) e.key: layoutJson(e.value),
      if (_fixLayout != null) '$fixHid|$fixRoom': layoutJson(_fixLayout!.snap()),
    },
  };

  void _persist() {
    final j = jsonEncode(snapshot());
    if (j == _saved) return;
    _saved = j;
    store.save(jsonDecode(j) as Map<String, dynamic>);
  }

  void _prep() {
    if (screen == 'oMore' && moreTab == 'rates' && rateDraft == null) {
      rateDraft = Map.of(rates[ownHid]!);
      acDraft = {for (final r in rooms[ownHid]!) r.n: r.ac};
    }
    final cr = screen == 'compare' && cmpA.isEmpty ? rooms[hid]!.where((r) => layoutOf(hid, r.n) != null && r.beds.where(AppState._open).length >= 2).firstOrNull : null;
    if (cr != null) {
      final r = cr;
      final free = r.beds.where(AppState._open).toList();
      room = r.n;
      floor = r.floor;
      cmpA = free[0].letter;
      cmpB = free[1].letter;
    }
    if (screen == 'picker' || sheet == 'hold') {
      final rs = rooms[hid]!;
      final r = rs.where((r) => r.floor == 2 && r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs[0];
      floor = r.floor;
      room = r.n;
      if (sheet == 'hold') bed = r.beds.where((b) => b.state == 'free').firstOrNull?.id;
    }
    if (screen == 'hold' && holds.isEmpty) {
      final b = rooms['anjani']!.firstWhere((r) => r.n == 202).beds[0];
      b.state = 'held';
      b.mine = true;
      holds = [Hold(id: 'h0', hid: 'anjani', bed: b.id, room: 202, opt: 'free', start: DateTime.now().millisecondsSinceEpoch - 17 * 60000, status: 'waiting')];
      holdId = 'h0';
    }
    if (sheet == 'bed' && obed == null) obed = '204-B';
    if (sheet == 'wa' && waTo == null) _enquire('anjani', 'Hi Srinivas, I found Anjani Residency on Hostelzy. Can I come and see the rooms this evening?', from: 'Hostel page · Ask on WhatsApp');
    if (sheet == 'enq' && enqRef == null) enqRef = 'HZ-4821';
    if (sheet == 'trusted' && trustedReq == null) trustedReq = 'k1';
    // F24 #25: the demo Electricity page starts from last month's sample readings.
    if (screen == 'oMeter' && meterRows[ownHid] == null && AppState.samples) {
      meterRows[ownHid] = sampleMeters(rooms[ownHid] ?? const []);
      meterRate = '8';
    }
    if (screen == 'oMore' && moreTab == 'menu' && menuDraft == null) _fillMenuDraft();
    if (sheet == 'addR' && rBed == null) {
      rBed = unassignedBeds.firstOrNull;
      final r = rBed != null ? findBed('anjani', rBed).r : null;
      rFee = r != null ? '${r.rent}' : '';
      rAdv = '${hostels[0].terms.advance}';
    }
  }

  void toastMsg(String m) {
    _toastTimer?.cancel();
    update(() {
      toast = m;
      toastUndo = null;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2600), () => update(() => toast = null));
  }

  /// F21 W4: "Hold on bed 204-D released · Undo" for 5 seconds.
  void toastWithUndo(String m, VoidCallback undo) {
    _toastTimer?.cancel();
    update(() {
      toast = m;
      toastUndo = undo;
    });
    _toastTimer = Timer(undoSecs, () => update(() {
      toast = null;
      toastUndo = null;
    }));
  }

  void undoToast() {
    final u = toastUndo;
    _toastTimer?.cancel();
    update(() {
      toast = null;
      toastUndo = null;
    });
    u?.call();
  }

  /// F21 W4: Remove saved, with Undo.
  void toggleSaved(String hid) {
    final was = saved[hid] ?? false;
    update(() => saved[hid] = !was);
    if (was) {
      toastWithUndo('Removed ${hostels.any((h) => h.id == hid) ? hostelById(hid).name : 'from saved'}', () => update(() => saved[hid] = true));
    } else {
      toastMsg('Saved on this phone.');
    }
  }

  /// Honest fallback until Google sign-in is set up: nothing leaves the phone.
  void continueOnPhone() => update(() {
    account = null;
    hist = [...hist, screen];
    screen = 'phone';
    sheet = null;
  });
}
