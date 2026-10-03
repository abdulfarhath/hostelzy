import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../../ui/layout.dart';

// F19 residents fix room layouts: the resident's room (board 1) and editor
// (2, 3), the send, lock and limit sheets (4, 0, 3c), the result (5), the
// owner's Today cards (8), compare (9), reject (10) and approved (11).

String _what(LItem i) => const {'fan': 'Fan', 'ac': 'AC unit', 'window': 'Window', 'door': 'Door', 'wash': 'Washroom', 'pillar': 'Pillar'}[i.kind] ?? i.kind;

/// "18 × 15 ft · 3 sharing · AC"
String _roomLine(RoomLayout l, Room r) => '${l.w.round()} × ${l.h.round()} ft${l.outline == null ? '' : ' · ${l.shape}'} · ${r.share} sharing · ${r.ac ? 'AC' : 'Non-AC'}';

/// Board 1 + 5: a room at the resident's hostel, with "Edit room" and the
/// state of their latest fix for it.
class ResidentRoomScreen extends StatelessWidget {
  const ResidentRoomScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.fixHid);
    final rs = s.rooms[s.fixHid] ?? const <Room>[];
    final room = s.fixRoomOf;
    final l = room == null ? null : s.liveLayout(s.fixHid, room.n);
    final f = room == null ? null : s.myFixFor(s.fixHid, room.n);
    final show = f != null && (f.status == 'pending' || !s.fixSeen.contains(f.id));
    final owner = h.owner.isEmpty ? 'your owner' : h.owner;
    final checked = room == null ? null : s.checkedLabel(s.fixHid, room.n);
    final muted = s.mutedAt(s.fixHid);
    Widget card(List<Widget> kids, {bool green = false}) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: box(bg: green ? p.gb : null, w: 2, c: p.tx),
      child: VGap(gap: 6, children: kids),
    );
    Widget? state;
    if (show && f.status == 'pending') {
      state = card([
        T('Waiting for $owner', w: 800, s: 15),
        T('Sent ${dayMon(DateTime.fromMillisecondsSinceEpoch(f.at))}${f.note.isEmpty ? '' : ' · “${f.note}”'} Tenants still see the current layout.', s: 13, c: p.mu, lh: 1.45),
        Kicker('Your suggestion · only you and $owner see it'),
        OutlineCta('Change my suggestion', icon: 'pencil', height: 46, fs: 14, onTap: () => s.changeFix(f)),
        OutlineCta('Withdraw it', icon: 'x', height: 46, fs: 14, onTap: () => s.withdrawFix(f)),
      ]);
    } else if (show && f.status == 'approved') {
      state = card(green: true, [
        T('$owner approved your fix', w: 800, s: 15),
        T('It’s live for tenants now${checked == null ? '' : ', marked “$checked”'}. Thanks for helping.', s: 13, lh: 1.45),
        Cta('Done', icon: 'check', height: 46, px: 14, fs: 14, onTap: () => s.update(() => s.fixSeen.add(f.id))),
      ]);
    } else if (show && f.status == 'rejected') {
      state = card([
        T('$owner didn’t approve it', w: 800, s: 15),
        T('${f.reason == null ? '' : '“${f.reason}” '}You can send a new fix any time.', s: 13, c: p.mu, lh: 1.45),
        OutlineCta('Edit room again', icon: 'pencil', height: 46, fs: 14, onTap: () {
          s.update(() => s.fixSeen.add(f.id));
          s.openFixEditor(s.fixHid, room!.n);
        }),
        OutlineCta('Talk to $owner on WhatsApp', icon: 'msg', height: 46, fs: 14, onTap: () => s.openWA(owner, 'Hi $owner, about my layout fix for room ${room!.label}.', phone: ownerWa(s.fixHid))),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: '${h.name}${s.myRoomLabel.isEmpty ? '' : ' · you live in ${s.myRoomLabel}'}', title: room == null ? 'Rooms' : 'Room ${room.label}', size: 28)),
            ],
          ),
        ),
        Scroll(
          horizontal: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              for (final r in rs) ...[ChipBtn(r.label, on: r.n == room?.n, onTap: () => s.update(() => s.fixRoom = r.n)), const SizedBox(width: 6)],
            ]),
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rRoom${s.scrollEpoch}${room?.n}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (room == null || l == null)
                  const Padding(padding: EdgeInsets.all(16), child: LayoutEmpty(icon: 'pencil', head: 'No layout yet', body: 'The owner draws this room first. Then you can fix it.'))
                else ...[
                  // F19 extras: tap an item for a quick fix.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // F24 item 10: rings only with the layer on (F12).
                    child: LayoutMap(l: l, room: room, mode: 'plain', fan: s.showFan, ac: s.showAc, onSelect: muted ? null : (id) {
                      final i = l.items.where((x) => x.id == id).firstOrNull;
                      if (i != null) s.openQuickFix('${_what(i)}${wallOf(i.rect, l.w, l.h) == null ? '' : ' · ${wallOf(i.rect, l.w, l.h)} wall'}');
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: T(_roomLine(l, room), s: 12, c: p.mu)),
                        const SizedBox(width: 8),
                        Flexible(child: T(checked ?? 'Layout v${l.version}${h.owner.isEmpty ? '' : ' · by ${h.owner}'}, ${l.drawn}', s: 12, c: checked == null ? p.mu : p.tx, w: checked == null ? 400 : 800, align: TextAlign.right)),
                      ],
                    ),
                  ),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: LayerChips(l: l)),
                  if (muted)
                    card([
                      const T('Suggestions are off for this hostel', w: 800, s: 15),
                      T('You can still see every room here.', s: 13, c: p.mu, lh: 1.45),
                    ])
                  else
                    state ??
                        card([
                          const T('Something in the wrong place?', w: 800, s: 15),
                          T('You live in ${h.name}, so you can fix any room here. Tap an item for a quick fix, or move things in the editor and send it to $owner.', s: 13, c: p.mu, lh: 1.45),
                        ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Ic('user', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('Residents of ${h.name} can see and fix every room here.', s: 12, c: p.mu, lh: 1.45))],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (room != null && l != null && !muted && !(show && f.status == 'pending'))
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Cta('Edit room', icon: 'pencil', height: 54, px: 16, fs: 15, onTap: () => s.openFixEditor(s.fixHid, room.n)),
          ),
      ],
    );
  }
}

/// Boards 2 and 3: the owner's editor in suggestion mode.
class FixEditorScreen extends StatelessWidget {
  const FixEditorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final l = s.fixLayout;
    final room = s.fixRoomOf;
    if (l == null || room == null) return const SizedBox();
    final sel = s.edSel;
    final selItem = sel == null || sel.startsWith('bed:') ? null : l.items.where((i) => i.id == sel).firstOrNull;
    final selBed = sel != null && sel.startsWith('bed:') ? room.beds.where((b) => b.letter == sel.substring(4)).firstOrNull : null;
    final taken = selBed != null && (selBed.state == 'booked' || s.residents.any((x) => x.bed == selBed.id));
    final selName = selItem != null
        ? '${_what(selItem)}${wallOf(selItem.rect, l.w, l.h) == null ? '' : ' · ${wallOf(selItem.rect, l.w, l.h)} wall'}'
        : selBed != null
        ? 'Bed ${selBed.letter}${taken ? ' · has a resident' : ''}'
        : 'Tap a bed or an item';
    final checks = s.fixChecks(l, room);
    final ok = checks.every((c) => c.$1);
    Widget sq(String icon, VoidCallback on, {String? label, Key? key, double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Tap(
        key: key,
        onTap: on,
        child: Container(
          height: label == null ? 36 : 40,
          constraints: const BoxConstraints(minWidth: 36),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
          alignment: Alignment.center,
          decoration: box(w: 1, c: p.dv),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Ic(icon, size: 16, color: p.tx), if (label != null) ...[const SizedBox(width: 6), T(label, s: 13, w: 600)]]),
        ),
      ),
    );
    Widget section(String t, List<Widget> kids) => VGap(gap: 6, children: [Kicker(t), ...kids]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Row(
            children: [
              BackBtn(onTap: s.leaveFixEditor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Rich([sp(context, 'Edit room · '), sp(context, 'Room ${room.label}', c: p.ac)], w: 800, s: 15),
                    T(s.fixTry ? 'You don’t live here · leaving discards your try' : 'Suggestion${s.myRoomLabel.isEmpty ? '' : ' · you live in ${s.myRoomLabel}'} · draft saved on this phone', s: 12, c: p.mu, ell: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (s.fixTry)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            decoration: BoxDecoration(color: p.sf, border: Border(bottom: bs(1, p.hl))),
            child: Row(children: [Ic('eye', size: 16, color: p.tx), const SizedBox(width: 8), const Expanded(child: T('Try mode · play freely, nothing is saved', s: 13, w: 800))]),
          )
        else
          Container(
            color: p.tx,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            child: Row(children: [Ic('lock', size: 16, color: p.bg), const SizedBox(width: 8), Expanded(child: T('Only you see this until you send it', s: 13, w: 800, c: p.bg))]),
          ),
        Container(
          color: p.sf,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: LayoutMap(l: l, room: room, mode: 'edit', fan: true, ac: true, selected: sel, onSelect: s.edSelect, onDrag: (id, d) => s.edDrag(l, id, d), onDragEnd: s.edDragEnd),
        ),
        Container(
          color: p.sf,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(child: T(selName, s: 14, w: 800, c: sel == null ? p.mu : p.tx, ell: true)),
              sq('back', () => s.edNudge(l, -1, 0), key: const ValueKey('fix-left')),
              const SizedBox(width: 4),
              Transform.rotate(angle: math.pi / 2, child: sq('back', () => s.edNudge(l, 0, -1), key: const ValueKey('fix-up'))),
              const SizedBox(width: 4),
              Transform.rotate(angle: -math.pi / 2, child: sq('back', () => s.edNudge(l, 0, 1), key: const ValueKey('fix-down'))),
              const SizedBox(width: 4),
              sq('chev', () => s.edNudge(l, 1, 0), key: const ValueKey('fix-right')),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
          child: Row(
            children: [
              sq('swap', () => s.edRotate(l), label: 'Turn'),
              const SizedBox(width: 6),
              sq('back', s.resetFix, label: 'Reset'),
              const Spacer(),
              sq('back', () => s.edUndo(l), label: 'Undo', opacity: s.canUndo ? 1 : .35),
              const SizedBox(width: 6),
              sq('arrow', () => s.edRedo(l), label: 'Redo', opacity: s.canRedo ? 1 : .35),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rFix${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: VGap(
                gap: 12,
                children: [
                  section('Status · tap an item', [
                    if (selItem != null && const ['fan', 'ac', 'window'].contains(selItem.kind))
                      Seg(opts: const [('ok', 'Working'), ('bad', 'Not working')], cur: selItem.working ? 'ok' : 'bad', onPick: (v) => s.fixSetWorking(selItem, v == 'ok'), center: true)
                    else
                      T('Tap a fan, the AC or a window to mark it working or not.', s: 12, c: p.mu),
                  ]),
                  section('Room size · ${l.w.round()} × ${l.h.round()} ft', [
                    T('Wrong size? Change the width or length by 1 ft.', s: 12, c: p.mu),
                    Row(
                      children: [
                        Expanded(child: Row(children: [const T('Width', s: 13), const Spacer(), sq('x', () => s.edResize(l, -1, 0), label: '−1'), const SizedBox(width: 6), sq('plus', () => s.edResize(l, 1, 0), label: '+1')])),
                        const SizedBox(width: 16),
                        Expanded(child: Row(children: [const T('Length', s: 13), const Spacer(), sq('x', () => s.edResize(l, 0, -1), label: '−1'), const SizedBox(width: 6), sq('plus', () => s.edResize(l, 0, 1), label: '+1')])),
                      ],
                    ),
                  ]),
                  section('Checks before sending', [
                    for (final (good, t) in checks) Row(children: [Ic(good ? 'check' : 'warn', size: 14, color: good ? p.gn : p.ad), const SizedBox(width: 8), Expanded(child: T(t, s: 13, c: good ? p.tx : p.ad, w: good ? 400 : 800))]),
                  ]),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: s.fixTry
              ? OutlineCta('Send · residents only', icon: 'lock', height: 54, onTap: s.openSendFix)
              : Cta('Send to owner', height: 54, px: 16, fs: 15, opacity: ok ? 1 : .4, onTap: s.openSendFix),
        ),
      ],
    );
  }
}

/// Board 0: "Edit room" for someone who doesn't live here.
class FixLockSheet extends StatelessWidget {
  const FixLockSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.fixHid);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          Align(alignment: Alignment.centerLeft, child: Container(width: 56, height: 56, color: p.sf, alignment: Alignment.center, child: const Ic('lock', size: 26))),
          T('Only residents of ${h.name} can fix room layouts', w: 800, s: 22, lh: 1.15),
          T('Stay here to help others see the real room.', s: 15, c: p.mu, lh: 1.5),
          Cta('Book a bed', height: 54, px: 16, fs: 15, onTap: () => s.update(() {
            s.sheet = null;
            s.hid = s.fixHid;
          })),
          OutlineCta('See beds', icon: 'bed', onTap: () {
            s.update(() {
              s.sheet = null;
              s.hid = s.fixHid;
            });
            s.openPicker();
          }),
          Center(child: Rich([sp(context, 'Already staying here? '), sp(context, 'Ask your owner for your invite code.', w: 800, c: p.tx)], s: 13, c: p.mu, align: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Board 3c: 3 fixes are waiting already.
class FixLimitSheet extends StatelessWidget {
  const FixLimitSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.fixHid);
    final waiting = s.myWaiting(s.fixHid);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('You have ${waiting.length} fixes waiting at ${h.name}', w: 800, s: 20, lh: 1.2),
          T('That’s the most at one time. Send this one once ${h.owner} answers one of them, or change one that’s waiting.', s: 14, c: p.mu, lh: 1.45),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              children: [
                for (final f in waiting)
                  Tap(
                    onTap: () => s.changeFix(f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Expanded(child: VGap(gap: 2, children: [T('Room ${f.room}', w: 800, s: 14), T('Sent ${dayMon(DateTime.fromMillisecondsSinceEpoch(f.at))}', s: 12, c: p.mu)])),
                          T('Waiting', s: 12, w: 800, c: p.ad),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          OutlineCta('Keep my draft for later', icon: 'check', onTap: () => s.update(() => s.sheet = null)),
        ],
      ),
    );
  }
}

/// Board 4: what changed, an optional note, and Send.
class FixSendSheet extends StatelessWidget {
  const FixSendSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final l = s.fixLayout, live = s.liveLayout(s.fixHid, s.fixRoom);
    if (l == null || live == null) return const SizedBox();
    final owner = hostelById(s.fixHid).owner;
    final diff = layoutDiff(live.snap(), l.snap());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              children: [
                for (final (what, change) in diff.lines)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(children: [Expanded(child: T(what, w: 800, s: 14)), T(change, s: 13, c: p.ad, w: 600)]),
                  ),
              ],
            ),
          ),
          T('A note for $owner (optional)', w: 800, s: 13),
          Field(value: s.fixNote, onChanged: (v) => s.update(() => s.fixNote = v), placeholder: 'The cupboard is on the left wall, next to the window.', maxLines: 3, height: null),
          FixPhotoRow(owner: owner),
          T('$owner sees your name${s.myRoomLabel.isEmpty ? '' : ' and that you live in ${s.myRoomLabel}'}. Tenants never see who sent it.', s: 12, c: p.mu, lh: 1.45),
          Cta('Send to owner', height: 54, px: 16, fs: 15, onTap: s.sendFix),
        ],
      ),
    );
  }
}

/// Board 8: owner Today, residents' fixes waiting. F19 extras: a Broken quick
/// fix is a repair card (Start work / Not broken); other quick fixes are
/// noted (Got it / Not right) and change no layout.
class OwnerFixCards extends StatelessWidget {
  const OwnerFixCards({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = s.fixesWaiting;
    if (list.isEmpty) return const SizedBox();
    final repairs = list.where((f) => f.broken).toList();
    final fixes = list.where((f) => !f.broken).toList();
    String from(LayoutFix f) => [f.author, if (f.authorBed.isNotEmpty) 'lives in ${f.authorBed}', if (f.since.isNotEmpty) 'resident since ${f.since}', ago(DateTime.now().millisecondsSinceEpoch - f.at)].join(' · ');
    Widget cardBox(List<Widget> kids) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(gap: 6, children: kids),
    );
    Widget two(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fixes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [const Kicker('Layout fixes from residents'), T('${fixes.length} new', s: 12, w: 800, c: p.ad)],
            ),
          ),
          for (final f in fixes)
            if (f.quick)
              cardBox([
                Row(children: [Expanded(child: T('Quick fix: ${f.quickLine}, Room ${f.room}', w: 800, s: 15)), Tag('New', bg: p.ab, fg: p.ad)]),
                T(from(f), s: 12, c: p.mu),
                if (f.note.isNotEmpty) T('“${f.note}”', s: 14, w: 600, lh: 1.4),
                if (f.photo != null) FixPhotoThumb(f),
                two(
                  Cta('Got it', icon: 'check', height: 44, px: 12, fs: 14, onTap: () => s.ackQuickFix(f, true)),
                  OutlineCta('Not right', icon: 'x', height: 44, px: 12, fs: 14, onTap: () => s.ackQuickFix(f, false)),
                ),
              ])
            else
              cardBox([
                Row(children: [Expanded(child: T('Layout fix for Room ${f.room}', w: 800, s: 15)), Tag('New', bg: p.ab, fg: p.ad)]),
                T(from(f), s: 12, c: p.mu),
                if (f.note.isNotEmpty) T('“${f.note}”', s: 14, w: 600, lh: 1.4),
                Cta('Compare and decide', height: 46, px: 14, fs: 14, onTap: () => s.openFix(f)),
              ]),
        ],
        for (final f in repairs) ...[
          const SizedBox(height: 10),
          cardBox([
            Row(children: [Expanded(child: T('Broken: ${f.item}, Room ${f.room}', w: 800, s: 15)), Tag('Repair', bg: p.ab, fg: p.ad)]),
            T(['From a resident’s quick fix', if (f.note.isNotEmpty) '“${f.note}”', if (f.photo != null) '1 photo'].join(' · '), s: 12, c: p.mu),
            if (f.photo != null) FixPhotoThumb(f),
            two(
              Cta('Start work', icon: 'wrench', height: 44, px: 12, fs: 14, onTap: () => s.setRepair(f, 'working')),
              OutlineCta('Not broken', icon: 'x', height: 44, px: 12, fs: 14, onTap: () => s.setRepair(f, 'not_broken')),
            ),
          ]),
        ],
      ],
    );
  }
}

/// The fix photo, loaded on this phone or from the private bucket.
class FixPhotoThumb extends StatelessWidget {
  const FixPhotoThumb(this.f, {super.key, this.size = 96});
  final LayoutFix f;
  final double size;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: FutureBuilder<ImageProvider?>(
        future: s.fixPhotoOf(f),
        builder: (context, snap) => Container(
          width: size,
          height: size * .75,
          decoration: box(bg: p.sf, w: 1, c: p.hl),
          child: snap.data == null ? Center(child: Ic('camera', size: 18, color: p.mu)) : Image(image: snap.data!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// "1 photo (optional)": add or remove the photo for a fix.
class FixPhotoRow extends StatelessWidget {
  const FixPhotoRow({super.key, required this.owner});
  final String owner;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ph = s.fixPhoto;
    return Row(
      children: [
        Tap(
          key: const ValueKey('fixPhoto'),
          onTap: ph == null ? s.pickFixPhoto : () => s.update(() => s.fixPhoto = null),
          child: Container(
            width: 64,
            height: 48,
            decoration: box(bg: p.sf, w: 2, c: p.tx),
            child: ph == null ? const Center(child: Ic('camera', size: 20)) : Image.memory(ph, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T(ph == null ? '1 photo (optional)' : '1 photo · tap to remove', w: 800, s: 13),
              T('Only $owner and the Hostelzy team see it.', s: 12, c: p.mu),
            ],
          ),
        ),
      ],
    );
  }
}

/// F19 extras (design `QuickFix`): what's wrong with one item, a word, a photo.
class QuickFixSheet extends StatelessWidget {
  const QuickFixSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final owner = hostelById(s.fixHid).owner.isEmpty ? 'your owner' : hostelById(s.fixHid).owner;
    final name = s.qfItem.split(' · ').first;
    final opts = [
      ('wrong_place', 'arrow', 'Wrong place', 'It’s somewhere else in the room'),
      ('missing', 'x', 'Missing', 'There’s no ${lowerName(name)} in this room'),
      ('broken', 'wrench', 'Broken', 'Also goes to $owner as a repair'),
      ('not_here', 'warn', 'Not in this room', 'Take it off the layout'),
    ];
    final probe = LayoutFix(id: '', hid: '', room: 0, snap: emptySnap, at: 0, kind: 'quick', issue: s.qfIssue, item: name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, icon, t, sub) in opts)
          Tap(
            key: ValueKey('qf-$k'),
            onTap: () => s.update(() => s.qfIssue = k),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: s.qfIssue == k ? p.sf : null, border: Border(bottom: bs(1, p.hl))),
              child: Row(
                children: [
                  Container(width: 36, height: 36, alignment: Alignment.center, decoration: box(w: s.qfIssue == k ? 2 : 1, c: s.qfIssue == k ? p.tx : p.dv), child: Ic(icon, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(t, w: 800, s: 15), T(sub, s: 12, c: p.mu)])),
                  Ic('chev', size: 16, color: p.mu),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: VGap(
            gap: 10,
            children: [
              Field(value: s.qfNote, onChanged: (v) => s.qfNote = v, placeholder: 'Add a word (optional): “AC doesn’t cool”'),
              Row(
                children: [
                  Expanded(child: Cta(s.qfIssue == null ? 'Pick what’s wrong' : 'Send: ${probe.quickLine}', height: 54, px: 16, fs: 15, opacity: s.qfIssue == null ? .4 : 1, onTap: s.sendQuickFix)),
                  const SizedBox(width: 8),
                  Tap(
                    key: const ValueKey('qfPhoto'),
                    onTap: s.fixPhoto == null ? s.pickFixPhoto : () => s.update(() => s.fixPhoto = null),
                    child: Container(width: 54, height: 54, decoration: box(w: 2, c: p.tx), child: s.fixPhoto == null ? const Center(child: Ic('camera', size: 20)) : Image.memory(s.fixPhoto!, fit: BoxFit.cover)),
                  ),
                ],
              ),
              T(s.fixPhoto == null ? 'Bigger change? Close this and move things in the editor.' : '1 photo · only $owner and the Hostelzy team see it. Tap it to remove.', s: 12, c: p.mu),
            ],
          ),
        ),
      ],
    );
  }
}

/// F19 extras (design `Mute`): turn off a resident's suggestions.
class FixMuteSheet extends StatelessWidget {
  const FixMuteSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final f = s.openFixItem;
    if (f == null) return const SizedBox();
    final first = f.author.split(' ').first;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          T('You won’t get $first’s layout fixes or notifications. Waiting ones are closed. $first isn’t told who muted them; they see “Suggestions are off for this hostel”.', s: 15, c: p.mu, lh: 1.5),
          Cta('Mute $first’s suggestions', icon: 'x', height: 54, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: () => s.muteFixAuthor(f)),
          OutlineCta('Cancel', icon: 'back', onTap: () => s.update(() => s.sheet = null)),
          T('Unmute any time in Manage → Residents.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// Board 9: the live layout and the fix side by side, then decide.
class OwnerFixScreen extends StatelessWidget {
  const OwnerFixScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final f = s.openFixItem;
    final room = f == null ? null : s.rooms[f.hid]?.where((r) => r.n == f.room).firstOrNull;
    final live = f == null ? null : s.layoutOf(f.hid, f.room);
    if (f == null || room == null || live == null) return const SizedBox();
    final now = live.forTenants;
    final sug = RoomLayout(hid: f.hid, room: f.room, w: f.snap.w, h: f.snap.h, beds: {}, items: [])..restore(f.snap);
    final diff = layoutDiff(now.snap(), f.snap);
    final first = f.author.split(' ').first;
    Widget side(String t, RoomLayout l, Set<String> marked) => Expanded(
      child: VGap(gap: 6, children: [Kicker(t), LayoutMap(l: l, room: room, mode: 'plain', fan: true, ac: true, marked: marked)]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${hostelById(f.hid).name} · Room ${room.label}', title: 'Layout fix', size: 28))],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oFix${s.scrollEpoch}${f.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VGap(
                gap: 12,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side('Now · v${now.version}', now, const {}), const SizedBox(width: 10), side('Suggested', sug, diff.ids)]),
                  Kicker('What changed · ${diff.lines.length}'),
                  for (final (what, change) in diff.lines) Row(children: [Ic('arrow', size: 14, color: p.ad), const SizedBox(width: 8), Expanded(child: Rich([sp(context, '$what ', w: 800), sp(context, change)], s: 14))]),
                  T('All checks pass. Bed IDs and prices don’t change.', s: 13, c: p.mu),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: p.sf,
                    child: VGap(
                      gap: 4,
                      children: [
                        T([f.author, if (f.authorBed.isNotEmpty) 'lives in ${f.authorBed}'].join(' · '), w: 800, s: 14),
                        if (f.note.isNotEmpty) T('“${f.note}”', s: 14, lh: 1.4),
                        if (f.photo != null) FixPhotoThumb(f, size: 120),
                        T('${f.photo != null ? '1 photo · ' : ''}Sent ${dayMon(DateTime.fromMillisecondsSinceEpoch(f.at))} · only you see who sent it', s: 12, c: p.mu),
                        Tap(key: const ValueKey('muteLink'), onTap: () => s.update(() => s.sheet = 'fixMute'), child: Padding(padding: const EdgeInsets.only(top: 4), child: T('Mute $first’s suggestions', s: 13, w: 800))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: VGap(
            gap: 8,
            children: [
              Cta('Approve & publish', icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.approveFix(f)),
              OutlineCta('Reject', icon: 'x', onTap: () => s.update(() {
                s.fixReason = '';
                s.sheet = 'fixReject';
              })),
              T('Tenants never see that $first sent it.', s: 12, c: p.mu),
            ],
          ),
        ),
      ],
    );
  }
}

/// Board 10: reject with an optional reason the resident sees.
class FixRejectSheet extends StatelessWidget {
  const FixRejectSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final f = s.openFixItem;
    if (f == null) return const SizedBox();
    final first = f.author.split(' ').first;
    const chips = ['It was moved back', 'Not accurate', 'Other'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('Why? (optional, $first sees it)', w: 800, s: 13),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final c in chips) ChipBtn(c, on: s.fixReason == c, onTap: () => s.update(() => s.fixReason = c == 'Other' ? '' : c))]),
          Field(value: s.fixReason, onChanged: (v) => s.update(() => s.fixReason = v), placeholder: 'The cupboard was moved back last week.', maxLines: 3, height: null),
          Cta('Reject the fix', icon: 'x', height: 54, px: 16, fs: 15, onTap: () => s.rejectFix(f)),
          T('The current layout stays live. $first can send a new fix.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// Board 11: approved and live.
class FixDoneScreen extends StatelessWidget {
  const FixDoneScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final l = s.layoutOf(s.ownHid, s.lRoom);
    final f = s.fixes.where((x) => x.hid == s.ownHid && x.room == s.lRoom && x.status == 'approved').lastOrNull;
    final first = f?.author.split(' ').first ?? 'The resident';
    final checked = s.checkedLabel(s.ownHid, s.lRoom);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHead(kicker: '${hostelById(s.ownHid).name} · Room ${s.lRoom}', title: 'Live for tenants', size: 28),
          const SizedBox(height: 6),
          T('Published just now', s: 13, c: p.mu),
          const SizedBox(height: 14),
          T('$first’s fix is live in the Room tab. Bed IDs and prices didn’t change. $first gets a notification.', s: 15, lh: 1.45),
          const SizedBox(height: 14),
          if (l != null) ...[
            KV('Version', 'v${l.version} · fix by a resident · ${dayMon(appToday)}', keyWidth: 80),
            KV('Before', 'v${l.version - 1} · kept in history', keyWidth: 80),
          ],
          if (checked != null) KV('Tenants see', checked, keyWidth: 80),
          const Spacer(),
          Cta('Done', icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.update(() {
            s.screen = 'oToday';
            s.hist = [];
          })),
          const SizedBox(height: 8),
          if (l != null && l.version > 1) OutlineCta('Undo publish · go back to v${l.version - 1}', icon: 'back', onTap: s.undoFixPublish),
        ],
      ),
    );
  }
}
