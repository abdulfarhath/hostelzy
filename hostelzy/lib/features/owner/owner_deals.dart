import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F03 Hostelzy deals: the owner's deal picker (board 4). F21 W2: the tenant's
// side is folded into the hostel page's price table (screens_tenant.dart).

/// F03 board 4, F22 Area 3 `deals`: up to 3 switches; the ones on are green.
/// "Save deals" sits under the page (OwnerManageScreen).
class OwnerDeals extends StatelessWidget {
  const OwnerDeals({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final on = s.dealDraft ?? s.dealsOf(h.id).on;
    final t = h.terms;
    final ref = s.rates[h.id]?[rateKey(false, 3)] ?? h.from;
    final cost = <String, int>{'exit': ((t.maintenance - exitHz).clamp(0, 1 << 20) / 12).round(), 'monthly': monthlyOff, 'first': (firstOff / 12).round(), 'advance': 0, 'laundry': laundryCost, 'noadmin': (joiningFee / 12).round()};
    String title(String id) => switch (id) {
      'exit' => '${fmt(t.maintenance - exitHz)} back when they leave',
      'monthly' => '${fmt(monthlyOff)} off every month',
      'first' => '${fmt(firstOff)} off the first month',
      'advance' => '${fmt(advanceOff)} lower advance',
      'laundry' => 'Free laundry',
      _ => 'No joining fee',
    };
    String sub(String id) => switch (id) {
      'exit' => 'You keep ${fmt(exitHz)} of the advance, not ${fmt(t.maintenance)}',
      'monthly' => 'Tenants see ${fmt(ref - monthlyOff)} instead of ${fmt(ref)} (3 sharing)',
      'first' => 'Once, on the first month’s rent',
      'advance' => '${fmt(t.advance - advanceOff)} instead of ${fmt(t.advance)} to book',
      'laundry' => 'Once a week',
      _ => 'Waive the one-time ${fmt(joiningFee)} fee',
    };
    String costTxt(String id) => cost[id] == 0 ? 'No cost to you' : id == 'monthly' ? 'Costs you ${fmt(monthlyOff)} a month for each tenant from the app' : 'Costs you about ${fmt(cost[id]!)} a month for each tenant from the app';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: T('Pick up to $maxDeals. Tenants who book through Hostelzy see the green price and find you in Best deals; walk-ins don’t get them. ${on.length} of $maxDeals on.', s: 14, c: p.mu, lh: 1.4),
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
                Semantics(
                  toggled: on.contains(id),
                  child: Tap(
                    key: ValueKey('deal-$id'),
                    onTap: () => s.toggleDeal(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(color: on.contains(id) ? p.gb : null, border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(title(id), w: 800, s: 16, c: on.contains(id) ? p.gn : p.tx),
                                const SizedBox(height: 1),
                                T(sub(id), s: 13, c: p.mu),
                                T(costTxt(id), s: 13, c: p.mu),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          DealSwitch(on: on.contains(id)),
                        ],
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('Always on: exit rules written at booking. Costs you nothing.', s: 13, c: p.mu))]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// A square on/off switch (`44×24`, 2px frame): filled when on.
class DealSwitch extends StatelessWidget {
  const DealSwitch({super.key, required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: box(bg: on ? p.tx : transparent, w: 2, c: p.tx),
      child: Container(width: 16, height: 16, color: on ? p.bg : p.tx),
    );
  }
}
