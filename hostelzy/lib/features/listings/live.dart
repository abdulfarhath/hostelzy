// B6: the signed-in user's live rows (holds, enquiries, payments, complaints)
// and Realtime. Row Level Security decides what comes back: tenants get their
// own, owners and managers their hostels', the team everything. A Realtime
// change is only a signal; the app then refetches, so joins (bed labels) and
// the rules stay in one place.

import '../../data.dart';

typedef LiveRows = ({List<Hold> holds, List<Enquiry> enquiries, List<Payment> payments, List<Complaint> complaints, Set<String> expired, String? myHostel});

/// Tables the app listens to (they are in the `supabase_realtime` publication).
const liveTables = ['holds', 'enquiries', 'payments', 'complaints'];

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

/// Server statuses → the app's: an advance hold is a booking ("book"), and an
/// expired hold shows as released (its id goes in [LiveRows.expired]).
Hold holdFromRow(Map<String, dynamic> r) {
  final b = r['beds'] as Map<String, dynamic>?;
  final status = r['status'] as String;
  return Hold(
    id: r['id'] as String,
    hid: r['hostel_id'] as String,
    bed: bedLabel(b),
    room: (b?['rooms'] as Map<String, dynamic>?)?['number'] as int? ?? 0,
    opt: switch (r['opt']) { 'advance' => 'book', final String o => o, _ => 'free' },
    start: _ms(r['started_at']),
    status: status == 'expired' ? 'released' : status,
    ref: r['ref'] as String?,
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
  );
}

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
);

LiveRows liveFromRows({required List<Map<String, dynamic>> holds, required List<Map<String, dynamic>> enquiries, required List<Map<String, dynamic>> payments, required List<Map<String, dynamic>> complaints, String? me, List<Map<String, dynamic>> stays = const []}) => (
  holds: [for (final r in holds) holdFromRow(r)],
  enquiries: [for (final r in enquiries) enquiryFromRow(r)],
  payments: [for (final r in payments) paymentFromRow(r)],
  complaints: [for (final r in complaints) complaintFromRow(r, me: me)],
  expired: {for (final r in holds) if (r['status'] == 'expired') r['id'] as String},
  // The hostel this user lives in (a confirmed, current stay), for complaints.
  myHostel: [for (final r in stays) if (r['user_id'] == me && r['confirmed'] == true && r['left_on'] == null) r['hostel_id'] as String].firstOrNull,
);
