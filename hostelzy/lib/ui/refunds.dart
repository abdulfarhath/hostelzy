import 'package:flutter/material.dart';
import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F24 item 5: the advance refund after a resident moves out. The owner marks
// it refunded with the UPI reference (board `oRefund`); the former resident
// says whether it arrived (board `rRefund`).

Widget _frame(BuildContext context, {required String kicker, required String title, required List<Widget> body, required List<Widget> foot}) {
  final s = AppScope.of(context);
  final p = PalScope.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title, size: 28))],
        ),
      ),
      Expanded(
        child: Scroll(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: VGap(gap: 12, children: body),
          ),
        ),
      ),
      if (foot.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(gap: 8, children: foot),
        ),
    ],
  );
}

Widget _rows(BuildContext context, List<(String, String)> rows) {
  final p = PalScope.of(context);
  return Container(
    decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, v) in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: Row(children: [Expanded(child: T(k, s: 14, c: p.mu)), const SizedBox(width: 12), Flexible(child: T(v, w: 800, s: 15, align: TextAlign.right))]),
          ),
      ],
    ),
  );
}

class OwnerRefundScreen extends StatelessWidget {
  const OwnerRefundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final r = s.refundOpen;
    if (r == null) return Padding(padding: const EdgeInsets.all(16), child: T('Nothing to refund right now.', s: 14, c: p.mu));
    final first = r.name.split(' ').first;
    final late = r.due.isBefore(appToday);
    return _frame(
      context,
      kicker: '${r.name} · bed ${r.bed}',
      title: 'Refund the advance',
      body: [
        _rows(context, [
          ('Advance', fmt(r.advance)),
          ('Kept', fmt(r.advance - r.amt)),
          ('Refund', fmt(r.amt)),
          ('Pay to', r.phone.length == 10 ? '+91 ${phoneSpaced(r.phone)} (UPI)' : 'Ask $first for their UPI ID'),
          ('Due', '${dayMon(r.due)}${late ? ' · late' : ''}'),
        ]),
        T('Moved out ${dayMon(r.leftOn)}. Refunds are due 7 days after leaving.', s: 13, c: late ? p.ad : p.mu),
        if (r.status == 'not_received') T('$first says it hasn’t arrived. Check your bank, then send it again.', s: 14, w: 800, c: p.ad),
        VGap(
          gap: 6,
          children: [
            const T('UPI reference (12 digits)', w: 800, s: 13),
            Field(key: const ValueKey('refundUtr'), value: s.refundUtr, numeric: true, placeholder: 'From your UPI app, after paying', onChanged: (v) => s.update(() => s.refundUtr = v)),
          ],
        ),
        T('$first is asked to confirm it arrived.', s: 13, c: p.mu),
      ],
      foot: [
        Cta('Mark ${fmt(r.amt)} refunded', key: const ValueKey('refundGo'), icon: 'check', height: 54, px: 16, fs: 15, opacity: s.refundUtr.replaceAll(RegExp(r'\D'), '').length == 12 ? 1 : .4, onTap: s.sendRefund),
        OutlineCta('Message $first', icon: 'msg', height: 48, fs: 14, onTap: () => s.openWA(r.name, 'Hi $first, about your ${fmt(r.amt)} advance refund from ${hostelById(r.hid).name}.', phone: r.phone)),
      ],
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
    if (r == null) return Padding(padding: const EdgeInsets.all(16), child: T('No refund waiting.', s: 14, c: p.mu));
    final h = hostelById(r.hid);
    final owner = h.owner.trim().isEmpty ? 'Your owner' : h.owner;
    final sent = r.status == 'sent';
    return _frame(
      context,
      kicker: '${h.name} · bed ${r.bed}',
      title: sent ? 'Did you get ${fmt(r.amt)}?' : 'Your refund',
      body: [
        if (sent)
          Container(
            key: const ValueKey('refundSent'),
            padding: const EdgeInsets.all(12),
            decoration: box(w: 2, c: p.tx),
            child: VGap(gap: 4, children: [T('$owner marked it refunded', w: 800, s: 16), T('UPI ref ${utrSpaced(r.utr)}. Check your bank app.', s: 14, c: p.mu)]),
          )
        else
          T(r.status == 'not_received' ? 'You told $owner it hasn’t arrived. They check and send it again.' : '${fmt(r.amt)} is due by ${dayMon(r.due)}. $owner marks it here when it’s sent.', s: 15, lh: 1.45),
        _rows(context, [('Advance', fmt(r.advance)), ('Kept', fmt(r.advance - r.amt)), ('Refund', fmt(r.amt)), ('Moved out', dayMon(r.leftOn))]),
      ],
      foot: [
        if (sent) ...[
          Cta('Yes, I got ${fmt(r.amt)}', key: const ValueKey('refundYes'), icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.confirmRefund(true)),
          OutlineCta('Not received', key: const ValueKey('refundNo'), icon: 'x', height: 48, fs: 14, onTap: () => s.confirmRefund(false)),
        ] else
          OutlineCta('Message $owner', icon: 'msg', height: 48, fs: 14, onTap: () => s.whatsapp(s.ownerPhoneFor(r.hid), 'Hi $owner, about my ${fmt(r.amt)} advance refund for bed ${r.bed}.')),
      ],
    );
  }
}
