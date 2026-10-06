import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/kit.dart';

/// Board 7: availability, on the hostel page. F26 #5: the team visit is the
/// ✓ VERIFIED badge next to the name now, not a block here.
class VisitedBlock extends StatelessWidget {
  const VisitedBlock(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final free = s.rooms[h.id]!.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free').length);
    final days = s.confirmed[h.id];
    final stale = s.stale(h.id);
    return VGap(
      gap: 8,
      children: [
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
