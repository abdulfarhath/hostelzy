import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'layout_map.dart';

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
