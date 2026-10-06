import 'package:flutter/material.dart';

import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'explore_screen.dart';

/// F26 #2: the Filters sheet. Who (Men / Women / Co-living), Room (AC,
/// sharing), Food, Rent, then deals and shared things. Sort is its own
/// dropdown on Explore now (the `sort` sheet).
class SearchSheet extends StatelessWidget {
  const SearchSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final count = filtered(s).length;
    Widget group(String label, Widget child) => VGap(gap: 8, children: [T(label, w: 800, s: 15), child]);
    const chipPad = EdgeInsets.symmetric(vertical: 10, horizontal: 12);
    Widget chip(String label, bool on, VoidCallback onTap, {Key? key}) => ChipBtn(label, key: key, on: on, pad: chipPad, onTap: () => s.update(onTap));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 18,
        children: [
          group('Who', wrap(6, [for (final g in const ['Men', 'Women', 'Co-living']) chip(g, s.fG == g, () => s.fG = s.fG == g ? 'Any' : g, key: ValueKey('fG-$g'))])),
          group(
            'Room',
            wrap(6, [
              for (final r in ['AC', 'Non-AC']) chip(r, s.fR == r, () => s.fR = s.fR == r ? 'Any' : r, key: ValueKey('fR-$r')),
              for (final n in ['2', '3', '4']) chip('$n sharing', s.fS == n, () => s.fS = s.fS == n ? 'Any' : n),
            ]),
          ),
          group(
            'Food',
            wrap(6, [
              chip('Food included', s.fFood, () {
                s.fFood = !s.fFood;
                if (s.fFood) s.fNoFood = false;
              }, key: const ValueKey('foodToggle')),
              chip('No food', s.fNoFood, () {
                s.fNoFood = !s.fNoFood;
                if (s.fNoFood) s.fFood = false;
              }, key: const ValueKey('noFood')),
            ]),
          ),
          group('Rent', wrap(6, [for (final (k, l) in const [('6k', 'Under ₹6,000'), ('8k', 'Under ₹8,000'), ('10k', 'Under ₹10,000')]) chip(l, s.fB == k, () => s.fB = s.fB == k ? 'Any' : k)])),
          group('Deals', wrap(6, [chip('Hostelzy deals only', s.fDeals, () => s.fDeals = !s.fDeals)])),
          // F23: things on the floor (working), and a geyser in the room's washroom.
          group('On the floor', wrap(6, [
            for (final k in const [('washer', 'Washing machine'), ('fridge', 'Fridge'), ('ro', 'RO water'), ('geyser', 'Geyser in my washroom')])
              chip(k.$2, s.fAm.contains(k.$1), () => s.fAm = s.fAm.contains(k.$1) ? (Set.of(s.fAm)..remove(k.$1)) : {...s.fAm, k.$1}, key: ValueKey('fAm-${k.$1}')),
          ])),
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

/// F26 #2: the sort dropdown. Price ↑ (default) · Distance · Rating · Best deals.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in sortLabels.entries)
            Tap(
              key: ValueKey('sort-${e.key}'),
              onTap: () => s.update(() {
                s.sortBy = e.key;
                s.sheet = null;
              }),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  children: [
                    Expanded(child: T(e.value, s: 16, w: s.sortBy == e.key ? 800 : 600)),
                    if (s.sortBy == e.key) Ic('check', size: 18, color: p.ad),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
