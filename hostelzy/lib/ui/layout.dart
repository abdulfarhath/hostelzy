import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
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
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);
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
    if (l.wash != null) {
      final w = sc(l.itemRect(l.wash!));
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
    final air = l.airflow;
    if (ac && air != null && l.ac != null) {
      final a = sc(air);
      final unit = sc(l.itemRect(l.ac!));
      final right = unit.center.dx > a.center.dx;
      final near = right ? a.right : a.left, far = right ? a.left : a.right;
      final path = Path()
        ..moveTo(near, a.top + a.height * .22)
        ..lineTo(near, a.top + a.height * .52)
        ..lineTo(far, a.bottom)
        ..lineTo(far, a.top)
        ..close();
      canvas.save();
      canvas.clipPath(path);
      final st = Paint()
        ..color = p.dv
        ..strokeWidth = 1;
      for (var x = a.left; x < a.right; x += 6) {
        canvas.drawLine(Offset(x, a.top), Offset(x, a.bottom), st);
      }
      canvas.restore();
    }
    if (fan) {
      final dash = Paint()
        ..color = p.dv
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final f in l.of('fan')) {
        final c = sc(l.itemRect(f)).center;
        final r = fanReach * k;
        const n = 36;
        for (var i = 0; i < n; i += 2) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * 2 * math.pi / n, 2 * math.pi / n, false, dash);
        }
      }
    }
    canvas.drawRect((Offset.zero & size).deflate(1), ink);
    if (l.window != null) {
      final w = sc(l.itemRect(l.window!));
      canvas.drawRect(Rect.fromLTWH(w.left, w.center.dy < size.height / 2 ? 0 : size.height - 6, w.width, 6), Paint()..color = p.tx);
    }
    if (l.door != null) {
      final d = sc(l.itemRect(l.door!));
      canvas.drawRect(Rect.fromLTWH(d.left, d.center.dy > size.height / 2 ? size.height - 4 : 0, d.width, 4), Paint()..color = p.bg);
    }
    if (l.ac != null) {
      final u = sc(l.itemRect(l.ac!));
      canvas.drawRect(u, Paint()..color = l.ac!.working ? p.tx : p.ad);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter o) => true;
}

/// How a bed looks on the map. [mode]: tenant | compare | plain.
class LayoutMap extends StatelessWidget {
  const LayoutMap({super.key, required this.l, required this.room, this.mode = 'tenant', this.focus, this.cmp = const [], this.fan = false, this.ac = false, this.onPick});
  final RoomLayout l;
  final Room room;
  final String mode;
  final String? focus;
  final List<String> cmp;
  final bool fan, ac;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
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
        if (l.wash != null) {
          final w = sc(l.itemRect(l.wash!));
          labels.add(Positioned(left: w.left + 6, top: w.bottom - 22, child: label('Washroom')));
        }
        if (l.window != null) {
          final w = sc(l.itemRect(l.window!));
          final top = w.center.dy < hgt / 2;
          labels.add(Positioned(left: w.left, top: top ? 9 : null, bottom: top ? null : 9, child: label('Window · ${l.window!.facing}', c: l.window!.working ? null : p.ad)));
        }
        if (l.door != null) {
          final d = sc(l.itemRect(l.door!));
          labels.add(Positioned(left: d.left + 12, top: d.center.dy > hgt / 2 ? d.top - 20 : 8, child: T('Door', s: 10, w: 800, ls: .08, upper: true, c: p.mu)));
        }
        if (l.ac != null) {
          final u = sc(l.itemRect(l.ac!));
          final right = u.center.dx > c.maxWidth / 2;
          labels.add(Positioned(left: right ? null : u.right + 4, right: right ? c.maxWidth - u.left + 4 : null, top: u.bottom + 4, child: label(l.ac!.working && !room.acRepair ? 'AC unit' : 'AC · under repair', c: l.ac!.working && !room.acRepair ? null : p.ad)));
        }
        for (final f in l.of('fan')) {
          final ct = sc(l.itemRect(f)).center;
          labels.add(Positioned(left: ct.dx - 11, top: ct.dy - 10, child: label(f.working ? 'Fan' : 'Fan · not working', icon: 'fan', c: f.working ? null : p.ad)));
        }
        for (final b in room.beds) {
          if (!l.beds.containsKey(b.letter)) continue;
          final r = sc(l.bedRect(b.letter));
          final (look, tag) = switch (mode) {
            'plain' => (BedLook(p.sf, p.tx, p.tx, '3 × 6 ft'), '3 × 6 ft'),
            'compare' when cmp.isNotEmpty && b.letter == cmp[0] => (bedState(p, 'sel'), 'Selected'),
            'compare' when cmp.length > 1 && b.letter == cmp[1] => (BedLook(p.ab, p.ac, p.ad, 'Compare'), 'Compare'),
            _ => () {
              final lk = lookOf(p, b, b.letter == focus && (b.state == 'free' || b.state == 'soon') ? b.id : s.bed);
              return (lk.look, lk.tag);
            }(),
          };
          kids.add(
            Positioned.fromRect(
              rect: r,
              child: Tap(
                onTap: () => onPick?.call(b.letter),
                child: BedBox(
                  look: look,
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T(b.letter, w: 800, s: 22, lh: 1),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: T(tag, s: 9, w: 800, ls: .06, upper: true, nowrap: true)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Semantics(
          label: 'Room ${l.room} layout, ${l.w.round()} by ${l.h.round()} feet',
          child: SizedBox(width: c.maxWidth, height: hgt, child: Stack(clipBehavior: Clip.hardEdge, children: [...kids, ...labels])),
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
    final picker = Scroll(
      horizontal: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            for (final r in rooms.where((r) => AppState.fits(r, s.pR))) ...[
              ChipBtn('${r.n}', on: r.n == room.n, onTap: () => s.update(() {
                s.room = r.n;
                s.floor = r.floor;
                s.bed = null;
                s.roomBed = null;
              })),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
    Widget body;
    if (!s.signedIn) {
      body = VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'lock', head: 'Sign in to see room layouts', body: 'Room layouts are only for people who have verified their phone number.'),
          T('It takes one OTP. We never share your number with the hostel until you choose to.', s: 12, c: p.mu, lh: 1.4),
        ],
      );
    } else if (l == null) {
      body = VGap(
        gap: 14,
        children: [
          const LayoutEmpty(icon: 'pencil', head: 'Layout coming soon', body: 'The Hostelzy team is drawing this room. You can still pick a bed from Plan or List, and see the photos.'),
          OutlineCta('Tell me when it’s ready', height: 50, onTap: () => s.toastMsg('Alerts come once the app is online. Check back here for now.')),
          T('Layouts are drawn by Hostelzy after a visit, so what you see matches the room.', s: 12, c: p.mu, lh: 1.4),
        ],
      );
    } else {
      body = VGap(
        gap: 10,
        children: [
          Row(
            children: [
              ChipBtn('Show fan reach', on: s.showFan, onTap: () => s.update(() => s.showFan = !s.showFan)),
              if (l.ac != null) ...[const SizedBox(width: 6), ChipBtn('Show AC airflow', on: s.showAc, onTap: () => s.update(() => s.showAc = !s.showAc))],
            ],
          ),
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T('${l.w.round()} × ${l.h.round()} ft · 1 square = 1 ft', s: 11, c: p.mu), T('Sample layout · real ones after a visit', s: 11, c: p.mu)]),
          if (fb != null)
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: VGap(
                gap: 8,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [Expanded(child: T('Bed ${fb.id} · ${const {'free': 'Free', 'held': 'On hold', 'soon': 'Free soon'}[fb.state] ?? 'Taken'}', w: 800, s: 17)), T('Same price as every bed here', s: 12, c: p.mu)],
                  ),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final f in bedFacts(l, room, fb.letter)) Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), color: p.sf, child: T(f, s: 12, w: 600))]),
                ],
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        picker,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: VGap(
            gap: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [Expanded(child: T('Room ${room.n}', w: 800, s: 20)), Rich([sp(context, '${room.share} sharing · ${room.type} · ${fmt(room.rent)}'), sp(context, '/mo', w: 400, c: p.mu)], s: 13, w: 600)],
              ),
              body,
            ],
          ),
        ),
      ],
    );
  }
}

/// The Room tab's bottom bar: Compare beds + Hold bed (or Verify my phone).
class RoomBar extends StatelessWidget {
  const RoomBar({super.key, required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    if (!s.signedIn) {
      return Cta('Verify my phone', height: 54, px: 16, fs: 15, onTap: () => s.go('phone'));
    }
    final l = s.liveLayout(s.hid, room.n);
    final focus = roomFocus(s, room);
    final b = room.beds.where((x) => x.letter == focus).firstOrNull;
    final can = b != null && (b.state == 'free' || b.state == 'soon') && !b.mine;
    final hold = can
        ? Cta('Hold bed ${b.letter}', height: 54, px: 16, fs: 15, onTap: () => s.update(() {
            s.bed = b.id;
            s.sheet = 'hold';
          }))
        : Cta(b == null ? 'Pick a bed' : 'Taken', height: 54, px: 16, fs: 15, bg: p.tk, fg: p.tx, onTap: () => s.toastMsg('Pick a free bed first.'));
    if (l == null) return hold;
    return Row(
      children: [
        Tap(
          onTap: s.openCompare,
          child: Container(height: 54, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('Compare beds', w: 800, s: 15)),
        ),
        const SizedBox(width: 8),
        Expanded(child: hold),
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
          child: Row(children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker('Room ${room.n} · ${room.share} sharing · ${room.type}'), const T('Compare beds', w: 800, s: 22, lh: 1.1)]))]),
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
    final (stText, stBg, stFg) = l == null
        ? ('Hostelzy is drawing this room', p.sf, p.tx)
        : l.request != null
        ? ('Change requested · new version within 48 h', p.ab, p.ad)
        : l.pending
        ? ('Check it and approve to go live', p.ab, p.ad)
        : ('Approved · live for tenants', p.tx, p.bg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Beds', title: 'Room ${room.n} layout', size: 26))]),
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
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    color: stBg,
                    child: Row(children: [Expanded(child: T(stText, s: 13, w: 800, c: stFg)), if (l != null) T('v${l.version} · drawn ${l.drawn}', s: 13, w: 600, c: stFg)]),
                  ),
                  if (l == null)
                    const LayoutEmpty(icon: 'pencil', head: 'Layout coming soon', body: 'The Hostelzy team draws every room after the visit. You approve it here before tenants see it.')
                  else ...[
                    LayoutMap(l: l, room: room, mode: 'plain', fan: true, ac: true),
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
        if (l != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(child: Cta(l.pending ? 'Approve layout' : 'Approved', icon: 'check', height: 52, px: 16, fs: 15, opacity: l.pending ? 1 : .5, onTap: () => l.pending ? s.approveLayout(l) : s.toastMsg('Tenants already see this layout.'))),
                const SizedBox(width: 8),
                Tap(
                  onTap: s.openLayoutRequest,
                  child: Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('Request a change', w: 800, s: 15)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Board 5: request a layout change (sheet).
class LayoutRequestSheet extends StatelessWidget {
  const LayoutRequestSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const tiles = [('photo', 'Room photo', 'From the door, whole room'), ('sketch', 'Paper sketch', 'Draw it on paper, take a photo'), ('voice', 'Voice note', 'Say what’s wrong, any language'), ('more', 'More photos', 'Pillar, alcove, balcony')];
    Widget tile((String, String, String) t) {
      final on = s.lReqAdded.contains(t.$1);
      final tl = Tap(
        onTap: () => s.update(() => on ? s.lReqAdded.remove(t.$1) : s.lReqAdded.add(t.$1)),
        child: Container(
          padding: const EdgeInsets.all(10),
          color: on ? p.sf : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Expanded(child: T(t.$2, w: 800, s: 14)), T(on ? 'Added' : '+ Add', s: 12, w: 800, c: on ? p.tx : p.ad)]),
              const SizedBox(height: 2),
              T(on ? (t.$1 == 'voice' ? 'Added · 0:18' : 'Added · 1 photo') : t.$3, s: 11, c: p.mu, lh: 1.3),
            ],
          ),
        ),
      );
      return Expanded(child: on ? Container(decoration: box(w: 2, c: p.tx), child: tl) : Dashed(color: p.dv, width: 1, child: tl));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          VGap(gap: 6, children: [const T('What’s different?', w: 800, s: 13), Field(value: s.lReqText, maxLines: 3, height: null, placeholder: 'Bed C is against the washroom wall, not near the door.', onChanged: (v) => s.update(() => s.lReqText = v))]),
          const Kicker('Add any of these'),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile(tiles[0]), const SizedBox(width: 8), tile(tiles[1])])),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile(tiles[2]), const SizedBox(width: 8), tile(tiles[3])])),
          Row(
            children: [
              Expanded(child: VGap(gap: 6, children: [const T('Length (ft)', w: 800, s: 13), Field(value: s.lReqLen, numeric: true, placeholder: '18', onChanged: (v) => s.update(() => s.lReqLen = v.replaceAll(RegExp(r'\D'), '')))])),
              const SizedBox(width: 8),
              Expanded(child: VGap(gap: 6, children: [const T('Width (ft)', w: 800, s: 13), Field(value: s.lReqWid, numeric: true, placeholder: '15', onChanged: (v) => s.update(() => s.lReqWid = v.replaceAll(RegExp(r'\D'), '')))])),
            ],
          ),
          T('Free. The Hostelzy team redraws it within 48 hours and sends you the new version to approve. Tenants keep seeing the current layout until then.', s: 12, c: p.mu, lh: 1.45),
          Cta('Send request', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.sendLayoutRequest),
        ],
      ),
    );
  }
}

/// Board 6: the Hostelzy team's layout editor. The design is a 1440 px
/// laptop screen with drag and drop; in the app it is one column with the
/// same panels (shape, items, selected item, beds, checks, owner request).
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
    int n(String k) => l.of(k).length;
    final checks = <(bool, String)>[
      if (room.ac) (l.ac != null, l.ac != null ? 'AC room has an AC unit' : 'AC room has no AC unit') else (true, 'Non-AC room · no AC unit needed'),
      (l.beds.length == room.share, '${l.beds.length} beds = ${room.share} sharing'),
      (l.window?.facing != null, 'Window facing set: ${l.window?.facing ?? '—'}'),
      (true, 'No gates, CCTV or exits drawn'),
    ];
    Widget section(String t, List<Widget> kids) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: VGap(gap: 8, children: [Kicker(t), ...kids]),
    );
    final req = l.request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Rich([sp(context, 'Hostelzy '), sp(context, 'admin', c: p.ac)], w: 800, s: 20),
              const SizedBox(height: 2),
              T('Layouts / ${h.name} / Floor ${room.floor} / Room ${room.n}', s: 12, c: p.mu),
              const SizedBox(height: 2),
              T(l.pending ? 'v${l.version} with the owner · v${l.version - 1} live' : 'v${l.version} live', s: 12, w: 800),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('aLayout${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Scroll(
                  horizontal: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [for (final r in rs) ...[ChipBtn('${r.n}', on: r.n == room.n, onTap: () => s.update(() => s.lRoom = r.n)), const SizedBox(width: 6)]]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChipBtn('Copy to rooms…', on: false, onTap: () => s.toastMsg('Copy to rooms is in the laptop editor.')),
                      ChipBtn('Mirror', on: l.mirrored, onTap: () => s.update(() => l.mirrored = !l.mirrored)),
                      ChipBtn('Flip', on: l.flipped, onTap: () => s.update(() => l.flipped = !l.flipped)),
                      ChipBtn('History', on: false, onTap: () => s.toastMsg('v1 drawn 28 Sep${l.version > 1 ? ' · v2 drawn ${l.drawn}' : ''}')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: VGap(
                    gap: 6,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T('${l.w.round()} × ${l.h.round()} ft · grid 1 ft', s: 12, w: 800), T('Room type ${room.type} · ${room.share} sharing', s: 12, c: p.mu)]),
                      LayoutMap(l: l, room: room, mode: 'plain', fan: true, ac: true),
                    ],
                  ),
                ),
                section('Room shape', [
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final sh in layoutShapes) ChipBtn(sh, on: l.shape == sh, onTap: () => s.update(() => l.shape = sh))]),
                  T('Drag walls to resize in 1 ft steps on the laptop editor.', s: 12, c: p.mu),
                ]),
                section('Items', [
                  for (final (k, v) in [('Bed', '${l.beds.length} placed'), ('Bunk bed (2 beds)', ''), ('Window', '${n('window')}'), ('Door', '${n('door')}'), ('Fan', '${n('fan')}'), ('AC', '${n('ac')}'), ('Washroom zone', '${n('wash')}'), ('Pillar', '')])
                    Row(children: [Expanded(child: T(k, s: 14, w: 600)), T(v == '0' ? '' : v, s: 13, c: p.mu)]),
                  T('Never draw gates, CCTV or exits. Power sockets come in phase 2.', s: 12, c: p.ad, lh: 1.4),
                ]),
                if (l.ac != null)
                  section('Selected · AC unit', [
                    for (final (k, opts) in const [('Wall', ['Top', 'Right', 'Bottom', 'Left']), ('Blows', ['Left', 'Down', 'Up']), ('Reach', ['6 ft', '8 ft', '10 ft']), ('Status', ['Working', 'Not working'])])
                      Row(
                        children: [
                          SizedBox(width: 60, child: T(k, s: 13, c: p.mu)),
                          Expanded(child: Seg(opts: [for (final o in opts) (o, o)], cur: k == 'Status' ? (l.ac!.working ? 'Working' : 'Not working') : s.acProps[k]!, onPick: (v) => k == 'Status' ? s.setWorking(l, l.ac!, v == 'Working') : s.update(() => s.acProps[k] = v), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), fs: 12, center: true)),
                        ],
                      ),
                  ]),
                section('Beds · linked to the bed map', [
                  for (final b in room.beds)
                    Row(
                      children: [
                        SizedBox(width: 60, child: T(b.id, w: 800, s: 14)),
                        Expanded(child: T(s.residents.any((x) => x.bed == b.id) ? 'Has a resident · can’t delete' : const {'free': 'Free', 'held': 'On hold', 'soon': 'Free soon'}[b.state] ?? 'Taken', s: 13, c: p.mu)),
                      ],
                    ),
                ]),
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
                          T('31 h left of 48', w: 800, s: 14, c: p.ad),
                          T('${h.owner} · ${req.at}', s: 12, c: p.mu),
                          if (req.text.isNotEmpty) T('“${req.text}”', s: 14, w: 600, lh: 1.4),
                          T([for (final a in req.added) const {'photo': 'Room photo', 'sketch': 'Paper sketch', 'voice': 'Voice note 0:18', 'more': 'More photos'}[a], if (req.size.isNotEmpty) req.size].join(' · '), s: 12, c: p.mu),
                        ],
                      ),
                    ),
                  ]),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Cta('Send to owner for approval', height: 54, px: 16, fs: 15, opacity: checks.every((c) => c.$1) ? 1 : .4, onTap: () => checks.every((c) => c.$1) ? s.sendLayoutToOwner(l) : s.toastMsg('Fix the checks first.')),
        ),
      ],
    );
  }
}
