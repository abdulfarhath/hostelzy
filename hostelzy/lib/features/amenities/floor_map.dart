import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'amenities_screens.dart';

// F25 (boards w4-floorMap, w4-oFloorPlan): one floor drawn as a corridor map.
// Rooms sit either side of the corridor (the first half above, the rest
// below: a sketch, the owner doesn't draw the floor); the shared things are
// drawn where the owner placed them. Things without a spot are listed under
// "Not placed yet", never guessed. Stairs and a WC are drawn only when the
// data says they exist (more than one floor; rooms with a shared bath). Never
// gates, CCTV or exits.

/// A shared thing as a small tag on the map: red when not working.
class ThingTag extends StatelessWidget {
  const ThingTag(this.a, {super.key, this.active = false});
  final Amenity a;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final (bg, fg, bd) = active ? (p.ac, p.ai, p.ac) : a.working ? (p.bg, p.tx, p.tx) : (p.ab, p.ad, p.ac);
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

/// The corridor map of [floor] of [hid]: [rooms] either side, the placed
/// shared things in the corridor. [bed] draws one bed; [roomFoot] adds a line
/// under a room (owner: the rent). While placing, [onSpot] gets the tapped
/// spot (0–100 each way) and the thing being placed shows there.
class FloorMap extends StatelessWidget {
  const FloorMap({super.key, required this.hid, required this.floor, required this.rooms, required this.bed, this.roomKey = 'roomCard', this.roomFoot, this.onRoom, this.onThing, this.dim, this.bedCols, this.perRow = 3, this.placing, this.spot, this.onSpot});
  final String hid;
  final int floor;
  final List<Room> rooms;
  final Widget Function(Room r, Bed b) bed;
  final String roomKey;
  final Widget Function(Room r)? roomFoot;
  final void Function(Room r)? onRoom;
  final void Function(Amenity a)? onThing;
  final bool Function(Room r)? dim;

  /// Beds as a grid of this many columns (owner), else as a wrap of boxes.
  final int? bedCols;
  final int perRow;
  final Amenity? placing;
  final (int, int)? spot;
  final void Function(int x, int y)? onSpot;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final per = ts > 1.3 ? 2 : perRow;
    final top = rooms.take((rooms.length + 1) ~/ 2).toList(), bottom = rooms.skip((rooms.length + 1) ~/ 2).toList();
    final things = s.placedOn(hid, floor).where((a) => a.id != placing?.id).toList();

    Widget card(Room r) {
      Widget beds;
      if (bedCols != null) {
        beds = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var k = 0; k < r.beds.length; k += bedCols!) ...[
              if (k > 0) const SizedBox(height: 4),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = k; j < k + bedCols!; j++) ...[
                      if (j > k) const SizedBox(width: 4),
                      Expanded(child: j < r.beds.length ? bed(r, r.beds[j]) : const SizedBox()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      } else {
        beds = Wrap(spacing: 4, runSpacing: 4, children: [for (final b in r.beds) bed(r, b)]);
      }
      final head = Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [T(r.label, w: 800, s: 13), T('${r.share}${r.ac ? ' · AC' : ''}', s: 12, c: p.mu)],
      );
      return Opacity(
        key: ValueKey('$roomKey-${r.n}'),
        opacity: dim?.call(r) == true ? .35 : 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: box(bg: p.bg, w: 2, c: p.tx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onRoom != null) Tap(key: ValueKey('roomName-${r.n}'), enabled: dim?.call(r) != true, onTap: () => onRoom!(r), child: head) else head,
              const SizedBox(height: 6),
              beds,
              if (roomFoot != null) ...[const SizedBox(height: 4), roomFoot!(r)],
            ],
          ),
        ),
      );
    }

    List<Widget> side(List<Room> rs) => [
      for (var i = 0; i < rs.length; i += per)
        Padding(
          padding: const EdgeInsets.all(6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + per; j++) ...[
                  if (j > i) const SizedBox(width: 6),
                  Expanded(child: j < rs.length ? card(rs[j]) : const SizedBox()),
                ],
              ],
            ),
          ),
        ),
    ];

    final sharedBath = [for (final r in rooms) if (r.bath == 'Shared') r.label];
    // Old owner plan (417c385): stairs block on the left, WC on the right.
    // Drawn only from real data: stairs when the hostel has more than one
    // floor, a WC when rooms on this floor use a shared washroom. Where they
    // sit along the corridor is a sketch, like the rooms.
    final stairs = {...floorsOf(s.rooms[hid] ?? const <Room>[]), ...s.amenityFloors(hid)}.length > 1;
    final wc = sharedBath.isNotEmpty;
    final h = 56 + 34 * ts;
    Widget end(String t, {bool hatch = false, required bool left}) => Container(
      width: 48,
      decoration: BoxDecoration(color: hatch ? null : p.bg, border: left ? Border(right: bs(2, p.tx)) : Border(left: bs(2, p.tx))),
      child: CustomPaint(
        painter: hatch ? Hatch(p.tk, 2, 7, angle: 90) : null,
        child: Center(child: Container(color: hatch ? p.sf : null, padding: const EdgeInsets.symmetric(horizontal: 2), child: T(t, s: 11, w: 800, c: p.mu))),
      ),
    );
    final corridor = Container(
      key: const ValueKey('corridor'),
      height: h,
      decoration: BoxDecoration(color: p.sf, border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stairs) KeyedSubtree(key: const ValueKey('stairs'), child: end('Stairs', hatch: true, left: true)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                Alignment at(int x, int y) => Alignment(x / 50 - 1, y / 50 - 1);
                final cur = placing == null ? null : spot;
                return Stack(
                  children: [
                    Positioned(left: 6, top: 4, child: Kicker(placing != null ? 'Corridor · tap where it is' : 'Corridor')),
                    if (onSpot != null)
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey('corridorTap'),
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => onSpot!((d.localPosition.dx / c.maxWidth * 100).round().clamp(0, 100), (d.localPosition.dy / c.maxHeight * 100).round().clamp(0, 100)),
                        ),
                      ),
                    for (final a in things)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Align(
                          alignment: at(a.posX!, a.posY!),
                          child: IgnorePointer(
                            ignoring: onSpot != null,
                            child: Tap(key: ValueKey('thing-${a.id}'), onTap: onThing == null ? null : () => onThing!(a), child: Semantics(label: '${a.label}${a.working ? '' : ', not working'}', child: ThingTag(a))),
                          ),
                        ),
                      ),
                    if (placing != null && cur != null)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Align(alignment: at(cur.$1, cur.$2), child: IgnorePointer(child: ThingTag(placing!, key: const ValueKey('placingTag'), active: true))),
                      ),
                  ],
                );
              },
            ),
          ),
          if (wc) KeyedSubtree(key: const ValueKey('wc'), child: end('WC', left: false)),
        ],
      ),
    );

    final inRooms = s.amenitiesOn(hid, floor).where((a) => a.inRooms).toList();
    String where(Amenity a) {
      final w = s.amenityWhere(a);
      return '${a.label} ${w[0].toLowerCase()}${w.substring(1)}${a.working ? '' : ' (not working)'}';
    }

    final map = Container(
      decoration: box(w: 2, c: p.tx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: Row(children: [Expanded(child: Kicker(s.floorName(floor))), Kicker('${rooms.length} room${rooms.length == 1 ? '' : 's'}')]),
          ),
          if (rooms.isEmpty) Padding(padding: const EdgeInsets.all(10), child: T('No rooms on this floor.', s: 13, c: p.mu)),
          ...side(top),
          corridor,
          ...side(bottom),
          for (final line in [for (final a in inRooms) where(a), if (sharedBath.isNotEmpty) 'Shared washroom on this floor for room${sharedBath.length == 1 ? '' : 's'} ${sharedBath.join(', ')}'])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
              child: T(line, s: 12, c: p.mu, lh: 1.35),
            ),
        ],
      ),
    );
    // The roof edge of the old plan: a thick bar over the middle.
    return Column(
      key: ValueKey('floorMap-$floor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FractionallySizedBox(widthFactor: .64, child: Container(height: 6, color: p.tx)),
        map,
      ],
    );
  }
}

/// Shared things on [floor] without a spot yet: listed, never guessed.
class NotPlacedStrip extends StatelessWidget {
  const NotPlacedStrip({super.key, required this.hid, required this.floor, this.onThing, this.note});
  final String hid;
  final int floor;
  final void Function(Amenity a)? onThing;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = s.unplacedOn(hid, floor);
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('notPlaced'),
      padding: const EdgeInsets.all(10),
      color: p.sf,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Kicker('Not placed yet'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final a in list) Tap(key: ValueKey('unplaced-${a.id}'), onTap: onThing == null ? null : () => onThing!(a), child: ThingTag(a))],
          ),
          if (note != null) ...[const SizedBox(height: 6), T(note!, s: 12, c: p.mu, lh: 1.4)],
        ],
      ),
    );
  }
}

/// Floor chips "Floor 2 · 4 free" (picker Plan, owner Floor plan).
class FloorChips extends StatelessWidget {
  const FloorChips({super.key, required this.items, required this.cur, required this.onPick, required this.keyPrefix});
  final List<(int floor, int free)> items;
  final int cur;
  final ValueChanged<int> onPick;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (f, free) in items)
          Tap(
            key: ValueKey('$keyPrefix-$f'),
            onTap: () => onPick(f),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: box(bg: f == cur ? p.tx : transparent, w: f == cur ? 2 : 1, c: f == cur ? p.tx : p.dv),
              child: T('${f == 0 ? 'Ground' : s.floorName(f)} · $free free', s: 13, w: 800, c: f == cur ? p.bg : p.tx),
            ),
          ),
      ],
    );
  }
}

/// H44 "Place on the floor": the floor map; tap the corridor where the thing
/// is, then save. Owner, manager or the team (Layouts › Shared things).
class PlaceThingSheet extends StatelessWidget {
  const PlaceThingSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.placingThing;
    if (a == null) return const SizedBox();
    final rooms = s.roomsOnFloor(a.hid, a.floor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('Tap the corridor where the ${a.label.toLowerCase()} is. Tenants see it there on the floor map.', s: 14, c: p.mu, lh: 1.4),
          const SizedBox(height: 12),
          FloorMap(
            hid: a.hid,
            floor: a.floor,
            rooms: rooms,
            roomKey: 'placeRoom',
            bed: (r, b) => BedBox(look: bedState(p, 'free'), width: 18, height: 18),
            placing: a,
            spot: s.amPlaceSpot,
            onSpot: (x, y) => s.update(() => s.amPlaceSpot = (x, y)),
          ),
          const SizedBox(height: 12),
          Cta(s.amPlaceSpot == null ? 'Tap a spot first' : 'Save the spot', key: const ValueKey('amPlaceSave'), icon: 'check', height: 54, px: 16, fs: 15, opacity: s.amPlaceSpot == null ? .4 : 1, onTap: s.savePlace),
          if (a.placed)
            Tap(
              key: const ValueKey('amPlaceClear'),
              onTap: () => s.savePlace(clear: true),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Take it off the map', w: 800, s: 14, c: p.ad)),
            ),
        ],
      ),
    );
  }
}
