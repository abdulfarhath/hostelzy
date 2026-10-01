// Sample data and pure helpers, ported 1:1 from the Claude Design prototype
// (project/HostelzyApp.dc.html).

class Hostel {
  const Hostel({required this.id, required this.name, required this.gender, required this.area, required this.from, required this.rating, required this.reviews, required this.food, required this.ac, required this.instant, required this.owner, required this.reply, required this.mins, required this.x, required this.y, required this.tags, this.terms = const Terms()});
  final String id, name, gender, area, owner;
  final int from, reviews, reply;
  final double rating;
  final bool food, ac, instant;
  final Map<String, int> mins;
  final double x, y;
  final List<String> tags;
  final Terms terms;
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

/// "Today" in the sample data.
final appToday = DateTime(2026, 10, 1);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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

const hostels = <Hostel>[
  Hostel(id: 'anjani', name: 'Anjani Residency', gender: 'Men', area: 'Madhapur', from: 7600, rating: 4.4, reviews: 212, food: true, ac: true, instant: false, owner: 'Srinivas', reply: 12, mins: {'Hitec City': 6, 'Gachibowli': 14, 'Ameerpet': 24, 'JNTU': 20}, x: 40, y: 42, tags: ['3 meals a day', 'AC rooms', 'Power backup', 'Washing machine']),
  Hostel(id: 'saisri', name: 'Sai Sri Ladies Hostel', gender: 'Women', area: 'Kondapur', from: 8200, rating: 4.7, reviews: 340, food: true, ac: false, instant: true, owner: 'Padmavathi', reply: 5, mins: {'Hitec City': 8, 'Gachibowli': 10, 'Ameerpet': 28, 'JNTU': 18}, x: 55, y: 28, tags: ['Biometric entry', 'Warden on site', '3 meals a day', 'CCTV in corridors'], terms: Terms(maintenance: 1500)),
  Hostel(id: 'nest42', name: 'Nest 42 Co-living', gender: 'Co-living', area: 'Gachibowli', from: 10800, rating: 4.2, reviews: 96, food: false, ac: true, instant: true, owner: 'Kavya', reply: 3, mins: {'Hitec City': 14, 'Gachibowli': 5, 'Ameerpet': 32, 'JNTU': 26}, x: 24, y: 62, tags: ['AC rooms', 'Gym', 'Daily housekeeping', 'Workspace'], terms: Terms(maintenance: 1500)),
  Hostel(id: 'greenview', name: "Greenview Men's PG", gender: 'Men', area: 'Kondapur', from: 6400, rating: 4.1, reviews: 158, food: true, ac: false, instant: false, owner: 'Ramesh', reply: 20, mins: {'Hitec City': 11, 'Gachibowli': 9, 'Ameerpet': 30, 'JNTU': 14}, x: 46, y: 56, tags: ['2 meals a day', 'Hot water 24h', 'Bike parking', 'Weekly laundry']),
  Hostel(id: 'orchid', name: "Orchid Women's PG", gender: 'Women', area: 'KPHB', from: 6900, rating: 4.5, reviews: 187, food: true, ac: false, instant: false, owner: 'Lalitha', reply: 9, mins: {'Hitec City': 20, 'Gachibowli': 25, 'Ameerpet': 16, 'JNTU': 6}, x: 70, y: 18, tags: ['3 meals a day', 'Near metro', 'CCTV at gate', 'Study room'], terms: Terms(maintenance: 1200)),
  Hostel(id: 'lakshmi', name: 'Lakshmi Students PG', gender: 'Men', area: 'Ameerpet', from: 5400, rating: 4.0, reviews: 410, food: true, ac: false, instant: false, owner: 'Venkat', reply: 15, mins: {'Hitec City': 26, 'Gachibowli': 34, 'Ameerpet': 4, 'JNTU': 15}, x: 80, y: 66, tags: ['Near coaching centres', '3 meals a day', 'Study room', 'Wi-Fi 100 Mbps']),
];

/// Number as JavaScript prints it (`4.0` → `4`).
String jsNum(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

Hostel hostelById(String id) => hostels.firstWhere((h) => h.id == id);

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
  Bed({required this.id, required this.letter, required this.room, required this.floor, required this.spot, required this.state, required this.soon});
  final String id, letter, spot;
  final int room, floor;

  /// free | held | soon | booked
  String state;
  String soon;
  bool mine = false;
}

class Room {
  Room({required this.n, required this.floor, required this.share, required this.rent, required this.bath, required this.beds});
  final int n, floor, share, rent;
  final String bath;
  final List<Bed> beds;
}

List<Room> mkRooms(Hostel h, int i) {
  var s = i * 977 + 131;
  double rnd() {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  }

  const sh = [2, 3, 4, 3];
  final out = <Room>[];
  for (var f = 1; f <= 3; f++) {
    for (var r = 1; r <= 4; r++) {
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
      out.add(Room(n: n, floor: f, share: share, rent: h.from + (4 - share) * 1100 + (f == 3 ? 300 : 0), bath: r % 2 == 1 ? 'Attached' : 'Shared', beds: beds));
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
}

class Resident {
  Resident({required this.name, required this.bed, required this.amt, required this.status, required this.note, this.phone = '', this.via = 'before', this.since = '', this.ref, this.confirmed = true, this.advance = 3000, this.joinAt});
  final String name, bed;
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

  /// When they moved in (ms), for residents added in the app.
  final int? joinAt;

  /// hz | direct | before | wait
  String get tag => confirmed ? via : 'wait';
  Resident copy() => Resident(name: name, bed: bed, amt: amt, status: status, note: note, phone: phone, via: via, since: since, ref: ref, confirmed: confirmed, advance: advance, joinAt: joinAt);
}

/// F06: how far back a phone's enquiry, hold or booking counts towards
/// "Joined via Hostelzy" (60 days, decided 2026-10-02).
const matchWindowDays = 60;

/// Owners must add new residents within this many days (F06 rules).
const addResidentDays = 2;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `Sat 3 Oct`
String dayName(DateTime d) => '${_weekdays[d.weekday - 1]} ${dayMon(d)}';

/// The sample resident (Rahul, bed 204-B) joined Anjani Residency on 14 Mar.
const residentJoined = '14 Mar';
const residentJoinDay = 14;

List<Resident> seedResidents() => [
  Resident(name: 'Rahul Varma', bed: '204-B', amt: 8020, status: 'Due', note: dueNote(hostels[0].terms, residentJoinDay), phone: '9848012345', since: 'Since Mar 2026'),
  Resident(name: 'Arjun Reddy', bed: '204-A', amt: 8020, status: 'Paid', note: 'Paid 29 Sep', phone: '9866104421', since: 'Since Jun 2026'),
  Resident(name: 'Sai Kiran', bed: '204-C', amt: 8020, status: 'Paid', note: 'Paid 30 Sep', phone: '9000312876', via: 'hz', since: 'Joined 20 Sep', ref: 'HZ-4712'),
  Resident(name: 'Mohammed Faiz', bed: '101-A', amt: 7600, status: 'Overdue', note: '12 days late', phone: '9959021143', since: 'Since Nov 2025'),
  Resident(name: 'Teja Naidu', bed: '102-B', amt: 8700, status: 'Paid', note: 'Paid 1 Oct', phone: '9640087712', via: 'direct', since: 'Joined 18 Sep'),
  Resident(name: 'Pranav Shetty', bed: '203-A', amt: 8700, status: 'Overdue', note: '4 days late', phone: '9701556210', since: 'Since Feb 2026'),
  Resident(name: 'Nikhil Goud', bed: '301-B', amt: 10100, status: 'Due', note: dueNote(hostels[0].terms, 22), phone: '9849770135', via: 'hz', since: 'Joined 28 Sep', ref: 'HZ-4790'),
  Resident(name: 'Harsha Vardhan', bed: '302-B', amt: 9000, status: 'Paid', note: 'Paid 28 Sep', phone: '9177345602', since: 'Since Jan 2026'),
  // The rest of the first import (grandfathered, "Before Hostelzy").
  for (final (n, b, a, ph, since) in const [
    ('Suresh Babu', '101-C', 7600, '9393012458', 'Since Nov 2025'),
    ('Kiran Kumar', '101-D', 7600, '9440221907', 'Since Apr 2026'),
    ('Venkatesh P', '102-A', 8700, '9848561230', 'Since Dec 2025'),
    ('Srikanth Rao', '104-B', 8700, '9010443381', 'Since May 2026'),
    ('Ajay Varma', '104-C', 8700, '9573120094', 'Since Jul 2026'),
    ('Mahesh Yadav', '201-A', 8700, '9908811265', 'Since Feb 2026'),
    ('Rohit Sharma', '201-B', 8700, '9618003347', 'Since Aug 2026'),
    ('Praveen K', '203-C', 8700, '9246510082', 'Since Jan 2026'),
    ('Anil Kumar', '302-A', 9000, '9885203316', 'Since Mar 2026'),
    ('Ganesh Reddy', '303-B', 7900, '9550147720', 'Since Jun 2026'),
    ('Sunil Naik', '303-C', 7900, '9032668814', 'Since Apr 2026'),
    ('Ramesh Goud', '304-C', 9000, '9701934456', 'Since May 2026'),
  ])
    Resident(name: n, bed: b, amt: a, status: 'Paid', note: 'Paid 1 Oct', phone: ph, since: since),
  // Added by the owner today, waiting for the resident's WhatsApp code.
  Resident(name: 'Ravi Teja', bed: '303-D', amt: 7900, status: 'Paid', note: 'Paid at move-in', phone: '9849033121', via: 'hz', since: 'Added today', ref: 'HZ-4821', confirmed: false),
];

/// F06 board 6: people who scanned the owner's invite QR and verified their
/// phone, waiting for the owner to approve.
class Signup {
  const Signup(this.id, this.name, this.phone, this.bed, this.ago);
  final String id, name, phone, bed, ago;
}

const seedSignups = [Signup('s1', 'Abhishek P', '9866450921', '103-A', '2 h ago'), Signup('s2', 'Naveen Goud', '9701883240', '202-B', '5 h ago')];

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
  Enquiry(ref: 'HZ-4821', name: 'Ravi Teja', phone: '9849033121', hid: 'anjani', bed: '204-A', at: now - 6 * 60000, from: 'Hostel page · Ask on WhatsApp', msg: 'Can I come and see the rooms this evening?'),
  Enquiry(ref: 'HZ-4817', name: 'Sandeep Kumar', phone: '9989120456', hid: 'anjani', bed: '201-C', at: now - 18 * 60000, from: 'Hold · WhatsApp owner', msg: 'Can I come and see it today at 6 pm?'),
  Enquiry(ref: 'HZ-4809', name: 'Imran Shaikh', phone: '9701245580', hid: 'anjani', at: now - 2 * 3600000, from: 'Hostel page · Ask on WhatsApp', msg: 'Is there a bed free from 5 Oct?', contacted: true),
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
  HoldRequest({required this.id, required this.name, required this.bed, required this.type, required this.secs, required this.note, required this.start, this.hold});
  final String id, name, bed, type, note;
  final int secs, start;
  final String? hold;
}

List<HoldRequest> seedRequests(int now) => [HoldRequest(id: 'k1', name: 'Karthik M', bed: '102-C', type: 'Free hold', secs: 2460, note: 'Can I visit at 6 pm today?', start: now), HoldRequest(id: 'v1', name: 'Vamsi Reddy', bed: '301-A', type: 'Free hold', secs: 3180, note: 'Joining Infosys on 12 Oct.', start: now)];

class Complaint {
  Complaint({required this.id, required this.by, required this.cat, required this.text, required this.status, required this.date, required this.note, this.mine = false});
  final int id;
  final String by, cat, text, date;
  final bool mine;
  String status, note;
  Complaint copyWith({String? status, String? note}) => Complaint(id: id, by: by, cat: cat, text: text, status: status ?? this.status, date: date, note: note ?? this.note, mine: mine);
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

const holdOptions = <String, HoldOption>{
  'free': HoldOption('Free hold', 'Held for 1 hour. The owner confirms before it is yours.', '₹0', 'If the owner does not confirm within the hour, the bed is released. You pay nothing.', 'Place free hold'),
  'paid': HoldOption('Paid hold', 'Guaranteed for 48 hours. Visit when it suits you.', '₹299', "₹299 comes off your first month's rent. Refunded in full if the owner cancels.", 'Pay ₹299 and hold'),
  'token': HoldOption('Book now', 'Pay a token advance. The bed is yours right away.', '₹2,000', 'The token is adjusted in your first rent. Full refund if you cancel within 24 hours.', 'Pay ₹2,000 and book'),
};

class Hold {
  Hold({required this.id, required this.hid, required this.bed, required this.room, required this.opt, required this.start, required this.status});
  final String id, hid, bed, opt;
  final int room, start;

  /// waiting | confirmed | held | booked | released
  final String status;
  Hold withStatus(String s) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: s);
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
