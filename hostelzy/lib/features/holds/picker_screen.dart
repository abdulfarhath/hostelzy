import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../layouts/layout_map.dart';

// ------------------------------------------------------------ picker

class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final rs = s.rooms[h.id]!;
    final room = rs.where((r) => r.n == s.room).firstOrNull ?? rs[0];
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    final hasSel = sb != null && sb.b != null;
    // F23: the room plan comes first (layout-first, founder); its "Floor view"
    // button and the floor view's room names switch between the two. The
    // list is a "See cheapest beds" link.
    final locked = s.floorLocked(h.id) && s.mode == 'plan';

    Widget body;
    if (locked) {
      body = const FloorLocked();
    } else if (s.mode == 'room') {
      body = RoomMode(rooms: rs, room: room);
    } else if (s.mode == 'plan') {
      body = _PlanMode(rooms: rs, room: room);
    } else {
      body = _ListMode(rooms: rs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: s.mode == 'room' ? [Kicker('${h.name} · ${room.share} sharing', ell: true), T('Room ${room.label}', w: 800, s: 26, lh: 1.1)] : [Kicker(h.name, ell: true), const T('Pick a bed', w: 800, s: 26, lh: 1.1)],
                ),
              ),
            ],
          ),
        ),
        if (s.mode == 'list')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                key: const ValueKey('cheapest'),
                onTap: () => s.update(() => s.mode = 'plan'),
                child: T('‹ Back to the plan', s: 14, w: 800, c: p.ad),
              ),
            ),
          ),
        if (h.ac && h.hasNon && s.mode != 'room')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(padding: EdgeInsets.only(right: 4), child: Kicker('Room')),
                for (final f in const ['Any', 'AC', 'Non-AC']) ChipBtn(f, on: s.pR == f, onTap: () => s.pickRoomType(f)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(key: ValueKey('picker${s.scrollEpoch}'), child: body),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: bs(2, p.tx)),
          ),
          child: s.mode == 'room' ? RoomBar(room: room) : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(hasSel ? 'Bed ${sb.b!.id} · ${fmt(sb.r!.rent)}/mo' : 'No bed picked', w: 800, s: 17, lh: 1.25),
                    T(hasSel ? sb.b!.spot : 'Tap a free bed', s: 12, c: p.mu, ell: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta('Continue', key: const ValueKey('pickContinue'), onTap: () => s.bed == null ? s.toastMsg('Pick a free bed first.') : s.update(() => s.sheet = 'hold'), height: 50, fs: 15, expand: false, opacity: hasSel ? 1 : .4),
            ],
          ),
        ),
      ],
    );
  }
}

const pickerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];

/// Floor tabs: label + "n free", bottom bar on the active one.
class FloorTabs extends StatelessWidget {
  const FloorTabs({super.key, required this.items, required this.cur, required this.onPick, this.borderTop = false});
  final List<(int floor, int free)> items;
  final int cur;
  final ValueChanged<int> onPick;
  final bool borderTop;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      decoration: borderTop ? BoxDecoration(border: Border(top: bs(2, p.tx))) : null,
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Tap(
                onTap: () => onPick(it.$1),
                child: InsetBar(
                  edge: Edge.bottom,
                  size: it.$1 == cur ? 3 : 1,
                  color: it.$1 == cur ? p.ac : p.hl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Css(
                      c: it.$1 == cur ? p.tx : p.mu,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('Floor ${it.$1}', w: 800, s: 15), const SizedBox(height: 2), T('${it.$2} free', s: 12)]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// F22 Area 1: floors as chips, then every room on the floor as a card with
/// its beds as boxes. A bed tap picks it; the room name opens the Room view.
class _PlanMode extends StatelessWidget {
  const _PlanMode({required this.rooms, required this.room});
  final List<Room> rooms;
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final floors = [
      for (final f in floorsOf(rooms)) (f, rooms.where((r) => r.floor == f && AppState.fits(r, s.pR)).fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length)),
    ];
    final tiles = rooms.where((r) => r.floor == s.floor).toList();
    Widget card(Room r) {
      final fits = AppState.fits(r, s.pR);
      return Opacity(
        key: ValueKey('roomCard-${r.n}'),
        opacity: fits ? 1 : .35,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: box(w: 2, c: r.beds.any((b) => b.id == s.bed) ? p.ac : p.tx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Tap(
                enabled: fits,
                // F12: the room name opens it in the Room view.
                onTap: () => s.openRoom(r.n),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: T('Room ${r.label}', w: 800, s: 15, lh: 1.2)),
                    const SizedBox(width: 8),
                    Expanded(child: T('${r.share} sharing${r.ac ? ' AC' : ''} · ${fmt(r.rent)}', s: 12, c: p.mu, lh: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in r.beds)
                    () {
                      final l = lookOf(p, b, s.bed);
                      return Tap(
                        key: ValueKey('bed-${b.id}'),
                        enabled: fits && l.can,
                        onTap: () => s.pickBed(b),
                        child: Semantics(
                          label: 'Bed ${b.id}, ${l.tag}',
                          child: BedBox(
                            look: l.look,
                            width: 54,
                            height: 48,
                            child: Center(child: T(b.letter, w: 800, s: 17)),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final grid = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) grid.add(const SizedBox(height: 10));
      grid.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: card(tiles[i])), const SizedBox(width: 10), Expanded(child: i + 1 < tiles.length ? card(tiles[i + 1]) : const SizedBox())],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < floors.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Tap(
                    key: ValueKey('floor-${floors[i].$1}'),
                    onTap: () {
                      final f = floors[i].$1;
                      final fit = rooms.where((r) => r.floor == f && AppState.fits(r, s.pR));
                      final r = fit.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? fit.firstOrNull ?? rooms.firstWhere((r) => r.floor == f);
                      s.update(() {
                        s.floor = f;
                        s.room = r.n;
                        s.bed = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: box(bg: floors[i].$1 == s.floor ? p.tx : transparent, w: 1, c: floors[i].$1 == s.floor ? p.tx : p.mu),
                      child: T('Floor ${floors[i].$1} · ${floors[i].$2} free', s: 13, w: 800, c: floors[i].$1 == s.floor ? p.bg : p.tx, lh: 1.2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...grid,
          for (final r in tiles.where((r) => r.ac && r.acRepair))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: p.ab,
              child: T('Room ${r.label}: AC under repair.${r.acSince.isEmpty ? '' : ' Complaint raised ${r.acSince}.'} The owner is fixing it.', s: 12, w: 600, c: p.ad, lh: 1.4),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Legend(items: pickerLegend),
              Tap(
                key: const ValueKey('cheapest'),
                onTap: () => s.update(() => s.mode = 'list'),
                child: const T('See cheapest beds ›', s: 13, w: 800, underline: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListMode extends StatelessWidget {
  const _ListMode({required this.rooms});
  final List<Room> rooms;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final lb = <({Bed b, Room r})>[];
    for (final r in rooms) {
      for (final b in r.beds) {
        if ((b.state == 'free' || b.state == 'soon') && !b.mine && AppState.fits(r, s.pR)) lb.add((b: b, r: r));
      }
    }
    // Stable sort by rent.
    final indexed = lb.asMap().entries.toList()..sort((x, y) => x.value.r.rent != y.value.r.rent ? x.value.r.rent.compareTo(y.value.r.rent) : x.key.compareTo(y.key));
    final sorted = indexed.map((e) => e.value).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
          child: Kicker('${sorted.length} beds you can take · cheapest first'),
        ),
        for (final e in sorted)
          () {
            final o = e.b.id == s.bed;
            return Tap(
              onTap: () => s.pickBed(e.b),
              child: InsetBar(
                edge: Edge.left,
                size: o ? 4 : 0,
                color: p.ac,
                bg: o ? p.ab : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Stripes(
                        step: 5,
                        width: 60,
                        height: 60,
                        border: Border.all(color: p.hl),
                        child: Container(
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(4),
                          child: T('bed', s: 9, mono: true, c: p.mu),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('Bed ${e.b.id}', w: 800, s: 16),
                            const SizedBox(height: 2),
                            T('Floor ${e.r.floor} · ${e.r.share} sharing · ${e.r.type} · ${e.r.bath} bath', s: 12, c: p.mu),
                            const SizedBox(height: 2),
                            T('${e.b.spot} · ${e.b.state == 'soon' ? 'Free from ${e.b.soon}' : 'Free now'}', s: 12, w: 600),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          T(fmt(e.r.rent), w: 800, s: 16),
                          T('per month', s: 11, c: p.mu),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
