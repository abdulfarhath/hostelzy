import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F24 Wave 1 (Main design v22): electricity by meter (`oMeter`), laundry day
// (`oLaundry`) and what a Trusted tenant gets (`trustedPerks`).

/// Board `oMeter`: Rent › Electricity. One "Now" reading per room; the units
/// since last month are split between the residents in the room.
class OwnerMeterScreen extends StatelessWidget {
  const OwnerMeterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final month = monthYear(appToday).split(' ').first;
    final rooms = s.rooms[s.ownHid] ?? const <Room>[];
    final (typed, all) = s.meterCount;
    Widget cols(List<Widget> c) => Row(children: [SizedBox(width: 64, child: c[0]), const SizedBox(width: 8), SizedBox(width: 76, child: c[1]), const SizedBox(width: 8), SizedBox(width: 86, child: c[2]), const SizedBox(width: 8), Expanded(child: c[3])]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Rent · $month', title: 'Electricity', size: 30, gap: 2))],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oMeter${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: T('Type each room’s meter now. We split it between the residents in the room.', s: 13, c: p.mu, lh: 1.45)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: VGap(gap: 6, children: [const T('₹ per unit', w: 800, s: 13), Field(key: const ValueKey('meterRate'), value: s.meterRate, numeric: true, onChanged: (v) => s.update(() => s.meterRate = v))]),
                      ),
                    ],
                  ),
                ),
                if (s.meterOff)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: T('Electricity by meter starts after Hostelzy’s next server update. Last month’s readings show here then.', s: 13, w: 800, c: p.ad, lh: 1.4)),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: cols([T('Room', s: 12, c: p.mu), T('Last month', s: 12, c: p.mu), T('Now', s: 12, c: p.mu), T('Units · each', s: 12, c: p.mu, align: TextAlign.right)]),
                ),
                for (final r in rooms)
                  () {
                    final last = s.meterOf(r.n, last: true)?.reading;
                    final now = (s.meterNow[r.n] ?? '').trim();
                    final units = s.meterUnits(r.n), each = s.meterEach(r.n), n = s.peopleIn(r.n);
                    final (top, sub) = now.isEmpty
                        ? ('Type it', '')
                        : last == null
                        ? ('First reading', 'Units from next month')
                        : units == null
                        ? ('Check it', 'Lower than last month')
                        : ('$units units', each != null ? '${fmt(each)} each' : n == 0 ? 'No one in' : 'Type ₹ per unit');
                    return Container(
                      key: ValueKey('meterRow-${r.n}'),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: cols([
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(r.label, w: 800, s: 15), T('$n in', s: 12, c: p.mu)]),
                        T(last == null ? '—' : grouped(last), s: 14, c: p.mu),
                        Semantics(
                          label: 'Meter now, room ${r.label}',
                          child: Container(
                            decoration: box(w: 2, c: now.isEmpty ? p.ad : p.tx),
                            child: Field(key: ValueKey('meter-${r.n}'), value: s.meterNow[r.n] ?? '', numeric: true, border: false, height: 36, fs: 15, w: 800, pad: const EdgeInsets.symmetric(horizontal: 8), onChanged: (v) => s.update(() => s.meterNow = {...s.meterNow, r.n: v})),
                          ),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [T(top, w: 800, s: 14, align: TextAlign.right), if (sub.isNotEmpty) T(sub, s: 12, c: p.mu, align: TextAlign.right)]),
                      ]),
                    );
                  }(),
                if (rooms.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Add your rooms first (Beds › Edit rooms).', s: 14, c: p.mu)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: T('Residents see “Electricity · 70 units ÷ 4 · ₹8/unit  ₹140” on their $month rent (the room’s units split by the residents in it). Rooms not added show “Electricity  Not added yet”.', s: 13, c: p.mu, lh: 1.45),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta(s.meterSaving ? 'Saving…' : 'Add to $month rent · $typed of $all rooms', key: const ValueKey('meterGo'), icon: 'check', height: 54, px: 16, fs: 15, opacity: typed > 0 ? 1 : .4, onTap: s.saveMeters),
        ),
      ],
    );
  }
}

/// Rent › the Electricity row (only when electricity is extra).
class MeterEntry extends StatelessWidget {
  const MeterEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final month = monthYear(appToday).split(' ').first;
    final done = (s.meterRows[s.ownHid] ?? const []).where((m) => m.month == meterMonth).length;
    return Tap(
      key: const ValueKey('meterOpen'),
      onTap: s.openMeter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: box(w: 2, c: p.tx),
        child: Row(
          children: [
            const Ic('bolt', size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const T('Electricity', w: 800, s: 15), T(done == 0 ? 'Type each room’s meter for $month' : '$month: $done room${done == 1 ? '' : 's'} added', s: 13, c: p.mu)])),
            const Ic('chev', size: 18),
          ],
        ),
      ),
    );
  }
}

/// Board `oLaundry`: House rules › Laundry day (row on the page; the sheet).
class LaundryRow extends StatelessWidget {
  const LaundryRow({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final l = s.laundryOf(s.ownHid);
    return VGap(
      gap: 6,
      children: [
        const T('Laundry day', w: 800, s: 13),
        Tap(
          key: const ValueKey('laundryOpen'),
          onTap: s.openLaundry,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: box(w: 2, c: p.tx),
            child: Row(children: [Expanded(child: T(l == null ? 'Not set · residents can get a reminder' : '${weekdayNames[l.day - 1]} · ${l.slot}', s: 15, c: l == null ? p.mu : p.tx)), const Ic('chev', size: 18)]),
          ),
        ),
      ],
    );
  }
}

class LaundrySheet extends StatelessWidget {
  const LaundrySheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          const T('Laundry day', w: 800, s: 13),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 4),
                Expanded(
                  child: Tap(
                    key: ValueKey('laundryDay-$d'),
                    onTap: () => s.update(() => s.laundryDayDraft = d),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: s.laundryDayDraft == d ? BoxDecoration(color: p.tx) : box(w: 1, c: p.dv),
                      child: T(weekdayNames[d - 1].substring(0, 3), w: 800, s: 13, c: s.laundryDayDraft == d ? p.bg : p.tx),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const T('Machine free', w: 800, s: 13),
          Seg(opts: [for (final x in laundrySlots) (x, x)], cur: s.laundrySlotDraft, onPick: (v) => s.update(() => s.laundrySlotDraft = v), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), fs: 13, center: true),
          T('Residents who turn on the Laundry reminder get it at 8 pm the evening before.', s: 13, c: p.mu, lh: 1.45),
          Cta('Save laundry day', key: const ValueKey('laundrySave'), icon: 'check', height: 54, px: 16, fs: 15, onTap: s.saveLaundry),
        ],
      ),
    );
  }
}

/// Board `trustedPerks`: what a Trusted tenant gets. Only what works:
/// first pick of beds that just turned free, 2-hour holds, the badge.
class PerksSheet extends StatelessWidget {
  const PerksSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final trusted = s.level == 'trusted';
    const perks = [
      ('bell', 'First look at new free beds', 'When a bed turns free, you can hold it 1 hour before everyone else'),
      ('clock', '2-hour holds', 'Instead of 1 hour'),
      ('check', 'Owners see “Trusted tenant”', 'On your hold request'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (icon, title, sub) in perks)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: Ic(icon, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(title, w: 800, s: 15), T(sub, s: 13, c: p.mu, lh: 1.35)])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          T(
            trusted
                ? 'You keep it with $trustedMonths months in Hostelzy hostels and rent paid on time. We never tell owners where you stayed before.'
                : 'You get it after $trustedMonths months in Hostelzy hostels with rent paid on time${s.isMember ? ' (${s.monthsOnTime} of $trustedMonths so far)' : ''}. We never tell owners where you stayed before.',
            s: 13,
            c: p.mu,
            lh: 1.45,
          ),
        ],
      ),
    );
  }
}
