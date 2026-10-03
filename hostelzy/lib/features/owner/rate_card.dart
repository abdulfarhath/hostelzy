import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../payments/payments_sheets.dart';

/// Placeholder QR (25×25 modules, three finder squares), as in the design.
/// The real code comes with the backend.

// ------------------------------------------------------------ F16 rate card

/// F16 rate card, F22 Area 3 `rates`: one table (room type / walk-in /
/// Hostelzy price), one UPI ID, "Rooms and floors ›", then which rooms have
/// AC. Saved with the Save button under it (OwnerManageScreen).
class RateCard extends StatelessWidget {
  const RateCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.rateDraft ?? s.rates[s.ownHid]!;
    final acd = s.acDraft ?? {for (final r in s.rooms[s.ownHid]!) r.n: r.ac};
    final rooms = s.rooms[s.ownHid]!.where((r) => r.floor == s.rcFloor).toList();
    final floors = floorsOf(s.rooms[s.ownHid]!);
    final deal = s.dealsOf(s.ownHid);
    final types = [for (final n in [2, 3, 4]) for (final ac in [false, true]) (n: n, ac: ac)];
    String name(int n, bool ac) => '$n sharing${ac ? ' AC' : ''}';
    const priceW = 100.0, hzW = 90.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Css(s: 13, c: p.mu, child: const Row(children: [Expanded(child: T('Room type')), SizedBox(width: 10), SizedBox(width: priceW, child: T('Walk-in')), SizedBox(width: 10), SizedBox(width: hzW, child: T('Hostelzy'))])),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in types)
                if (d[rateKey(t.ac, t.n)] case final v?)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(child: T(name(t.n, t.ac), w: 800, s: 15)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: priceW,
                          child: Semantics(
                            label: 'Walk-in price, ${t.n} sharing ${t.ac ? 'AC' : 'Non-AC'}',
                            child: Field(
                              value: fmt(v),
                              height: 44,
                              w: 800,
                              pad: const EdgeInsets.symmetric(horizontal: 8),
                              numeric: true,
                              onChanged: (x) {
                                final dg = x.replaceAll(RegExp(r'\D'), '');
                                s.update(() => s.rateDraft![rateKey(t.ac, t.n)] = int.tryParse(dg.length > 6 ? dg.substring(0, 6) : dg) ?? 0);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // F03: the Hostelzy price is the walk-in price minus any monthly deal.
                        () {
                          final off = deal.covers(t.ac) && deal.on.contains('monthly');
                          return SizedBox(width: hzW, child: T(fmt(off ? v - monthlyOff : v), w: 800, s: 15, c: off ? p.gn : p.tx));
                        }(),
                      ],
                    ),
                  ),
              // Types not offered yet: one line each, to add a price.
              for (final t in types)
                if (d[rateKey(t.ac, t.n)] == null)
                  Tap(
                    onTap: () => s.addRate(t.ac, t.n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(children: [Expanded(child: Rich([sp(context, name(t.n, t.ac), w: 800, c: p.mu), sp(context, ' · not offered', c: p.mu)], s: 14)), T('+ Add', s: 14, w: 800, c: p.ad)]),
                    ),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: T(deal.on.contains('monthly') ? 'Green: ${fmt(monthlyOff)} a month off with your Hostelzy deal, ${deal.targetText}.' : 'Hostelzy price is the walk-in price until you add a monthly deal.', s: 13, c: p.mu),
        ),
        // F17: where tenants pay the owner.
        const UpiCard(),
        Tap(
          key: const ValueKey('roomsFloors'),
          onTap: () => s.go('oRooms'),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Align(alignment: Alignment.centerLeft, child: T('Rooms and floors ›', s: 14, w: 800)),
          ),
        ),
        // Which rooms have AC (F16): kept here so the rate card saves both together.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Expanded(child: Kicker('AC rooms · Floor ${s.rcFloor}')),
              for (final f in floors)
                Tap(
                  key: ValueKey('rcFloor-$f'),
                  onTap: () => s.update(() => s.rcFloor = f),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(left: 4),
                    alignment: Alignment.center,
                    decoration: box(bg: f == s.rcFloor ? p.tx : transparent, w: 1, c: f == s.rcFloor ? p.tx : p.dv),
                    child: T('$f', s: 13, w: 800, c: f == s.rcFloor ? p.bg : p.tx),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in rooms)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('Room ${r.label}', w: 800, s: 15),
                            T('${r.share} sharing · ${d[rateKey(acd[r.n]!, r.share)] != null ? '${fmt(d[rateKey(acd[r.n]!, r.share)]!)} walk-in' : 'no price yet'}', s: 13, c: p.mu),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: Seg(opts: const [('non', 'Non-AC'), ('ac', 'AC')], cur: acd[r.n]! ? 'ac' : 'non', onPick: (v) => s.setRoomAc(r, v == 'ac'), pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 6), center: true),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: T('An AC room needs an AC unit in its layout. If a room’s layout has none, add it there and publish first, then make the room AC.', s: 13, c: p.mu, lh: 1.4),
        ),
      ],
    );
  }
}
