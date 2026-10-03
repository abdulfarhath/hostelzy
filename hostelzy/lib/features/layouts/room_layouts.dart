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

  /// "Ask Hostelzy to draw it" sheet draft (F24 item 11): what's different,
  /// the size (W × L ft), the shape and up to 3 photos.
  String lReqText = '', lReqLen = '', lReqWid = '', lReqShape = 'Custom';
  List<Uint8List> lReqPhotos = [];

  /// F24: owners' shape requests (this hostel's, from the server; on sample
  /// data kept here). Photos on sample data stay on this phone, by request.
  List<ShapeRequest> shapeReqs = [];
  final Map<String, List<Uint8List>> shapePhotosLocal = {};

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

  /// F24: the open "Ask Hostelzy to draw it" request for a room, if any.
  ShapeRequest? shapeReqFor(String hid, int n) => shapeReqs.where((q) => q.hid == hid && q.room == n && q.open).lastOrNull;

  /// F24: the hostel's shape requests from the server. Until the SQL runs
  /// (or offline) the list stays as it was.
  Future<void> loadShapeRequests(String hid) async {
    if (!onServer) return;
    try {
      final rs = await data.shapeRequests(hid);
      update(() => shapeReqs = [...shapeReqs.where((q) => q.hid != hid), ...rs]);
    } catch (e) {
      debugPrint('shape requests: $e');
    }
  }

  /// "Ask Hostelzy to draw it" for room [lRoom] ([shape]: the one picked, or
  /// the room's current shape).
  void openShapeRequest({String? shape}) {
    final l = layoutOf(ownHid, lRoom);
    update(() {
      lReqText = '';
      lReqLen = l != null ? '${l.w.round()}' : clLen;
      lReqWid = l != null ? '${l.h.round()}' : clWid;
      lReqShape = shape ?? l?.shape ?? 'Custom';
      lReqPhotos = [];
      sheet = 'layoutReq';
    });
  }

  Future<void> pickShapePhoto() async {
    if (lReqPhotos.length >= 3) return toastMsg('3 photos is the most.');
    final raw = await picker.pick();
    if (raw == null) return;
    final jpg = prepPhoto(raw, 'free');
    if (jpg == null) return toastMsg('That photo didn’t open. Try another one.');
    update(() => lReqPhotos = [...lReqPhotos, jpg]);
  }

  /// Send the request: on the server the team sees it in the console's Layout
  /// help queue (done within 48 hours); on sample data it waits here.
  Future<void> sendLayoutRequest() async {
    final hid = ownHid, n = lRoom;
    final note = lReqText.trim();
    if (note.isEmpty && lReqPhotos.isEmpty) return toastMsg('Say what’s different, or add a photo.');
    final w = double.tryParse(lReqLen) ?? 0, h = double.tryParse(lReqWid) ?? 0;
    final photos = List.of(lReqPhotos);
    if (onServer) {
      try {
        final paths = [for (final ph in photos) await data.uploadFixPhoto(hid, account!.uid, ph)];
        await data.requestShape(hid, n, shape: lReqShape, note: note, w: w, h: h, photos: paths);
      } catch (e) {
        debugPrint('shape request: $e');
        return toastMsg('Couldn’t send it. Check your internet and try again.');
      }
      await loadShapeRequests(hid);
    } else {
      final id = 'sr${DateTime.now().millisecondsSinceEpoch}';
      if (photos.isNotEmpty) shapePhotosLocal[id] = photos;
      update(() {
        for (final q in shapeReqs.where((q) => q.hid == hid && q.room == n && q.open)) {
          q.status = 'cancelled';
        }
        shapeReqs = [...shapeReqs, ShapeRequest(id: id, hid: hid, room: n, shape: lReqShape, note: note, w: w, h: h, photos: [for (var i = 0; i < photos.length; i++) '$id/$i'], at: DateTime.now().millisecondsSinceEpoch)];
      });
    }
    update(() {
      sheet = null;
      lReqPhotos = [];
    });
    toastMsg('Sent. The Hostelzy team draws it within 48 hours. You get a notification.');
  }

  /// F24 board oShapeBack: the team's drawing as a layout for room [n] (beds
  /// and things fitted inside its walls when the team sent only the shape).
  RoomLayout? drawnLayout(ShapeRequest q) {
    final d = q.drawing;
    if (q.status != 'sent' || d == null) return null;
    final r = rooms[q.hid]?.where((x) => x.n == q.room).firstOrNull;
    if (r == null) return null;
    final cur = layoutOf(q.hid, q.room);
    final l = mkLayout(q.hid, r, street: true)
      ..version = (cur?.version ?? 0) + (cur?.live ?? false ? 1 : 0)
      ..live = false
      ..drawn = dayMon(DateTime.fromMillisecondsSinceEpoch(q.sentAt ?? now));
    final snap = snapFromJson(d);
    if ((d['beds'] as Map?)?.isNotEmpty ?? false) {
      l.restore(snap);
    } else {
      if (cur != null) l.restore(cur.snap());
      l.mirrorTo(snap.w, snap.h);
      l.setShape(snap.shape, custom: snap.outline);
      l.fitInside();
    }
    if (l.version < 1) l.version = 1;
    return l;
  }

  /// "Publish v1": the team's drawing goes live for tenants.
  void publishDrawn(ShapeRequest q) {
    final d = drawnLayout(q);
    if (d == null) return;
    final cur = layoutOf(q.hid, q.room);
    update(() {
      if (cur == null) {
        (layouts[q.hid] ??= {})[q.room] = d;
      } else {
        if (cur.live) cur.published ??= cur.snap();
        cur.restore(d.snap());
      }
      lRoom = q.room;
      // On the server, publishing the room closes the request.
      if (!onServer) q.status = 'published';
    });
    publishLayout(layoutOf(q.hid, q.room)!);
  }
}
