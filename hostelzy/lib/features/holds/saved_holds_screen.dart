import 'package:flutter/material.dart';

import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../explore/explore_screen.dart';
import 'holds_screens.dart';

/// F26 #16: while Holds (or one hold) is on screen, the user has seen every
/// hold result, so the red dot on the Holds tab goes.
class HoldsSeen extends StatelessWidget {
  const HoldsSeen({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Rebuilt on every app change, so a result arriving here is seen too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) s.markHoldsSeen();
    });
    return child;
  }
}

/// F26 #17 (S88): a resident inside Find a bed gets Saved and Holds in one
/// tab, two segments. A plain tenant keeps the two tabs.
class SavedHoldsScreen extends StatelessWidget {
  const SavedHoldsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final nSaved = s.saved.values.where((v) => v).length;
    final nHolds = s.holds.where((h) => h.status != 'released' && !s.expiredHolds.contains(h.id)).length;
    final holds = s.shSeg == 'holds';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: const T('Saved & Holds', s: 30, w: 800, lh: 1.02, ls: -.025),
        ),
        Seg(key: const ValueKey('shSeg'), margin: const EdgeInsets.all(16), opts: [('saved', 'Saved · $nSaved'), ('holds', 'Holds · $nHolds')], cur: s.shSeg, onPick: (v) => s.update(() => s.shSeg = v), center: true, dividers: true),
        Expanded(child: holds ? const HoldsSeen(child: HoldsScreen(bare: true)) : const SavedScreen(bare: true)),
      ],
    );
  }
}
