import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../meter/stay_tools_screens.dart';

/// F26 #20 rent tag colours: Paid green, Late red, Due plain (outline).
({Color bg, Color fg, Color border}) rentTag(Pal p, String status) => switch (status) {
  'Paid' => (bg: p.gb, fg: p.gn, border: p.gb),
  'Overdue' => (bg: p.ab, fg: p.ad, border: p.ab),
  _ => (bg: transparent, fg: p.tx, border: p.dv),
};

/// F26 #20: the ready WhatsApp reminder, from the resident's real row.
String rentReminder(AppState s, Resident r) {
  final month = monthYear(appToday).split(' ').first;
  final n = r.note.trim();
  final when = RegExp(r'^\d+ days? late$').hasMatch(n)
      ? 'is $n'
      : n.startsWith('Due ')
      ? 'is due ${n.substring(4)}'
      : r.status == 'Overdue'
      ? 'is late'
      : 'is due';
  final upi = s.ownerUpi[s.ownHid]?.id ?? '';
  return 'Hi ${r.name.split(' ').first}, $month rent ${fmt(r.amt)} for bed ${r.bed} $when. Pay in the Hostelzy app${upi.isEmpty ? '' : ' or by UPI to $upi'}.';
}

/// F22 Area 3 (board `oRent`): what came in and what's still to come, then
/// one row per resident with a status tag (F26 #20: Paid green, Late red, Due
/// plain) and Call + WhatsApp on every unpaid row.
class OwnerRentScreen extends StatelessWidget {
  const OwnerRentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final collected = s.residents.where((r) => r.status == 'Paid').fold<int>(0, (a, r) => a + r.amt);
    final expected = s.residents.fold<int>(0, (a, r) => a + r.amt);
    final rows = s.residents.where((r) => s.rentF == 'All' || r.status == s.rentF);
    int n(String st) => st == 'All' ? s.residents.length : s.residents.where((r) => r.status == st).length;
    String word(String st) => st == 'Overdue' ? 'Late' : st;
    return Scroll(
      key: ValueKey('oRent${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: PageHead(kicker: monthYear(appToday), title: 'Rent'),
          ),
          Container(
            key: const ValueKey('rentTotals'),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: box(w: 2, c: p.tx),
            child: VGap(
              gap: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T('Collected', s: 13, c: p.mu),
                          FittedBox(fit: BoxFit.scaleDown, child: T(fmt(collected), w: 800, s: 30, ls: -.02)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          T('Still to come', s: 13, c: p.mu),
                          FittedBox(fit: BoxFit.scaleDown, child: T(fmt(expected - collected), w: 800, s: 22, c: p.ad)),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 10,
                  decoration: box(w: 2, c: p.tx),
                  child: LayoutBuilder(
                    builder: (context, c) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Container(width: expected == 0 ? 0 : (c.maxWidth * collected / expected).clamp(0, c.maxWidth).toDouble(), color: p.tx)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // F24 #25 (board `oMeter`): electricity by meter, when it's extra.
          if (hostelById(s.ownHid).terms.electricityExtra) const MeterEntry(),
          Seg(
            opts: [for (final st in const ['All', 'Due', 'Overdue', 'Paid']) (st, '${word(st)} ${n(st)}')],
            cur: s.rentF,
            onPick: (v) => s.update(() => s.rentF = v),
            pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            center: true,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Container(
                    key: ValueKey('rentRow-${r.bed}'),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T(r.name, w: 800, s: 16),
                              const SizedBox(height: 1),
                              T('${r.bed} · ${fmt(r.amt)} · ${r.note}', s: 13, c: p.mu),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tag(word(r.status), key: ValueKey('rentTag-${r.bed}'), bg: rentTag(p, r.status).bg, fg: rentTag(p, r.status).fg, border: rentTag(p, r.status).border),
                        const SizedBox(width: 10),
                        if (r.status != 'Paid') ...[
                          Tap(
                            key: ValueKey('rentCall-${r.bed}'),
                            onTap: () => s.call(r.phone),
                            child: Semantics(
                              button: true,
                              label: 'Call ${r.name}',
                              child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const Ic('phone', size: 18)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tap(
                            key: ValueKey('rentWa-${r.bed}'),
                            onTap: () => r.phone.isEmpty ? s.toastMsg('No number for ${r.name} yet.') : s.whatsapp(r.phone, rentReminder(s, r)),
                            child: Semantics(
                              button: true,
                              label: 'WhatsApp reminder to ${r.name}',
                              child: Container(width: 44, height: 44, alignment: Alignment.center, color: p.tx, child: Ic('msg', size: 18, color: p.bg)),
                            ),
                          ),
                        ] else
                          const SizedBox(width: 94),
                      ],
                    ),
                  ),
                if (rows.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('No one here.', s: 14, c: p.mu)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
