part of '../../state.dart';

// layout editor
mixin _LayoutEditorData {

  /// Selected thing in the editor: an item id, or `bed:A`.
  String? edSel;
  final List<LayoutSnap> _undo = [], _redo = [];
  Offset _dragStart = Offset.zero, _dragTotal = Offset.zero;
  String? _dragId;

  /// Days since the owner confirmed the layouts still match the rooms.
  final Map<String, int> layoutConfirmed = Map.of(seedLayoutConfirmed);
}

extension LayoutEditorActions on AppState {
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _remember(RoomLayout l) {
    // The first edit of a live layout keeps a copy for tenants until the
    // owner approves the new version.
    if (!l.pending) l.published ??= l.snap();
    _undo.add(l.snap());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  Rect? _selRect(RoomLayout l) {
    final id = edSel;
    if (id == null) return null;
    if (id.startsWith('bed:')) return l.beds.containsKey(id.substring(4)) ? l.bedRect(id.substring(4)) : null;
    return l.items.where((i) => i.id == id).firstOrNull?.rect;
  }

  /// Move the selected thing so its top-left is [to] (feet), on the 1-ft
  /// grid and inside the room.
  void _place(RoomLayout l, Offset to) {
    final r = _selRect(l);
    if (r == null) return;
    final x = to.dx.roundToDouble().clamp(0, l.w - r.width).toDouble();
    final y = to.dy.roundToDouble().clamp(0, l.h - r.height).toDouble();
    final id = edSel!;
    if (id.startsWith('bed:')) {
      // A bunk bed moves as one: both beds share the spot.
      final b = l.bunks[id.substring(4)] ?? id.substring(4);
      l.beds[b] = Offset(x, y);
      final up = l.upperOn(b);
      if (up != null) l.beds[up] = Offset(x, y);
    } else {
      final i = l.items.firstWhere((i) => i.id == id);
      i
        ..x = x
        ..y = y;
    }
  }

  /// Drag from the editor map: [d] in feet since the last update.
  void edDrag(RoomLayout l, String id, Offset d) {
    if (_dragId != id) {
      _dragId = id;
      edSel = id;
      _remember(l);
      _dragStart = _selRect(l)!.topLeft;
      _dragTotal = Offset.zero;
    }
    _dragTotal += d;
    update(() => _place(l, _dragStart + _dragTotal));
  }

  /// Ends a drag (the next drag starts a new undo step).
  void edDragEnd() => _dragId = null;

  void edNudge(RoomLayout l, double dx, double dy) {
    final r = _selRect(l);
    if (r == null) return toastMsg('Tap a bed or an item first.');
    _remember(l);
    update(() => _place(l, r.topLeft + Offset(dx, dy)));
  }

  void edAdd(RoomLayout l, Room room, String kind) {
    if (kind == 'bed') {
      final missing = room.beds.map((b) => b.letter).where((x) => !l.beds.containsKey(x)).firstOrNull;
      if (missing == null) return toastMsg('All ${room.share} beds are placed. A new bed changes the sharing: the owner confirms the price first.');
      _remember(l);
      update(() {
        l.beds[missing] = Offset(((l.w - bedW) / 2).roundToDouble(), ((l.h - bedH) / 2).roundToDouble());
        edSel = 'bed:$missing';
      });
      return;
    }
    final n = l.items.where((i) => i.kind == kind).length + 1;
    var id = '$kind$n';
    while (l.items.any((i) => i.id == id)) {
      id = '${id}x';
    }
    final (w, h, x, y) = switch (kind) {
      'ac' => (.5, 1.8, l.w - .5, (l.h / 2).roundToDouble()),
      'window' => (4.0, .3, ((l.w - 4) / 2).roundToDouble(), 0.0),
      'door' => (3.0, .2, ((l.w - 3) / 2).roundToDouble(), l.h - .2),
      'wash' => (5.0, 4.0, 0.0, l.h - 4),
      'pillar' => (1.5, 1.5, ((l.w - 1.5) / 2).roundToDouble(), ((l.h - 1.5) / 2).roundToDouble()),
      _ => (1.0, 1.0, (l.w / 2).roundToDouble(), (l.h / 2).roundToDouble()),
    };
    _remember(l);
    update(() {
      l.items.add(LItem(id, kind, x, y, w, h, facing: kind == 'window' ? 'street' : null));
      edSel = id;
    });
  }

  void edDelete(RoomLayout l, Room room) {
    final id = edSel;
    if (id == null) return toastMsg('Tap a bed or an item first.');
    if (id.startsWith('bed:')) {
      final bedId = '${room.label}-${id.substring(4)}';
      if (residents.any((r) => r.bed == bedId) || findBed(l.hid, bedId).b?.state == 'booked') return toastMsg('Bed $bedId has a resident. It can’t be deleted.');
    }
    _remember(l);
    update(() {
      if (id.startsWith('bed:')) {
        final b = id.substring(4);
        l.beds.remove(b);
        l.bunks.remove(b);
        l.bunks.removeWhere((_, lower) => lower == b);
      } else {
        l.items.removeWhere((i) => i.id == id);
      }
      edSel = null;
    });
  }

  /// AC, window and door go to the next wall (top → right → bottom → left);
  /// a washroom zone or pillar turns 90°.
  void edRotate(RoomLayout l) {
    final id = edSel;
    final i = id == null ? null : l.items.where((x) => x.id == id).firstOrNull;
    if (i == null) return toastMsg('Tap an AC, window, door, washroom or pillar to turn it.');
    _remember(l);
    update(() {
      if (const ['ac', 'window', 'door'].contains(i.kind)) {
        const order = ['top', 'right', 'bottom', 'left'];
        final next = order[(order.indexOf(wallOf(i.rect, l.w, l.h) ?? 'left') + 1) % 4];
        final len = math.max(i.w, i.h), thick = math.min(i.w, i.h);
        switch (next) {
          case 'top' || 'bottom':
            i
              ..w = len
              ..h = thick
              ..x = ((l.w - len) / 2).roundToDouble()
              ..y = next == 'top' ? 0 : l.h - thick;
          default:
            i
              ..w = thick
              ..h = len
              ..y = ((l.h - len) / 2).roundToDouble()
              ..x = next == 'left' ? 0 : l.w - thick;
        }
      } else {
        final w0 = i.w;
        i
          ..w = i.h
          ..h = w0
          ..x = i.x.clamp(0, math.max(0, l.w - i.w)).toDouble()
          ..y = i.y.clamp(0, math.max(0, l.h - i.h)).toDouble();
      }
    });
  }

  /// Room size in feet (8 to 30), keeping everything inside the walls.
  void edResize(RoomLayout l, double dw, double dh) {
    final w = (l.w + dw).clamp(8, 30).toDouble(), h = (l.h + dh).clamp(8, 30).toDouble();
    if (w == l.w && h == l.h) return;
    _remember(l);
    update(() {
      final oldW = l.w, oldH = l.h;
      l
        ..w = w
        ..h = h;
      for (final i in l.items) {
        // Items on the right / bottom wall stay on it.
        if (i.x + i.w >= oldW - .5) i.x = w - i.w;
        if (i.y + i.h >= oldH - .5) i.y = h - i.h;
        i
          ..x = i.x.clamp(0, math.max(0, w - i.w)).toDouble()
          ..y = i.y.clamp(0, math.max(0, h - i.h)).toDouble();
      }
      for (final k in l.beds.keys.toList()) {
        final b = l.beds[k]!;
        l.beds[k] = Offset(b.dx.clamp(0, w - bedW).toDouble(), b.dy.clamp(0, h - bedH).toDouble());
      }
    });
  }

  void edUndo(RoomLayout l) {
    if (_undo.isEmpty) return;
    update(() {
      _redo.add(l.snap());
      l.restore(_undo.removeLast());
    });
  }

  void edRedo(RoomLayout l) {
    if (_redo.isEmpty) return;
    update(() {
      _undo.add(l.snap());
      l.restore(_redo.removeLast());
    });
  }

  /// Stack another bed on the selected one as a bunk (upper over lower), or
  /// take a bunk apart again.
  void edBunk(RoomLayout l, Room room) {
    final id = edSel;
    if (id == null || !id.startsWith('bed:')) return toastMsg('Tap a bed first.');
    final b = id.substring(4);
    final lower = l.bunks[b] ?? b;
    final upper = l.upperOn(lower);
    _remember(l);
    if (upper != null) {
      update(() {
        l.bunks.remove(upper);
        final p = l.beds[lower]!;
        l.beds[upper] = Offset(p.dx + bedW + 1 > l.w - bedW ? (p.dx - bedW - 1).clamp(0, l.w - bedW).toDouble() : p.dx + bedW + 1, p.dy);
      });
      return toastMsg('Bunk taken apart: two single beds.');
    }
    final p0 = l.bedRect(lower).center;
    final other = (l.beds.keys.where((k) => k != lower && !l.bunks.containsKey(k) && l.upperOn(k) == null).toList()..sort((a, c) => (l.bedRect(a).center - p0).distance.compareTo((l.bedRect(c).center - p0).distance))).firstOrNull;
    if (other == null) return toastMsg('No single bed left to stack.');
    update(() {
      l.bunks[other] = lower;
      l.beds[other] = l.beds[lower]!;
    });
    toastMsg('Bed ${room.label}-$other is now the upper bunk over ${room.label}-$lower.');
  }

  /// Copy this layout to the other rooms of the same type (same sharing, AC
  /// or not) as new versions for the owner to approve.
  void copyToSameRooms(RoomLayout l, Room room) {
    final same = rooms[l.hid]!.where((r) => r.n != room.n && r.share == room.share && r.ac == room.ac).toList();
    if (same.isEmpty) return toastMsg('No other ${room.share}-sharing ${room.type} rooms here.');
    update(() {
      for (final r in same) {
        final t = layouts[l.hid]?[r.n];
        if (t == null) continue;
        if (!t.pending) t.published ??= t.snap();
        t
          ..restore(l.snap())
          ..version += t.pending ? 0 : 1
          ..pending = true
          ..drawn = dayMon(appToday);
      }
    });
    toastMsg('Copied to rooms ${same.map((r) => r.label).join(', ')} as new versions for the owner to approve.');
  }

  void confirmLayouts(String hid) {
    update(() => layoutConfirmed[hid] = 0);
    toastMsg('Thanks. Tenants see your layouts as confirmed today.');
  }

  void edMirror(RoomLayout l, {bool vertical = false}) {
    _remember(l);
    update(() => l.mirror(vertical: vertical));
  }

  /// Admin: send the new version to the owner for approval.
  void sendLayoutToOwner(RoomLayout l) {
    update(() {
      l
        ..version += l.pending ? 0 : 1
        ..pending = true
        ..drawn = dayMon(appToday)
        ..request = null;
    });
    toastMsg('v${l.version} is waiting for ${hostelById(l.hid).owner}’s approval.');
  }
}
