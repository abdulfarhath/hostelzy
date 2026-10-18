part of '../../state.dart';

// F29 Part 2 (wave 2): "Ask to join". The owner picks a free bed and a date
// (H48 `askJoin`) and sends a WhatsApp link; the tenant opens it, signs in and
// fills S94 `joinForm` (name, phone, date, ID sent to the owner on WhatsApp);
// the owner reviews in Today › Joining (H49 `joinReview`) and approves: the
// same path as "Add a resident". Hostelzy never stores the ID image or number.
// The Drive option (wave 4) is hidden until `owner_drive` has a row.

/// H48: what the owner picks.
class JoinDraft {
  String? bed;
  String fee = '', adv = '', name = '';

  /// Days from today the tenant moves in (0 = today).
  int days = 0;
}

/// A tenant's filled request, as the owner sees it in Today › Joining.
class JoinReq {
  JoinReq({required this.id, required this.hid, required this.bed, required this.fee, required this.advance, required this.movesIn, required this.name, required this.phone, required this.date, required this.idReceived, this.idFileId, this.token = '', required this.at});
  final String id, hid, bed, name, phone, token;
  final int fee, advance, at;
  final DateTime movesIn, date;
  String idReceived;
  final String? idFileId;

  factory JoinReq.fromRow(Map<String, dynamic> r) {
    final b = r['beds'] as Map<String, dynamic>?;
    final room = b?['rooms'] as Map<String, dynamic>?;
    final label = room == null ? '' : '${room['label'] ?? room['number']}-${b?['letter']}';
    DateTime d(Object? v) => v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();
    return JoinReq(
      id: r['id'] as String,
      hid: r['hostel_id'] as String,
      bed: label,
      fee: (r['fee'] as num?)?.toInt() ?? 0,
      advance: (r['advance'] as num?)?.toInt() ?? 0,
      movesIn: d(r['moves_in']),
      name: r['tenant_name'] as String? ?? '',
      phone: r['tenant_phone'] as String? ?? '',
      date: d(r['tenant_date'] ?? r['moves_in']),
      idReceived: r['id_received'] as String? ?? 'none',
      idFileId: r['id_file_id'] as String?,
      token: r['token'] as String? ?? '',
      at: d(r['filled_at'] ?? r['created_at']).millisecondsSinceEpoch,
    );
  }

  String get first => name.split(' ').first;
}

/// S94: what the link is for, from `join_request_info(token)`.
class JoinInfo {
  JoinInfo({required this.token, required this.id, required this.hid, required this.hostel, required this.owner, required this.bed, required this.fee, required this.advance, required this.movesIn, this.nameHint = '', required this.status, this.taken = false, this.mine = false, this.drive = false, this.ownerPhone = ''});
  final String token, id, hid, hostel, owner, bed, nameHint, status, ownerPhone;
  final int fee, advance;
  final DateTime movesIn;
  final bool taken, mine, drive;

  factory JoinInfo.fromJson(String token, Map<String, dynamic> j) => JoinInfo(
    token: token,
    id: j['id'] as String,
    hid: j['hostel_id'] as String,
    hostel: j['hostel'] as String? ?? '',
    owner: j['owner'] as String? ?? 'your owner',
    bed: j['bed'] as String? ?? '',
    fee: (j['fee'] as num?)?.toInt() ?? 0,
    advance: (j['advance'] as num?)?.toInt() ?? 0,
    movesIn: j['moves_in'] == null ? DateTime.now() : DateTime.parse(j['moves_in'] as String),
    nameHint: j['name_hint'] as String? ?? '',
    status: j['status'] as String? ?? 'sent',
    taken: j['taken'] == true,
    mine: j['mine'] == true,
    // Wave 4 (Build 4): true once the owner connected Google Drive.
    drive: j['drive'] == true,
    ownerPhone: j['owner_phone'] as String? ?? '',
  );

  bool get open => status == 'sent' && !taken;
}

/// The join link the owner sends: opens the app if installed, else W3.
String joinLink(String token) => '$webBase/j/?t=${Uri.encodeQueryComponent(token)}';

mixin _JoinData {
  JoinDraft joinDraft = JoinDraft();

  /// Owner: filled requests waiting for a decision (Today › Joining).
  List<JoinReq>? _joinReqs;
  bool joinBusy = false;

  /// Owner: the request open in H49, and the "ID received on WhatsApp" tick.
  JoinReq? reviewReq;
  bool idTick = false;

  /// Tenant: the request behind S94 and what they typed; [jSent] = done state.
  JoinInfo? joinInfo;
  String jName = '', jPhone = '', jId = 'none';
  DateTime? jDate;
  bool jSent = false;

  /// The last token this owner made (tests and "Link made").
  String? lastJoinToken;
}

extension JoinActions on AppState {

  /// Owner: requests waiting for a decision at this hostel.
  List<JoinReq> get joinReqs => (_joinReqs ??= AppState.samples && !onServer ? _seedJoinReqs() : []).where((r) => r.hid == ownHid || !onServer).toList();

  /// Demo: one pending join request (F29 build note).
  List<JoinReq> _seedJoinReqs() {
    final free = [for (final r in rooms['anjani'] ?? const <Room>[]) for (final b in r.beds) if (b.state == 'free' && !b.mine) b].firstOrNull;
    if (free == null) return [];
    final room = rooms['anjani']!.firstWhere((r) => r.n == free.room);
    final n = DateTime.now().millisecondsSinceEpoch;
    return [JoinReq(id: 'j-demo', hid: 'anjani', bed: free.id, fee: room.rent, advance: hostelById('anjani').terms.advance, movesIn: appToday.add(const Duration(days: 3)), name: 'Ravi Teja', phone: '9000000040', date: appToday.add(const Duration(days: 3)), idReceived: 'whatsapp', token: 'DEMO-J1', at: n - 2 * 3600000)];
  }

  /// Manage › Residents › Ask to join (and S40's "Not on the app yet · Ask to join").
  void openAskJoin({String? bed}) => update(() {
    final free = <String>[for (final r in rooms[ownHid] ?? const <Room>[]) for (final b in r.beds) if ((b.state == 'free' || b.state == 'soon') && !b.mine) b.id];
    joinDraft = JoinDraft()..bed = bed ?? free.firstOrNull;
    final r = joinDraft.bed != null ? findBed(ownHid, joinDraft.bed).r : null;
    joinDraft
      ..fee = r != null ? '${r.rent}' : ''
      ..adv = '${hostelById(ownHid).terms.advance}';
    sheet = 'askJoin';
  });

  void pickJoinBed(String id) => update(() {
    joinDraft.bed = id;
    final r = findBed(ownHid, id).r;
    if (r != null) joinDraft.fee = '${r.rent}';
  });

  /// H48 "Send on WhatsApp": the link is made (on the server), WhatsApp opens
  /// on the owner's phone with the message; the owner picks the chat.
  Future<void> sendAskJoin() async {
    final d = joinDraft;
    final f = d.bed == null ? null : findBed(ownHid, d.bed);
    if (f?.b == null) return toastMsg('Pick a free bed.');
    if (f!.b!.state == 'booked') return toastMsg('Bed ${d.bed} is taken.');
    final fee = int.tryParse(d.fee) ?? 0, adv = int.tryParse(d.adv) ?? 0;
    if (fee < 1000) return toastMsg('Add the monthly fee (₹1,000 or more).');
    if (joinBusy) return;
    final h = hostelById(ownHid);
    final movesIn = appToday.add(Duration(days: d.days));
    String token;
    if (onServer && f.b!.key != null) {
      update(() => joinBusy = true);
      try {
        token = await data.newJoinRequest(bedKey: f.b!.key!, fee: fee, advance: adv, movesIn: movesIn, name: d.name.trim());
      } catch (e) {
        debugPrint('ask join: $e');
        update(() => joinBusy = false);
        return toastMsg('$e'.contains('is taken') ? 'Bed ${d.bed} is taken.' : 'Couldn’t make the link. Check your internet and try again.');
      }
    } else {
      token = 'DEMO-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    }
    update(() {
      joinBusy = false;
      lastJoinToken = token;
      sheet = null;
    });
    final who = d.name.trim().isEmpty ? 'Hi!' : 'Hi ${d.name.trim().split(' ').first}!';
    whatsapp('', '$who Join ${h.name} on Hostelzy for bed ${d.bed}. Fill your details here (2 min): ${joinLink(token)}');
    toastMsg('Link made for bed ${d.bed}. It works for 7 days.');
  }

  /// Deep link `app/j/?t=<token>`: sign in, then S94.
  Future<void> openJoinLink(String token) async {
    final t = token.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]{6,24}$').hasMatch(t)) return toastMsg('That link isn’t a Hostelzy join link.');
    if (!needSignIn('join', () => openJoinLink(t))) return;
    JoinInfo? info;
    if (data.remote && !t.startsWith('DEMO-')) {
      try {
        final j = await data.joinRequestInfo(t);
        if (j != null) info = JoinInfo.fromJson(t, j);
      } catch (e) {
        debugPrint('join info: $e');
        return toastMsg('Couldn’t open the link. Check your internet and try again.');
      }
      if (info == null) return toastMsg('This link isn’t valid any more. Ask your owner for a new one.');
    } else {
      // Demo: a link for a free bed at the sample hostel.
      final free = [for (final r in rooms['anjani']!) for (final b in r.beds) if (b.state == 'free' && !b.mine) b].first;
      final room = rooms['anjani']!.firstWhere((r) => r.n == free.room);
      final h = hostelById('anjani');
      info = JoinInfo(token: t, id: 'demo', hid: 'anjani', hostel: h.name, owner: h.owner, bed: free.id, fee: room.rent, advance: h.terms.advance, movesIn: appToday.add(const Duration(days: 3)), status: 'sent', ownerPhone: ownerPhones['anjani'] ?? '');
    }
    update(() {
      joinInfo = info;
      jName = meName;
      jPhone = myPhone;
      jDate = info!.movesIn;
      jId = info.mine ? 'whatsapp' : 'none';
      jSent = info.status == 'filled' && info.mine;
      if (role == 'owner') role = 'tenant';
      inFindBed = false;
      screen = 'joinForm';
      hist = [homeTab];
      sheet = null;
    });
  }

  /// S94 "Send ID on WhatsApp": the photo goes from the tenant's phone to the
  /// owner's WhatsApp; Hostelzy keeps only the tick.
  void sendIdOnWhatsApp() {
    final i = joinInfo;
    if (i == null) return;
    whatsapp(i.ownerPhone, 'Here is my ID for bed ${i.bed}');
    update(() => jId = 'whatsapp');
  }

  /// S94 "Send to owner".
  Future<void> sendJoinForm() async {
    final i = joinInfo;
    if (i == null) return;
    final name = jName.trim().replaceAll(RegExp(r'\s+'), ' '), phone = jPhone.replaceAll(RegExp(r'\D'), ''), date = jDate ?? i.movesIn;
    if (name.length < 2) return toastMsg('Enter your name.');
    if (!AppState.validPhone(phone)) return toastMsg('Enter your 10-digit phone (6–9 first).');
    if (joinBusy) return;
    if (data.remote && i.id != 'demo') {
      update(() => joinBusy = true);
      try {
        await data.fillJoinRequest(token: i.token, name: name, phone: phone, date: date, idReceived: jId);
      } catch (e) {
        debugPrint('join form: $e');
        update(() => joinBusy = false);
        final m = '$e';
        return toastMsg(m.contains('just taken')
            ? 'This bed was just taken. Ask your owner.'
            : m.contains('valid any more')
            ? 'This link isn’t valid any more. Ask your owner for a new one.'
            : 'Couldn’t send it. Check your internet and try again.');
      }
    } else {
      _joinReqs = [...joinReqs, JoinReq(id: 'j${DateTime.now().millisecondsSinceEpoch}', hid: i.hid, bed: i.bed, fee: i.fee, advance: i.advance, movesIn: i.movesIn, name: name, phone: phone, date: date, idReceived: jId, token: i.token, at: DateTime.now().millisecondsSinceEpoch)];
    }
    update(() {
      joinBusy = false;
      jSent = true;
      if (myName.isEmpty) myName = name;
      if (this.phone.isEmpty) this.phone = phone;
    });
    toastMsg('Sent. ${i.owner} approves it in Hostelzy; we’ll notify you.');
  }

  /// Owner Today: the filled requests from the server (staff only).
  Future<void> loadJoins() async {
    if (!onServer) return;
    try {
      final rows = await data.joinRequests(ownHid);
      update(() => _joinReqs = [for (final r in rows) JoinReq.fromRow(r)]);
    } catch (e) {
      debugPrint('joins: $e');
    }
  }

  void openJoinReview(JoinReq r) => update(() {
    reviewReq = r;
    idTick = false;
    sheet = 'joinReview';
  });

  /// H49 Approve: the stay is made the way "Add a resident" makes it.
  Future<void> approveJoin() async {
    final r = reviewReq;
    if (r == null) return;
    if (r.idReceived == 'whatsapp' && !idTick) return toastMsg('Tick “ID received on WhatsApp” first, or ask again.');
    if (r.idReceived == 'none') return toastMsg('${r.first} hasn’t sent an ID yet. Ask again, or wait.');
    if (onServer) {
      final ok = await _write(() => data.decideJoin(r.id, true));
      if (!ok) return;
      await loadJoins();
      update(() {
        sheet = null;
        reviewReq = null;
      });
      return toastMsg('${r.first} is in bed ${r.bed}. They get a notification.');
    }
    final f = findBed(ownHid, r.bed);
    if (f.b == null || (f.b!.state == 'booked' && residents.any((x) => x.bed == r.bed))) return toastMsg('Bed ${r.bed} is taken.');
    final res = _newResident(r.name, r.phone, r.bed, r.fee, r.advance, r.date.millisecondsSinceEpoch, confirmed: true);
    if (r.date.isAfter(appToday)) {
      res.status = 'Due';
      res.note = 'Moves in ${dayMon(r.date)}';
    }
    update(() {
      residents = [res, ...residents];
      _joinReqs = joinReqs.where((x) => x.id != r.id).toList();
      sheet = null;
      reviewReq = null;
      resF = 'All';
    });
    toastMsg('${r.first} is in bed ${r.bed}. They get a notification.');
  }

  /// H49 Decline.
  Future<void> declineJoin() async {
    final r = reviewReq;
    if (r == null) return;
    if (onServer) {
      final ok = await _write(() => data.decideJoin(r.id, false));
      if (!ok) return;
      await loadJoins();
    } else {
      _joinReqs = joinReqs.where((x) => x.id != r.id).toList();
    }
    update(() {
      sheet = null;
      reviewReq = null;
    });
    toastMsg('Declined. ${r.first} gets a notification.');
  }

  /// H49 Ask again: a push to the tenant and the WhatsApp text from the owner.
  Future<void> askIdAgain() async {
    final r = reviewReq;
    if (r == null) return;
    var phone = r.phone;
    if (onServer) {
      try {
        phone = await data.askIdAgain(r.id);
      } catch (e) {
        debugPrint('ask id again: $e');
        return toastMsg('Couldn’t send it. Check your internet and try again.');
      }
      unawaited(loadJoins());
    }
    update(() {
      r.idReceived = 'none';
      idTick = false;
    });
    whatsapp(phone, 'Please re-send your ID for bed ${r.bed} at ${hostelById(ownHid).name}.');
  }
}
