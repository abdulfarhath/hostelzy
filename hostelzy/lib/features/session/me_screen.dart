import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../../state.dart';
import '../../ui/kit.dart';

// ------------------------------------------------------------ me

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final isOwner = s.role == 'owner';
    // F22 Area 1: one list, each row with a one-line status. F26 #10: Saved,
    // Holds and My stay are tabs, so they aren't rows here.
    final rows = <(String, String, VoidCallback)>[
      // F24: an advance refund still open after moving out.
      if (s.myRefund case final r? when s.role != 'resident') ('Your refund', '${fmt(r.amt)} · ${r.status == 'sent' ? 'did it arrive?' : r.status == 'not_received' ? 'not received' : 'due ${dayMon(r.due)}'}', s.openMyRefund),
      if (!isOwner) ('Stay Rewards', const {'trusted': 'Trusted tenant', 'member': 'Member'}[s.level] ?? 'Not a member yet', () => s.go('rewards')),
      ('Reminders', s.remSummary[0].toUpperCase() + s.remSummary.substring(1), s.openReminders),
      ('Settings', 'Language, notifications, log out', () => s.go('settings')),
      ('Help on WhatsApp', 'Ask the Hostelzy team', () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, I need help with the app.')),
    ];
    Widget row((String, String, VoidCallback) r) => Tap(
      key: ValueKey('me-${r.$1}'),
      onTap: r.$3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(r.$1, s: 16, w: 800), T(r.$2, s: 13, c: p.mu)])),
            Ic('chev', size: 18, color: p.mu),
          ],
        ),
      ),
    );
    return Scroll(
      key: ValueKey('me${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  color: p.ac,
                  alignment: Alignment.center,
                  child: s.meName.isEmpty && !isOwner ? Ic('user', size: 28, color: p.ai) : T(initials(s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner), w: 800, s: 24, c: p.ai),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T(s.meName.isNotEmpty ? s.meName : (isOwner ? hostelById(s.ownHid).owner : 'Add your name'), w: 800, s: 24, lh: 1.05),
                      const SizedBox(height: 3),
                      T(s.phone.length == 10 ? '+91 ${phoneSpaced(s.phone)} · not verified' : (s.signedIn ? 'Add your number' : 'Browsing as a guest'), s: 13, c: p.mu),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final r in rows) row(r),
          // F26 #11: Log out in red at the end of the list.
          if (s.signedIn)
            Tap(
              key: const ValueKey('me-logout'),
              onTap: s.logOut,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(top: bs(2, p.dv), bottom: bs(1, p.hl))),
                child: Row(children: [Ic('logout', size: 20, color: p.ad), const SizedBox(width: 12), T('Log out', s: 16, w: 800, c: p.ad)]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Expanded(child: T(isOwner ? 'Looking for a bed, or live in a PG?' : 'Live in a PG or run one?', s: 14, c: p.mu)),
                Tap(key: const ValueKey('switchRole'), onTap: () => s.tab('role'), child: T('Switch role ›', s: 14, w: 800, c: p.ad)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: T('Hostelzy $appVersion · Made in Hyderabad', s: 12, c: p.mu),
          ),
        ],
      ),
    );
  }
}
