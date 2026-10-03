import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../amenities/amenities_screens.dart';

// Hostelzy team mode (Settings → Hostelzy team) and the owner's list of room
// layouts (Manage → Layouts).

/// Team access (B7): Hostelzy team Google accounts only.
class TeamSheet extends StatelessWidget {
  const TeamSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.account;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('For the Hostelzy team only. Owners and tenants don’t need this.', s: 13, c: p.mu, lh: 1.45),
          if (a == null)
            const T('Sign in with your Hostelzy team Google account, then come back here.', s: 14, w: 600, lh: 1.45)
          else ...[
            T('Signed in as ${a.email}', s: 14, w: 600),
            Cta(s.teamChecking ? 'Checking…' : 'Open team tools', icon: 'lock', height: 54, px: 16, fs: 15, onTap: s.checkTeam),
          ],
          T('The founder adds team accounts. There is no passcode.', s: 12, c: p.mu),
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
      ('chart', 'Onboarding tracker', 'Lead → Visited → Signed up → Live → Trial → Paying', () {
        s.go('aTrack');
        s.loadTeam();
      }),
      ('room', 'Layout editor', 'Draw and move beds, fans, AC, windows; send to the owner', () => s.openLayout(s.lRoom, editor: true)),
      ('userPlus', 'Team members', 'Who helps with visits, layouts and payments', () {
        s.go('aTeam');
        s.loadTeam();
      }),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: AppState.samples && !s.onServer ? 'Team tools · sample data' : 'Team tools', title: 'Hostelzy team', size: 28))],
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
                  // F25: plan payments and Fair Play cases are desk work, in the team console only.
                  Padding(
                    key: const ValueKey('aHomeConsole'),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: T('Payments and Fair Play cases are in the team console: farhath.me/hostelzy/app/console', s: 13, c: p.mu, lh: 1.4),
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
    // F18 design "Rooms": the owner edits and publishes; Live / Draft / No layout.
    String kind(int n) {
      final l = s.layoutOf(h.id, n);
      if (l == null) return 'none';
      if (!l.live || l.pending || l.published != null) return 'draft';
      return 'live';
    }

    ({String label, Color bg, Color fg}) state(int n) {
      final l = s.layoutOf(h.id, n);
      // F24: an "Ask Hostelzy to draw it" request, or its drawing back.
      final q = s.shapeReqFor(h.id, n);
      if (q != null) return q.status == 'sent' ? (label: 'Drawn · publish it', bg: p.tx, fg: p.bg) : (label: 'Help requested', bg: p.ab, fg: p.ad);
      if (l == null) return (label: 'No layout', bg: p.ab, fg: p.ad);
      if (l.disputes > 0) return (label: 'Resident: not accurate', bg: p.ab, fg: p.ad);
      if (kind(n) == 'draft') return (label: 'Draft', bg: transparent, fg: p.tx);
      return (label: 'Live', bg: p.tx, fg: p.bg);
    }

    String sub(Room r) {
      final l = s.layoutOf(h.id, r.n);
      // F13 S4, F24 4a: residents' 30-day reviews say the layout is wrong.
      if (l != null && l.disputes > 0) return 'Residents say this layout is wrong';
      final note = l == null ? '' : (l.pending ? ' · Hostelzy drew a new version' : (kind(r.n) == 'draft' ? ' · changes not published' : ' · edited ${l.drawn}'));
      return '${r.share} sharing · ${r.type}$note';
    }

    final counts = {for (final k in ['live', 'draft', 'none']) k: rs.where((r) => kind(r.n) == k).length};
    final shown = rs.where((r) => s.layoutsF == 'all' || kind(r.n) == s.layoutsF).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Layouts', title: s.amOwnerTab == 'things' ? s.floorName(s.amFloor) : 'Room layouts', size: 28))]),
        ),
        // F23: the floors' shared things sit beside the room layouts.
        Seg(
          key: const ValueKey('layoutsTab'),
          opts: [('rooms', 'Rooms'), ('things', 'Shared things ${s.amenities.where((a) => a.hid == h.id).length}')],
          cur: s.amOwnerTab,
          onPick: (v) => s.update(() {
            s.amOwnerTab = v;
            s.amHid = h.id;
            if (!floorsOf(rs).contains(s.amFloor) && !s.amenityFloors(h.id).contains(s.amFloor)) s.amFloor = floorsOf(rs).first;
          }),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          center: true,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        if (s.amOwnerTab == 'things') const Expanded(child: OwnerSharedThings()) else ...[
        Scroll(
          horizontal: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (final (k, lbl) in [('all', 'All ${rs.length}'), ('live', 'Live ${counts['live']}'), ('draft', 'Draft ${counts['draft']}'), ('none', 'No layout ${counts['none']}')]) ...[
                  ChipBtn(lbl, on: s.layoutsF == k, onTap: () => s.update(() => s.layoutsF = k)),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oLayouts${s.scrollEpoch}'),
            child: Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in floorsOf(rs).where((f) => shown.any((r) => r.floor == f))) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Kicker('Floor $f')),
                    for (final r in shown.where((r) => r.floor == f))
                      () {
                        final st = state(r.n);
                        return Tap(
                          onTap: () => s.ownerLayout(r.n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('Room ${r.label}', w: 800, s: 15), T(sub(r), s: 12, c: (s.layoutOf(h.id, r.n)?.disputes ?? 0) > 0 ? p.ad : p.mu)])),
                                Container(decoration: st.bg == transparent ? box(w: 1, c: p.tx) : null, child: Tag(st.label, bg: st.bg, fg: st.fg)),
                                const SizedBox(width: 6),
                                Ic('chev', size: 18, color: p.mu),
                              ],
                            ),
                          ),
                        );
                      }(),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Ic('pencil', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('You edit and publish your own layouts. Want help? The Hostelzy team can draw one for you.', s: 12, c: p.mu, lh: 1.45))]),
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ],
    );
  }
}
