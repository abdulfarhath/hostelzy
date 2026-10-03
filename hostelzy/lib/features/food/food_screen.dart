import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// Monday–Sunday × breakfast/lunch/dinner table with a sticky day column.
class WeekTable extends StatefulWidget {
  const WeekTable({super.key, required this.onPick});
  final ValueChanged<int> onPick;
  @override
  State<WeekTable> createState() => _WeekTableState();
}

class _WeekTableState extends State<WeekTable> {
  final ctl = ScrollController();
  final offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    ctl.addListener(() => offset.value = ctl.offset);
  }

  @override
  void dispose() {
    ctl.dispose();
    offset.dispose();
    super.dispose();
  }

  /// Takes part in row layout (grid item) but is painted by [sticky].
  Widget _ghost(Widget child) => Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: child);

  Widget sticky(Widget child) => Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: 68,
    child: ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, v, c) => Transform.translate(offset: Offset(v, 0), child: c),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth < 640 ? 640.0 : c.maxWidth;
          Widget cell(String t) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(border: Border(left: bs(1, p.hl))),
              child: T(t, s: 13, lh: 1.35),
            ),
          );
          final headCell = Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: p.bg,
              border: Border(right: bs(1, p.hl)),
            ),
            child: const Kicker('Day', s: 10, nowrap: true),
          );
          Widget dayCell(int i) => Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: i == todayIdx ? p.ab : p.bg,
              border: Border(right: bs(1, p.hl)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                T(weekDays[i][0], w: 800, s: 14, c: i == todayIdx ? p.ad : p.tx),
                const SizedBox(height: 1),
                T('${weekDays[i][1]} ${weekDays[i][2]}', s: 11, c: p.mu),
              ],
            ),
          );
          return Scroll(
            horizontal: true,
            controller: ctl,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                    child: Stack(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 68, child: _ghost(headCell)),
                              for (final m in meals)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(border: Border(left: bs(1, p.hl))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        T(m[1], w: 800, s: 14),
                                        const SizedBox(height: 1),
                                        T(s.mealTimeText(s.foodHid, m[0]), s: 11, c: p.mu),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        sticky(headCell),
                      ],
                    ),
                  ),
                  for (var i = 0; i < s.menu.length; i++)
                    Tap(
                      onTap: () => widget.onPick(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == todayIdx ? p.ab : transparent,
                          border: Border(bottom: bs(1, p.hl)),
                        ),
                        child: Stack(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(width: 68, child: _ghost(dayCell(i))),
                                  cell(s.menu[i].b),
                                  cell(s.menu[i].l),
                                  cell(s.menu[i].n),
                                ],
                              ),
                            ),
                            sticky(dayCell(i)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// F22 Area 2 (board `food`): today first. A day strip, the 3 meals tagged
/// Done / Next / Later on today, "How was breakfast?", and the whole week one
/// tap away in the header.
class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  /// When each meal ends (hour of the day), for Done / Next / Later.
  static const _ends = {'b': 9.5, 'l': 14.0, 'n': 22.0};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final fh = s.foodHid;
    final dm = s.menu[s.day];
    final week = s.foodView == 'week';
    final noMenu = s.menuOf(fh) == null;
    // Tenants open Food from a hostel page: no rating, and a way back.
    final mine = s.role == 'resident';
    final now = DateTime.fromMillisecondsSinceEpoch(s.now);
    final hour = now.hour + now.minute / 60;
    final next = meals.where((m) => hour < _ends[m[0]]!).firstOrNull?[0];
    String tag(String k) => hour >= _ends[k]! ? 'Done' : (k == next ? 'Next' : 'Later');
    return Scroll(
      key: ValueKey('food${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnShow(() => s.loadMenu(fh), child: const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!mine) ...[BackBtn(onTap: s.back), const SizedBox(width: 12)],
                Expanded(
                  child: PageHead(kicker: hostelById(fh).name, title: mine ? 'Food' : 'Food menu'),
                ),
                if (!noMenu)
                  Tap(
                    key: const ValueKey('foodWeek'),
                    onTap: () => s.update(() => s.foodView = week ? 'day' : 'week'),
                    child: Padding(padding: const EdgeInsets.only(bottom: 6), child: T(week ? '‹ By day' : 'Whole week ›', s: 14, w: 800)),
                  ),
              ],
            ),
          ),
          if (noMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: T('${mine ? s.stayOwner : hostelById(fh).owner} hasn’t put the menu on Hostelzy yet. It shows here once they do.', s: 14, c: p.mu, lh: 1.45),
            )
          else if (week) ...[
            WeekTable(
              onPick: (i) => s.update(() {
                s.day = i;
                s.foodView = 'day';
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: T('Today is highlighted. Swipe sideways for dinner. Tap a day to open it.', s: 12, c: p.mu),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < weekDays.length; i++)
                      Expanded(
                        child: Tap(
                          key: ValueKey('day-$i'),
                          onTap: () => s.update(() => s.day = i),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: i == s.day ? p.tx : transparent,
                            alignment: Alignment.center,
                            child: Css(
                              c: i == s.day ? p.bg : p.tx,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [T(weekDays[i][0], s: 12, w: 600), T(weekDays[i][1], w: 800, s: 17)]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final m in meals)
              () {
                final today = s.day == todayIdx;
                final tg = today ? tag(m[0]) : null;
                return Opacity(
                  opacity: tg == 'Done' ? .55 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Rich([sp(context, m[1], w: 800, s: 18), sp(context, '  ${s.mealTimeText(s.foodHid, m[0])}', s: 13, c: p.mu)]),
                              const SizedBox(height: 2),
                              T(dm.of(m[0]), s: 15, lh: 1.4),
                            ],
                          ),
                        ),
                        if (tg != null) ...[const SizedBox(width: 12), Tag(tg, bg: tg == 'Next' ? p.ab : p.sf, fg: tg == 'Next' ? p.ad : (tg == 'Done' ? p.mu : p.tx))],
                      ],
                    ),
                  ),
                );
              }(),
            if (mine && s.day == todayIdx)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: box(w: 2, c: p.tx),
                child: VGap(
                  gap: 8,
                  children: [
                    const T('How was breakfast?', w: 800, s: 15),
                    Seg(
                      opts: same(['Good', 'Okay', 'Poor']),
                      cur: s.rated,
                      onPick: (v) => s.rateMeal('b', v),
                      pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      fs: 14,
                      center: true,
                      dividers: true,
                    ),
                    T('${s.stayOwner} sees how many said each, never your name.', s: 13, c: p.mu),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
