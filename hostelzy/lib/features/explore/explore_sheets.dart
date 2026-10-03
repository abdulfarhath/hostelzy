import 'package:flutter/material.dart';

import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'explore_screen.dart';

class SearchSheet extends StatelessWidget {
  const SearchSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final count = filtered(s).length;
    // F21 W2: Filters sheet. Sort lives here; same labels as the Explore chips.
    Widget group(String label, Widget child) => VGap(gap: 8, children: [T(label, w: 800, s: 15), child]);
    const segPad = EdgeInsets.symmetric(vertical: 11, horizontal: 6);
    const chipPad = EdgeInsets.symmetric(vertical: 10, horizontal: 12);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 18,
        children: [
          group('Sort by', Seg(opts: const [('rec', 'Recommended'), ('near', 'Nearest'), ('deals', 'Best deals'), ('price', 'Lowest price')], cur: s.sortBy, onPick: (v) => s.update(() => s.sortBy = v), pad: segPad, center: true, byLabel: true)),
          group('For', Seg(opts: const [('Any', 'Anyone'), ('Men', 'Men'), ('Women', 'Women'), ('Co-living', 'Co-living')], cur: s.fG, onPick: (v) => s.update(() => s.fG = v), pad: segPad, center: true)),
          group(
            'Room',
            wrap(6, [
              for (final n in ['2', '3', '4']) ChipBtn('$n sharing', on: s.fS == n, pad: chipPad, onTap: () => s.update(() => s.fS = s.fS == n ? 'Any' : n)),
              for (final r in ['AC', 'Non-AC']) ChipBtn(r, on: s.fR == r, pad: chipPad, onTap: () => s.update(() => s.fR = s.fR == r ? 'Any' : r)),
            ]),
          ),
          group(
            'Budget',
            wrap(6, [
              for (final (k, l) in const [('Any', 'Any'), ('6k', 'Under ₹6,000'), ('8k', 'Under ₹8,000'), ('10k', 'Under ₹10,000')]) ChipBtn(l, on: s.fB == k, pad: chipPad, onTap: () => s.update(() => s.fB = k)),
            ]),
          ),
          group('Deals', wrap(6, [ChipBtn('Hostelzy deals only', on: s.fDeals, pad: chipPad, onTap: () => s.update(() => s.fDeals = !s.fDeals))])),
          // F23: things on the floor (working), and a geyser in the room's washroom.
          group('On the floor', wrap(6, [
            for (final k in const [('washer', 'Washing machine'), ('fridge', 'Fridge'), ('ro', 'RO water'), ('geyser', 'Geyser in my washroom')])
              ChipBtn(k.$2, key: ValueKey('fAm-${k.$1}'), on: s.fAm.contains(k.$1), pad: chipPad, onTap: () => s.update(() => s.fAm = s.fAm.contains(k.$1) ? (Set.of(s.fAm)..remove(k.$1)) : {...s.fAm, k.$1})),
          ])),
          Tap(
            key: const ValueKey('foodToggle'),
            onTap: () => s.update(() => s.fFood = !s.fFood),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const T('Food included', s: 15, w: 800),
                Container(
                  width: 44,
                  height: 24,
                  padding: const EdgeInsets.all(2),
                  decoration: box(bg: s.fFood ? p.ac : transparent, w: 2, c: p.tx),
                  alignment: s.fFood ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(width: 16, height: 16, color: s.fFood ? p.ai : p.tx),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Tap(key: const ValueKey('clearAll'), onTap: s.clearFilters, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4), child: T('Clear all', w: 800, s: 15, underline: true))),
              const SizedBox(width: 16),
              Expanded(
                child: Cta(
                  'Show $count hostels',
                  height: 54,
                  px: 16,
                  fs: 15,
                  onTap: () {
                    if (s.screen != 'explore' && s.screen != 'map') {
                      s.tab('explore');
                    } else {
                      s.update(() => s.sheet = null);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
