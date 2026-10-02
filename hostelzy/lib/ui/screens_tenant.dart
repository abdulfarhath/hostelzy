import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
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
    return (s.fG == 'Any' || h.gender == s.fG) && (!s.fFood || h.food) && (!s.fDeals || s.bestQuote(h.id, f: s.fR) != null) && from <= lim && (s.fS == 'Any' || rs.any((r) => r.share == int.parse(s.fS) && r.beds.any((b) => b.state == 'free')));
  }

  final out = browsable.where(ok).toList();
  // Array.prototype.sort is stable; List.sort is not guaranteed to be, so sort by (mins, index).
  final idx = {for (var i = 0; i < hostels.length; i++) hostels[i].id: i};
  int saving(Hostel h) {
    final q = s.bestQuote(h.id, f: s.fR);
    return q == null ? -1 : q.save6 * 10 + (q.upfront > 0 ? 1 : 0);
  }

  int cheapest(Hostel h) => s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).fold<int>(1 << 30, (a, r) => r.rent < a ? r.rent : a);
  final score = {for (final h in out) h.id: s.rankScore(h.id)};

  out.sort((a, b) {
    // F08 Recommended (Hostelzy rank), F03 Best deals, or Lowest price; then nearest.
    final d = switch (s.sortBy) {
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
                PageHead(kicker: 'Hyderabad · $totalFree beds free now', title: 'Find a bed', gap: 2),
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
                // F21 W2: the rank shows once, on the first card.
                for (final (i, h) in results.indexed) HostelCard(h, first: i == 0 && s.sortBy == 'rec'),
                // F18 design "Empty": no hostels live yet (or none in the area picked).
                if (browsable.isEmpty || (results.isEmpty && s.mapArea != null))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    child: VGap(
                      gap: 10,
                      children: [
                        T(s.mapArea != null ? 'No hostels in ${s.mapArea} yet' : 'No hostels in this area yet', w: 800, s: 20),
                        T('Hostelzy is adding hostels area by area, after a visit to each one. Check back soon, or try another area.', s: 14, c: p.mu, lh: 1.45),
                        Align(alignment: Alignment.centerLeft, child: Tap(onTap: s.openWhere, child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), decoration: box(w: 2, c: p.tx), child: const T('Pick another area', w: 800, s: 14)))),
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
            ),
          ),
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
                      if (first)
                        Positioned(left: 8, top: 8, child: Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), child: T('#1 near you', s: 13, w: 800, c: p.bg))),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Tap(
                          key: ValueKey('save-${h.id}'),
                          onTap: () {
                            s.update(() => s.saved[h.id] = !saved);
                            s.toastMsg(saved ? 'Removed from saved' : 'Saved on this phone.');
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
  final secs = s.holdSecs;
  return (hh: hh, r: r, left: secs - (s.now - h.start) / 1000);
}

class HoldsScreen extends StatelessWidget {
  const HoldsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const lab = {'waiting': 'Waiting for owner', 'confirmed': 'Confirmed', 'held': 'Held', 'paying': 'Advance · owner to confirm', 'booked': 'Booked · advance confirmed', 'released': 'Released'};
    return Scroll(
      key: ValueKey('holds${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: const PageHead(kicker: "Beds you're holding", title: 'Holds'),
          ),
          // F07 board 3: asked after one of your holds ends (the 102-B sample
          // shows in debug builds only, F17).
          if (s.joinAnswer == null && (s.endedHold != null || kDebugMode))
            Tap(
              onTap: () => s.update(() => s.sheet = 'joined'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(s.endedHold != null ? '${hostelById(s.endedHold!.hid).name} · ${s.endedHold!.bed}' : 'Anjani Residency · 102-B', w: 800, s: 15), T('Hold ended${s.endedHold != null ? '' : ' 11 Sep'} · Did you join? One tap', s: 12, c: p.mu)])),
                    Container(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7), decoration: box(w: 1, c: p.dv), child: T('Ended', s: 11, w: 800, ls: .05, upper: true, c: p.mu)),
                  ],
                ),
              ),
            ),
          for (final h in s.holds.reversed)
            () {
              final i = holdInfo(s, h);
              final timed = const ['waiting', 'confirmed', 'held'].contains(h.status);
              return Tap(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T(s.expiredHolds.contains(h.id) ? 'Expired' : lab[h.status]!, s: 11, w: 600, ls: .08, upper: true, lh: 1.3, c: p.ad),
                            const SizedBox(height: 3),
                            T('Bed ${h.bed}', w: 800, s: 18),
                            const SizedBox(height: 3),
                            T('${i.hh.name} · ${fmt(i.r.rent)}/mo', s: 13, c: p.mu),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          T(
                            timed
                                ? cd(i.left)
                                : h.status == 'booked'
                                ? 'Booked'
                                : '—',
                            w: 800,
                            s: 22,
                            tab: true,
                          ),
                          T(
                            timed
                                ? 'left'
                                : h.status == 'booked'
                                ? 'move-in'
                                : '',
                            s: 11,
                            c: p.mu,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }(),
          if (s.holds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: VGap(
                gap: 10,
                children: [
                  const T('No holds yet.', w: 800, s: 22, lh: 1.1),
                  T('Pick a bed in any hostel and hold it free for an hour while you go and see it.', s: 14, c: p.mu, lh: 1.45),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Cta('Find a bed', onTap: () => s.tab('explore'), height: null, vpad: 12, px: 16, fs: 14, iconSize: 14, expand: false, gap: 10),
                    ),
                  ),
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
    void move(String t) => s.update(() {
      s.hist = [...s.hist, s.screen];
      s.screen = 'move';
      s.sheet = null;
      s.moveTab = t;
    });
    // F21 W3: My stay (moved off resident Home).
    final stay = <(String, VoidCallback, Color)>[
      ('Room layouts · fix any room', () => s.openFixRoom(s.myRoomLabel.isEmpty ? (s.rooms[s.homeHid ?? 'anjani']?.first.n ?? 101) : int.tryParse(s.myRoomLabel) ?? 101), p.tx),
      ('Swap bed', () => move('swap'), p.tx),
      ('Give notice', () => move('vacate'), p.tx),
    ];
    final rows = <(String, VoidCallback, Color)>[
      ('Reminders · ${s.remSummary}', s.openReminders, p.tx),
      if (!isOwner) ('Stay Rewards · ${const {'trusted': 'Trusted tenant', 'member': 'Member'}[s.level] ?? 'not a member yet'}', () => s.go('rewards'), p.tx),
      ('Saved hostels · ${s.saved.values.where((v) => v).length}', () => s.go('saved'), p.tx),
      ('Settings', () => s.go('settings'), p.tx),
      ('Switch role', () => s.tab('role'), p.tx),
      ('Log out', s.logOut, p.ad),
    ];
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
                  child: T(initials(s.meName.isNotEmpty ? s.meName : (isOwner ? hostelById(s.ownHid).owner : '')), w: 800, s: 24, c: p.ai),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T(s.meName.isNotEmpty ? s.meName : (isOwner ? hostelById(s.ownHid).owner : 'Add your name'), w: 800, s: 24, lh: 1.05),
                      const SizedBox(height: 3),
                      T('${s.phone.length == 10 ? '+91 ${phoneSpaced(s.phone)}' : 'Add your number'} · ${{'tenant': 'Looking for a bed', 'resident': 'Resident', 'owner': 'Owner, ${hostelById(s.ownHid).name}'}[s.role]}', s: 13, c: p.mu),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: VGap(
              gap: 10,
              children: [
                const Kicker('Appearance'),
                Seg(opts: const [('light', 'Light'), ('dark', 'Dark')], cur: s.theme, onPick: (v) => s.update(() => s.theme = v), pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12), fs: 14),
              ],
            ),
          ),
          if (s.role == 'resident') ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('My stay')),
            for (final r in stay)
              Tap(
                key: ValueKey('stay-${r.$1}'),
                onTap: r.$2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(top: r == stay.first ? bs(2, p.dv) : BorderSide.none, bottom: bs(1, p.hl))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T(r.$1, s: 15, w: 600), Ic('chev', size: 18, color: p.mu)]),
                ),
              ),
            const SizedBox(height: 12),
          ],
          for (final r in rows)
            Tap(
              onTap: r.$2,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    T(r.$1, s: 15, w: 600, c: r.$3),
                    Ic('chev', size: 18, color: p.mu),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: T('Hostelzy 1.0 · Made in Hyderabad', s: 12, c: p.mu),
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
              if (!moneyRules(h).any((m) => m[0] == r.k)) [r.k, r.v],
            ...moneyRules(h),
          ]
        : h.id == 'anjani'
        ? [
            for (final r in s.rules)
              if (!moneyRules(h).any((m) => m[0] == r.k)) [r.k, r.v],
            ...moneyRules(h),
          ]
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
                              s.update(() => s.saved[h.id] = !saved);
                              s.toastMsg(saved ? 'Removed from saved' : 'Saved on this phone.');
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
    // F12: Room sits beside Plan; Plan stays the default. F21 W2: Building
    // folds into Plan's floors; the list is a "See cheapest beds" link.
    const modes = [('plan', 'Plan'), ('room', 'Room')];
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(h.name, ell: true), const T('Pick a bed', w: 800, s: 22, lh: 1.1)]),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: box(w: 2, c: p.tx),
          child: Row(
            children: [
              for (var i = 0; i < modes.length; i++)
                Expanded(
                  child: Tap(
                    onTap: () => s.update(() => s.mode = modes[i].$1),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: s.mode == modes[i].$1 ? p.tx : transparent,
                        border: i > 0 ? Border(left: bs(1, p.hl)) : null,
                      ),
                      child: Css(
                        c: s.mode == modes[i].$1 ? p.bg : p.tx,
                        s: 13,
                        w: 600,
                        child: T(modes[i].$2, align: TextAlign.center),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              key: const ValueKey('cheapest'),
              onTap: () => s.update(() => s.mode = s.mode == 'list' ? 'plan' : 'list'),
              child: T(s.mode == 'list' ? '‹ Back to the plan' : 'See cheapest beds ›', s: 14, w: 800, c: p.ad),
            ),
          ),
        ),
        if (h.ac && h.hasNon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Padding(padding: EdgeInsets.only(right: 4), child: Kicker('Room')),
                for (final f in const ['Any', 'AC', 'Non-AC']) ...[
                  const SizedBox(width: 6),
                  ChipBtn(f, on: s.pR == f, onTap: () => s.pickRoomType(f)),
                ],
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
                    T(hasSel ? 'Bed ${sb.b!.id}' : 'No bed picked', w: 800, s: 17),
                    T(hasSel ? '${sb.b!.spot} · ${sb.r!.share} sharing · ${sb.r!.type} · ${fmt(sb.r!.rent)}/mo' : 'Tap a free bed to hold it', s: 12, c: p.mu, ell: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta('Hold bed', onTap: () => s.bed == null ? s.toastMsg('Pick a free bed first.') : s.update(() => s.sheet = 'hold'), height: 50, px: 18, fs: 15, expand: false, opacity: hasSel ? 1 : .4),
            ],
          ),
        ),
      ],
    );
  }
}

const pickerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked'), ('Selected', 'sel')];

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
    final cols = room.share == 3 ? 3 : 2;
    final beds = room.beds;
    final rows = <Widget>[];
    for (var i = 0; i < beds.length; i += cols) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) cells.add(const SizedBox(width: 10));
        cells.add(Expanded(child: i + j < beds.length ? _PlanBed(beds[i + j]) : const SizedBox()));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FloorTabs(
          items: floors,
          cur: s.floor,
          onPick: (f) {
            final fit = rooms.where((r) => r.floor == f && AppState.fits(r, s.pR));
            final r = fit.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? fit.firstOrNull ?? rooms.firstWhere((r) => r.floor == f);
            s.update(() {
              s.floor = f;
              s.room = r.n;
              s.bed = null;
            });
          },
        ),
        // F14 uneven floors: tiles wrap into rows of 4, however many rooms.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < tiles.length; i++)
                  () {
                    final r = tiles[i];
                    final fr = r.beds.where((b) => (b.state == 'free' || b.state == 'soon') && !b.mine).length;
                    final fits = AppState.fits(r, s.pR);
                    return Tap(
                      enabled: fits,
                      // F12: tapping a room opens it in the Room tab.
                      onTap: () => s.openRoom(r.n),
                      child: Opacity(
                        opacity: !fits ? .35 : (fr > 0 ? 1 : .5),
                        child: Container(
                          width: (c.maxWidth - 24) / 4,
                          padding: const EdgeInsets.all(10),
                          decoration: box(w: 2, c: r.n == room.n ? p.ac : p.hl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T(r.label, w: 800, s: 19),
                              const SizedBox(height: 3),
                              Align(alignment: Alignment.centerLeft, child: RoomTypeTag(r.ac)),
                              const SizedBox(height: 3),
                              T('${r.share} sharing', s: 12, c: p.mu),
                              const SizedBox(height: 2),
                              T(fr > 0 ? '$fr open' : 'Full', s: 12, w: 600),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  T('Room ${room.n}', w: 800, s: 20, nowrap: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Rich([sp(context, '${room.share} sharing · ${room.type} · ${fmt(room.rent)}'), sp(context, '/mo', w: 400, c: p.mu)], s: 13, w: 600, align: TextAlign.right),
                  ),
                ],
              ),
              if (room.ac && room.acRepair)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  color: p.ab,
                  child: T('AC under repair. Complaint raised 30 Sep. The owner is fixing it.', s: 12, w: 600, c: p.ad, lh: 1.4),
                ),
              const SizedBox(height: 12),
              Container(
                decoration: box(w: 2, c: p.tx),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 36, 14, 38),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
                        ),
                        Positioned(
                          top: -2,
                          left: w * .22,
                          width: w * .56,
                          height: 6,
                          child: Container(color: p.tx),
                        ),
                        Positioned(top: 10, left: w * .22, child: const _PlanLabel('Window')),
                        if (room.ac)
                          Positioned(
                            top: 8,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                              decoration: box(w: 1, c: p.tx),
                              child: const T('AC UNIT', s: 10, w: 800, ls: .08),
                            ),
                          ),
                        Positioned(bottom: -2, right: 20, width: 64, height: 2, child: Container(color: p.bg)),
                        const Positioned(bottom: 10, right: 20, child: _PlanLabel('Door')),
                        if (room.bath == 'Attached') const Positioned(bottom: 10, left: 14, child: _PlanLabel('Attached bath ↙')),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              const Legend(items: pickerLegend),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanLabel extends StatelessWidget {
  const _PlanLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Kicker(text, s: 10);
}

class _PlanBed extends StatelessWidget {
  const _PlanBed(this.b);
  final Bed b;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final l = lookOf(p, b, s.bed);
    return Tap(
      enabled: l.can,
      onTap: () => s.pickBed(b),
      child: BedBox(
        look: l.look,
        minHeight: 118,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(b.letter, w: 800, s: 28, lh: 1),
                Opacity(
                  opacity: .55,
                  child: Container(width: 16, height: 24, decoration: box(w: 1.5, c: l.look.fg)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(b.spot, s: 12, lh: 1.25), const SizedBox(height: 4), T(l.tag, s: 10, w: 600, ls: .08, upper: true, lh: 1.3)]),
          ],
        ),
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

class HoldScreen extends StatelessWidget {
  const HoldScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hold = s.holds.where((h) => h.id == s.holdId).firstOrNull ?? s.holds.lastOrNull;
    var hostel = '', bed = '', label = '', big = '', sub = '', owner = '';
    var bg = p.sf, fg = p.tx;
    var rows = <(String, String)>[];
    var steps = <TimelineStep>[];
    var canSim = false, canCancel = false, canMoveIn = false, expired = false;
    Payment? pay;
    VoidCallback wa = () {};
    if (hold != null) {
      final i = holdInfo(s, hold);
      final st = hold.status;
      pay = hold.opt == 'book' ? s.payOfHold(hold.id) : null;
      final amt = fmt(pay?.amt ?? hold.paid);
      final utr = utrSpaced(pay?.utr ?? '');
      final m = switch (st) {
        // F17: a booking stays "paying" until the owner confirms the money.
        'paying' => switch (pay?.status) {
          'waiting' => ['Waiting for ${i.hh.owner}', amt, 'Payment sent · ${i.hh.owner} needs to see $amt with UPI reference $utr in their account. Until then the bed is not booked yet.', 'sf', 'tx'],
          'missing' => ['Not received', amt, '${i.hh.owner} says the payment didn’t arrive. Check UPI reference $utr in your UPI app. If the money left your account, send ${i.hh.owner} the UPI receipt on WhatsApp, or ask your bank.', 'sf', 'tx'],
          _ => ['Pay the advance', amt, 'Pay ${i.hh.owner} by UPI, then enter the UTR. The bed is held for you meanwhile; it says Booked only after ${i.hh.owner} confirms.', 'sf', 'tx'],
        },
        'booked' when pay?.done != null => ['Booked', 'Yours.', '${i.hh.owner} confirmed $amt on ${pay!.done}. Show booking code ${hold.ref ?? ''} at the hostel on move-in day.', 'gn', 'ai'],
        'waiting' => ['Free hold', cd(i.left), 'left on your free hold. ${i.hh.owner} doesn’t know yet: tell them on WhatsApp so they keep the bed.', 'sf', 'tx'],
        'confirmed' => ['Confirmed by ${i.hh.owner}', cd(i.left), 'Go and see it before the timer ends to keep the bed.', 'gn', 'ai'],
        'held' => ['Held for you', cd(i.left), 'Go and see it before the timer ends to keep the bed.', 'gn', 'ai'],
        'booked' => ['Booked', 'Yours.', 'Advance paid to ${i.hh.owner}. Show booking code ${hold.ref ?? ''} when you move in. Your price is fixed.', 'gn', 'ai'],
        _ when s.expiredHolds.contains(hold.id) => ['Hold expired', '0:00', 'Your hold has ended. Bed ${hold.bed} is free for everyone again. You can hold it again if it’s still free.', 'sf', 'tx'],
        _ => ['Released', '—', 'The hold ended. You paid nothing.', 'sf', 'tx'],
      };
      expired = st == 'released' && s.expiredHolds.contains(hold.id);
      final done = st != 'waiting' && st != 'released' && st != 'paying';
      hostel = i.hh.name;
      bed = hold.bed;
      label = m[0];
      big = m[1];
      sub = m[2];
      bg = m[3] == 'gn' ? p.gn : p.sf;
      fg = m[4] == 'ai' ? p.ai : p.tx;
      owner = i.hh.owner;
      final o = holdOptions[hold.opt]!;
      final q = s.quote(hold.hid, i.r.ac, i.r.share);
      rows = [
        ('Room', '${i.r.n} · ${i.r.share} sharing · Floor ${i.r.floor}'),
        ('Rent', '${fmt(q.hzFee)} a month'),
        ('Hold type', o.title),
        if (hold.opt == 'book') ...[(st == 'booked' ? 'Paid to ${i.hh.owner}' : 'Advance to ${i.hh.owner}', fmt(hold.paid)), if (pay?.utr != null) ('UPI reference', utr), ('Booking code', hold.ref ?? '—'), if (hold.perks.isNotEmpty) ('Your price is fixed', hold.perks.join(' · '))] else ('Paid now', '₹0'),
      ];
      steps = [
        TimelineStep(t: 'Hold placed', d: 'Bed taken off the market for everyone else', bg: p.tx, bd: p.tx),
        TimelineStep(t: hold.opt == 'free' ? 'Owner confirms' : 'Owner confirms the advance', d: hold.opt == 'free' ? (done ? 'Confirmed by ${i.hh.owner}' : 'After you tell ${i.hh.owner} on WhatsApp') : (st == 'booked' ? 'Confirmed by ${i.hh.owner}' : 'After you send the UTR'), bg: done ? p.tx : p.ac, bd: done ? p.tx : p.ac),
        TimelineStep(t: 'Visit and move in', d: hold.opt == 'book' ? 'Pay the first month (${fmt(q.hzFirst)}) at move-in. Show ${hold.ref}.' : 'Pay ${fmt(q.hzAdv)} advance + first month at move-in.', bg: done ? p.ac : transparent, bd: done ? p.ac : p.tk),
      ];
      // Demo only: never in the Play Store build (F17).
      canSim = st == 'waiting' && kDebugMode;
      canCancel = st == 'waiting' || st == 'confirmed' || st == 'held';
      canMoveIn = st == 'confirmed' || st == 'booked' || st == 'held';
      wa = () => s.enquire(hold.hid, "Hi ${i.hh.owner}, I've held bed ${hold.bed} at ${i.hh.name} on Hostelzy. Can I come and see it today at 6 pm?", bed: hold.bed, from: 'Hold · WhatsApp owner');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(hostel), T('Bed $bed', w: 800, s: 22, lh: 1.1)]),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('hold${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(bottom: bs(2, p.tx)),
                  ),
                  child: Css(
                    c: fg,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(label, s: 11, w: 600, ls: .1, upper: true), const SizedBox(height: 6), T(big, w: 800, s: 64, lh: 1, ls: -.03, tab: true), const SizedBox(height: 8), T(sub, s: 14, lh: 1.4)]),
                  ),
                ),
                for (final r in rows) KV(r.$1, r.$2, keyWidth: 120),
                const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('What happens next')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: steps),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: VGap(
                    gap: 8,
                    children: [
                      if (canMoveIn)
                        Cta("Moving in · see what to pay", height: 52, px: 16, fs: 15, onTap: () => s.go('moveIn')),
                      if (pay != null && hold?.status == 'paying') ...[
                        if (pay.status == 'due') ...[
                          Cta('Pay ${fmt(pay.amt)} by UPI', height: 52, px: 16, fs: 15, onTap: () => s.payByUpi(pay!)),
                          OutlineCta('I’ve already paid · enter UTR', icon: 'chev', onTap: () => s.openPayUtr(pay!)),
                        ],
                        if (pay.status == 'waiting') ...[
                          Cta('Remind $owner on WhatsApp', icon: 'msg', height: 52, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: () => s.whatsapp(ownerPhones[pay!.hid] ?? '', 'Hi $owner, I paid the ${fmt(pay.amt)} advance for bed ${pay.bed} by UPI. UTR ${utrSpaced(pay.utr ?? '')}, note ${pay.note}. Please confirm on Hostelzy.')),
                          OutlineCta('Fix the UTR', icon: 'chev', onTap: () => s.openPayUtr(pay!)),
                        ],
                        if (pay.status == 'missing') ...[
                          Cta('Fix the UTR', height: 52, px: 16, fs: 15, onTap: () => s.openPayUtr(pay!)),
                          OutlineCta('Talk to $owner on WhatsApp', icon: 'msg', onTap: () => s.whatsapp(ownerPhones[pay!.hid] ?? '', 'Hi $owner, about my advance for bed ${pay.bed}: UTR ${utrSpaced(pay.utr ?? '')}, note ${pay.note}.')),
                          Tap(onTap: () => s.cancelBooking(hold!), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Cancel and pick another bed', w: 600, s: 14, c: p.ad))),
                        ],
                      ] else if (expired) ...[
                        Cta('Hold ${hold!.bed} again', height: 52, px: 16, fs: 15, onTap: () {
                          final b = s.findBed(hold.hid, hold.bed).b;
                          if (b == null || b.state != 'free') return s.toastMsg('Bed ${hold.bed} has been taken. See other beds.');
                          s.update(() {
                            s.hid = hold.hid;
                            s.bed = hold.bed;
                          });
                          s.openPicker();
                          s.update(() {
                            s.bed = hold.bed;
                            s.sheet = 'hold';
                          });
                        }),
                        OutlineCta('See other beds', onTap: () {
                          s.update(() => s.hid = hold.hid);
                          s.openPicker();
                        }),
                      ] else
                        Cta(hold?.status == 'waiting' ? 'Tell $owner on WhatsApp' : 'WhatsApp $owner', icon: 'msg', height: 52, px: 16, fs: 15, bg: hold?.status == 'waiting' ? p.ac : p.tx, fg: hold?.status == 'waiting' ? p.ai : p.bg, onTap: wa),
                      OutlineCta('Directions', icon: 'pin', onTap: () => s.directions(hostelById(hold?.hid ?? s.hid))),
                      if (canCancel)
                        Tap(
                          onTap: () => s.releaseHold(hold!, msg: 'Hold released.'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: T('Release this hold', w: 600, s: 14, c: p.ad),
                          ),
                        ),
                      if (canSim)
                        Tap(
                          onTap: () {
                            s.setHold(hold!.id, 'confirmed');
                            s.toastMsg('$owner confirmed on WhatsApp.');
                          },
                          child: Dashed(
                            color: p.dv,
                            width: 1,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            child: T('Demo: simulate the owner confirming', s: 12, c: p.mu),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: 'Me · ${list.length} saved', title: 'Saved hostels', size: 28))]),
        ),
        Expanded(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('Nothing saved yet. Tap Save on a hostel to keep it here.', s: 15, c: p.mu, lh: 1.5),
                      const SizedBox(height: 14),
                      Cta('Explore hostels', onTap: () => s.tab('explore')),
                    ],
                  ),
                )
              : Scroll(
                  child: Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final h in list)
                          Tap(
                            onTap: () => s.update(() {
                              s.hist = [...s.hist, s.screen];
                              s.screen = 'detail';
                              s.hid = h.id;
                              s.dealAc = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                              child: Row(
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(h.name, w: 800, s: 15), T('${h.gender} · ${h.area} · ${kmLabel(s.kmFor(h))} ${s.kmFrom}', s: 12, c: p.mu)])),
                                  Rich([sp(context, fmt(s.fromOf(h))), sp(context, '/mo', s: 12, w: 400, c: p.mu)], s: 16, w: 800),
                                  const SizedBox(width: 8),
                                  Tap(onTap: () => s.update(() => s.saved[h.id] = false), child: Ic('x', size: 18, color: p.mu)),
                                ],
                              ),
                            ),
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
