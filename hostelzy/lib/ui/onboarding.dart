import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F14 onboarding: the Add hostel wizard in Hostelzy admin mode (boards 1–6),
// the Visited badge and availability on the hostel page (7), add a manager
// (8), the hostel switcher (9), "Still N free beds?" (10) and the founder's
// onboarding tracker (11, one column on the phone).

/// F22 Area 4: the header of every Hostelzy team tool (back, kicker, title).
class TeamHead extends StatelessWidget {
  const TeamHead({super.key, required this.kicker, required this.title, this.onBack});
  final String kicker, title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [BackBtn(onTap: onBack ?? s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title, gap: 2))],
      ),
    );
  }
}

/// F22 Area 4: the small status label on a team row (11px capitals).
class StatusTag extends StatelessWidget {
  const StatusTag(this.text, {super.key, this.hot = false, this.bg, this.fg});
  final String text;
  final bool hot;
  final Color? bg, fg;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final b = bg ?? (hot ? p.ab : transparent);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
      decoration: box(bg: b, w: 1, c: bg ?? (hot ? p.ab : p.dv)),
      child: T(text, s: 11, w: 800, ls: .05, lh: 1.3, upper: true, nowrap: true, c: fg ?? (hot ? p.ad : p.mu)),
    );
  }
}

Widget _label(String t) => T(t, w: 800, s: 13);

Widget _field(String label, String v, ValueChanged<String> on, {bool numeric = false, String? ph}) => VGap(
  gap: 6,
  children: [
    _label(label),
    Field(value: v, numeric: numeric, placeholder: ph, onChanged: on),
  ],
);

/// Boards 1–6: Add hostel, one step at a time.
class AddHostelScreen extends StatelessWidget {
  const AddHostelScreen({super.key});
  static const titles = ['Basics', 'Rooms, floor by floor', 'Rate card', 'Photos', 'Current residents', 'Ready to go live?'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    final i = s.addStep - 1;
    final body = switch (s.addStep) {
      1 => const _Basics(),
      2 => const _Rooms(),
      3 => const _Rates(),
      4 => const _Photos(),
      5 => const _Residents(),
      _ => const _GoLive(),
    };
    final left = s.goLiveLeft;
    final (cta, ok) = switch (s.addStep) {
      1 => ('Next: rooms', d.name.trim().isNotEmpty),
      2 => ('Next: rates · ${d.roomCount} rooms, ${d.bedCount} beds', d.roomCount > 0),
      3 => ('Next: photos', true),
      4 => ('Next: residents', true),
      5 => ('Next: go live', true),
      _ => (left.isEmpty ? 'Go live' : 'Go live · ${left.length} ${left.length == 1 ? 'thing' : 'things'} left', left.isEmpty),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeamHead(kicker: 'Add hostel · step ${s.addStep} of 6', title: titles[i], onBack: () => s.addStep > 1 ? s.update(() => s.addStep--) : s.back()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (var k = 0; k < 6; k++) ...[
                if (k > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 6,
                    color: k < i
                        ? p.tx
                        : k == i
                        ? p.ac
                        : p.tk,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('aAdd${s.addStep}'),
            child: Padding(padding: const EdgeInsets.only(bottom: 16), child: body),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta(
            cta,
            icon: 'arrow',
            height: 54,
            px: 16,
            fs: 15,
            opacity: ok || s.addStep == 6 ? 1 : .4,
            onTap: () {
              if (s.addStep == 6) return s.goLive();
              if (!ok) return s.toastMsg(s.addStep == 1 ? 'Add the hostel name.' : 'Add at least one room.');
              s.update(() => s.addStep++);
            },
          ),
        ),
      ],
    );
  }
}

/// Board 1 (F22 Area 4): name, who it's for, area, gate and food, the map pin.
class _Basics extends StatelessWidget {
  const _Basics();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VGap(
        gap: 12,
        children: [
          _field('Hostel name', d.name, (v) => s.update(() => d.name = v)),
          _label('For'),
          Seg(opts: const [('Men', 'Men'), ('Women', 'Women'), ('Co-living', 'Co-living')], cur: d.gender, onPick: (v) => s.update(() => d.gender = v), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), center: true),
          _label('Area'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final a in areaSpot.keys) ChipBtn(a, on: d.area == a, onTap: () => s.update(() => d.area = a))],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Gate closes', d.gate, (v) => s.update(() => d.gate = v))),
              const SizedBox(width: 8),
              Expanded(
                child: VGap(
                  gap: 6,
                  children: [
                    _label('Food'),
                    // One of three answers: each tap moves to the next.
                    Tap(
                      key: const ValueKey('aAddFood'),
                      onTap: () => s.update(() => d.food = foodOpts[(foodOpts.indexOf(d.food) + 1) % foodOpts.length]),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 46),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: box(w: 2, c: p.tx),
                        child: Row(children: [Expanded(child: T(d.food, s: 15)), Ic('chevD', size: 18, color: p.mu)]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Cta(
            d.pinChecked ? 'Map pin · checked at the gate' : 'Map pin · check it at the gate',
            icon: d.pinChecked ? 'check' : 'pin',
            height: 48,
            px: 16,
            fs: 14,
            bg: transparent,
            fg: p.tx,
            border: p.tx,
            onTap: () => s.update(() => d.pinChecked = !d.pinChecked),
          ),
          _label('Amenities'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final a in amenityList) ChipBtn(a, on: d.amenities.contains(a), onTap: () => s.update(() => d.amenities.contains(a) ? d.amenities.remove(a) : d.amenities.add(a)))],
          ),
        ],
      ),
    );
  }
}

/// Board 2 (F22 Area 4): rooms floor by floor. Each floor is a card of room
/// chips; tap a chip to rename it, change sharing or AC, or remove it.
class _Rooms extends StatefulWidget {
  const _Rooms();
  @override
  State<_Rooms> createState() => _RoomsState();
}

class _RoomsState extends State<_Rooms> {
  DraftRoom? sel;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    String suggest(int fi, int k) => fi == 0 ? 'G0${k + 1}' : '${fi * 100 + k + 1}';
    void addRoom(DraftFloor f, int fi) => s.update(() {
      var k = f.rooms.length;
      while (d.allRooms.any((r) => r.label == suggest(fi, k))) {
        k++;
      }
      f.rooms.add(DraftRoom(suggest(fi, k), d.defShare, d.defAc));
    });
    String renumber(String label, int fi) => RegExp(r'^\d+$').hasMatch(label) ? '${int.parse(label) + 100}' : '$label-$fi';

    Widget chip(DraftRoom r) {
      final on = identical(sel, r);
      return Tap(
        key: ValueKey('aRoom-${r.label}'),
        onTap: () => setState(() => sel = on ? null : r),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: box(bg: on ? p.tx : null, w: 1, c: on ? p.tx : p.dv),
          child: Rich([sp(context, r.label, w: 800), sp(context, ' · ${r.share}${r.ac ? ' AC' : ''}')], s: 13, c: on ? p.bg : p.tx),
        ),
      );
    }

    Widget editor(DraftFloor f, DraftRoom r) => Container(
      padding: const EdgeInsets.all(10),
      color: p.sf,
      child: VGap(
        gap: 8,
        children: [
          Row(
            children: [
              Expanded(child: T('Room number', s: 13, w: 800)),
              Tap(
                onTap: () => s.update(() {
                  f.rooms.remove(r);
                  sel = null;
                }),
                child: T('Remove room', s: 13, w: 800, c: p.ad),
              ),
            ],
          ),
          Field(key: ValueKey(r), value: r.label, onChanged: (v) => s.update(() => r.label = v.trim().toUpperCase())),
          Seg(opts: [for (var n = 1; n <= 4; n++) ('$n', '$n sharing')], cur: '${r.share}', onPick: (v) => s.update(() => r.share = int.parse(v)), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), fs: 13, center: true),
          Seg(opts: const [('non', 'Non-AC'), ('ac', 'AC')], cur: r.ac ? 'ac' : 'non', onPick: (v) => s.update(() => r.ac = v == 'ac'), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), fs: 13, center: true),
        ],
      ),
    );

    final cards = <Widget>[];
    for (var fi = 0; fi < d.floors.length; fi++) {
      final f = d.floors[fi];
      final open = f.rooms.where((r) => identical(r, sel)).firstOrNull;
      cards.add(
        Container(
          key: ValueKey('aFloor-$fi'),
          padding: const EdgeInsets.all(10),
          decoration: box(w: 2, c: p.tx),
          child: VGap(
            gap: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T(f.name, w: 800, s: 15),
                        if (f.note.isNotEmpty && !f.noBeds) T(f.note, s: 12, c: p.mu),
                      ],
                    ),
                  ),
                  if (!f.noBeds) Tap(onTap: () => addRoom(f, fi), child: T('+ Room', s: 13, w: 800, c: p.ad)),
                ],
              ),
              if (f.noBeds)
                Wrap(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: box(w: 1, c: p.dv),
                      child: Rich([sp(context, f.note.isNotEmpty ? f.note : 'No rooms', w: 800), sp(context, ' · no beds')], s: 13),
                    ),
                  ],
                )
              else if (f.rooms.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: [for (final r in f.rooms) chip(r)]),
              if (open != null) editor(f, open),
              if (f.noBeds || f.rooms.isEmpty)
                Tap(
                  onTap: () => s.update(() => f.noBeds = !f.noBeds),
                  child: Row(
                    children: [
                      Expanded(child: T(f.noBeds ? 'No beds here · hidden from tenants' : 'Has beds', s: 13, c: p.mu)),
                      Container(
                        width: 44,
                        height: 24,
                        padding: const EdgeInsets.all(2),
                        alignment: f.noBeds ? Alignment.centerRight : Alignment.centerLeft,
                        decoration: box(bg: f.noBeds ? p.tx : null, w: 2, c: p.tx),
                        child: Container(width: 16, height: 16, color: f.noBeds ? p.bg : p.tx),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final top = d.floors.lastWhere((f) => !f.noBeds && f.rooms.isNotEmpty, orElse: () => d.floors.first);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VGap(
        gap: 12,
        children: [
          T('Floors can have different rooms. Tap a room to change sharing or AC.', s: 14, c: p.mu, lh: 1.4),
          ...cards,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Cta(
                  'Copy floor above',
                  icon: 'copy',
                  height: 44,
                  px: 12,
                  fs: 13,
                  bg: transparent,
                  fg: p.tx,
                  border: p.tx,
                  onTap: () {
                    if (top.noBeds || top.rooms.isEmpty) return s.toastMsg('Add rooms to a floor first.');
                    final fi = d.floors.length;
                    s.update(() => d.floors.add(DraftFloor(floorName(fi), [for (final r in top.rooms) r.copy()..label = renumber(r.label, fi)], note: 'Copied from ${top.name.split(' ').first}')));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Cta('Add floor', icon: 'plus', height: 44, px: 12, fs: 13, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.update(() => d.floors.add(DraftFloor(floorName(d.floors.length), [])))),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Tap(
                  onTap: () => s.update(() {
                    if (d.defAc) {
                      d.defAc = false;
                      d.defShare = d.defShare == 4 ? 2 : d.defShare + 1;
                    } else {
                      d.defAc = true;
                    }
                  }),
                  child: Rich([sp(context, 'New rooms: ${d.defShare} sharing · ${d.defAc ? 'AC' : 'Non-AC'} · '), sp(context, 'Change', w: 800, c: p.ad)], s: 13, c: p.mu),
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                onTap: () => d.floors.any((f) => f.name == 'Terrace') ? s.toastMsg('There is already a terrace.') : s.update(() => d.floors.add(DraftFloor('Terrace', []))),
                child: T('+ Terrace', s: 13, w: 800, c: p.ad),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Board 3: rate card for the room types used, plus money terms.
class _Rates extends StatelessWidget {
  const _Rates();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    final missing = d.missingPrices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 6), child: Kicker('Used in this hostel · per month')),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final k in d.types)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Expanded(child: Row(children: [T('${k.substring(k.length - 1)} sharing', w: 800, s: 14), const SizedBox(width: 6), RoomTypeTagSmall(k.startsWith('ac'))])),
                      SizedBox(
                        width: 120,
                        child: Container(
                          decoration: missing.contains(k) ? box(w: 2, c: p.ad) : null,
                          child: Field(key: ValueKey('rate$k'), value: (d.prices[k] ?? 0) > 0 ? '${d.prices[k]}' : '', numeric: true, placeholder: 'Price needed', height: 40, onChanged: (v) => s.update(() => d.prices[k] = int.tryParse(v.replaceAll(RegExp(r'\D'), '')) ?? 0)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final k in missing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: T('${d.allRooms.where((r) => rateKey(r.ac, r.share) == k).map((r) => 'Room ${r.label}').join(', ')}: ${d.typeLabel(k)}${k.startsWith('ac') ? '' : ' Non-AC'}. Add its price.', s: 12, w: 600, c: p.ad),
          ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 6), child: Kicker('Money terms (F02)')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: VGap(
            gap: 10,
            children: [
              Row(
                children: [
                  Expanded(child: _field('Advance (₹)', '${d.advance}', (v) => s.update(() => d.advance = int.tryParse(v) ?? 0), numeric: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Kept on leaving (₹)', '${d.kept}', (v) => s.update(() => d.kept = int.tryParse(v) ?? 0), numeric: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Notice (days)', '${d.notice}', (v) => s.update(() => d.notice = int.tryParse(v) ?? 0), numeric: true)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VGap(
                      gap: 6,
                      children: [
                        _label('Fee due on'),
                        Seg(opts: const [('join', 'Joining'), ('first', '1st')], cur: d.dueOnJoining ? 'join' : 'first', onPick: (v) => s.update(() => d.dueOnJoining = v == 'join'), center: true),
                      ],
                    ),
                  ),
                ],
              ),
              OutlineCta('Pick deals now (optional, up to 3)', icon: 'chev', height: 46, fs: 14, onTap: () => s.toastMsg('Deals can be picked in Manage → Deals once the hostel is live.')),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small AC / Non-AC tag for the rate card rows.
class RoomTypeTagSmall extends StatelessWidget {
  const RoomTypeTagSmall(this.ac, {super.key});
  final bool ac;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
      decoration: box(w: 1, c: ac ? p.tx : p.dv),
      child: T(ac ? 'AC' : 'Non-AC', s: 11, w: 800, ls: .05, upper: true, c: ac ? p.tx : p.mu),
    );
  }
}

/// Board 4: photo checklist (photos go to the hostel's Drive folder until
/// the backend stores them) and the sketches for room layouts.
class _Photos extends StatelessWidget {
  const _Photos();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    final slots = d.photoSlots;
    final rows = <Widget>[];
    for (var k = 0; k < slots.length; k += 3) {
      if (k > 0) rows.add(const SizedBox(height: 6));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: 6),
              Expanded(
                child: k + j < slots.length
                    ? () {
                        final name = slots[k + j];
                        final on = d.photos.contains(name);
                        final tile = SizedBox(
                          height: 86,
                          child: Stack(
                            children: [
                              if (on)
                                Positioned.fill(
                                  child: Stripes(step: 6, border: Border.all(color: p.hl)),
                                )
                              else
                                Center(child: Ic('qr', size: 22, color: p.mu)),
                              if (on)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    color: p.tx,
                                    alignment: Alignment.center,
                                    child: Ic('check', size: 12, color: p.bg),
                                  ),
                                ),
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4), child: T(name, s: 10, w: 800)),
                              ),
                            ],
                          ),
                        );
                        return Tap(
                          onTap: () => s.update(() => on ? d.photos.remove(name) : d.photos.add(name)),
                          child: on ? tile : Dashed(color: p.dv, child: tile),
                        );
                      }()
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: T('Taken by Hostelzy, in daylight, from the door. Tick each one once it is in the hostel’s Drive folder.', s: 13, c: p.mu, lh: 1.4)),
              const SizedBox(width: 8),
              T('${d.photoCount} of ${HostelDraft.minPhotos} minimum', w: 800, s: 14, c: d.photoCount >= HostelDraft.minPhotos ? p.tx : p.ad),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: rows),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('For room layouts (F12)'), T('${d.sketches.length} of ${d.types.length} types', s: 12, w: 800)]),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            children: [
              for (final k in d.types)
                Tap(
                  onTap: () => s.update(() => d.sketches.contains(k) ? d.sketches.remove(k) : d.sketches.add(k)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T('${k.substring(k.length - 1)} sharing · ${k.startsWith('ac') ? 'AC' : 'Non-AC'}', w: 800, s: 15),
                              T('Sketch + measurements', s: 12, c: p.mu),
                            ],
                          ),
                        ),
                        d.sketches.contains(k) ? Tag('Done', bg: p.tx, fg: p.bg) : T('+ Add', s: 12, w: 800, c: p.ad),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Board 5: current residents, grandfathered as Before Hostelzy (F06).
class _Residents extends StatelessWidget {
  const _Residents();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Seg(opts: const [('one', 'Type one'), ('paste', 'Paste a list')], cur: s.resPasteMode ? 'paste' : 'one', onPick: (v) => s.update(() => s.resPasteMode = v == 'paste'), center: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: s.resPasteMode
              ? VGap(
                  gap: 8,
                  children: [
                    Field(key: const ValueKey('resPaste'), value: s.resPaste, maxLines: 4, height: null, placeholder: 'One per line: name, phone, bed\nRavi Kumar, 90000 00001, 101-A', onChanged: (v) => s.update(() => s.resPaste = v)),
                    OutlineCta('Add these', icon: 'plus', height: 46, fs: 14, onTap: s.pasteDraftResidents),
                  ],
                )
              : VGap(
                  gap: 8,
                  children: [
                    Field(key: const ValueKey('resName'), value: s.resName, placeholder: 'Name', onChanged: (v) => s.update(() => s.resName = v)),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Field(key: const ValueKey('resPhone'), value: s.resPhone, numeric: true, placeholder: 'Phone', onChanged: (v) => s.update(() => s.resPhone = v)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Field(key: const ValueKey('resBed'), value: s.resBed, placeholder: 'Bed 101-A', onChanged: (v) => s.update(() => s.resBed = v)),
                        ),
                      ],
                    ),
                    OutlineCta('Add resident', icon: 'plus', height: 46, fs: 14, onTap: s.addDraftResident),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Kicker('${d.takenBeds} of ${d.bedCount} beds have a resident'),
              const SizedBox(height: 2),
              T('The owner adds the rest within 3 days.', s: 12, c: p.mu),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            children: [
              for (final r in d.residents)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T(r.name, w: 800, s: 15),
                            T('${phoneSpaced(r.phone)} · bed ${r.bed}', s: 12, c: p.mu),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                        decoration: box(w: 1, c: p.dv),
                        child: T('Joined before Hostelzy', s: 11, w: 800, ls: .05, upper: true, c: p.mu),
                      ),
                    ],
                  ),
                ),
              if (d.residents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: T('No residents added yet.', s: 14, c: p.mu),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: T('Residents here before Hostelzy count as “Joined before Hostelzy”. They confirm their stay in the app by joining with your invite code.', s: 12, c: p.mu, lh: 1.45),
        ),
      ],
    );
  }
}

/// Board 6: go-live checklist. "Go live" stays locked until every item is
/// done; open items are red. F22 Area 4: the board's rows and footnote.
class _GoLive extends StatelessWidget {
  const _GoLive();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    final taken = d.takenBeds;
    final missingPhotos = d.photoSlots.where((x) => !d.photos.contains(x)).take(2).map((x) => x[0].toLowerCase() + x.substring(1)).join(' and ');
    final items = <(bool, String, String, VoidCallback?)>[
      if (d.floors.every((f) => f.noBeds || f.rooms.isEmpty)) (false, 'At least one room with beds', 'Add rooms on step 2', () => s.update(() => s.addStep = 2)),
      (d.ownerVerified, 'Owner’s phone rang', d.ownerVerified ? 'Checked by a call · ${phoneSpaced(d.ownerPhone)} · ${d.ownerName}' : 'Call the owner’s number on the visit, below', null),
      (d.fairPlay, 'Fair Play rules: owner agreed', d.fairPlay ? 'Read together on ${dayMon(appToday)}' : 'Read the rules out loud together, then tick here', () => s.update(() => d.fairPlay = !d.fairPlay)),
      (d.photoCount >= HostelDraft.minPhotos, '${HostelDraft.minPhotos} photos', d.photoCount >= HostelDraft.minPhotos ? '${d.photoCount} of ${HostelDraft.minPhotos}' : '${d.photoCount} of ${HostelDraft.minPhotos} · add $missingPhotos', () => s.update(() => s.addStep = 4)),
      (d.missingPrices.isEmpty, 'Every room type has a price', d.missingPrices.isEmpty ? '${d.types.length} of ${d.types.length}' : '${d.missingPrices.map(d.typeLabel).join(', ')} has no price', () => s.update(() => s.addStep = 3)),
      (d.bedsChecked, 'Bed status checked on the visit', '$taken taken · ${d.bedCount - taken} free · 0 on hold', () => s.update(() => d.bedsChecked = !d.bedsChecked)),
      (d.pinChecked, 'Map pin checked at the gate', d.pinChecked ? 'Done' : 'Check the pin at the gate', () => s.update(() => d.pinChecked = !d.pinChecked)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (ok, t, sub, on) in items)
            Tap(
              onTap: on,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: box(bg: ok ? p.tx : null, w: 2, c: ok ? p.tx : p.ad),
                      child: ok ? Ic('check', size: 16, color: p.bg) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T(t, w: 800, s: 15),
                          T(sub, s: 13, c: ok ? p.mu : p.ad, lh: 1.35),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!d.ownerVerified)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: VGap(
                gap: 8,
                children: [
                  Field(key: const ValueKey('ownerPhone'), value: d.ownerPhone, numeric: true, placeholder: 'Owner phone', onChanged: (v) => s.update(() => d.ownerPhone = v.replaceAll(RegExp(r'\D'), ''))),
                  // No SMS codes yet (DECISIONS 2026-10-02): call it on the visit.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Cta('Call it', icon: 'phone', height: 46, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: () => d.ownerPhone.length != 10 ? s.toastMsg('Enter the 10-digit phone.') : s.call(d.ownerPhone))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Cta('The owner’s phone rang', icon: 'check', height: 46, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: () {
                          if (d.ownerPhone.length != 10) return s.toastMsg('Enter the 10-digit phone.');
                          s.update(() => d.ownerVerified = true);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          T('Optional: ${d.residents.length} residents added', s: 13, c: p.mu),
          const SizedBox(height: 12),
          T('Goes live with “Visited by Hostelzy · ${dayMon(appToday)} ${appToday.year}”. The 30-day free trial starts today.', s: 13, c: p.mu, lh: 1.45),
        ],
      ),
    );
  }
}


/// Board 7: Visited by Hostelzy + availability, on the hostel page.
class VisitedBlock extends StatelessWidget {
  const VisitedBlock(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final v = s.visited[h.id];
    final free = s.rooms[h.id]!.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free').length);
    final days = s.confirmed[h.id];
    final stale = s.stale(h.id);
    return VGap(
      gap: 8,
      children: [
        if (v != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: box(w: 2, c: p.tx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ic('shieldOk', size: 20, color: p.tx),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('Visited by Hostelzy · $v', w: 800, s: 15),
                      T('Photos taken by our team · beds and prices checked in person', s: 12, c: p.mu, lh: 1.35),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          color: stale ? p.ab : p.sf,
          child: stale
              ? Rich([sp(context, 'Availability not confirmed', w: 800, c: p.ad), sp(context, ' · owner hasn’t confirmed for ${days ?? staleAfterDays} days. Ask before you visit.')], s: 13, lh: 1.4)
              : Rich(
                  [
                    sp(context, '$free free ${free == 1 ? 'bed' : 'beds'}', w: 800),
                    sp(
                      context,
                      ' · confirmed by the owner ${days == 0
                          ? 'today'
                          : days == 1
                          ? 'yesterday'
                          : '$days days ago'}',
                    ),
                  ],
                  s: 13,
                  lh: 1.4,
                ),
        ),
      ],
    );
  }
}

/// Board 10: "Still N free beds?" on owner Today, every 3 days.
class FreeBedsCard extends StatelessWidget {
  const FreeBedsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    if (!s.needsConfirm(hid)) return const SizedBox();
    final free = s.rooms[hid]!.expand((r) => r.beds).where((b) => b.state == 'free').toList();
    final n = free.length;
    final days = s.confirmed[hid]!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 8,
        children: [
          T('Still $n free ${n == 1 ? 'bed' : 'beds'}?', w: 800, s: 18),
          T('Last confirmed $days days ago. Fresh beds rank higher.', s: 13, c: p.mu),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in free)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: box(w: 1, c: p.tx),
                  child: T(b.id, s: 12, w: 800),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Cta('Yes, all $n free', icon: 'check', height: 46, px: 12, fs: 14, onTap: () => s.confirmBeds(hid)),
              ),
              const SizedBox(width: 8),
              Cta('Update', icon: 'chev', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.tab('oBeds')),
            ],
          ),
          T('Not confirmed for $staleAfterDays days: tenants see “Availability not confirmed” and you rank lower.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

/// Board 9: hostel switcher (sheet from the hostel name on Today).
class SwitchSheet extends StatelessWidget {
  const SwitchSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in s.ownerHostels)
          () {
            final h = hostelById(id);
            final rs = s.rooms[id]!;
            final beds = rs.fold<int>(0, (a, r) => a + r.beds.length);
            final free = rs.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free').length);
            final trial = id != 'anjani';
            return Tap(
              onTap: () => s.switchHostel(id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: id == s.ownHid ? p.sf : null,
                  border: Border(bottom: bs(1, p.hl), left: id == s.ownHid ? bs(4, p.ac) : BorderSide.none),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T(h.name, w: 800, s: 16),
                          T('${h.area} · $beds beds · $free free', s: 12, c: p.mu),
                        ],
                      ),
                    ),
                    trial ? Tag('Trial · 30 days', bg: p.ab, fg: p.ad) : Tag('Live', bg: p.tx, fg: p.bg),
                  ],
                ),
              ),
            );
          }(),
        Tap(
          onTap: () => s.toastMsg('Message the Hostelzy team on WhatsApp to book a visit.'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: Row(
              children: [
                Ic('plus', size: 18, color: p.ad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('Add another hostel', w: 800, s: 15, c: p.ad),
                      T('The Hostelzy team visits to set it up', s: 12, c: p.mu),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: T('Each hostel has its own plan and its own managers.', s: 12, c: p.mu),
        ),
      ],
    );
  }
}

/// Board 8, F22 Area 3 `oTeam`: you and your managers, what managers can't
/// see, and Add a manager.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    Widget pill(String t, {required Color bg, required Color fg, required Color bd}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: box(bg: bg, w: 1, c: bd),
      child: T(t, s: 11, w: 800, ls: .05, lh: 1.3, upper: true, c: fg, nowrap: true),
    );
    Widget row(String name, String sub, Widget tag) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        children: [
          Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: T(initials(name).toUpperCase(), s: 13, w: 800)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [T(name, w: 800, s: 16), const SizedBox(height: 1), T(sub, s: 13, c: p.mu)],
            ),
          ),
          const SizedBox(width: 12),
          tag,
        ],
      ),
    );
    final owner = ownerPhones[h.id] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: '${h.name} · Manage', title: 'Team', gap: 2)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('oTeam${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row(h.owner, owner.isEmpty ? 'Owner' : 'Owner · ${phoneSpaced(owner)}', pill('You', bg: p.tx, fg: p.bg, bd: p.tx)),
                  for (final m in s.managers) row(m.name, 'Manager · ${phoneSpaced(m.phone)}', m.joined ? pill('Active', bg: transparent, fg: p.tx, bd: p.tx) : pill('Invite pending', bg: p.ab, fg: p.ad, bd: p.ab)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: T('Managers run beds, residents, enquiries, complaints and food. Managers can’t see your plan, deals, rates or Fair Play notices.', s: 14, c: p.mu, lh: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta('Add a manager', icon: 'userPlus', height: 54, px: 16, fs: 15, onTap: () => s.update(() => s.sheet = 'manager')),
        ),
      ],
    );
  }
}

/// Board 8 sheet: add a manager.
class ManagerSheet extends StatelessWidget {
  const ManagerSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Widget perm(String t, bool on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Ic(on ? 'check' : 'lock', size: 16, color: on ? p.tx : p.mu),
          const SizedBox(width: 8),
          T(t, s: 14, c: on ? p.tx : p.mu),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          _field('Name', s.mgrName, (v) => s.update(() => s.mgrName = v), ph: 'Prakash'),
          _field('WhatsApp number', s.mgrPhone, (v) => s.update(() => s.mgrPhone = v), numeric: true, ph: '90000 00002'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Kicker('Manager can'),
                    const SizedBox(height: 4),
                    for (final t in const ['Beds and holds', 'Residents', 'Enquiries', 'Complaints', 'Food menu']) perm(t, true),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Kicker('Only you'),
                    const SizedBox(height: 4),
                    for (final t in const ['Plan and billing', 'Deals', 'Rate card', 'Fair Play notices']) perm(t, false),
                  ],
                ),
              ),
            ],
          ),
          Cta('Send invite', icon: 'msg', height: 54, px: 16, fs: 15, onTap: s.addManager),
          T('${s.mgrName.trim().isEmpty ? 'They' : s.mgrName.trim()} join${s.mgrName.trim().isEmpty ? '' : 's'} by signing in with this number (OTP).', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// Board 11: the founder's onboarding tracker. F22 Area 4 (aTrack): a seg by
/// stage, then one row per hostel with its next-step button, and Add hostel.
class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  /// The tabs, and the stages (onboardStages) each one holds.
  static const tabs = [('Lead', [0]), ('Visited', [1]), ('Signed up', [2, 3]), ('Live', [4, 5, 6])];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final inCl = s.leads.where((l) => s.trackCl < 0 || l.cluster == s.trackCl).toList();
    final live = s.leads.where((l) => l.stage >= 4).length;
    final tab = s.trackTab.clamp(0, tabs.length - 1);
    final list = inCl.where((l) => tabs[tab].$2.contains(l.stage)).toList()..sort((a, b) => a.stage.compareTo(b.stage));
    String lower(String t) => t.isEmpty ? t : t[0].toLowerCase() + t.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeamHead(kicker: 'Hostelzy team · live $live of 20 this month', title: 'Onboarding'),
        Seg(
          opts: [for (var i = 0; i < tabs.length; i++) ('$i', '${tabs[i].$1} ${inCl.where((l) => tabs[i].$2.contains(l.stage)).length}')],
          cur: '$tab',
          onPick: (v) => s.update(() => s.trackTab = int.parse(v)),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          center: true,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Scroll(
          horizontal: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                ChipBtn('All areas', on: s.trackCl < 0, pad: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), onTap: () => s.update(() => s.trackCl = -1)),
                for (var i = 0; i < clusters.length; i++) ...[const SizedBox(width: 6), ChipBtn(clusters[i], on: s.trackCl == i, pad: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), onTap: () => s.update(() => s.trackCl = i))],
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('aTrack${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final l in list)
                    Container(
                      key: ValueKey('aLead-${l.name}'),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(l.name, w: 800, s: 16, lh: 1.25),
                                T([l.area, if (tabs[tab].$2.length > 1) onboardStages[l.stage], 'next: ${lower(l.next)}'].join(' · '), s: 13, c: p.mu, lh: 1.4),
                              ],
                            ),
                          ),
                          if (l.stage < onboardStages.length - 1) ...[
                            const SizedBox(width: 10),
                            Tap(
                              onTap: () => l.stage == 3 && l.hid == null ? s.openAddHostel() : s.update(() => l.stage++),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 40),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                alignment: Alignment.center,
                                decoration: box(w: 2, c: p.tx),
                                child: T(l.stage == 3 && l.hid == null ? 'Add hostel' : onboardStages[l.stage + 1], s: 13, w: 800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('No hostels at this stage.', s: 14, c: p.mu)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta('Add hostel', icon: 'plus', height: 54, px: 16, fs: 15, onTap: s.openAddHostel),
        ),
      ],
    );
  }
}
