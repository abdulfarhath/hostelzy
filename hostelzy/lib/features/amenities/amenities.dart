part of '../../state.dart';

// F23: floor amenities (fridge, washing machine, RO…) and room items (a
// geyser in the room washroom). Owners, managers and the hostel's residents
// add or change them; everyone else only sees them.
mixin _AmenityData {
  /// Every hostel's things: sample data in demo builds, the server's otherwise.
  List<Amenity> amenities = AppState.samples ? seedAmenities() : [];

  /// The floor sheet and the add / change sheet.
  String amHid = 'anjani';
  int amFloor = 2;
  Amenity? amDraft;

  /// "Something broke": the floor sheet's rows turn into Not working buttons.
  bool amBreak = false;

  /// Owner Layouts: Rooms or Shared things.
  String amOwnerTab = 'rooms';

  /// Tenant filters: things that must be on a floor (or in the washroom).
  Set<String> fAm = {};

  /// Resident changes today, per hostel (sample data; the server counts its own).
  final Map<String, int> amEditsToday = {};
}

/// Sample things for the demo hostels.
List<Amenity> seedAmenities() {
  final day = DateTime(2026, 10, 1).millisecondsSinceEpoch, before = DateTime(2026, 9, 28).millisecondsSinceEpoch;
  var n = 0;
  Amenity a(String hid, int floor, String kind, {bool working = true, String place = 'floor', List<int> rooms = const [], bool res = false, int? at}) =>
      Amenity(id: 'am${n++}', hid: hid, floor: floor, kind: kind, working: working, place: place, rooms: rooms, byResident: res, at: at ?? before);
  return [
    a('anjani', 0, 'lift'),
    a('anjani', 0, 'shoes'),
    a('anjani', 1, 'fridge'),
    a('anjani', 1, 'ro'),
    a('anjani', 1, 'washer'),
    a('anjani', 2, 'fridge'),
    a('anjani', 2, 'ro'),
    a('anjani', 2, 'geyser', place: 'washroom', rooms: [201, 203]),
    a('anjani', 2, 'washer', working: false, res: true, at: day),
    a('anjani', 3, 'ro'),
    a('anjani', 3, 'iron'),
    a('saisri', 1, 'fridge'),
    a('saisri', 1, 'ro'),
    a('saisri', 2, 'washer'),
  ];
}

extension AmenityActions on AppState {
  /// A floor's things, shared ones first, by kind order.
  List<Amenity> amenitiesOn(String hid, int floor) {
    final order = [for (final k in amenityKinds) k.$1];
    return amenities.where((a) => a.hid == hid && a.floor == floor).toList()..sort((x, y) {
      if (x.inRooms != y.inRooms) return x.inRooms ? 1 : -1;
      return order.indexOf(x.kind).compareTo(order.indexOf(y.kind));
    });
  }

  /// Floors with things, lowest first.
  List<int> amenityFloors(String hid) => {for (final a in amenities.where((a) => a.hid == hid)) a.floor}.toList()..sort();

  /// What's inside one room (a geyser in its washroom…).
  List<Amenity> inRoom(String hid, int room) => amenities.where((a) => a.hid == hid && a.inRooms && a.rooms.contains(room)).toList();

  /// "Ground floor", "Floor 2".
  String floorName(int f) => f == 0 ? 'Ground floor' : 'Floor $f';

  /// The rooms on a floor of a hostel.
  List<Room> roomsOnFloor(String hid, int floor) => (rooms[hid] ?? const <Room>[]).where((r) => r.floor == floor).toList();

  /// "Geyser in 4 of 6 rooms", "Fridge", "Washing machine ×2".
  String amenityLine(Amenity a) {
    if (a.inRooms) {
      final all = roomsOnFloor(a.hid, a.floor).length;
      return '${a.label} in ${a.rooms.length == all ? 'every room' : '${a.rooms.length} of $all rooms'}';
    }
    return a.qty > 1 ? '${a.label} ×${a.qty}' : a.label;
  }

  /// "In the room washroom of 201, 202, 204"
  String amenityWhere(Amenity a) => switch (a.place) {
    'washroom' => 'In the room washroom of ${a.rooms.join(', ')}',
    'room' => 'In rooms ${a.rooms.join(', ')}',
    _ => a.qty > 1 ? '${a.qty} on this floor' : 'On this floor',
  };

  /// Owners and managers of [hid], the Hostelzy team, and its residents can
  /// change the list; tenants only see it.
  bool canEditAmenities(String hid) => (role == 'owner' && ownHid == hid) || teamUnlocked || isResidentOf(hid);
  bool isResidentOf(String hid) => role == 'resident' && myStay?.hid == hid;
  bool amenityStaff(String hid) => (role == 'owner' && ownHid == hid) || teamUnlocked;

  void openFloorSheet(String hid, int floor) => update(() {
    amHid = hid;
    amFloor = floor;
    amBreak = false;
    sheet = 'amFloor';
  });

  /// The add sheet, or the change sheet for [edit].
  void openAddAmenity({Amenity? edit, String? hid, int? floor}) => update(() {
    if (hid != null) amHid = hid;
    if (floor != null) amFloor = floor;
    amDraft = edit != null
        ? Amenity(id: edit.id, key: edit.key, hid: edit.hid, floor: edit.floor, kind: edit.kind, name: edit.name, qty: edit.qty, working: edit.working, place: edit.place, rooms: List.of(edit.rooms), byResident: edit.byResident, at: edit.at)
        : Amenity(id: 'new', hid: amHid, floor: amFloor, kind: '', qty: 1);
    sheet = 'amAdd';
  });

  /// Pick what it is. A geyser goes in the room washroom unless changed.
  void pickAmenityKind(String kind) => update(() {
    final d = amDraft!;
    final wasGeyser = d.kind == 'geyser';
    d.kind = kind;
    if (kind == 'geyser' && d.place == 'floor' && d.key == null) {
      d.place = 'washroom';
      d.rooms = [for (final r in roomsOnFloor(d.hid, d.floor)) if (r.bath == 'Attached') r.n];
    } else if (wasGeyser && kind != 'geyser' && d.key == null) {
      d.place = 'floor';
      d.rooms = [];
    }
  });

  void setAmenityPlace(String place) => update(() {
    final d = amDraft!;
    d.place = place;
    d.rooms = place == 'floor' ? [] : (d.rooms.isEmpty ? [for (final r in roomsOnFloor(d.hid, d.floor)) r.n] : d.rooms);
  });

  void toggleAmenityRoom(int n) => update(() {
    final d = amDraft!;
    d.rooms = d.rooms.contains(n) ? (d.rooms.where((x) => x != n).toList()) : ([...d.rooms, n]..sort());
  });

  void allAmenityRooms() => update(() => amDraft!.rooms = [for (final r in roomsOnFloor(amDraft!.hid, amDraft!.floor)) r.n]);

  /// "Save · Geyser in 4 room washrooms", "Save · Fridge on floor 2".
  String amenitySaveLabel(Amenity d) {
    if (d.kind.isEmpty) return 'Pick what it is';
    final what = d.qty > 1 && !d.inRooms ? '${d.qty} × ${d.label}' : d.label;
    return switch (d.place) {
      'washroom' => 'Save · $what in ${d.rooms.length} room washroom${d.rooms.length == 1 ? '' : 's'}',
      'room' => 'Save · $what in ${d.rooms.length} room${d.rooms.length == 1 ? '' : 's'}',
      _ => 'Save · $what on ${floorName(d.floor).toLowerCase()}',
    };
  }

  /// Save the draft: the owner's changes go live at once; a resident's too,
  /// tagged "Added by a resident", and the owner is told (at most 20 a day).
  Future<void> saveAmenityDraft() async {
    final d = amDraft;
    if (d == null) return;
    if (d.kind.isEmpty) return toastMsg('Pick what it is first.');
    if (d.kind == 'other' && d.name.trim().length < 2) return toastMsg('Type what it is.');
    if (d.inRooms && d.rooms.isEmpty) return toastMsg('Pick the rooms that have it.');
    final res = !amenityStaff(d.hid);
    if (res && !isResidentOf(d.hid)) return toastMsg('Only residents of this hostel can change this list.');
    if (res && !onServer && (amEditsToday[d.hid] ?? 0) >= 20) return toastMsg('That’s 20 changes today. Try again tomorrow.');
    d
      ..byResident = res
      ..at = now
      ..name = d.kind == 'other' ? d.name.trim() : '';
    String? key = d.key;
    if (onServer) {
      try {
        key = await data.saveAmenity(d);
      } catch (e) {
        debugPrint('amenity: $e');
        return toastMsg(_serverWords(e) ?? 'Couldn’t save it. Check your internet and try again.');
      }
    }
    final saved = Amenity(id: key ?? (d.id == 'new' ? 'am${now}_${amenities.length}' : d.id), key: key, hid: d.hid, floor: d.floor, kind: d.kind, name: d.name, qty: d.qty, working: d.working, place: d.place, rooms: d.rooms, byResident: res, at: now);
    final label = amenitySaveLabel(d).replaceFirst('Save · ', '');
    update(() {
      amenities = [...amenities.where((a) => a.id != d.id), saved];
      if (res) amEditsToday[d.hid] = (amEditsToday[d.hid] ?? 0) + 1;
      amDraft = null;
      amFloor = d.floor;
      sheet = 'amFloor';
    });
    toastMsg(res ? 'Saved: $label. ${hostelById(d.hid).owner} sees the change.' : 'Saved: $label.');
  }

  Future<void> removeAmenity(Amenity a) async {
    if (!canEditAmenities(a.hid)) return;
    if (onServer && a.key != null) {
      try {
        await data.removeAmenity(a.key!);
      } catch (e) {
        debugPrint('amenity: $e');
        return toastMsg(_serverWords(e) ?? 'Couldn’t remove it. Check your internet and try again.');
      }
    }
    update(() {
      amenities = amenities.where((x) => x.id != a.id).toList();
      amDraft = null;
      sheet = 'amFloor';
    });
    toastMsg('Removed: ${a.label} on ${floorName(a.floor).toLowerCase()}.');
  }

  /// "Something broke" / "Working again", in one tap.
  Future<void> setAmenityWorking(Amenity a, bool working) async {
    if (!canEditAmenities(a.hid)) return;
    update(() => amDraft = Amenity(id: a.id, key: a.key, hid: a.hid, floor: a.floor, kind: a.kind, name: a.name, qty: a.qty, working: working, place: a.place, rooms: List.of(a.rooms)));
    await saveAmenityDraft();
    update(() => amBreak = false);
  }

  /// Broken things in the owner's hostel, for "Needs you now".
  List<Amenity> get brokenThings => amenities.where((a) => a.hid == ownHid && !a.working).toList();

  /// The newest change a resident made to [hid]'s list on [floor].
  Amenity? lastResidentChange(String hid, int floor) {
    final r = amenities.where((a) => a.hid == hid && a.floor == floor && a.byResident).toList()..sort((x, y) => y.at.compareTo(x.at));
    return r.firstOrNull;
  }

  /// Hostel filter: every picked thing is somewhere in the hostel and working.
  bool hasAmenities(String hid, Set<String> kinds) {
    for (final k in kinds) {
      final ok = k == 'geyser'
          ? amenities.any((a) => a.hid == hid && a.kind == 'geyser' && a.place == 'washroom' && a.working)
          : amenities.any((a) => a.hid == hid && a.kind == k && !a.inRooms && a.working);
      if (!ok) return false;
    }
    return true;
  }

  /// A Postgres error's message, when it's one of ours in plain words.
  String? _serverWords(Object e) {
    final m = RegExp(r'message: ([^,]+)').firstMatch('$e')?.group(1) ?? '';
    if (m.isEmpty) return null;
    return '${m[0].toUpperCase()}${m.substring(1)}.';
  }
}
