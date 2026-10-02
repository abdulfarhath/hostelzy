part of '../../state.dart';

// F18 owner edits layouts
mixin _OwnerLayoutsData {

  /// DECISIONS 2026-10-02: owners edit and publish their own layouts; the
  /// Hostelzy team can still draw one for them. True while the owner edits.
  bool edOwner = false;

  /// Room layouts list filter: all | live | draft | none.
  String layoutsF = 'all';

  /// Create-a-layout draft (feet).
  String clLen = '', clWid = '';

  /// What tenants saw before the last publish, for "Undo publish".
  ({int room, LayoutSnap? snap, int version})? lastPublish;
}

extension OwnerLayoutsActions on AppState {

  /// Owner taps a room: its layout, or "Create a layout" when it has none.
  void ownerLayout(int n) {
    if (layoutOf(ownHid, n) != null) return openLayout(n);
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    final l = mkLayout(ownHid, r, street: true);
    update(() {
      lRoom = n;
      clLen = '${l.w.round()}';
      clWid = '${l.h.round()}';
      hist = [...hist, screen];
      screen = 'oCreate';
      sheet = null;
    });
  }

  /// The nearest room of the same type that already has a layout to copy.
  Room? copySource(int n) {
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    return rooms[ownHid]!.where((x) => x.n != n && x.share == r.share && x.ac == r.ac && layoutOf(ownHid, x.n) != null).firstOrNull;
  }

  /// Start drawing: a rectangle of the given size, or a copy of [from].
  void createLayout({int? from}) {
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
      l.mirrorTo(len, wid);
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
        ..request = null
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
