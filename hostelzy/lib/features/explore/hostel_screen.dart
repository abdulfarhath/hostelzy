import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../fair_play/fair_play_screens.dart';
import '../food/week_table.dart';
import '../holds/building_view.dart';
import '../onboarding/onboarding_cards.dart';
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
                      // F26 #5: ✓ VERIFIED next to the name, only after a team visit.
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [T(h.name, w: 800, s: 30, lh: 1.02, ls: -.025), if (s.visited[h.id] != null) const VerifiedBadge()],
                      ),
                      if (s.visited[h.id] case final v?) T('Beds and prices checked by Hostelzy · $v', key: const ValueKey('verifiedLine'), s: 13, c: p.mu),
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
                // F26 #3: the whole building inline (S87); big hostels open it on its own page.
                HostelBuilding(hid: h.id),
                // F26 #4: the whole week, always.
                FoodWeekSection(hid: h.id),
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
                // F14: whether the owner confirmed the free beds (the visit is the ✓ VERIFIED badge, F26 #5).
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: VisitedBlock(h)),
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

/// F26 #5: navy ✓ VERIFIED, white text. Only for a hostel the Hostelzy team
/// visited (`visited_on`); the grey UNVERIFIED badge sits in the same spot.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    const white = Color(0xFFFFFFFF);
    return Container(
      key: const ValueKey('verifiedBadge'),
      color: p.vf,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Ic('check', size: 14, color: white), SizedBox(width: 4), T('Verified', s: 12, w: 800, ls: .08, upper: true, c: white, nowrap: true)],
      ),
    );
  }
}

/// Tenant taps a free bed in the building: the bed picker opens on it.
/// A bed that can't be held only says why (taken, on hold).
void pickFromBuilding(AppState s, Bed b) {
  if ((b.state != 'free' && b.state != 'soon') || b.mine) return s.pickBed(b);
  s.holdOpt = 'free';
  s.openPicker();
  s.pickBed(b);
}

/// F26 #3: the hostel page's building. Up to [featuredBeds] beds the cross-section
/// (S87) is inline; a bigger hostel (the F10 80+ tier, the same line as its
/// featured spot) collapses to "See all N rooms ›" (its own page).
class HostelBuilding extends StatelessWidget {
  const HostelBuilding({super.key, required this.hid});
  final String hid;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final rs = s.rooms[hid] ?? const <Room>[];
    if (rs.isEmpty) return const SizedBox.shrink();
    final beds = rs.fold<int>(0, (a, r) => a + r.beds.length);
    if (beds <= featuredBeds) {
      return Padding(
        key: const ValueKey('inlineBuilding'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: BuildingView(hid: hid, rooms: rs, onBed: (b) => pickFromBuilding(s, b)),
      );
    }
    final floors = {for (final r in rs) r.floor}.length;
    final free = s.freeOf(hid).f;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          const Kicker('Whole building'),
          Tap(
            key: const ValueKey('seeAllRooms'),
            onTap: () => s.go('building'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: box(w: 2, c: p.tx),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T('See all ${rs.length} rooms ›', w: 800, s: 16),
                        T('$beds beds on $floors ${floors == 1 ? 'floor' : 'floors'} · $free free', s: 13, c: p.mu),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Ic('chev', size: 16),
                ],
              ),
            ),
          ),
          T('Big hostels open the building on its own page, so this page stays short.', s: 12, c: p.mu, lh: 1.45),
        ],
      ),
    );
  }
}

/// F26 #3: an 80+ bed hostel's whole building on its own page (S87).
class BuildingScreen extends StatelessWidget {
  const BuildingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final rs = s.rooms[h.id] ?? const <Room>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker('All ${rs.length} rooms'), T(h.name, w: 800, s: 17, ell: true)])),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('building${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: BuildingView(hid: h.id, rooms: rs, onBed: (b) => pickFromBuilding(s, b)),
            ),
          ),
        ),
      ],
    );
  }
}
