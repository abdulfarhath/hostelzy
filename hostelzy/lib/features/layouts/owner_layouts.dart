part of '../../state.dart';

// F18 owner edits layouts
mixin _OwnerLayoutsData {

  /// DECISIONS 2026-10-02: owners edit and publish their own layouts; the
  /// Hostelzy team can still draw one for them. True while the owner edits.
  bool edOwner = false;

  /// Room layouts list filter: all | live | draft | none.
  String layoutsF = 'all';

  /// Create-a-layout draft (feet: width, length) and the room's shape (F24).
  String clLen = '', clWid = '', clShape = 'Rectangle';

  /// What tenants saw before the last publish, for "Undo publish".
  ({int room, LayoutSnap? snap, int version})? lastPublish;
}

extension OwnerLayoutsActions on AppState {

  /// Owner taps a room: its layout, or "Create a layout" when it has none.
  /// F24: a room Hostelzy is drawing opens its status ([create]: draw anyway).
  void ownerLayout(int n, {bool create = false}) {
    if (layoutOf(ownHid, n) != null || (!create && shapeReqFor(ownHid, n) != null)) return openLayout(n);
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    final l = mkLayout(ownHid, r, street: true);
    update(() {
      lRoom = n;
      clLen = '${l.w.round()}';
      clWid = '${l.h.round()}';
      clShape = 'Rectangle';
      hist = [...hist, screen];
      screen = 'oCreate';
      sheet = null;
    });
    loadShapeRequests(ownHid);
  }

  /// The nearest room of the same type that already has a layout to copy.
  Room? copySource(int n) {
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    return rooms[ownHid]!.where((x) => x.n != n && x.share == r.share && x.ac == r.ac && layoutOf(ownHid, x.n) != null).firstOrNull;
  }

  /// Start drawing: a room of the picked shape and size, or a copy of [from].
  /// F24: beds and things start inside the shape's walls.
  void createLayout({int? from}) {
    if (from == null && clShape == 'Custom') return openShapeRequest(shape: 'Custom');
    final r = rooms[ownHid]!.firstWhere((x) => x.n == lRoom);
    final len = double.tryParse(clLen) ?? 0, wid = double.tryParse(clWid) ?? 0;
    if (from == null && (len < 6 || wid < 6 || len > 60 || wid > 60)) return toastMsg('Enter the room size in feet (6 to 60).');
    final l = mkLayout(ownHid, r, street: true)
      ..published = null
      ..live = false
      ..drawn = dayMon(appToday);
    if (from != null) {
      l.restore(layoutOf(ownHid, from)!.snap());
    } else {
      l
        ..mirrorTo(len, wid)
        ..setShape(clShape)
        ..fitInside();
    }
    update(() {
      (layouts[ownHid] ??= {})[lRoom] = l;
      screen = 'oLayouts';
      hist = hist.where((x) => x != 'oCreate').toList();
    });
    openLayout(lRoom, editor: true, owner: true);
  }

  /// Owner publishes: tenants see this version now, no approval needed.
  void publishLayout(RoomLayout l) {
    if (onServer) {
      // F19 server: owners publish their own layouts (the server checks them).
      _write(() => data.publishLayout(l.hid, l.room, layoutJson(l.snap()))).then((ok) async {
        if (!ok) return;
        await refreshListings();
        // F24: publishing closed the room's answered shape request.
        await loadShapeRequests(l.hid);
        update(() {
          edOwner = false;
          screen = 'oPublished';
          sheet = null;
        });
      });
      return;
    }
    final wasLive = l.live;
    update(() {
      lastPublish = (room: l.room, snap: wasLive ? (l.published ?? l.snap()) : null, version: l.version);
      if (wasLive) l.version += 1;
      l
        ..live = true
        ..pending = false
        ..published = null
        ..drawn = dayMon(appToday);
      edOwner = false;
      screen = 'oPublished';
      sheet = null;
    });
  }

  /// "Undo publish · go back to vN" (or hide a first layout again).
  void undoPublish(RoomLayout l) {
    final u = lastPublish;
    if (u == null || u.room != l.room) return;
    update(() {
      if (u.snap == null) {
        l.live = false;
      } else {
        l
          ..restore(u.snap!)
          ..version = u.version;
      }
      lastPublish = null;
      screen = 'oLayout';
    });
    toastMsg(u.snap == null ? 'Unpublished. Tenants see “Layout coming soon” again.' : 'Back to v${u.version}. Tenants see it again.');
  }
}
