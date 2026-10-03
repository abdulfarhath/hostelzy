import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../amenities/amenities_screens.dart';

// F25 (board w4-building; the founder's pick: the original cross-section from
// commit 417c385; the hub merged the floor map into it, one screen). A roof, then every floor top-down: the floor's label in a
// 40-px left column, its shared things as chips on top of the row, then its
// rooms with their beds (free / on hold / taken / your pick), then the base
// slab. Floors come from the hostel's real rooms; a ground floor shows only
// when the data has one (rooms, or shared things on floor 0), with only what
// the data says. Nothing invented (no "reception", gates, CCTV or exits).

/// A shared thing as a small chip: red when not working.
class ThingTag extends StatelessWidget {
  const ThingTag(this.a, {super.key});
  final Amenity a;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final (bg, fg, bd) = a.working ? (p.bg, p.tx, p.tx) : (p.ab, p.ad, p.ac);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      decoration: box(bg: bg, w: 1, c: bd),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic(amenityIcon(a.kind), size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(child: T(a.working ? a.label : '${a.label} · not working', s: 11, w: 800, ls: .04, upper: true, c: fg, ell: true)),
        ],
      ),
    );
  }
}

const buildingLegend = [('Free', 'free'), ('On hold', 'held'), ('Taken', 'booked'), ('Your pick', 'sel')];

/// [onBed]: a tap on a bed (tenant: pick it; owner: the bed sheet). A tap on
/// a floor's label or its shared things opens the floor sheet (H42).
/// [selected]: the picked bed's id. [dim]: rooms that don't fit the filter.
class BuildingView extends StatelessWidget {
  const BuildingView({super.key, required this.hid, required this.rooms, required this.onBed, this.selected, this.dim, this.tenant = true});
  final String hid;
  final List<Room> rooms;
  final void Function(Bed b) onBed;
  final String? selected;
  final bool Function(Room r)? dim;
  final bool tenant;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final floors = {...floorsOf(rooms), ...s.amenityFloors(hid)}.toList()..sort((a, b) => b.compareTo(a));
    bool open(Bed b) => (b.state == 'free' || b.state == 'soon') && !b.mine;
    int freeOn(int f) => rooms.where((r) => r.floor == f && dim?.call(r) != true).fold<int>(0, (x, r) => x + r.beds.where(open).length);
    final total = floors.fold<int>(0, (x, f) => x + freeOn(f));

    Widget bedBox(Room r, Bed b) {
      final l = lookOf(p, b, selected);
      final off = dim?.call(r) == true;
      return Tap(
        key: ValueKey('bBed-${b.id}'),
        enabled: !off && (!tenant || l.can),
        onTap: off ? null : () => onBed(b),
        child: Semantics(label: 'Bed ${b.id}, ${l.tag}', child: BedBox(look: l.look, width: 22, height: 28)),
      );
    }

    Widget roomCell(Room r, bool first) => Opacity(
      key: ValueKey('bRoom-${r.n}'),
      opacity: dim?.call(r) == true ? .35 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: r.beds.any((b) => b.id == selected) ? p.sf : null,
          border: first ? null : Border(left: bs(1, p.hl)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            T(r.label, s: 12, w: 600, c: p.mu),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [for (final b in r.beds) bedBox(r, b)]),
          ],
        ),
      ),
    );

    Widget row(int f) {
      final rs = rooms.where((r) => r.floor == f).toList();
      final things = s.amenitiesOn(hid, f).where((a) => !a.inRooms).toList();
      final ts = MediaQuery.textScalerOf(context).scale(1);
      final per = ts > 1.3 ? 2 : 3;
      final label = Container(
        width: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(right: bs(2, p.tx))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            T(f == 0 ? 'G' : 'F$f', w: 800, s: 14),
            if (rs.isNotEmpty) T('${freeOn(f)}', s: 12, c: p.mu),
          ],
        ),
      );
      return Container(
        key: ValueKey('bFloorRow-$f'),
        decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Tap(key: ValueKey('bFloor-$f'), onTap: () => s.openFloorSheet(hid, f), child: Semantics(label: '${s.floorName(f)}${rs.isEmpty ? '' : ', ${freeOn(f)} free'}: shared things', child: label)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // F25: the floor's shared things on top of its row.
                    if (things.isNotEmpty)
                      Tap(
                        key: ValueKey('bThings-$f'),
                        onTap: () => s.openFloorSheet(hid, f),
                        child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                        decoration: rs.isEmpty ? null : BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                        child: Wrap(spacing: 4, runSpacing: 4, children: [for (final a in things) ThingTag(a)]),
                      )),
                    if (rs.isEmpty)
                      Padding(padding: const EdgeInsets.all(8), child: T(f == 0 ? 'Ground floor' : s.floorName(f), s: 12, c: p.mu))
                    else
                      for (var i = 0; i < rs.length; i += per)
                        Container(
                          decoration: i == 0 ? null : BoxDecoration(border: Border(top: bs(1, p.hl))),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var j = i; j < i + per; j++) Expanded(child: j < rs.length ? roomCell(rs[j], j == i) : const SizedBox()),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('buildingView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Kicker(tenant ? 'Cross-section · tap any free bed' : 'Cross-section · tap a bed')),
            const SizedBox(width: 8),
            T('$total free', key: const ValueKey('bTotalFree'), s: 12, c: p.mu),
          ],
        ),
        const SizedBox(height: 10),
        // The roof.
        FractionallySizedBox(
          widthFactor: .8,
          child: Container(height: 14, decoration: BoxDecoration(color: p.sf, border: Border(top: bs(2, p.tx), left: bs(2, p.tx), right: bs(2, p.tx)))),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx), left: bs(2, p.tx), right: bs(2, p.tx))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final f in floors) row(f)]),
        ),
        // The base slab, wider than the building.
        SizedBox(
          height: 8,
          child: Stack(clipBehavior: Clip.none, children: [Positioned(left: -6, right: -6, top: 0, bottom: 0, child: Container(color: p.tx))]),
        ),
        const SizedBox(height: 14),
        Legend(items: tenant ? buildingLegend : buildingLegend.take(3).toList()),
        const SizedBox(height: 8),
        T('Shared things sit on top of each floor. Tap a floor to see if they’re working.', s: 12, c: p.mu, lh: 1.45),
      ],
    );
  }
}
