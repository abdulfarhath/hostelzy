import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../../ui/onboarding.dart';
import '../amenities/amenities_screens.dart';
import '../fair_play/fair_play_screens.dart';
import '../photos/photos_screens.dart';

// ------------------------------------------------------------ detail

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final rs = s.rooms[h.id]!;
    final free = s.freeOf(h.id).f;
    final photos = s.photosOf[h.id] ?? const [];
    final saved = s.saved[h.id] ?? false;
    final deal = s.dealsOf(h.id);
    // F21 W2: the cheapest bed sets "From … · … to move in" and the advance line.
    final low = ([...rs]..sort((a, b) => a.rent.compareTo(b.rent))).first;
    final q0 = s.quote(h.id, low.ac, low.share);
    // F16: sharing × room type grid; one column per type the hostel has.
    final kinds = [if (h.hasNon) false, if (h.ac) true];
    ({int price, int free})? cell(int n, bool ac) {
      final rr = rs.where((r) => r.share == n && r.ac == ac).toList();
      if (rr.isEmpty) return null;
      return (price: rr.first.rent, free: rr.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length));
    }
    // F17: Anjani shows the rules its owner keeps in Manage → Rules; other
    // sample hostels use the standard set until their owners add theirs.
    // S3: rules the owner saved on the server come first.
    final ownRules = s.hostelRules[h.id];
    final rules = ownRules != null
        ? [
            for (final r in ownRules)
              if (r.v.trim().isNotEmpty && !moneyRules(h).any((m) => m[0] == r.k)) [r.k, r.v],
            ...moneyRules(h),
          ]
        : h.id == 'anjani'
        ? [
            for (final r in s.rules)
              if (!moneyRules(h).any((m) => m[0] == r.k)) [r.k, r.v],
            ...moneyRules(h),
          ]
        // F24: a real hostel's page never shows rules its owner didn't add.
        : !isSeedHostel(h.id)
        ? moneyRules(h)
        : [
      ['Gate closes', h.gender == 'Women' ? '9:30 pm' : '10:30 pm'],
      ['Visitors', 'Common area, till 8 pm'],
      ...moneyRules(h),
      ['Food', h.food ? 'Included, veg and non-veg' : 'Not included, shared kitchen'],
          ];
    Widget tagRow(int i) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), child: T(h.tags[i], s: 14, w: 600)),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), child: T(i + 1 < h.tags.length ? h.tags[i + 1] : '', s: 14, w: 600)),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scroll(
            key: ValueKey('detail${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 232,
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                  child: CustomPaint(
                    painter: Hatch(p.sf, 8, 16, base: p.bg),
                    child: Stack(
                      children: [
                        // B7: the owner's cover photo; tap for the gallery.
                        Positioned.fill(child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : Tap(onTap: () => s.openGallery(h.id), child: PhotoImg(photos.first.url)))),
                        Positioned(
                          top: 10,
                          left: 12,
                          child: BackBtn(onTap: s.back, bg: p.bg),
                        ),
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Tap(
                            onTap: () {
                              s.toggleSaved(h.id);
                            },
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: box(bg: p.bg, w: 1, c: p.dv),
                              child: Css(
                                c: saved ? p.ad : p.tx,
                                s: 13,
                                w: 600,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [const Ic('heart', size: 16), const SizedBox(width: 6), T(saved ? 'Saved' : 'Save')]),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 10,
                          child: photos.isEmpty
                              ? T('No photos yet', s: 11, mono: true, c: p.mu)
                              : Tap(
                                  onTap: () => s.openGallery(h.id),
                                  child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), child: T('See ${photos.length} photo${photos.length == 1 ? '' : 's'}', s: 13, w: 800)),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.dv))),
                  child: VGap(
                    gap: 6,
                    children: [
                      Kicker('${h.gender} · ${h.area}, Hyderabad', c: p.ad),
                      T(h.name, w: 800, s: 30, lh: 1.02, ls: -.025),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Css(
                          s: 13,
                          c: p.mu,
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              // Each `{{ }}` is its own flex item, so the pieces sit 4px apart.
                              // F08: verified reviews; tap for the Reviews screen.
                              Tap(
                                onTap: () => s.go('reviews'),
                                child: Css(
                                  c: p.tx,
                                  w: 600,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final (i, w) in (h.reviews == 0 ? [const T('New on Hostelzy · no reviews yet')] : [const Ic('star', size: 13), T(jsNum(h.rating)), const T('·'), T('${h.reviews}'), const T('verified reviews'), T('›', c: p.ad)]).indexed) ...[if (i > 0) const SizedBox(width: 4), w],
                                    ],
                                  ),
                                ),
                              ),
                              T('${kmLabel(s.kmFor(h))} ${s.kmFrom}'),
                              if (s.visited[h.id] != null) const T('Visited by Hostelzy'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // F24 item 12 (DECISIONS F03, Design v22 r-detail): the deal's headline is the
                // 6-month saving, its parts under it, from this hostel's real deals only.
                if (dealHeadline(s.bestQuote(h.id)) case (final head, final parts))
                  Container(
                    key: const ValueKey('dealHeadline'),
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: box(bg: p.gb, w: 2, c: p.gn),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T(head, w: 800, s: 20, c: p.gn, lh: 1.15),
                        if (parts.isNotEmpty) ...[const SizedBox(height: 2), T(parts, s: 13, w: 600, c: p.gn, lh: 1.35)],
                      ],
                    ),
                  ),
                // Design v25 w1-dealsPaused: the owner's deals are paused (plan 15+ days late)
                // or hidden (strike 2). Say so instead of letting them vanish.
                if (s.dealsPaused(h.id) || s.dealsHidden(h.id))
                  Container(
                    key: const ValueKey('dealsPaused'),
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: box(bg: p.sf, w: 2, c: p.tx),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Ic('shield', size: 18, color: p.tx),
                        const SizedBox(width: 10),
                        const Expanded(child: T('Hostelzy deals are paused for this hostel. Walk-in prices shown.', s: 14, w: 700, lh: 1.35)),
                      ],
                    ),
                  ),
                // F21 W2: one table. The Hostelzy price sits in it, walk-in struck through.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 96, child: Kicker('Rent per month')),
                      const SizedBox(width: 12),
                      Expanded(child: T('Advance ${fmt(q0.hzAdv)} · ${fmt(q0.hzBack)} back when you leave', s: 13, w: 600, c: p.mu, lh: 1.35)),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: box(w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(width: 92),
                              for (final ac in kinds)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(border: Border(left: bs(1, p.hl))),
                                    child: T(ac ? 'AC' : 'Non-AC', s: 12, w: 800, ls: .06, upper: true),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (final n in [2, 3, 4])
                        if (kinds.any((ac) => cell(n, ac) != null))
                          Container(
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 92,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Align(alignment: Alignment.centerLeft, child: T('$n sharing', w: 800, s: 14)),
                                    ),
                                  ),
                                  for (final ac in kinds)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                        decoration: BoxDecoration(color: cell(n, ac) != null && deal.covers(ac) ? p.gb : null, border: Border(left: bs(1, p.hl))),
                                        child: () {
                                          final c = cell(n, ac);
                                          final hz = c != null ? s.quote(h.id, ac, n) : null;
                                          final off = hz != null && hz.hzFee < hz.fee;
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              T(c != null ? fmt(off ? hz.hzFee : c.price) : '—', w: 800, s: 18, c: c == null ? p.mu : (off ? p.gn : p.tx)),
                                              if (off) Text('${fmt(c!.price)} walk in', style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12, color: p.mu, decoration: TextDecoration.lineThrough, decorationColor: p.mu)),
                                              const SizedBox(height: 1),
                                              T(c != null ? (c.free > 0 ? '${c.free} free' : 'Full right now') : 'Not offered', s: 12, c: p.mu),
                                            ],
                                          );
                                        }(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      if (deal.on.isNotEmpty)
                        Container(
                          color: p.gb,
                          padding: const EdgeInsets.all(10),
                          child: T(dealLine(deal), s: 13, w: 800, c: p.gn),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: T('Same price for every bed of a type.${h.food ? ' Food included.' : ''} Electricity ${h.terms.electricityExtra ? 'extra, by meter' : 'included'}.', s: 13, c: p.mu, lh: 1.4),
                ),
                // F03 (F24 Wave 4d): when the owner last stood by these prices; nothing when unknown.
                if (s.ratesConfirmedAt[h.id] case final at?)
                  Padding(
                    key: const ValueKey('ratesConfirmed'),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: s.ratesStale(h.id)
                        ? Rich([sp(context, 'Not confirmed in over a month', w: 800, c: p.ad), sp(context, ' · ask the owner before you visit.')], s: 13, lh: 1.4)
                        : Rich([sp(context, 'Confirmed by the owner', w: 800), sp(context, ' · ${dayMon(at.toLocal())}')], s: 13, lh: 1.4),
                  ),
                // F23: the shared things on each floor (and the geyser in rooms).
                OnEachFloor(hid: h.id),
                // Today's food, then the whole week, when the owner has put a menu.
                FoodPeek(hid: h.id),
                const SizedBox(height: 12),
                // F21 W2: rules folded under one row.
                Tap(
                  key: const ValueKey('houseRules'),
                  onTap: () => s.update(() => s.rulesOpen = !s.rulesOpen),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv), bottom: bs(s.rulesOpen ? 0 : 2, p.dv))),
                    child: Row(children: [const Expanded(child: T('House rules', w: 800, s: 16)), Ic(s.rulesOpen ? 'chevD' : 'chev', size: 18)]),
                  ),
                ),
                if (s.rulesOpen)
                  for (final r in rules)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 28),
                      child: Css(
                        s: 14,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 120, child: T(r[0], c: p.mu)),
                            const SizedBox(width: 12),
                            Expanded(child: T(r[1], w: 600)),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                // F14: Visited by Hostelzy + whether the owner confirmed the free beds.
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: VisitedBlock(h)),
                // F18: any number of tags (new hostels may have fewer than four).
                if (h.tags.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: p.hl,
                      border: Border(top: bs(2, p.dv), bottom: bs(2, p.dv)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < h.tags.length; i += 2) ...[if (i > 0) const SizedBox(height: 1), tagRow(i)]]),
                  ),
                // F07: the owner's number shows only after a hold.
                OwnerContact(h),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: bs(2, p.tx)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Rich([sp(context, 'From ${fmt(q0.hzFee)}'), sp(context, '/mo', s: 13, w: 400, c: p.mu)], w: 800, s: 19),
                    T('${fmt(q0.hzMove)} to move in · $free free', s: 13, c: p.mu),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta(
                'Pick a bed',
                onTap: () {
                  s.holdOpt = 'free';
                  s.openPicker();
                },
                height: 50,
                fs: 15,
                expand: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// F24 item 12: "Save ₹1,700 in 6 months" over "₹1,000 off the advance + ₹200
/// off every month", from the hostel's best quote; null when it has no deal.
(String, String)? dealHeadline(DealQuote? q) {
  if (q == null || !q.any) return null;
  final parts = [
    if (q.hzAdv < q.adv) '${fmt(q.adv - q.hzAdv)} off the advance',
    if (q.join > 0) 'no ${fmt(q.join)} joining fee',
    if (q.firstOffNow > 0) '${fmt(q.firstOffNow)} off the first month',
    if (q.hzFee < q.fee) '${fmt(q.fee - q.hzFee)} off every month',
    if (q.moreBack > 0) '${fmt(q.moreBack)} more back when you leave',
    if (q.laundry) 'free laundry',
  ];
  final head = q.save6 > 0
      ? 'Save ${fmt(q.save6)} in 6 months'
      : q.upfront > 0
      ? '${fmt(q.upfront)} less upfront'
      : q.moreBack > 0
      ? '${fmt(q.moreBack)} more back when you leave'
      : 'Hostelzy deal';
  return (head, parts.join(' + '));
}

/// "Hostelzy price: ₹200 off every month · ₹500 exit" (F21 W2 table footer).
String dealLine(Deals d) {
  final rest = [for (final id in dealMenu.where((x) => x != 'monthly' && d.on.contains(x))) dealPerk(id)];
  final parts = [if (d.on.contains('monthly')) '${fmt(monthlyOff)} off every month', ...rest, if (d.target != 'all') d.targetText];
  return '${d.on.contains('monthly') ? 'Hostelzy price' : 'Hostelzy deal'}: ${parts.join(' · ')}';
}

/// Hostel page (board `new-foodPeek`): today's three meals from the owner's
/// menu, then "Whole week ›" (the `foodWeek` sheet). A hostel that serves
/// food but has no menu yet says so; one without food shows nothing.
class FoodPeek extends StatelessWidget {
  const FoodPeek({super.key, required this.hid});
  final String hid;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final m = s.menuOf(hid);
    final show = m != null || hostelById(hid).food;
    Widget row({Key? key, required Widget child, VoidCallback? onTap}) {
      final c = Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: child,
      );
      return onTap == null ? c : Tap(key: key, onTap: onTap, child: c);
    }

    return OnShow(
      () => s.loadMenu(hid),
      child: !show
          ? const SizedBox.shrink()
          : Column(
              key: const ValueKey('foodPeek'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Kicker('Food menu · today, $todayName'),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m == null)
                        row(child: T('Menu not added yet', s: 14, c: p.mu))
                      else ...[
                        for (final ml in meals)
                          row(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 92,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [T(ml[1], w: 800, s: 14), T(s.mealTimeText(hid, ml[0]), s: 11, c: p.mu)],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: T(m[todayIdx].of(ml[0]).trim().isEmpty ? '—' : m[todayIdx].of(ml[0]), s: 14, c: p.mu, lh: 1.35)),
                              ],
                            ),
                          ),
                        row(
                          key: const ValueKey('foodMenu'),
                          onTap: () => s.openFoodFor(hid),
                          child: Row(children: [const Expanded(child: T('Whole week', w: 800, s: 14)), Ic('chev', size: 16, color: p.tx)]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Board `new-foodWeek`: a hostel's menu, Mon–Sun chips and three meals.
class FoodWeekSheet extends StatelessWidget {
  const FoodWeekSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final m = s.menuOf(s.foodFor ?? s.hid) ?? blankWeek;
    final d = s.fwDay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Tap(
                    key: ValueKey('fwDay-$i'),
                    onTap: () => s.update(() => s.fwDay = i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: box(bg: i == d ? p.tx : transparent, w: 1, c: i == d ? p.tx : p.dv),
                      child: FittedBox(fit: BoxFit.scaleDown, child: T(weekDays[i][0], s: 13, w: 800, c: i == d ? p.bg : p.tx, nowrap: true)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final ml in meals)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(ml[1], w: 800, s: 15), T(s.mealTimeText(s.foodFor ?? s.hid, ml[0]), s: 12, c: p.mu)])),
                        const SizedBox(width: 8),
                        Expanded(child: T(m[d].of(ml[0]).trim().isEmpty ? '—' : m[d].of(ml[0]), s: 14, lh: 1.4)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          T('From ${hostelById(s.foodFor ?? s.hid).owner}’s menu on Hostelzy.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}
