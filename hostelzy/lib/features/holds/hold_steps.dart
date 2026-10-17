import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/kit.dart';
import '../fair_play/fair_play_screens.dart' show ContactButtons;

/// F26 #9: a free hold's steps, Sent → Owner reviewing → Kept / Declined.
/// "Owner reviewing" only once the owner really opened it ([Hold.seen]).
/// After 30 minutes with no answer: "Still waiting. Call the owner?". Under
/// them, F26 #7: WhatsApp + Call while the hold is live, locked when declined.
class HoldSteps extends StatelessWidget {
  const HoldSteps(this.hold, {super.key});
  final Hold hold;

  /// Shown for free holds that are waiting, kept, or declined by the owner.
  static bool shows(AppState s, Hold h) =>
      h.opt != 'book' && (const ['waiting', 'confirmed', 'held'].contains(h.status) && s.liveHold(h) || h.declined && h.status == 'released');

  @override
  Widget build(BuildContext context) => Ticking(_build);

  Widget _build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hold;
    final owner = hostelById(h.hid).owner;
    final kept = h.status == 'held' || h.status == 'confirmed';
    final declined = h.declined && h.status == 'released';
    final waiting = s.stillWaiting(h, DateTime.now().millisecondsSinceEpoch);
    // (number, label, done, current, bad)
    final steps = <(String, String, bool, bool, bool)>[
      ('1', 'Sent · ${clockTime(h.start).replaceFirst('Today, ', '')}', true, false, false),
      ('2', h.seen != null && !kept && !declined ? 'Owner reviewing · since ${clockTime(h.seen!).replaceFirst('Today, ', '')}' : 'Owner reviewing', h.seen != null || kept || declined, h.seen != null && !kept && !declined, false),
      ('3', declined ? 'Declined' : 'Kept', kept || declined, false, declined),
    ];
    Widget step((String, String, bool, bool, bool) x) {
      final (n, label, done, cur, bad) = x;
      final reached = done || cur;
      return Row(
        key: ValueKey('step-$n${cur ? '-now' : done ? '-done' : ''}'),
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: box(bg: cur || bad ? p.ac : (done ? p.tx : transparent), w: reached ? null : 2, c: p.dv),
            child: done && !cur ? Ic(bad ? 'x' : 'check', size: 14, color: bad ? p.ai : p.bg) : T(n, s: 12, w: 800, c: cur ? p.ai : p.mu),
          ),
          const SizedBox(width: 10),
          Expanded(child: T(label, s: 14, w: 800, c: reached ? p.tx : p.mu)),
        ],
      );
    }

    return Container(
      key: ValueKey('holdSteps-${h.id}'),
      padding: const EdgeInsets.all(12),
      child: VGap(
        gap: 12,
        children: [
          VGap(gap: 8, children: [for (final x in steps) step(x)]),
          if (waiting)
            Container(
              key: const ValueKey('stillWaiting'),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: p.ab,
              child: T('Still waiting. Call the owner?', s: 14, w: 800, lh: 1.4, c: p.ad),
            )
          else if (kept)
            T('${owner.isEmpty ? 'The owner' : owner} kept your bed. Visit before the hold ends, or pay to book.', s: 14, lh: 1.4)
          else if (declined)
            T('The owner couldn’t keep this bed. Call and WhatsApp are locked again.', s: 14, lh: 1.4, c: p.mu),
          ContactButtons(declined ? null : h, callFirst: waiting),
        ],
      ),
    );
  }
}
