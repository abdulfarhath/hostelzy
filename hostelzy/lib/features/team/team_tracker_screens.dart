import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../onboarding/add_hostel_screen.dart';

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
          labeledField('Name', s.mgrName, (v) => s.update(() => s.mgrName = v), ph: 'Prakash'),
          labeledField('WhatsApp number', s.mgrPhone, (v) => s.update(() => s.mgrPhone = v), numeric: true, ph: '90000 00002'),
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
          T('${s.mgrName.trim().isEmpty ? 'They' : s.mgrName.trim()} join${s.mgrName.trim().isEmpty ? '' : 's'} by signing in with Google and the code we send on WhatsApp.', s: 12, c: p.mu),
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
                          if (l.stage < onboardStages.length - 1 && !(s.data.remote && l.stage >= 4 && l.hid != null && !isSeedHostel(l.hid!))) ...[
                            const SizedBox(width: 10),
                            Tap(
                              onTap: () => s.advanceLead(l),
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
