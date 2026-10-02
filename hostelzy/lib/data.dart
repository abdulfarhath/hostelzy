// Sample data and pure helpers, ported 1:1 from the Claude Design prototype
// (project/HostelzyApp.dc.html).

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

class Hostel {
  const Hostel({required this.id, required this.name, required this.gender, required this.area, required this.from, required this.rating, required this.reviews, required this.food, required this.ac, required this.instant, required this.owner, required this.reply, required this.mins, required this.x, required this.y, required this.tags, this.terms = const Terms(), this.onlyAc = false});
  final String id, name, gender, area, owner;
  final int from, reviews, reply;
  final double rating;
  final bool food, ac, instant;
  final Map<String, int> mins;
  final double x, y;
  final List<String> tags;
  final Terms terms;
  // F08: [rating] and [reviews] are the verified-review star rating and count.

  /// F16: [ac] = has AC rooms; [onlyAc] = every room is AC.
  final bool onlyAc;
  bool get hasNon => !ac || !onlyAc;
}

/// How a hostel charges (F02, Hyderabad / Chennai norm): an advance plus the
/// first month at move-in, then only the monthly fee. On leaving the owner
/// keeps [maintenance] from the advance and returns the rest.
///
/// Defaults agreed with the founder on 2026-10-01 (BOARD Q5, Q6): 30 days'
/// notice, fee due on the joining date, electricity extra.
class Terms {
  const Terms({this.advance = 3000, this.maintenance = 1000, this.noticeDays = 30, this.dueOnJoining = true, this.electricityExtra = true});
  final int advance, maintenance, noticeDays;

  /// Monthly fee due on the joining date (true) or on the 1st (false).
  final bool dueOnJoining;
  final bool electricityExtra;

  int get refund => advance - maintenance;

  /// Day of the month the fee is due for someone who joined on [joinDay].
  int dueDay(int joinDay) => dueOnJoining ? joinDay : 1;
}

/// "Today": the real date in India in the Play Store build (F17); the sample
/// data's day (1 Oct 2026) in debug builds and tests, so the samples line up.
/// F18: a getter, so the date moves on while the app stays open overnight.
DateTime get appToday => const bool.fromEnvironment('dart.vm.product') ? _todayIst() : DateTime(2026, 10, 1);

DateTime _todayIst() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(n.year, n.month, n.day);
}

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "October 2026"
String monthYear(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "fan", but "AC unit" keeps its capitals.
String lowerName(String n) => n.length > 1 && n[1].toUpperCase() == n[1] && n[1].toLowerCase() != n[1] ? n : n.toLowerCase();

/// `31 Oct`
String dayMon(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Last-day choices when giving notice today: the earliest day the notice
/// period allows, then 15 and 30 days after it.
List<String> leaveDates(Terms t) => [for (final x in [0, 15, 30]) dayMon(appToday.add(Duration(days: t.noticeDays + x)))];

/// `Due 14 Oct` for a resident who joined on [joinDay].
String dueNote(Terms t, int joinDay) => 'Due ${t.dueDay(joinDay)} ${_months[appToday.month - 1]}';

/// `13 days left`, `due today`.
String dueLeft(Terms t, int joinDay) {
  final n = t.dueDay(joinDay) - appToday.day;
  return n <= 0 ? 'due today' : '$n day${n == 1 ? '' : 's'} left';
}

/// The sample hostels plus any the Hostelzy team put live with Add hostel
/// (F14). In memory only until the backend (F13): [resetSampleData] trims it.
final hostels = <Hostel>[
  Hostel(id: 'anjani', name: 'Anjani Residency', gender: 'Men', area: 'Madhapur', from: 7600, rating: 4.4, reviews: 38, food: true, ac: true, instant: false, owner: 'Srinivas', reply: 12, mins: {'Hitec City': 6, 'Gachibowli': 14, 'Ameerpet': 24, 'JNTU': 20}, x: 40, y: 42, tags: ['3 meals a day', 'AC rooms', 'Power backup', 'Washing machine']),
  Hostel(id: 'saisri', name: 'Sai Sri Ladies Hostel', gender: 'Women', area: 'Kondapur', from: 8200, rating: 4.7, reviews: 52, food: true, ac: false, instant: true, owner: 'Padmavathi', reply: 5, mins: {'Hitec City': 8, 'Gachibowli': 10, 'Ameerpet': 28, 'JNTU': 18}, x: 55, y: 28, tags: ['Biometric entry', 'Warden on site', '3 meals a day', 'CCTV in corridors'], terms: Terms(maintenance: 1500)),
  Hostel(id: 'nest42', name: 'Nest 42 Co-living', gender: 'Co-living', area: 'Gachibowli', from: 10800, rating: 4.2, reviews: 14, food: false, ac: true, instant: true, owner: 'Kavya', reply: 3, mins: {'Hitec City': 14, 'Gachibowli': 5, 'Ameerpet': 32, 'JNTU': 26}, x: 24, y: 62, tags: ['AC rooms', 'Gym', 'Daily housekeeping', 'Workspace'], terms: Terms(maintenance: 1500), onlyAc: true),
  Hostel(id: 'greenview', name: "Greenview Men's PG", gender: 'Men', area: 'Kondapur', from: 6400, rating: 4.1, reviews: 22, food: true, ac: false, instant: false, owner: 'Ramesh', reply: 20, mins: {'Hitec City': 11, 'Gachibowli': 9, 'Ameerpet': 30, 'JNTU': 14}, x: 46, y: 56, tags: ['2 meals a day', 'Hot water 24h', 'Bike parking', 'Weekly laundry']),
  Hostel(id: 'orchid', name: "Orchid Women's PG", gender: 'Women', area: 'KPHB', from: 6900, rating: 4.5, reviews: 31, food: true, ac: false, instant: false, owner: 'Lalitha', reply: 9, mins: {'Hitec City': 20, 'Gachibowli': 25, 'Ameerpet': 16, 'JNTU': 6}, x: 70, y: 18, tags: ['3 meals a day', 'Near metro', 'CCTV at gate', 'Study room'], terms: Terms(maintenance: 1200)),
  Hostel(id: 'lakshmi', name: 'Lakshmi Students PG', gender: 'Men', area: 'Ameerpet', from: 5400, rating: 4.0, reviews: 47, food: true, ac: false, instant: false, owner: 'Venkat', reply: 15, mins: {'Hitec City': 26, 'Gachibowli': 34, 'Ameerpet': 4, 'JNTU': 15}, x: 80, y: 66, tags: ['Near coaching centres', '3 meals a day', 'Study room', 'Wi-Fi 100 Mbps']),
];

/// Number as JavaScript prints it (`4.0` → `4`).
String jsNum(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

/// F18: an id that is no longer listed (removed hostel, stale saved hold)
/// gets a placeholder instead of a crash.
Hostel hostelById(String id) => hostels.firstWhere((h) => h.id == id, orElse: () => Hostel(id: id, name: 'Hostel no longer listed', gender: 'Co-living', area: 'Hyderabad', from: 0, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: const {}, x: 50, y: 50, tags: const []));

const landmarks = ['Hitec City', 'Gachibowli', 'Ameerpet', 'JNTU'];
const landmarkXY = <String, List<double>>{
  'Hitec City': [50, 36],
  'Gachibowli': [16, 72],
  'Ameerpet': [86, 76],
  'JNTU': [78, 8],
};

/// `'₹' + Math.round(n).toLocaleString('en-IN')`
String fmt(num n) {
  final v = n.round();
  final neg = v < 0;
  final s = v.abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '₹${neg ? '-' : ''}$out';
}

const spots = <int, List<String>>{
  2: ['By the window', 'By the door'],
  3: ['By the window', 'Middle', 'By the door'],
  4: ['Window, lower bunk', 'Window, upper bunk', 'Door, lower bunk', 'Door, upper bunk'],
};
const soonDates = ['8 Oct', '12 Oct', '15 Oct', '20 Oct'];

class Bed {
  Bed({required this.id, required this.letter, required this.room, required this.floor, required this.spot, required this.state, required this.soon, this.key});
  final String id, letter, spot;

  /// S1: the bed's id on the server (null on sample data).
  final String? key;
  final int room, floor;

  /// free | held | soon | booked
  String state;
  String soon;
  bool mine = false;
}

class Room {
  Room({required this.n, required this.floor, required this.share, required this.rent, required this.bath, required this.beds, this.ac = false, this.acRepair = false, this.name});
  final int n, floor, share;

  /// The owner's own room number when it isn't a plain number ("204A", F14).
  final String? name;
  String get label => name ?? '$n';
  final String bath;
  final List<Bed> beds;

  /// F16: the rent comes from the hostel's rate card (sharing × AC / non-AC),
  /// so it changes when the owner edits the rate card or the room type.
  int rent;
  bool ac;

  /// AC not working: the room stays AC; tenants see "AC under repair".
  bool acRepair;
  String get type => ac ? 'AC' : 'Non-AC';
}

/// F16 rate-card key: `ac3`, `non2`.
String rateKey(bool ac, int share) => '${ac ? 'ac' : 'non'}$share';

/// Sample rate card: non-AC as before (₹1,100 more per bed fewer), AC
/// ₹1,200 more. Hostels with both kinds have no 4-sharing AC rooms.
Map<String, int> seedRates(Hostel h) => {
  for (final s in [2, 3, 4]) ...{
    if (h.hasNon) rateKey(false, s): h.from + (4 - s) * 1100,
    if (h.ac && (h.onlyAc || s < 4)) rateKey(true, s): h.from + (4 - s) * 1100 + (h.onlyAc ? 0 : 1200),
  },
};

/// Sample room types: AC-only and non-AC-only hostels are uniform; mixed
/// hostels have AC on floors 2 and 3 for 2 and 3 sharing.
bool seedRoomAc(Hostel h, int floor, int share) => h.ac && (h.onlyAc || (floor >= 2 && share <= 3));

/// Rooms per floor (DECISIONS 2026-10-02, "Uneven floors"): floors differ
/// and can be empty. Hostels not listed have 3 floors of 4 rooms (Anjani's
/// rooms stay as they were).
const floorPlans = <String, List<int>>{
  'saisri': [3, 5, 2],
  'greenview': [4, 2],
  'lakshmi': [2, 0, 5],
};

/// Floors that have at least one bed, lowest first.
List<int> floorsOf(List<Room> rooms) => (rooms.where((r) => r.beds.isNotEmpty).map((r) => r.floor).toSet().toList()..sort());

List<Room> mkRooms(Hostel h, int i) {
  var s = i * 977 + 131;
  double rnd() {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  }

  const sh = [2, 3, 4, 3];
  final rates = seedRates(h);
  final out = <Room>[];
  final plan = floorPlans[h.id] ?? const [4, 4, 4];
  for (var f = 1; f <= plan.length; f++) {
    for (var r = 1; r <= plan[f - 1]; r++) {
      final share = sh[(r + f) % 4], n = f * 100 + r;
      final beds = <Bed>[];
      for (var k = 0; k < share; k++) {
        final x = rnd();
        beds.add(
          Bed(
            id: '$n-${'ABCD'[k]}',
            letter: 'ABCD'[k],
            room: n,
            floor: f,
            spot: spots[share]![k],
            state: x < .34
                ? 'free'
                : x < .44
                ? 'held'
                : x < .54
                ? 'soon'
                : 'booked',
            soon: soonDates[(x * 40).floor() % 4],
          ),
        );
      }
      final ac = seedRoomAc(h, f, share);
      out.add(Room(n: n, floor: f, share: share, rent: rates[rateKey(ac, share)]!, ac: ac, bath: r % 2 == 1 ? 'Attached' : 'Shared', beds: beds));
    }
  }
  return out;
}

void _setB(List<Room> rooms, String id, String st) {
  for (final r in rooms) {
    for (final b in r.beds) {
      if (b.id == id) b.state = st;
    }
  }
}

void fixAnjani(List<Room> a) {
  for (final id in ['204-A', '204-B', '204-C', '101-A', '102-B', '203-A', '301-B', '302-B']) {
    _setB(a, id, 'booked');
  }
  for (final id in ['204-D', '201-C', '202-A', '103-B']) {
    _setB(a, id, 'free');
  }
  _setB(a, '203-B', 'soon');
  _setB(a, '102-C', 'held');
  _setB(a, '301-A', 'held');
  a.firstWhere((r) => r.n == 201).acRepair = true;
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

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `Sat 3 Oct`
String dayName(DateTime d) => '${_weekdays[d.weekday - 1]} ${dayMon(d)}';

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

/// F05: a tenant tapped "Ask on WhatsApp" / "WhatsApp owner". Hostelzy
/// records it (HZ code, OTP-verified phone, hostel, bed, time) before
/// WhatsApp opens, so the owner can trust it whatever the tenant types.
class Enquiry {
  Enquiry({required this.ref, required this.name, required this.phone, required this.hid, this.bed, required this.at, required this.from, required this.msg, this.contacted = false});
  final String ref, name, phone, hid, from, msg;

  /// Bed asked about; null = "Any bed".
  final String? bed;

  /// Time in ms since epoch.
  final int at;
  final bool contacted;
  Enquiry withContacted() => Enquiry(ref: ref, name: name, phone: phone, hid: hid, bed: bed, at: at, from: from, msg: msg, contacted: true);
}

List<Enquiry> seedEnquiries(int now) => [
  Enquiry(ref: 'HZ-4821', name: 'Ravi Teja', phone: '9000000029', hid: 'anjani', bed: '204-A', at: now - 6 * 60000, from: 'Hostel page · Ask on WhatsApp', msg: 'Can I come and see the rooms this evening?'),
  Enquiry(ref: 'HZ-4817', name: 'Sandeep Kumar', phone: '9000000032', hid: 'anjani', bed: '201-C', at: now - 18 * 60000, from: 'Hold · WhatsApp owner', msg: 'Can I come and see it today at 6 pm?'),
  Enquiry(ref: 'HZ-4809', name: 'Imran Shaikh', phone: '9000000033', hid: 'anjani', at: now - 2 * 3600000, from: 'Hostel page · Ask on WhatsApp', msg: 'Is there a bed free from 5 Oct?', contacted: true),
];

/// "6 min ago", "2 h ago".
String ago(int ms) {
  final m = ms ~/ 60000;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  return h < 24 ? '$h h ago' : '${h ~/ 24} d ago';
}

/// "Today, 6:42 pm"
String clockTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return 'Today, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

class HoldRequest {
  HoldRequest({required this.id, required this.name, required this.bed, required this.type, required this.secs, required this.note, required this.start, this.hold, this.trusted = false});
  final String id, name, bed, type, note;
  final int secs, start;
  final String? hold;

  /// F09: the tenant is a Trusted tenant (owners see the badge, not where they stayed).
  final bool trusted;
}

List<HoldRequest> seedRequests(int now) => [HoldRequest(id: 'k1', name: 'Karthik M', bed: '102-C', type: 'Free hold', secs: 2460, note: 'Can I visit at 6 pm today?', start: now, trusted: true), HoldRequest(id: 'v1', name: 'Vamsi Reddy', bed: '301-A', type: 'Free hold', secs: 3180, note: 'Joining Infosys on 12 Oct.', start: now)];

class Complaint {
  Complaint({required this.id, required this.by, required this.cat, required this.text, required this.status, required this.date, required this.note, this.mine = false, this.key});
  final int id;

  /// The server's id (uuid) for live complaints; null on sample data.
  final String? key;
  final String by, cat, text, date;
  final bool mine;
  String status, note;
  Complaint copyWith({String? status, String? note}) => Complaint(id: id, by: by, cat: cat, text: text, status: status ?? this.status, date: date, note: note ?? this.note, mine: mine, key: key);
}

List<Complaint> seedComplaints() => [
  Complaint(id: 1, by: 'Rahul V · 204', cat: 'Geyser', text: 'No hot water in bathroom 2 since Monday.', status: 'In progress', date: '28 Sep', note: 'Plumber booked for Tuesday', mine: true),
  Complaint(id: 2, by: 'Rahul V · 204', cat: 'WiFi', text: 'Drops every night after 11 pm.', status: 'Resolved', date: '20 Sep', note: 'Router replaced', mine: true),
  Complaint(id: 3, by: 'Teja N · 102', cat: 'Cleaning', text: 'Room not swept for three days.', status: 'Open', date: '30 Sep', note: ''),
  Complaint(id: 4, by: 'Faiz M · 101', cat: 'Water', text: 'Low pressure on floor 1 in the mornings.', status: 'Open', date: '1 Oct', note: ''),
];

class DayMenu {
  const DayMenu(this.b, this.l, this.n);
  final String b, l, n;
  String of(String k) => k == 'b'
      ? b
      : k == 'l'
      ? l
      : n;
  DayMenu withMeal(String k, String v) => DayMenu(k == 'b' ? v : b, k == 'l' ? v : l, k == 'n' ? v : n);
}

const seedMenu = [
  DayMenu('Idli, sambar, coconut chutney', 'Rice, dal, bendakaya fry, curd', 'Chapati, paneer butter masala'),
  DayMenu('Upma, banana', 'Rice, sambar, cabbage poriyal', 'Egg curry, rice, rasam'),
  DayMenu('Poori, aloo curry', 'Veg biryani, raita', 'Chapati, dal tadka, salad'),
  DayMenu('Pesarattu, ginger chutney', 'Rice, tomato pappu, aloo fry, curd', 'Chicken curry or paneer, chapati'),
  DayMenu('Dosa, peanut chutney', 'Rice, rasam, beans fry', 'Veg fried rice, gobi manchurian'),
  DayMenu('Pongal, vada', 'Lemon rice, curd rice, papad', 'Chapati, chana masala'),
  DayMenu('Aloo paratha, curd', 'Chicken biryani or veg biryani', 'Khichdi, pickle'),
];

const meals = [
  ['b', 'Breakfast', '7:30 – 9:30'],
  ['l', 'Lunch', '12:30 – 2:00'],
  ['n', 'Dinner', '8:00 – 10:00'],
];
const weekDays = [
  ['Mon', '28'],
  ['Tue', '29'],
  ['Wed', '30'],
  ['Thu', '1'],
  ['Fri', '2'],
  ['Sat', '3'],
  ['Sun', '4'],
];

class Rule {
  const Rule(this.k, this.v);
  final String k, v;
}

List<Rule> seedRules(Terms t) => [
  const Rule('Gate closes', '10:30 pm'),
  const Rule('Visitors', 'Common area only, till 8 pm'),
  Rule('Notice period', '${t.noticeDays} days'),
  Rule('Advance', '${fmt(t.advance)} at move-in'),
  Rule('Exit maintenance', '${fmt(t.maintenance)} kept from the advance'),
  Rule('Fee due', t.dueOnJoining ? 'Every month on the joining date' : 'On the 1st of every month'),
  Rule('Electricity', t.electricityExtra ? 'Extra, split by room meter' : 'Included in the fee'),
  const Rule('Quiet hours', '11 pm – 6 am'),
];

/// Hostel page rule rows for [h].
List<List<String>> moneyRules(Hostel h) => [
  ['Notice period', '${h.terms.noticeDays} days'],
  ['Advance', '${fmt(h.terms.advance)} + first month at move-in'],
  ['Exit maintenance', '${fmt(h.terms.maintenance)} kept from the advance'],
  ['Fee due', h.terms.dueOnJoining ? 'Every month on your joining date' : 'On the 1st of every month'],
  ['Electricity', h.terms.electricityExtra ? 'Extra, split by room meter' : 'Included in the fee'],
];

const homeOf = {'tenant': 'explore', 'resident': 'rHome', 'owner': 'oToday'};

class HoldOption {
  const HoldOption(this.title, this.sub, this.amt, this.note, this.cta);
  final String title, sub, amt, note, cta;
}

/// F04: two ways to take a bed. The ₹299 paid hold and the ₹2,000 token are
/// gone (DECISIONS 2026-10-02): book by paying the advance straight to the
/// owner, or hold free for an hour.
const holdOptions = <String, HoldOption>{
  'free': HoldOption('Free hold', 'Held for 1 hour. The owner confirms before it is yours.', '₹0', 'If the owner does not confirm within the hour, the bed is released. You pay nothing.', 'Hold free'),
  'book': HoldOption('Booked with advance', 'Advance paid to the owner. The bed is yours.', '', 'Paid by UPI straight to the owner. Hostelzy never holds your money.', 'Pay advance'),
};

/// Free hold length; Members (F09) get 2 hours.
const freeHoldSecs = 3600, memberHoldSecs = 7200;

// ------------------------------------------------------------ F09 Stay Rewards

/// ₹100 off the next Hostelzy hostel's first month (given by the owner,
/// credited on the owner's next Hostelzy invoice) and ₹100 per referral.
const memberReward = 100, referralReward = 100;

/// Trusted tenant after this many months, rent on time, no owner complaints.
const trustedMonths = 6;

class Hold {
  Hold({required this.id, required this.hid, required this.bed, required this.room, required this.opt, required this.start, required this.status, this.ref, this.paid = 0, this.perks = const []});
  final String id, hid, bed, opt;
  final int room, start;

  /// F04 booking: HZ code, advance paid to the owner, and the locked deal.
  final String? ref;
  final int paid;
  final List<String> perks;

  /// waiting | confirmed | held | booked | released
  final String status;
  Hold withStatus(String s) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: s, ref: ref, paid: paid, perks: perks);
  Hold withPerks(List<String> p) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: status, ref: ref, paid: paid, perks: p);
}

/// Countdown text, `cd()` in the prototype.
String cd(num t) {
  final v = t < 0 ? 0 : t.floor();
  final h = v ~/ 3600, m = (v % 3600) ~/ 60, x = v % 60;
  return '${h > 0 ? '$h:${m.toString().padLeft(2, '0')}' : '$m'}:${x.toString().padLeft(2, '0')}';
}

/// `s.replace(/(\d{5})(\d{0,5})/, '$1 $2')`
String phoneSpaced(String s) => s.replaceFirstMapped(RegExp(r'(\d{5})(\d{0,5})'), (m) => '${m[1]} ${m[2]}');

String initials(String n) {
  final s = n.split(' ').map((w) => w.isEmpty ? '' : w[0]).join();
  return s.length > 2 ? s.substring(0, 2) : s;
}

// ------------------------------------------------------------ F03 deals

/// The owner's deal menu (F03). Amounts are fixed for now.
const monthlyOff = 200, firstOff = 500, advanceOff = 1000, exitHz = 500, joiningFee = 1000, laundryCost = 50;

const dealMenu = ['exit', 'monthly', 'first', 'advance', 'laundry', 'noadmin'];

/// Max active deals per owner (DECISIONS 2026-10-02).
const maxDeals = 3;

const dealTitle = {
  'exit': 'Lower exit maintenance',
  'monthly': 'Monthly fee discount',
  'first': 'First month off',
  'advance': 'Lower advance',
  'laundry': 'Free extra',
  'noadmin': 'No joining fee',
};

/// Short perk labels for chips and the locked-deal card.
String dealPerk(String id) => switch (id) {
  'exit' => '${fmt(exitHz)} exit',
  'monthly' => '${fmt(monthlyOff)} off monthly',
  'first' => '${fmt(firstOff)} off first month',
  'advance' => '${fmt(advanceOff)} lower advance',
  'laundry' => 'Free laundry',
  _ => 'No joining fee',
};

/// A hostel's published deals: which ones, which room types (all | ac |
/// non, F16) and when the owner last confirmed them.
class Deals {
  const Deals({this.on = const {}, this.target = 'all', this.confirmed = '1 Oct'});
  final Set<String> on;
  final String target, confirmed;
  bool covers(bool ac) => on.isNotEmpty && (target == 'all' || (target == 'ac') == ac);
  String get targetText => switch (target) {
    'ac' => 'AC rooms only',
    'non' => 'non-AC rooms only',
    _ => 'all rooms',
  };

  /// One-line summary: "₹200 off every month".
  String get summary => on.contains('monthly') ? '${fmt(monthlyOff)} off every month' : on.isEmpty ? '' : dealPerk(dealMenu.firstWhere(on.contains));
}

final seedDeals = <String, Deals>{
  'anjani': const Deals(on: {'exit', 'monthly', 'laundry'}),
  'saisri': const Deals(on: {'exit', 'advance'}),
  'greenview': const Deals(on: {'first', 'exit'}),
  'orchid': const Deals(on: {'monthly'}, target: 'non'),
};

/// Walk-in vs Hostelzy prices for one room type at one monthly [fee].
class DealQuote {
  DealQuote(Terms t, this.fee, Set<String> on)
    : hzFee = fee - (on.contains('monthly') ? monthlyOff : 0),
      adv = t.advance,
      hzAdv = t.advance - (on.contains('advance') ? advanceOff : 0),
      exit = t.maintenance,
      hzExit = on.contains('exit') && t.maintenance > exitHz ? exitHz : t.maintenance,
      join = on.contains('noadmin') ? joiningFee : 0,
      firstOffNow = on.contains('first') ? firstOff : 0,
      laundry = on.contains('laundry');
  final int fee, hzFee, adv, hzAdv, exit, hzExit, join, firstOffNow;
  final bool laundry;

  int get hzFirst => hzFee - firstOffNow;
  int get move => adv + fee + join;
  int get hzMove => hzAdv + hzFirst;
  int get back => adv - exit;
  int get hzBack => hzAdv - hzExit;

  /// Saving over the first 6 months (DECISIONS: the headline).
  int get save6 => (6 * fee + join) - (5 * hzFee + hzFirst);
  int get upfront => move - hzMove;
  int get moreBack => hzExit < exit ? exit - hzExit : 0;
  bool get any => hzFee != fee || hzAdv != adv || hzExit != exit || join > 0 || firstOffNow > 0 || laundry;

  /// Explore ribbon text.
  String get ribbon => save6 > 0
      ? 'Save ${fmt(save6)} in 6 mo'
      : upfront > 0
      ? '${fmt(upfront)} less upfront'
      : moreBack > 0
      ? '${fmt(moreBack)} more back'
      : 'Hostelzy deal';
}

// ------------------------------------------------------------ F08 reviews

const reviewCats = ['Food', 'Cleanliness', 'Safety', 'Water and power', 'Owner'];

/// A review from a resident with a confirmed stay (one per stay).
class Review {
  Review({required this.id, required this.hid, required this.name, required this.stars, required this.text, required this.stay, this.kind = '30-day', this.cats = const {}, this.layout, this.advance, this.again, this.reply, this.replyWhen, this.fresh = false});
  final String id, hid, name, text, stay, kind;
  final int stars;
  final Map<String, int> cats;

  /// "Is the room layout accurate?" Yes | Mostly | No (F12).
  final String? layout;

  /// Exit review: did the advance come back? all | part | not.
  final String? advance, again;
  String? reply, replyWhen;

  /// Not yet seen by the owner.
  bool fresh;
}

List<Review> seedReviews() => [
  Review(id: 'r1', hid: 'anjani', name: 'Karthik M.', stars: 5, text: 'Clean rooms, good food on weekdays. Got my ₹2,000 back the day I left.', stay: 'Stayed 8 months · left Aug 2026', kind: 'exit', advance: 'all', again: 'Yes'),
  Review(id: 'r2', hid: 'anjani', name: 'Naveen G.', stars: 3, text: 'Water pressure drops after 9 pm on the 2nd floor.', stay: 'Staying since Jun 2026', reply: 'Thanks Naveen. We’re fitting a booster pump on 10 Oct.', replyWhen: 'replied 3 days later'),
  Review(id: 'r3', hid: 'anjani', name: 'Teja N.', stars: 4, text: 'Room not swept for a few days in September, fixed after I complained.', stay: 'Staying since Sep 2026', fresh: true),
  Review(id: 'r4', hid: 'anjani', name: 'Arjun R.', stars: 5, text: 'Got my advance back the same day. Would stay again.', stay: 'Left Sep 2026', kind: 'exit', advance: 'all', again: 'Yes', fresh: true),
];

/// Per-hostel review aggregates from the sample data (category averages,
/// advance returned in full of those who left, layout accurate %).
class ReviewStats {
  const ReviewStats(this.cats, this.advFull, this.advLeft, this.layoutPct);
  final List<double> cats;
  final int advFull, advLeft, layoutPct;
}

const seedStats = <String, ReviewStats>{
  'anjani': ReviewStats([4.5, 3.9, 4.7, 4.1, 4.4], 35, 36, 92),
  'saisri': ReviewStats([4.6, 4.8, 4.9, 4.5, 4.7], 41, 41, 95),
  'nest42': ReviewStats([3.6, 4.5, 4.4, 4.6, 4.0], 9, 10, 88),
  'greenview': ReviewStats([4.2, 3.8, 4.3, 3.9, 4.2], 17, 19, 81),
  'orchid': ReviewStats([4.5, 4.4, 4.8, 4.2, 4.6], 24, 25, 90),
  'lakshmi': ReviewStats([4.1, 3.7, 4.2, 3.8, 4.0], 38, 44, 76),
};

/// F08 ranking factors and weights (DECISIONS 2026-10-02): verified reviews
/// 50%, reply speed 15%, beds kept up to date 15%, complaints resolved 10%,
/// listing complete 10%. Fair Play strikes lower the rank. The number itself
/// is never shown.
const rankWeights = <String, double>{'reviews': .5, 'reply': .15, 'fresh': .15, 'complaints': .1, 'listing': .1};

const rankLabel = {'reviews': 'Verified reviews', 'reply': 'Reply speed', 'fresh': 'Beds kept up to date', 'complaints': 'Complaints resolved', 'listing': 'Listing complete'};

/// Sample values (0–1) for the factors not derived from reviews or reply time.
const seedFactors = <String, Map<String, double>>{
  'anjani': {'fresh': .8, 'complaints': .7, 'listing': .8},
  'saisri': {'fresh': .6, 'complaints': .85, 'listing': .5},
  'nest42': {'fresh': .9, 'complaints': .75, 'listing': .9},
  'greenview': {'fresh': .75, 'complaints': .9, 'listing': .9},
  'orchid': {'fresh': .6, 'complaints': .7, 'listing': .7},
  'lakshmi': {'fresh': .5, 'complaints': .6, 'listing': .5},
};

/// Owner tips per factor.
const rankTips = {'fresh': 'Confirm free beds when we ask, every 3 days', 'complaints': 'Fix complaints within 3 days', 'listing': 'Add layouts for every room type'};

String rankWord(double v) => v >= .85 ? 'Strong' : v >= .7 ? 'Good' : 'Can improve';

const rankReason = {'reviews': 'great reviews', 'reply': 'quick replies', 'fresh': 'beds kept up to date', 'complaints': 'complaints resolved fast', 'listing': 'full listing'};

// ------------------------------------------------------------ F07 Fair Play

/// Owners' phone numbers: tenants see them only after a hold (DECISIONS).
final ownerPhones = <String, String>{'anjani': '9000000101', 'saisri': '9000000102', 'nest42': '9000000103', 'greenview': '9000000104', 'orchid': '9000000105', 'lakshmi': '9000000106'};

/// "98••• •••••"
String maskPhone(String p) => p.length < 2 ? '••••• •••••' : '${p.substring(0, 2)}••• •••••';

const fairRules = [
  ('Add every resident within 3 days', 'Name and phone. That is how a stay counts as Via Hostelzy or Direct.'),
  ('Never take a Hostelzy tenant off the app', 'Don’t ask them to cancel a hold or pay you outside the booking.'),
  ('Honour the deal and exit rules', 'The price, advance and maintenance shown at booking.'),
  ('Keep beds and prices up to date', 'Confirm free beds when we ask, every 3 days.'),
];

/// Strike ladder (DECISIONS 2026-10-02). No fines.
const strikeLadder = [('Strike 1', 'Warning', 'Nothing changes yet'), ('Strike 2', 'Deals hidden', 'For 30 days'), ('Strike 3', 'Removed', 'From Hostelzy')];

/// One dated fact from Hostelzy's own records.
class CaseEvent {
  const CaseEvent(this.date, this.title, this.sub, {this.flag = false});
  final String date, title, sub;
  final bool flag;
}

/// A Fair Play case: new → waiting (48 h for the owner) → decide → closed.
class FairCase {
  FairCase({required this.id, required this.hid, required this.title, required this.signal, required this.status, this.events = const [], this.resident, this.ownerReply, this.tenantNote, this.result, this.hoursLeft = 47.2, this.openedAt, this.key});
  final String id, hid, title, signal;

  /// S5: the case's id on the server (null on sample data).
  final String? key;
  String status;
  final List<CaseEvent> events;

  /// Resident the owner can switch to Via Hostelzy to fix the mistake.
  final String? resident;
  String? ownerReply, tenantNote, result;
  final double hoursLeft;

  /// F18 (F4): when the case opened (ms). The owner's 48 hours run from here;
  /// sample cases without it keep their sample time.
  final int? openedAt;
  double hoursLeftAt(int now) => openedAt == null ? hoursLeft : (48 - (now - openedAt!) / 3600000).clamp(0, 48).toDouble();
}

List<FairCase> seedCases() => [
  FairCase(
    id: 'FP-0142',
    hid: 'anjani',
    title: 'Teja Naidu was added as Direct',
    signal: 'Held, then added as Direct · tenant says yes',
    status: 'waiting',
    resident: 'Teja Naidu',
    events: const [
      CaseEvent('10 Sep', 'Enquired on Hostelzy', 'HZ-4766 · phone 90000 00013 verified by OTP'),
      CaseEvent('11 Sep', 'Held bed 102-B', 'Free 1-hour hold'),
      CaseEvent('11 Sep', 'Hold cancelled by tenant', '18 minutes later'),
      CaseEvent('18 Sep', 'Added by you as Direct', 'Bed 102-B · same phone number', flag: true),
      CaseEvent('1 Oct', 'Teja answered “Yes, I joined”', 'In the Hostelzy app', flag: true),
    ],
    tenantNote: 'I found it on Hostelzy, the owner said I could skip the hold.',
  ),
  FairCase(id: 'FP-0141', hid: 'greenview', title: 'Bed 101-B taken after a cancelled hold', signal: 'Hold cancelled, same bed taken in 7 days', status: 'waiting'),
  FairCase(id: 'FP-0140', hid: 'lakshmi', title: 'Tenant report', signal: 'Tenant report: asked to pay without the app', status: 'waiting'),
  FairCase(id: 'FP-0139', hid: 'orchid', title: 'Direct resident on the deal price', signal: 'Direct resident paying the deal price', status: 'new'),
  FairCase(id: 'FP-0138', hid: 'nest42', title: 'Holds declined while beds fill', signal: 'Declining holds while occupancy rises', status: 'new'),
  FairCase(id: 'FP-0137', hid: 'saisri', title: 'Joined but never added', signal: 'Tenant said “Yes, I joined”, never added', status: 'new'),
];

// ------------------------------------------------------------ F10 owner plan

/// Flat plans by hostel size (DECISIONS 2026-10-02). No commission.
const planTiers = <({int upTo, String label, int price, String note})>[
  (upTo: 30, label: 'Up to 30 beds', price: 499, note: 'Everything below'),
  (upTo: 80, label: '31 to 80 beds', price: 999, note: 'Everything below'),
  (upTo: 1 << 30, label: '80+ beds', price: 1499, note: 'Plus a featured spot in your area'),
];
int planTierOf(int beds) => planTiers.indexWhere((t) => beds <= t.upTo);
const planIncluded = 'Verified enquiries with HZ codes · holds · residents app for rent and complaints · deals · Hostelzy score.';

/// Reminder after 5 days late; deals paused after 15.
const remindAfterDays = 5, pauseAfterDays = 15;

/// Anjani's 30-day trial started when the listing went live (1 Oct).
/// F18 (F12): the 30-day trial and first invoice run from the plan's start.
const trialDays = 30;

/// An owner's monthly Hostelzy invoice. [status]: upcoming | due | checking |
/// paid | missing (UTR not found in the bank record).
class Invoice {
  Invoice({required this.ref, required this.hid, required this.beds, required this.amt, required this.due, this.status = 'upcoming', this.utr, this.sent, this.late = 0, this.checked, this.key});
  final String ref, hid;

  /// S7: the invoice's id on the server (null on sample data).
  final String? key;
  final int beds;
  int amt;
  final DateTime due;
  String status;
  String? utr, sent, checked;

  /// Days past [due] while unpaid.
  int late;

  bool get pausesDeals => status != 'paid' && late >= pauseAfterDays;
}

/// Other owners' invoices on the founder's payments screen.
List<Invoice> seedInvoices() => [
  Invoice(ref: 'HZ-INV-1019', hid: 'greenview', beds: 24, amt: 499, due: DateTime(2026, 10, 1), status: 'checking', utr: '402177100532', sent: '1 Oct, 9:02 am'),
  Invoice(ref: 'HZ-INV-1016', hid: 'lakshmi', beds: 96, amt: 1499, due: DateTime(2026, 9, 30), status: 'checking', utr: '402099214418', sent: '30 Sep, 8:40 pm'),
  Invoice(ref: 'HZ-INV-0998', hid: 'orchid', beds: 28, amt: 499, due: DateTime(2026, 9, 16), status: 'due', late: 15),
  Invoice(ref: 'HZ-INV-0990', hid: 'saisri', beds: 40, amt: 999, due: DateTime(2026, 9, 20), status: 'paid', utr: '401922107781', sent: '20 Sep', checked: '21 Sep'),
  Invoice(ref: 'HZ-INV-0987', hid: 'nest42', beds: 18, amt: 499, due: DateTime(2026, 9, 18), status: 'paid', utr: '401811902265', sent: '18 Sep', checked: '18 Sep'),
];

/// "4021 8834 1297".
String utrSpaced(String u) => [for (var i = 0; i < u.length; i += 4) u.substring(i, i + 4 > u.length ? u.length : i + 4)].join(' ');

// ------------------------------------------------------------ F12 room layouts

/// A bed on a layout is 2.7 × 5.4 ft ("3 × 6 ft" with its gap).
const bedW = 2.7, bedH = 5.4;

/// A fan covers about 4 ft around it ("Under a fan").
const fanReach = 4.0;

/// Room shapes in the Hostelzy team's library (phase 1: the sample rooms are
/// rectangles).
const layoutShapes = ['Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom'];

/// Hostels whose rooms Hostelzy has drawn. The rest show "Layout coming soon".
const layoutHostels = ['anjani', 'saisri', 'nest42', 'orchid'];

/// One drawn item. [kind]: fan | ac | window | door | wash | pillar. Feet
/// from the room's top-left corner; the team moves them in the editor.
class LItem {
  LItem(this.id, this.kind, this.x, this.y, this.w, this.h, {this.facing, this.working = true});
  final String id, kind;
  double x, y, w, h;

  /// Window: street | courtyard | building.
  String? facing;
  bool working;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
  LItem copy() => LItem(id, kind, x, y, w, h, facing: facing, working: working);
}

/// Which wall an item sits on: top | bottom | left | right (null = inside).
String? wallOf(Rect r, double w, double h) {
  if (r.top < .5) return 'top';
  if (r.bottom > h - .5) return 'bottom';
  if (r.left < .5) return 'left';
  if (r.right > w - .5) return 'right';
  return null;
}

/// A saved state of a layout, for undo / redo in the editor.
typedef LayoutSnap = ({double w, double h, Map<String, Offset> beds, List<LItem> items, Map<String, String> bunks});

/// F19: a resident's suggested fix to a room layout. The owner (and the
/// team after 7 days) approves or rejects it; tenants never see who sent it.
class LayoutFix {
  LayoutFix({required this.id, required this.hid, required this.room, required this.snap, required this.at, this.note = '', this.status = 'pending', this.author = '', this.authorBed = '', this.since = '', this.reason, this.decidedAt, this.mine = false, this.baseVersion = 1, this.kind = 'layout', this.issue, this.item, this.photo, this.repair, this.authorId = ''});
  final String id, hid;
  final int room;
  final LayoutSnap snap;
  final String note, author, authorBed, since;

  /// F19 extras: layout | quick (one item: wrong_place | missing | broken |
  /// not_here); the photo (storage path, or a local key on sample data); a
  /// Broken quick fix's repair: working | not_broken.
  final String kind;
  final String? issue, item, photo;
  String? repair;

  /// Who sent it (for muting).
  final String authorId;

  bool get quick => kind == 'quick';
  bool get broken => quick && issue == 'broken';

  /// "AC unit is broken", "Fan is in the wrong place".
  String get quickLine => switch (issue) {
    'broken' => '$item is broken',
    'missing' => 'There’s no ${lowerName(item ?? '')} in this room',
    'not_here' => '$item isn’t in this room',
    _ => '$item is in the wrong place',
  };

  /// pending | approved | rejected | withdrawn
  String status;
  String? reason;

  /// When it was sent / decided (ms).
  final int at;
  int? decidedAt;

  /// Sent from this phone (the resident's own).
  final bool mine;

  /// The live version it was drawn on.
  final int baseVersion;
}

/// F19: a layout as JSON for the server ({w, h, beds: {A: [x, y]}, items, bunks}).
Map<String, dynamic> layoutJson(LayoutSnap l) => {
  'w': l.w,
  'h': l.h,
  'beds': {for (final e in l.beds.entries) e.key: [e.value.dx, e.value.dy]},
  'items': [for (final i in l.items) {'id': i.id, 'kind': i.kind, 'x': i.x, 'y': i.y, 'w': i.w, 'h': i.h, if (i.facing != null) 'facing': i.facing, 'working': i.working}],
  'bunks': l.bunks,
};

/// F19: [layoutJson] back to a snapshot.
LayoutSnap snapFromJson(Map<String, dynamic> j) {
  num n(Object? v) => v as num? ?? 0;
  return (
    w: n(j['w']).toDouble(),
    h: n(j['h']).toDouble(),
    beds: {for (final e in (j['beds'] as Map? ?? const {}).entries) e.key as String: Offset(n((e.value as List)[0]).toDouble(), n(e.value[1]).toDouble())},
    items: [
      for (final i in (j['items'] as List? ?? const []).cast<Map>()) LItem(i['id'] as String, i['kind'] as String, n(i['x']).toDouble(), n(i['y']).toDouble(), n(i['w']).toDouble(), n(i['h']).toDouble(), facing: i['facing'] as String?, working: i['working'] as bool? ?? true),
    ],
    bunks: {for (final e in (j['bunks'] as Map? ?? const {}).entries) e.key as String: e.value as String},
  );
}

/// F19: what a fix changes, in words, and which things moved (for the red
/// outline): "Fan 1" · "moved", "AC unit" · "right → left wall".
({List<(String, String)> lines, Set<String> ids}) layoutDiff(LayoutSnap a, LayoutSnap b) {
  const names = {'fan': 'Fan', 'ac': 'AC unit', 'window': 'Window', 'door': 'Door', 'wash': 'Washroom', 'pillar': 'Pillar'};
  final lines = <(String, String)>[], ids = <String>{};
  String nm(LItem i) {
    final same = [...a.items, ...b.items].where((x) => x.kind == i.kind).map((x) => x.id).toSet();
    return same.length > 1 ? '${names[i.kind] ?? i.kind} ${i.id.replaceAll(RegExp(r'[^0-9]'), '')}' : names[i.kind] ?? i.kind;
  }
  for (final i in b.items) {
    final o = a.items.where((x) => x.id == i.id).firstOrNull;
    if (o == null) {
      lines.add((nm(i), 'added'));
      ids.add(i.id);
      continue;
    }
    final wo = wallOf(o.rect, a.w, a.h), wn = wallOf(i.rect, b.w, b.h);
    final changes = [
      if (wo != wn && (wo != null || wn != null)) '${wo ?? 'middle'} → ${wn ?? 'middle'}${wn == null ? '' : ' wall'}'
      else if (o.x != i.x || o.y != i.y) 'moved',
      if ((o.w != i.w || o.h != i.h) && wo == wn) 'turned',
      if (o.working != i.working) i.working ? 'working' : 'not working',
      if (o.facing != i.facing && i.facing != null) 'faces ${i.facing}',
    ];
    if (changes.isNotEmpty) {
      lines.add((nm(i), changes.join(' · ')));
      ids.add(i.id);
    }
  }
  for (final o in a.items) {
    if (!b.items.any((x) => x.id == o.id)) lines.add((nm(o), 'taken off'));
  }
  for (final k in b.beds.keys.toList()..sort()) {
    if (a.beds[k] != b.beds[k]) {
      lines.add(('Bed $k', a.beds.containsKey(k) ? 'moved' : 'added'));
      ids.add('bed:$k');
    }
  }
  if (a.w != b.w || a.h != b.h) lines.add(('Size', '${a.w.round()} × ${a.h.round()} → ${b.w.round()} × ${b.h.round()} ft'));
  return (lines: lines, ids: ids);
}

/// A room's layout, drawn by the Hostelzy team. Layout beds are the bed-map
/// beds (same letters). [live]: a version tenants see. [pending]: a newer
/// version waiting for the owner's approval.
class RoomLayout {
  RoomLayout({required this.hid, required this.room, required this.w, required this.h, required this.beds, required this.items, this.version = 1, this.live = true, this.pending = false, this.drawn = '28 Sep', this.verified = '28 Sep'});
  final String hid;
  final int room;
  double w, h;
  final Map<String, Offset> beds;
  final List<LItem> items;
  int version;
  bool live, pending;
  String drawn, verified;
  String shape = 'Rectangle';

  /// What tenants see while the team edits a new version (null = this).
  LayoutSnap? published;

  /// Bunk beds: upper bed letter → the lower bed it stands on (same spot).
  final Map<String, String> bunks = {};

  /// Residents who answered "No" to "Is the room layout accurate?".
  int disputes = 0;

  /// The upper bunk on [lower], if any.
  String? upperOn(String lower) => bunks.entries.where((e) => e.value == lower).firstOrNull?.key;

  /// The layout tenants see: the last approved version.
  RoomLayout get forTenants {
    final p = published;
    if (p == null) return this;
    return RoomLayout(hid: hid, room: room, w: p.w, h: p.h, beds: Map.of(p.beds), items: [for (final i in p.items) i.copy()], version: version - 1, live: true, drawn: drawn, verified: verified)..bunks.addAll(p.bunks);
  }

  /// The owner's open change request (F12 board 5).
  ({String text, Set<String> added, String size, String at})? request;

  Rect bedRect(String letter) => Rect.fromLTWH(beds[letter]!.dx, beds[letter]!.dy, bedW, bedH);
  Rect itemRect(LItem i) => i.rect;

  /// F18 Create a layout: resize the starting rectangle to [len] × [wid] ft,
  /// keeping beds and items inside the walls.
  void mirrorTo(double len, double wid) {
    final sx = len / w, sy = wid / h;
    for (final k in beds.keys.toList()) {
      beds[k] = Offset((beds[k]!.dx * sx).roundToDouble().clamp(0, len - 3), (beds[k]!.dy * sy).roundToDouble().clamp(0, wid - 6));
    }
    for (final i in items) {
      i
        ..x = (i.x * sx).clamp(0, len - i.w)
        ..y = (i.y * sy).clamp(0, wid - i.h);
    }
    w = len;
    h = wid;
  }

  LayoutSnap snap() => (w: w, h: h, beds: Map.of(beds), items: [for (final i in items) i.copy()], bunks: Map.of(bunks));
  void restore(LayoutSnap s) {
    w = s.w;
    h = s.h;
    beds
      ..clear()
      ..addAll(s.beds);
    items
      ..clear()
      ..addAll([for (final i in s.items) i.copy()]);
    bunks
      ..clear()
      ..addAll(s.bunks);
  }

  /// Mirror left ↔ right (or flip top ↔ bottom) for a room drawn the other way.
  void mirror({bool vertical = false}) {
    for (final k in beds.keys.toList()) {
      final b = beds[k]!;
      beds[k] = vertical ? Offset(b.dx, h - b.dy - bedH) : Offset(w - b.dx - bedW, b.dy);
    }
    for (final i in items) {
      vertical ? i.y = h - i.y - i.h : i.x = w - i.x - i.w;
    }
  }
  Iterable<LItem> of(String kind) => items.where((i) => i.kind == kind);
  LItem? get ac => of('ac').firstOrNull;
  LItem? get window => of('window').firstOrNull;
  LItem? get door => of('door').firstOrNull;
  LItem? get wash => of('wash').firstOrNull;

  /// The AC blows about 8.5 ft into the room from its wall: this box, in feet.
  Rect? get airflow {
    final a = ac;
    if (a == null) return null;
    final r = a.rect, c = r.center;
    double cl(double v, double max) => v.clamp(0, max).toDouble();
    return switch (wallOf(r, w, h)) {
      'left' => Rect.fromLTRB(r.right, cl(c.dy - 3.25, h), cl(r.right + 8.5, w), cl(c.dy + 3.25, h)),
      'top' => Rect.fromLTRB(cl(c.dx - 3.25, w), r.bottom, cl(c.dx + 3.25, w), cl(r.bottom + 8.5, h)),
      'bottom' => Rect.fromLTRB(cl(c.dx - 3.25, w), cl(r.top - 8.5, h), cl(c.dx + 3.25, w), r.top),
      _ => Rect.fromLTRB(cl(r.left - 8.5, w), cl(c.dy - 3.25, h), r.left, cl(c.dy + 3.25, h)),
    };
  }
}

String _m(double ft) {
  final m = (ft * .3048 * 2).round() / 2;
  return m == m.roundToDouble() ? '${m.round()} m' : '$m m';
}

double _distTo(Offset p, Rect r) {
  final dx = p.dx < r.left ? r.left - p.dx : (p.dx > r.right ? p.dx - r.right : 0.0);
  final dy = p.dy < r.top ? r.top - p.dy : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
  return Offset(dx, dy).distance;
}

/// What a bed is like, for the facts and the compare table. Never priced by
/// position (DECISIONS 2026-10-02).
({String fan, String? ac, String win, String door, String wash, String wall, String bunk}) bedTraits(RoomLayout l, Room r, String letter) {
  final b = l.bedRect(letter);
  final c = b.center;
  final fans = l.of('fan').where((f) => (l.itemRect(f).center - c).distance <= fanReach).toList();
  final fan = fans.isEmpty ? 'No fan overhead' : (fans.any((f) => f.working) ? 'Under a fan' : 'Fan not working');
  final air = l.airflow;
  final ac = !r.ac ? null : (r.acRepair || l.ac?.working == false ? 'AC under repair' : (air != null && air.contains(c) ? 'In the airflow' : 'Out of the airflow'));
  final wi = l.window;
  final wr = wi != null ? l.itemRect(wi) : null;
  final side = wr == null
      ? false
      : switch (wallOf(wr, l.w, l.h)) {
          'top' => b.top < 2 && b.left < wr.right && b.right > wr.left,
          'bottom' => b.bottom > l.h - 2 && b.left < wr.right && b.right > wr.left,
          'left' => b.left < 2 && b.top < wr.bottom && b.bottom > wr.top,
          'right' => b.right > l.w - 2 && b.top < wr.bottom && b.bottom > wr.top,
          _ => false,
        };
  final win = side ? 'Window side · ${wi!.facing}' : 'No window';
  final dr = l.door != null ? _distTo(c, l.itemRect(l.door!)) : 99.0;
  final door = dr * .3048 < 2.2 ? 'Near the door' : _m(dr);
  final wash = l.wash == null ? 'Outside the room' : _m(_distTo(c, l.itemRect(l.wash!)));
  final walls = (b.left < 1.5 || b.right > l.w - 1.5 ? 1 : 0) + (b.top < 1.5 || b.bottom > l.h - 1.5 ? 1 : 0);
  final wall = switch (walls) {
    2 => 'Corner',
    1 => 'One wall',
    _ => 'No wall',
  };
  final bunk = l.bunks.containsKey(letter) ? 'Upper bunk' : (l.upperOn(letter) != null ? 'Lower bunk' : 'Single bed');
  return (fan: fan, ac: ac, win: win, door: door, wash: wash, wall: wall, bunk: bunk);
}

/// "Under a fan", "Window side · faces street", "In the AC airflow", "Door 4 m away".
List<String> bedFacts(RoomLayout l, Room r, String letter) {
  final t = bedTraits(l, r, letter);
  return [
    if (t.bunk != 'Single bed') t.bunk,
    if (t.wall == 'Corner') 'Corner bed · walls on two sides',
    t.fan,
    if (t.win != 'No window') t.win.replaceFirst('· ', '· faces '),
    if (t.ac != null) t.ac == 'AC under repair' ? t.ac! : t.ac!.replaceFirst('the airflow', 'the AC airflow'),
    t.door == 'Near the door' ? t.door : 'Door ${t.door} away',
    t.wash == 'Outside the room' ? 'Common washroom outside' : 'Washroom ${t.wash} away',
  ];
}

/// The sample layout the Hostelzy team drew for room [r]: beds along the
/// walls, window on the top wall, door bottom right, attached washroom bottom
/// left, fans, and an AC unit on the right wall of AC rooms.
RoomLayout mkLayout(String hid, Room r, {required bool street}) {
  final (w, h) = switch (r.share) {
    2 => (14.0, 12.0),
    3 => (18.0, 15.0),
    _ => (20.0, 15.0),
  };
  final slots = <Offset>[
    const Offset(.8, 1.4),
    if (r.share == 2) Offset(w - 3.5, 1.4) else Offset(w / 2, 1.4),
    if (r.share >= 3) Offset(w - 3.9, h - 7.2),
    if (r.share >= 4) Offset(w / 2 - 2.5, h - 7.2),
  ];
  final fans = r.share == 2 ? [const Offset(4, 4.5)] : [Offset(w * .575, 7), Offset(w * .83, 10.75)];
  return RoomLayout(
    hid: hid,
    room: r.n,
    w: w,
    h: h,
    beds: {for (var i = 0; i < r.beds.length && i < slots.length; i++) r.beds[i].letter: slots[i]},
    items: [
      LItem('win', 'window', w * .42, 0, w * .41, .3, facing: street ? 'street' : 'courtyard'),
      LItem('door', 'door', w - 4.5, h - .2, 3, .2),
      if (r.bath == 'Attached') LItem('wash', 'wash', 0, h - 4, 5, 4),
      for (var i = 0; i < fans.length; i++) LItem('fan${i + 1}', 'fan', fans[i].dx - .5, fans[i].dy - .5, 1, 1),
      if (r.ac) LItem('ac', 'ac', w - .5, 1.3, .5, 1.8),
    ],
  );
}

/// Layouts for every room of the hostels Hostelzy has drawn. Rooms on the
/// first half of each floor face the street. Anjani 204 has a v2 waiting for
/// the owner's approval.
Map<String, Map<int, RoomLayout>> seedLayouts(Map<String, List<Room>> rooms) {
  final out = <String, Map<int, RoomLayout>>{};
  for (final hid in layoutHostels) {
    final rs = rooms[hid]!;
    out[hid] = {
      for (final r in rs)
        r.n: () {
          final floor = rs.where((x) => x.floor == r.floor).toList();
          return mkLayout(hid, r, street: floor.indexOf(r) < (floor.length + 1) ~/ 2);
        }(),
    };
  }
  // Sample bunk bed: Nest 42 room 101, bed D is the upper bunk over C.
  final n101 = out['nest42']?[101];
  if (n101 != null && n101.beds.containsKey('C') && n101.beds.containsKey('D')) {
    n101.bunks['D'] = 'C';
    n101.beds['D'] = n101.beds['C']!;
  }
  out['anjani']![204]!
    ..version = 2
    ..pending = true
    ..drawn = '1 Oct';
  return out;
}

// ------------------------------------------------------------ F14 onboarding

const _seedIds = ['anjani', 'saisri', 'nest42', 'greenview', 'orchid', 'lakshmi'];

bool isSeedHostel(String id) => _seedIds.contains(id);

/// Drop hostels added in an earlier session (data lives in memory until F13).
void resetSampleData() {
  hostels.removeWhere((h) => !_seedIds.contains(h.id));
  ownerPhones.removeWhere((k, _) => !_seedIds.contains(k));
  liveListings = false;
  livePos.clear();
}

/// F13: true once live hostels came from the database. Tenants then browse
/// only those; the sample hostels stay only behind the owner and resident
/// sample screens until those are online too.
bool liveListings = false;

/// Hostels a tenant can find (Explore, map, ranking).
List<Hostel> get browsable => liveListings ? hostels.where((h) => !_seedIds.contains(h.id)).toList() : hostels;

/// Map positions of live hostels (from the database).
final livePos = <String, (double, double)>{};

/// The owner is asked to confirm free beds every 3 days; after 7 days
/// tenants see "Availability not confirmed" and the hostel ranks lower.
const confirmEveryDays = 3, staleAfterDays = 7;

/// Days since each owner last confirmed their free beds (sample).
/// Days since each owner last confirmed their room layouts still match (F12:
/// every 3 months).
const seedLayoutConfirmed = {'anjani': 92, 'saisri': 20, 'nest42': 40, 'orchid': 10};
const layoutConfirmEvery = 90;

const seedConfirmed = {'anjani': 3, 'saisri': 1, 'nest42': 0, 'greenview': 9, 'orchid': 2, 'lakshmi': 5};

/// "Visited by Hostelzy" dates (sample: the hostels the founder visited).
const seedVisited = {'anjani': '1 Oct 2026', 'saisri': '28 Sep 2026', 'nest42': '29 Sep 2026'};

const amenityList = ['Wi-Fi', 'Power backup', 'Washing machine', 'Hot water', 'Parking', 'Gym', 'Lift'];
const foodOpts = ['3 meals', '2 meals', 'No food'];

/// First clusters (DECISIONS 2026-10-02).
const clusters = ['Ameerpet / SR Nagar', 'Madhapur / Hitec City / Kondapur'];
const areaCluster = {'Ameerpet': 0, 'SR Nagar': 0, 'KPHB': 0, 'Madhapur': 1, 'Hitec City': 1, 'Kondapur': 1, 'Gachibowli': 1};
const onboardStages = ['Lead', 'Visited', 'Signed up', 'Data complete', 'Live', 'Trial', 'Paying'];

/// Map spots and minutes to landmarks by area, for hostels added on a visit.
const areaSpot = <String, ({double x, double y, Map<String, int> mins})>{
  'Madhapur': (x: 40, y: 40, mins: {'Hitec City': 7, 'Gachibowli': 12, 'Ameerpet': 22, 'JNTU': 16}),
  'Kondapur': (x: 52, y: 32, mins: {'Hitec City': 9, 'Gachibowli': 10, 'Ameerpet': 28, 'JNTU': 17}),
  'Hitec City': (x: 34, y: 44, mins: {'Hitec City': 4, 'Gachibowli': 9, 'Ameerpet': 24, 'JNTU': 18}),
  'Ameerpet': (x: 78, y: 62, mins: {'Hitec City': 25, 'Gachibowli': 33, 'Ameerpet': 5, 'JNTU': 14}),
  'SR Nagar': (x: 74, y: 56, mins: {'Hitec City': 22, 'Gachibowli': 30, 'Ameerpet': 6, 'JNTU': 12}),
};

/// One row on the founder's onboarding tracker.
class Lead {
  Lead(this.name, this.area, this.next, this.stage, {this.hid});
  final String name, area;
  String next;
  int stage;
  final String? hid;
  int get cluster => areaCluster[area] ?? 1;
}

List<Lead> seedLeads() => [
  Lead('Sri Sai PG', 'SR Nagar', 'Call Mon', 0),
  Lead('Vasavi Boys Hostel', 'Ameerpet', 'Visit Tue 11 am', 0),
  Lead("Greenview Men's PG", 'Kondapur', 'Owner to decide by Fri', 1, hid: 'greenview'),
  Lead("Orchid Women's PG", 'KPHB', 'Photos missing', 2, hid: 'orchid'),
  Lead('Lakshmi Students PG', 'Ameerpet', 'Go live Thu', 3, hid: 'lakshmi'),
  Lead('Nest 42 Co-living', 'Gachibowli', 'Check bed status', 4, hid: 'nest42'),
  Lead('Anjani Residency', 'Madhapur', 'Trial ends 31 Oct', 5, hid: 'anjani'),
  Lead('Sai Sri Ladies Hostel', 'Kondapur', 'Trial ends 28 Oct', 5, hid: 'saisri'),
];

/// A room in the Add hostel wizard: the owner's own number, sharing, AC.
class DraftRoom {
  DraftRoom(this.label, this.share, this.ac);
  String label;
  int share;
  bool ac;
  DraftRoom copy() => DraftRoom(label, share, ac);
}

/// A floor: its own room count, or no beds (kitchen, office) and hidden.
class DraftFloor {
  DraftFloor(this.name, this.rooms, {this.noBeds = false, this.note = ''});
  final String name;
  final List<DraftRoom> rooms;
  bool noBeds;
  String note;
}

String floorName(int i) => switch (i) {
  0 => 'Ground floor',
  1 => '1st floor',
  2 => '2nd floor',
  3 => '3rd floor',
  _ => '${i}th floor',
};

/// Everything the founder fills in on the visit (Add hostel, 6 steps).
class HostelDraft {
  String name = 'Anjani Annex', gender = 'Men', area = 'Kondapur', food = '3 meals', gate = '10:30 pm';
  bool pinChecked = false;
  Set<String> amenities = {'Wi-Fi', 'Power backup', 'Washing machine', 'Hot water'};
  int defShare = 3;
  bool defAc = false;

  /// Sample from the design: Ground 0, 1st 3, 2nd 5, 3rd 2 = 10 rooms, 29 beds.
  final List<DraftFloor> floors = [
    DraftFloor('Ground floor', [], noBeds: true, note: 'Kitchen and office'),
    DraftFloor('1st floor', [DraftRoom('101', 3, false), DraftRoom('102', 3, false), DraftRoom('105', 2, false)], note: 'Owner numbers: 103, 104 skipped'),
    DraftFloor('2nd floor', [DraftRoom('201', 3, true), DraftRoom('202', 4, false), DraftRoom('203', 3, true), DraftRoom('204', 3, false), DraftRoom('204A', 2, false)], note: 'Copied from 1st, then changed'),
    DraftFloor('3rd floor', [DraftRoom('301', 3, false), DraftRoom('302', 3, false)]),
  ];
  final Map<String, int> prices = {'non2': 8100, 'non3': 7000, 'ac3': 8200};
  int advance = 3000, kept = 1000, notice = 30;
  bool dueOnJoining = true;
  final Set<String> photos = {'Front', 'Washroom', 'Food', 'Common area'};
  final Set<String> sketches = {};
  final List<({String name, String phone, String bed})> residents = [];
  String ownerName = 'Srinivas', ownerPhone = '';
  bool ownerVerified = false, fairPlay = false, bedsChecked = false;

  Iterable<DraftRoom> get allRooms => floors.where((f) => !f.noBeds).expand((f) => f.rooms);
  int get roomCount => allRooms.length;
  int get bedCount => allRooms.fold(0, (a, r) => a + r.share);

  /// Room types used, e.g. `non3`, `ac3`, in a stable order.
  List<String> get types => {for (final r in allRooms) rateKey(r.ac, r.share)}.toList()..sort((a, b) => a.compareTo(b));
  String typeLabel(String k) => '${k.substring(k.length - 1)} sharing${k.startsWith('ac') ? ' AC' : ''}';
  List<String> get missingPrices => [for (final k in types) if ((prices[k] ?? 0) <= 0) k];

  /// Front, each room type, washroom, food, common area, gate sticker.
  List<String> get photoSlots => ['Front', for (final k in types) typeLabel(k), 'Washroom', 'Food', 'Common area', 'Gate sticker'];
  int get photoCount => photos.where(photoSlots.contains).length;
  static const minPhotos = 8;
  int get takenBeds => residents.length;
}

// ------------------------------------------------------------ F17 payments

/// A payment from a tenant or resident straight to the owner's UPI ID.
/// Hostelzy never holds the money: the payer sends the UTR, the owner checks
/// their bank and confirms. [kind]: advance | rent. [status]: due | waiting |
/// paid | missing (owner says it didn't arrive).
class Payment {
  Payment({required this.id, required this.kind, required this.hid, required this.who, required this.what, required this.bed, required this.amt, required this.note, this.holdId, this.status = 'due', this.utr, this.sent, this.done});
  final String id, kind, hid, who, what, bed, note;
  final int amt;
  final String? holdId;
  String status;
  String? utr, sent, done;
}

/// Sample: one rent payment already waiting for the owner (F17 board 4).
List<Payment> seedPayments() => [
  Payment(id: 'rent204B', kind: 'rent', hid: 'anjani', who: 'Rahul V.', what: 'October rent', bed: '204-B', amt: 8020, note: 'Rent Oct · 204-B'),
  Payment(id: 'p1', kind: 'rent', hid: 'anjani', who: 'Arjun R.', what: 'October rent', bed: '204-A', amt: 7000, note: 'Rent Oct · 204-A', status: 'waiting', utr: '402199102245', sent: 'Thu 1 Oct, 9:20 am'),
];

/// F18 (F11): what a UPI ID looks like (handle@psp).
bool validUpiId(String id) => RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(id.trim());

/// `upi://pay` link with the payee, amount and note filled in.
Uri upiUri({required String id, required String name, required int amt, required String note}) => Uri(scheme: 'upi', host: 'pay', queryParameters: {'pa': id, 'pn': name, 'am': '$amt', 'tn': note, 'cu': 'INR'});

// ------------------------------------------------------------ F17 real map

/// Map positions (latitude, longitude) of the sample hostels and landmarks.
const hostelLatLng = <String, (double, double)>{
  'anjani': (17.4483, 78.3915),
  'saisri': (17.4590, 78.3650),
  'nest42': (17.4405, 78.3485),
  'greenview': (17.4640, 78.3560),
  'orchid': (17.4935, 78.3995),
  'lakshmi': (17.4375, 78.4480),
};
const landmarkLatLng = <String, (double, double)>{
  'Hitec City': (17.4474, 78.3762),
  'Gachibowli': (17.4401, 78.3489),
  'Ameerpet': (17.4374, 78.4487),
  'JNTU': (17.4933, 78.3915),
};
const areaLatLng = <String, (double, double)>{
  'Madhapur': (17.4483, 78.3915),
  'Kondapur': (17.4615, 78.3600),
  'Hitec City': (17.4474, 78.3762),
  'Ameerpet': (17.4374, 78.4487),
  'SR Nagar': (17.4410, 78.4410),
  'Gachibowli': (17.4401, 78.3489),
  'KPHB': (17.4935, 78.3995),
  'Kukatpally': (17.4849, 78.4138),
  'Jubilee Hills': (17.4326, 78.4071),
  'Begumpet': (17.4447, 78.4664),
};

/// F18 map: areas tenants can pick (design "Areas"); empty ones show "Soon".
const mapAreas = ['Ameerpet', 'SR Nagar', 'Madhapur', 'Hitec City', 'Kondapur', 'Gachibowli', 'KPHB', 'Kukatpally', 'Jubilee Hills', 'Begumpet'];

/// Search this area: hostels within this many km of the map's centre.
const searchRadiusKm = 3.0;

(double, double) posOf(Hostel h) => livePos[h.id] ?? hostelLatLng[h.id] ?? areaLatLng[h.area] ?? landmarkLatLng['Hitec City']!;

/// Straight-line distance in km (haversine). Travel time comes later.
double kmBetween((double, double) a, (double, double) b) {
  const r = 6371.0, d = 3.141592653589793 / 180;
  final dLat = (b.$1 - a.$1) * d, dLng = (b.$2 - a.$2) * d;
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(a.$1 * d) * math.cos(b.$1 * d) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(x));
}

double kmTo(Hostel h, String landmark) => kmBetween(posOf(h), landmarkLatLng[landmark]!);

/// "1.2 km"
String kmLabel(double km) => '${km.toStringAsFixed(1)} km';
