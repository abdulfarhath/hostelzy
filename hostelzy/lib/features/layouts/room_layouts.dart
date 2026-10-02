part of '../../state.dart';

// F12 room layouts
mixin _RoomLayoutsData {

  /// Room tab layer toggles: off by default (DECISIONS 2026-10-02).
  bool showFan = false, showAc = false;

  /// Layouts are only for people who signed in (Google, F13).
  bool signedIn = true;

  /// The two beds on Compare beds (letters in [room]).
  String cmpA = '', cmpB = '';

  /// The bed whose facts show in the Room tab (a letter), when not picked.
  String? roomBed;

  /// Owner (Beds → room layout) and the Hostelzy admin editor: which room.
  int lRoom = 204;

  /// Request-a-change sheet draft.
  String lReqText = '', lReqLen = '', lReqWid = '';
  Set<String> lReqAdded = {};

  /// Admin editor: the selected AC unit's properties.
  final Map<String, String> acProps = {'Wall': 'Right', 'Blows': 'Left', 'Reach': '8 ft', 'Status': 'Working'};
}

extension RoomLayoutsActions on AppState {

  RoomLayout? layoutOf(String hid, int n) => layouts[hid]?[n];

  /// What tenants see: the last approved version.
  RoomLayout? liveLayout(String hid, int n) {
    final l = layoutOf(hid, n);
    return l != null && l.live ? l.forTenants : null;
  }

  /// Women's PGs: whole-floor plans only after a hold here.
  bool floorLocked(String hid) => hostelById(hid).gender == 'Women' && !heldAt(hid);

  void openCompare() {
    final r = rooms[hid]!.firstWhere((x) => x.n == room);
    final free = r.beds.where(AppState._open).map((b) => b.letter).toList();
    if (free.length < 2) return toastMsg('Only one free bed in this room.');
    final sel = bed != null && free.contains(bed!.split('-').last) ? bed!.split('-').last : free.first;
    cmpA = sel;
    cmpB = free.firstWhere((x) => x != sel);
    go('compare');
  }

  /// Owner marks a fan, the AC or the window Working / Not working. Broken
  /// items show honestly to tenants and raise a complaint.
  void setWorking(RoomLayout l, LItem i, bool ok) {
    if (i.working == ok) return;
    final r = rooms[l.hid]!.firstWhere((x) => x.n == l.room);
    final name = switch (i.kind) {
      'fan' => 'Fan ${i.id.substring(3)}',
      'ac' => 'AC unit',
      _ => 'Window',
    };
    update(() {
      i.working = ok;
      // Working / not working shows to tenants right away, also on the live copy.
      for (final x in l.published?.items ?? const <LItem>[]) {
        if (x.id == i.id) x.working = ok;
      }
      if (i.kind == 'ac') r.acRepair = !ok;
      if (!ok) {
        final id = complaints.fold<int>(0, (a, c) => c.id > a ? c.id : a) + 1;
        complaints = [Complaint(id: id, by: 'Layout · ${l.room}', cat: i.kind == 'ac' ? 'AC' : i.kind == 'fan' ? 'Fan' : 'Window', text: '$name in room ${l.room} marked not working.', status: 'Open', date: dayMon(appToday), note: ''), ...complaints];
      }
    });
    toastMsg(ok ? '$name working again.' : '$name marked not working. A complaint is raised.');
  }

  void approveLayout(RoomLayout l) {
    update(() {
      l
        ..pending = false
        ..live = true
        ..published = null;
    });
    toastMsg('Room ${l.room} layout approved. Tenants see it now.');
  }

  void sendLayoutRequest() {
    final l = layoutOf(ownHid, lRoom);
    if (l == null) return toastMsg('This room has no layout yet.');
    if (lReqText.trim().isEmpty && lReqAdded.isEmpty) return toastMsg('Say what’s different, or add a photo.');
    update(() {
      l.request = (text: lReqText.trim(), added: Set.of(lReqAdded), size: lReqLen.isNotEmpty && lReqWid.isNotEmpty ? '$lReqLen × $lReqWid ft' : '', at: '${dayMon(appToday)}, 7:10 pm');
      sheet = null;
    });
    toastMsg('Request saved. It reaches the Hostelzy team once the app is online (F13).');
  }
}
