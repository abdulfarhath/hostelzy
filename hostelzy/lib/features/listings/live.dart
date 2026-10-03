// B6: the signed-in user's live rows (holds, enquiries, payments, complaints)
// and Realtime. Row Level Security decides what comes back: tenants get their
// own, owners and managers their hostels', the team everything. A Realtime
// change is only a signal; the app then refetches, so joins (bed labels) and
// the rules stay in one place.

import '../../data.dart';

/// S6: the signed-in user's Stay Rewards from the server (ledger + profile).
typedef Rewards = ({bool member, String since, String? code, bool referred, int balance, int friends, bool used, List<({String hid, String what, int amt})> ownerCredits});

typedef LiveRows = ({List<Hold> holds, List<Enquiry> enquiries, List<Payment> payments, List<Complaint> complaints, Set<String> expired, String? myHostel, List<Signup> signups, List<Resident> residents, List<Invoice> invoices, Map<String, DateTime> trialEnds, List<FairCase> cases, List<String> myHostels, List<({String hid, String name, String phone, bool joined})> managers, List<LayoutFix> fixes, Rewards? rewards, List<({String hid, String uid, String name})> mutes, Resident? myStay, List<MoveReq> moves, List<Refund> refunds, Refund? myRefund});

/// Tables the app listens to (they are in the `supabase_realtime` publication).
const liveTables = ['holds', 'enquiries', 'payments', 'complaints', 'invite_signups', 'stays', 'invoices', 'fair_cases', 'layout_fixes', 'move_requests'];

int _ms(Object? t) => t == null ? 0 : DateTime.parse(t as String).millisecondsSinceEpoch;

/// "204-A" from a bed row joined with its room.
String bedLabel(Map<String, dynamic>? b) {
  if (b == null) return '';
  final r = b['rooms'] as Map<String, dynamic>?;
  return '${r?['label'] ?? r?['number'] ?? ''}-${b['letter']}';
}

Enquiry enquiryFromRow(Map<String, dynamic> r) => Enquiry(
  ref: r['ref'] as String,
  name: r['name'] as String? ?? '',
  phone: r['phone'] as String? ?? '',
  hid: r['hostel_id'] as String,
  bed: r['bed'] as String?,
  at: _ms(r['created_at']),
  from: r['source'] as String? ?? '',
  msg: r['msg'] as String? ?? '',
  contacted: r['contacted'] as bool? ?? false,
);

/// Server statuses → the app's: an advance hold is a booking ("book") that is
/// "paying" until the owner confirms, and an expired hold shows as released
/// (its id goes in [LiveRows.expired]). [paid]: its advance, from payments.
Hold holdFromRow(Map<String, dynamic> r, {int paid = 0}) {
  final b = r['beds'] as Map<String, dynamic>?;
  final status = r['status'] as String;
  return Hold(
    id: r['id'] as String,
    hid: r['hostel_id'] as String,
    bed: bedLabel(b),
    room: (b?['rooms'] as Map<String, dynamic>?)?['number'] as int? ?? 0,
    opt: switch (r['opt']) { 'advance' => 'book', final String o => o, _ => 'free' },
    start: _ms(r['started_at']),
    status: status == 'expired' ? 'released' : (status == 'waiting' && r['opt'] == 'advance' ? 'paying' : status),
    ref: r['ref'] as String?,
    paid: paid,
    trusted: r['trusted'] == true,
    ends: r['expires_at'] == null ? null : _ms(r['expires_at']),
  );
}

Payment paymentFromRow(Map<String, dynamic> r) {
  final kind = r['kind'] as String;
  final hold = r['holds'] as Map<String, dynamic>?;
  final bed = bedLabel(hold?['beds'] as Map<String, dynamic>?);
  return Payment(
    id: r['id'] as String,
    kind: kind,
    hid: r['hostel_id'] as String,
    who: r['payer_name'] as String? ?? 'Tenant',
    what: kind == 'rent' ? 'Rent' : (bed.isEmpty ? 'Advance' : 'Advance for bed $bed'),
    bed: bed,
    amt: r['amount'] as int,
    note: r['note'] as String? ?? '',
    holdId: r['hold_id'] as String?,
    status: switch (r['status']) { 'pending' => 'due', final String s => s, _ => 'due' },
    utr: r['utr'] as String?,
    sent: r['utr'] == null ? null : dayMon(DateTime.parse(r['created_at'] as String).toLocal()),
    done: r['confirmed_at'] == null ? null : dayMon(DateTime.parse(r['confirmed_at'] as String).toLocal()),
    at: _ms(r['created_at']),
  );
}

/// S2: a current stay → the owner's resident row. Rent shows from this
/// stay's latest rent payment; with none it is Due.
Resident residentFromRow(Map<String, dynamic> r, List<Map<String, dynamic>> payments) {
  final rent = [for (final p in payments) if (p['stay_id'] == r['id'] && p['kind'] == 'rent' && p['status'] != 'cancelled') p]..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  final last = rent.firstOrNull;
  final joined = DateTime.parse(r['joined_on'] as String);
  final confirmed = r['confirmed'] as bool? ?? false;
  return Resident(
    name: r['name'] as String,
    bed: bedLabel(r['beds'] as Map<String, dynamic>?),
    amt: r['rent'] as int? ?? 0,
    status: switch (last?['status']) { 'paid' => 'Paid', 'waiting' => 'Waiting', _ => 'Due' },
    note: switch (last?['status']) { 'paid' => 'Confirmed', 'waiting' => 'UPI reference sent · confirm it', 'missing' => 'UPI reference not found', _ => 'No rent payment yet this month' },
    phone: r['phone'] as String? ?? '',
    via: r['via'] as String? ?? 'direct',
    since: confirmed ? 'Joined ${dayMon(joined)}' : 'Added ${dayMon(joined)}',
    ref: r['ref'] as String?,
    confirmed: confirmed,
    advance: r['advance'] as int? ?? 0,
    joinAt: joined.millisecondsSinceEpoch,
    lateDays: r['late_days'] as int? ?? 0,
    key: r['id'] as String,
  )..leavingOn = _day(r['leaving_on']);
}

DateTime? _day(Object? d) => d == null ? null : DateTime.parse(d as String);

/// F24: a notice or move request (with the resident's name and bed when staff read it).
MoveReq moveFromRow(Map<String, dynamic> r) {
  final st = r['stays'] as Map<String, dynamic>?;
  return MoveReq(
    id: r['id'] as String,
    hid: r['hostel_id'] as String,
    stayKey: r['stay_id'] as String? ?? '',
    kind: r['kind'] as String,
    status: r['status'] as String,
    name: st?['name'] as String? ?? '',
    bed: bedLabel(st?['beds'] as Map<String, dynamic>?),
    lastDay: _day(r['last_day']),
    toBed: r['to_bed'] as String? ?? '',
    reason: r['reason'] as String? ?? '',
    at: _ms(r['created_at']),
  );
}

/// F24: a former resident's refund.
Refund refundFromRow(Map<String, dynamic> r) => Refund(
  stayKey: r['id'] as String,
  hid: r['hostel_id'] as String,
  name: r['name'] as String? ?? '',
  phone: r['phone'] as String? ?? '',
  bed: bedLabel(r['beds'] as Map<String, dynamic>?),
  advance: r['advance'] as int? ?? 0,
  amt: r['refund_amount'] as int? ?? 0,
  status: r['refund_status'] as String,
  utr: r['refund_utr'] as String? ?? '',
  leftOn: _day(r['left_on'])!,
  sentOn: r['refund_sent_at'] == null ? null : DateTime.parse(r['refund_sent_at'] as String).toLocal(),
);

/// F24 #25: one room's meter reading for a month (₹ per unit is the owner's).
typedef MeterRow = ({int room, DateTime month, int reading, double rate, int? units, int? people, int? each});

MeterRow meterFromRow(Map<String, dynamic> r) => (
  room: (r['rooms'] as Map<String, dynamic>?)?['number'] as int? ?? r['room'] as int? ?? 0,
  month: DateTime.parse(r['month'] as String),
  reading: r['reading'] as int,
  rate: (r['rate'] as num).toDouble(),
  units: r['units'] as int?,
  people: r['people'] as int?,
  each: r['each_amt'] as int?,
);

/// F24 #16: the tenant's level from the server (`my_level()`).
typedef Level = ({String level, int months, int late});

Level levelFrom(Map<String, dynamic> m) => (level: m['level'] as String? ?? 'none', months: (m['months'] as num?)?.toInt() ?? 0, late: (m['late'] as num?)?.toInt() ?? 0);

/// S7: an owner-plan invoice from the server.
Invoice invoiceFromRow(Map<String, dynamic> r) => Invoice(
  ref: r['ref'] as String,
  hid: r['hostel_id'] as String,
  beds: r['beds'] as int? ?? 0,
  amt: r['amount'] as int? ?? 0,
  due: DateTime.parse(r['due'] as String),
  status: r['status'] as String? ?? 'due',
  utr: r['utr'] as String?,
  late: r['late'] as int? ?? 0,
  checked: r['status'] == 'paid' ? 'confirmed' : null,
  key: r['id'] as String,
);

/// S4: a review from the server. The id is the server's.
Review reviewFromRow(Map<String, dynamic> r) {
  final at = DateTime.parse(r['created_at'] as String).toLocal();
  return Review(
    id: r['id'] as String,
    hid: r['hostel_id'] as String,
    name: r['author_name'] as String? ?? 'Resident',
    stars: r['stars'] as int,
    text: r['body'] as String? ?? '',
    stay: '${r['kind'] == 'exit' ? 'Left' : 'Posted'} ${dayMon(at)}',
    kind: r['kind'] == 'exit' ? 'exit' : '30-day',
    cats: {for (final e in ((r['cats'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
    layout: r['layout'] as String?,
    advance: r['advance'] as String?,
    again: r['again'] as String?,
    reply: r['reply'] as String?,
    replyWhen: r['replied_at'] == null ? null : 'replied ${dayMon(DateTime.parse(r['replied_at'] as String).toLocal())}',
    fresh: r['reply'] == null,
  );
}

/// S4: a hostel's review aggregates, from its reviews: category averages,
/// advance returned in full of those who left, layout accurate % (Mostly = half).
ReviewStats statsOf(List<Review> rs) {
  double avg(String c) {
    final v = [for (final r in rs) if (r.cats[c] != null) r.cats[c]!];
    return v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  }
  final exits = rs.where((r) => r.kind == 'exit' && r.advance != null).toList();
  final lay = [for (final r in rs) if (r.layout != null) r.layout == 'Yes' ? 1.0 : r.layout == 'Mostly' ? .5 : 0.0];
  return ReviewStats([for (final c in reviewCats) avg(c)], exits.where((r) => r.advance == 'all').length, exits.length, lay.isEmpty ? 0 : (100 * lay.reduce((a, b) => a + b) / lay.length).round());
}

/// S5: a Fair Play case from the server. A new case the owner has replied to
/// waits for the team ("decide"); decided and closed cases show as closed.
FairCase caseFromRow(Map<String, dynamic> r) {
  final reply = r['owner_reply'] as String?;
  return FairCase(
    id: r['ref'] as String,
    hid: r['hostel_id'] as String,
    title: r['title'] as String,
    signal: r['signal'] as String,
    status: switch (r['status']) { 'new' => reply != null ? 'decide' : 'new', 'waiting' => 'waiting', _ => 'closed' },
    events: [
      for (final e in (r['events'] as List? ?? const []).cast<Map>()) CaseEvent('${e['on'] ?? ''}', '${e['what'] ?? ''}', '${e['detail'] ?? ''}', flag: e['flag'] == true),
    ],
    resident: r['resident'] as String?,
    ownerReply: reply,
    result: r['decision'] as String?,
    openedAt: _ms(r['created_at']),
    key: r['id'] as String,
    tenantPhoto: r['tenant_photo'] as String?,
    ownerPhoto: r['owner_photo'] as String?,
  );
}

/// S6: Stay Rewards from the profile row and the ledger the user may read
/// (their own entries, and owner credits for hostels they run).
Rewards rewardsFrom(Map<String, dynamic>? p, List<Map<String, dynamic>> ledger, {String? me}) {
  final mine = [for (final e in ledger) if (e['user_id'] == me) e];
  final since = p?['member_since'] == null ? '' : 'Since ${dayMon(DateTime.parse(p!['member_since'] as String).toLocal())} · first stay via Hostelzy';
  return (
    member: p?['member'] as bool? ?? false,
    since: since,
    code: p?['ref_code'] as String?,
    referred: p?['referred_by'] != null,
    balance: mine.fold<int>(0, (a, e) => a + (e['amount'] as int)),
    friends: mine.where((e) => e['kind'] == 'referral_referrer').length,
    used: mine.any((e) => e['kind'] == 'spend'),
    ownerCredits: [
      for (final e in ledger)
        if (e['hostel_id'] != null && (e['kind'] == 'owner_credit' || e['kind'] == 'reversal'))
          (hid: e['hostel_id'] as String, what: e['kind'] == 'reversal' ? e['reason'] as String? ?? 'Reversed' : 'Member reward · ${e['reason'] ?? ''}', amt: e['amount'] as int),
    ],
  );
}

/// F19: a resident's layout fix from the server.
LayoutFix fixFromRow(Map<String, dynamic> r, {String? me}) => LayoutFix(
  id: r['id'] as String,
  hid: r['hostel_id'] as String,
  room: r['room'] as int,
  snap: snapFromJson((r['layout'] as Map).cast<String, dynamic>()),
  at: _ms(r['created_at']),
  note: r['note'] as String? ?? '',
  status: r['status'] as String? ?? 'pending',
  author: () {
    final w = (r['author_name'] as String? ?? '').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    return w.isEmpty ? 'A resident' : (w.length == 1 ? w.first : '${w.first} ${w.last[0]}.');
  }(),
  authorBed: r['author_bed'] as String? ?? '',
  reason: r['reason'] as String?,
  decidedAt: r['decided_at'] == null ? null : _ms(r['decided_at']),
  mine: me != null && r['author_id'] == me,
  baseVersion: r['base_version'] as int? ?? 1,
  kind: r['kind'] as String? ?? 'layout',
  issue: r['issue'] as String?,
  item: r['item'] as String?,
  photo: r['photo'] as String?,
  repair: r['repair'] as String?,
  authorId: r['author_id'] as String? ?? '',
);

/// Complaint ids are uuids on the server; the app keys them by a stable int.
int complaintKey(String uuid) => int.parse(uuid.replaceAll('-', '').substring(0, 8), radix: 16);

Complaint complaintFromRow(Map<String, dynamic> r, {String? me}) => Complaint(
  id: complaintKey(r['id'] as String),
  by: r['bed'] as String? ?? '',
  cat: r['cat'] as String,
  text: r['body'] as String,
  status: r['status'] == 'Fixed' ? 'Resolved' : r['status'] as String,
  date: dayMon(DateTime.parse(r['created_at'] as String).toLocal()),
  note: r['note'] as String? ?? '',
  mine: me != null && r['author_id'] == me,
  key: r['id'] as String,
  photo: r['photo'] as String?,
  at: DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
);

LiveRows liveFromRows({required List<Map<String, dynamic>> holds, required List<Map<String, dynamic>> enquiries, required List<Map<String, dynamic>> payments, required List<Map<String, dynamic>> complaints, String? me, List<Map<String, dynamic>> stays = const [], List<Map<String, dynamic>> signups = const [], List<Map<String, dynamic>> invoices = const [], List<Map<String, dynamic>> plans = const [], List<Map<String, dynamic>> cases = const [], List<Map<String, dynamic>> staff = const [], List<Map<String, dynamic>> managers = const [], List<Map<String, dynamic>> fixes = const [], List<Map<String, dynamic>> mutes = const [], List<Map<String, dynamic>>? profile, List<Map<String, dynamic>> ledger = const [], List<Map<String, dynamic>> moves = const [], int? now}) => (
  holds: [
    for (final r in holds)
      holdFromRow(r, paid: [for (final p in payments) if (p['hold_id'] == r['id'] && p['kind'] == 'advance' && p['status'] != 'cancelled') p['amount'] as int].firstOrNull ?? 0),
  ],
  enquiries: [for (final r in enquiries) enquiryFromRow(r)],
  payments: [for (final r in payments) paymentFromRow(r)],
  complaints: [for (final r in complaints) complaintFromRow(r, me: me)],
  expired: {for (final r in holds) if (r['status'] == 'expired') r['id'] as String},
  // The hostel this user lives in (a confirmed, current stay), for complaints.
  myHostel: [for (final r in stays) if (r['user_id'] == me && r['confirmed'] == true && r['left_on'] == null) r['hostel_id'] as String].firstOrNull,
  // F21: the user's own confirmed stay (bed, rent, joined), for the resident screens.
  myStay: [for (final r in stays) if (r['user_id'] == me && r['confirmed'] == true && r['left_on'] == null) residentFromRow(r, payments)].firstOrNull,
  // C: invite sign-ups waiting for this owner (RLS: staff see their hostel's).
  // S2: the hostels' current residents (RLS: staff see their hostels'), not this user's own stay.
  // S7: owner-plan invoices (RLS: the owner's hostels; the team sees all), newest due first.
  // S8: the hostels this user runs (owner or manager), and the owners' manager invites.
  myHostels: [for (final r in staff) if (r['user_id'] == me) r['hostel_id'] as String],
  rewards: profile == null ? null : rewardsFrom(profile.firstOrNull, ledger, me: me),
  managers: [for (final r in managers) (hid: r['hostel_id'] as String, name: r['name'] as String, phone: r['phone'] as String? ?? '', joined: r['used_by'] != null)],
  fixes: [for (final r in fixes) fixFromRow(r, me: me)],
  // F19 extras: residents whose suggestions are off (staff see their hostel's; a resident sees their own).
  mutes: [for (final r in mutes) (hid: r['hostel_id'] as String, uid: r['user_id'] as String, name: r['name'] as String? ?? '')],
  cases: [for (final r in cases) caseFromRow(r)]..sort((a, b) => (b.openedAt ?? 0).compareTo(a.openedAt ?? 0)),
  invoices: [for (final r in invoices) invoiceFromRow(r)]..sort((a, b) => b.due.compareTo(a.due)),
  trialEnds: {for (final p in plans) if (p['trial_ends'] != null) p['hostel_id'] as String: DateTime.parse(p['trial_ends'] as String)},
  residents: [for (final r in stays) if (r['left_on'] == null && r['user_id'] != me && r['name'] != null) residentFromRow(r, payments)],
  // F24: notices and moves (staff: their hostels'; a resident: their own), newest first.
  moves: [for (final r in moves) moveFromRow(r)],
  // F24: refunds still open for residents who moved out (staff see their hostels').
  refunds: [for (final r in stays) if (r['left_on'] != null && r['user_id'] != me && r['refund_status'] != null && r['refund_status'] != 'received') refundFromRow(r)],
  myRefund: [for (final r in stays) if (r['user_id'] == me && r['left_on'] != null && r['refund_status'] != null && r['refund_status'] != 'received') refundFromRow(r)].firstOrNull,
  signups: [
    for (final r in signups)
      if (r['status'] == 'pending' && r['user_id'] != me)
        Signup(r['id'] as String, r['name'] as String, r['phone'] as String, r['bed'] as String? ?? '', ago((now ?? DateTime.now().millisecondsSinceEpoch) - _ms(r['created_at']))),
  ],
);
