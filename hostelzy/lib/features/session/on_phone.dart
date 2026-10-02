part of '../../state.dart';

// F18 on this phone
mixin _OnPhoneData {

  /// Where the user's own data is kept between launches ([NoStore] in tests).
  Store store = const NoStore();
  String _saved = '';

  /// The user's own name: typed by them (prefilled from Google, editable).
  String myName = '';
}

extension OnPhoneActions on AppState {

  /// Display names from the user's own name; never a sample person.
  String get meName => myName.trim();
  String get meFirst => meName.isEmpty ? '' : meName.split(RegExp(r'\s+')).first;

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
    'name': myName,
    'phone': phone,
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
    // F20: reminders ring from this phone.
    'rem': remJson(),
    // F18 (F5): the owner's house rules and menu stay on the phone.
    'rules': [for (final r in rules) [r.k, r.v]],
    'menu': [for (final d in menu) [d.b, d.l, d.n]],
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
    if (screen == 'rConfirm') {
      cBed = residents.where((r) => !r.confirmed).firstOrNull?.bed;
      cOtp = '';
    }
    if (sheet == 'addR' && rBed == null) {
      rBed = unassignedBeds.firstOrNull;
      final r = rBed != null ? findBed('anjani', rBed).r : null;
      rFee = r != null ? '${r.rent}' : '';
      rAdv = '${hostels[0].terms.advance}';
    }
  }

  void toastMsg(String m) {
    _toastTimer?.cancel();
    update(() => toast = m);
    _toastTimer = Timer(const Duration(milliseconds: 2600), () => update(() => toast = null));
  }
}
