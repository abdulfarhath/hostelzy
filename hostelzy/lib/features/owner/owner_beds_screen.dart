import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../amenities/floor_map.dart';
import 'owner_today_screen.dart';

const ownerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];

/// "SK" for Sneha Kumar.
String initialsOf(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return '';
  return (w.length == 1 ? w.first.substring(0, w.first.length.clamp(0, 2)) : '${w.first[0]}${w[1][0]}').toUpperCase();
}

/// F22 Area 3 (board `beds`) + F25 (board w4-oFloorPlan): Beds is
/// *Floor plan · All floors*. Floor plan: one floor as a corridor map, each
/// bed with the resident's initials, Free, Hold or the free-from date, the
/// shared things placed (broken ones red, with a Mark Fixed line). All
/// floors: every floor's rooms as cards. A bed opens the bed sheet (H18).
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
    String sem(Bed b) => 'Bed ${b.id}, ${s.residents.where((x) => x.bed == b.id).firstOrNull?.name ?? const {'free': 'free', 'held': 'on hold', 'booked': 'taken', 'soon': 'free soon'}[b.state] ?? b.state}';

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
                              return Tap(
                                key: ValueKey('obed-${b.id}'),
                                onTap: () => openBed(b),
                                child: Semantics(
                                  label: sem(b),
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

    List<Widget> grid(List<Room> fr) => [
      for (var k = 0; k < fr.length; k += 2) ...[
        if (k > 0) const SizedBox(height: 8),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: card(fr[k])), const SizedBox(width: 8), Expanded(child: k + 1 < fr.length ? card(fr[k + 1]) : const SizedBox())])),
      ],
    ];

    // F25: one bed on the floor plan: letter, then who / Free / Hold / the date.
    Widget planBed(Room r, Bed b) {
      final sel = s.sheet == 'bed' && s.obed == b.id;
      final res = s.residents.where((x) => x.bed == b.id).firstOrNull;
      final word = switch (b.state) {
        'free' => 'Free',
        'held' => 'Hold',
        'soon' => b.soon.isEmpty ? 'Soon' : b.soon,
        _ => res != null ? initialsOf(res.name) : 'Taken',
      };
      return Tap(
        key: ValueKey('obed-${b.id}'),
        onTap: () => openBed(b),
        child: Semantics(
          label: sem(b),
          child: BedBox(
            look: sel ? bedState(p, 'sel') : bedState(p, b.state),
            minHeight: 46,
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [T(b.letter, s: 12, w: 800), T(word, key: ValueKey('obedWord-${b.id}'), s: 12, w: 800, ell: true)],
            ),
          ),
        ),
      );
    }

    final broken = s.amenitiesOn(s.ownHid, cur).where((x) => !x.working).toList();
    final List<Widget> body = s.obView == 'all'
        ? [
            for (final f in floors) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Row(children: [Expanded(child: T(s.floorName(f), key: ValueKey('obAllFloor-$f'), w: 800, s: 17)), T('${freeOn(f)} free', s: 13, c: p.mu)]),
              ),
              ...grid(a.where((r) => r.floor == f).toList()),
              const SizedBox(height: 14),
            ],
          ]
        : [
            FloorChips(keyPrefix: 'obFloor', items: [for (final f in floors) (f, freeOn(f))], cur: cur, onPick: (f) => s.update(() => s.obFloor = f)),
            const SizedBox(height: 10),
            FloorMap(
              hid: s.ownHid,
              floor: cur,
              rooms: a.where((r) => r.floor == cur).toList(),
              roomKey: 'oRoom',
              perRow: 2,
              bedCols: 2,
              bed: planBed,
              roomFoot: (r) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  T('Rent ${fmt(r.rent)}', s: 12, c: p.mu),
                  // F12/F18: Hostelzy drew a new layout for this room; the owner publishes it.
                  if (s.layoutOf(s.ownHid, r.n)?.pending == true) ...[
                    const SizedBox(height: 4),
                    Tap(
                      onTap: () => s.ownerLayout(r.n),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        color: p.ac,
                        child: T('New layout', s: 12, w: 800, c: p.ai),
                      ),
                    ),
                  ],
                ],
              ),
              onThing: (x) => s.openFloorSheet(s.ownHid, x.floor),
            ),
            for (final x in broken)
              Container(
                key: ValueKey('brokenLine-${x.id}'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                color: p.ab,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T('${x.label}, ${s.floorName(x.floor).toLowerCase()}: not working.', s: 13, w: 800, c: p.ad, lh: 1.35),
                          T('Marked by ${x.byResident ? 'a resident' : 'you'} · ${dayMon(DateTime.fromMillisecondsSinceEpoch(x.at))}', s: 12, c: p.ad, lh: 1.35),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tap(
                      key: ValueKey('markFixed-${x.id}'),
                      onTap: () async {
                        await s.setAmenityWorking(x, true);
                        if (s.sheet == 'amFloor') s.update(() => s.sheet = null);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: box(w: 2, c: p.ad),
                        child: T('Mark Fixed', s: 13, w: 800, c: p.ad),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            NotPlacedStrip(hid: s.ownHid, floor: cur, onThing: (x) => s.openFloorSheet(s.ownHid, x.floor), note: 'Place them in Layouts › Shared things so tenants see where they are.'),
            const SizedBox(height: 8),
            T('Initials = who sleeps there. Tap a bed to manage it, or a shared thing to change it.', s: 12, c: p.mu, lh: 1.45),
            const SizedBox(height: 12),
          ];

    return Scroll(
      key: ValueKey('oBeds${s.scrollEpoch}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(kicker: occCounts(s), title: 'Beds'),
            const SizedBox(height: 12),
            Seg(
              key: const ValueKey('obView'),
              opts: const [('plan', 'Floor plan'), ('all', 'All floors')],
              cur: s.obView,
              onPick: (v) => s.update(() => s.obView = v),
              center: true,
            ),
            const SizedBox(height: 10),
            ...body,
            Wrap(
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
