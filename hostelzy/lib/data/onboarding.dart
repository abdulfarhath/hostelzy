import '../data.dart';

/// The owner is asked to confirm free beds every 3 days; after 7 days
/// tenants see "Availability not confirmed" and the hostel ranks lower.
const confirmEveryDays = 3, staleAfterDays = 7;

/// Days since each owner last confirmed their free beds (sample).
/// Days since each owner last confirmed their room layouts still match (F12:
/// every 3 months).
const seedLayoutConfirmed = {'anjani': 92, 'saisri': 20, 'nest42': 40, 'orchid': 10};

const layoutConfirmEvery = 90;

/// F03: rates are confirmed by the owner monthly. Owner Today asks from 30
/// days; after 31 days tenants see "Not confirmed in over a month".
const ratesConfirmEvery = 30, ratesStaleAfterDays = 31;

/// Days since each sample owner last confirmed their rates (demo only).
const seedRatesConfirmed = {'anjani': 12, 'saisri': 4, 'nest42': 20, 'greenview': 40, 'orchid': 9, 'lakshmi': 2};

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

  /// F24 Wave 4c: the owner's WhatsApp when it isn't their phone ('' = same);
  /// the map pin dropped at the gate (null until then); house rules typed on
  /// the visit.
  String ownerWa = '';
  (double, double)? pin;
  String visitors = 'Common area only, till 8 pm';

  /// The number the owner chats on.
  String get ownerChat => ownerWa.length == 10 ? ownerWa : ownerPhone;
  bool ownerVerified = false, fairPlay = false, bedsChecked = false;

  /// F24: the draft's id on the server once saved; the owner's one-time code
  /// and whether their account is linked; residents already saved as stays.
  String? serverId;
  String ownerCode = '';
  bool ownerLinked = false;
  final Set<String> savedResidents = {};

  HostelDraft();

  /// F24: an empty draft for real hostels (the sample one is for the demo).
  HostelDraft.blank() {
    name = '';
    area = '';
    gate = '';
    visitors = '';
    amenities = {};
    floors
      ..clear()
      ..addAll([DraftFloor('Ground floor', []), DraftFloor('1st floor', [])]);
    prices.clear();
    photos.clear();
    ownerName = '';
  }

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
