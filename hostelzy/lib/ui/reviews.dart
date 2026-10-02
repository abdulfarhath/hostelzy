import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F08 verified reviews and the Hostelzy rank: resident review forms (boards 1–2),
// the tenant's Reviews screen (3), the owner's ranking (5) and replies (6).

/// A row of [n] small stars, filled up to [filled].
class Stars extends StatelessWidget {
  const Stars(this.filled, {super.key, this.size = 12, this.n = 5});
  final int filled, n;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < n; i++) Padding(padding: const EdgeInsets.only(right: 1), child: Ic('star', size: size, color: i < filled ? p.tx : p.tk))]);
  }
}

/// Big tappable stars for the review forms.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onPick});
  final int value;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Row(
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Semantics(
            label: '$i stars',
            button: true,
            child: Tap(
              onTap: () => onPick(i),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: box(bg: i <= value ? p.tx : transparent, w: 2, c: i <= value ? p.tx : p.dv),
                child: Ic('star', size: 24, color: i <= value ? p.bg : p.tk),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// F22 Area 2: a label and five 40px stars on one row.
class StarRow extends StatelessWidget {
  const StarRow(this.label, {super.key, required this.value, required this.onPick});
  final String label;
  final int value;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        children: [
          Expanded(child: T(label, w: 800, s: 15)),
          for (var i = 1; i <= 5; i++)
            Semantics(
              label: '$label $i stars',
              button: true,
              child: Tap(
                onTap: () => onPick(i),
                child: SizedBox(width: 40, height: 40, child: Center(child: Ic('star', size: 24, color: i <= value ? p.tx : p.tk))),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _head(BuildContext context, String kicker, String title, {double size = 26}) {
  final s = AppScope.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title, size: size))],
    ),
  );
}

/// One review as tenants and owners see it.
class ReviewCard extends StatelessWidget {
  const ReviewCard(this.r, {super.key, this.ownerView = false});
  final Review r;
  final bool ownerView;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(r.hid);
    final open = ownerView && s.replyFor == r.id;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: VGap(
        gap: 4,
        children: [
          // F22 Area 1: who and how long, stars on the right; the kind and when below.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: T(r.name, w: 800, s: 15)), const SizedBox(width: 8), Stars(r.stars)],
          ),
          T('${r.kind == 'exit' ? 'Exit review' : '30-day review'} · ${r.stay}', s: 12, c: p.mu),
          if (r.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: T(r.text, s: 15, lh: 1.45)),
          if (r.advance != null) T(r.advance == 'all' ? 'Got the advance back in full.' : r.advance == 'part' ? 'Got only part of the advance back.' : 'Advance not back yet.', s: 13, c: p.mu),
          if (r.reply != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              color: p.sf,
              child: Rich([sp(context, '${h.owner} replied: ', w: 800), sp(context, r.reply!), if (r.replyWhen != null) sp(context, ' · ${r.replyWhen}', c: p.mu)], s: 13, lh: 1.45),
            )
          else if (ownerView && !open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tap(
                  onTap: () => s.update(() {
                    s.replyFor = r.id;
                    s.replyText = '';
                  }),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: box(w: 2, c: p.tx), child: const T('Reply', w: 800, s: 13)),
                ),
              ),
            ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: VGap(
                gap: 8,
                children: [
                  const T('Your reply', w: 800, s: 13),
                  Field(value: s.replyText, onChanged: (v) => s.update(() => s.replyText = v), placeholder: 'Thank them, or say what you are fixing', maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
                  Cta('Post reply', icon: 'check', height: 48, px: 14, fs: 14, onTap: () => s.postReply(r)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// F08 board 3: verified reviews on a hostel.
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final st = s.stats[h.id]!;
    final list = s.reviews.where((r) => r.hid == h.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, h.name, 'Reviews', size: 22),
        Expanded(
          child: Scroll(
            key: ValueKey('reviews${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // F22 Area 1: the score and the category bars side by side.
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [T(jsNum(h.rating), w: 800, s: 52, lh: 1, ls: -.04), T('${h.reviews} verified stays', s: 13, c: p.mu)],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            for (var i = 0; i < reviewCats.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(flex: 5, child: T(reviewCats[i], s: 12, c: p.mu, ell: true)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        height: 10,
                                        decoration: box(w: 2, c: p.tx),
                                        child: LayoutBuilder(builder: (context, c) => Row(children: [Container(width: c.maxWidth * st.cats[i] / 5, color: p.tx)])),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    T(st.cats[i].toStringAsFixed(1), s: 12, w: 800),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: T('Advance back in full: ${st.advFull} of ${st.advLeft} who left · Layout accurate: ${st.layoutPct}%', s: 12, c: p.mu, lh: 1.4),
                ),
                for (final r in list) ReviewCard(r),
                if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Reviews from residents with a confirmed stay show up here.', s: 14, c: p.mu)),
                Padding(padding: const EdgeInsets.all(16), child: T('Only people who stayed here can review. Owners can reply, not delete.', s: 12, c: p.mu, lh: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// F08 board 1, F22 Area 2 (`rReview`): a row of stars per category, an
/// optional line, Post review. Overall is the average of the rows.
class ResidentReviewScreen extends StatelessWidget {
  const ResidentReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '30 days at ${s.stayHostel.name}', 'How is your stay?'),
        Expanded(
          child: Scroll(
            key: ValueKey('rReview${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in reviewCats)
                        StarRow(
                          c,
                          value: s.rvCats[c] ?? 0,
                          onPick: (v) => s.update(() {
                            s.rvCats[c] = v;
                            final all = s.rvCats.values;
                            s.rvStars = (all.reduce((a, b) => a + b) / all.length).round();
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: VGap(gap: 6, children: [const T('Is the room layout right?', w: 800, s: 13), Seg(opts: same(['Yes', 'Mostly', 'No']), cur: s.rvLayout, onPick: (v) => s.update(() => s.rvLayout = v), pad: const EdgeInsets.all(10))]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: VGap(
                    gap: 8,
                    children: [
                      const T('Anything others should know? (optional)', w: 800, s: 13),
                      Field(value: s.rvText, onChanged: (v) => s.update(() => s.rvText = v), placeholder: 'Food, water, the owner…', maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
                      T('Shown as ${s.meShort} · verified resident. ${s.stayOwner} can reply, not delete.', s: 13, c: p.mu, lh: 1.4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta('Post review', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.postReview),
        ),
      ],
    );
  }
}

/// F08 board 2, F22 Area 2 (`rExit`): did the advance come back, overall
/// stars, an optional line.
class ExitReviewScreen extends StatelessWidget {
  const ExitReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final t = s.stayHostel.terms;
    final back = t.advance - t.maintenance;
    Widget option(String v, String label) {
      final on = s.exAdv == v;
      return Tap(
        key: ValueKey('exAdv-$v'),
        onTap: () => s.update(() => s.exAdv = v),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: box(bg: on ? p.ab : transparent, w: 2, c: on ? p.ac : p.tx),
          child: T(label, w: 800, s: 15),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${s.stayHostel.name} · ${s.vDate}', 'Exit review'),
        Expanded(
          child: Scroll(
            key: ValueKey('rExit${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: VGap(
                    gap: 8,
                    children: [
                      T('Did you get your ${fmt(back)} back?', w: 800, s: 20, lh: 1.2),
                      T('Advance ${fmt(t.advance)} minus ${fmt(t.maintenance)} maintenance.', s: 13, c: p.mu),
                      option('all', 'Yes, ${fmt(back)}'),
                      option('part', 'Only part of it'),
                      option('not', 'Not yet'),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: StarRow('Overall', value: s.exStars, onPick: (v) => s.update(() => s.exStars = v)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: VGap(
                    gap: 8,
                    children: [
                      const T('Anything others should know? (optional)', w: 800, s: 13),
                      Field(value: s.exText, onChanged: (v) => s.update(() => s.exText = v), placeholder: 'The room, the owner, getting the advance back…', maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
                      T('Shown as ${s.meShort} · verified stay. Your answer counts toward the hostel’s “advance returned” record.', s: 13, c: p.mu, lh: 1.4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta('Post review', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.postExitReview),
        ),
      ],
    );
  }
}

/// F08 board 6: the owner reads and replies to reviews.
class OwnerReviewsScreen extends StatelessWidget {
  const OwnerReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final all = s.reviews.where((r) => r.hid == h.id).toList();
    final fresh = all.where((r) => r.fresh && r.reply == null).toList();
    final low = all.where((r) => r.stars <= 3).toList();
    final list = switch (s.revF) {
      'new' => fresh,
      'low' => low,
      _ => all,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${h.name} · ${jsNum(h.rating)} · ${h.reviews} verified', 'Reviews', size: 28),
        Seg(opts: [('new', 'New ${fresh.length}'), ('all', 'All ${all.length}'), ('low', 'Low rating ${low.length}')], cur: s.revF, onPick: (v) => s.update(() => s.revF = v), pad: const EdgeInsets.all(10), margin: const EdgeInsets.fromLTRB(16, 0, 16, 12)),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(
              key: ValueKey('oReviews${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in list) ReviewCard(r, ownerView: true),
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing here right now.', s: 14, c: p.mu)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: T('You can reply once to each review. Reviews can’t be removed; report one only if it breaks the rules (abuse, personal details).', s: 12, c: p.mu, lh: 1.4),
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

/// F08 board 5: the owner's ranking and what moves it. No number shown.
class OwnerRankScreen extends StatelessWidget {
  const OwnerRankScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final f = s.factors(h.id);
    final strikes = s.strikes[h.id] ?? 0;
    String tip(String k) => switch (k) {
      'reviews' => 'Rated ${jsNum(h.rating)} by ${h.reviews} verified residents',
      'reply' => 'Usually replies in ${h.reply} min',
      _ => f[k]! >= .85 ? '' : rankTips[k]!,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${h.name} · Manage', 'Your ranking', size: 28),
        // F21 W3: one Manage row for reviews and ranking; reviews open from here.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(alignment: Alignment.centerLeft, child: Tap(key: const ValueKey('readReviews'), onTap: () => s.go('oReviews'), child: T('Read and reply to reviews ›', s: 14, w: 800, c: p.ad))),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oRank${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      T('#${s.rankOf(h.id)}', w: 800, s: 64, lh: .9, ls: -.04),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [T('of ${browsable.length} near ${s.lm}', w: 800, s: 16), const SizedBox(height: 2), T('Tenants see: ${s.rankReasons(h.id).toLowerCase()}', s: 12, c: p.mu)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final k in rankWeights.keys)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: VGap(
                      gap: 6,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Flexible(child: T('${rankLabel[k]} · ${(rankWeights[k]! * 100).round()}%', w: 800, s: 14)), const SizedBox(width: 8), Flexible(child: T(rankWord(f[k]!), w: 800, s: 13, c: f[k]! >= .7 ? p.tx : p.ad, align: TextAlign.right))],
                        ),
                        Container(
                          height: 8,
                          decoration: box(w: 2, c: p.tx),
                          child: LayoutBuilder(builder: (context, c) => Row(children: [Container(width: c.maxWidth * f[k]!, color: p.tx)])),
                        ),
                        if (tip(k).isNotEmpty) T(tip(k), s: 12, c: p.mu),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Flexible(child: T('Fair Play strikes', w: 800, s: 14)), const SizedBox(width: 8), Flexible(child: T(strikes == 0 ? '0 · rank not lowered' : '$strikes · rank lowered', w: 800, s: 13, c: strikes == 0 ? p.tx : p.ad, align: TextAlign.right))]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "How it works" sheet behind the Recommended sort.
class RankSheet extends StatelessWidget {
  const RankSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 10,
        children: [
          T('Hostels are ranked by what residents and Hostelzy can check, never by who pays.', s: 14, lh: 1.45),
          for (final k in rankWeights.keys) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T(rankLabel[k]!, s: 14), T('${(rankWeights[k]! * 100).round()}%', w: 800, s: 14)]),
          T('Reviews count only from residents with a confirmed stay. Fair Play strikes lower the rank.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}
