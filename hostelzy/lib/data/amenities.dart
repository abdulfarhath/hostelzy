
// ------------------------------------------------------------ F23 amenities

/// F23: the shared things on a floor (fridge, washing machine, RO…) and the
/// few that live inside rooms (a geyser in the room washroom). Positions on
/// the map don't matter; "Floor 2 has a fridge" is enough. Never CCTV, gates
/// or exits (DECISIONS).
const amenityKinds = <(String, String, String)>[
  // (kind, label, icon)
  ('fridge', 'Fridge', 'fridge'),
  ('washer', 'Washing machine', 'washer'),
  ('ro', 'Water purifier (RO)', 'ro'),
  ('cooler', 'Water cooler', 'cooler'),
  ('geyser', 'Geyser', 'geyser'),
  ('microwave', 'Microwave', 'microwave'),
  ('stove', 'Induction / stove', 'stove'),
  ('iron', 'Iron + board', 'iron'),
  ('tv', 'TV', 'tv'),
  ('wifi', 'Wi-Fi router', 'wifi'),
  ('drying', 'Drying stand', 'drying'),
  ('shoes', 'Shoe rack', 'shoes'),
  ('lift', 'Lift', 'lift'),
  ('dustbin', 'Dustbin', 'trash'),
  ('other', 'Other', 'plus'),
];

/// Short names for chips: "RO water", not "Water purifier (RO)".
String amenityShort(String kind) => const {'ro': 'RO water', 'stove': 'Stove', 'iron': 'Iron', 'wifi': 'Wi-Fi', 'washer': 'Washing machine'}[kind] ?? amenityKinds.firstWhere((k) => k.$1 == kind, orElse: () => amenityKinds.last).$2;

class Amenity {
  Amenity({required this.id, required this.hid, required this.floor, required this.kind, this.name = '', this.qty = 1, this.working = true, this.place = 'floor', this.rooms = const [], this.byResident = false, this.at = 0, this.key});
  final String id, hid;
  int floor;
  String kind;

  /// The typed name for "Other".
  String name;
  int qty;
  bool working;

  /// floor (shared) · washroom (in the room washroom) · room (in the room).
  String place;

  /// For washroom / room items: which rooms on this floor have it.
  List<int> rooms;

  /// Added or last changed by a resident (owners can correct it).
  bool byResident;
  int at;

  /// The server row id (null on sample data).
  final String? key;

  String get label => kind == 'other' && name.trim().isNotEmpty ? name.trim() : amenityShort(kind);
  bool get inRooms => place != 'floor';
}
