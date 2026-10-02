import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F03 Hostelzy deals: the owner's deal picker (board 4). F21 W2: the tenant's
// side is folded into the hostel page's price table (screens_tenant.dart).

/// F03 board 4: the owner picks up to 3 deals (Manage → Deals).
class OwnerDeals extends StatelessWidget {
  const OwnerDeals({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostels[0];
    final on = s.dealDraft ?? s.dealsOf(h.id).on;
    final t = h.terms;
    final ref = s.rates[h.id]![rateKey(false, 3)] ?? h.from;
    final q = DealQuote(t, ref, on);
    final cost = <String, int>{'exit': ((t.maintenance - exitHz).clamp(0, 1 << 20) / 12).round(), 'monthly': monthlyOff, 'first': (firstOff / 12).round(), 'advance': 0, 'laundry': laundryCost, 'noadmin': (joiningFee / 12).round()};
    String costTxt(String id) => cost[id] == 0 ? 'No cost' : id == 'monthly' ? '${fmt(monthlyOff)}/mo' : '≈ ${fmt(cost[id]!)}/mo';
    String sub(String id) => switch (id) {
      'exit' => '${fmt(t.maintenance)} → ${fmt(exitHz)} when they leave',
      'monthly' => '${fmt(ref)} → ${fmt(ref - monthlyOff)}',
      'first' => '${fmt(firstOff)} off the first month',
      'advance' => '${fmt(t.advance)} → ${fmt(t.advance - advanceOff)} to book',
      'laundry' => 'Laundry once a week',
      _ => 'Waive the one-time ${fmt(joiningFee)} fee',
    };
    String tenant(String id) => switch (id) {
      'exit' => '${fmt(t.maintenance - exitHz)} back',
      'monthly' => '${fmt(monthlyOff * 6)} in 6 mo',
      'first' => '${fmt(firstOff)} once',
      'advance' => '${fmt(advanceOff)} less upfront',
      'laundry' => 'Free laundry',
      _ => '${fmt(joiningFee)} once',
    };
    final n = on.length;
    final costSum = on.fold<int>(0, (a, id) => a + cost[id]!);
    final strength = n == 0 ? 'None' : (q.save6 >= 1500 || n == maxDeals) ? 'Strong' : q.save6 >= 800 ? 'Good' : 'Basic';
    final rank = switch (strength) {
      'Strong' => 'Top deals near ${s.lm}',
      'Good' => 'Shown in Best deals',
      _ => 'Add a deal to show in Best deals',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: VGap(
            gap: 4,
            children: [
              Kicker('3 sharing · walk-in ${fmt(ref)}'),
              const T('Your Hostelzy deals', w: 800, s: 24, lh: 1.05, ls: -.02),
              T("Pick up to $maxDeals. Tenants who book through Hostelzy get them; walk-ins don't.", s: 13, c: p.mu, lh: 1.4),
            ],
          ),
        ),
        if (h.ac && h.hasNon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Seg(opts: const [('all', 'All rooms'), ('ac', 'AC only'), ('non', 'Non-AC only')], cur: s.dealTarget, onPick: (v) => s.update(() => s.dealTarget = v), pad: const EdgeInsets.all(10)),
          ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in dealMenu)
                Tap(
                  onTap: () => s.toggleDeal(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                    decoration: BoxDecoration(color: on.contains(id) ? p.gb : null, border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: box(bg: on.contains(id) ? p.tx : transparent, w: 2, c: p.tx),
                          child: on.contains(id) ? Ic('check', size: 14, color: p.bg) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(dealTitle[id]!, w: 800, s: 15), const SizedBox(height: 1), T(sub(id), s: 12, c: p.mu)]),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [T(tenant(id), s: 12, w: 800, c: p.gn), const SizedBox(height: 1), T(costTxt(id), s: 11, c: p.mu)]),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(children: [Ic('shield', size: 16, color: p.gn), const SizedBox(width: 8), Expanded(child: T('Always on: exit rules written at booking. Costs you nothing.', s: 12, c: p.mu))]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: VGap(
            gap: 10,
            children: [
              Container(
                color: p.hl,
                padding: const EdgeInsets.all(1),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: p.gb,
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Tenant saves · 6 months', s: 10, w: 600, ls: .08, upper: true, c: p.gn), T(fmt(q.save6), w: 800, s: 24, c: p.gn)]),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Expanded(
                        child: Container(
                          color: p.bg,
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Costs you / month', s: 10, w: 600, ls: .08, upper: true, c: p.mu), T(fmt(costSum), w: 800, s: 24)]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VGap(
                gap: 5,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T('$n of $maxDeals picked · $strength', s: 12, w: 800), T(rank, s: 12, c: p.mu)]),
                  Container(
                    height: 10,
                    decoration: box(w: 2, c: p.tx),
                    child: LayoutBuilder(builder: (context, c) => Row(children: [Container(width: c.maxWidth * n / maxDeals, color: p.gn)])),
                  ),
                  T('One empty bed costs you ${fmt(ref)} a month.', s: 12, c: p.mu),
                ],
              ),
              Cta('Publish deals', icon: 'check', height: 52, px: 16, fs: 15, onTap: s.publishDeals),
            ],
          ),
        ),
      ],
    );
  }
}
