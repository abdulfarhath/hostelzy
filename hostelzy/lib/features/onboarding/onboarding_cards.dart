import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// Board 7: Visited by Hostelzy + availability, on the hostel page.
class VisitedBlock extends StatelessWidget {
  const VisitedBlock(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final v = s.visited[h.id];
    final free = s.rooms[h.id]!.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free').length);
    final days = s.confirmed[h.id];
    final stale = s.stale(h.id);
    return VGap(
      gap: 8,
      children: [
        if (v != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: box(w: 2, c: p.tx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ic('shieldOk', size: 20, color: p.tx),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('Visited by Hostelzy · $v', w: 800, s: 15),
                      T('Photos taken by our team · beds and prices checked in person', s: 12, c: p.mu, lh: 1.35),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          color: stale ? p.ab : p.sf,
          child: stale
              ? Rich([sp(context, 'Availability not confirmed', w: 800, c: p.ad), sp(context, ' · owner hasn’t confirmed for $days days. Ask before you visit.')], s: 13, lh: 1.4)
              : Rich(
                  [
                    sp(context, '$free free ${free == 1 ? 'bed' : 'beds'}', w: 800),
                    if (days != null)
                    sp(
                      context,
                      ' · confirmed by the owner ${days == 0
                          ? 'today'
                          : days == 1
                          ? 'yesterday'
                          : '$days days ago'}',
                    ),
                  ],
                  s: 13,
                  lh: 1.4,
                ),
        ),
        // F24 #15 (Design v22 r-detail): residents' approved layout fixes, from the server.
        if (s.hostelCheckedLabel(h.id) case final ck?)
          Row(
            key: const ValueKey('hostelChecked'),
            children: [Ic('check', size: 16, color: p.tx), const SizedBox(width: 8), Expanded(child: T(ck, s: 13, w: 700))],
          ),
      ],
    );
  }
}

/// Board 10: "Still N free beds?" on owner Today, every 3 days.
class FreeBedsCard extends StatelessWidget {
  const FreeBedsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    if (!s.needsConfirm(hid)) return const SizedBox();
    final free = s.rooms[hid]!.expand((r) => r.beds).where((b) => b.state == 'free').toList();
    final n = free.length;
    final days = s.confirmed[hid];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 8,
        children: [
          T('Still $n free ${n == 1 ? 'bed' : 'beds'}?', w: 800, s: 18),
          T(days == null ? 'Not confirmed yet. Fresh beds rank higher.' : 'Last confirmed $days days ago. Fresh beds rank higher.', s: 13, c: p.mu),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in free)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: box(w: 1, c: p.tx),
                  child: T(b.id, s: 12, w: 800),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Cta('Yes, all $n free', icon: 'check', height: 46, px: 12, fs: 14, onTap: () => s.confirmBeds(hid)),
              ),
              const SizedBox(width: 8),
              Cta('Update', icon: 'chev', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.tab('oBeds')),
            ],
          ),
          T('Not confirmed for $staleAfterDays days: tenants see “Availability not confirmed” and you rank lower.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

/// F03 (F24 Wave 4d): "Are your rates still right?" on owner Today, monthly.
/// Owner only (rates are the owner's, Wave 3a).
class RatesConfirmCard extends StatelessWidget {
  const RatesConfirmCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    if (!s.needsRatesConfirm(hid)) return const SizedBox();
    final at = s.ratesConfirmedAt[hid];
    final rc = s.rates[hid] ?? const <String, int>{};
    final keys = rc.keys.toList()..sort((a, b) => (a.startsWith('ac') ? 1 : 0).compareTo(b.startsWith('ac') ? 1 : 0));
    return Container(
      key: const ValueKey('ratesCard'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 8,
        children: [
          const T('Are your rates still right?', w: 800, s: 18),
          T(at == null ? 'Not confirmed yet. Tenants see the date you last confirmed them.' : 'Last confirmed ${dayMon(at.toLocal())}. Tenants see the date you last confirmed them.', s: 13, c: p.mu, lh: 1.4),
          if (keys.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in keys)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: box(w: 1, c: p.tx),
                    child: T('${k.replaceFirst(RegExp('^(ac|non)'), '')} sharing ${k.startsWith('ac') ? 'AC' : 'non-AC'} · ${fmt(rc[k]!)}', s: 12, w: 800),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(child: Cta('Rates still right', icon: 'check', height: 46, px: 12, fs: 14, onTap: () => s.confirmRates(hid))),
              const SizedBox(width: 8),
              Cta('Change', icon: 'chev', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: s.openRates),
            ],
          ),
          T('Not confirmed for a month: tenants see “Not confirmed in over a month” on your prices.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}
