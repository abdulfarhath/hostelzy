import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../data.dart';
import '../state.dart';
import 'amenities.dart';
import 'common.dart';
import 'fairplay.dart';
import 'kit.dart';
import 'photos.dart';
import 'layout.dart';
import 'onboarding.dart';
import 'reminders.dart';

// ------------------------------------------------------------ derived values

List<Hostel> filtered(AppState s) {
  final lim = {'Any': 1e9, '6k': 6000, '8k': 8000, '10k': 10000}[s.fB]!;
  bool ok(Hostel h) {
    final rs = s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).toList();
    if (rs.isEmpty) return false;
    final from = rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
    // F07: a hostel with 3 strikes is removed from Hostelzy.
    if (s.removed(h.id)) return false;
    // F18: the area picked on the map.
    if (!s.inMapArea(h)) return false;
    return (s.fG == 'Any' || h.gender == s.fG) && (!s.fFood || h.food) && (!s.fDeals || s.bestQuote(h.id, f: s.fR) != null) && from <= lim && (s.fS == 'Any' || rs.any((r) => r.share == int.parse(s.fS) && r.beds.any((b) => b.state == 'free'))) && (s.fAm.isEmpty || s.hasAmenities(h.id, s.fAm));
  }

  final out = browsable.where(ok).toList();
  // Array.prototype.sort is stable; List.sort is not guaranteed to be, so sort by (mins, index).
  final idx = {for (var i = 0; i < hostels.length; i++) hostels[i].id: i};
  // F03 Best deals: the 6-month saving (the Explore ribbon and the hostel
  // page headline); paused or hidden deals (F07, F10) have none, so 0.
  int saving(Hostel h) {
    final q = s.bestQuote(h.id, f: s.fR);
    return q == null ? 0 : q.save6 * 10 + (q.upfront > 0 ? 1 : 0);
  }

  int cheapest(Hostel h) => s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).fold<int>(1 << 30, (a, r) => r.rent < a ? r.rent : a);
  final score = {for (final h in out) h.id: s.rankScore(h.id)};
  // F10: an 80+ bed hostel's plan has a featured spot: first under Recommended.
  final feat = {for (final h in out) if (s.featured(h.id)) h.id};

  out.sort((a, b) {
    // F08 Recommended (Hostelzy rank), F03 Best deals, or Lowest price; then nearest.
    final d = switch (s.sortBy) {
      'rec' when feat.contains(a.id) != feat.contains(b.id) => feat.contains(a.id) ? -1 : 1,
      'rec' => score[b.id]!.compareTo(score[a.id]!),
      'deals' => saving(b).compareTo(saving(a)),
      'price' => cheapest(a).compareTo(cheapest(b)),
      _ => 0,
    };
    if (d != 0) return d;
    final c = s.kmFor(a).compareTo(s.kmFor(b));
    return c != 0 ? c : idx[a.id]!.compareTo(idx[b.id]!);
  });
  return out;
}

/// The best-ranked hostel among [results] (the "#1 near you" card).
String? topRanked(AppState s, List<Hostel> results) {
  String? top;
  var best = double.negativeInfinity;
  for (final h in results) {
    final v = s.rankScore(h.id);
    if (v > best) (top, best) = (h.id, v);
  }
  return top;
}

String searchSummary(AppState s) {
  final budget = {'Any': 'Any budget', '6k': 'Under ₹6,000', '8k': 'Under ₹8,000', '10k': 'Under ₹10,000'}[s.fB]!;
  return [s.lm, s.fG == 'Any' ? 'Anyone' : s.fG, s.fS == 'Any' ? null : '${s.fS} sharing', s.fR == 'Any' ? null : '${s.fR} rooms', budget, s.fFood ? 'Food' : null].whereType<String>().join(' · ');
}

String featOf(Hostel h) => [h.food ? 'Food' : 'No food', h.ac ? (h.onlyAc ? 'AC rooms' : 'AC and non-AC') : null].whereType<String>().join(' · ');

/// F16: small AC / Non-AC tag (AC: ink border, Non-AC: muted).
class RoomTypeTag extends StatelessWidget {
  const RoomTypeTag(this.ac, {super.key});
  final bool ac;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 5),
      decoration: box(w: 1, c: ac ? p.tx : p.dv),
      child: T(ac ? 'AC' : 'Non-AC', s: 10, w: 800, ls: .06, upper: true, c: ac ? p.tx : p.mu),
    );
  }
}

// ------------------------------------------------------------ explore

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final results = filtered(s);
    final top = s.sortBy == 'rec' ? topRanked(s, results) : null;
    final totalFree = results.fold<int>(0, (a, h) => a + s.freeOf(h.id).f);
    void set(void Function() f) => s.update(f);
    // F21 W2: one search bar, one row of filters; sort lives in Filters.
    final chips = [
      for (final g in const ['Men', 'Women', 'Co-living']) ChipBtn(g, on: s.fG == g, onTap: () => set(() => s.fG = s.fG == g ? 'Any' : g), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
      ChipBtn('AC', on: s.fR == 'AC', onTap: () => set(() => s.fR = s.fR == 'AC' ? 'Any' : 'AC'), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
      ChipBtn('Under ₹8,000', on: s.fB == '8k', onTap: () => set(() => s.fB = s.fB == '8k' ? 'Any' : '8k'), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
      ChipBtn('Hostelzy deals', on: s.fDeals, onTap: () => set(() => s.fDeals = !s.fDeals), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
    ];
    return Scroll(
      key: ValueKey('explore${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // F20: the reminders offer, from the 3rd app open (F21 W2).
          OnShow(s.maybeOfferReminders, child: const SizedBox.shrink()),
          if (!s.signedIn)
            Container(
              color: p.sf,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
              child: Row(children: [Expanded(child: T('Browsing as a guest', s: 13, w: 600, c: p.mu)), Tap(onTap: () => s.startSignIn(), child: const T('Sign in', s: 13, w: 800, underline: true))]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: VGap(
              gap: 12,
              children: [
                PageHead(kicker: s.listState == 'ready' ? 'Hyderabad · $totalFree beds free now' : 'Hyderabad', title: 'Find a bed', gap: 2),
                if (s.showToday) const TodayCard(margin: EdgeInsets.zero),
                WhereBar(onTap: s.openWhere),
              ],
            ),
          ),
          Scroll(
            horizontal: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  FiltersBtn(onTap: () => set(() => s.sheet = 'search')),
                  for (final c in chips) ...[const SizedBox(width: 6), c],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // F21 W4: grey cards while loading; "You're offline" instead of "No hostels".
                if (s.listState == 'loading') ...const [SkeletonCard(), SkeletonCard()]
                else if (s.listState == 'offline') const OfflineBlock()
                else ...[
                  // F24: the last list from the server, kept on this phone: the banner,
                  // then the saved cards under it (Design w1-exploreCached).
                  if (s.listState == 'cached' && s.cachedAt != null)
                  Tap(
                    key: const ValueKey('cachedBanner'),
                    onTap: () => s.reconnect?.call(),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: box(w: 2, c: p.tx),
                      child: Row(children: [Ic('wifi', size: 18, color: p.tx), const SizedBox(width: 10), Expanded(child: T('Offline. Hostels as of ${dayMon(s.cachedAt!)}, ${clockTime(s.cachedAt!.millisecondsSinceEpoch).replaceFirst('Today, ', '')}. Tap to try again.', s: 13, w: 600, lh: 1.35))]),
                    ),
                  ),
                // F21 W2: the rank shows once, on the first card.
                // F10: featured hostels come first, so "#1" goes to the best rank among the results.
                for (final h in results) HostelCard(h, first: h.id == top),
                // F18 design "Empty": no hostels live yet (or none in the area picked).
                if (browsable.isEmpty || (results.isEmpty && s.mapArea != null))
                  // F22 Area 1: what to do next, not just "nothing here".
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Column(
                      children: [
                        Container(width: 64, height: 64, alignment: Alignment.center, color: p.sf, child: const Ic('search', size: 30)),
                        const SizedBox(height: 12),
                        T(s.mapArea != null ? 'No hostels in ${s.mapArea} yet' : 'No hostels in this area yet', w: 800, s: 22, align: TextAlign.center),
                        const SizedBox(height: 8),
                        T('We add hostels area by area, after we visit each one. Try a nearby area.', s: 15, c: p.mu, lh: 1.5, align: TextAlign.center),
                        const SizedBox(height: 14),
                        if (s.nearbyArea case final a?)
                          Cta('Try $a', key: const ValueKey('tryArea'), height: 50, px: 16, fs: 15, expand: false, onTap: () => s.pickWhereArea(a))
                        else
                          OutlineCta('Pick another area', icon: 'pin', onTap: s.openWhere),
                      ],
                    ),
                  )
                else if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    child: VGap(
                      gap: 10,
                      children: [
                        const T('Nothing matches yet.', w: 800, s: 20),
                        T('Try a higher budget or any room type.', s: 14, c: p.mu),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Tap(
                            onTap: s.clearFilters,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: box(w: 2, c: p.tx),
                              child: const T('Clear filters', w: 800, s: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// F21 W4: a grey placeholder card while hostels load.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    Widget bar(double f, double h) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: f, child: Container(height: h, color: p.sf));
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: VGap(gap: 8, children: [Container(height: 168, color: p.sf), bar(.6, 16), bar(.8, 12), bar(.7, 12)]),
      ),
    );
  }
}

/// F21 W4: "You're offline · Retry" (never "No hostels" when it's the network).
class OfflineBlock extends StatelessWidget {
  const OfflineBlock({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: VGap(
        gap: 10,
        children: [
          const T('You’re offline', w: 800, s: 20),
          T('Hostels show again when you’re back online. Your saved hostels and holds are still here.', s: 14, c: p.mu, lh: 1.45),
          Align(alignment: Alignment.centerLeft, child: Tap(key: const ValueKey('retry'), onTap: s.retryListings, child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: box(w: 2, c: p.tx), child: const T('Retry', w: 800, s: 14)))),
        ],
      ),
    );
  }
}

/// F21 W4: an inline error with Retry (toasts are for success only).
class InlineError extends StatelessWidget {
  const InlineError(this.title, {super.key, required this.onRetry, this.sub = 'Check your internet.'});
  final String title, sub;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: box(bg: p.ab, w: 2, c: p.ad),
      child: Row(
        children: [
          Ic('warn', size: 20, color: p.ad),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(title, w: 800, s: 15, c: p.ad), T(sub, s: 13)])),
          const SizedBox(width: 8),
          Tap(key: const ValueKey('inlineRetry'), onTap: onRetry, child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: box(w: 2, c: p.tx), child: const T('Retry', w: 800, s: 14))),
        ],
      ),
    );
  }
}

/// F21 W2: the one "Where?" field, on Explore and the Map.
class WhereBar extends StatelessWidget {
  const WhereBar({super.key, required this.onTap, this.height = 50});
  final VoidCallback onTap;
  final double height;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final set = s.mapArea != null || s.areaCenter != null || s.myPos != null || s.lm != landmarks.first;
    return Tap(
      key: const ValueKey('whereBar'),
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: box(bg: p.bg, w: 2, c: p.tx),
        child: Row(
          children: [
            const Ic('search', size: 18),
            const SizedBox(width: 10),
            Expanded(child: set ? T(s.whereLabel, s: 15, w: 800, ell: true) : T('Where? Area, landmark or hostel', s: 15, c: p.mu, ell: true)),
          ],
        ),
      ),
    );
  }
}

/// "Filters" with a count badge; opens the Filters sheet (sort is in there).
class FiltersBtn extends StatelessWidget {
  const FiltersBtn({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final n = s.filterCount;
    return Tap(
      key: const ValueKey('filtersBtn'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: box(w: 2, c: p.tx),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Ic('sliders', size: 16),
            const SizedBox(width: 8),
            const T('Filters', s: 13, w: 800, nowrap: true),
            if (n > 0) ...[const SizedBox(width: 6), Container(color: p.ac, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), child: T('$n', s: 12, w: 800, c: p.ai))],
          ],
        ),
      ),
    );
  }
}

/// F21 W2: the real cost of a hostel's cheapest bed that fits the filters.
({int fee, int move, int? hz})? cardCost(AppState s, Hostel h) {
  final rs = s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).toList();
  if (rs.isEmpty) return null;
  rs.sort((a, b) => a.rent.compareTo(b.rent));
  final q = s.quote(h.id, rs.first.ac, rs.first.share);
  return (fee: q.fee, move: q.move, hz: q.hzFee < q.fee ? q.hzFee : null);
}

/// Photo-first hostel card (F21 W2): photo, save heart, rank once, a green
/// Hostelzy price only when there's a deal, then the real cost.
class HostelCard extends StatelessWidget {
  const HostelCard(this.h, {super.key, this.first = false});
  final Hostel h;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final photos = s.photosOf[h.id] ?? const [];
    final saved = s.saved[h.id] ?? false;
    final cost = cardCost(s, h);
    final best = s.bestQuote(h.id, f: s.fR);
    final ribbon = cost?.hz != null ? 'Hostelzy price ${fmt(cost!.hz!)}' : best?.ribbon;
    final free = s.freeOf(h.id).f;
    final featured = s.featured(h.id);
    return Tap(
      onTap: () => s.update(() {
        s.hist = [...s.hist, s.screen];
        s.screen = 'detail';
        s.sheet = null;
        s.hid = h.id;
        s.dealAc = null;
        s.rulesOpen = false;
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: CustomPaint(
                painter: Hatch(p.sf, 8, 16, base: p.bg),
                child: Container(
                  decoration: box(w: 1, c: p.hl),
                  child: Stack(
                    children: [
                      Positioned.fill(child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url))),
                      // F10: the 80+ bed plan's featured spot is labelled, never passed off as rank.
                      if (first || featured)
                        Positioned(left: 8, top: 8, child: Container(key: featured ? ValueKey('featured-${h.id}') : null, color: p.tx, padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: T([if (featured) 'Featured', if (first) '#1 near you'].join(' · '), s: 13, w: 800, c: p.bg))),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Tap(
                          key: ValueKey('save-${h.id}'),
                          onTap: () {
                            s.toggleSaved(h.id);
                          },
                          child: Container(width: 40, height: 40, alignment: Alignment.center, color: p.bg, child: Ic('heart', size: 18, color: saved ? p.ad : p.tx)),
                        ),
                      ),
                      Positioned(left: 8, bottom: 8, child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: T(photos.isEmpty ? 'No photos yet' : '1 / ${photos.length}', s: 12, c: p.mu))),
                      if (ribbon != null)
                        Positioned(right: 0, bottom: 0, child: Container(color: p.gb, padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), child: T(ribbon, s: 13, w: 800, c: p.gn))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: T(h.name, w: 800, s: 18, lh: 1.2)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('star', size: 13, color: p.tx), const SizedBox(width: 3), T(h.reviews == 0 ? 'New' : jsNum(h.rating), s: 14, w: 800)]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            T('${h.gender} · ${h.area} · ${kmLabel(s.kmFor(h))} ${s.kmFrom} · $free free', s: 14, c: p.mu),
            if (cost != null) ...[
              const SizedBox(height: 4),
              Rich([
                sp(context, '${fmt(cost.fee)}/mo', w: 800, c: p.tx),
                sp(context, ' · ${fmt(cost.move)} to move in · electricity ${h.terms.electricityExtra ? 'extra' : 'included'}'),
              ], s: 14, c: p.mu),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ map



// ------------------------------------------------------------ holds

({Hostel hh, Room r, double left}) holdInfo(AppState s, Hold h) {
  final hh = hostelById(h.hid);
  final r = s.findBed(h.hid, h.bed).r!;
  final secs = s.holdSecsOf(h);
  return (hh: hh, r: r, left: secs - (s.now - h.start) / 1000);
}

class HoldsScreen extends StatelessWidget {
  const HoldsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const lab = {'waiting': 'Waiting for owner', 'confirmed': 'Held', 'held': 'Held', 'paying': 'Waiting for owner', 'booked': 'Booked', 'released': 'Released'};
    return Scroll(
      key: ValueKey('holds${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: const T('Holds', s: 30, w: 800, lh: 1.02, ls: -.025),
          ),
          // F21 W4: an inline error with Retry, never a silent empty list.
          if (s.liveFailed && s.onServer) InlineError('Couldn’t load your holds', onRetry: s.refreshLive),
          // F22 Area 1: one list; "Did you join …?" is asked right here (F07).
          for (final h in s.holds.reversed.where((h) => !s.releasing.contains(h.id)))
            () {
              final i = holdInfo(s, h);
              final timed = const ['waiting', 'confirmed', 'held'].contains(h.status);
              final ended = s.expiredHolds.contains(h.id) || h.status == 'released';
              final tag = ended ? (h.status == 'released' ? 'Released' : 'Ended') : (lab[h.status] ?? h.status);
              return Tap(
                key: ValueKey('holdRow-${h.id}'),
                onTap: () => s.update(() {
                  s.hist = [...s.hist, s.screen];
                  s.screen = 'hold';
                  s.sheet = null;
                  s.holdId = h.id;
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tag(tag, bg: ended ? p.sf : (h.status == 'booked' ? p.gb : p.ab), fg: ended ? p.mu : (h.status == 'booked' ? p.gn : p.ad)),
                            const SizedBox(height: 6),
                            T('Bed ${h.bed}', w: 800, s: 18),
                            const SizedBox(height: 2),
                            T('${i.hh.name} · ${fmt(i.r.rent)}/mo', s: 13, c: p.mu),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (timed && !ended)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [T(cd(i.left), w: 800, s: 22, tab: true), T('left', s: 12, c: p.mu)])
                      else
                        Ic('chev', size: 18, color: p.mu),
                    ],
                  ),
                ),
              );
            }(),
          // Only about a real ended hold; the demo build may show a sample one.
          if (s.askJoined)
            Container(
              key: const ValueKey('joinedAsk'),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: box(w: 2, c: p.tx),
              child: VGap(
                gap: 8,
                children: [
                  T('Did you join ${hostelById(s.endedHold?.hid ?? 'anjani').name}?', w: 800, s: 17),
                  T('Your hold on bed ${s.endedHold?.bed ?? '102-B'} ended. One tap helps us keep owners fair.${s.onServer ? ' If you joined, your ₹100 Member reward unlocks once the owner confirms your stay.' : ' A yes unlocks your ₹100 Member reward.'}', s: 13, c: p.mu, lh: 1.4),
                  // F07 / F24 item 14: Yes / Not yet / Still deciding.
                  Cta('Yes, I joined', icon: 'check', height: 46, px: 14, fs: 14, onTap: () => s.answerJoined('yes')),
                  Row(
                    children: [
                      Expanded(child: OutlineCta('Not yet', icon: 'x', height: 46, fs: 14, onTap: () => s.answerJoined('not_yet'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlineCta('Still deciding', icon: 'clock', height: 46, fs: 14, onTap: () => s.answerJoined('deciding'))),
                    ],
                  ),
                  if (s.onServer) T('Only the Hostelzy team sees your answer, never the owner.', s: 12, c: p.mu, lh: 1.4),
                  Tap(onTap: () => s.update(() => s.sheet = 'report'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: T('The owner asked me to skip the app ›', s: 13, w: 800, c: p.ad))),
                ],
              ),
            ),
          if (s.holds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Container(width: 64, height: 64, alignment: Alignment.center, color: p.sf, child: const Ic('clock', size: 30)),
                  const SizedBox(height: 12),
                  const T('No holds yet', w: 800, s: 22, align: TextAlign.center),
                  const SizedBox(height: 8),
                  T('Hold any free bed for 1 hour while you go and see it. It costs nothing.', s: 15, c: p.mu, lh: 1.5, align: TextAlign.center),
                  const SizedBox(height: 14),
                  Cta('Find a bed', height: 50, px: 16, fs: 15, expand: false, onTap: () => s.tab('explore')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ me

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final isOwner = s.role == 'owner';
    // F22 Area 1: one list, each row with a one-line status.
    final live = s.holds.where((h) => !const ['released', 'expired'].contains(h.status)).toList();
    final held = live.where((h) => h.status != 'booked').length, booked = live.where((h) => h.status == 'booked').length;
    final nSaved = s.saved.values.where((v) => v).length;
    final rows = <(String, String, VoidCallback)>[
      // F22 Area 2: the resident's stay is one row; its actions live in My stay.
      // F24: an advance refund still open after moving out.
      if (s.myRefund case final r?) ('Your refund', '${fmt(r.amt)} · ${r.status == 'sent' ? 'did it arrive?' : r.status == 'not_received' ? 'not received' : 'due ${dayMon(r.due)}'}', s.openMyRefund),
      if (s.role == 'resident') ('My stay', s.myStay == null ? 'Not on Hostelzy yet' : [if (s.myStay!.bed.isNotEmpty) 'Bed ${s.myStay!.bed}', s.stayHostel.name].join(' · '), () => s.go('rStay')),
      if (!isOwner) ('Saved', nSaved == 0 ? 'Nothing yet' : '$nSaved hostel${nSaved == 1 ? '' : 's'}', () => s.go('saved')),
      if (!isOwner) ('Holds', live.isEmpty ? 'None right now' : [if (held > 0) '$held held', if (booked > 0) '$booked booked'].join(' · '), () => s.tab('holds')),
      if (!isOwner) ('Stay Rewards', const {'trusted': 'Trusted tenant', 'member': 'Member'}[s.level] ?? 'Not a member yet', () => s.go('rewards')),
      ('Reminders', s.remSummary[0].toUpperCase() + s.remSummary.substring(1), s.openReminders),
      ('Settings', 'Language, notifications, log out', () => s.go('settings')),
      ('Help on WhatsApp', 'Ask the Hostelzy team', () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, I need help with the app.')),
    ];
    Widget row((String, String, VoidCallback) r) => Tap(
      key: ValueKey('me-${r.$1}'),
      onTap: r.$3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(r.$1, s: 16, w: 800), T(r.$2, s: 13, c: p.mu)])),
            Ic('chev', size: 18, color: p.mu),
          ],
        ),
      ),
    );
    return Scroll(
      key: ValueKey('me${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  color: p.ac,
                  alignment: Alignment.center,
                  child: s.meName.isEmpty && !isOwner ? Ic('user', size: 28, color: p.ai) : T(initials(s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner), w: 800, s: 24, c: p.ai),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T(s.meName.isNotEmpty ? s.meName : (isOwner ? hostelById(s.ownHid).owner : 'Add your name'), w: 800, s: 24, lh: 1.05),
                      const SizedBox(height: 3),
                      T(s.phone.length == 10 ? '+91 ${phoneSpaced(s.phone)} · not verified' : (s.signedIn ? 'Add your number' : 'Browsing as a guest'), s: 13, c: p.mu),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final r in rows) row(r),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Expanded(child: T(isOwner ? 'Looking for a bed, or live in a PG?' : 'Live in a PG or run one?', s: 14, c: p.mu)),
                Tap(key: const ValueKey('switchRole'), onTap: () => s.tab('role'), child: T('Switch role ›', s: 14, w: 800, c: p.ad)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: T('Hostelzy $appVersion · Made in Hyderabad', s: 12, c: p.mu),
          ),
        ],
      ),
    );
  }
}

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
                        Expanded(child: T('Hostelzy deals are paused for this hostel. Walk-in prices shown.', s: 14, w: 700, lh: 1.35)),
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
                px: 18,
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

// ------------------------------------------------------------ picker

class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final rs = s.rooms[h.id]!;
    final room = rs.where((r) => r.n == s.room).firstOrNull ?? rs[0];
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    final hasSel = sb != null && sb.b != null;
    // F23: the room plan comes first (layout-first, founder); its "Floor view"
    // button and the floor view's room names switch between the two. The
    // list is a "See cheapest beds" link.
    final locked = s.floorLocked(h.id) && s.mode == 'plan';

    Widget body;
    if (locked) {
      body = const FloorLocked();
    } else if (s.mode == 'room') {
      body = RoomMode(rooms: rs, room: room);
    } else if (s.mode == 'plan') {
      body = _PlanMode(rooms: rs, room: room);
    } else {
      body = _ListMode(rooms: rs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: s.mode == 'room' ? [Kicker('${h.name} · ${room.share} sharing', ell: true), T('Room ${room.label}', w: 800, s: 26, lh: 1.1)] : [Kicker(h.name, ell: true), const T('Pick a bed', w: 800, s: 26, lh: 1.1)],
                ),
              ),
            ],
          ),
        ),
        if (s.mode == 'list')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                key: const ValueKey('cheapest'),
                onTap: () => s.update(() => s.mode = 'plan'),
                child: T('‹ Back to the plan', s: 14, w: 800, c: p.ad),
              ),
            ),
          ),
        if (h.ac && h.hasNon && s.mode != 'room')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(padding: EdgeInsets.only(right: 4), child: Kicker('Room')),
                for (final f in const ['Any', 'AC', 'Non-AC']) ChipBtn(f, on: s.pR == f, onTap: () => s.pickRoomType(f)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(key: ValueKey('picker${s.scrollEpoch}'), child: body),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: bs(2, p.tx)),
          ),
          child: s.mode == 'room' ? RoomBar(room: room) : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(hasSel ? 'Bed ${sb.b!.id} · ${fmt(sb.r!.rent)}/mo' : 'No bed picked', w: 800, s: 17, lh: 1.25),
                    T(hasSel ? sb.b!.spot : 'Tap a free bed', s: 12, c: p.mu, ell: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta('Continue', key: const ValueKey('pickContinue'), icon: 'arrow', onTap: () => s.bed == null ? s.toastMsg('Pick a free bed first.') : s.update(() => s.sheet = 'hold'), height: 50, px: 18, fs: 15, expand: false, opacity: hasSel ? 1 : .4),
            ],
          ),
        ),
      ],
    );
  }
}

const pickerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];

/// Floor tabs: label + "n free", bottom bar on the active one.
class FloorTabs extends StatelessWidget {
  const FloorTabs({super.key, required this.items, required this.cur, required this.onPick, this.borderTop = false});
  final List<(int floor, int free)> items;
  final int cur;
  final ValueChanged<int> onPick;
  final bool borderTop;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      decoration: borderTop ? BoxDecoration(border: Border(top: bs(2, p.tx))) : null,
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Tap(
                onTap: () => onPick(it.$1),
                child: InsetBar(
                  edge: Edge.bottom,
                  size: it.$1 == cur ? 3 : 1,
                  color: it.$1 == cur ? p.ac : p.hl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Css(
                      c: it.$1 == cur ? p.tx : p.mu,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('Floor ${it.$1}', w: 800, s: 15), const SizedBox(height: 2), T('${it.$2} free', s: 12)]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// F22 Area 1: floors as chips, then every room on the floor as a card with
/// its beds as boxes. A bed tap picks it; the room name opens the Room view.
class _PlanMode extends StatelessWidget {
  const _PlanMode({required this.rooms, required this.room});
  final List<Room> rooms;
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final floors = [
      for (final f in floorsOf(rooms)) (f, rooms.where((r) => r.floor == f && AppState.fits(r, s.pR)).fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length)),
    ];
    final tiles = rooms.where((r) => r.floor == s.floor).toList();
    Widget card(Room r) {
      final fits = AppState.fits(r, s.pR);
      return Opacity(
        key: ValueKey('roomCard-${r.n}'),
        opacity: fits ? 1 : .35,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: box(w: 2, c: r.beds.any((b) => b.id == s.bed) ? p.ac : p.tx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Tap(
                enabled: fits,
                // F12: the room name opens it in the Room view.
                onTap: () => s.openRoom(r.n),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: T('Room ${r.label}', w: 800, s: 15, lh: 1.2)),
                    const SizedBox(width: 8),
                    Expanded(child: T('${r.share} sharing${r.ac ? ' AC' : ''} · ${fmt(r.rent)}', s: 12, c: p.mu, lh: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in r.beds)
                    () {
                      final l = lookOf(p, b, s.bed);
                      return Tap(
                        key: ValueKey('bed-${b.id}'),
                        enabled: fits && l.can,
                        onTap: () => s.pickBed(b),
                        child: Semantics(
                          label: 'Bed ${b.id}, ${l.tag}',
                          child: BedBox(
                            look: l.look,
                            width: 54,
                            height: 48,
                            child: Center(child: T(b.letter, w: 800, s: 17)),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final grid = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) grid.add(const SizedBox(height: 10));
      grid.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: card(tiles[i])), const SizedBox(width: 10), Expanded(child: i + 1 < tiles.length ? card(tiles[i + 1]) : const SizedBox())],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < floors.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Tap(
                    key: ValueKey('floor-${floors[i].$1}'),
                    onTap: () {
                      final f = floors[i].$1;
                      final fit = rooms.where((r) => r.floor == f && AppState.fits(r, s.pR));
                      final r = fit.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? fit.firstOrNull ?? rooms.firstWhere((r) => r.floor == f);
                      s.update(() {
                        s.floor = f;
                        s.room = r.n;
                        s.bed = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: box(bg: floors[i].$1 == s.floor ? p.tx : transparent, w: 1, c: floors[i].$1 == s.floor ? p.tx : p.mu),
                      child: T('Floor ${floors[i].$1} · ${floors[i].$2} free', s: 13, w: 800, c: floors[i].$1 == s.floor ? p.bg : p.tx, lh: 1.2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...grid,
          for (final r in tiles.where((r) => r.ac && r.acRepair))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: p.ab,
              child: T('Room ${r.label}: AC under repair.${r.acSince.isEmpty ? '' : ' Complaint raised ${r.acSince}.'} The owner is fixing it.', s: 12, w: 600, c: p.ad, lh: 1.4),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Legend(items: pickerLegend),
              Tap(
                key: const ValueKey('cheapest'),
                onTap: () => s.update(() => s.mode = 'list'),
                child: T('See cheapest beds ›', s: 13, w: 800, underline: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListMode extends StatelessWidget {
  const _ListMode({required this.rooms});
  final List<Room> rooms;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final lb = <({Bed b, Room r})>[];
    for (final r in rooms) {
      for (final b in r.beds) {
        if ((b.state == 'free' || b.state == 'soon') && !b.mine && AppState.fits(r, s.pR)) lb.add((b: b, r: r));
      }
    }
    // Stable sort by rent.
    final indexed = lb.asMap().entries.toList()..sort((x, y) => x.value.r.rent != y.value.r.rent ? x.value.r.rent.compareTo(y.value.r.rent) : x.key.compareTo(y.key));
    final sorted = indexed.map((e) => e.value).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
          child: Kicker('${sorted.length} beds you can take · cheapest first'),
        ),
        for (final e in sorted)
          () {
            final o = e.b.id == s.bed;
            return Tap(
              onTap: () => s.pickBed(e.b),
              child: InsetBar(
                edge: Edge.left,
                size: o ? 4 : 0,
                color: p.ac,
                bg: o ? p.ab : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Stripes(
                        step: 5,
                        width: 60,
                        height: 60,
                        border: Border.all(width: 1, color: p.hl),
                        child: Container(
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(4),
                          child: T('bed', s: 9, mono: true, c: p.mu),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T('Bed ${e.b.id}', w: 800, s: 16),
                            const SizedBox(height: 2),
                            T('Floor ${e.r.floor} · ${e.r.share} sharing · ${e.r.type} · ${e.r.bath} bath', s: 12, c: p.mu),
                            const SizedBox(height: 2),
                            T('${e.b.spot} · ${e.b.state == 'soon' ? 'Free from ${e.b.soon}' : 'Free now'}', s: 12, w: 600),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          T(fmt(e.r.rent), w: 800, s: 16),
                          T('per month', s: 11, c: p.mu),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// F22 Area 1: one status card for a hold: Held / Waiting for owner / Booked /
/// Not received / Ended. A big number, one line, a few facts and one or two
/// actions.
class HoldScreen extends StatelessWidget {
  const HoldScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hold = s.holds.where((h) => h.id == s.holdId).firstOrNull ?? s.holds.lastOrNull;
    if (hold == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back))), Padding(padding: const EdgeInsets.all(16), child: T('This hold isn’t on this phone any more.', s: 15, c: p.mu))]);
    }
    final i = holdInfo(s, hold);
    final st = hold.status;
    final owner = i.hh.owner;
    final pay = hold.opt == 'book' ? s.payOfHold(hold.id) : null;
    final amt = fmt(pay?.amt ?? hold.paid);
    final utr = utrSpaced(pay?.utr ?? '');
    final q = s.quote(hold.hid, i.r.ac, i.r.share);
    final expired = s.expiredHolds.contains(hold.id);
    final code = hold.ref;
    void wa() => s.enquire(hold.hid, "Hi $owner, I've held bed ${hold.bed} at ${i.hh.name} on Hostelzy. Can I come and see it today at 6 pm?", bed: hold.bed, from: 'Hold · WhatsApp owner');
    void again() {
      final b = s.findBed(hold.hid, hold.bed).b;
      if (b == null || b.state != 'free') return s.toastMsg('Bed ${hold.bed} has been taken. See other beds.');
      s.update(() => s.hid = hold.hid);
      s.openPicker();
      s.update(() {
        s.bed = hold.bed;
        s.holdOpt = 'free';
        s.sheet = 'hold';
      });
    }

    void others() {
      s.update(() => s.hid = hold.hid);
      s.openPicker();
    }

    // (label, big, line, rows, primary, secondary, link, green)
    final ({String label, String big, String line, List<(String, String)> rows, (String, String, VoidCallback)? main, (String, String, VoidCallback)? alt, bool green}) v = switch (st) {
      'paying' when pay?.status == 'waiting' => (
        label: 'Waiting for $owner',
        big: amt,
        line: 'You sent the UPI reference. It says Booked only after $owner sees the money, so it’s not booked yet.',
        rows: [('UPI reference', utr), if (pay?.sent != null) ('Sent', pay!.sent!), if (code != null) ('Booking code', code)],
        main: ('Remind $owner', 'msg', () => s.whatsapp(ownerWa(pay!.hid), 'Hi $owner, I paid the ${fmt(pay.amt)} advance for bed ${pay.bed} by UPI. UPI reference ${utrSpaced(pay.utr ?? '')}, booking code ${pay.note}. Please confirm on Hostelzy.')),
        alt: ('Fix the UPI reference', 'chev', () => s.openPayUtr(pay!)),
        green: false,
      ),
      'paying' when pay?.status == 'missing' => (
        label: 'Not received',
        big: amt,
        line: '$owner didn’t see this payment. Check the UPI reference in your UPI app. If the money left your account, send $owner the UPI receipt on WhatsApp.',
        rows: [('UPI reference', utr), if (pay?.sent != null) ('Sent', pay!.sent!)],
        main: ('Fix the UPI reference', 'arrow', () => s.openPayUtr(pay!)),
        alt: ('Talk to $owner', 'msg', () => s.whatsapp(ownerWa(pay!.hid), 'Hi $owner, about my advance for bed ${pay.bed}: UPI reference ${utrSpaced(pay.utr ?? '')}, booking code ${pay.note}.')),
        green: false,
      ),
      'paying' => (
        label: 'Pay to book',
        big: amt,
        line: 'Pay $owner by UPI, then enter the UPI reference. The bed is kept for you meanwhile; it says Booked once $owner sees the money.',
        rows: [if (code != null) ('Booking code', code), ('Rent', '${fmt(hold.fixedFee > 0 ? hold.fixedFee : q.hzFee)} a month'), if (hold.perks.isNotEmpty) ('Hostelzy deal', hold.perks.join(' · '))],
        main: pay == null ? null : ('Pay $amt by UPI', 'arrow', () => s.payByUpi(pay)),
        alt: pay == null ? null : ('I’ve paid · enter UPI reference', 'chev', () => s.openPayUtr(pay)),
        green: false,
      ),
      'booked' => (
        label: 'Booked',
        big: 'Yours.',
        line: pay?.done != null ? '$owner confirmed $amt on ${pay!.done}. Show ${code ?? 'your booking code'} when you move in.' : 'Advance paid to $owner. Show ${code ?? 'your booking code'} when you move in.',
        rows: [('Pay at move-in', '${fmt(q.hzFirst)} first month'), ('Your price is fixed', '${fmt(hold.fixedFee > 0 ? hold.fixedFee : q.hzFee)} a month'), if (code != null) ('Booking code', code), if (hold.perks.isNotEmpty) ('Hostelzy deal', hold.perks.join(' · '))],
        main: ('Moving in · see what to pay', 'arrow', () => s.go('moveIn')),
        alt: ('Directions', 'pin', () => s.directions(i.hh)),
        green: true,
      ),
      'waiting' || 'confirmed' || 'held' => (
        label: st == 'waiting' ? 'Held for you · free' : 'Held · $owner confirmed',
        big: cd(i.left),
        line: st == 'waiting' ? 'Go and see it. $owner doesn’t know yet: tell them you’re coming so they keep it.' : 'Go and see it before the timer ends to keep the bed.',
        rows: [('Rent', '${fmt(q.hzFee)} a month'), ('To move in', '${fmt(q.hzMove)} · advance ${fmt(q.hzAdv)} + first month'), if (code != null) ('Booking code', code)],
        main: st == 'waiting' ? ('Tell $owner on WhatsApp', 'msg', wa) : ('Moving in · see what to pay', 'arrow', () => s.go('moveIn')),
        alt: st == 'waiting' ? ('Directions', 'pin', () => s.directions(i.hh)) : ('WhatsApp $owner', 'msg', wa),
        green: st != 'waiting',
      ),
      _ => (
        label: expired ? 'Hold ended' : 'Released',
        big: expired ? '0:00' : '—',
        line: 'Bed ${hold.bed} is free for everyone again. Nothing was charged.',
        rows: [('Bed', '${hold.bed} · ${i.r.share} sharing'), ('Rent', '${fmt(q.hzFee)} a month')],
        main: ('Hold it again', 'arrow', again),
        alt: ('See other beds', 'chev', others),
        green: false,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(i.hh.name), T('Bed ${hold.bed}', w: 800, s: 22, lh: 1.1)])),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('hold${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('holdCard'),
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: v.green ? p.gb : p.sf,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Kicker(v.label, c: v.green ? p.gn : p.ad),
                              const SizedBox(height: 4),
                              T(v.big, w: 800, s: 56, lh: 1, ls: -.03, tab: true, c: v.green ? p.gn : p.tx),
                              const SizedBox(height: 8),
                              T(v.line, s: 14, lh: 1.45),
                            ],
                          ),
                        ),
                        for (final r in v.rows) KV(r.$1, r.$2, keyWidth: 120),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: VGap(
                            gap: 8,
                            children: [
                              if (v.main case final m?) Cta(m.$1, icon: m.$2, height: 52, px: 16, fs: 15, onTap: m.$3),
                              if (v.alt case final a?) OutlineCta(a.$1, icon: a.$2, onTap: a.$3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (st == 'paying' && pay?.status == 'missing')
                    Tap(onTap: () => s.cancelBooking(hold), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Cancel and pick another bed', w: 600, s: 14, c: p.ad))),
                  if (st == 'waiting' || st == 'confirmed' || st == 'held')
                    Tap(onTap: () => s.releaseWithUndo(hold), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Release this hold', w: 600, s: 14, c: p.ad))),
                  // Demo only: never in the Play Store build (F17).
                  if (st == 'waiting' && kDebugMode)
                    Tap(
                      onTap: () {
                        s.setHold(hold.id, 'confirmed');
                        s.toastMsg('$owner confirmed on WhatsApp.');
                      },
                      child: Dashed(color: p.dv, width: 1, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), child: T('Demo: simulate the owner confirming', s: 12, c: p.mu)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// F18 (D9): the hostels the tenant saved, kept on this phone.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = [for (final e in s.saved.entries) if (e.value && hostels.any((h) => h.id == e.key)) hostelById(e.key)];
    // F22 Area 1: photo rows; removing one can be undone.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Row(children: [if (s.hist.isNotEmpty) ...[BackBtn(onTap: s.back), const SizedBox(width: 12)], const T('Saved', s: 30, w: 800, lh: 1.02, ls: -.025)]),
        ),
        Expanded(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  child: Column(
                    children: [
                      Container(width: 64, height: 64, alignment: Alignment.center, color: p.sf, child: const Ic('heart', size: 30)),
                      const SizedBox(height: 12),
                      const T('Nothing saved yet', w: 800, s: 22, align: TextAlign.center),
                      const SizedBox(height: 8),
                      T('Tap the heart on any hostel to keep it here.', s: 15, c: p.mu, lh: 1.5, align: TextAlign.center),
                      const SizedBox(height: 14),
                      Cta('Find a bed', height: 50, px: 16, fs: 15, expand: false, onTap: () => s.tab('explore')),
                    ],
                  ),
                )
              : Scroll(
                  key: ValueKey('saved${s.scrollEpoch}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in list)
                        () {
                          final photos = s.photosOf[h.id] ?? const [];
                          final cost = cardCost(s, h);
                          return Tap(
                            key: ValueKey('savedRow-${h.id}'),
                            onTap: () => s.update(() {
                              s.hist = [...s.hist, s.screen];
                              s.screen = 'detail';
                              s.hid = h.id;
                              s.dealAc = null;
                              s.rulesOpen = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    height: 72,
                                    child: CustomPaint(
                                      painter: Hatch(p.sf, 8, 16, base: p.bg),
                                      child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        T(h.name, w: 800, s: 16),
                                        T('${h.gender} · ${h.area} · ${s.freeOf(h.id).f} free', s: 13, c: p.mu),
                                        if (cost != null) T('${fmt(cost.fee)}/mo', s: 14, w: 800),
                                      ],
                                    ),
                                  ),
                                  Tap(
                                    key: ValueKey('unsave-${h.id}'),
                                    onTap: () => s.toggleSaved(h.id),
                                    child: Semantics(label: 'Remove from saved', child: SizedBox(width: 44, height: 44, child: Center(child: Ic('heart', size: 20, color: p.ad)))),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
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
