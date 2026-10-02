part of '../../state.dart';

// F14 rooms after go-live
mixin _RoomsLiveData {

  /// Add-a-room sheet draft.
  int nrFloor = 1, nrShare = 3;
  bool nrAc = false;
  String nrLabel = '';
}

extension RoomsLiveActions on AppState {

  /// Why a room can't be removed (a resident or a hold on it), or null.
  String? roomBlock(String hid, int n) {
    final r = rooms[hid]!.firstWhere((r) => r.n == n);
    final busy = r.beds.where((b) => b.state != 'free' || residents.any((x) => x.bed == b.id) || holds.any((h) => h.hid == hid && h.bed == b.id && h.status != 'released')).toList();
    if (busy.isEmpty) return null;
    return residents.any((x) => busy.any((b) => b.id == x.bed)) || busy.any((b) => b.state == 'booked') ? 'Has a resident' : 'Has a hold';
  }

  void openAddRoom(String hid, int floor) {
    final onFloor = rooms[hid]!.where((r) => r.floor == floor).map((r) => r.n).toList();
    var n = floor * 100 + 1;
    while (onFloor.contains(n) || rooms[hid]!.any((r) => r.label == '$n')) {
      n++;
    }
    update(() {
      nrFloor = floor;
      nrLabel = '$n';
      nrShare = 3;
      nrAc = false;
      sheet = 'addRoom';
    });
  }

  void addRoom(String hid) {
    final label = nrLabel.trim().toUpperCase();
    if (label.isEmpty) return toastMsg('Give the room a number.');
    if (rooms[hid]!.any((r) => r.label == label)) return toastMsg('Room $label already exists.');
    final rs = rooms[hid]!;
    var n = nrFloor * 100 + 1;
    while (rs.any((r) => r.n == n)) {
      n++;
    }
    final rent = rates[hid]?[rateKey(nrAc, nrShare)] ?? 0;
    if (rent == 0) return toastMsg('Add a price for $nrShare sharing ${nrAc ? 'AC' : 'Non-AC'} in Manage → Rates first.');
    final before = List.of(rs);
    update(() {
      rs.add(Room(
        n: n,
        floor: nrFloor,
        share: nrShare,
        ac: nrAc,
        rent: rent,
        bath: 'Attached',
        name: label == '$n' ? null : label,
        beds: [for (var k = 0; k < nrShare; k++) Bed(id: '$label-${'ABCD'[k]}', letter: 'ABCD'[k], room: n, floor: nrFloor, spot: spots[nrShare]![k], state: 'free', soon: '')],
      ));
      rs.sort((a, b) => a.floor != b.floor ? a.floor - b.floor : a.n - b.n);
      sheet = null;
    });
    _saveRoomsLive(hid, before, 'Room $label added with $nrShare free beds. Hostelzy draws its layout on the next visit.');
  }

  /// F24 item 3: on the server the hostel's rooms are saved as a list; if the
  /// server says no (someone moved in meanwhile), the change is undone.
  Future<void> _saveRoomsLive(String hid, List<Room> before, String done) async {
    if (!onServer) return toastMsg(done);
    try {
      await data.saveRooms(hid, [
        for (final r in rooms[hid]!) {'number': r.n, 'label': r.name, 'floor': r.floor, 'share': r.share, 'ac': r.ac, 'rent': r.rent, 'bath': r.bath},
      ]);
      await refreshListings();
      toastMsg(done);
    } catch (e) {
      debugPrint('rooms: $e');
      update(() => rooms[hid] = before);
      final m = '$e';
      final i = m.indexOf('room ');
      toastMsg(m.contains('has someone in it') && i >= 0 ? 'Not saved: ${m.substring(i, m.indexOf('in it', i) + 5)}.' : 'Couldn’t save it. Check your internet and try again.');
    }
  }

  void removeRoom(String hid, int n) {
    final why = roomBlock(hid, n);
    final r = rooms[hid]!.firstWhere((r) => r.n == n);
    if (why != null) return toastMsg('Room ${r.label} can’t be removed: ${why.toLowerCase()}.');
    final before = List.of(rooms[hid]!);
    update(() {
      rooms[hid]!.removeWhere((x) => x.n == n);
      layouts[hid]?.remove(n);
    });
    _saveRoomsLive(hid, before, 'Room ${r.label} removed.');
  }

  /// A new floor above the top one, starting with one room.
  void addFloor(String hid) {
    final top = rooms[hid]!.fold<int>(0, (a, r) => r.floor > a ? r.floor : a);
    openAddRoom(hid, top + 1);
  }

  void removeFloor(String hid, int floor) {
    final rs = rooms[hid]!.where((r) => r.floor == floor).toList();
    final blocked = rs.where((r) => roomBlock(hid, r.n) != null).toList();
    if (blocked.isNotEmpty) return toastMsg('Floor $floor can’t be removed: room ${blocked.map((r) => r.label).join(', ')} ${blocked.length == 1 ? 'has' : 'have'} a resident or hold.');
    final before = List.of(rooms[hid]!);
    update(() {
      rooms[hid]!.removeWhere((r) => r.floor == floor);
      for (final r in rs) {
        layouts[hid]?.remove(r.n);
      }
    });
    _saveRoomsLive(hid, before, 'Floor $floor removed.');
  }
}
