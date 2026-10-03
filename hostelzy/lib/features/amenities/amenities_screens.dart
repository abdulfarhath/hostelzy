import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F23: floor amenities and room items. The pieces every role sees (chips, the
// hostel page block, the strip above a room plan) and the two sheets (a
// floor's list, add / change a thing).

String amenityIcon(String kind) => amenityKinds.firstWhere((k) => k.$1 == kind, orElse: () => amenityKinds.last).$3;

/// One thing as a chip: icon + words; struck through and grey when broken,
/// with a red NOT WORKING tag.
class AmenityChip extends StatelessWidget {
  const AmenityChip(this.a, {super.key, this.text});
  final Amenity a;
  final String? text;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final c = a.working ? p.tx : p.mu;
    final chip = Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: box(w: 1, c: a.working ? p.tx : p.dv),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic(amenityIcon(a.kind), size: 16, color: c),
          const SizedBox(width: 5),
          Flexible(child: Text(text ?? a.label, style: TextStyle(fontFamily: 'Archivo', fontSize: 13, fontWeight: FontWeight.w600, color: c, decoration: a.working ? null : TextDecoration.lineThrough, decorationColor: c), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    if (a.working) return chip;
    return Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: chip), Container(padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), color: p.ab, child: T('NOT WORKING', s: 11, w: 800, c: p.ad))]);
  }
}

/// Hostel page: "On each floor", one row per floor; a tap opens the floor.
class OnEachFloor extends StatelessWidget {
  const OnEachFloor({super.key, required this.hid});
  final String hid;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final floors = s.amenityFloors(hid);
    if (floors.isEmpty) return const SizedBox.shrink();
    final byRes = s.amenities.where((a) => a.hid == hid && a.byResident).map((a) => a.at).fold<int>(0, (x, y) => x > y ? x : y);
    return Column(
      key: const ValueKey('onEachFloor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: Kicker('On each floor')),
              if (byRes > 0) T('Updated by residents · ${dayMon(DateTime.fromMillisecondsSinceEpoch(byRes))}', s: 12, w: 800, c: p.mu),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in floors)
                Tap(
                  key: ValueKey('amFloor-$f'),
                  onTap: () => s.openFloorSheet(hid, f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T(s.floorName(f), w: 800, s: 15),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final a in s.amenitiesOn(hid, f)) AmenityChip(a, text: s.amenityLine(a))]),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: () {
            final ex = s.amenities.where((a) => a.hid == hid && a.inRooms).firstOrNull;
            final inRooms = ex == null ? '' : ' “${s.amenityLine(ex).replaceFirst('${ex.label} ', '')}” means the room’s own ${ex.place == 'washroom' ? 'washroom' : 'room'} has it. Each room plan shows its own.';
            return T('Shared by everyone on that floor.$inRooms', s: 13, c: p.mu, lh: 1.4);
          }(),
        ),
      ],
    );
  }
}

/// Above a room plan: the shared things on that floor; a tap opens the floor.
class FloorStrip extends StatelessWidget {
  const FloorStrip({super.key, required this.hid, required this.floor});
  final String hid;
  final int floor;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final shared = s.amenitiesOn(hid, floor).where((a) => !a.inRooms).toList();
    if (shared.isEmpty && !s.canEditAmenities(hid)) return const SizedBox.shrink();
    return Tap(
      key: const ValueKey('floorStrip'),
      onTap: () => s.openFloorSheet(hid, floor),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        color: p.sf,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  T('On ${s.floorName(floor).toLowerCase()}', w: 800, s: 13),
                  const SizedBox(height: 6),
                  if (shared.isEmpty) T('Nothing listed yet. Add the fridge, RO, washing machine…', s: 13, c: p.mu) else Wrap(spacing: 6, runSpacing: 6, children: [for (final a in shared) AmenityChip(a)]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Ic('chev', size: 16, color: p.tx),
          ],
        ),
      ),
    );
  }
}

/// "Geyser in washroom" for a room's bed facts.
List<String> roomThingLines(AppState s, String hid, int room) => [
  for (final a in s.inRoom(hid, room)) '${a.label} ${a.place == 'washroom' ? 'in washroom' : 'in the room'}${a.working ? '' : ' (not working)'}',
];

/// The floor sheet: each thing with its count and status; the people who may
/// change the list get Add a thing / Something broke.
class AmenityFloorSheet extends StatelessWidget {
  const AmenityFloorSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.amHid);
    final list = s.amenitiesOn(s.amHid, s.amFloor);
    final edit = s.canEditAmenities(s.amHid);
    final staff = s.amenityStaff(s.amHid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing listed on this floor yet.', s: 14, c: p.mu)),
        for (final a in list)
          Tap(
            key: ValueKey('amRow-${a.id}'),
            enabled: edit,
            onTap: () => s.amBreak ? s.setAmenityWorking(a, !a.working) : s.openAddAmenity(edit: a),
            child: Opacity(
              opacity: a.working ? 1 : .8,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  children: [
                    Container(width: 36, height: 36, color: p.sf, alignment: Alignment.center, child: Ic(amenityIcon(a.kind), size: 20, color: p.tx)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T(a.qty > 1 && !a.inRooms ? '${a.label} ×${a.qty}' : a.label, w: 800, s: 16),
                          T(
                            [
                              if (a.inRooms) s.amenityWhere(a),
                              if (a.byResident) 'Added by a resident · ${dayMon(DateTime.fromMillisecondsSinceEpoch(a.at))}${staff ? '' : ' · ${h.owner} told'}',
                            ].join(' · '),
                            s: 13,
                            c: p.mu,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (s.amBreak && edit)
                      Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), decoration: box(w: 2, c: p.tx), child: T(a.working ? 'Not working' : 'Working again', s: 12, w: 800))
                    else
                      Tag(a.working ? 'Working' : 'Not working', bg: a.working ? transparent : p.ab, fg: a.working ? p.mu : p.ad),
                  ],
                ),
              ),
            ),
          ),
        if (edit) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(child: Cta('Add a thing', key: const ValueKey('amAddBtn'), icon: 'plus', height: 48, px: 14, fs: 14, onTap: s.openAddAmenity)),
                const SizedBox(width: 8),
                Expanded(child: OutlineCta(s.amBreak ? 'Done' : 'Something broke', key: const ValueKey('amBreakBtn'), icon: s.amBreak ? 'check' : 'wrench', height: 48, px: 14, fs: 14, onTap: () => s.update(() => s.amBreak = !s.amBreak))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: T(s.amBreak ? 'Tap what isn’t working (or works again).' : staff ? 'Residents can add or fix this list. You see every change here.' : 'Residents can add or fix this list. ${h.owner} sees every change.', s: 13, c: p.mu, lh: 1.4),
          ),
        ] else
          Padding(padding: const EdgeInsets.all(16), child: T('Residents and ${h.owner} keep this list up to date.', s: 13, c: p.mu)),
      ],
    );
  }
}

/// Add or change a thing: what, where, how many, working or not.
class AmenityAddSheet extends StatelessWidget {
  const AmenityAddSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.amDraft;
    if (d == null) return const SizedBox();
    final rs = s.roomsOnFloor(d.hid, d.floor);
    final allOn = rs.isNotEmpty && rs.every((r) => d.rooms.contains(r.n));
    Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: T(t, w: 800, s: 13));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('1 · What is it?'),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 24) / 5;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in amenityKinds)
                    Tap(
                      key: ValueKey('amKind-${k.$1}'),
                      onTap: () => s.pickAmenityKind(k.$1),
                      child: Semantics(
                        label: k.$2,
                        selected: d.kind == k.$1,
                        child: Container(
                          width: w,
                          constraints: const BoxConstraints(minHeight: 70),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          decoration: box(bg: d.kind == k.$1 ? p.ab : transparent, w: d.kind == k.$1 ? 2 : 1, c: d.kind == k.$1 ? p.ac : p.dv),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Ic(k.$3, size: 18, color: p.tx),
                              const SizedBox(height: 4),
                              T(const {'washer': 'Washer', 'ro': 'RO', 'cooler': 'Cooler', 'stove': 'Stove', 'iron': 'Iron', 'wifi': 'Wi-Fi', 'drying': 'Drying', 'shoes': 'Shoe rack'}[k.$1] ?? k.$2, s: 12, w: 800, align: TextAlign.center, lh: 1.15),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (d.kind == 'other') ...[
            const SizedBox(height: 10),
            Field(key: const ValueKey('amName'), value: d.name, placeholder: 'What is it? e.g. Table tennis', onChanged: (v) => s.update(() => d.name = v)),
          ],
          const SizedBox(height: 14),
          label('2 · Where?'),
          Seg(opts: const [('floor', 'On the floor'), ('washroom', 'In room washroom'), ('room', 'In the room')], cur: d.place, onPick: s.setAmenityPlace, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), center: true, dividers: true),
          if (d.inRooms) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in rs) ChipBtn('${r.n}', key: ValueKey('amRoom-${r.n}'), on: d.rooms.contains(r.n), onTap: () => s.toggleAmenityRoom(r.n)),
                ChipBtn('All rooms on this floor', on: allOn, onTap: s.allAmenityRooms),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: T(d.inRooms ? '3 · How many in each?' : '3 · How many?', w: 800, s: 13)),
              Container(
                decoration: box(w: 2, c: p.tx),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tap(key: const ValueKey('amMinus'), onTap: () => s.update(() => d.qty = (d.qty - 1).clamp(1, 20)), child: const SizedBox(width: 48, height: 46, child: Center(child: T('−', w: 800, s: 20)))),
                    Container(width: 48, height: 46, alignment: Alignment.center, decoration: BoxDecoration(border: Border(left: bs(2, p.tx), right: bs(2, p.tx))), child: T('${d.qty}', w: 800, s: 18)),
                    Tap(key: const ValueKey('amPlus'), onTap: () => s.update(() => d.qty = (d.qty + 1).clamp(1, 20)), child: const SizedBox(width: 48, height: 46, child: Center(child: T('+', w: 800, s: 20)))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          label('4 · Is it working?'),
          Seg(opts: const [('yes', 'Working'), ('no', 'Not working')], cur: d.working ? 'yes' : 'no', onPick: (v) => s.update(() => d.working = v == 'yes'), pad: const EdgeInsets.all(10), fs: 14, center: true, dividers: true),
          const SizedBox(height: 14),
          Cta(s.amenitySaveLabel(d), key: const ValueKey('amSave'), icon: 'check', height: 54, px: 16, fs: 15, opacity: d.kind.isEmpty ? .4 : 1, onTap: s.saveAmenityDraft),
          if (d.key != null || d.id != 'new') ...[
            const SizedBox(height: 8),
            Tap(
              key: const ValueKey('amRemove'),
              onTap: () => s.removeAmenity(s.amenities.firstWhere((a) => a.id == d.id)),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: T('Remove ${d.label}', w: 800, s: 14, c: p.ad)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Owner Layouts → Shared things: floor chips, who changed what, an edit
/// button per thing and "Add a shared thing".
class OwnerSharedThings extends StatelessWidget {
  const OwnerSharedThings({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    final floors = {...floorsOf(s.rooms[hid] ?? const <Room>[]), ...s.amenityFloors(hid)}.toList()..sort();
    final list = s.amenitiesOn(hid, s.amFloor);
    final last = s.lastResidentChange(hid, s.amFloor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in floors)
                ChipBtn(f == 0 ? 'Ground' : 'Floor $f', key: ValueKey('ownFloor-$f'), on: f == s.amFloor, onTap: () => s.update(() {
                  s.amFloor = f;
                  s.amHid = hid;
                })),
            ],
          ),
        ),
        if (last != null)
          Container(
            key: const ValueKey('residentChanged'),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            color: p.sf,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ic('user', size: 20, color: p.tx),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const T('A resident changed this floor', w: 800, s: 14),
                      T('${last.label}${last.working ? '' : ' marked Not working'} · ${dayMon(DateTime.fromMillisecondsSinceEpoch(last.at))}. Keep it, or correct it.', s: 13, c: p.mu, lh: 1.4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Scroll(
            key: ValueKey('ownThings${s.scrollEpoch}'),
            child: Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in list)
                    Container(
                      key: ValueKey('ownThing-${a.id}'),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Container(width: 36, height: 36, color: p.sf, alignment: Alignment.center, child: Ic(amenityIcon(a.kind), size: 20, color: p.tx)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(a.inRooms ? '${a.label} · in room ${a.place == 'washroom' ? 'washrooms' : 'rooms'}' : (a.qty > 1 ? '${a.label} ×${a.qty}' : a.label), w: 800, s: 16),
                                T([if (a.inRooms) a.rooms.join(', '), a.byResident ? 'a resident' : 'you', dayMon(DateTime.fromMillisecondsSinceEpoch(a.at))].join(' · '), s: 13, c: p.mu),
                                // F25: where it is on the floor map.
                                if (!a.inRooms) T(a.placed ? 'On the floor map' : 'Not placed yet', key: ValueKey('ownSpot-${a.id}'), s: 13, w: 600, c: a.placed ? p.mu : p.ad),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tag(a.working ? 'Working' : 'Not working', bg: a.working ? transparent : p.ab, fg: a.working ? p.mu : p.ad),
                          const SizedBox(width: 8),
                          if (!a.inRooms) ...[
                            Tap(
                              key: ValueKey('ownPlace-${a.id}'),
                              onTap: () => s.openPlaceThing(a),
                              child: Semantics(label: 'Place ${a.label} on the floor', child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: Ic('pin', size: 16, color: p.tx))),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Tap(
                            key: ValueKey('ownEdit-${a.id}'),
                            onTap: () => s.openAddAmenity(edit: a),
                            child: Semantics(label: 'Change ${a.label}', child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: Ic('pencil', size: 16, color: p.tx))),
                          ),
                        ],
                      ),
                    ),
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing on this floor yet. Add the fridge, RO, washing machine…', s: 14, c: p.mu)),
                  Padding(padding: const EdgeInsets.all(16), child: T('Broken things also show on Today as a repair.', s: 13, c: p.mu)),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
          child: Cta('Add a shared thing', key: const ValueKey('ownAddThing'), icon: 'plus', height: 54, px: 16, fs: 15, onTap: () => s.openAddAmenity(hid: hid, floor: s.amFloor)),
        ),
      ],
    );
  }
}
