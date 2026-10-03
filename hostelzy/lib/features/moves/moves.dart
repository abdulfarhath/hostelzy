part of '../../state.dart';

// F24 item 5: notice, moving to another bed and moving out, on the server,
// and the advance refund until the former resident says they got it.
mixin _MoveData {
  /// Notices and moves: a resident's own; the owner's hostels'.
  List<MoveReq> moves = [];

  /// Owner: refunds still open for residents who moved out.
  List<Refund> refunds = AppState.samples ? [Refund(stayKey: 'r-old', hid: 'anjani', name: 'Naveen Goud', phone: '9000000031', bed: '103-B', advance: 3000, amt: 2000, status: 'due', leftOn: appToday.subtract(const Duration(days: 2)))] : [];

  /// A former resident's own refund (shown in Me and on `rRefund`).
  Refund? myRefund;

  /// The owner's refund page: whose, and the UPI reference typed.
  String? refundFor;
  String refundUtr = '';
}

extension MoveActions on AppState {
  MoveReq? _mine(String kind) {
    final k = myStay?.key;
    return moves.where((m) => m.kind == kind && m.status != 'withdrawn' && (k == null || m.stayKey == k || m.stayKey.isEmpty)).firstOrNull;
  }

  /// The resident's latest notice / move request.
  MoveReq? get myNotice => _mine('vacate');

  /// Owner: open requests at their hostel.
  List<MoveReq> get openMoves => [for (final m in moves) if (m.status == 'open' && m.hid == ownHid) m];

  /// Owner: refunds to send (or sent and not received).
  List<Refund> get refundsToDo => [for (final r in refunds) if (r.hid == ownHid && r.status != 'received') r];

  String _moveWords(Object e) {
    final m = '$e';
    for (final k in const ['pick a last day from today on', 'isn\'t free', 'pick a bed in your hostel', 'isn\'t open any more', 'already moved out', 'the UPI reference is 12 digits', 'only residents']) {
      if (m.contains(k)) {
        final i = m.indexOf(k);
        final end = m.indexOf(RegExp(r'[,}\n]'), i);
        final w = m.substring(i, end < 0 ? m.length : end).trim();
        return '${w[0].toUpperCase()}${w.substring(1)}.';
      }
    }
    return 'Couldn’t save it. Check your internet and try again.';
  }

  Future<bool> _moveWrite(Future<void> Function() f) async {
    try {
      await f();
      await refreshLive();
      return true;
    } catch (e) {
      debugPrint('move: $e');
      toastMsg(_moveWords(e));
      return false;
    }
  }

  /// Give notice for [vDate] (one of [leaveDates]); the owner accepts it.
  Future<void> giveNotice() async {
    final days = leaveDays(stayHostel.terms);
    final i = leaveDates(stayHostel.terms).indexOf(vDate);
    final day = days[i < 0 ? 0 : i];
    if (onServer) {
      if (!await _moveWrite(() => data.giveNotice(day, vReason ?? ''))) return;
      update(() => notice = true);
      return toastMsg('Notice sent. $stayOwner accepts it in Hostelzy.');
    }
    update(() {
      notice = true;
      moves = [MoveReq(id: 'n${_nowMs()}', hid: stayHostel.id, stayKey: '', kind: 'vacate', status: 'open', name: meName, bed: myStay?.bed ?? '', lastDay: day, reason: vReason ?? '', at: _nowMs()), ...moves.where((m) => m.kind != 'vacate')];
    });
    toastMsg('Notice sent. $stayOwner accepts it in Hostelzy.');
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Ask to move to [swapBed]; the owner accepts it.
  Future<void> askMove() async {
    final to = swapBed;
    if (to == null) return;
    if (onServer) {
      final key = findBed(stayHostel.id, to).b?.key;
      if (key == null) return toastMsg('That bed isn’t on Hostelzy yet.');
      if (!await _moveWrite(() => data.askMove(key))) return;
      update(() => swapSent = true);
      return toastMsg('Sent. $stayOwner accepts it in Hostelzy.');
    }
    update(() {
      swapSent = true;
      moves = [MoveReq(id: 'm${_nowMs()}', hid: stayHostel.id, stayKey: '', kind: 'swap', status: 'open', name: meName, bed: myStay?.bed ?? '', toBed: to, at: _nowMs()), ...moves.where((m) => m.kind != 'swap')];
    });
    toastMsg('Sent. $stayOwner accepts it in Hostelzy.');
  }

  Future<void> withdrawMove(MoveReq m) async {
    if (onServer) {
      if (!await _moveWrite(() => data.withdrawMove(m.id))) return;
    } else {
      update(() => moves = [for (final x in moves) if (x.id != m.id) x]);
    }
    update(() {
      if (m.kind == 'vacate') notice = false;
      if (m.kind == 'swap') swapSent = false;
    });
    toastMsg(m.kind == 'vacate' ? 'Notice withdrawn.' : 'Request withdrawn.');
  }

  /// Owner: accept or say no to a notice or a move.
  Future<void> answerMove(MoveReq m, bool accept) async {
    final who = m.name.isEmpty ? 'They' : m.name.split(' ').first;
    if (onServer) {
      if (!await _moveWrite(() => data.answerMove(m.id, accept))) return;
    } else {
      update(() {
        moves = [for (final x in moves) x.id == m.id ? MoveReq(id: x.id, hid: x.hid, stayKey: x.stayKey, kind: x.kind, status: accept ? 'accepted' : 'declined', name: x.name, bed: x.bed, lastDay: x.lastDay, toBed: x.toBed, reason: x.reason, at: x.at) : x];
        if (accept && m.kind == 'vacate' && m.lastDay != null) {
          final b = findBed(ownHid, m.bed).b;
          if (b != null) {
            b.state = 'soon';
            b.soon = dayMon(m.lastDay!);
          }
        }
      });
    }
    toastMsg(!accept
        ? '$who is told. Talk to them on WhatsApp.'
        : m.kind == 'vacate'
        ? 'Accepted. Bed ${m.bed} shows free from ${dayMon(m.lastDay ?? appToday)}.'
        : '$who moves to bed ${m.toBed}. New rent from next month.');
  }

  /// Owner: the bed sheet's "Mark as leaving" (no notice in the app).
  Future<void> markLeaving(Resident r, Bed b, DateTime day) async {
    if (onServer && r.key != null) {
      if (!await _moveWrite(() => data.markLeaving(r.key!, day))) return;
    }
    update(() {
      r.leavingOn = day;
      b.state = 'soon';
      b.soon = dayMon(day);
      sheet = null;
    });
    toastMsg('Bed ${b.id} is listed as free from ${dayMon(day)}.');
  }

  /// Owner: they moved out today; the refund is due in 7 days.
  Future<void> movedOut(Resident r, Bed b) async {
    final kept = hostelById(ownHid).terms.maintenance;
    final amt = math.max(0, r.advance - kept);
    if (onServer && r.key != null) {
      if (!await _moveWrite(() => data.movedOut(r.key!))) return;
    } else {
      update(() {
        residents = [for (final x in residents) if (x != r) x];
        b.state = 'free';
        b.soon = '';
        if (amt > 0) refunds = [Refund(stayKey: r.key ?? 'local-${r.bed}', hid: ownHid, name: r.name, phone: r.phone, bed: r.bed, advance: r.advance, amt: amt, status: 'due', leftOn: appToday), ...refunds];
      });
    }
    update(() => sheet = null);
    toastMsg(amt > 0 ? '${r.name.split(' ').first} moved out. Refund ${fmt(amt)} by ${dayMon(appToday.add(const Duration(days: 7)))}.' : '${r.name.split(' ').first} moved out.');
  }

  /// Owner: the refund sheet (board `oRefund`).
  void openRefund(Refund r) => update(() {
    refundFor = r.stayKey;
    refundUtr = '';
    sheet = 'refund';
  });

  /// An owner's number, when the server gave it (F24 item 1).
  String ownerPhoneFor(String hid) => ownerWa(hid);

  /// Former resident: their refund page.
  void openMyRefund() => update(() {
    hist = [...hist, screen];
    screen = 'rRefund';
  });

  Refund? get refundOpen => refunds.where((r) => r.stayKey == refundFor).firstOrNull;

  Future<void> sendRefund() async {
    final r = refundOpen;
    if (r == null) return;
    final u = refundUtr.replaceAll(RegExp(r'\D'), '');
    if (u.length != 12) return toastMsg('The UPI reference is 12 digits.');
    if (onServer) {
      if (!await _moveWrite(() => data.sendRefund(r.stayKey, u))) return;
    } else {
      update(() => refunds = [for (final x in refunds) x.stayKey == r.stayKey ? Refund(stayKey: x.stayKey, hid: x.hid, name: x.name, phone: x.phone, bed: x.bed, advance: x.advance, amt: x.amt, status: 'sent', utr: u, leftOn: x.leftOn, sentOn: appToday) : x]);
    }
    update(() => sheet = null);
    toastMsg('Marked ${fmt(r.amt)} refunded. ${r.name.split(' ').first} is asked to confirm.');
  }

  /// Former resident: "Yes, I got it" / "Not received" (board `rRefund`).
  Future<void> confirmRefund(bool got) async {
    final r = myRefund;
    if (r == null) return;
    if (onServer) {
      if (!await _moveWrite(() => data.confirmRefund(r.stayKey, got))) return;
    }
    update(() => myRefund = got ? null : Refund(stayKey: r.stayKey, hid: r.hid, name: r.name, phone: r.phone, bed: r.bed, advance: r.advance, amt: r.amt, status: 'not_received', utr: r.utr, leftOn: r.leftOn, sentOn: r.sentOn));
    toastMsg(got ? 'Thanks. Glad it’s sorted.' : '${hostelById(r.hid).owner} is told. Talk to them on WhatsApp too.');
    if (got) back();
  }
}
