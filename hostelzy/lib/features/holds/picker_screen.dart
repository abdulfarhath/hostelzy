import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../layouts/layout_map.dart';

// ------------------------------------------------------------ picker

/// F26 #8: one floor section per floor; the floor chips scroll to it.
final Map<int, GlobalKey> _floorKeys = {};
GlobalKey _floorKey(int f) => _floorKeys.putIfAbsent(f, () => GlobalKey(debugLabel: 'floor$f'));

void _jumpTo(int f, {bool animate = true}) => WidgetsBinding.instance.addPostFrameCallback((_) {
  final c = _floorKeys[f]?.currentContext;
  if (c == null || !c.mounted) return;
  Scrollable.ensureVisible(c, duration: animate ? const Duration(milliseconds: 250) : Duration.zero);
});

/// The free beds a tenant can take in [rs] (fitting the AC filter [f]).
int _freeIn(Iterable<Room> rs, String f) => rs.where((r) => AppState.fits(r, f)).fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length);

class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final rs = s.rooms[h.id]!;
    final room = rs.where((r) => r.n == s.room).firstOrNull ?? rs[0];
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    final hasSel = sb != null && sb.b != null;
    // F26 #8 (founder): no Plan / Room / Building tabs. Every room's drawn
    // layout in one scroll, grouped by floor; the floor chips jump. A room's
    // name opens it on its own (the Room view, "Floor view" comes back). The
    // Building view lives on the hostel page. Layouts are open to everyone.
    final roomView = s.mode == 'room';
    final floors = floorsOf(rs);
    final cur = floors.contains(s.floor) ? s.floor : floors.first;
    final roomLive = roomView && s.liveLayout(h.id, room.n) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: roomView ? [Kicker('${h.name} · Floor ${room.floor} · ${room.share} sharing', ell: true), T('Room ${room.label}', w: 800, s: 26, lh: 1.1)] : [Kicker(h.name, ell: true), const T('Pick a bed', w: 800, s: 26, lh: 1.1)],
                ),
              ),
            ],
          ),
        ),
        if (!roomView)
          Scroll(
            horizontal: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  for (final f in floors) ...[
                    if (f != floors.first) const SizedBox(width: 6),
                    Tap(
                      key: ValueKey('floor-$f'),
                      onTap: () {
                        s.update(() => s.floor = f);
                        _jumpTo(f);
                      },
                      child: Semantics(
                        selected: f == cur,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: box(bg: f == cur ? p.tx : transparent, w: f == cur ? 2 : 1, c: f == cur ? p.tx : p.dv),
                          child: T('Floor $f', s: 13, w: f == cur ? 800 : 600, c: f == cur ? p.bg : p.tx, nowrap: true),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (h.ac && h.hasNon && !roomView)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(padding: EdgeInsets.only(right: 4), child: Kicker('Room')),
                for (final f in const ['Any', 'AC', 'Non-AC']) ChipBtn(f, on: s.pR == f, onTap: () => s.pickRoomType(f)),
              ],
            ),
          ),
        if (roomView) const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(key: ValueKey('picker${s.scrollEpoch}'), child: roomView ? RoomMode(rooms: rs, room: room) : _AllRooms(rooms: rs)),
          ),
        ),
        // F26 #12: the tenant's room layout → F19 try mode (residents: the fix editor).
        if (roomLive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Cta('Edit this layout', key: const ValueKey('editLayout'), icon: 'pencil', height: 44, fs: 14, onTap: () => s.openFixEditor(h.id, room.n)),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: bs(2, p.tx)),
          ),
          child: roomView ? RoomBar(room: room) : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(hasSel ? 'Bed ${sb.b!.id} · ${fmt(sb.r!.rent)}/mo' : 'No bed picked', w: 800, s: 17, lh: 1.25),
                    T(hasSel ? 'Floor ${sb.r!.floor} · ${sb.b!.spot}' : 'Tap a free bed', s: 12, c: p.mu, ell: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta('Continue', key: const ValueKey('pickContinue'), onTap: () => s.bed == null ? s.toastMsg('Pick a free bed first.') : s.update(() => s.sheet = 'hold'), height: 50, fs: 15, expand: false, opacity: hasSel ? 1 : .4),
            ],
          ),
        ),
      ],
    );
  }
}

/// F26 #8: every floor, every room: its drawn layout (beds, fan, AC,
/// window, door, washroom), or its beds as boxes when it has no layout yet.
class _AllRooms extends StatefulWidget {
  const _AllRooms({required this.rooms});
  final List<Room> rooms;
  @override
  State<_AllRooms> createState() => _AllRoomsState();
}

class _AllRoomsState extends State<_AllRooms> {
  @override
  void initState() {
    super.initState();
    // Opened on a floor further down (the first free bed): show it.
    final s = context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
    final floors = floorsOf(widget.rooms);
    if (floors.isNotEmpty && s.floor != floors.first && floors.contains(s.floor)) _jumpTo(s.floor, animate: false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final rooms = widget.rooms;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in floorsOf(rooms))
            Column(
              key: _floorKey(f),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.only(top: 12), child: Kicker('Floor $f · ${_freeIn(rooms.where((r) => r.floor == f), s.pR)} free')),
                for (final r in rooms.where((r) => r.floor == f)) _RoomCard(hid: s.hid, r: r),
              ],
            ),
          const SizedBox(height: 12),
          const Legend(items: pickerLegend),
          const SizedBox(height: 8),
          T('Hostelzy never shows gates, CCTV, exits or residents’ names on any plan.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.hid, required this.r});
  final String hid;
  final Room r;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final fits = AppState.fits(r, s.pR);
    final l = s.liveLayout(hid, r.n);
    final free = r.beds.where((b) => b.state == 'free' && !b.mine).length;
    final drawn = l == null ? const <Bed>[] : r.beds.where((b) => l.beds.containsKey(b.letter)).toList();
    final loose = r.beds.where((b) => !drawn.contains(b)).toList();
    Widget boxBed(Bed b) {
      final lk = lookOf(p, b, s.bed);
      return Tap(
        key: ValueKey('bed-${b.id}'),
        enabled: fits && lk.can,
        onTap: () => s.pickBed(b),
        child: Semantics(
          label: 'Bed ${b.id}, ${lk.tag}',
          child: BedBox(look: lk.look, width: 54, height: 48, child: Center(child: T(b.letter, w: 800, s: 17))),
        ),
      );
    }

    return Opacity(
      key: ValueKey('roomCard-${r.n}'),
      opacity: fits ? 1 : .35,
      child: IgnorePointer(
        ignoring: !fits,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
          child: VGap(
            gap: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Tap(
                      // The room's name opens it on its own (bed facts, compare).
                      onTap: () => s.openRoom(r.n),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T('Room ${r.label}', w: 800, s: 16, lh: 1.2, underline: true),
                          T('${r.share} sharing${r.ac ? ' AC' : ''} · ${fmt(r.rent)}', s: 12, c: p.mu, lh: 1.3),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  T(free == 0 ? 'Full' : '$free free', s: 13, w: 800, c: free == 0 ? p.mu : p.tx),
                ],
              ),
              if (r.ac && r.acRepair)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  color: p.ab,
                  child: T('AC under repair.${r.acSince.isEmpty ? '' : ' Complaint raised ${r.acSince}.'} The owner is fixing it.', s: 12, w: 600, c: p.ad, lh: 1.4),
                ),
              if (l != null)
                LayoutMap(
                  l: l,
                  room: r,
                  bedKeys: true,
                  fan: s.showFan,
                  ac: s.showAc,
                  onPick: (k) {
                    final b = r.beds.firstWhere((x) => x.letter == k);
                    s.pickBed(b);
                  },
                ),
              if (loose.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: [for (final b in loose) boxBed(b)]),
              if (l != null)
                Align(
                  alignment: Alignment.centerRight,
                  // F26 #12: red, the app's primary action (round 3).
                  child: Cta('Edit this layout', key: ValueKey('editLayout-${r.n}'), icon: 'pencil', height: 40, px: 14, fs: 14, gap: 8, expand: false, onTap: () => s.openFixEditor(hid, r.n)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const pickerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];
