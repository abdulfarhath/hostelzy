import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'layout_map.dart';

/// Working / Not working switch.
class _WorkSwitch extends StatelessWidget {
  const _WorkSwitch({required this.ok, required this.onPick});
  final bool ok;
  final ValueChanged<bool> onPick;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    Widget half(String t, bool on, Color bg, Color fg, bool v) => Expanded(
      child: Tap(
        onTap: () => onPick(v),
        child: Container(height: 36, alignment: Alignment.center, color: on ? bg : null, child: T(t, s: 12, w: 600, c: on ? fg : p.tx)),
      ),
    );
    return Container(
      width: 176,
      decoration: box(w: 2, c: p.tx),
      child: Row(children: [half('Working', ok, p.tx, p.bg, true), half('Not working', !ok, p.ad, p.ai, false)]),
    );
  }
}

String _itemName(RoomLayout l, LItem i) {
  final b = l.beds.keys.where((k) => (l.bedRect(k).center - l.itemRect(i).center).distance <= fanReach).firstOrNull;
  return switch (i.kind) {
    'fan' => 'Fan ${i.id.substring(3)}${b != null ? ' · over bed $b' : ''}',
    'ac' => 'AC unit · ${l.itemRect(i).center.dx > l.w / 2 ? 'right' : 'left'} wall',
    _ => 'Window · faces ${i.facing}',
  };
}

/// Board 4: the owner checks a layout, marks items, approves it.
class OwnerLayoutScreen extends StatelessWidget {
  const OwnerLayoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final l = s.layoutOf(h.id, room.n);
    // F24 item 11: an "Ask Hostelzy to draw it" request, and the team's
    // drawing once it comes back (board oShapeBack).
    final q = s.shapeReqFor(h.id, room.n);
    final drawn = q == null ? null : s.drawnLayout(q);
    final (stText, stBg, stFg) = drawn != null
        ? ('Hostelzy drew a new version · check and publish', p.tx, p.bg)
        : q != null
        ? ('Asked Hostelzy · ${hoursLeft(q.due, DateTime.now().millisecondsSinceEpoch)} · done within 48 h', p.ab, p.ad)
        : l == null
        ? ('No layout yet', p.ab, p.ad)
        : l.pending
        ? ('Hostelzy drew a new version · check and publish', p.ab, p.ad)
        : !l.live
        ? ('Draft · tenants see “Layout coming soon”', p.sf, p.tx)
        : l.published != null
        ? ('Live · you have changes not published', p.sf, p.tx)
        : ('Live for tenants', p.tx, p.bg);
    String at(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${dayMon(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    final shown = drawn ?? l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Beds', title: 'Room ${room.label} layout', size: 26))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oLayout${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 10,
                children: [
                  Container(
                    key: const ValueKey('layoutStatus'),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    color: stBg,
                    child: Row(children: [Expanded(child: T(stText, s: 13, w: 800, c: stFg)), if (l != null && drawn == null) T('v${l.version} · drawn ${l.drawn}', s: 13, w: 600, c: stFg)]),
                  ),
                  // F13 S4, F24 4a: residents answered "Is the room layout right? No".
                  if (l != null && l.disputes > 0)
                    Container(
                      key: const ValueKey('layoutDisputed'),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: box(bg: p.ab, w: 2, c: p.ad),
                      child: VGap(gap: 2, children: [
                        T('Residents say this layout is wrong', w: 800, s: 14, c: p.ad),
                        T('${l.disputes} ${l.disputes == 1 ? 'resident' : 'residents'} answered “No” in the 30-day review. Check the room, fix the layout and publish it again.', s: 13, lh: 1.4),
                      ]),
                    ),
                  if (shown == null)
                    q != null
                        ? LayoutEmpty(icon: 'pencil', head: 'Hostelzy is drawing it', body: 'You asked on ${at(q.at)}${q.w > 0 && q.h > 0 ? ' · ${q.shape} · ${q.w.round()} × ${q.h.round()} ft' : ''}. Done within 48 hours; you get a notification.')
                        : const LayoutEmpty(icon: 'pencil', head: 'No layout yet', body: 'Draw it yourself in a few minutes and publish it, or ask the Hostelzy team to draw it for you, free.')
                  else if (drawn != null) ...[
                    LayoutMap(l: drawn, room: room, mode: 'plain', fan: true, ac: true),
                    Row(
                      children: [
                        Expanded(child: T('${drawn.w.round()} × ${drawn.h.round()} ft · ${drawn.shape} · ${room.share} sharing', s: 12, c: p.mu)),
                        T('v${drawn.version} · drawn by Hostelzy, ${drawn.drawn}', s: 12, c: p.mu),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      color: p.sf,
                      child: T('You asked on ${at(q!.at)}.${q.sentAt != null ? ' Drawn in ${((q.sentAt! - q.at) / 3600000).ceil()} hours.' : ''} Check the beds, fan and window, then publish. Tenants see it straight away.', s: 13, lh: 1.45),
                    ),
                  ] else ...[
                    LayoutMap(l: l!, room: room, mode: 'plain', fan: true, ac: true),
                    if (q != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        color: p.sf,
                        child: T('You asked Hostelzy on ${at(q.at)}${q.note.isEmpty ? '' : ': “${q.note}”'}. Tenants keep seeing this layout until you publish the new one.', s: 13, lh: 1.45),
                      ),
                    Container(
                      decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final i in l.items.where((i) => const ['fan', 'ac', 'window'].contains(i.kind)))
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        T(_itemName(l, i), w: 800, s: 14),
                                        T(i.working ? 'Shown to tenants' : (i.kind == 'ac' ? 'Tenants see “AC under repair”. A complaint is raised.' : 'Tenants see “Not working”. A complaint is raised.'), s: 11, c: i.working ? p.mu : p.ad, lh: 1.3),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _WorkSwitch(ok: i.working, onPick: (v) => s.setWorking(l, i, v)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
        // F18 (DECISIONS 2026-10-02): the owner edits and publishes; Hostelzy helps if asked.
        if (drawn != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: VGap(
              gap: 8,
              children: [
                Cta('Publish v${drawn.version}', icon: 'check', key: const ValueKey('publishDrawn'), height: 54, px: 16, fs: 15, onTap: () => s.publishDrawn(q!)),
                OutlineCta('Ask Hostelzy to change it', icon: 'msg', onTap: () => s.openShapeRequest(shape: q!.shape)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: l == null
                      ? Cta('Create a layout', icon: 'pencil', height: 52, px: 16, fs: 15, onTap: () => s.ownerLayout(room.n, create: true))
                      : l.pending
                      ? Cta('Publish v${l.version}', icon: 'check', height: 52, px: 16, fs: 15, onTap: () => s.approveLayout(l))
                      : Cta('Edit layout', icon: 'pencil', height: 52, px: 16, fs: 15, onTap: () => s.openLayout(room.n, editor: true, owner: true)),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: s.openLayoutRequest,
                  child: Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('Ask Hostelzy', w: 800, s: 15)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Owner Today: every 3 months, confirm the room layouts still match (F12).
class ConfirmLayoutsCard extends StatelessWidget {
  const ConfirmLayoutsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final days = s.layoutConfirmed[s.ownHid];
    if (days == null || days < layoutConfirmEvery || s.layouts[s.ownHid] == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 8,
        children: [
          const T('Do your room layouts still match?', w: 800, s: 17),
          T('Last confirmed $days days ago. Every 3 months, check that beds, fans, AC and windows are still where the layouts show them.', s: 13, c: p.mu, lh: 1.4),
          Row(
            children: [
              Expanded(child: Cta('All still correct', icon: 'check', height: 46, px: 12, fs: 14, onTap: () => s.confirmLayouts(s.ownHid))),
              const SizedBox(width: 8),
              Cta('Review', icon: 'chev', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.go('oLayouts')),
            ],
          ),
        ],
      ),
    );
  }
}

/// F24 board oShape: a shape tile's little outline.
class ShapeIconPainter extends CustomPainter {
  ShapeIconPainter(this.shape, this.color);
  final String shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final box = Rect.fromLTRB(4, 4, size.width - 4, size.height - 4);
    if (shape == 'Custom') {
      canvas.drawPath(
        Path()
          ..moveTo(box.left + 4, box.top + 2)
          ..cubicTo(box.left + 14, box.top - 4, box.right, box.top + 6, box.right - 2, box.center.dy)
          ..cubicTo(box.right - 4, box.bottom, box.left + 10, box.bottom + 2, box.left, box.center.dy + 4)
          ..close(),
        ink,
      );
      return;
    }
    final o = shapeOutline(shape, box.width, box.height);
    if (o == null) return canvas.drawRect(box, ink);
    canvas.drawPath(Path()..addPolygon([for (final q in o) q + box.topLeft], true), ink);
  }

  @override
  bool shouldRepaint(ShapeIconPainter o) => o.shape != shape || o.color != color;
}

/// F18 design "Create": a room with no layout yet.
class CreateLayoutScreen extends StatelessWidget {
  const CreateLayoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final src = s.copySource(room.n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Room ${room.label}', title: 'Create a layout', size: 28))]),
        ),
        Expanded(
          child: Scroll(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 14,
                children: [
                  T('Room ${room.label} has no layout yet. Tenants see “Layout coming soon” until you publish one.', s: 14, c: p.mu, lh: 1.5),
                  // F24 item 11 (board oShape): pick the room's shape first.
                  const T('Room shape', w: 800, s: 13),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: .95,
                    children: [
                      for (final sh in layoutShapes)
                        Tap(
                          key: ValueKey('shape-$sh'),
                          // Custom: the Hostelzy team draws it (48 h).
                          onTap: () => sh == 'Custom' ? s.openShapeRequest(shape: 'Custom') : s.update(() => s.clShape = sh),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: box(bg: s.clShape == sh ? p.ab : transparent, w: s.clShape == sh ? 2 : 1, c: s.clShape == sh ? p.ac : p.dv),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 44, height: 36, child: CustomPaint(painter: ShapeIconPainter(sh, p.tx))),
                                const SizedBox(height: 4),
                                FittedBox(fit: BoxFit.scaleDown, child: T(sh, s: 12, w: 800, nowrap: true)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: VGap(gap: 6, children: [const T('Width (ft)', w: 800, s: 13), Field(key: const ValueKey('clLen'), value: s.clLen, numeric: true, onChanged: (v) => s.update(() => s.clLen = v.replaceAll(RegExp(r'\D'), '')))])),
                      const SizedBox(width: 10),
                      Expanded(child: VGap(gap: 6, children: [const T('Length (ft)', w: 800, s: 13), Field(key: const ValueKey('clWid'), value: s.clWid, numeric: true, onChanged: (v) => s.update(() => s.clWid = v.replaceAll(RegExp(r'\D'), '')))])),
                    ],
                  ),
                  if (src != null)
                    Tap(
                      onTap: () => s.createLayout(from: src.n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: box(w: 2, c: p.tx),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Copy Room ${src.label} instead', w: 800, s: 14), T('Same shape and items · you can change them after', w: 600, s: 11, c: p.mu)])),
                            const Ic('copy', size: 18),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    color: p.sf,
                    child: VGap(
                      gap: 6,
                      children: [
                        Rich([sp(context, 'Not on the list, or no time? ', w: 800), sp(context, 'Tap Custom. Send a photo and a sketch; the Hostelzy team draws it within 48 hours, free.')], s: 13, lh: 1.45),
                        Tap(key: const ValueKey('askHostelzy'), onTap: () => s.openShapeRequest(shape: s.clShape), child: T('Ask Hostelzy to draw it', w: 800, s: 14, c: p.ad)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta(s.clShape == 'Rectangle' ? 'Start drawing' : 'Start drawing · ${s.clShape}', key: const ValueKey('startDrawing'), height: 54, px: 16, fs: 15, onTap: s.createLayout),
        ),
      ],
    );
  }
}

/// F18 design "Published": the owner's layout is live, no approval needed.
class LayoutPublishedScreen extends StatelessWidget {
  const LayoutPublishedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final room = s.rooms[h.id]!.firstWhere((r) => r.n == s.lRoom);
    final l = s.layoutOf(h.id, room.n)!;
    final u = s.lastPublish?.room == room.n ? s.lastPublish : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Room ${room.label}', title: 'Live for tenants'))]),
        ),
        Expanded(
          child: Scroll(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VGap(
                gap: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: p.tx,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Ic('check', size: 20, color: p.bg),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Published just now', w: 800, s: 14, c: p.bg), T('Tenants see this layout in the Room tab right away. Bed IDs and prices didn’t change.', s: 13, c: p.bg, lh: 1.4)])),
                      ],
                    ),
                  ),
                  LayoutMap(l: l, room: room, mode: 'plain', fan: true, ac: true),
                  KV('Version', 'v${l.version} · by you · ${l.drawn}', keyWidth: 90),
                  if (u?.snap != null) KV('Before', 'v${u!.version}', keyWidth: 90),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 8,
            children: [
              Cta('Done', icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.update(() {
                s.screen = 'oLayouts';
                s.hist = s.hist.where((x) => x != 'aLayout' && x != 'oLayout' && x != 'oLayouts').toList();
              })),
              OutlineCta('Edit again', icon: 'pencil', onTap: () => s.openLayout(room.n, editor: true, owner: true)),
              if (u != null) Tap(onTap: () => s.undoPublish(l), child: T(u.snap == null ? 'Undo publish · hide it again' : 'Undo publish · go back to v${u.version}', w: 800, s: 13, c: p.tx)),
            ],
          ),
        ),
      ],
    );
  }
}
