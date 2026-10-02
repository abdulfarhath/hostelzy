import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F17 payments: pay the owner by UPI → enter the UTR → the owner confirms →
// only then Booked / Paid. Boards 1–6 of the Make It Real canvas.

/// Pay by UPI · Enter UTR · Owner confirms · Booked (or Paid).
class PaySteps4 extends StatelessWidget {
  const PaySteps4(this.p, {super.key, this.at});
  final Payment p;

  /// Force the current step (the UTR sheet is step 2).
  final int? at;
  @override
  Widget build(BuildContext context) {
    final c = PalScope.of(context);
    final steps = ['Pay by UPI', 'Enter UTR', 'Owner confirms', p.kind == 'rent' ? 'Paid' : 'Booked'];
    final cur = at ??
        switch (p.status) {
          'waiting' || 'missing' => 2,
          'paid' => 3,
          _ => 0,
        };
    return Container(
      decoration: box(w: 2, c: c.tx),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == cur ? (p.status == 'missing' ? c.ad : c.ac) : i < cur ? c.tx : null, border: i > 0 ? Border(left: bs(1, c.hl)) : null),
                  child: T(steps[i], s: 11, w: 800, lh: 1.2, align: TextAlign.center, c: i == cur ? c.ai : i < cur ? c.bg : c.mu),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _shieldNote(BuildContext context, List<InlineSpan> spans) {
  final p = PalScope.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: Rich(spans, s: 12, c: p.mu, lh: 1.45))],
  );
}

/// Board 1: pay the advance (sheet `payAdv`).
class PayAdvSheet extends StatelessWidget {
  const PayAdvSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final pay = s.pay;
    if (pay == null) return const SizedBox();
    final h = hostelById(pay.hid);
    final upi = s.ownerUpi[pay.hid]!;
    Widget line(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(children: [T(k, s: 14, c: p.mu), const SizedBox(width: 12), Expanded(child: T(v, s: 14, w: 800, align: TextAlign.right))]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          PaySteps4(pay),
          Container(
            decoration: box(w: 2, c: p.tx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line('Advance (refundable)', fmt(pay.amt)),
                line('Pay to', '${upi.name} · ${upi.id}'),
                line('UPI note', pay.note),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: p.tx,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Expanded(child: T('Pay ${h.owner}', w: 800, s: 15, c: p.bg)), T(fmt(pay.amt), w: 800, s: 26, c: p.bg)]),
                ),
              ],
            ),
          ),
          _shieldNote(context, [sp(context, 'You pay ${h.owner} directly. Hostelzy never holds your money. The bed says '), sp(context, 'Booked', w: 800, c: p.tx), sp(context, ' only after ${h.owner} confirms the money arrived.')]),
          Cta('Pay ${fmt(pay.amt)} by UPI', height: 54, px: 16, fs: 15, onTap: () => s.payByUpi(pay)),
          OutlineCta('I’ve already paid · enter UTR', icon: 'chev', onTap: () => s.openPayUtr(pay)),
        ],
      ),
    );
  }
}

/// Board 2: enter the UTR (sheet `payUtr`, advance or rent).
class PayUtrSheet extends StatelessWidget {
  const PayUtrSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final pay = s.pay;
    if (pay == null) return const SizedBox();
    final owner = hostelById(pay.hid).owner;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          PaySteps4(pay, at: 1),
          VGap(
            gap: 6,
            children: [
              const T('12-digit UTR from your UPI app', w: 800, s: 13),
              Field(
                value: s.payUtr,
                numeric: true,
                placeholder: '4021 8834 1297',
                onChanged: (v) => s.update(() {
                  final d = v.replaceAll(RegExp(r'\D'), '');
                  s.payUtr = d.length > 12 ? d.substring(0, 12) : d;
                }),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: p.sf,
            child: Rich([sp(context, 'Where to find it:', w: 800), sp(context, ' open the payment in your UPI app → details → '), sp(context, 'UTR', w: 800), sp(context, ' or '), sp(context, 'UPI Ref. No.', w: 800)], s: 13, lh: 1.45),
          ),
          _shieldNote(context, [sp(context, '$owner checks this number in their bank or UPI app. No screenshots needed.')]),
          Cta('Send to $owner', height: 54, px: 16, fs: 15, opacity: s.payUtr.length == 12 ? 1 : .4, onTap: s.sendPayUtr),
        ],
      ),
    );
  }
}

/// Board 4: "Received ₹3,000?" on owner Today, for advances and rent.
class PaymentsToCheck extends StatelessWidget {
  const PaymentsToCheck({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = s.payments.where((x) => x.hid == s.ownHid && x.status == 'waiting').toList();
    if (list.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('Payments to check'), T('${list.length} waiting', s: 12, w: 800, c: p.ad)]),
          ),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final x in list)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [Expanded(child: T('Received ${fmt(x.amt)}?', w: 800, s: 18)), Tag('Check your bank', bg: p.ab, fg: p.ad)]),
                              const SizedBox(height: 4),
                              T('${x.who} · ${x.what}${x.kind == 'rent' ? ' · bed ${x.bed}' : ''}', s: 13, c: p.mu),
                            ],
                          ),
                        ),
                        KV('UTR', utrSpaced(x.utr ?? ''), keyWidth: 70),
                        KV('UPI note', x.note, keyWidth: 70),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(child: Cta('Yes, received', icon: 'check', height: 46, px: 14, fs: 14, onTap: () => s.confirmPayment(x, true))),
                              const SizedBox(width: 8),
                              Cta('Not received', icon: 'x', height: 46, px: 14, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.confirmPayment(x, false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _shieldNote(context, [sp(context, 'Open your bank or UPI app and look for this UTR. Tap “Yes, received” only when you see the money. The tenant sees “Booked” or “Paid” only after that.')]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Board 6: Manage → Rates, "Where tenants pay you".
class UpiCard extends StatelessWidget {
  const UpiCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final u = s.ownerUpi[s.ownHid]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: VGap(
        gap: 10,
        children: [
          const Kicker('Where tenants pay you'),
          VGap(gap: 6, children: [const T('Your UPI ID', w: 800, s: 13), Field(key: const ValueKey('upiId'), value: u.id, placeholder: 'name@bank', onChanged: (v) => s.setOwnerUpi(v.trim(), u.name))]),
          VGap(gap: 6, children: [const T('Name shown in UPI', w: 800, s: 13), Field(key: const ValueKey('upiName'), value: u.name, onChanged: (v) => s.setOwnerUpi(u.id, v))]),
          OutlineCta('Test with ₹1', icon: 'chev', height: 48, fs: 14, onTap: () => s.openLink(upiUri(id: u.id, name: u.name, amt: 1, note: 'Hostelzy test'), 'a UPI app')),
          T('Pays you ₹1 from your own phone to check it works.', s: 12, c: p.mu),
          _shieldNote(context, [sp(context, 'Advances and rent go straight to this UPI ID. Hostelzy never holds the money; you confirm each payment in the app.')]),
          if (u.id.startsWith('sample.')) T('This is a sample ID. Type your own before tenants pay you.', s: 12, w: 800, c: p.ad),
          // F18 (F11): name@bank, e.g. srinivas@okaxis or 98xxxxxx10@ybl.
          if (u.id.isNotEmpty && !validUpiId(u.id)) T('That isn’t a UPI ID. It looks like name@bank (for example srinivas@okaxis).', s: 12, w: 800, c: p.ad),
        ],
      ),
    );
  }
}
