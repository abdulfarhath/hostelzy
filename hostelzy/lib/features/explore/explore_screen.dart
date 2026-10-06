import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../photos/photos_screens.dart';
import '../reminders/reminders_screens.dart';
import 'unverified_screen.dart';

// ------------------------------------------------------------ derived values

/// F26 #2: the sort dropdown, in its order (Price ↑ is the default).
const sortLabels = {'price': 'Price ↑', 'near': 'Distance', 'rating': 'Rating', 'deals': 'Best deals'};

/// "Then by price, lowest first" under the pinned Featured hostel.
const sortThen = {'price': 'Then by price, lowest first', 'near': 'Then by distance, nearest first', 'rating': 'Then by rating, highest first', 'deals': 'Then by Hostelzy deal, biggest saving first'};

/// One ordering step: negative when [a] goes first, 0 when it can't tell.
typedef HostelOrder = int Function(Hostel a, Hostel b);

/// The lowest rent that fits the room filter; a listed (UNVERIFIED) hostel
/// has only its expected range, so its lowest end.
int cheapestRent(AppState s, Hostel h) => h.listed ? h.rentMin : s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).fold<int>(1 << 30, (a, r) => r.rent < a ? r.rent : a);

/// F26 #21: the listing-tier step, run before the picked sort. Under
/// Price ↑: ✓ VERIFIED first inside each ₹2,000 price band ([tierCompare]);
/// under any other sort listed hostels come after every verified one.
HostelOrder? listingTierStep(AppState s) => (a, b) => tierCompare(a, b, (h) => cheapestRent(s, h), byPrice: s.sortBy == 'price');

List<Hostel> filtered(AppState s) {
  final lim = {'Any': 1e9, '6k': 6000, '8k': 8000, '10k': 10000}[s.fB]!;
  bool ok(Hostel h) {
    // F26 #21: a listed (UNVERIFIED) hostel has only its expected rent range;
    // filters it can't answer (food, deals, a free bed, AC, amenities) leave it out.
    if (h.listed) {
      return !s.removed(h.id) && s.inMapArea(h) && (s.fG == 'Any' || h.gender == s.fG) && h.rentMin <= lim && !s.fFood && !s.fDeals && s.fS == 'Any' && s.fR == 'Any' && s.fAm.isEmpty;
    }
    final rs = s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).toList();
    if (rs.isEmpty) return false;
    final from = rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
    // F07: a hostel with 3 strikes is removed from Hostelzy.
    if (s.removed(h.id)) return false;
    // F18: the area picked on the map.
    if (!s.inMapArea(h)) return false;
    return (s.fG == 'Any' || h.gender == s.fG) && (!s.fFood || h.food) && (!s.fNoFood || !h.food) && (!s.fDeals || s.bestQuote(h.id, f: s.fR) != null) && from <= lim && (s.fS == 'Any' || rs.any((r) => r.share == int.parse(s.fS) && r.beds.any((b) => b.state == 'free'))) && (s.fAm.isEmpty || s.hasAmenities(h.id, s.fAm));
  }

  final out = browsable.where(ok).toList();
  // Array.prototype.sort is stable; List.sort is not guaranteed to be, so the last step is the index.
  final idx = {for (var i = 0; i < hostels.length; i++) hostels[i].id: i};
  // F03 Best deals: the 6-month saving (the Explore ribbon and the hostel
  // page headline); paused or hidden deals (F07, F10) have none, so 0.
  int saving(Hostel h) {
    final q = s.bestQuote(h.id, f: s.fR);
    return q == null ? 0 : q.save6 * 10 + (q.upfront > 0 ? 1 : 0);
  }

  int cheapest(Hostel h) => cheapestRent(s, h);
  // A hostel with no reviews yet has no rating: after every rated one.
  double stars(Hostel h) => h.reviews == 0 ? -1 : h.rating;
  int km(Hostel a, Hostel b) => s.kmFor(a).compareTo(s.kmFor(b));

  // F26 #2: the picked sort, then nearest, then the list order.
  final steps = <HostelOrder>[
    ?listingTierStep(s),
    switch (s.sortBy) {
      'near' => km,
      'rating' => (a, b) => stars(b).compareTo(stars(a)),
      'deals' => (a, b) => saving(b).compareTo(saving(a)),
      _ => (a, b) => cheapest(a).compareTo(cheapest(b)),
    },
    km,
    (a, b) => idx[a.id]!.compareTo(idx[b.id]!),
  ];
  out.sort((a, b) {
    for (final f in steps) {
      final d = f(a, b);
      if (d != 0) return d;
    }
    return 0;
  });
  // F10 / F26 #2: one featured (80+ bed) hostel keeps a pinned spot on top.
  if (pinnedFeatured(s, out) case final pin?) {
    out
      ..remove(pin)
      ..insert(0, pin);
  }
  return out;
}

/// The one featured hostel pinned on top of [results]: the best-ranked
/// featured one (F10 plan), or null.
Hostel? pinnedFeatured(AppState s, List<Hostel> results) {
  Hostel? top;
  var best = double.negativeInfinity;
  for (final h in results) {
    // F26 #21: ranking and the featured spot are for verified hostels only.
    if (h.listed || !s.featured(h.id)) continue;
    final v = s.rankScore(h.id);
    if (v > best) (top, best) = (h, v);
  }
  return top;
}

/// F26 #2: the tag on the first card after the pinned one, when the sort
/// makes it true ("Lowest price", "Nearest"); none otherwise.
String? firstTag(String sortBy) => switch (sortBy) {
  'price' => 'Lowest price',
  'near' => 'Nearest',
  _ => null,
};

/// F26 #1: the 📍 inside the search field: the map at my location (the
/// location explainer first, when it isn't on yet).
void openMapNearMe(AppState s) {
  s.tab('map');
  s.update(() {
    if (s.myPos == null) {
      s.sheet = 'loc';
    } else {
      s.mapArea = null;
      s.areaCenter = null;
      s.mapMoved = false;
      s.mapFocus++;
    }
  });
}

/// F26 #2: "Near me" chip. Off: the location explainer. On: tapped again →
/// Pick a place (area or landmark, the Where? field).
void tapNearMe(AppState s) {
  if (s.myPos == null) {
    s.update(() => s.sheet = 'loc');
  } else {
    s.openWhere();
  }
}

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
    // F26 #2: one featured hostel pinned on top, then the picked sort.
    final pinned = results.isNotEmpty && !results.first.listed && s.featured(results.first.id) ? results.first : null;
    final rest = pinned == null ? results : results.skip(1).toList();
    // F26 #21: inside a price band a verified hostel goes before a cheaper
    // listed one, so "Lowest price" only when it really is the lowest.
    final lowest = rest.isEmpty || s.sortBy != 'price' || rest.every((h) => cheapestRent(s, h) >= cheapestRent(s, rest.first));
    final tag = rest.isNotEmpty && !rest.first.listed && lowest ? firstTag(s.sortBy) : null;
    final totalFree = results.fold<int>(0, (a, h) => a + s.freeOf(h.id).f);
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
              child: Row(children: [Expanded(child: T('Browsing as a guest', s: 13, w: 600, c: p.mu)), Tap(onTap: s.startSignIn, child: const T('Sign in', s: 13, w: 800, underline: true))]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: VGap(
              gap: 12,
              children: [
                // F26 #21: "Madhapur · 12 verified · 84 listed" once anything is listed.
                PageHead(kicker: s.listState == 'ready' ? s.tierLine(s.mapArea) ?? 'Hyderabad · $totalFree beds free now' : 'Hyderabad', title: 'Find a bed', gap: 2),
                if (s.showToday) const TodayCard(margin: EdgeInsets.zero),
                WhereBar(onTap: s.openWhere, onPin: () => openMapNearMe(s)),
              ],
            ),
          ),
          Scroll(
            horizontal: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  // F26 #2: [📍 Near me ✓] [Price ↑ ▾] [Filters · n].
                  RowBtn('Near me', key: const ValueKey('nearMeChip'), on: s.myPos != null, lead: 'pin', trail: s.myPos != null ? 'check' : null, onTap: () => tapNearMe(s)),
                  const SizedBox(width: 6),
                  RowBtn(sortLabels[s.sortBy] ?? 'Price ↑', key: const ValueKey('sortBtn'), trail: 'chevD', onTap: () => s.update(() => s.sheet = 'sort')),
                  const SizedBox(width: 6),
                  FiltersBtn(onTap: () => s.update(() => s.sheet = 'search')),
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
                if (pinned != null) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Kicker('Featured')),
                  HostelCard(pinned, pinned: true),
                  if (rest.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Kicker(sortThen[s.sortBy] ?? '')),
                ],
                for (final (i, h) in rest.indexed) h.listed ? UnverifiedCard(h) : HostelCard(h, tag: i == 0 && rest.length > 1 ? tag : null),
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
  const WhereBar({super.key, required this.onTap, this.onPin, this.height = 50});
  final VoidCallback onTap;

  /// F26 #1: the 📍 inside the field (Explore: the map at my location).
  final VoidCallback? onPin;
  final double height;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final set = s.mapArea != null || s.areaCenter != null || s.myPos != null || s.lm != landmarks.first;
    final field = Tap(
      key: const ValueKey('whereBar'),
      onTap: onTap,
      child: Container(
        height: height - 4,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Ic('search', size: 18),
            const SizedBox(width: 10),
            Expanded(child: set ? T(s.whereLabel, s: 15, w: 800, ell: true) : T('Area, landmark or hostel', s: 15, c: p.mu, ell: true)),
          ],
        ),
      ),
    );
    return Container(
      height: height,
      decoration: box(bg: p.bg, w: 2, c: p.tx),
      child: Row(
        children: [
          Expanded(child: field),
          if (onPin != null)
            Tap(
              key: const ValueKey('wherePin'),
              onTap: onPin,
              child: Semantics(
                label: 'Map at my location',
                button: true,
                child: Container(
                  width: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border(left: bs(2, p.tx))),
                  child: Ic('pin', size: 22, color: p.ad),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// F26 #2: a button in the row under the search field (40 px, 2 px rule);
/// filled when [on].
class RowBtn extends StatelessWidget {
  const RowBtn(this.label, {super.key, required this.onTap, this.on = false, this.lead, this.trail});
  final String label;
  final VoidCallback onTap;
  final bool on;
  final String? lead, trail;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final fg = on ? p.bg : p.tx;
    return Tap(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: box(bg: on ? p.tx : transparent, w: 2, c: p.tx),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lead != null) ...[Ic(lead!, size: 16, color: fg), const SizedBox(width: 6)],
            T(label, s: 13, w: 800, c: fg, nowrap: true),
            if (trail != null) ...[const SizedBox(width: 6), Ic(trail!, size: 14, color: fg)],
          ],
        ),
      ),
    );
  }
}

/// "Filters · n"; opens the Filters sheet (Men / Women / Co-living, AC, food, rent…).
class FiltersBtn extends StatelessWidget {
  const FiltersBtn({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = s.filterCount;
    return RowBtn(n > 0 ? 'Filters · $n' : 'Filters', key: const ValueKey('filtersBtn'), lead: 'sliders', onTap: onTap);
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

/// Photo-first hostel card (F21 W2): photo, save heart, a tag ("Featured" on
/// the pinned one, F26 #2: "Lowest price" / "Nearest" on the first after it),
/// a green Hostelzy price only when there's a deal, then the real cost.
class HostelCard extends StatelessWidget {
  const HostelCard(this.h, {super.key, this.pinned = false, this.tag});
  final Hostel h;
  final bool pinned;
  final String? tag;
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
                      if (pinned || tag != null)
                        Positioned(left: 8, top: 8, child: Container(key: pinned ? ValueKey('featured-${h.id}') : null, color: p.tx, padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: T(pinned ? 'Featured' : tag!, s: 13, w: 800, c: p.bg))),
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

/// F18 (D9): the hostels the tenant saved, kept on this phone.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, this.bare = false});

  /// F26 #17: inside Saved & Holds, without its own title.
  final bool bare;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = [for (final e in s.saved.entries) if (e.value && hostels.any((h) => h.id == e.key)) hostelById(e.key)];
    // F22 Area 1: photo rows; removing one can be undone.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!bare)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: Row(children: [if (s.hist.isNotEmpty) ...[BackBtn(onTap: s.back), const SizedBox(width: 12)], const T('Saved', s: 30, w: 800, lh: 1.02, ls: -.025)]),
          ),
        Expanded(
          child: list.isEmpty
              ? Scroll(child: Padding(
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
                ))
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
