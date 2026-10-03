import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// F22 Area 2 (board `rPay`): one amount card, a few rows, one or two
/// actions at the bottom. Due → Waiting for owner → Paid (card goes dark).
class RentPayScreen extends StatelessWidget {
  const RentPayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final st = s.myStay;
    if (st == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: PageHead(kicker: 'Your stay', title: 'Rent'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: T('Your stay isn’t on Hostelzy yet. Once your owner adds you, your rent shows here.', s: 14, c: p.mu, lh: 1.45),
          ),
        ],
      );
    }
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final terms = h.terms;
    // F21: the month's real rent; on the server nothing exists until the resident starts paying.
    // F24 #25: this month's electricity (board `rentMeter`) is added to the rent.
    final meter = s.myMeter;
    final elec = s.myElectricity;
    final rent = s.myRentPay ?? Payment(id: '', kind: 'rent', hid: st.hid, who: s.meShort, what: 'Rent', bed: st.bed, amt: st.rent + elec, note: s.rentNote);
    final started = rent.id.isNotEmpty;
    final sample = !s.onServer;
    final history = sample ? [('September', '₹8,040 · confirmed 3 Sep'), ('August', '₹7,980 · confirmed 4 Aug'), ('July', '₹8,110 · confirmed 2 Jul')] : const <(String, String)>[];
    final advance = sample ? terms.advance : s.myStayRow?.advance ?? 0;
    final upi = s.ownerUpi[st.hid]?.id ?? '';
    final month = monthYear(appToday).split(' ').first;
    final paid = rent.status == 'paid';
    final (label, line) = switch (rent.status) {
      'paid' => ('$month rent · Paid', '$owner confirmed on ${rent.done}. Thank you.'),
      'waiting' => ('Waiting for $owner', 'You sent UPI reference ${utrSpaced(rent.utr ?? '')}. It says Paid once $owner sees it.'),
      'missing' => ('Not received', '$owner couldn’t find UPI reference ${utrSpaced(rent.utr ?? '')}. Check it in your UPI app.'),
      _ => ('$month rent', '${dueNote(terms, st.joinDay)} · ${dueLeft(terms, st.joinDay)}'),
    };
    void remind() => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, I paid ${fmt(rent.amt)} rent for bed ${st.bed} by UPI. UPI reference ${utrSpaced(rent.utr ?? '')}. Please confirm on Hostelzy.');
    final actions = <Widget>[
      if (rent.status == 'due') ...[
        Cta('Pay ${fmt(rent.amt)} by UPI', height: 54, px: 16, fs: 15, onTap: s.payMyRent),
        if (started) OutlineCta('I’ve paid · enter UPI reference', icon: 'chev', onTap: () => s.openPayUtr(rent)),
      ],
      if (rent.status == 'waiting') ...[
        Cta('Remind $owner', icon: 'msg', height: 54, px: 16, fs: 15, onTap: remind),
        OutlineCta('Fix the UPI reference', icon: 'chev', onTap: () => s.openPayUtr(rent)),
      ],
      if (rent.status == 'missing') ...[
        Cta('Fix the UPI reference', height: 54, px: 16, fs: 15, onTap: () => s.openPayUtr(rent)),
        OutlineCta('Talk to $owner on WhatsApp', icon: 'msg', onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, about my rent for bed ${st.bed}: UPI reference ${utrSpaced(rent.utr ?? '')}.')),
      ],
      if (paid)
        Cta(
          'Share receipt',
          icon: 'msg',
          height: 54,
          px: 16,
          fs: 15,
          onTap: () => s.share('Rent receipt · ${h.name} · bed ${st.bed} · ${monthYear(appToday)} · ${fmt(rent.amt)} · UPI ref. ${utrSpaced(rent.utr ?? '')} · confirmed by $owner on ${rent.done}'),
        ),
    ];
    Widget row(String k, String v) => KV(k, v, keyWidth: 130);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scroll(
            key: ValueKey('rPay${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: PageHead(kicker: '${h.name}${st.bed.isEmpty ? '' : ' · Bed ${st.bed}'}', title: 'Rent'),
                ),
                Container(
                  key: const ValueKey('rentCard'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  padding: const EdgeInsets.all(16),
                  color: paid ? p.tx : p.sf,
                  child: Css(
                    c: paid ? p.bg : p.tx,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Kicker(label, c: paid ? p.bg : p.tx),
                        const SizedBox(height: 4),
                        T(fmt(rent.amt), w: 800, s: 52, lh: 1.05, ls: -.03, tab: true),
                        const SizedBox(height: 6),
                        T(line, s: 14, w: rent.status == 'due' || rent.status == 'missing' ? 800 : 400, c: paid ? p.bg : (rent.status == 'waiting' ? p.tx : p.ad), lh: 1.4),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row('Rent', fmt(sample ? rent.amt - elec : st.rent)),
                      if (meter != null)
                        KV('Electricity · ${meter.units} units ÷ ${meter.people} · ${perUnit(meter.rate)}/unit', fmt(elec), key: const ValueKey('rentMeter'), keyWidth: 150)
                      else if (terms.electricityExtra)
                        row('Electricity', 'Not added yet'),
                      row('Pay to', upi.isEmpty ? '$owner hasn’t added a UPI ID yet' : upi),
                    ],
                  ),
                ),
                if (history.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Paid before')),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final x in history) row(x.$1, x.$2)]),
                  ),
                ],
                if (advance > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: T('Advance ${fmt(advance)} · ${fmt(math.max(0, advance - terms.maintenance))} back when you leave', s: 14),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: T('You pay $owner directly. Hostelzy never holds the money.', s: 12, c: p.mu, lh: 1.4),
                ),
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: p.bg,
              border: Border(top: bs(2, p.tx)),
            ),
            child: VGap(gap: 8, children: actions),
          ),
      ],
    );
  }
}
