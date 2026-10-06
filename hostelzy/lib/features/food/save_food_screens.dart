import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F27 Save food (proposal canvas v11, boards F27-1 … F27-7):
// - [NextMealCard]      F27-1, resident Home above the week table (S23).
// - [WeekPlanScreen]    F27-2, Plan your meals (S90 `rMeals`).
// - [HeadcountCard]     F27-3, owner Today under the Fair Play pin (S36).
// - [OwnerMealsScreen]  F27-4, Manage › Meals (S91 `oMeals`).
// - F27-5 is the push (lib/reminders.dart `showFoodAsk`).
// - [PlatesSavedCard]   F27-6, Me › Stay Rewards (S22).
// - [CooksToCountChip]  F27-7, hostel page food block (S13).
// Green only on plates-saved numbers.

/// "9,870" (Indian grouping, like ₹ amounts).
String plates(int n) => fmt(n).replaceFirst('₹', '');

/// The green plates-saved chip (F27-1, F27-2, F27-7).
class SavedChip extends StatelessWidget {
  const SavedChip(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: p.gb,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic('plate', size: 14, color: p.gn),
            const SizedBox(width: 6),
            Flexible(child: T(text, s: 12, w: 800, c: p.gn, lh: 1.3)),
          ],
        ),
      ),
    );
  }
}

/// A big Eating / Skip button; the picked one is filled.
class _Choice extends StatelessWidget {
  const _Choice(this.label, {super.key, required this.on, required this.onTap, this.icon});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final fg = on ? p.bg : p.tx;
    return Tap(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: box(bg: on ? p.tx : transparent, w: 2, c: p.tx),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: T(label, s: 17, w: 800, c: fg, align: TextAlign.center)),
            if (icon != null) ...[const SizedBox(width: 8), Ic(icon!, size: 18, color: fg)],
          ],
        ),
      ),
    );
  }
}

/// F27-1: the next meal a resident can still answer for, on Home.
class NextMealCard extends StatelessWidget {
  const NextMealCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = s.stayHostel;
    final b = s.foodOf(h.id);
    final next = s.nextOpenMeal(h.id);
    if (b == null || next == null || s.myStay == null || !s.servesFood(h.id)) return const SizedBox.shrink();
    final (d, k) = next;
    final dish = (s.menuOf(h.id)?[d.weekday - 1].of(k) ?? '').trim();
    final eating = s.eatingAt(h.id, d, k);
    final (res, skip) = s.countAt(h.id, d, k);
    final when = d == s.foodToday ? '' : ' · ${d.difference(s.foodToday).inDays == 1 ? 'tomorrow' : dayName(d).split(' ').first}';
    return Container(
      key: const ValueKey('nextMeal'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: Kicker('Next meal')),
              Tap(key: const ValueKey('planWeek'), onTap: s.openWeekPlan, child: T('Plan the week ›', s: 13, w: 800, c: p.ad)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T('${mealWord(k)}$when · ${s.foodClockText(s.mealAt(h.id, d, k))}', key: const ValueKey('nextMealTitle'), s: 22, w: 800, lh: 1.15),
              if (dish.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: T(dish, s: 14, c: p.mu)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _Choice('Eating', key: const ValueKey('eatBtn'), icon: 'check', on: eating, onTap: () => s.setEating(h.id, d, k, true))),
              const SizedBox(width: 8),
              Expanded(child: _Choice('Skip', key: const ValueKey('skipBtn'), on: !eating, onTap: () => s.setEating(h.id, d, k, false))),
            ],
          ),
          T('Closes at ${s.foodClockText(s.cutoffAt(h.id, d, k))}${res > 0 ? ' · ${res - skip} eating so far' : ''}', key: const ValueKey('nextMealCloses'), s: 13, c: p.mu),
          if (b.saved.youWeek > 0) SavedChip('You saved ${b.saved.youWeek} plate${b.saved.youWeek == 1 ? '' : 's'} this week', key: const ValueKey('savedWeek')),
        ],
      ),
    );
  }
}

/// F27-2 (S90 `rMeals`): today and the next 6 days × breakfast, lunch,
/// dinner. Tap a meal to switch; closed meals are locked.
class WeekPlanScreen extends StatelessWidget {
  const WeekPlanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = s.stayHostel;
    final b = s.foodOf(h.id);
    final planned = s.plannedSkips;
    Widget head(String t) => T(t, s: 11, w: 800, ls: .08, upper: true, c: p.mu);
    Widget cell(int i, DateTime d, String k) {
      final eat = s.eatingAt(h.id, d, k), open = s.mealOpen(h.id, d, k);
      final label = '${mealWord(k)} ${dayName(d)}: ${eat ? 'eating' : 'skip'}${open ? '' : ', closed'}';
      final Widget look = eat
          ? Container(
              constraints: const BoxConstraints(minHeight: 40),
              color: p.tx,
              alignment: Alignment.center,
              child: Ic(open ? 'check' : 'lock', size: 16, color: p.bg),
            )
          : Dashed(
              color: p.dv,
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!open) ...[Ic('lock', size: 12, color: p.mu), const SizedBox(width: 4)],
                    Flexible(child: T('Skip', s: 12, w: 800, c: p.mu)),
                  ],
                ),
              ),
            );
      return Semantics(
        label: label,
        button: open,
        child: Tap(key: ValueKey('plan-$i-$k'), onTap: () => s.toggleMeal(h.id, d, k), child: Opacity(opacity: open ? 1 : .45, child: look)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnShow(() => s.loadFood(h.id), child: const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Food', title: 'Plan your meals'))],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: b == null
                ? const SizedBox.shrink()
                : Scroll(
                    key: ValueKey('rMeals${s.scrollEpoch}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: VGap(
                        gap: 12,
                        children: [
                          T('Tap a meal to switch between eating and skip. Everything is “eating” unless you skip.', s: 13, c: p.mu, lh: 1.45),
                          Column(
                            key: const ValueKey('planGrid'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(width: 82),
                                  for (final m in meals) ...[Expanded(child: head(m[1])), if (m[0] != 'n') const SizedBox(width: 6)],
                                ],
                              ),
                              for (final (i, d) in s.foodWeek.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          width: 76,
                                          child: Align(alignment: Alignment.centerLeft, child: T(i == 0 ? '${dayName(d).split(' ').first} · today' : dayName(d).split(' ').first, s: 14, w: 800, lh: 1.2)),
                                        ),
                                        const SizedBox(width: 6),
                                        for (final k in const ['b', 'l', 'n']) ...[Expanded(child: cell(i, d, k)), if (k != 'n') const SizedBox(width: 6)],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Tap(
                            key: const ValueKey('skipWeekend'),
                            onTap: () => s.skipWeekend(h.id),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: box(w: 2, c: p.tx),
                              alignment: Alignment.centerLeft,
                              child: T(s.weekendSkipped(h.id) ? 'Eat all weekend' : 'Skip all weekend', s: 15, w: 800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            color: p.sf,
                            child: T('Each meal closes ${b.cutoff} h before it is served. A skip after that counts from the next meal.', key: const ValueKey('cutoffNote'), s: 13, lh: 1.45),
                          ),
                          if (planned > 0) SavedChip('This week you’re saving $planned plate${planned == 1 ? '' : 's'}', key: const ValueKey('planned')),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// F27-3: "Dinner tonight · 34 of 40 eating" on owner Today. Tap → Meals.
class HeadcountCard extends StatelessWidget {
  const HeadcountCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    final b = s.foodOf(hid);
    if (b == null || !s.servesFood(hid)) return const SizedBox.shrink();
    final (d, k) = s.headcountMeal(hid);
    final (res, skip) = s.countAt(hid, d, k);
    if (res == 0) return const SizedBox.shrink();
    final eat = res - skip;
    final open = s.mealOpen(hid, d, k);
    return Tap(
      key: const ValueKey('headcountCard'),
      onTap: s.openMeals,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: box(w: 2, c: p.tx),
        child: VGap(
          gap: 8,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [Kicker(s.mealWhen(d, k)), T(open ? 'Closes ${s.foodClockText(s.cutoffAt(hid, d, k))}' : 'Count closed', s: 12, c: p.mu)],
            ),
            Row(
              children: [
                Expanded(child: T('$eat of $res eating', key: const ValueKey('headcount'), s: 26, w: 800, lh: 1.1)),
                const Ic('chev', size: 18),
              ],
            ),
            Semantics(
              label: '$eat of $res eating',
              child: Container(
                height: 10,
                decoration: box(bg: p.sf, w: 1, c: p.tx),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (eat > 0) Expanded(flex: eat, child: Container(color: p.tx)),
                    if (skip > 0) Expanded(flex: skip, child: const SizedBox()),
                  ],
                ),
              ),
            ),
            T('$skip skipping · cook for $eat', s: 13, c: p.mu),
          ],
        ),
      ),
    );
  }
}

/// F27-4 (S91 `oMeals`): plates saved this month, today's three meals, who
/// is skipping (this hostel's residents only), the next 7 days and the cut-off.
class OwnerMealsScreen extends StatelessWidget {
  const OwnerMealsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hid = s.ownHid;
    final h = hostelById(hid);
    final b = s.foodOf(hid);
    final today = s.foodToday;
    final (hd, hk) = s.headcountMeal(hid);
    final listMeal = hd == today ? hk : 'n';
    final skippers = [for (final x in b?.skippers ?? const <({String key, String name, String bed})>[]) if (x.key == mealKey(today, listMeal)) x];
    Widget kicker(String t, {Key? key}) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker(t, key: key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnShow(() => s.loadFood(hid), child: const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Manage', title: 'Meals'))],
          ),
        ),
        Expanded(
          child: b == null
              ? const SizedBox.shrink()
              : Scroll(
                  key: ValueKey('oMeals${s.scrollEpoch}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: const ValueKey('platesMonth'),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(14),
                        color: p.gb,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Kicker('Plates saved this month', c: p.gn),
                            T(plates(b.saved.hostelMonth), s: 40, w: 800, lh: 1.1, c: p.gn),
                          ],
                        ),
                      ),
                      kicker('Today · of ${s.countAt(hid, today, 'n').$1} residents'),
                      Container(
                        decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final m in meals)
                              Container(
                                key: ValueKey('mealRow-${m[0]}'),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          T(m[1], s: 16, w: 800),
                                          T(
                                            s.mealOpen(hid, today, m[0]) ? 'Open · closes ${s.foodClockText(s.cutoffAt(hid, today, m[0]))}' : 'Closed ${s.foodClockText(s.cutoffAt(hid, today, m[0]))}',
                                            s: 13,
                                            c: p.mu,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    T('${s.countAt(hid, today, m[0]).$1 - s.countAt(hid, today, m[0]).$2}', s: 24, w: 800),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      kicker('Who’s skipping ${mealWord(listMeal).toLowerCase()} · ${skippers.length}', key: const ValueKey('skippersHead')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: T(
                          skippers.isEmpty ? 'Nobody is skipping ${mealWord(listMeal).toLowerCase()} so far.' : skippers.map((x) => x.bed.isEmpty ? x.name : '${x.name} ${x.bed}').join(' · '),
                          key: const ValueKey('skippers'),
                          s: 14,
                          lh: 1.5,
                          c: skippers.isEmpty ? p.mu : null,
                        ),
                      ),
                      kicker('Next 7 days · eating'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Table(
                          key: const ValueKey('mealWeek'),
                          columnWidths: const {0: FixedColumnWidth(76)},
                          children: [
                            TableRow(
                              decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                              children: [
                                const SizedBox(),
                                for (final m in meals) Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6), child: T(m[1], s: 11, w: 800, ls: .06, upper: true, c: p.mu)),
                              ],
                            ),
                            for (final (i, d) in s.foodWeek.indexed)
                              TableRow(
                                decoration: BoxDecoration(color: i == 0 ? p.ab : null, border: Border(bottom: bs(1, p.hl))),
                                children: [
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: T(dayName(d).split(' ').first, s: 13, w: 800)),
                                  for (final m in meals)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      child: T('${s.countAt(hid, d, m[0]).$1 - s.countAt(hid, d, m[0]).$2}', s: 13),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      kicker('Count closes before each meal'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Seg(
                          key: const ValueKey('cutoffSeg'),
                          opts: const [('2', '2 h'), ('3', '3 h'), ('4', '4 h')],
                          cur: '${b.cutoff}',
                          onPick: (v) => s.setMealCutoff(int.parse(v)),
                          center: true,
                          dividers: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: T('Residents can change their answer until then. After it, the answer is locked and the count is final.', s: 13, c: p.mu, lh: 1.4),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// F27-6: plates saved by you, your hostel and Hostelzy (Stay Rewards).
class PlatesSavedCard extends StatelessWidget {
  const PlatesSavedCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    if (s.role != 'resident' || s.myStay == null) return const SizedBox.shrink();
    final h = s.stayHostel;
    final b = s.foodOf(h.id);
    if (b == null) return const SizedBox.shrink();
    Widget line(String k, int n) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
      child: Row(children: [Expanded(child: T(k, s: 14)), const SizedBox(width: 12), T(plates(n), s: 18, w: 800, c: p.gn)]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnShow(() => s.loadFood(h.id), child: const SizedBox.shrink()),
        const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Plates saved')),
        Container(
          key: const ValueKey('platesSaved'),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          color: p.gb,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Kicker('You saved', c: p.gn),
              T('${plates(b.saved.you)} plate${b.saved.you == 1 ? '' : 's'}', s: 34, w: 800, lh: 1.1, c: p.gn),
              const SizedBox(height: 8),
              line('${h.name} saved', b.saved.hostel),
              line('Hostelzy saved', b.saved.hostelzy),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: T('1 skip = 1 plate the kitchen didn’t cook. No ranking of people: nobody is judged for eating.', s: 12, c: p.mu, lh: 1.4),
        ),
      ],
    );
  }
}

/// F27-7: "Cooks to count · N plates saved" under the hostel page's food
/// kicker, only once the hostel really saved plates.
class CooksToCountChip extends StatelessWidget {
  const CooksToCountChip({super.key, required this.hid});
  final String hid;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = s.hostelPlates[hid] ?? 0;
    return OnShow(
      () => s.loadPlates(hid),
      child: n <= 0
          ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.only(bottom: 8), child: SavedChip('Cooks to count · ${plates(n)} plates saved', key: const ValueKey('cooksToCount'))),
    );
  }
}
