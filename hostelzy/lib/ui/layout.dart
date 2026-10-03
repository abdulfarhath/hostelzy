import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'amenities.dart';
import 'common.dart';
import 'kit.dart';

// F12 room layouts: the tenant Room tab (board 1), compare two beds (2), the
// special states (3), the owner's approve screen (4) and request sheet (5),
// and the Hostelzy admin editor (6, one column on the phone).

/// Draws a room on a 1-ft grid: walls, washroom (hatched), window (bar),
/// door (gap), AC airflow (stripes) and fan reach (dashed circles). Layers
/// are told apart by pattern, not colour alone.
class _RoomPainter extends CustomPainter {
  _RoomPainter(this.l, this.p, {required this.fan, required this.ac});
  final RoomLayout l;
  final Pal p;
  final bool fan, ac;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / l.w;
    Rect sc(Rect r) => Rect.fromLTRB(r.left * k, r.top * k, r.right * k, r.bottom * k);
    // F24: a shaped room: outside its walls is plain surface, inside the grid.
    final o = l.outline;
    final walls = o == null ? null : (Path()..addPolygon([for (final q in o) Offset((q.dx * k).clamp(1, size.width - 1), (q.dy * k).clamp(1, size.height - 1))], true));
    canvas.drawRect(Offset.zero & size, Paint()..color = walls == null ? p.bg : p.sf);
    if (walls != null) {
      canvas.save();
      canvas.clipPath(walls);
      canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);
    }
    final grid = Paint()
      ..color = p.hl
      ..strokeWidth = 1;
    for (var x = 1; x < l.w; x++) {
      canvas.drawLine(Offset(x * k, 0), Offset(x * k, size.height), grid);
    }
    for (var y = 1; y < l.h; y++) {
      canvas.drawLine(Offset(0, y * k), Offset(size.width, y * k), grid);
    }
    final ink = Paint()
      ..color = p.tx
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final wz in l.of('wash')) {
      final w = sc(wz.rect);
      canvas.save();
      canvas.clipRect(w);
      canvas.drawRect(w, Paint()..color = p.bg);
      final hatch = Paint()
        ..color = p.tk
        ..strokeWidth = 2;
      for (var d = -w.height; d < w.width + w.height; d += 7) {
        canvas.drawLine(Offset(w.left + d, w.bottom), Offset(w.left + d + w.height, w.top), hatch);
      }
      canvas.restore();
      canvas.drawRect(w, ink);
    }
    for (final pl in l.of('pillar')) {
      final r = sc(pl.rect);
      canvas.drawRect(r, Paint()..color = p.tk);
      canvas.drawRect(r, ink);
    }
    final air = l.airflow;
    if (ac && air != null && l.ac != null) {
      // Stripes fan out from the AC's wall into the room.
      final a = sc(air);
      final side = wallOf(l.ac!.rect, l.w, l.h) ?? 'right';
      final path = Path();
      switch (side) {
        case 'left' || 'right':
          final near = side == 'right' ? a.right : a.left, far = side == 'right' ? a.left : a.right;
          path
            ..moveTo(near, a.top + a.height * .3)
            ..lineTo(near, a.top + a.height * .7)
            ..lineTo(far, a.bottom)
            ..lineTo(far, a.top);
        default:
          final near = side == 'bottom' ? a.bottom : a.top, far = side == 'bottom' ? a.top : a.bottom;
          path
            ..moveTo(a.left + a.width * .3, near)
            ..lineTo(a.left + a.width * .7, near)
            ..lineTo(a.right, far)
            ..lineTo(a.left, far);
      }
      path.close();
      canvas.save();
      canvas.clipPath(path);
      final st = Paint()
        ..color = p.dv
        ..strokeWidth = 1;
      if (side == 'left' || side == 'right') {
        for (var x = a.left; x < a.right; x += 6) {
          canvas.drawLine(Offset(x, a.top), Offset(x, a.bottom), st);
        }
      } else {
        for (var y = a.top; y < a.bottom; y += 6) {
          canvas.drawLine(Offset(a.left, y), Offset(a.right, y), st);
        }
      }
      canvas.restore();
    }
    if (fan) {
      final dash = Paint()
        ..color = p.dv
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final f in l.of('fan')) {
        final c = sc(f.rect).center;
        final r = fanReach * k;
        const n = 36;
        for (var i = 0; i < n; i += 2) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * 2 * math.pi / n, 2 * math.pi / n, false, dash);
        }
      }
    }
    if (walls != null) {
      canvas.restore();
      canvas.drawPath(walls, ink);
    } else {
      canvas.drawRect((Offset.zero & size).deflate(1), ink);
    }
    // Windows are a bar on their wall, doors a gap in it. F24: on an inner
    // wall of a shaped room, where they are drawn.
    Rect onWall(LItem i, double t) {
      final r = sc(i.rect);
      if (walls != null && wallOf(i.rect, l.w, l.h) == null) return r;
      return switch (wallOf(i.rect, l.w, l.h)) {
        'bottom' => Rect.fromLTWH(r.left, size.height - t, r.width, t),
        'left' => Rect.fromLTWH(0, r.top, t, r.height),
        'right' => Rect.fromLTWH(size.width - t, r.top, t, r.height),
        _ => Rect.fromLTWH(r.left, 0, r.width, t),
      };
    }

    for (final w in l.of('window')) {
      canvas.drawRect(onWall(w, 6), Paint()..color = w.working ? p.tx : p.ad);
    }
    for (final d in l.of('door')) {
      canvas.drawRect(onWall(d, 4), Paint()..color = p.bg);
    }
    for (final a in l.of('ac')) {
      canvas.drawRect(sc(a.rect), Paint()..color = a.working ? p.tx : p.ad);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter o) => true;
}

/// How a bed looks on the map. [mode]: tenant | compare | plain | edit. In
/// edit mode items and beds can be selected and dragged ([onDrag] gets feet).
class LayoutMap extends StatelessWidget {
  const LayoutMap({super.key, required this.l, required this.room, this.mode = 'tenant', this.focus, this.cmp = const [], this.fan = false, this.ac = false, this.onPick, this.selected, this.onSelect, this.onDrag, this.onDragEnd, this.marked = const {}});
  final RoomLayout l;
  final Room room;
  final String mode;
  final String? focus;
  final List<String> cmp;
  final bool fan, ac;
  final ValueChanged<String>? onPick;
  final String? selected;
  final ValueChanged<String>? onSelect;
  final void Function(String id, Offset deltaFt)? onDrag;
  final VoidCallback? onDragEnd;

  /// F19: things outlined in red (what a resident's fix changed).
  final Set<String> marked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final edit = mode == 'edit';
    Widget label(String t, {Color? c, String? icon}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      color: p.bg,
      child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Ic(icon, size: 14, color: c ?? p.tx), const SizedBox(width: 3)], T(t, s: 10, w: 800, ls: .08, upper: true, c: c ?? p.tx, nowrap: true)]),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final k = c.maxWidth / l.w;
        final hgt = l.h * k;
        Rect sc(Rect r) => Rect.fromLTRB(r.left * k, r.top * k, r.right * k, r.bottom * k);
        final kids = <Widget>[Positioned.fill(child: CustomPaint(painter: _RoomPainter(l, p, fan: fan, ac: ac)))];
        final labels = <Widget>[];
        // F23: a geyser in this room's washroom shows on the plan.
        final geyser = s.inRoom(l.hid, room.n).any((a) => a.kind == 'geyser' && a.place == 'washroom');
        for (final wz in l.of('wash')) {
          final w = sc(wz.rect);
          labels.add(Positioned(left: w.left + 6, top: w.bottom - 22, child: geyser ? label('Washroom · Geyser', icon: 'geyser') : label('Washroom')));
        }
        for (final wi in l.of('window')) {
          final w = sc(wi.rect);
          final txt = label('Window · ${wi.facing}', c: wi.working ? null : p.ad);
          labels.add(switch (wallOf(wi.rect, l.w, l.h)) {
            'bottom' => Positioned(left: w.left, bottom: 9, child: txt),
            'left' => Positioned(left: 9, top: w.top, child: txt),
            'right' => Positioned(right: 9, top: w.top, child: txt),
            _ => Positioned(left: w.left, top: 9, child: txt),
          });
        }
        for (final dr in l.of('door')) {
          final d = sc(dr.rect);
          final wall = wallOf(dr.rect, l.w, l.h);
          labels.add(Positioned(
            left: wall == 'right' ? null : (wall == 'left' ? 8 : d.left + 12),
            right: wall == 'right' ? 8 : null,
            top: wall == 'bottom' ? d.top - 20 : (wall == 'top' ? 8 : d.top + 4),
            child: T('Door', s: 10, w: 800, ls: .08, upper: true, c: p.mu),
          ));
        }
        for (final a in l.of('ac')) {
          final u = sc(a.rect);
          final ok = a.working && !room.acRepair;
          final txt = label(ok ? 'AC unit' : 'AC · under repair', c: ok ? null : p.ad);
          labels.add(switch (wallOf(a.rect, l.w, l.h)) {
            'left' => Positioned(left: u.right + 4, top: u.bottom + 4, child: txt),
            'top' => Positioned(left: u.left, top: u.bottom + 4, child: txt),
            'bottom' => Positioned(left: u.left, top: u.top - 22, child: txt),
            _ => Positioned(right: c.maxWidth - u.left + 4, top: u.bottom + 4, child: txt),
          });
        }
        for (final pl in l.of('pillar')) {
          final r = sc(pl.rect);
          labels.add(Positioned(left: r.right + 3, top: r.top, child: label('Pillar')));
        }
        for (final f in l.of('fan')) {
          final ct = sc(f.rect).center;
          labels.add(Positioned(left: ct.dx - 11, top: ct.dy - 10, child: label(f.working ? 'Fan' : 'Fan · not working', icon: 'fan', c: f.working ? null : p.ad)));
        }
        (BedLook, String) lookFor(Bed b) => switch (mode) {
          'plain' || 'edit' => (BedLook(p.sf, p.tx, p.tx, '3 × 6 ft'), '3 × 6 ft'),
          'compare' when cmp.isNotEmpty && b.letter == cmp[0] => (bedState(p, 'sel'), 'Selected'),
          'compare' when cmp.length > 1 && b.letter == cmp[1] => (BedLook(p.ab, p.ac, p.ad, 'Compare'), 'Compare'),
          _ => () {
            final lk = lookOf(p, b, b.letter == focus && (b.state == 'free' || b.state == 'soon') ? b.id : s.bed);
            return (lk.look, lk.tag);
          }(),
        };
        Widget bedBox(Bed b, {String? note}) {
          final (look, tag) = lookFor(b);
          return Tap(
            onTap: () => onPick?.call(b.letter),
            child: BedBox(
              look: look,
              padding: const EdgeInsets.all(5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: T(b.letter, w: 800, s: note == null ? 22 : 16, lh: 1))), if (note != null) ...[const SizedBox(width: 4), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: T(note, s: 8, w: 800, upper: true, nowrap: true)))]]),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: T(tag, s: 9, w: 800, ls: .06, upper: true, nowrap: true)),
                ],
              ),
            ),
          );
        }

        for (final b in room.beds) {
          if (!l.beds.containsKey(b.letter) || l.bunks.containsKey(b.letter)) continue;
          final r = sc(l.bedRect(b.letter));
          final up = l.upperOn(b.letter);
          final upper = up == null ? null : room.beds.where((x) => x.letter == up).firstOrNull;
          // A bunk bed: the upper bunk on top, the lower below, each tappable.
          kids.add(
            Positioned.fromRect(
              rect: r,
              child: upper == null
                  ? bedBox(b)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: bedBox(upper, note: 'Upper')), Container(height: 2, color: p.tx), Expanded(child: bedBox(b, note: 'Lower'))]),
            ),
          );
        }
        // Edit mode: a touch target per bed and item (at least 32 px), and
        // the selected one outlined in red. F19 quick fix: in view mode with
        // [onSelect], items (not beds) can be tapped too.
        final handles = <Widget>[];
        if (edit || onSelect != null) {
          Widget handle(String id, Rect ftRect) {
            final r = sc(ftRect);
            final hit = Rect.fromCenter(center: r.center, width: math.max(r.width, 32), height: math.max(r.height, 32));
            return Positioned.fromRect(
              rect: hit,
              child: GestureDetector(
                key: ValueKey('ed-$id'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect?.call(id),
                onPanUpdate: edit ? (d) => onDrag?.call(id, d.delta / k) : null,
                onPanEnd: edit ? (_) => onDragEnd?.call() : null,
                child: Container(decoration: id == selected ? BoxDecoration(border: Border.all(color: p.ac, width: 2)) : null),
              ),
            );
          }

          for (final i in l.items) {
            handles.add(handle(i.id, i.rect));
          }
          for (final b in l.beds.keys.where((b) => edit && !l.bunks.containsKey(b))) {
            handles.add(handle('bed:$b', l.bedRect(b)));
          }
        }
        for (final id in marked) {
          final ft = id.startsWith('bed:') ? (l.beds.containsKey(id.substring(4)) ? l.bedRect(id.substring(4)) : null) : l.items.where((i) => i.id == id).firstOrNull?.rect;
          if (ft == null) continue;
          final r = sc(ft).inflate(3);
          handles.add(Positioned.fromRect(rect: r, child: IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: p.ac, width: 2))))));
        }
        return Semantics(
          label: 'Room ${l.room} layout, ${l.w.round()} by ${l.h.round()} feet${l.outline == null ? '' : ', ${l.shape}'}',
          child: SizedBox(width: c.maxWidth, height: hgt, child: Stack(children: [...kids, ...labels, ...handles])),
        );
      },
    );
  }
}

/// Dashed box with an icon, for "Layout coming soon" and the locked states.
class LayoutEmpty extends StatelessWidget {
  const LayoutEmpty({super.key, required this.icon, required this.head, required this.body});
  final String icon, head, body;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Dashed(
      color: p.dv,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(width: 52, height: 52, color: p.sf, alignment: Alignment.center, child: Ic(icon, size: 24, color: p.tx)),
          const SizedBox(height: 8),
          T(head, w: 800, s: 20, align: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: T(body, s: 14, c: p.mu, lh: 1.45, align: TextAlign.center)),
        ],
      ),
    );
  }
}

/// The bed whose facts show in the Room tab: the picked bed, else the
/// tapped one, else the first free bed.
String? roomFocus(AppState s, Room r) {
  final picked = s.bed != null && s.bed!.startsWith('${r.n}-') ? s.bed!.split('-').last : null;
  return picked ?? s.roomBed ?? r.beds.where((b) => b.state == 'free' && !b.mine).firstOrNull?.letter ?? r.beds.firstOrNull?.letter;
}

/// Board 1 + 3: the bed picker's Room tab.
class RoomMode extends StatelessWidget {
  const RoomMode({super.key, required this.rooms, required this.room});
  final List<Room> rooms;
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final l = s.liveLayout(h.id, room.n);
    final focus = roomFocus(s, room);
    final fb = room.beds.where((b) => b.letter == focus).firstOrNull;
    Widget body;
    if (!s.signedIn) {
      body = VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'lock', head: 'Sign in to see room layouts', body: 'Room layouts are only for people signed in to Hostelzy.'),
          T('It takes one tap with Google. We never share your number with the hostel until you choose to.', s: 12, c: p.mu, lh: 1.4),
        ],
      );
    } else if (l == null && (s.needsRoomFetch(h.id, room.n) || s.roomFetch['${h.id}|${room.n}'] == 'loading')) {
      // F24 Wave 4b: a women's PG's room comes from the server one by one.
      if (s.needsRoomFetch(h.id, room.n)) WidgetsBinding.instance.addPostFrameCallback((_) => s.fetchRoomLayout(h.id, room.n));
      body = Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Center(child: T('Loading the layout…', key: const ValueKey('roomLoading'), s: 14, c: p.mu)));
    } else if (l == null && s.roomFetch['${h.id}|${room.n}'] == 'capped') {
      // The server shows a women's PG a few rooms a day before a hold.
      body = VGap(
        key: const ValueKey('roomCapped'),
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'lock', head: 'Floor plan shows after you hold a bed', body: 'For residents’ safety, a women’s PG shows a few rooms a day before a hold. Hold a bed to see every room.'),
          OutlineCta('Pick a bed from Plan', height: 50, onTap: () => s.update(() => s.mode = 'plan')),
          T('Hostelzy never shows gates, CCTV, exits or residents’ names on any plan.', s: 12, c: p.mu, lh: 1.4),
        ],
      );
    } else if (l == null && s.roomFetch['${h.id}|${room.n}'] == 'failed') {
      body = VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'warn', head: 'Couldn’t load this room', body: 'Check your internet and try again. You can still pick a bed from Plan or List.'),
          OutlineCta('Try again', key: const ValueKey('roomRetry'), height: 50, onTap: () => s.fetchRoomLayout(h.id, room.n)),
        ],
      );
    } else if (l == null) {
      if (s.onServer && !s.layoutWaitsLoaded) WidgetsBinding.instance.addPostFrameCallback((_) => s.loadLayoutWaits());
      final waiting = s.waitingForLayout(h.id, room.n);
      body = VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'pencil', head: 'Layout coming soon', body: 'The owner hasn’t published this room’s layout yet. You can still pick a bed from Plan or List, and see the photos.'),
          // F24 item 27: saved on the server; a notification when it's published.
          waiting
              ? Container(
                  key: const ValueKey('layoutWaiting'),
                  height: 50,
                  alignment: Alignment.center,
                  color: p.sf,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('bell', size: 16, color: p.tx), const SizedBox(width: 8), const T('We’ll tell you', w: 800, s: 15)]),
                )
              : OutlineCta('Tell me when it’s ready', key: const ValueKey('layoutNotify'), icon: 'bell', height: 50, onTap: () => s.tellMeWhenReady(h.id, room.n)),
          T(waiting ? 'You get a notification when the owner publishes room ${room.label}’s layout.' : 'Owners draw their rooms and residents correct them, so what you see matches the room.', s: 12, c: p.mu, lh: 1.4),
        ],
      );
    } else {
      final ck = s.checkedLabel(h.id, room.n);
      body = VGap(
        gap: 10,
        children: [
          // F23: the shared things on this floor, above the plan.
          FloorStrip(hid: h.id, floor: room.floor),
          // F24 item 10 (DECISIONS F12): fans and the AC show as icons; their
          // reach and airflow only when that layer is on (off by default).
          LayoutMap(
            l: l,
            room: room,
            focus: focus,
            fan: s.showFan,
            ac: s.showAc,
            onPick: (k) {
              final b = room.beds.firstWhere((x) => x.letter == k);
              s.update(() {
                s.roomBed = k;
                s.bed = (b.state == 'free' || b.state == 'soon') && !b.mine ? b.id : null;
              });
            },
          ),
          Row(
            children: [
              Expanded(child: T('${l.w.round()} × ${l.h.round()} ft${l.outline == null ? '' : ' · ${l.shape}'}', s: 12, c: p.mu)),
              // F19: residents' approved fixes; their names are never shown.
              if (ck != null)
                Row(mainAxisSize: MainAxisSize.min, children: [Ic('shieldOk', size: 14, color: p.tx), const SizedBox(width: 4), T(ck, s: 12, w: 800)])
              else
                T(AppState.samples ? 'Sample layout' : 'Layout v${l.version}', s: 12, c: p.mu),
            ],
          ),
          LayerChips(l: l),
          if (fb != null)
            Container(
              key: const ValueKey('bedFacts'),
              padding: const EdgeInsets.all(12),
              decoration: box(w: 2, c: p.tx),
              child: VGap(
                gap: 6,
                children: [
                  T('Bed ${fb.letter} · ${const {'free': 'free', 'held': 'on hold', 'soon': 'free soon'}[fb.state] ?? 'taken'}', w: 800, s: 17),
                  T(bedFacts(l, room, fb.letter).join(' · '), s: 14, c: p.mu, lh: 1.4),
                  // F23: what the room itself has (a geyser in its washroom…).
                  for (final x in roomThingLines(s, h.id, room.n)) Row(children: [Ic(x.startsWith('Geyser') ? 'geyser' : 'check', size: 18, color: p.tx), const SizedBox(width: 6), Expanded(child: T(x, s: 14, w: 800))]),
                ],
              ),
            ),
          if (room.beds.where((b) => (b.state == 'free' || b.state == 'soon') && !b.mine).length >= 2)
            Align(
              alignment: Alignment.centerLeft,
              child: Tap(key: const ValueKey('compareLink'), onTap: s.openCompare, child: const T('Compare with another bed ›', s: 14, w: 800, underline: true)),
            ),
          // F19: anyone can suggest a fix; only residents of this hostel can send one.
          Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              onTap: () => s.openFixEditor(s.hid, room.n),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('pencil', size: 14, color: p.mu), const SizedBox(width: 6), T('Edit room', s: 13, w: 600, c: p.mu)]),
            ),
          ),
        ],
      );
    }
    // F23: layout first. The rooms on this floor as chips, the floor view one tap away.
    final onFloor = rooms.where((r) => r.floor == room.floor && AppState.fits(r, s.pR)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in onFloor)
                      Tap(
                        key: ValueKey('roomChip-${r.n}'),
                        onTap: () => s.update(() {
                          s.room = r.n;
                          s.bed = null;
                          s.roomBed = null;
                        }),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: box(bg: r.n == room.n ? p.tx : transparent, w: r.n == room.n ? 2 : 1, c: r.n == room.n ? p.tx : p.dv),
                          child: T(r.label, w: 800, s: 14, c: r.n == room.n ? p.bg : p.tx),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                key: const ValueKey('floorView'),
                onTap: () => s.update(() => s.mode = 'plan'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('bed', size: 16, color: p.tx), const SizedBox(width: 6), const T('Floor view', w: 800, s: 13)]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (room.ac && room.acRepair)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: p.ab,
              child: T('AC under repair.${room.acSince.isEmpty ? '' : ' Complaint raised ${room.acSince}.'} The owner is fixing it.', s: 12, w: 600, c: p.ad, lh: 1.4),
            ),
          body,
        ],
      ),
    );
  }
}

/// F24 item 10 (board roomLayersOn): "Show: Fan reach · AC airflow". Both
/// start off; then fans and the AC are icons with labels only.
class LayerChips extends StatelessWidget {
  const LayerChips({super.key, required this.l});
  final RoomLayout l;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final fans = l.of('fan').isNotEmpty, ac = l.ac != null;
    if (!fans && !ac) return const SizedBox();
    Widget chip(String t, bool on, VoidCallback tap, Key key) => Tap(
      key: key,
      onTap: tap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: box(bg: on ? p.tx : transparent, w: 2, c: on ? p.tx : p.dv),
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (on) ...[Ic('check', size: 14, color: p.bg), const SizedBox(width: 6)], T(t, s: 13, w: 800, c: on ? p.bg : p.tx)]),
      ),
    );
    return Row(
      children: [
        const Kicker('Show'),
        const SizedBox(width: 8),
        if (fans) chip('Fan reach', s.showFan, () => s.update(() => s.showFan = !s.showFan), const ValueKey('layerFan')),
        if (fans && ac) const SizedBox(width: 6),
        if (ac) chip('AC airflow', s.showAc, () => s.update(() => s.showAc = !s.showAc), const ValueKey('layerAc')),
      ],
    );
  }
}

/// The Room tab's bottom bar: Compare beds + Hold bed (or Sign in).
class RoomBar extends StatelessWidget {
  const RoomBar({super.key, required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    if (!s.signedIn) {
      return Cta('Sign in', height: 54, px: 16, fs: 15, onTap: s.startSignIn);
    }
    final focus = roomFocus(s, room);
    final b = room.beds.where((x) => x.letter == focus).firstOrNull;
    final can = b != null && (b.state == 'free' || b.state == 'soon') && !b.mine;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T(can ? 'Bed ${b.id} · ${fmt(room.rent)}/mo' : (b == null ? 'No bed picked' : 'Bed ${b.id} is taken'), w: 800, s: 17, lh: 1.25),
              T(can ? 'Same price for every bed here' : 'Tap a free bed', s: 12, c: p.mu, ell: true),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Cta(
          'Continue',
          key: const ValueKey('roomContinue'),
          height: 50,
          fs: 15,
          expand: false,
          opacity: can ? 1 : .4,
          onTap: () => can
              ? s.update(() {
                  s.bed = b.id;
                  s.sheet = 'hold';
                })
              : s.toastMsg('Pick a free bed first.'),
        ),
      ],
    );
  }
}

/// Women's PGs before a hold: the floor plan is locked (board 3).
class FloorLocked extends StatelessWidget {
  const FloorLocked({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'lock', head: 'Floor plan shows after you hold a bed', body: 'For residents’ safety, the full floor plan of a women’s PG opens only after a hold. Each room’s own layout is in the Room tab.'),
          OutlineCta('See rooms in the Room tab', height: 50, onTap: () => s.update(() => s.mode = 'room')),
          T('Hostelzy never shows gates, CCTV, exits or residents’ names on any plan.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

/// Board 2: compare two free beds of the same room.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final room = s.rooms[s.hid]!.firstWhere((r) => r.n == s.room);
    final l = s.liveLayout(s.hid, room.n);
    if (l == null) return const SizedBox();
    final a = bedTraits(l, room, s.cmpA), b = bedTraits(l, room, s.cmpB);
    final rows = <(String, String, String)>[
      if (a.bunk != 'Single bed' || b.bunk != 'Single bed') ('Bed', a.bunk, b.bunk),
      ('Fan', a.fan, b.fan),
      if (a.ac != null) ('AC', a.ac!, b.ac!),
      ('Window', a.win, b.win),
      ('Door', a.door, b.door),
      ('Washroom', a.wash, b.wash),
      ('Walls', a.wall, b.wall),
    ];
    Widget cell(String t, {int w = 400, Color? bg, Color? c, bool left = false, double size = 13}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(color: bg, border: left ? Border(left: bs(1, p.hl)) : null),
        child: T(t, s: size, w: w, c: c),
      ),
    );
    void pickHold(String k) => s.update(() {
      s.bed = '${room.n}-$k';
      s.sheet = 'hold';
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker('Room ${room.label} · ${room.share} sharing · ${room.type}'), const T('Compare beds', w: 800, s: 22, lh: 1.1)]))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('compare${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: VGap(
                    gap: 10,
                    children: [
                      LayoutMap(
                        l: l,
                        room: room,
                        mode: 'compare',
                        cmp: [s.cmpA, s.cmpB],
                        onPick: (k) {
                          final bd = room.beds.firstWhere((x) => x.letter == k);
                          if (!((bd.state == 'free' || bd.state == 'soon') && !bd.mine) || k == s.cmpA) return;
                          s.update(() => s.cmpB = k);
                        },
                      ),
                      T('Comparing two open beds. Both cost ${fmt(room.rent)} a month.', s: 12, c: p.mu),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx))),
                  child: Row(children: [const SizedBox(width: 96), cell('Bed ${s.cmpA}', w: 800, size: 17, bg: p.ac, c: p.ai), cell('Bed ${s.cmpB}', w: 800, size: 17, bg: p.ab, c: p.ad, left: true)]),
                ),
                for (final r in [...rows, ('Price', '${fmt(room.rent)}/mo', '${fmt(room.rent)}/mo')])
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 96, child: Padding(padding: const EdgeInsets.fromLTRB(16, 9, 10, 9), child: T(r.$1, s: 13, c: p.mu))),
                          cell(r.$2, w: r.$1 == 'Price' ? 800 : (r.$2 == r.$3 ? 400 : 600)),
                          cell(r.$3, w: r.$1 == 'Price' ? 800 : (r.$2 == r.$3 ? 400 : 600), left: true),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Row(
            children: [
              Expanded(child: Cta('Hold ${s.cmpA}', height: 54, px: 14, fs: 15, onTap: () => pickHold(s.cmpA))),
              const SizedBox(width: 8),
              Expanded(child: Cta('Hold ${s.cmpB}', height: 54, px: 14, fs: 15, bg: transparent, fg: p.tx, border: p.tx, onTap: () => pickHold(s.cmpB))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Working / Not working switch.
class _WorkSwitch extends StatelessWidget {
  const _WorkSwitch({required this.ok, required this.onPick});
  final bool ok;
  final ValueChanged<bool> onPick;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    Widget half(String t, bool on, Color bg, Color fg, bool v) => Expanded(
      child: Tap(
        onTap: () => onPick(v),
        child: Container(height: 36, alignment: Alignment.center, color: on ? bg : null, child: T(t, s: 12, w: 600, c: on ? fg : p.tx)),
      ),
    );
    return Container(
      width: 176,
      decoration: box(w: 2, c: p.tx),
      child: Row(children: [half('Working', ok, p.tx, p.bg, true), half('Not working', !ok, p.ad, p.ai, false)]),
    );
  }
}

String _itemName(RoomLayout l, LItem i) {
  final b = l.beds.keys.where((k) => (l.bedRect(k).center - l.itemRect(i).center).distance <= fanReach).firstOrNull;
  return switch (i.kind) {
    'fan' => 'Fan ${i.id.substring(3)}${b != null ? ' · over bed $b' : ''}',
    'ac' => 'AC unit · ${l.itemRect(i).center.dx > l.w / 2 ? 'right' : 'left'} wall',
    _ => 'Window · faces ${i.facing}',
  };
}

/// Board 4: the owner checks a layout, marks items, approves it.
class OwnerLayoutScreen extends StatelessWidget {
  const OwnerLayoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final l = s.layoutOf(h.id, room.n);
    // F24 item 11: an "Ask Hostelzy to draw it" request, and the team's
    // drawing once it comes back (board oShapeBack).
    final q = s.shapeReqFor(h.id, room.n);
    final drawn = q == null ? null : s.drawnLayout(q);
    final (stText, stBg, stFg) = drawn != null
        ? ('Hostelzy drew a new version · check and publish', p.tx, p.bg)
        : q != null
        ? ('Asked Hostelzy · ${hoursLeft(q.due, DateTime.now().millisecondsSinceEpoch)} · done within 48 h', p.ab, p.ad)
        : l == null
        ? ('No layout yet', p.ab, p.ad)
        : l.pending
        ? ('Hostelzy drew a new version · check and publish', p.ab, p.ad)
        : !l.live
        ? ('Draft · tenants see “Layout coming soon”', p.sf, p.tx)
        : l.published != null
        ? ('Live · you have changes not published', p.sf, p.tx)
        : ('Live for tenants', p.tx, p.bg);
    String at(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dayMon(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    final shown = drawn ?? l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Beds', title: 'Room ${room.label} layout', size: 26))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oLayout${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 10,
                children: [
                  Container(
                    key: const ValueKey('layoutStatus'),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    color: stBg,
                    child: Row(children: [Expanded(child: T(stText, s: 13, w: 800, c: stFg)), if (l != null && drawn == null) T('v${l.version} · drawn ${l.drawn}', s: 13, w: 600, c: stFg)]),
                  ),
                  // F13 S4, F24 4a: residents answered "Is the room layout right? No".
                  if (l != null && l.disputes > 0)
                    Container(
                      key: const ValueKey('layoutDisputed'),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: box(bg: p.ab, w: 2, c: p.ad),
                      child: VGap(gap: 2, children: [
                        T('Residents say this layout is wrong', w: 800, s: 14, c: p.ad),
                        T('${l.disputes} ${l.disputes == 1 ? 'resident' : 'residents'} answered “No” in the 30-day review. Check the room, fix the layout and publish it again.', s: 13, lh: 1.4),
                      ]),
                    ),
                  if (shown == null)
                    q != null
                        ? LayoutEmpty(icon: 'pencil', head: 'Hostelzy is drawing it', body: 'You asked on ${at(q.at)}${q.w > 0 && q.h > 0 ? ' · ${q.shape} · ${q.w.round()} × ${q.h.round()} ft' : ''}. Done within 48 hours; you get a notification.')
                        : const LayoutEmpty(icon: 'pencil', head: 'No layout yet', body: 'Draw it yourself in a few minutes and publish it, or ask the Hostelzy team to draw it for you, free.')
                  else if (drawn != null) ...[
                    LayoutMap(l: drawn, room: room, mode: 'plain', fan: true, ac: true),
                    Row(
                      children: [
                        Expanded(child: T('${drawn.w.round()} × ${drawn.h.round()} ft · ${drawn.shape} · ${room.share} sharing', s: 12, c: p.mu)),
                        T('v${drawn.version} · drawn by Hostelzy, ${drawn.drawn}', s: 12, c: p.mu),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      color: p.sf,
                      child: T('You asked on ${at(q!.at)}.${q.sentAt != null ? ' Drawn in ${((q.sentAt! - q.at) / 3600000).ceil()} hours.' : ''} Check the beds, fan and window, then publish. Tenants see it straight away.', s: 13, lh: 1.45),
                    ),
                  ] else ...[
                    LayoutMap(l: l!, room: room, mode: 'plain', fan: true, ac: true),
                    if (q != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        color: p.sf,
                        child: T('You asked Hostelzy on ${at(q.at)}${q.note.isEmpty ? '' : ': “${q.note}”'}. Tenants keep seeing this layout until you publish the new one.', s: 13, lh: 1.45),
                      ),
                    Container(
                      decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final i in l.items.where((i) => const ['fan', 'ac', 'window'].contains(i.kind)))
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        T(_itemName(l, i), w: 800, s: 14),
                                        T(i.working ? 'Shown to tenants' : (i.kind == 'ac' ? 'Tenants see “AC under repair”. A complaint is raised.' : 'Tenants see “Not working”. A complaint is raised.'), s: 11, c: i.working ? p.mu : p.ad, lh: 1.3),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _WorkSwitch(ok: i.working, onPick: (v) => s.setWorking(l, i, v)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
        // F18 (DECISIONS 2026-10-02): the owner edits and publishes; Hostelzy helps if asked.
        if (drawn != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: VGap(
              gap: 8,
              children: [
                Cta('Publish v${drawn.version}', icon: 'check', key: const ValueKey('publishDrawn'), height: 54, px: 16, fs: 15, onTap: () => s.publishDrawn(q!)),
                OutlineCta('Ask Hostelzy to change it', icon: 'msg', onTap: () => s.openShapeRequest(shape: q!.shape)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: l == null
                      ? Cta('Create a layout', icon: 'pencil', height: 52, px: 16, fs: 15, onTap: () => s.ownerLayout(room.n, create: true))
                      : l.pending
                      ? Cta('Publish v${l.version}', icon: 'check', height: 52, px: 16, fs: 15, onTap: () => s.approveLayout(l))
                      : Cta('Edit layout', icon: 'pencil', height: 52, px: 16, fs: 15, onTap: () => s.openLayout(room.n, editor: true, owner: true)),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: s.openLayoutRequest,
                  child: Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('Ask Hostelzy', w: 800, s: 15)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// F24 board oShapeReq: "Ask Hostelzy to draw it" (sheet). Saved in the
/// app; the team draws it within 48 hours and sends it back to publish.
class LayoutRequestSheet extends StatelessWidget {
  const LayoutRequestSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          VGap(gap: 6, children: [const T('What’s different?', w: 800, s: 13), Field(key: const ValueKey('lReqText'), value: s.lReqText, maxLines: 3, height: null, placeholder: 'Bed C is against the washroom wall, not near the door.', onChanged: (v) => s.update(() => s.lReqText = v))]),
          VGap(gap: 6, children: [
            const T('Shape', w: 800, s: 13),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final sh in layoutShapes) ChipBtn(sh, on: s.lReqShape == sh, onTap: () => s.update(() => s.lReqShape = sh))]),
          ]),
          // Photos or a paper sketch: up to 3, private to the owner and the team.
          Row(
            children: [
              for (var i = 0; i < s.lReqPhotos.length; i++) ...[
                Tap(
                  onTap: () => s.update(() => s.lReqPhotos = [...s.lReqPhotos]..removeAt(i)),
                  child: Container(width: 64, height: 48, decoration: box(bg: p.sf, w: 2, c: p.tx), child: Image.memory(s.lReqPhotos[i], fit: BoxFit.cover)),
                ),
                const SizedBox(width: 8),
              ],
              if (s.lReqPhotos.length < 3)
                Expanded(child: OutlineCta(s.lReqPhotos.isEmpty ? 'Add photos or a sketch' : 'Add another', key: const ValueKey('shapePhoto'), icon: 'camera', height: 48, fs: 14, onTap: s.pickShapePhoto)),
            ],
          ),
          Row(
            children: [
              Expanded(child: VGap(gap: 6, children: [const T('Width (ft)', w: 800, s: 13), Field(value: s.lReqLen, numeric: true, placeholder: '14', onChanged: (v) => s.update(() => s.lReqLen = v.replaceAll(RegExp(r'\D'), '')))])),
              const SizedBox(width: 8),
              Expanded(child: VGap(gap: 6, children: [const T('Length (ft)', w: 800, s: 13), Field(value: s.lReqWid, numeric: true, placeholder: '12', onChanged: (v) => s.update(() => s.lReqWid = v.replaceAll(RegExp(r'\D'), '')))])),
            ],
          ),
          T('Free. The Hostelzy team draws it within 48 hours. Tenants keep seeing the current layout.', s: 12, c: p.mu, lh: 1.45),
          Cta('Send request', height: 54, px: 16, fs: 15, onTap: s.sendLayoutRequest),
        ],
      ),
    );
  }
}

/// Board 6: the Hostelzy team's layout editor. Tap a bed or item to select
/// it, drag it on the 1-ft grid or nudge it; add, delete, turn, resize the
/// room, undo / redo. Bed facts update as things move.
class AdminLayoutScreen extends StatelessWidget {
  const AdminLayoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final rs = s.rooms[h.id]!;
    final room = rs.firstWhere((r) => r.n == s.lRoom);
    final l = s.layoutOf(h.id, room.n)!;
    final sel = s.edSel;
    final selItem = sel == null || sel.startsWith('bed:') ? null : l.items.where((i) => i.id == sel).firstOrNull;
    final selName = sel == null
        ? 'Tap a bed or an item'
        : sel.startsWith('bed:')
        ? 'Bed ${room.label}-${sel.substring(4)}'
        : selItem == null
        ? 'Tap a bed or an item'
        : '${const {'fan': 'Fan', 'ac': 'AC unit', 'window': 'Window', 'door': 'Door', 'wash': 'Washroom zone', 'pillar': 'Pillar'}[selItem.kind]}${selItem.kind == 'ac' || selItem.kind == 'window' || selItem.kind == 'door' ? ' · ${wallOf(selItem.rect, l.w, l.h) ?? 'inside'} wall' : ''}';
    final checks = <(bool, String)>[
      if (room.ac) (l.ac != null, l.ac != null ? 'AC room has an AC unit' : 'AC room needs an AC unit') else (true, 'Non-AC room · no AC unit needed'),
      (l.beds.length == room.share, '${l.beds.length} beds placed · ${room.share} sharing'),
      (l.window == null || l.window!.facing != null, 'Window facing: ${l.window?.facing ?? 'no window'}'),
      // F24: beds and things inside the room's shape.
      if (l.outline != null) wallsCheck(l, room.label),
      (true, 'No gates, CCTV or exits drawn'),
    ];
    Widget sq(String icon, VoidCallback on, {String? label, Key? key}) => Tap(
      key: key,
      onTap: on,
      child: Container(
        height: 36,
        constraints: const BoxConstraints(minWidth: 36),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
        alignment: Alignment.center,
        decoration: box(w: 2, c: p.tx),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Ic(icon, size: 16, color: p.tx), if (label != null) ...[const SizedBox(width: 6), T(label, s: 13, w: 800)]]),
      ),
    );
    Widget section(String t, List<Widget> kids) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: VGap(gap: 8, children: [Kicker(t), ...kids]),
    );
    // F24: the owner's "Ask Hostelzy to draw it" request for this room.
    final req = s.shapeReqFor(h.id, room.n);
    final lockedBy = s.edLockedBy;
    final ready = checks.every((c) => c.$1) && lockedBy == null;
    void blocked() => s.toastMsg(lockedBy != null ? '${lockedBy.name} is editing this room. Try again when they’re done.' : 'Fix the checks first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Rich([sp(context, 'Layout editor · '), sp(context, '${h.name} · Room ${room.label}', c: p.ac)], w: 800, s: 15),
                    // F12: one editor at a time. Someone else has this room open.
                    if (lockedBy != null)
                      T('${lockedBy.name} is editing this room', key: const ValueKey('edLocked'), s: 12, w: 800, c: p.ad, ell: true)
                    else
                      T(l.pending ? 'v${l.version} with the owner · v${l.version - 1} live' : 'v${l.version} live · edits make a new version', s: 12, c: p.mu),
                  ],
                ),
              ),
            ],
          ),
        ),
        Scroll(
          horizontal: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [for (final r in rs) ...[ChipBtn(r.label, on: r.n == room.n, onTap: () => s.edSwitchRoom(r.n)), const SizedBox(width: 6)]]),
          ),
        ),
        // The map stays out of the scroll so dragging never scrolls the page.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: LayoutMap(l: l, room: room, mode: 'edit', fan: true, ac: true, selected: sel, onSelect: s.edSelect, onDrag: (id, d) => s.edDrag(l, id, d), onDragEnd: s.edDragEnd),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(child: T(selName, s: 13, w: 800, c: sel == null ? p.mu : p.tx, ell: true)),
              sq('back', () => s.edNudge(l, -1, 0), key: const ValueKey('nudge-left')),
              const SizedBox(width: 4),
              Transform.rotate(angle: math.pi / 2, child: sq('back', () => s.edNudge(l, 0, -1), key: const ValueKey('nudge-up'))),
              const SizedBox(width: 4),
              Transform.rotate(angle: -math.pi / 2, child: sq('back', () => s.edNudge(l, 0, 1), key: const ValueKey('nudge-down'))),
              const SizedBox(width: 4),
              sq('chev', () => s.edNudge(l, 1, 0), key: const ValueKey('nudge-right')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              sq('swap', () => s.edRotate(l), label: 'Turn'),
              const SizedBox(width: 6),
              sq('trash', () => s.edDelete(l, room), label: 'Delete'),
              const Spacer(),
              Opacity(opacity: s.canUndo ? 1 : .35, child: sq('back', () => s.edUndo(l), label: 'Undo')),
              const SizedBox(width: 6),
              Opacity(opacity: s.canRedo ? 1 : .35, child: sq('arrow', () => s.edRedo(l), label: 'Redo')),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(
              key: ValueKey('aLayout${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section('Add', [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (k, t) in const [('bed', '+ Bed'), ('fan', '+ Fan'), ('ac', '+ AC'), ('window', '+ Window'), ('door', '+ Door'), ('wash', '+ Washroom'), ('pillar', '+ Pillar')]) ChipBtn(t, on: false, onTap: () => s.edAdd(l, room, k)),
                    ]),
                    T('Never draw gates, CCTV or exits. Power sockets come in phase 2.', s: 12, c: p.ad, lh: 1.4),
                  ]),
                  if (selItem?.kind == 'window')
                    section('Window faces', [Seg(opts: const [('street', 'Street'), ('courtyard', 'Courtyard'), ('building', 'Building')], cur: selItem!.facing ?? 'street', onPick: (v) => s.update(() => selItem.facing = v), center: true)]),
                  if (selItem != null && const ['fan', 'ac', 'window'].contains(selItem.kind))
                    section('Status', [Seg(opts: const [('ok', 'Working'), ('bad', 'Not working')], cur: selItem.working ? 'ok' : 'bad', onPick: (v) => s.setWorking(l, selItem, v == 'ok'), center: true)]),
                  section('Room size · ${l.w.round()} × ${l.h.round()} ft${l.outline == null ? '' : ' · ${l.shape}'}', [
                    // One row each, so the buttons fit a 390-wide phone.
                    Row(children: [const T('Width', s: 13), const Spacer(), sq('x', () => s.edResize(l, -1, 0), label: '−1', key: const ValueKey('w-')), const SizedBox(width: 6), sq('plus', () => s.edResize(l, 1, 0), label: '+1', key: const ValueKey('w+'))]),
                    Row(children: [const T('Length', s: 13), const Spacer(), sq('x', () => s.edResize(l, 0, -1), label: '−1', key: const ValueKey('h-')), const SizedBox(width: 6), sq('plus', () => s.edResize(l, 0, 1), label: '+1', key: const ValueKey('h+'))]),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ChipBtn(sel != null && sel.startsWith('bed:') && (l.bunks.containsKey(sel.substring(4)) || l.upperOn(sel.substring(4)) != null) ? 'Unstack bunk' : 'Stack as bunk', on: false, onTap: () => s.edBunk(l, room)),
                      ChipBtn('Copy to same rooms', on: false, onTap: () => s.copyToSameRooms(l, room)),
                      ChipBtn('Mirror ↔', on: false, onTap: () => s.edMirror(l)),
                      ChipBtn('Flip ↕', on: false, onTap: () => s.edMirror(l, vertical: true)),
                      ChipBtn('History', on: false, onTap: () => s.toastMsg('v1 drawn 28 Sep${l.version > 1 ? ' · v${l.version} drawn ${l.drawn}' : ''}')),
                    ]),
                  ]),
                  section('Bed facts · update as you move things', [
                    for (final b in l.beds.keys.toList()..sort())
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 60, child: T('${room.label}-$b', w: 800, s: 13)),
                          Expanded(child: T(bedFacts(l, room, b).join(' · '), s: 12, c: p.mu, lh: 1.4)),
                        ],
                      ),
                  ]),
                  section('Beds · linked to the bed map', [
                    for (final b in room.beds)
                      Row(
                        children: [
                          SizedBox(width: 60, child: T(b.id, w: 800, s: 14)),
                          Expanded(child: T(s.residents.any((x) => x.bed == b.id) || b.state == 'booked' ? 'Has a resident · can’t delete' : const {'free': 'Free', 'held': 'On hold', 'soon': 'Free soon'}[b.state] ?? 'Taken', s: 13, c: p.mu)),
                          if (!l.beds.containsKey(b.letter)) T('Not placed', s: 12, w: 800, c: p.ad),
                        ],
                      ),
                  ]),
                  if (l.disputes > 0)
                    section('Residents', [T('Residents say this layout is wrong: ${l.disputes} answered “No” in the 30-day review. Check it on the next visit.', s: 13, c: p.ad, lh: 1.4)]),
                  section('Checks before sending', [
                    for (final (ok, t) in checks) Row(children: [Ic(ok ? 'check' : 'warn', size: 16, color: ok ? p.gn : p.ad), const SizedBox(width: 8), Expanded(child: T(t, s: 13))]),
                  ]),
                  if (req != null)
                    section('Owner request', [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: box(bg: p.ab, w: 2, c: p.ad),
                        child: VGap(
                          gap: 4,
                          children: [
                            T(req.status == 'sent' ? 'Sent to ${h.owner} · waiting for them to publish' : 'Draw within 48 hours · ${hoursLeft(req.due, DateTime.now().millisecondsSinceEpoch)}', w: 800, s: 14, c: p.ad),
                            T('${h.owner} · ${req.shape}${req.w > 0 && req.h > 0 ? ' · ${req.w.round()} × ${req.h.round()} ft' : ''}', s: 12, c: p.mu),
                            if (req.note.isNotEmpty) T('“${req.note}”', s: 14, w: 600, lh: 1.4),
                            if (req.photos.isNotEmpty) T('${req.photos.length} ${req.photos.length == 1 ? 'photo' : 'photos'} · in the team console', s: 12, c: p.mu),
                          ],
                        ),
                      ),
                    ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          // F18: owners publish straight away; the team sends its drawing to the owner.
          child: Row(
            children: [
              Expanded(
                child: s.edOwner
                    ? Cta('Publish', key: const ValueKey('edPublish'), icon: 'check', height: 52, px: 16, fs: 15, opacity: ready ? 1 : .4, onTap: () => ready ? s.publishLayout(l) : blocked())
                    : Cta('Send to owner', height: 52, px: 16, fs: 15, opacity: ready ? 1 : .4, onTap: () => ready ? s.sendLayoutToOwner(l) : blocked()),
              ),
              // F12: publishing waits until the other editor is done (10 minutes after they stop).
              if (lockedBy != null) ...[
                const SizedBox(width: 8),
                Cta('Check again', key: const ValueKey('edLockRetry'), height: 52, px: 14, fs: 15, expand: false, bg: transparent, fg: p.ad, border: p.ad, onTap: s.takeLayoutLock),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


/// Owner Today: every 3 months, confirm the room layouts still match (F12).
class ConfirmLayoutsCard extends StatelessWidget {
  const ConfirmLayoutsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final days = s.layoutConfirmed[s.ownHid];
    if (days == null || days < layoutConfirmEvery || s.layouts[s.ownHid] == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 8,
        children: [
          const T('Do your room layouts still match?', w: 800, s: 17),
          T('Last confirmed $days days ago. Every 3 months, check that beds, fans, AC and windows are still where the layouts show them.', s: 13, c: p.mu, lh: 1.4),
          Row(
            children: [
              Expanded(child: Cta('All still correct', icon: 'check', height: 46, px: 12, fs: 14, onTap: () => s.confirmLayouts(s.ownHid))),
              const SizedBox(width: 8),
              Cta('Review', icon: 'chev', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.go('oLayouts')),
            ],
          ),
        ],
      ),
    );
  }
}

/// F24 board oShape: a shape tile's little outline.
class ShapeIconPainter extends CustomPainter {
  ShapeIconPainter(this.shape, this.color);
  final String shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final box = Rect.fromLTRB(4, 4, size.width - 4, size.height - 4);
    if (shape == 'Custom') {
      canvas.drawPath(
        Path()
          ..moveTo(box.left + 4, box.top + 2)
          ..cubicTo(box.left + 14, box.top - 4, box.right, box.top + 6, box.right - 2, box.center.dy)
          ..cubicTo(box.right - 4, box.bottom, box.left + 10, box.bottom + 2, box.left, box.center.dy + 4)
          ..close(),
        ink,
      );
      return;
    }
    final o = shapeOutline(shape, box.width, box.height);
    if (o == null) return canvas.drawRect(box, ink);
    canvas.drawPath(Path()..addPolygon([for (final q in o) q + box.topLeft], true), ink);
  }

  @override
  bool shouldRepaint(ShapeIconPainter o) => o.shape != shape || o.color != color;
}

/// F18 design "Create": a room with no layout yet.
class CreateLayoutScreen extends StatelessWidget {
  const CreateLayoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final src = s.copySource(room.n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Room ${room.label}', title: 'Create a layout', size: 28))]),
        ),
        Expanded(
          child: Scroll(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 14,
                children: [
                  T('Room ${room.label} has no layout yet. Tenants see “Layout coming soon” until you publish one.', s: 14, c: p.mu, lh: 1.5),
                  // F24 item 11 (board oShape): pick the room's shape first.
                  const T('Room shape', w: 800, s: 13),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: .95,
                    children: [
                      for (final sh in layoutShapes)
                        Tap(
                          key: ValueKey('shape-$sh'),
                          // Custom: the Hostelzy team draws it (48 h).
                          onTap: () => sh == 'Custom' ? s.openShapeRequest(shape: 'Custom') : s.update(() => s.clShape = sh),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: box(bg: s.clShape == sh ? p.ab : transparent, w: s.clShape == sh ? 2 : 1, c: s.clShape == sh ? p.ac : p.dv),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 44, height: 36, child: CustomPaint(painter: ShapeIconPainter(sh, p.tx))),
                                const SizedBox(height: 4),
                                FittedBox(fit: BoxFit.scaleDown, child: T(sh, s: 12, w: 800, nowrap: true)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: VGap(gap: 6, children: [const T('Width (ft)', w: 800, s: 13), Field(key: const ValueKey('clLen'), value: s.clLen, numeric: true, onChanged: (v) => s.update(() => s.clLen = v.replaceAll(RegExp(r'\D'), '')))])),
                      const SizedBox(width: 10),
                      Expanded(child: VGap(gap: 6, children: [const T('Length (ft)', w: 800, s: 13), Field(key: const ValueKey('clWid'), value: s.clWid, numeric: true, onChanged: (v) => s.update(() => s.clWid = v.replaceAll(RegExp(r'\D'), '')))])),
                    ],
                  ),
                  if (src != null)
                    Tap(
                      onTap: () => s.createLayout(from: src.n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: box(w: 2, c: p.tx),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Copy Room ${src.label} instead', w: 800, s: 14), T('Same shape and items · you can change them after', w: 600, s: 11, c: p.mu)])),
                            const Ic('copy', size: 18),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    color: p.sf,
                    child: VGap(
                      gap: 6,
                      children: [
                        Rich([sp(context, 'Not on the list, or no time? ', w: 800), sp(context, 'Tap Custom. Send a photo and a sketch; the Hostelzy team draws it within 48 hours, free.')], s: 13, lh: 1.45),
                        Tap(key: const ValueKey('askHostelzy'), onTap: () => s.openShapeRequest(shape: s.clShape), child: T('Ask Hostelzy to draw it', w: 800, s: 14, c: p.ad)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta(s.clShape == 'Rectangle' ? 'Start drawing' : 'Start drawing · ${s.clShape}', key: const ValueKey('startDrawing'), height: 54, px: 16, fs: 15, onTap: s.createLayout),
        ),
      ],
    );
  }
}

/// F18 design "Published": the owner's layout is live, no approval needed.
class LayoutPublishedScreen extends StatelessWidget {
  const LayoutPublishedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final l = s.layoutOf(h.id, room.n)!;
    final u = s.lastPublish?.room == room.n ? s.lastPublish : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Room ${room.label}', title: 'Live for tenants'))]),
        ),
        Expanded(
          child: Scroll(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: p.tx,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Ic('check', size: 20, color: p.bg),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Published just now', w: 800, s: 14, c: p.bg), T('Tenants see this layout in the Room tab right away. Bed IDs and prices didn’t change.', s: 13, c: p.bg, lh: 1.4)])),
                      ],
                    ),
                  ),
                  LayoutMap(l: l, room: room, mode: 'plain', fan: true, ac: true),
                  KV('Version', 'v${l.version} · by you · ${l.drawn}', keyWidth: 90),
                  if (u?.snap != null) KV('Before', 'v${u!.version}', keyWidth: 90),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 8,
            children: [
              Cta('Done', icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.update(() {
                s.screen = 'oLayouts';
                s.hist = s.hist.where((x) => x != 'aLayout' && x != 'oLayout' && x != 'oLayouts').toList();
              })),
              OutlineCta('Edit again', icon: 'pencil', onTap: () => s.openLayout(room.n, editor: true, owner: true)),
              if (u != null) Tap(onTap: () => s.undoPublish(l), child: T(u.snap == null ? 'Undo publish · hide it again' : 'Undo publish · go back to v${u.version}', w: 800, s: 13, c: p.tx)),
            ],
          ),
        ),
      ],
    );
  }
}
