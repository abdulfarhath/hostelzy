
class Hostel {
  const Hostel({required this.id, required this.name, required this.gender, required this.area, required this.from, required this.rating, required this.reviews, required this.food, required this.ac, required this.instant, required this.owner, required this.reply, required this.mins, required this.x, required this.y, required this.tags, this.terms = const Terms(), this.onlyAc = false, this.live = true, this.visitedOn = '', this.bedsCheckedAt, this.layoutsCheckedAt, this.ratesCheckedAt, this.ratesTracked = false});
  final String id, name, gender, area, owner;

  /// F24: false for a draft the team is still onboarding (never in Explore);
  /// [visitedOn] is "Visited by Hostelzy" from the server ("2 Oct 2026").
  final bool live;
  final String visitedOn;

  /// F24 item 9: the owner's last "Yes, all free" (newest bed confirmation on
  /// the server) and the oldest published layout's last "All still correct";
  /// null when unknown (sample data, never confirmed).
  final DateTime? bedsCheckedAt, layoutsCheckedAt;

  /// F24 Wave 4d (F03): the oldest rate card's "confirmed by the owner" time
  /// on the server; null when unknown. [ratesTracked]: the server keeps it
  /// (SQL 4zd1 ran), so a null means the owner never confirmed.
  final DateTime? ratesCheckedAt;
  final bool ratesTracked;
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

/// The sample hostels plus any the Hostelzy team put live with Add hostel
/// (F14). In memory only until the backend (F13): [resetSampleData] trims it.
final hostels = <Hostel>[
  const Hostel(id: 'anjani', name: 'Anjani Residency', gender: 'Men', area: 'Madhapur', from: 7600, rating: 4.4, reviews: 38, food: true, ac: true, instant: false, owner: 'Srinivas', reply: 12, mins: {'Hitec City': 6, 'Gachibowli': 14, 'Ameerpet': 24, 'JNTU': 20}, x: 40, y: 42, tags: ['3 meals a day', 'AC rooms', 'Power backup', 'Washing machine']),
  const Hostel(id: 'saisri', name: 'Sai Sri Ladies Hostel', gender: 'Women', area: 'Kondapur', from: 8200, rating: 4.7, reviews: 52, food: true, ac: false, instant: true, owner: 'Padmavathi', reply: 5, mins: {'Hitec City': 8, 'Gachibowli': 10, 'Ameerpet': 28, 'JNTU': 18}, x: 55, y: 28, tags: ['Biometric entry', 'Warden on site', '3 meals a day', 'CCTV in corridors'], terms: Terms(maintenance: 1500)),
  const Hostel(id: 'nest42', name: 'Nest 42 Co-living', gender: 'Co-living', area: 'Gachibowli', from: 10800, rating: 4.2, reviews: 14, food: false, ac: true, instant: true, owner: 'Kavya', reply: 3, mins: {'Hitec City': 14, 'Gachibowli': 5, 'Ameerpet': 32, 'JNTU': 26}, x: 24, y: 62, tags: ['AC rooms', 'Gym', 'Daily housekeeping', 'Workspace'], terms: Terms(maintenance: 1500), onlyAc: true),
  const Hostel(id: 'greenview', name: "Greenview Men's PG", gender: 'Men', area: 'Kondapur', from: 6400, rating: 4.1, reviews: 22, food: true, ac: false, instant: false, owner: 'Ramesh', reply: 20, mins: {'Hitec City': 11, 'Gachibowli': 9, 'Ameerpet': 30, 'JNTU': 14}, x: 46, y: 56, tags: ['2 meals a day', 'Hot water 24h', 'Bike parking', 'Weekly laundry']),
  const Hostel(id: 'orchid', name: "Orchid Women's PG", gender: 'Women', area: 'KPHB', from: 6900, rating: 4.5, reviews: 31, food: true, ac: false, instant: false, owner: 'Lalitha', reply: 9, mins: {'Hitec City': 20, 'Gachibowli': 25, 'Ameerpet': 16, 'JNTU': 6}, x: 70, y: 18, tags: ['3 meals a day', 'Near metro', 'CCTV at gate', 'Study room'], terms: Terms(maintenance: 1200)),
  const Hostel(id: 'lakshmi', name: 'Lakshmi Students PG', gender: 'Men', area: 'Ameerpet', from: 5400, rating: 4.0, reviews: 47, food: true, ac: false, instant: false, owner: 'Venkat', reply: 15, mins: {'Hitec City': 26, 'Gachibowli': 34, 'Ameerpet': 4, 'JNTU': 15}, x: 80, y: 66, tags: ['Near coaching centres', '3 meals a day', 'Study room', 'Wi-Fi 100 Mbps']),
];

/// F18: an id that is no longer listed (removed hostel, stale saved hold)
/// gets a placeholder instead of a crash.
Hostel hostelById(String id) => hostels.firstWhere((h) => h.id == id, orElse: () => Hostel(id: id, name: 'Hostel no longer listed', gender: 'Co-living', area: 'Hyderabad', from: 0, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: const {}, x: 50, y: 50, tags: const []));

const landmarks = ['Hitec City', 'Gachibowli', 'Ameerpet', 'JNTU'];

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

  /// F24 #16: when it turned free again (someone left). For an hour only
  /// Trusted tenants can hold it (the server checks).
  DateTime? freedAt;

  /// F24 item 8: held for a walk-in until then (ms since epoch); 0 when not.
  int walkInUntil = 0;
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

  /// F24 item 7: the day the AC was marked not working ("3 Oct"), when known.
  String acSince = '';
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

const homeOf = {'tenant': 'explore', 'resident': 'rHome', 'owner': 'oToday'};

// ------------------------------------------------------------ F07 Fair Play

/// Owners' phone numbers: tenants see them only after a hold (DECISIONS).
/// F24 Wave 4c: an owner's WhatsApp when it isn't their phone number.
final ownerWhatsApps = <String, String>{};

/// The number WhatsApp links use for a hostel's owner: their WhatsApp, else
/// their phone ('' when neither is known).
String ownerWa(String hid) => (ownerWhatsApps[hid] ?? '').isNotEmpty ? ownerWhatsApps[hid]! : ownerPhones[hid] ?? '';

final ownerPhones = <String, String>{'anjani': '9000000101', 'saisri': '9000000102', 'nest42': '9000000103', 'greenview': '9000000104', 'orchid': '9000000105', 'lakshmi': '9000000106'};

/// "98••• •••••"
String maskPhone(String p) => p.length < 2 ? '••••• •••••' : '${p.substring(0, 2)}••• •••••';

// ------------------------------------------------------------ F14 onboarding

const _seedIds = ['anjani', 'saisri', 'nest42', 'greenview', 'orchid', 'lakshmi'];

bool isSeedHostel(String id) => _seedIds.contains(id);

/// Drop hostels added in an earlier session (data lives in memory until F13).
void resetSampleData() {
  hostels.removeWhere((h) => !_seedIds.contains(h.id));
  ownerPhones.removeWhere((k, _) => !_seedIds.contains(k));
  ownerWhatsApps.clear();
  liveListings = false;
  livePos.clear();
}

/// F13: true once live hostels came from the database. Tenants then browse
/// only those; the sample hostels stay only behind the owner and resident
/// sample screens until those are online too.
bool liveListings = false;

/// Hostels a tenant can find (Explore, map, ranking).
List<Hostel> get browsable => liveListings ? hostels.where((h) => !_seedIds.contains(h.id) && h.live).toList() : hostels;

/// Map positions of live hostels (from the database).
final livePos = <String, (double, double)>{};
