import '../data.dart';

/// F24: a resident's notice or move to another bed, from `move_requests`.
/// [kind]: vacate | swap. [status]: open | accepted | declined | withdrawn.
class MoveReq {
  const MoveReq({required this.id, required this.hid, required this.stayKey, required this.kind, required this.status, this.name = '', this.bed = '', this.lastDay, this.toBed = '', this.reason = '', this.at = 0});
  final String id, hid, stayKey, kind, status, name, bed, toBed, reason;
  final DateTime? lastDay;
  final int at;
}

/// F24: a former resident's advance refund. [status]: due | sent | received | not_received.
class Refund {
  const Refund({required this.stayKey, required this.hid, required this.name, required this.phone, required this.bed, required this.advance, required this.amt, required this.status, required this.leftOn, this.utr = '', this.sentOn});
  final String stayKey, hid, name, phone, bed, status, utr;
  final int advance, amt;
  final DateTime leftOn;

  /// When the owner marked it refunded (board `rRefund`).
  final DateTime? sentOn;
  DateTime get due => leftOn.add(const Duration(days: 7));
}

class Resident {
  Resident({required this.name, required this.bed, required this.amt, required this.status, required this.note, this.phone = '', this.via = 'before', this.since = '', this.ref, this.confirmed = true, this.advance = 3000, this.joinAt, this.lateDays = 0, this.key});
  final String name, bed;

  /// S2: the stay's id on the server (null on sample data).
  final String? key;
  final int amt;
  String status, note;

  /// F06. `phone`: 10 digits. `via`: hz (joined via Hostelzy) | direct |
  /// before (the grandfathered first import). `since`: "Joined 28 Sep" or
  /// "Since Mar 2026". `ref`: the matched HZ code. A resident only counts
  /// once [confirmed] by the WhatsApp code.
  final String phone, via;
  String since;
  final String? ref;
  final int advance;
  bool confirmed;

  /// F06 3-day rule: added this many days after moving in, though they came
  /// through Hostelzy (0 = on time). Shown as Late and a Fair Play signal.
  final int lateDays;

  /// When they moved in (ms), for residents added in the app.
  final int? joinAt;

  /// F24: their last day once notice is accepted or the owner marked it.
  DateTime? leavingOn;

  /// F24 item 13: the deal perks locked when they booked, from the server.
  List<String> perks = const [];

  /// hz | direct | before | wait
  String get tag => confirmed ? via : 'wait';
  Resident copy() => Resident(name: name, bed: bed, amt: amt, status: status, note: note, phone: phone, via: via, since: since, ref: ref, confirmed: confirmed, advance: advance, joinAt: joinAt, lateDays: lateDays, key: key);
}

/// F06: how far back a phone's enquiry, hold or booking counts towards
/// "Joined via Hostelzy" (60 days, decided 2026-10-02).
const matchWindowDays = 60;

/// Owners must add new residents within this many days (F06 rules).
const addResidentDays = 2;

/// F06: a resident who came through Hostelzy is added within 3 days of moving in.
const addWithinDays = 3;

/// The sample resident (Rahul, bed 204-B) joined Anjani Residency on 14 Mar.
const residentJoined = '14 Mar';

const residentJoinDay = 14;

List<Resident> seedResidents() => [
  Resident(name: 'Rahul Varma', bed: '204-B', amt: 8020, status: 'Due', note: dueNote(hostels[0].terms, residentJoinDay), phone: '9000000001', since: 'Since Mar 2026'),
  Resident(name: 'Arjun Reddy', bed: '204-A', amt: 8020, status: 'Paid', note: 'Paid 29 Sep', phone: '9000000010', since: 'Since Jun 2026'),
  Resident(name: 'Sai Kiran', bed: '204-C', amt: 8020, status: 'Paid', note: 'Paid 30 Sep', phone: '9000000011', via: 'hz', since: 'Joined 20 Sep', ref: 'HZ-4712'),
  Resident(name: 'Mohammed Faiz', bed: '101-A', amt: 7600, status: 'Overdue', note: '12 days late', phone: '9000000012', since: 'Since Nov 2025'),
  Resident(name: 'Teja Naidu', bed: '102-B', amt: 8700, status: 'Paid', note: 'Paid 1 Oct', phone: '9000000013', via: 'direct', since: 'Joined 18 Sep'),
  Resident(name: 'Pranav Shetty', bed: '203-A', amt: 8700, status: 'Overdue', note: '4 days late', phone: '9000000014', since: 'Since Feb 2026'),
  Resident(name: 'Nikhil Goud', bed: '301-B', amt: 10100, status: 'Due', note: dueNote(hostels[0].terms, 22), phone: '9000000015', via: 'hz', since: 'Joined 28 Sep', ref: 'HZ-4790'),
  Resident(name: 'Harsha Vardhan', bed: '302-B', amt: 9000, status: 'Paid', note: 'Paid 28 Sep', phone: '9000000016', since: 'Since Jan 2026'),
  // The rest of the first import (grandfathered, "Before Hostelzy").
  for (final (n, b, a, ph, since) in const [
    ('Suresh Babu', '101-C', 7600, '9000000017', 'Since Nov 2025'),
    ('Kiran Kumar', '101-D', 7600, '9000000018', 'Since Apr 2026'),
    ('Venkatesh P', '102-A', 8700, '9000000019', 'Since Dec 2025'),
    ('Srikanth Rao', '104-B', 8700, '9000000020', 'Since May 2026'),
    ('Ajay Varma', '104-C', 8700, '9000000021', 'Since Jul 2026'),
    ('Mahesh Yadav', '201-A', 8700, '9000000022', 'Since Feb 2026'),
    ('Rohit Sharma', '201-B', 8700, '9000000023', 'Since Aug 2026'),
    ('Praveen K', '203-C', 8700, '9000000024', 'Since Jan 2026'),
    ('Anil Kumar', '302-A', 9000, '9000000025', 'Since Mar 2026'),
    ('Ganesh Reddy', '303-B', 7900, '9000000026', 'Since Jun 2026'),
    ('Sunil Naik', '303-C', 7900, '9000000027', 'Since Apr 2026'),
    ('Ramesh Goud', '304-C', 9000, '9000000028', 'Since May 2026'),
  ])
    Resident(name: n, bed: b, amt: a, status: 'Paid', note: 'Paid 1 Oct', phone: ph, since: since),
  // Added by the owner today, waiting for the resident's WhatsApp code.
  Resident(name: 'Ravi Teja', bed: '303-D', amt: 7900, status: 'Paid', note: 'Paid at move-in', phone: '9000000029', via: 'hz', since: 'Added today', ref: 'HZ-4821', confirmed: false),
];

/// F06 board 6: people who scanned the owner's invite QR and verified their
/// phone, waiting for the owner to approve.
class Signup {
  const Signup(this.id, this.name, this.phone, this.bed, this.ago);
  final String id, name, phone, bed, ago;
}

const seedSignups = [Signup('s1', 'Abhishek P', '9000000030', '103-A', '2 h ago'), Signup('s2', 'Naveen Goud', '9000000031', '202-B', '5 h ago')];

class Complaint {
  Complaint({required this.id, required this.by, required this.cat, required this.text, required this.status, required this.date, required this.note, this.mine = false, this.key, this.photo, this.at});
  final int id;

  /// The server's id (uuid) for live complaints; null on sample data.
  final String? key;
  final String by, cat, text, date;
  final bool mine;

  /// F21 W3: the photo's storage path (server) and when it was raised (ms).
  final String? photo;
  final int? at;
  String status, note;
  Complaint copyWith({String? status, String? note}) => Complaint(id: id, by: by, cat: cat, text: text, status: status ?? this.status, date: date, note: note ?? this.note, mine: mine, key: key, photo: photo, at: at);
}

List<Complaint> seedComplaints() => [
  Complaint(id: 1, by: 'Rahul V · 204', cat: 'Geyser', text: 'No hot water in bathroom 2 since Monday.', status: 'In progress', date: '28 Sep', note: 'Plumber booked for Tuesday', mine: true),
  Complaint(id: 2, by: 'Rahul V · 204', cat: 'Wi-Fi', text: 'Drops every night after 11 pm.', status: 'Resolved', date: '20 Sep', note: 'Router replaced', mine: true),
  Complaint(id: 3, by: 'Teja N · 102', cat: 'Cleaning', text: 'Room not swept for three days.', status: 'Open', date: '30 Sep', note: ''),
  Complaint(id: 4, by: 'Faiz M · 101', cat: 'Water', text: 'Low pressure on floor 1 in the mornings.', status: 'Open', date: '1 Oct', note: ''),
];
