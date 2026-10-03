import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F14 after go-live: Manage → Rooms (add or remove a room or a whole floor,
// never one with a resident or a hold) and the Hostelzy team's members.

class OwnerRoomsScreen extends StatelessWidget {
  const OwnerRoomsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final rs = s.rooms[h.id]!;
    final floors = floorsOf(rs);
    final empty = s.emptyFloors[h.id] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · ${rs.length} rooms · ${rs.fold<int>(0, (a, r) => a + r.beds.length)} beds', title: 'Rooms', size: 28))]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: T('Add or remove rooms and floors. A room with a resident or a hold can’t be removed. Prices come from Manage → Rates.', s: 13, c: p.mu, lh: 1.45)),
        Expanded(
          child: Scroll(
            key: ValueKey('oRooms${s.scrollEpoch}'),
            child: Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in empty)
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Row(children: [Expanded(child: T(e, w: 800, s: 15)), T('No beds · hidden from tenants', s: 12, c: p.mu)])),
                  for (final f in floors) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      decoration: BoxDecoration(color: p.sf, border: Border(top: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Expanded(child: T('Floor $f', w: 800, s: 15)),
                          Tap(onTap: () => s.removeFloor(h.id, f), child: T('Remove floor', s: 12, w: 800, c: p.ad)),
                        ],
                      ),
                    ),
                    for (final r in rs.where((r) => r.floor == f))
                      () {
                        final why = s.roomBlock(h.id, r.n);
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('Room ${r.label}', w: 800, s: 15), T('${r.share} sharing · ${r.type} · ${fmt(r.rent)}', s: 12, c: p.mu)])),
                              why != null
                                  ? Tag(why, bg: p.sf, fg: p.mu)
                                  : Tap(
                                      onTap: () => s.removeRoom(h.id, r.n),
                                      child: Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), decoration: box(w: 2, c: p.ad), child: T('Remove', s: 12, w: 800, c: p.ad)),
                                    ),
                            ],
                          ),
                        );
                      }(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Align(alignment: Alignment.centerLeft, child: Tap(onTap: () => s.openAddRoom(h.id, f), child: T('+ Add a room on floor $f', s: 13, w: 800, c: p.ad))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Cta('Add a floor', icon: 'plus', height: 52, px: 16, fs: 15, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.addFloor(h.id)),
        ),
      ],
    );
  }
}

/// Sheet: a new room on a floor.
class AddRoomSheet extends StatelessWidget {
  const AddRoomSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final rent = s.rates[s.ownHid]?[rateKey(s.nrAc, s.nrShare)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          VGap(gap: 6, children: [const T('Room number', w: 800, s: 13), Field(value: s.nrLabel, placeholder: '105 or 204A', onChanged: (v) => s.update(() => s.nrLabel = v))]),
          VGap(gap: 6, children: [const T('Sharing', w: 800, s: 13), Seg(opts: const [('1', '1'), ('2', '2'), ('3', '3'), ('4', '4')], cur: '${s.nrShare}', onPick: (v) => s.update(() => s.nrShare = int.parse(v)), center: true)]),
          VGap(gap: 6, children: [const T('Room type', w: 800, s: 13), Seg(opts: const [('non', 'Non-AC'), ('ac', 'AC')], cur: s.nrAc ? 'ac' : 'non', onPick: (v) => s.update(() => s.nrAc = v == 'ac'), center: true)]),
          T(rent == null || rent == 0 ? 'No price for this type yet: add it in Manage → Rates first.' : '${fmt(rent)} a month per bed, from your rate card.', s: 12, c: rent == null || rent == 0 ? p.ad : p.mu),
          Cta('Add room', icon: 'plus', height: 54, px: 16, fs: 15, onTap: () => s.addRoom(s.ownHid)),
        ],
      ),
    );
  }
}

/// Team mode: the Hostelzy team's members.
class TeamMembersScreen extends StatelessWidget {
  const TeamMembersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: PageHead(kicker: 'Hostelzy team', title: 'Team members', size: 28))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('aTeam${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in s.teamMembers)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(m.name, w: 800, s: 15), T('${phoneSpaced(m.phone)} · ${m.role}', s: 12, c: p.mu)])),
                              m.joined ? Tag('Active', bg: p.tx, fg: p.bg) : Tag('Invite pending', bg: p.ab, fg: p.ad),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: VGap(
                    gap: 10,
                    children: [
                      const Kicker('Add a team member'),
                      Field(key: const ValueKey('tmName'), value: s.tmName, placeholder: 'Name', onChanged: (v) => s.update(() => s.tmName = v)),
                      Field(key: const ValueKey('tmPhone'), value: s.tmPhone, numeric: true, placeholder: 'WhatsApp number', onChanged: (v) => s.update(() => s.tmPhone = v)),
                      Seg(opts: const [('Visits', 'Visits'), ('Layouts', 'Layouts'), ('Payments', 'Payments')], cur: s.tmRole, onPick: (v) => s.update(() => s.tmRole = v), center: true),
                      Cta('Send invite', icon: 'userPlus', height: 52, px: 16, fs: 15, onTap: s.addTeamMember),
                      T('Visits: add hostels and residents. Layouts: draw rooms. Payments: check UTRs. They show as Active once the founder adds their Google account and they open team tools.', s: 12, c: p.mu, lh: 1.45),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
