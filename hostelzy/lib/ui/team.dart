import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// Hostelzy team mode (Settings → Hostelzy team) and the owner's list of room
// layouts (Manage → Layouts).

/// Passcode sheet. Temporary until F13 adds real admin accounts.
class TeamSheet extends StatelessWidget {
  const TeamSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('For the Hostelzy team only. Owners and tenants don’t need this.', s: 13, c: p.mu, lh: 1.45),
          VGap(gap: 6, children: [const T('Team passcode', w: 800, s: 13), Field(value: s.teamCode, numeric: true, placeholder: '4 digits', hiddenText: true, onChanged: (v) => s.update(() => s.teamCode = v.replaceAll(RegExp(r'\D'), '')))]),
          Cta('Open team tools', icon: 'lock', height: 54, px: 16, fs: 15, onTap: s.unlockTeam),
          T('Temporary: real team accounts come with the backend (F13).', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// Team home: every Hostelzy team tool in one place.
class TeamHomeScreen extends StatelessWidget {
  const TeamHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final tools = <(String, String, String, VoidCallback)>[
      ('plus', 'Add hostel', 'On a visit: basics, rooms floor by floor, rates, photos, residents, go live', s.openAddHostel),
      ('chart', 'Onboarding tracker', 'Lead → Visited → Signed up → Live → Trial → Paying', () => s.go('aTrack')),
      ('wallet', 'Payments check', 'Owners’ plan invoices and UTRs to match in the bank', () => s.go('aPay')),
      ('flag', 'Fair Play cases', 'Signals, owner replies, strikes', () => s.go('aCases')),
      ('room', 'Layout editor', 'Draw and move beds, fans, AC, windows; send to the owner', () => s.openLayout(s.lRoom, editor: true)),
      ('userPlus', 'Team members', 'Who helps with visits, layouts and payments', () => s.go('aTeam')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: PageHead(kicker: 'Team tools · sample data until the backend is connected', title: 'Hostelzy team', size: 28))],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('aHome${s.scrollEpoch}'),
            child: Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (icon, t, sub, go) in tools)
                    Tap(
                      onTap: go,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                        child: Row(
                          children: [
                            Container(width: 40, height: 40, color: p.sf, alignment: Alignment.center, child: Ic(icon, size: 20, color: p.tx)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(t, w: 800, s: 16), const SizedBox(height: 2), T(sub, s: 12, c: p.mu, lh: 1.35)])),
                            Ic('chev', size: 18, color: p.mu),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlineCta('Lock team tools on this phone', icon: 'lock', onTap: () => s.update(() {
                      s.teamUnlocked = false;
                      s.screen = 'settings';
                      s.hist = [];
                    })),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Manage → Layouts: every room with its layout state.
class OwnerLayoutsScreen extends StatelessWidget {
  const OwnerLayoutsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final rs = s.rooms[h.id]!;
    ({String label, Color bg, Color fg}) state(int n) {
      final l = s.layoutOf(h.id, n);
      if (l == null) return (label: 'Coming soon', bg: p.sf, fg: p.mu);
      if (l.request != null) return (label: 'Change requested', bg: p.ab, fg: p.ad);
      if (l.disputes > 0) return (label: 'Resident: not accurate', bg: p.ab, fg: p.ad);
      if (l.pending) return (label: 'Waiting for approval', bg: p.ac, fg: p.ai);
      return (label: 'Live', bg: p.tx, fg: p.bg);
    }

    final waiting = rs.where((r) => s.layoutOf(h.id, r.n)?.pending == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Manage', title: 'Room layouts', size: 28))]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: T(waiting > 0 ? '$waiting ${waiting == 1 ? 'layout waits' : 'layouts wait'} for your approval. The Hostelzy team draws every room; you check and approve.' : 'The Hostelzy team draws every room; you check and approve. Request a change any time, free.', s: 13, c: p.mu, lh: 1.45),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oLayouts${s.scrollEpoch}'),
            child: Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in floorsOf(rs)) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Kicker('Floor $f')),
                    for (final r in rs.where((r) => r.floor == f))
                      () {
                        final st = state(r.n);
                        return Tap(
                          onTap: () => s.openLayout(r.n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('Room ${r.label}', w: 800, s: 15), T('${r.share} sharing · ${r.type}', s: 12, c: p.mu)])),
                                Tag(st.label, bg: st.bg, fg: st.fg),
                                const SizedBox(width: 6),
                                Ic('chev', size: 18, color: p.mu),
                              ],
                            ),
                          ),
                        );
                      }(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
