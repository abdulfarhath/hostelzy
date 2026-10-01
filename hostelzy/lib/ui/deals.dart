import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F03 Hostelzy deals: the tenant's deal table on the hostel page (board 1 and
// F16 board 6) and the owner's deal picker (board 4).

/// Room type and sharing the hostel page's deal table shows.
({bool ac, int share}) dealView(AppState s, Hostel h) {
  final d = s.dealsOf(h.id);
  final kinds = [if (h.hasNon) false, if (h.ac) true];
  final ac = s.dealAc != null && kinds.contains(s.dealAc) ? s.dealAc! : kinds.firstWhere(d.covers, orElse: () => kinds.first);
  final shares = s.rooms[h.id]!.where((r) => r.ac == ac).map((r) => r.share).toSet();
  return (ac: ac, share: shares.contains(3) ? 3 : (shares.toList()..sort()).first);
}

class DealBlock extends StatelessWidget {
  const DealBlock(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.dealsOf(h.id);
    final v = dealView(s, h);
    final q = s.quote(h.id, v.ac, v.share);
    final both = h.ac && h.hasNon;
    final kinds = [if (h.hasNon) false, if (h.ac) true];
    String typeName(bool ac) => ac ? 'AC' : 'Non-AC';
    int shareOf(bool ac) {
      final sh = s.rooms[h.id]!.where((r) => r.ac == ac).map((r) => r.share).toSet();
      return sh.contains(3) ? 3 : (sh.toList()..sort()).first;
    }

    Widget row(String k, String hz, String walk, {bool strike = false, bool small = false}) => Container(
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 125, child: Padding(padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12), child: T(k, s: 13, c: p.mu))),
            Expanded(flex: 100, child: Container(color: p.gb, padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10), child: T(hz, s: small ? 13 : 15, w: 800))),
            Expanded(
              flex: 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                child: Text(walk, style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14, color: p.mu, decoration: strike ? TextDecoration.lineThrough : null, decorationColor: p.mu)),
              ),
            ),
          ],
        ),
      ),
    );

    final exitLine = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Ic('shieldOk', size: 16, color: p.gn)),
          const SizedBox(width: 8),
          Expanded(
            child: Rich([
              sp(context, 'Exit rules locked when you book: '),
              sp(context, '${fmt(q.hzExit)} maintenance, ${h.terms.noticeDays} days notice', w: 800, c: p.tx),
              sp(context, '. Hostelzy steps in if they change.'),
            ], s: 12, c: p.mu, lh: 1.4),
          ),
        ],
      ),
    );
    if (d.on.isEmpty) return Padding(padding: const EdgeInsets.only(bottom: 14), child: exitLine);

    final covered = d.covers(v.ac);
    final other = kinds.where((k) => k != v.ac && d.covers(k)).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (both)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Seg(opts: [for (final k in kinds) (k ? 'ac' : 'non', '${typeName(k)} · ${shareOf(k)} sharing')], cur: v.ac ? 'ac' : 'non', onPick: (x) => s.update(() => s.dealAc = x == 'ac'), pad: const EdgeInsets.all(10)),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: box(w: 2, c: p.tx),
            child: covered
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: p.gn,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            T(both ? 'Hostelzy deal · ${typeName(v.ac)}' : 'Hostelzy deal', w: 800, s: 15, c: p.ai),
                            T('Confirmed by owner · ${d.confirmed}', s: 12, w: 600, c: p.ai),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(flex: 125, child: SizedBox()),
                              Expanded(flex: 100, child: Container(color: p.gb, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), child: T('With Hostelzy', s: 11, w: 800, ls: .06, upper: true, c: p.gn))),
                              Expanded(flex: 100, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), child: T('Walk in', s: 11, w: 600, ls: .06, upper: true, c: p.mu))),
                            ],
                          ),
                        ),
                      ),
                      row('Monthly fee', fmt(q.hzFee), fmt(q.fee), strike: q.hzFee != q.fee),
                      if (q.firstOffNow > 0) row('First month', fmt(q.hzFirst), fmt(q.fee), strike: true),
                      row('Advance', fmt(q.hzAdv), fmt(q.adv), strike: q.hzAdv != q.adv),
                      if (q.join > 0) row('Joining fee', '₹0', fmt(q.join), strike: true),
                      row('To move in', fmt(q.hzMove), fmt(q.move), strike: q.hzMove != q.move),
                      row('Exit maintenance', fmt(q.hzExit), fmt(q.exit), strike: q.hzExit != q.exit),
                      row('Back when you leave', fmt(q.hzBack), fmt(q.back)),
                      if (q.laundry) row('Extra', 'Free laundry weekly', '—', small: true),
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Kicker(q.save6 > 0 ? 'You save in the first 6 months' : q.upfront > 0 ? 'Less to pay upfront' : 'More back when you leave'),
                                  const SizedBox(height: 2),
                                  T(fmt(q.save6 > 0 ? q.save6 : q.upfront > 0 ? q.upfront : q.moreBack), w: 800, s: 34, lh: 1, ls: -.03, c: p.gn),
                                  if (q.save6 > 0 && (q.upfront > 0 || q.hzFee < q.fee)) ...[
                                    const SizedBox(height: 2),
                                    T([if (q.upfront > 0) '${fmt(q.upfront)} less to move in', if (q.hzFee < q.fee) '${fmt(q.fee - q.hzFee)}/month'].join(' + '), s: 12, w: 600, c: p.gn),
                                  ],
                                ],
                              ),
                            ),
                            if (q.moreBack > 0 && q.save6 + q.upfront > 0) ...[
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [T('Plus ${fmt(q.moreBack)} more', s: 12, c: p.mu), T('back when you leave', s: 12, c: p.mu)]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('No Hostelzy deal on ${v.ac ? 'AC' : 'non-AC'} rooms', w: 800, s: 15),
                            const SizedBox(height: 4),
                            T(other != null ? "The owner's deal covers ${other ? 'AC' : 'non-AC'} rooms only. You pay the walk-in price here." : 'You pay the walk-in price here.', s: 13, c: p.mu, lh: 1.4),
                          ],
                        ),
                      ),
                      for (final (k, x) in [('Monthly fee', q.fee), ('Advance', q.adv), ('To move in', q.move)])
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T(k, s: 14, c: p.mu), T(fmt(x), s: 14, w: 800)]),
                        ),
                      if (other != null)
                        Tap(
                          onTap: () => s.update(() => s.dealAc = other),
                          child: Padding(padding: const EdgeInsets.all(12), child: T('See the deal on ${other ? 'AC' : 'non-AC'} rooms', s: 13, w: 800, c: p.gn)),
                        ),
                    ],
                  ),
          ),
          exitLine,
        ],
      ),
    );
  }
}

/// F03 board 4: the owner picks up to 3 deals (Manage → Deals).
class OwnerDeals extends StatelessWidget {
  const OwnerDeals({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostels[0];
    final on = s.dealDraft ?? s.dealsOf(h.id).on;
    final t = h.terms;
    final ref = s.rates[h.id]![rateKey(false, 3)] ?? h.from;
    final q = DealQuote(t, ref, on);
    final cost = <String, int>{'exit': ((t.maintenance - exitHz).clamp(0, 1 << 20) / 12).round(), 'monthly': monthlyOff, 'first': (firstOff / 12).round(), 'advance': 0, 'laundry': laundryCost, 'noadmin': (joiningFee / 12).round()};
    String costTxt(String id) => cost[id] == 0 ? 'No cost' : id == 'monthly' ? '${fmt(monthlyOff)}/mo' : '≈ ${fmt(cost[id]!)}/mo';
    String sub(String id) => switch (id) {
      'exit' => '${fmt(t.maintenance)} → ${fmt(exitHz)} when they leave',
      'monthly' => '${fmt(ref)} → ${fmt(ref - monthlyOff)}',
      'first' => '${fmt(firstOff)} off the first month',
      'advance' => '${fmt(t.advance)} → ${fmt(t.advance - advanceOff)} to book',
      'laundry' => 'Laundry once a week',
      _ => 'Waive the one-time ${fmt(joiningFee)} fee',
    };
    String tenant(String id) => switch (id) {
      'exit' => '${fmt(t.maintenance - exitHz)} back',
      'monthly' => '${fmt(monthlyOff * 6)} in 6 mo',
      'first' => '${fmt(firstOff)} once',
      'advance' => '${fmt(advanceOff)} less upfront',
      'laundry' => 'Free laundry',
      _ => '${fmt(joiningFee)} once',
    };
    final n = on.length;
    final costSum = on.fold<int>(0, (a, id) => a + cost[id]!);
    final strength = n == 0 ? 'None' : (q.save6 >= 1500 || n == maxDeals) ? 'Strong' : q.save6 >= 800 ? 'Good' : 'Basic';
    final rank = switch (strength) {
      'Strong' => 'Top deals near ${s.lm}',
      'Good' => 'Shown in Best deals',
      _ => 'Add a deal to rank higher',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: VGap(
            gap: 4,
            children: [
              Kicker('3 sharing · walk-in ${fmt(ref)}'),
              const T('Your Hostelzy deals', w: 800, s: 24, lh: 1.05, ls: -.02),
              T("Pick up to $maxDeals. Tenants who book through Hostelzy get them; walk-ins don't.", s: 13, c: p.mu, lh: 1.4),
            ],
          ),
        ),
        if (h.ac && h.hasNon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Seg(opts: const [('all', 'All rooms'), ('ac', 'AC only'), ('non', 'Non-AC only')], cur: s.dealTarget, onPick: (v) => s.update(() => s.dealTarget = v), pad: const EdgeInsets.all(10)),
          ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in dealMenu)
                Tap(
                  onTap: () => s.toggleDeal(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                    decoration: BoxDecoration(color: on.contains(id) ? p.gb : null, border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: box(bg: on.contains(id) ? p.tx : transparent, w: 2, c: p.tx),
                          child: on.contains(id) ? Ic('check', size: 14, color: p.bg) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(dealTitle[id]!, w: 800, s: 15), const SizedBox(height: 1), T(sub(id), s: 12, c: p.mu)]),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [T(tenant(id), s: 12, w: 800, c: p.gn), const SizedBox(height: 1), T(costTxt(id), s: 11, c: p.mu)]),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(children: [Ic('shield', size: 16, color: p.gn), const SizedBox(width: 8), Expanded(child: T('Always on: exit rules written at booking. Costs you nothing.', s: 12, c: p.mu))]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: VGap(
            gap: 10,
            children: [
              Container(
                color: p.hl,
                padding: const EdgeInsets.all(1),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: p.gb,
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Tenant saves · 6 months', s: 10, w: 600, ls: .08, upper: true, c: p.gn), T(fmt(q.save6), w: 800, s: 24, c: p.gn)]),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Expanded(
                        child: Container(
                          color: p.bg,
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T('Costs you / month', s: 10, w: 600, ls: .08, upper: true, c: p.mu), T(fmt(costSum), w: 800, s: 24)]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VGap(
                gap: 5,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T('$n of $maxDeals picked · $strength', s: 12, w: 800), T(rank, s: 12, c: p.mu)]),
                  Container(
                    height: 10,
                    decoration: box(w: 2, c: p.tx),
                    child: LayoutBuilder(builder: (context, c) => Row(children: [Container(width: c.maxWidth * n / maxDeals, color: p.gn)])),
                  ),
                  T('One empty bed costs you ${fmt(ref)} a month.', s: 12, c: p.mu),
                ],
              ),
              Cta('Publish deals', icon: 'check', height: 52, px: 16, fs: 15, onTap: s.publishDeals),
            ],
          ),
        ),
      ],
    );
  }
}
