import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../team/team_tracker_screens.dart';

Widget _label(String t) => T(t, w: 800, s: 13);

Widget labeledField(String label, String v, ValueChanged<String> on, {bool numeric = false, String? ph}) => VGap(
  gap: 6,
  children: [
    _label(label),
    Field(value: v, numeric: numeric, placeholder: ph, onChanged: on),
  ],
);

/// Boards 1–6: Add hostel, one step at a time.
class AddHostelScreen extends StatelessWidget {
  const AddHostelScreen({super.key});
  static const titles = ['Basics', 'Rooms, floor by floor', 'Rate card', 'Photos', 'Current residents', 'Owner account', 'Ready to go live?'];

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
      6 => const _OwnerAccount(),
      _ => const _GoLive(),
    };
    final left = s.goLiveLeft;
    final (cta, ok) = switch (s.addStep) {
      1 => ('Next: rooms', d.name.trim().isNotEmpty),
      2 => ('Next: rates · ${d.roomCount} rooms, ${d.bedCount} beds', d.roomCount > 0),
      3 => ('Next: photos', true),
      4 => ('Next: residents', true),
      5 => ('Next: owner account', true),
      6 => ('Next: go live', true),
      _ => (left.isEmpty ? 'Go live' : 'Go live · ${left.length} ${left.length == 1 ? 'thing' : 'things'} left', left.isEmpty),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeamHead(kicker: 'Add hostel · step ${s.addStep} of 7', title: titles[i], onBack: () => s.addStep > 1 ? s.update(() => s.addStep--) : s.back()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (var k = 0; k < 7; k++) ...[
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
            height: 54,
            px: 16,
            fs: 15,
            opacity: ok || s.addStep == 7 ? 1 : .4,
            onTap: () {
              if (s.addStep == 7) return s.goLive();
              if (!ok) return s.toastMsg(s.addStep == 1 ? 'Add the hostel name.' : 'Add at least one room.');
              s.nextAddStep();
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
          labeledField('Hostel name', d.name, (v) => s.update(() => d.name = v)),
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
              Expanded(child: labeledField('Gate closes', d.gate, (v) => s.update(() => d.gate = v))),
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
          // F24 Wave 4c: house rules typed on the visit go on the server too.
          labeledField('Visitors', d.visitors, (v) => s.update(() => d.visitors = v), ph: 'Common area only, till 8 pm'),
          // F24 Wave 4c (board `aPin`): the real pin, dropped at the gate.
          Cta(
            d.pin != null ? 'Map pin · dropped at the gate' : 'Map pin · drop it at the gate',
            key: const ValueKey('aAddPin'),
            icon: d.pin != null ? 'check' : 'pin',
            height: 48,
            px: 16,
            fs: 14,
            bg: transparent,
            fg: p.tx,
            border: p.tx,
            onTap: s.openPin,
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
              const Expanded(child: T('Room number', s: 13, w: 800)),
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
          Seg(opts: [for (var n = 1; n <= 4; n++) ('$n', '$n sharing')], cur: '${r.share}', onPick: (v) => s.update(() => r.share = int.parse(v)), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), center: true),
          Seg(opts: const [('non', 'Non-AC'), ('ac', 'AC')], cur: r.ac ? 'ac' : 'non', onPick: (v) => s.update(() => r.ac = v == 'ac'), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), center: true),
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
                  Expanded(child: labeledField('Advance (₹)', '${d.advance}', (v) => s.update(() => d.advance = int.tryParse(v) ?? 0), numeric: true)),
                  const SizedBox(width: 10),
                  Expanded(child: labeledField('Kept on leaving (₹)', '${d.kept}', (v) => s.update(() => d.kept = int.tryParse(v) ?? 0), numeric: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: labeledField('Notice (days)', '${d.notice}', (v) => s.update(() => d.notice = int.tryParse(v) ?? 0), numeric: true)),
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
    // F24: real photos on the server, through the owners' Photos screen.
    if (s.onServer) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: VGap(
          gap: 12,
          children: [
            T('${s.draftPhotos} of ${HostelDraft.minPhotos} photos', key: const ValueKey('draftPhotoCount'), w: 800, s: 22),
            T('Take them on the visit: ${d.photoSlots.join(', ')}.', s: 14, c: p.mu, lh: 1.45),
            Cta('Add photos', key: const ValueKey('draftPhotos'), icon: 'camera', height: 50, px: 14, fs: 15, onTap: s.openDraftPhotos),
            T('They upload to this hostel now; the owner can change them later in Manage › Photos.', s: 12, c: p.mu),
          ],
        ),
      );
    }
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
/// F24 board `aAddOwner` (step 6 of 7): the owner's name and number, and a
/// one-time sign-in link on WhatsApp. Linked once they sign in with it.
class _OwnerAccount extends StatelessWidget {
  const _OwnerAccount();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.draft;
    final first = d.ownerName.trim().isEmpty ? 'The owner' : d.ownerName.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VGap(
        gap: 12,
        children: [
          T('The owner runs ${d.name.trim().isEmpty ? 'the hostel' : d.name.trim()} from their phone: beds, rent, residents and enquiries. They sign in with Google; no password.', s: 14, c: p.mu, lh: 1.45),
          VGap(gap: 6, children: [const T('Owner’s name', w: 800, s: 13), Field(key: const ValueKey('ownerName'), value: d.ownerName, placeholder: 'As tenants will see it', onChanged: (v) => s.update(() => d.ownerName = v))]),
          VGap(gap: 6, children: [const T('Owner’s phone', w: 800, s: 13), Field(key: const ValueKey('ownerPhone6'), value: d.ownerPhone, numeric: true, placeholder: '10 digits', onChanged: (v) => s.update(() => d.ownerPhone = v.replaceAll(RegExp(r'\D'), '')))]),
          // F24 Wave 4c: only when they chat on another number.
          VGap(gap: 6, children: [const T('WhatsApp, if different', w: 800, s: 13), Field(key: const ValueKey('ownerWa6'), value: d.ownerWa, numeric: true, placeholder: 'Same as phone', onChanged: (v) => s.update(() => d.ownerWa = v.replaceAll(RegExp(r'\D'), '')))]),
          Container(
            key: const ValueKey('ownerStatus'),
            padding: const EdgeInsets.all(12),
            decoration: box(w: 2, c: d.ownerLinked ? p.tx : p.dv),
            child: Row(
              children: [
                Container(width: 28, height: 28, alignment: Alignment.center, decoration: box(bg: d.ownerLinked ? p.tx : null, w: 2, c: d.ownerLinked ? p.tx : p.mu), child: d.ownerLinked ? Ic('check', size: 16, color: p.bg) : null),
                const SizedBox(width: 12),
                Expanded(
                  child: VGap(
                    gap: 2,
                    children: [
                      T(d.ownerLinked ? 'Linked' : d.ownerCode.isEmpty ? 'Not linked yet' : 'Link sent · waiting for $first', w: 800, s: 15),
                      T(d.ownerLinked ? '$first runs it from the Hostelzy app.' : 'The link works once, for 7 days.', s: 13, c: p.mu),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!d.ownerLinked) ...[
            Cta(d.ownerCode.isEmpty ? 'Send sign-in link on WhatsApp' : 'Send the link again', key: const ValueKey('ownerLink'), icon: 'msg', height: 50, px: 14, fs: 15, onTap: s.sendOwnerLink),
            if (d.ownerCode.isNotEmpty) OutlineCta('Check again', key: const ValueKey('ownerCheck'), icon: 'check', height: 46, fs: 14, onTap: s.checkOwnerLinked),
          ],
          T('You can go on and come back: go live needs the owner linked.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

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
      (d.ownerLinked, 'Owner account linked', d.ownerLinked ? '${d.ownerName} signs in with Google' : 'Send the sign-in link on step 6', () => s.update(() => s.addStep = 6)),
      (s.draftPhotos >= HostelDraft.minPhotos, '${HostelDraft.minPhotos} photos', s.draftPhotos >= HostelDraft.minPhotos ? '${s.draftPhotos} of ${HostelDraft.minPhotos}' : '${s.draftPhotos} of ${HostelDraft.minPhotos}${s.onServer ? '' : ' · add $missingPhotos'}', () => s.update(() => s.addStep = 4)),
      (d.missingPrices.isEmpty, 'Every room type has a price', d.missingPrices.isEmpty ? '${d.types.length} of ${d.types.length}' : '${d.missingPrices.map(d.typeLabel).join(', ')} has no price', () => s.update(() => s.addStep = 3)),
      (d.bedsChecked, 'Bed status checked on the visit', '$taken taken · ${d.bedCount - taken} free · 0 on hold', () => s.update(() => d.bedsChecked = !d.bedsChecked)),
      (d.pinChecked && d.pin != null, 'Map pin dropped at the gate', d.pin != null ? '${d.pin!.$1.toStringAsFixed(5)}, ${d.pin!.$2.toStringAsFixed(5)}' : 'Drop the pin at the gate', s.openPin),
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
