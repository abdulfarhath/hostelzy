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

  /// F24 Wave 4b (F12): a women's PG's rooms fetched one by one for the Room
  /// tab (`hid|room` → layout), and how each fetch went: loading | done |
  /// capped (the server wants a hold first) | failed.
  final Map<String, RoomLayout> peekLayouts = {};
  final Map<String, String> roomFetch = {};

  /// F24 item 27: rooms (`hid|room`) this tenant asked "Tell me when it's
  /// ready" for, and whether the server's list was loaded this session.
  final Set<String> layoutWaitSet = {};
  bool layoutWaitsLoaded = false;

  /// Admin editor: the selected AC unit's properties.
  final Map<String, String> acProps = {'Wall': 'Right', 'Blows': 'Left', 'Reach': '8 ft', 'Status': 'Working'};
}

extension RoomLayoutsActions on AppState {

  RoomLayout? layoutOf(String hid, int n) => layouts[hid]?[n];

  /// What tenants see: the last approved version.
  RoomLayout? liveLayout(String hid, int n) {
    final l = layoutOf(hid, n) ?? peekLayouts['$hid|$n'];
    return l != null && l.live ? l.forTenants : null;
  }

  /// F24 Wave 4b: a women's PG on the server lists its layouts only to
  /// people with a hold there, so the Room tab asks for this one room.
  bool needsRoomFetch(String hid, int n) => onServer && signedIn && hostelById(hid).gender == 'Women' && layoutOf(hid, n) == null && !roomFetch.containsKey('$hid|$n');

  Future<void> fetchRoomLayout(String hid, int n) async {
    final k = '$hid|$n';
    if (roomFetch[k] == 'loading') return;
    update(() => roomFetch[k] = 'loading');
    try {
      final l = await data.roomLayout(hid, n);
      update(() {
        if (l != null) peekLayouts[k] = l;
        roomFetch[k] = 'done';
      });
    } catch (e) {
      debugPrint('room layout: $e');
      update(() => roomFetch[k] = '$e'.contains('hold a bed') ? 'capped' : 'failed');
    }
  }

  /// F24 item 27: the rooms this tenant waits for, once a session.
  Future<void> loadLayoutWaits() async {
    if (!onServer || layoutWaitsLoaded || account == null) return;
    layoutWaitsLoaded = true;
    try {
      final w = await data.layoutWaits();
      update(() => layoutWaitSet.addAll(w));
    } catch (e) {
      debugPrint('layout waits: $e');
    }
  }

  bool waitingForLayout(String hid, int n) => layoutWaitSet.contains('$hid|$n');

  /// "Tell me when it's ready": saved on the server; when the owner publishes
  /// this room's layout the tenant gets one notification.
  Future<void> tellMeWhenReady(String hid, int n) async {
    final k = '$hid|$n';
    if (layoutWaitSet.contains(k)) return;
    final label = rooms[hid]?.where((r) => r.n == n).firstOrNull?.label ?? '$n';
    if (onServer) {
      try {
        await data.waitForLayout(hid, n);
      } catch (e) {
        debugPrint('wait for layout: $e');
        if ('$e'.contains('layout is ready')) {
          await refreshListings();
          return toastMsg('Room $label’s layout is ready now.');
        }
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
    }
    update(() => layoutWaitSet.add(k));
    toastMsg('We’ll tell you when room $label’s layout is ready.');
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
    void mark(bool v, String since) {
      i.working = v;
      // Working / not working shows to tenants right away, also on the live copy.
      for (final x in l.published?.items ?? const <LItem>[]) {
        if (x.id == i.id) x.working = v;
      }
      if (i.kind == 'ac') {
        r.acRepair = !v;
        r.acSince = v ? '' : since;
      }
    }

    // F24 item 7: on the server it is saved for tenants, and the server
    // raises (or closes) the hostel's complaint with its real date.
    if (onServer && !isSeedHostel(l.hid)) {
      update(() => mark(ok, r.acSince));
      data.setItemWorking(l.hid, l.room, i.id, ok).then((at) async {
        if (at != null && i.kind == 'ac') update(() => r.acSince = dayMon(at));
        toastMsg(ok ? '$name working again. Its complaint is closed.' : '$name marked not working. A complaint is raised.');
        await refreshLive();
      }, onError: (Object e) {
        debugPrint('working: $e');
        update(() => mark(!ok, ''));
        toastMsg('$e'.contains('publish this room') ? 'Publish this room’s layout first, then mark it.' : 'Couldn’t save it. Check your internet and try again.');
      });
      return;
    }
    update(() {
      mark(ok, dayMon(appToday));
      final what = '$name in room ${l.room} marked not working.';
      if (ok) {
        complaints = [for (final c in complaints) c.text == what && c.status != 'Resolved' ? c.copyWith(status: 'Resolved', note: 'Working again') : c];
      } else if (!complaints.any((c) => c.text == what && c.status != 'Resolved')) {
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
