part of '../../state.dart';

// F19 residents fix room layouts
mixin _LayoutFixesData {

  /// Residents' fixes: on Supabase from the server; on sample data one waits
  /// for the owner of Anjani.
  List<LayoutFix> fixes = AppState.samples ? seedFixes() : [];

  /// The room being fixed or viewed ([fixHid], [fixRoom]) and the editor's
  /// working copy. Drafts stay on this phone until they are sent.
  String fixHid = 'anjani';
  int fixRoom = 203;
  RoomLayout? _fixLayout;
  final Map<String, LayoutSnap> fixDrafts = {};

  /// Send sheet note; the owner's open fix and reject reason.
  String fixNote = '', fixReason = '';
  String? fixId;

  /// Approved / rejected results the resident closed with Done.
  final Set<String> fixSeen = {};

  /// Public "Checked by N residents · date": hostel → room → (N, date).
  final Map<String, Map<int, (int, String)>> layoutChecks = {};
}

List<LayoutFix> seedFixes() => [
  LayoutFix(
    id: 'fx1',
    hid: 'anjani',
    room: 203,
    at: DateTime.now().subtract(const Duration(minutes: 12)).millisecondsSinceEpoch,
    author: 'Rahul V.',
    authorBed: '204-B',
    since: 'Mar 2026',
    note: 'The fan is over bed A, not in the middle.',
    snap: () {
      final rs = mkRooms(hostels[0], 0);
      fixAnjani(rs);
      final l = mkLayout('anjani', rs.firstWhere((r) => r.n == 203), street: true);
      final f = l.of('fan').first;
      final b = l.beds['A']!;
      f
        ..x = b.dx + 1
        ..y = b.dy + 2;
      return l.snap();
    }(),
  ),
];

extension LayoutFixesActions on AppState {
  /// The hostel this user lives in: on Supabase their confirmed stay; on
  /// sample data the resident lives at Anjani.
  String? get homeHid => AppState.samples ? (role == 'resident' ? 'anjani' : null) : myHostel;
  bool livesAt(String hid) => homeHid == hid;

  /// "204": the resident's own room, for the editor's subtitle.
  String get myRoomLabel => AppState.samples ? '204' : myBedLabel.split('-').first;

  String get _fixKey => '$fixHid|$fixRoom';
  RoomLayout? get fixLayout => _fixLayout;
  Room? get fixRoomOf => rooms[fixHid]?.where((r) => r.n == fixRoom).firstOrNull;

  /// This resident's fixes waiting for the owner at [hid].
  List<LayoutFix> myWaiting(String hid) => fixes.where((f) => f.mine && f.hid == hid && f.status == 'pending').toList();

  /// The resident's latest fix for a room (any status but withdrawn).
  LayoutFix? myFixFor(String hid, int room) => fixes.where((f) => f.mine && f.hid == hid && f.room == room && f.status != 'withdrawn').lastOrNull;

  /// Owner: fixes waiting at their hostel, oldest first.
  List<LayoutFix> get fixesWaiting => fixes.where((f) => f.hid == ownHid && f.status == 'pending').toList()..sort((a, b) => a.at.compareTo(b.at));

  /// The resident's room screen (board 1) for [room] at their hostel.
  void openFixRoom(int room) {
    final hid = homeHid;
    if (hid == null) return toastMsg('Only residents can fix room layouts. Ask your owner for your invite code.');
    update(() {
      fixHid = hid;
      fixRoom = room;
      hist = [...hist, screen];
      screen = 'rRoom';
      sheet = null;
    });
  }

  /// "Edit room": residents get the suggestion editor; everyone else the
  /// "residents only" sheet (board 0); 3 waiting fixes is the most (3c).
  void openFixEditor(String hid, int room) {
    final live = liveLayout(hid, room);
    update(() {
      fixHid = hid;
      fixRoom = room;
    });
    if (!livesAt(hid)) return update(() => sheet = 'fixLock');
    if (live == null) return toastMsg('This room has no layout yet. The owner or the Hostelzy team draws it first.');
    final open = myWaiting(hid);
    if (open.length >= 3 && !open.any((f) => f.room == room)) return update(() => sheet = 'fixLimit');
    final r = rooms[hid]!.firstWhere((x) => x.n == room);
    final l = RoomLayout(hid: hid, room: room, w: live.w, h: live.h, beds: {}, items: [], version: live.version, drawn: live.drawn)..restore(fixDrafts[_fixKey] ?? live.snap());
    _undo.clear();
    _redo.clear();
    update(() {
      _fixLayout = l;
      edSel = null;
      lRoom = r.n;
      hist = [...hist, screen];
      screen = 'rFix';
      sheet = null;
    });
  }

  /// Suggestion editor: Working / Not working on the draft only (the owner's
  /// copy and complaints change when the fix is approved).
  void fixSetWorking(LItem i, bool ok) {
    final l = _fixLayout;
    if (l == null || i.working == ok) return;
    _remember(l);
    update(() => i.working = ok);
  }

  /// Keep the draft on this phone and leave the editor.
  void leaveFixEditor() {
    final l = _fixLayout;
    if (l != null) fixDrafts[_fixKey] = l.snap();
    back();
  }

  /// Reset: throw away the draft and start again from the live layout.
  void resetFix() {
    final live = liveLayout(fixHid, fixRoom), l = _fixLayout;
    if (live == null || l == null) return;
    update(() {
      fixDrafts.remove(_fixKey);
      l.restore(live.snap());
      edSel = null;
      _undo.clear();
      _redo.clear();
    });
    toastMsg('Back to the live layout.');
  }

  /// The editor's checks (board 2): AC unit, bed count, residents' beds, no
  /// gates or exits. A failed check says why (board 3).
  List<(bool, String)> fixChecks(RoomLayout l, Room room) {
    final taken = [for (final b in room.beds) if (b.state == 'booked' || residents.any((x) => x.bed == b.id)) b.letter];
    final gone = taken.where((x) => !l.beds.containsKey(x)).firstOrNull;
    return [
      if (room.ac) (l.ac != null, l.ac != null ? 'AC room has an AC unit' : 'AC room needs an AC unit') else (true, 'Non-AC room · no AC unit needed'),
      (l.beds.length == room.share, '${l.beds.length} beds placed · ${room.share} sharing'),
      (gone == null, gone == null ? 'Beds with a resident stay in place' : 'Bed $gone has a resident · it can’t be deleted'),
      (true, 'No gates, CCTV or exits drawn'),
    ];
  }

  /// "Send to owner": the checks pass and something changed → the send sheet.
  void openSendFix() {
    final l = _fixLayout, room = fixRoomOf, live = liveLayout(fixHid, fixRoom);
    if (l == null || room == null || live == null) return;
    final bad = fixChecks(l, room).where((c) => !c.$1).firstOrNull;
    if (bad != null) return toastMsg('${bad.$2}. Fix it before sending.');
    if (layoutDiff(live.snap(), l.snap()).lines.isEmpty) return toastMsg('Nothing changed yet. Move things to where they really are.');
    update(() {
      fixNote = '';
      sheet = 'fixSend';
    });
  }

  /// Send the fix: on Supabase the server checks the stay and the rules and
  /// tells the owner; on sample data it waits here.
  Future<void> sendFix() async {
    final l = _fixLayout, live = liveLayout(fixHid, fixRoom);
    if (l == null || live == null) return;
    final snap = l.snap(), hid = fixHid, room = fixRoom, note = fixNote.trim();
    final owner = hostelById(hid).owner;
    if (onServer) {
      try {
        await data.sendLayoutFix(hid, room, layoutJson(snap), note);
      } catch (e) {
        final m = '$e';
        return toastMsg(m.contains('3 fixes waiting')
            ? 'You have 3 fixes waiting here. Send this one once $owner answers one.'
            : m.contains('only residents')
            ? 'Only residents of ${hostelById(hid).name} can fix its rooms.'
            : m.contains('has a resident') || m.contains('needs an AC') || m.contains('place ')
            ? 'This layout doesn’t pass the checks. Look at the list above Send.'
            : 'Couldn’t send it. Check your internet and try again.');
      }
      await refreshLive();
    } else {
      update(() {
        for (final f in fixes.where((f) => f.mine && f.hid == hid && f.room == room && f.status == 'pending')) {
          f.status = 'withdrawn';
        }
        fixes = [...fixes, LayoutFix(id: 'fx${DateTime.now().millisecondsSinceEpoch}', hid: hid, room: room, snap: snap, at: DateTime.now().millisecondsSinceEpoch, note: note, author: meShort, authorBed: '204-B', since: 'Mar 2026', mine: true, baseVersion: live.version)];
      });
    }
    update(() {
      fixDrafts.remove('$hid|$room');
      _fixLayout = null;
      sheet = null;
      hist = hist.where((x) => x != 'rFix').toList();
      screen = 'rRoom';
    });
    toastMsg('Sent to $owner. You get a notification when they decide.');
  }

  /// "Withdraw it": the fix stops waiting; tenants still see the live layout.
  Future<void> withdrawFix(LayoutFix f) async {
    if (onServer) {
      if (!await _write(() => data.withdrawLayoutFix(f.id))) return;
    } else {
      update(() => f.status = 'withdrawn');
    }
    toastMsg('Withdrawn. Nothing changes for tenants.');
  }

  /// "Change my suggestion" / "Edit room again": back to the editor with it.
  void changeFix(LayoutFix f) {
    fixDrafts['${f.hid}|${f.room}'] = f.snap;
    openFixEditor(f.hid, f.room);
  }

  /// Owner: compare a fix with the live layout (board 9).
  void openFix(LayoutFix f) => update(() {
    fixId = f.id;
    hist = [...hist, screen];
    screen = 'oFix';
    sheet = null;
  });

  LayoutFix? get openFixItem => fixes.where((f) => f.id == fixId).firstOrNull;

  /// "Approve & publish": the fix becomes the live layout (the old version
  /// stays in history) and the resident is told.
  Future<void> approveFix(LayoutFix f) async {
    final l = layoutOf(f.hid, f.room);
    if (l == null) return;
    if (onServer) {
      try {
        await data.decideLayoutFix(f.id, true);
      } catch (e) {
        return toastMsg('$e'.contains('isn’t waiting') || '$e'.contains('isn\'t waiting') ? 'This fix was withdrawn or decided already.' : 'Couldn’t publish it. Check your internet and try again.');
      }
      await refreshListings();
      await refreshLive();
    }
    update(() {
      if (!onServer) {
        lastPublish = (room: l.room, snap: l.published ?? l.snap(), version: l.version);
        l
          ..restore(f.snap)
          ..version += 1
          ..live = true
          ..pending = false
          ..published = null
          ..drawn = dayMon(appToday);
        f
          ..status = 'approved'
          ..decidedAt = DateTime.now().millisecondsSinceEpoch;
        final c = layoutChecks[f.hid]?[f.room];
        (layoutChecks[f.hid] ??= {})[f.room] = ((c?.$1 ?? 0) + 1, dayMon(appToday));
      }
      lRoom = f.room;
      hist = hist.where((x) => x != 'oFix').toList();
      screen = 'oFixDone';
      sheet = null;
    });
  }

  /// "Reject" (board 10): the live layout stays; the resident sees the reason.
  Future<void> rejectFix(LayoutFix f) async {
    final why = fixReason.trim();
    if (onServer) {
      if (!await _write(() => data.decideLayoutFix(f.id, false, reason: why))) return;
    } else {
      update(() {
        f
          ..status = 'rejected'
          ..reason = why.isEmpty ? null : why
          ..decidedAt = DateTime.now().millisecondsSinceEpoch;
      });
    }
    update(() {
      fixReason = '';
      sheet = null;
      hist = hist.where((x) => x != 'oFix').toList();
      screen = hist.isNotEmpty ? hist.removeLast() : 'oToday';
    });
    toastMsg('Rejected. The current layout stays live. ${f.author.split(' ').first} can send a new fix.');
  }

  /// "Undo publish · go back to vN" after approving a fix.
  Future<void> undoFixPublish() async {
    final l = layoutOf(ownHid, lRoom);
    if (l == null) return;
    if (onServer) {
      if (!await _write(() => data.undoLayoutPublish(ownHid, lRoom))) return;
      await refreshListings();
      update(() => screen = 'oToday');
      return toastMsg('Back to the earlier version. Tenants see it again.');
    }
    final f = fixes.where((x) => x.hid == ownHid && x.room == lRoom && x.status == 'approved').lastOrNull;
    if (f != null) {
      f
        ..status = 'rejected'
        ..reason = 'Undone by the owner';
      final c = layoutChecks[ownHid]?[lRoom];
      if (c != null && c.$1 <= 1) {
        layoutChecks[ownHid]!.remove(lRoom);
      } else if (c != null) {
        layoutChecks[ownHid]![lRoom] = (c.$1 - 1, c.$2);
      }
    }
    undoPublish(l);
    update(() => screen = 'oToday');
  }

  /// "Checked by 3 residents · 2 Oct" for tenants, or null.
  String? checkedLabel(String hid, int room) {
    final c = layoutChecks[hid]?[room];
    if (c == null || c.$1 == 0) return null;
    return 'Checked by ${c.$1 == 1 ? 'a resident' : '${c.$1} residents'} · ${c.$2}';
  }
}
