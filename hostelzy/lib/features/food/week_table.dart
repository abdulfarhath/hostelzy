import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'save_food_screens.dart';

// F26 #4 (#13): the food menu is always the whole week, one table, today's
// row highlighted. No "today" card and no Today / Full week toggle anywhere.
// Shared by the hostel page (tenant) and resident Home.
//
// Public API:
// - [FoodWeekTable]: just the table for one hostel (Mon–Sun × breakfast,
//   lunch, dinner; headers carry the meal start times). Says "Menu not added
//   yet" when the hostel has no menu.
// - [FoodWeekSection]: the table with its kicker ("Food menu · this week" ·
//   "From <owner>’s menu"); loads the menu from the server when it shows, and
//   shows nothing for a hostel that serves no food and has no menu.

/// "7:30": the start of a meal at [hid] (the owner's time, else the usual one).
String mealStart(AppState s, String hid, String k) => mealSpan(s.mealTimeOf(hid, k) ?? usualMealTimes[k]!).split(' – ').first;

/// Mon–Sun × breakfast / lunch / dinner for [hid], today's row highlighted.
/// [menu] overrides the hostel's saved week (e.g. a draft); by default it is
/// `s.menuOf(hid)`.
class FoodWeekTable extends StatelessWidget {
  const FoodWeekTable({super.key, required this.hid, this.menu});
  final String hid;
  final List<DayMenu>? menu;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final m = menu ?? s.menuOf(hid);
    if (m == null || weekEmpty(m)) {
      return Container(
        key: const ValueKey('weekTableEmpty'),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(border: Border(top: bs(2, p.tx), bottom: bs(1, p.hl))),
        child: T('Menu not added yet', s: 14, c: p.mu),
      );
    }
    Widget head(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6), child: T(t, s: 10, w: 800, ls: .06, upper: true, c: p.mu, lh: 1.25));
    Widget cell(String t, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: T(t.trim().isEmpty ? '—' : t, s: 12, lh: 1.3, w: bold ? 800 : null),
    );
    final today = todayIdx;
    return Table(
      key: const ValueKey('weekTable'),
      columnWidths: const {0: FixedColumnWidth(52)},
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          children: [head(''), for (final ml in meals) head('${ml[1]} · ${mealStart(s, hid, ml[0])}')],
        ),
        for (var i = 0; i < 7; i++)
          TableRow(
            decoration: BoxDecoration(color: i == today ? p.ab : null, border: Border(bottom: bs(1, p.hl))),
            children: [
              Padding(
                key: ValueKey('weekRow-$i'),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(weekDays[i][0], s: 12, w: 800, lh: 1.3),
                    if (i == today) T('today', key: const ValueKey('weekToday'), s: 11, w: 800, c: p.ad, lh: 1.2),
                  ],
                ),
              ),
              for (final ml in meals) cell(i < m.length ? m[i].of(ml[0]) : ''),
            ],
          ),
      ],
    );
  }
}

/// The hostel page's food block: kicker, then [FoodWeekTable]. Fetches the
/// menu when it shows. Nothing for a hostel without food and without a menu.
class FoodWeekSection extends StatelessWidget {
  const FoodWeekSection({super.key, required this.hid, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0)});
  final String hid;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final m = s.menuOf(hid);
    final h = hostelById(hid);
    return OnShow(
      () => s.loadMenu(hid),
      child: m == null && !h.food
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('foodWeekSection'),
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 12,
                      children: [const Kicker('Food menu · this week'), if (m != null) T('From ${h.owner}’s menu', s: 12, c: p.mu)],
                    ),
                  ),
                  // F27-7: only once the hostel really saved plates.
                  CooksToCountChip(hid: hid),
                  FoodWeekTable(hid: hid, menu: m),
                ],
              ),
            ),
    );
  }
}
