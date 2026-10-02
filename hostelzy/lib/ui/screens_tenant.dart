import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'deals.dart';
import 'fairplay.dart';
import 'kit.dart';
import 'layout.dart';
import 'onboarding.dart';

// ------------------------------------------------------------ derived values

List<Hostel> filtered(AppState s) {
  final lim = {'Any': 1e9, '6k': 6000, '8k': 8000, '10k': 10000}[s.fB]!;
  bool ok(Hostel h) {
    final rs = s.rooms[h.id]!.where((r) => AppState.fits(r, s.fR)).toList();
    if (rs.isEmpty) return false;
    final from = rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
    // F07: a hostel with 3 strikes is removed from Hostelzy.
    if (s.removed(h.id)) return false;
    return (s.fG == 'Any' || h.gender == s.fG) && (!s.fFood || h.food) && from <= lim && (s.fS == 'Any' || rs.any((r) => r.share == int.parse(s.fS) && r.beds.any((b) => b.state == 'free')));
  }

  final out = hostels.where(ok).toList();
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
    final c = a.mins[s.lm]!.compareTo(b.mins[s.lm]!);
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
    const sorts = [('rec', 'Recommended'), ('near', 'Nearest'), ('price', 'Lowest price'), ('deals', 'Best deals')];
    final chips = [
      ChipBtn('All', on: s.fG == 'Any' && s.fR == 'Any', onTap: () => set(() {
        s.fG = 'Any';
        s.fR = 'Any';
      })),
      ChipBtn('AC', on: s.fR == 'AC', onTap: () => set(() => s.fR = s.fR == 'AC' ? 'Any' : 'AC')),
      ChipBtn('Non-AC', on: s.fR == 'Non-AC', onTap: () => set(() => s.fR = s.fR == 'Non-AC' ? 'Any' : 'Non-AC')),
      ChipBtn('Women', on: s.fG == 'Women', onTap: () => set(() => s.fG = 'Women')),
      ChipBtn('Men', on: s.fG == 'Men', onTap: () => set(() => s.fG = 'Men')),
      ChipBtn('Co-living', on: s.fG == 'Co-living', onTap: () => set(() => s.fG = 'Co-living')),
      ChipBtn('Food included', on: s.fFood, onTap: () => set(() => s.fFood = !s.fFood)),
      ChipBtn('Under ₹8,000', on: s.fB == '8k', onTap: () => set(() => s.fB = s.fB == '8k' ? 'Any' : '8k')),
    ];
    return Scroll(
      key: ValueKey('explore${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: VGap(
              gap: 14,
              children: [
                PageHead(kicker: '${results.length} hostels · $totalFree beds free now', title: 'Beds near ${s.lm}'),
                Tap(
                  onTap: () => set(() => s.sheet = 'search'),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: box(w: 2, c: p.tx),
                    child: Row(
                      children: [
                        const Ic('search', size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: T(searchSummary(s), s: 14, w: 600, ell: true)),
                        const SizedBox(width: 10),
                        T('Edit', s: 12, w: 600, c: p.ad),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Scroll(
            horizontal: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  for (var i = 0; i < sorts.length; i++) ...[if (i > 0) const SizedBox(width: 6), ChipBtn(sorts[i].$2, on: s.sortBy == sorts[i].$1, onTap: () => set(() => s.sortBy = sorts[i].$1))],
                ],
              ),
            ),
          ),
          Scroll(
            horizontal: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 6), chips[i]],
                ],
              ),
            ),
          ),
          if (s.sortBy == 'rec')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                children: [
                  T('Ranked mostly by verified reviews, then reply speed, beds kept up to date, complaints resolved and a complete listing. Fair Play strikes lower the rank. ', s: 12, c: p.mu, lh: 1.45),
                  Tap(onTap: () => set(() => s.sheet = 'rank'), child: T('How it works', s: 12, w: 800, c: p.ad, lh: 1.45)),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in results) HostelCard(h),
                if (results.isEmpty)
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
                            onTap: () => set(() {
                              s.fG = 'Any';
                              s.fS = 'Any';
                              s.fB = 'Any';
                              s.fFood = false;
                              s.fR = 'Any';
                            }),
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

class HostelCard extends StatelessWidget {
  const HostelCard(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // F16: one line per room type, filtered like the list. F03: covered
    // types show the Hostelzy price with the walk-in price struck through.
    final deal = s.dealsOf(h.id);
    final lines = [
      for (final ac in [true, false])
        if (s.fR == 'Any' || (s.fR == 'AC') == ac)
          if (s.typeSummary(h.id, ac) case final t?) (ac: ac, from: t.from, hz: deal.covers(ac) && deal.on.contains('monthly') ? t.from - monthlyOff : t.from, free: t.free),
    ];
    final best = s.bestQuote(h.id, f: s.fR);
    return Tap(
      onTap: () => s.update(() {
        s.hist = [...s.hist, s.screen];
        s.screen = 'detail';
        s.sheet = null;
        s.hid = h.id;
        s.dealAc = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 108,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Stripes(
                    step: 6,
                    height: 118,
                    border: Border.all(width: 1, color: p.hl),
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(6),
                          child: T('facade', s: 10, mono: true, c: p.mu),
                        ),
                        if (s.sortBy == 'rec')
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), child: T('#${s.rankOf(h.id)}', s: 13, w: 800, c: p.bg)),
                          ),
                        if (best != null)
                          Positioned(
                            left: -1,
                            right: -1,
                            bottom: -1,
                            child: Container(color: p.gn, padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6), child: T(best.ribbon, s: 11, w: 800, c: p.ai)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Css(
                      s: 11,
                      w: 600,
                      lh: 1.3,
                      child: Row(
                        children: [
                          Expanded(child: T('${h.gender} · ${h.area}', ls: .08, upper: true, c: p.ad, ell: true)),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Ic('star', size: 11, color: p.tx),
                              const SizedBox(width: 3),
                              T(h.reviews == 0 ? 'New' : '${jsNum(h.rating)} · ${h.reviews}', ls: .08, c: p.tx),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    T(h.name, w: 800, s: 17, lh: 1.15),
                    const SizedBox(height: 4),
                    T('${h.mins[s.lm]} min to ${s.lm} · ${featOf(h)}', s: 13, c: p.mu),
                    // F08: rank and its reasons, never the score number.
                    const SizedBox(height: 3),
                    Rich([sp(context, '#${s.rankOf(h.id)} near ${s.lm}', w: 800, c: p.tx), sp(context, ' · ${s.rankReasons(h.id)}')], s: 12, c: p.mu, lh: 1.35),
                    if (best != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final id in dealMenu.where(deal.on.contains))
                            Container(color: p.gb, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: T(dealPerk(id), s: 11, w: 600, c: p.gn)),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      T('No Hostelzy deal yet', s: 12, c: p.mu),
                    ],
                    const Spacer(),
                    const SizedBox(height: 10),
                    for (final l in lines) ...[
                      if (l != lines.first) const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [RoomTypeTag(l.ac), const SizedBox(width: 6), Flexible(child: T('${l.free} free', s: 12, c: p.mu, ell: true))],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              if (l.hz == l.from) T('from ', s: 12, c: p.mu),
                              if (l.hz < l.from) ...[
                                Text(fmt(l.from), style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12, color: p.mu, decoration: TextDecoration.lineThrough, decorationColor: p.mu)),
                                const SizedBox(width: 4),
                              ],
                              Rich([sp(context, fmt(l.hz), s: 16, w: 800), sp(context, '/mo', s: 12, c: p.mu)]),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ map

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final filt = filtered(s);
    final mh = hostelById(s.mapSel);
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          Widget road(double left, double top, double rw, double rh, double deg) => Positioned(
            left: left,
            top: top,
            width: rw,
            height: rh,
            child: Transform.rotate(
              angle: deg * 3.141592653589793 / 180,
              child: Container(color: p.bg),
            ),
          );
          Positioned at(double xPct, double yPct, Offset tr, Widget child) => Positioned(
            left: w * xPct / 100,
            top: h * yPct / 100,
            child: FractionalTranslation(translation: tr, child: child),
          );
          final pins = [for (final ho in hostels) ho]..sort((a, b) => (a.id == s.mapSel ? 1 : 0) - (b.id == s.mapSel ? 1 : 0));
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter(p.sf, p.hl))),
              road(-.2 * w, .44 * h, 1.4 * w, 14, -14),
              road(.58 * w, -.1 * h, 12, 1.2 * h, 18),
              road(-.1 * w, .76 * h, 1.2 * w, 8, 6),
              Positioned(right: 10, bottom: 206, child: T('map tiles', s: 10, mono: true, c: p.mu)),
              for (final l in landmarks)
                at(
                  landmarkXY[l]![0],
                  landmarkXY[l]![1],
                  const Offset(-.5, -.5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, color: l == s.lm ? p.ac : p.tx),
                      const SizedBox(width: 5),
                      T(l, s: 11, w: 600, c: p.mu),
                    ],
                  ),
                ),
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Tap(
                  onTap: () => s.update(() => s.sheet = 'search'),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: box(bg: p.bg, w: 2, c: p.tx),
                    child: Row(
                      children: [
                        const Ic('search', size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: T(searchSummary(s), s: 14, w: 600, ell: true)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: box(bg: p.bg, w: 2, c: p.tx),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Stripes(step: 6, width: 84, height: 84, border: Border.all(width: 1, color: p.hl)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T('${mh.gender} · ${mh.area}', s: 11, w: 600, ls: .08, upper: true, lh: 1.3, c: p.ad),
                              const SizedBox(height: 3),
                              T(mh.name, w: 800, s: 16, lh: 1.15),
                              const SizedBox(height: 3),
                              T('${s.freeOf(mh.id).f} beds free · ${mh.mins[s.lm]} min to ${s.lm}', s: 12, c: p.mu),
                              const Spacer(),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Rich([sp(context, fmt(mh.from)), sp(context, '/mo', s: 12, w: 400, c: p.mu)], s: 16, w: 800),
                                  Tap(
                                    onTap: () => s.update(() {
                                      s.hist = [...s.hist, s.screen];
                                      s.screen = 'detail';
                                      s.sheet = null;
                                      s.hid = mh.id;
                                      s.dealAc = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                                      color: p.ac,
                                      child: Css(
                                        c: p.ai,
                                        w: 800,
                                        s: 13,
                                        child: const Row(mainAxisSize: MainAxisSize.min, children: [T('View'), SizedBox(width: 8), Ic('arrow', size: 13)]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (final ho in pins)
                () {
                  final sel = ho.id == s.mapSel, vis = filt.contains(ho);
                  return at(
                    ho.x,
                    ho.y,
                    const Offset(-.5, -1),
                    Tap(
                      onTap: () => s.update(() => s.mapSel = ho.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        decoration: box(
                          bg: sel ? p.ac : p.bg,
                          w: 2,
                          c: sel
                              ? p.ac
                              : vis
                              ? p.tx
                              : p.tk,
                        ),
                        child: T(
                          '₹${(ho.from / 1000).toStringAsFixed(1)}k',
                          w: 800,
                          s: 13,
                          c: sel
                              ? p.ai
                              : vis
                              ? p.tx
                              : p.mu,
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.bg, this.line);
  final Color bg, line;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final p = Paint()..color = line;
    for (var y = 0.0; y < size.height; y += 34) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => o.bg != bg || o.line != line;
}

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
    const lab = {'waiting': 'Waiting for owner', 'confirmed': 'Confirmed', 'held': 'Held', 'booked': 'Booked · advance paid', 'released': 'Released'};
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
          // F07 board 3: asked after a hold ends.
          if (s.joinAnswer == null)
            Tap(
              onTap: () => s.update(() => s.sheet = 'joined'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const T('Anjani Residency · 102-B', w: 800, s: 15), T('Hold ended 11 Sep · Did you join? One tap', s: 12, c: p.mu)])),
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
                            T(lab[h.status]!, s: 11, w: 600, ls: .08, upper: true, lh: 1.3, c: p.ad),
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
                                ? '5 Oct'
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
    final rows = <(String, VoidCallback, Color)>[
      if (!isOwner) ('Stay Rewards · ${const {'trusted': 'Trusted tenant', 'member': 'Member'}[s.level] ?? 'not a member yet'}', () => s.go('rewards'), p.tx),
      ('Saved hostels', () => s.toastMsg('${s.saved.values.where((v) => v).length} saved'), p.tx),
      ('Notifications', () => s.toastMsg('Notifications go to WhatsApp and here.'), p.tx),
      ('Switch role', () => s.tab('role'), p.tx),
      (
        'Log out',
        () => s.update(() {
          s.screen = 'welcome';
          s.hist = [];
          s.phone = '';
          s.otp = '';
        }),
        p.ad,
      ),
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
                  child: T(isOwner ? 'SR' : 'RV', w: 800, s: 24, c: p.ai),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T(isOwner ? 'Srinivas Rao' : 'Rahul Varma', w: 800, s: 24, lh: 1.05),
                      const SizedBox(height: 3),
                      T('+91 ${s.phone.isNotEmpty ? phoneSpaced(s.phone) : '98480 12345'} · ${const {'tenant': 'Looking for a bed', 'resident': 'Resident', 'owner': 'Owner, Anjani Residency'}[s.role]}', s: 13, c: p.mu),
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
    final saved = s.saved[h.id] ?? false;
    // F03: the deal table's room type drives the bottom bar.
    final dv = dealView(s, h);
    final dq = s.quote(h.id, dv.ac, dv.share);
    final deal = s.dealsOf(h.id);
    // F16: sharing × room type grid; one column per type the hostel has.
    final kinds = [if (h.hasNon) false, if (h.ac) true];
    ({int price, int free})? cell(int n, bool ac) {
      final rr = rs.where((r) => r.share == n && r.ac == ac).toList();
      if (rr.isEmpty) return null;
      return (price: rr.first.rent, free: rr.fold<int>(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length));
    }
    final rules = [
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
            child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), child: T(h.tags[i + 1], s: 14, w: 600)),
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
                              s.toastMsg(saved ? 'Removed from saved' : "Saved. We'll tell you if a bed frees up.");
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
                        Positioned(left: 14, bottom: 10, child: T('hostel photos · 1 / 12', s: 11, mono: true, c: p.mu)),
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
                              T('${h.mins[s.lm]} min to ${s.lm}'),
                              T(h.instant ? 'Instant booking' : 'Owner confirms holds'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // F14: Visited by Hostelzy + whether the owner confirmed the free beds.
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: VisitedBlock(h)),
                DealBlock(h),
                Container(
                  decoration: BoxDecoration(
                    color: p.hl,
                    border: Border(top: bs(2, p.dv), bottom: bs(2, p.dv)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tagRow(0), const SizedBox(height: 1), tagRow(2)]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [const Kicker('Rent by room type'), T('per month', s: 12, c: p.mu)],
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
                                    child: T(ac ? 'AC' : 'Non-AC', s: 11, w: 800, ls: .06, upper: true),
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
                                          // F03: rooms the deal covers show the Hostelzy price, walk-in struck through.
                                          final hz = c != null ? s.quote(h.id, ac, n) : null;
                                          final off = hz != null && hz.hzFee < hz.fee;
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              T(c != null ? fmt(off ? hz.hzFee : c.price) : '—', w: 800, s: 17, c: c == null ? p.mu : (off ? p.gn : p.tx)),
                                              if (off) Text(fmt(c!.price), style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12, color: p.mu, decoration: TextDecoration.lineThrough, decorationColor: p.mu)),
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
                          child: T('Hostelzy deal: ${deal.summary} · ${deal.targetText}', s: 13, w: 800, c: p.gn),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: VGap(
                    gap: 4,
                    children: [
                      T('Every bed in a room type costs the same. Window or door, upper or lower.', s: 12, c: p.mu, lh: 1.4),
                      T('${h.food ? 'Food included. ' : ''}Electricity ${h.terms.electricityExtra ? "extra, by the room's meter" : 'included'}.', s: 12, c: p.mu, lh: 1.4),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
                  child: const Kicker('House rules'),
                ),
                for (final r in rules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                    child: Css(
                      s: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 130, child: T(r[0], c: p.mu)),
                          const SizedBox(width: 12),
                          Expanded(child: T(r[1], w: 600)),
                        ],
                      ),
                    ),
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
                    if (dq.any) ...[
                      Text('${fmt(dq.move)} walk in', style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12, color: p.mu, decoration: TextDecoration.lineThrough, decorationColor: p.mu)),
                      T('${fmt(dq.hzMove)} to move in', w: 800, s: 18),
                    ] else ...[
                      Rich([sp(context, 'From ${fmt(h.from)}'), sp(context, '/mo', s: 12, w: 400, c: p.mu)], w: 800, s: 18),
                      T('$free beds free right now', s: 12, c: p.mu),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Cta(
                dq.any ? 'Book with deal' : 'Pick a bed',
                onTap: () {
                  s.openPicker();
                  if (dq.any && h.ac && h.hasNon) s.pickRoomType(dv.ac ? 'AC' : 'Non-AC');
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
    // F12: Room sits beside Plan; Plan stays the default.
    const modes = [('plan', 'Plan'), ('room', 'Room'), ('list', 'List'), ('building', 'Building')];
    final locked = s.floorLocked(h.id) && (s.mode == 'plan' || s.mode == 'building');

    Widget body;
    if (locked) {
      body = const FloorLocked();
    } else if (s.mode == 'room') {
      body = RoomMode(rooms: rs, room: room);
    } else if (s.mode == 'plan') {
      body = _PlanMode(rooms: rs, room: room);
    } else if (s.mode == 'list') {
      body = _ListMode(rooms: rs);
    } else {
      body = _BuildingMode(rooms: rs, room: room);
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

class _BuildingMode extends StatelessWidget {
  const _BuildingMode({required this.rooms, required this.room});
  final List<Room> rooms;
  final Room room;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Widget floorRow(int f) {
      final rs = rooms.where((r) => r.floor == f).toList();
      return Container(
        decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border(right: bs(2, p.tx))),
                child: T('F$f', w: 800, s: 14),
              ),
              for (var i = 0; i < rs.length; i++)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: rs[i].n == room.n && s.bed != null ? p.sf : transparent,
                      border: i > 0 ? Border(left: bs(1, p.hl)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T('${rs[i].n}', s: 11, w: 600, c: p.mu),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          children: [
                            for (final b in rs[i].beds)
                              () {
                                final l = lookOf(p, b, s.bed);
                                return Tap(
                                  enabled: l.can,
                                  onTap: () => s.pickBed(b),
                                  child: BedBox(look: l.look, width: 16, height: 26),
                                );
                              }(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Kicker('Cross-section · tap any free bed'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => Container(
              height: 14,
              margin: EdgeInsets.symmetric(horizontal: c.maxWidth * .1),
              decoration: BoxDecoration(
                color: p.sf,
                border: Border(top: bs(2, p.tx), left: bs(2, p.tx), right: bs(2, p.tx)),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: bs(2, p.tx), left: bs(2, p.tx), right: bs(2, p.tx)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in floorsOf(rooms).reversed) floorRow(f),
                Container(
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(border: Border(right: bs(2, p.tx))),
                          child: const T('G', w: 800, s: 14),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: T('Reception · dining hall · bike parking', s: 12, c: p.mu),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // `height:8px;margin-inline:-6px`: base slab wider than the building.
          SizedBox(
            height: 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [Positioned(left: -6, right: -6, top: 0, bottom: 0, child: Container(color: p.tx))],
            ),
          ),
          const SizedBox(height: 14),
          const Legend(items: pickerLegend),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ hold status

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
    var canSim = false, canCancel = false, canMoveIn = false;
    VoidCallback wa = () {};
    if (hold != null) {
      final i = holdInfo(s, hold);
      final st = hold.status;
      final m = switch (st) {
        'waiting' => ['Waiting for ${i.hh.owner}', cd(i.left), 'left for ${i.hh.owner} to confirm. Usually replies in ~${i.hh.reply} min.', 'sf', 'tx'],
        'confirmed' => ['Confirmed by ${i.hh.owner}', cd(i.left), 'Go and see it before the timer ends to keep the bed.', 'gn', 'ai'],
        'held' => ['Held for you', cd(i.left), 'Go and see it before the timer ends to keep the bed.', 'gn', 'ai'],
        'booked' => ['Booked', 'Yours.', 'Advance paid to ${i.hh.owner}. Show ${hold.ref ?? 'your HZ code'} when you move in; your deal is locked.', 'gn', 'ai'],
        _ => ['Released', '—', 'The hold ended. You paid nothing.', 'sf', 'tx'],
      };
      final done = st != 'waiting' && st != 'released';
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
        if (hold.opt == 'book') ...[('Paid to ${i.hh.owner}', fmt(hold.paid)), ('HZ code', hold.ref ?? '—'), if (hold.perks.isNotEmpty) ('Deal locked', hold.perks.join(' · '))] else ('Paid now', '₹0'),
      ];
      steps = [
        TimelineStep(t: 'Hold placed', d: 'Bed taken off the market for everyone else', bg: p.tx, bd: p.tx),
        TimelineStep(t: hold.opt == 'free' ? 'Owner confirms' : 'Advance paid', d: hold.opt == 'free' ? (done ? 'Confirmed on WhatsApp' : 'Usually within ${i.hh.reply} minutes') : 'Done', bg: done ? p.tx : p.ac, bd: done ? p.tx : p.ac),
        TimelineStep(t: 'Visit and move in', d: hold.opt == 'book' ? 'Pay the first month (${fmt(q.hzFirst)}) at move-in. Show ${hold.ref}.' : 'Pay ${fmt(q.hzAdv)} advance + first month at move-in.', bg: done ? p.ac : transparent, bd: done ? p.ac : p.tk),
      ];
      canSim = st == 'waiting';
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
                      Cta('WhatsApp $owner', parts: ['WhatsApp', owner], icon: 'msg', height: 52, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: wa),
                      OutlineCta('Directions', icon: 'pin', onTap: () => s.toastMsg('Opening Maps…')),
                      if (canCancel)
                        Tap(
                          onTap: () {
                            final b = s.findBed(hold!.hid, hold.bed).b;
                            if (b != null) {
                              b.state = 'free';
                              b.mine = false;
                            }
                            s.setHold(hold.id, 'released');
                            s.toastMsg('Hold released.');
                          },
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
