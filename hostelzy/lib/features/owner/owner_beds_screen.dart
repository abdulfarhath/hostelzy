import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../holds/building_view.dart';
import 'owner_today_screen.dart';

const ownerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];

/// F22 Area 3 (board `beds`): floor chips with free counts, rooms as cards
/// with their beds as boxes, the legend and "Rooms and rates ›". A bed opens
/// the bed sheet.
class OwnerBedsScreen extends StatelessWidget {
  const OwnerBedsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms[s.ownHid]!;
    final floors = floorsOf(a);
    int freeOn(int f) => a.where((r) => r.floor == f).fold<int>(0, (x, r) => x + r.beds.where((b) => b.state == 'free').length);
    void openBed(Bed b) => s.update(() {
      s.sheet = 'bed';
      s.obed = b.id;
    });
    final cur = floors.contains(s.obFloor) ? s.obFloor : (floors.firstOrNull ?? 1);
    final fr = a.where((r) => r.floor == cur).toList();

    Widget card(Room r) {
      // F12/F18: Hostelzy drew a new layout for this room; the owner publishes it.
      final wait = s.layoutOf(s.ownHid, r.n)?.pending == true;
      return Container(
        key: ValueKey('oRoom-${r.n}'),
        padding: const EdgeInsets.all(10),
        decoration: box(w: 2, c: p.tx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: T('Room ${r.label}', w: 800, s: 15, lh: 1.25)),
                const SizedBox(width: 6),
                Expanded(child: T([r.share, if (r.ac) 'AC', fmt(r.rent)].join(' · '), s: 12, c: p.mu, align: TextAlign.right, lh: 1.35)),
              ],
            ),
            const SizedBox(height: 8),
            for (var k = 0; k < r.beds.length; k += 2) ...[
              if (k > 0) const SizedBox(height: 6),
              Row(
                children: [
                  for (var j = k; j < k + 2; j++) ...[
                    if (j > k) const SizedBox(width: 6),
                    Expanded(
                      child: j < r.beds.length
                          ? () {
                              final b = r.beds[j];
                              final sel = s.sheet == 'bed' && s.obed == b.id;
                              final res = s.residents.where((x) => x.bed == b.id).firstOrNull;
                              return Tap(
                                key: ValueKey('obed-${b.id}'),
                                onTap: () => openBed(b),
                                child: Semantics(
                                  label: 'Bed ${b.id}, ${res?.name ?? const {'free': 'free', 'held': 'on hold', 'booked': 'taken', 'soon': 'free soon'}[b.state] ?? b.state}',
                                  child: BedBox(look: sel ? bedState(p, 'sel') : bedState(p, b.state), minHeight: 64, child: Center(child: T(b.letter, w: 800, s: 18))),
                                ),
                              );
                            }()
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ],
            if (wait) ...[
              const SizedBox(height: 8),
              Tap(
                onTap: () => s.ownerLayout(r.n),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: p.ac,
                  child: Row(children: [Ic('room', size: 14, color: p.ai), const SizedBox(width: 6), Expanded(child: T('New layout', s: 13, w: 800, c: p.ai, ell: true))]),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final grid = <Widget>[];
    for (var k = 0; k < fr.length; k += 2) {
      if (k > 0) grid.add(const SizedBox(height: 8));
      grid.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: card(fr[k])), const SizedBox(width: 8), Expanded(child: k + 1 < fr.length ? card(fr[k + 1]) : const SizedBox())])));
    }
    return Scroll(
      key: ValueKey('oBeds${s.scrollEpoch}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(kicker: occCounts(s), title: 'Beds'),
            const SizedBox(height: 12),
            // F25 (hub): Rooms · Building; Building is the tenant picker's component.
            Seg(key: const ValueKey('obView'), opts: const [('rooms', 'Rooms'), ('building', 'Building')], cur: s.obView, onPick: (v) => s.update(() => s.obView = v), center: true),
            const SizedBox(height: 12),
            if (s.obView == 'building')
              BuildingView(hid: s.ownHid, rooms: a, tenant: false, selected: s.sheet == 'bed' ? s.obed : null, onBed: openBed)
            else ...[
            Row(
              children: [
                for (final f in floors) ...[
                  if (f != floors.first) const SizedBox(width: 6),
                  Expanded(
                    child: Tap(
                      key: ValueKey('obFloor-$f'),
                      onTap: () => s.update(() => s.obFloor = f),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                        alignment: Alignment.center,
                        decoration: box(bg: f == cur ? p.tx : transparent, w: f == cur ? 2 : 1, c: f == cur ? p.tx : p.dv),
                        child: T('Floor $f · ${freeOn(f)} free', s: 13, w: 800, c: f == cur ? p.bg : p.tx, align: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ...grid,
            const SizedBox(height: 12),
            ],
            if (s.obView == 'rooms') Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Legend(items: ownerLegend),
                Tap(key: const ValueKey('roomsRates'), onTap: s.openRates, child: const T('Rooms and rates ›', s: 13, w: 800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
