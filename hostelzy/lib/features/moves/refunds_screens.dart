import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F24 item 5: the advance refund after a resident moves out. The owner marks
// it refunded with the UPI reference (board `oRefund`, a sheet); the former
// resident says whether it arrived (board `rRefund`).

Widget _rows(BuildContext context, List<(String, String)> rows, {double pad = 16}) {
  final p = PalScope.of(context);
  return Container(
    decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, v) in rows)
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: pad),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: Row(children: [SizedBox(width: 120, child: T(k, s: 14, c: p.mu)), const SizedBox(width: 12), Expanded(child: T(v, w: 600, s: 14))]),
          ),
      ],
    ),
  );
}

/// "+91 98765 00001 (UPI)", or ask for their UPI ID.
String _payTo(Refund r) => r.phone.length == 10 ? '+91 ${phoneSpaced(r.phone)} (UPI)' : 'Ask ${r.name.split(' ').first} for their UPI ID';

/// Board `oRefund`: the sheet's title, kicker and body.
String refundSheetTitle(Refund? r) => r == null ? 'Refund' : 'Refund ${r.name.split(' ').first}’s advance';
String? refundSheetKicker(Refund? r) => r == null ? null : 'Left ${dayMon(r.leftOn)} · Bed ${r.bed}';

class RefundSheet extends StatelessWidget {
  const RefundSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final r = s.refundOpen;
    if (r == null) return Padding(padding: const EdgeInsets.all(16), child: T('Nothing to refund right now.', s: 14, c: p.mu));
    final first = r.name.split(' ').first;
    final late = r.due.isBefore(appToday);
    final ok = s.refundUtr.replaceAll(RegExp(r'\D'), '').length == 12;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          _rows(context, [('Advance', fmt(r.advance)), ('Kept on leaving', '− ${fmt(r.advance - r.amt)}'), ('Refund', fmt(r.amt)), ('Pay to', _payTo(r))], pad: 0),
          if (r.status == 'not_received') T('$first says it hasn’t arrived. Check your bank, then send it again.', s: 14, w: 800, c: p.ad),
          VGap(
            gap: 6,
            children: [
              const T('UPI reference (UTR), 12 digits', w: 800, s: 13),
              Field(key: const ValueKey('refundUtr'), value: s.refundUtr, numeric: true, placeholder: '4021 9910 2245', onChanged: (v) => s.update(() => s.refundUtr = v)),
            ],
          ),
          Cta('Mark ${fmt(r.amt)} refunded', key: const ValueKey('refundGo'), icon: 'check', height: 54, px: 16, fs: 15, opacity: ok ? 1 : .4, onTap: s.sendRefund),
          T('$first confirms in the app. If they say it didn’t come, Hostelzy asks you for this UPI reference. Due by ${dayMon(r.due)}, 7 days after they left.${late ? ' It’s late now.' : ''}', s: 13, c: late ? p.ad : p.mu, lh: 1.45),
        ],
      ),
    );
  }
}

class ResidentRefundScreen extends StatelessWidget {
  const ResidentRefundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final r = s.myRefund;
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: r == null ? 'Your stay' : '${hostelById(r.hid).name} · left ${dayMon(r.leftOn)}', title: 'Your refund', gap: 2))],
      ),
    );
    if (r == null) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: T('No refund waiting.', s: 14, c: p.mu))]);
    final h = hostelById(r.hid);
    final owner = h.owner.trim().isEmpty ? 'Your owner' : h.owner;
    final sent = r.status == 'sent';
    final (kicker, line) = switch (r.status) {
      'sent' => ('$owner marked it refunded${r.sentOn == null ? '' : ' · ${dayMon(r.sentOn!)}'}', '${r.phone.length == 10 ? 'To +91 ${phoneSpaced(r.phone)} · ' : ''}UPI ref. ${utrSpaced(r.utr)}'),
      'not_received' => ('You said it hasn’t arrived', '$owner is told. They check and send it again.'),
      _ => ('Due by ${dayMon(r.due)}', '$owner marks it here when it’s sent.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(
          child: Scroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: sent ? const ValueKey('refundSent') : null,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  color: p.sf,
                  child: VGap(gap: 10, children: [Kicker(kicker, c: p.mu), T(fmt(r.amt), w: 800, s: 44, lh: 1), T(line, s: 14, lh: 1.4)]),
                ),
                const SizedBox(height: 12),
                _rows(context, [('Advance', fmt(r.advance)), ('Kept on leaving', '− ${fmt(r.advance - r.amt)}'), ('Due by', dayMon(r.due))]),
                if (sent)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: VGap(gap: 8, children: [T('Did ${fmt(r.amt)} reach your bank?', w: 800, s: 17), T('Check your bank app for the UPI reference above.', s: 13, c: p.mu, lh: 1.45)]),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 8,
            children: [
              if (sent) ...[
                Cta('Yes, I got ${fmt(r.amt)}', key: const ValueKey('refundYes'), icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.confirmRefund(true)),
                OutlineCta('Not received', key: const ValueKey('refundNo'), icon: 'x', onTap: () => s.confirmRefund(false)),
              ] else
                OutlineCta('Message $owner', icon: 'msg', onTap: () => s.whatsapp(s.ownerPhoneFor(r.hid), 'Hi $owner, about my ${fmt(r.amt)} advance refund for bed ${r.bed}.')),
            ],
          ),
        ),
      ],
    );
  }
}
