import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

class ResidentHomeScreen extends StatelessWidget {
  const ResidentHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final tm = s.menu[3];
    final board = <(String, String?, VoidCallback?)>[('Arjun and Sai leave 8:40 am for Mindspace. Auto share, ₹40 each.', 'Join', () => s.toastMsg('Joined. Meet at the gate at 8:40.')), ('September electricity for room 204: ₹1,260, split 3 ways.', null, null), ('Water tank cleaning on Saturday, 10 am to 1 pm.', null, null)];
    final quick = <(String, String, VoidCallback)>[
      (
        'Swap bed',
        'swap',
        () => s.update(() {
          s.hist = [...s.hist, s.screen];
          s.screen = 'move';
          s.sheet = null;
          s.moveTab = 'swap';
        }),
      ),
      (
        'Give notice',
        'logout',
        () => s.update(() {
          s.hist = [...s.hist, s.screen];
          s.screen = 'move';
          s.sheet = null;
          s.moveTab = 'vacate';
        }),
      ),
      ('Raise complaint', 'wrench', () => s.tab('help')),
      ('Message warden', 'msg', () => s.openWA('Ravi, warden', 'Hi Ravi, this is Rahul from room 204.')),
    ];
    Widget quickBtn((String, String, VoidCallback) q) => Expanded(
      child: Tap(
        onTap: q.$3,
        child: Container(
          color: p.bg,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Ic(q.$2, size: 22, color: p.ad),
              const SizedBox(height: 18),
              T(q.$1, w: 800, s: 15),
            ],
          ),
        ),
      ),
    );
    return Scroll(
      key: ValueKey('rHome${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageHead(kicker: 'Anjani Residency · Room 204 · Bed B', title: 'Morning, Rahul', size: 32),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: box(bg: s.paid ? p.gb : transparent, w: 2, c: p.tx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Kicker('October rent'),
                      const SizedBox(height: 4),
                      const T('₹8,020', w: 800, s: 34, ls: -.02, lh: 1.05),
                      const SizedBox(height: 2),
                      T(s.paid ? 'Paid today. Thank you.' : 'Due 5 Oct · 4 days left', s: 13, w: 600, c: s.paid ? p.gn : p.ad),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Cta(s.paid ? 'Receipt' : 'Pay', onTap: () => s.tab('rPay'), height: 44, px: 14, fs: 14, iconSize: 14, expand: false, gap: 10, bg: s.paid ? transparent : p.ac, fg: s.paid ? p.tx : p.ai, border: s.paid ? p.tx : p.ac),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Kicker("Today's food · Thursday", nowrap: true),
                Tap(
                  onTap: () => s.tab('food'),
                  child: T('Full week', s: 12, w: 600, c: p.ad),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < meals.length; i++)
                  Opacity(
                    opacity: i == 0 ? .55 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 76,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: T(meals[i][2], s: 12, c: p.mu),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(meals[i][1], w: 800, s: 15),
                                const SizedBox(height: 2),
                                T(tm.of(meals[i][0]), s: 13, c: p.mu),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tag(const ['Done', 'Next', 'Later'][i], bg: i == 1 ? p.ac : p.sf, fg: i == 1 ? p.ai : p.tx),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 22, 16, 6), child: Kicker('Room 204 board')),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final n in board)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Css(
                      s: 14,
                      lh: 1.4,
                      child: Row(
                        children: [
                          Expanded(child: T(n.$1)),
                          if (n.$2 != null) ...[
                            const SizedBox(width: 12),
                            Tap(
                              onTap: n.$3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: box(w: 2, c: p.tx),
                                child: T(n.$2!, w: 800, s: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 22),
            decoration: BoxDecoration(
              color: p.hl,
              border: Border(top: bs(2, p.dv), bottom: bs(1, p.hl)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [quickBtn(quick[0]), const SizedBox(width: 1), quickBtn(quick[1])]),
                ),
                const SizedBox(height: 1),
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [quickBtn(quick[2]), const SizedBox(width: 1), quickBtn(quick[3])]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RentPayScreen extends StatelessWidget {
  const RentPayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final history = [if (s.paid) ('October 2026', '₹8,020', 'Paid 1 Oct by ${s.payM}'), ('September 2026', '₹8,040', 'Paid 3 Sep by UPI'), ('August 2026', '₹7,980', 'Paid 4 Aug by UPI'), ('July 2026', '₹8,110', 'Paid 2 Jul by Card')];
    return Scroll(
      key: ValueKey('rPay${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: const PageHead(kicker: 'Bed 204-B · Anjani Residency', title: 'Pay rent'),
          ),
          if (!s.paid) ...[
            const LineRow('Rent, bed 204-B', '₹7,600'),
            const LineRow('Electricity, September share', '₹420'),
            const LineRow('Late fee', '₹0'),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [T('Total for October', w: 800, s: 16), T('₹8,020', w: 800, s: 26)]),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 8), child: Kicker('Pay with')),
            Seg(opts: same(['UPI', 'Card', 'Net banking']), cur: s.payM, onPick: (v) => s.update(() => s.payM = v), pad: const EdgeInsets.all(12), fs: 14, margin: const EdgeInsets.symmetric(horizontal: 16)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Cta(
                    'Pay ₹8,020 by ${s.payM}',
                    parts: ['Pay', '₹8,020', 'by', s.payM],
                    onTap: () {
                      s.update(() {
                        s.paid = true;
                        for (final r in s.residents) {
                          if (r.bed == '204-B') {
                            r.status = 'Paid';
                            r.note = 'Paid 1 Oct';
                          }
                        }
                      });
                      s.toastMsg('Paid ₹8,020. Receipt sent on WhatsApp.');
                    },
                  ),
                  const SizedBox(height: 8),
                  T('Due 5 Oct. The owner gets a receipt on WhatsApp.', s: 12, c: p.mu),
                ],
              ),
            ),
          ],
          if (s.paid)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: p.gn,
                border: Border(bottom: bs(2, p.tx)),
              ),
              child: Css(
                c: p.ai,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: box(w: 2, c: p.ai),
                        child: const Ic('check', size: 24),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const T('₹8,020 paid', w: 800, s: 40, ls: -.03, lh: 1),
                    const SizedBox(height: 8),
                    const T('October 2026 · Receipt HZ-2610-0482', s: 14, w: 600),
                  ],
                ),
              ),
            ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('Deposit')),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(top: bs(2, p.dv), bottom: bs(1, p.hl)),
            ),
            child: Css(
              s: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Rich([sp(context, '₹15,200', w: 800), sp(context, ' '), sp(context, 'held since 14 Mar', c: p.mu)]),
                  Tag('Refundable', bg: p.sf),
                ],
              ),
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('History')),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in history)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Css(
                      s: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Rich([sp(context, h.$1, w: 800), sp(context, '\n'), sp(context, h.$3, s: 12, w: 600, c: p.gn)])),
                          const SizedBox(width: 12),
                          T(h.$2, w: 600),
                        ],
                      ),
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
              color: i == 3 ? p.ab : p.bg,
              border: Border(right: bs(1, p.hl)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                T(weekDays[i][0], w: 800, s: 14, c: i == 3 ? p.ad : p.tx),
                const SizedBox(height: 1),
                T('${weekDays[i][1]}${i < 3 ? ' Sep' : ' Oct'}', s: 11, c: p.mu),
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
                                        T(m[2], s: 11, c: p.mu),
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
                          color: i == 3 ? p.ab : transparent,
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

class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final dm = s.menu[s.day];
    return Scroll(
      key: ValueKey('food${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageHead(kicker: 'This week · Anjani Residency', title: 'Food'),
          ),
          Seg(opts: const [('day', 'By day'), ('week', 'Whole week')], cur: s.foodView, onPick: (v) => s.update(() => s.foodView = v), margin: const EdgeInsets.fromLTRB(16, 0, 16, 14)),
          if (s.foodView == 'week') ...[
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
          ],
          if (s.foodView == 'day') ...[
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
                          onTap: () => s.update(() => s.day = i),
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == s.day ? p.tx : transparent,
                              border: i > 0 ? Border(left: bs(1, p.hl)) : null,
                            ),
                            child: InsetBar(
                              edge: Edge.bottom,
                              size: i == 3 ? 4 : 0,
                              color: p.ac,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 10, 0, 9),
                                child: Css(
                                  c: i == s.day ? p.bg : p.tx,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(weekDays[i][0], s: 11, w: 600), const SizedBox(height: 1), T(weekDays[i][1], w: 800, s: 18)]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final m in meals)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: VGap(
                  gap: 6,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        T(m[1], w: 800, s: 20),
                        T(m[2], s: 13, c: p.mu),
                      ],
                    ),
                    T(dm.of(m[0]), s: 15, lh: 1.45),
                  ],
                ),
              ),
            if (s.day == 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                child: VGap(
                  gap: 10,
                  children: [
                    const Kicker('How was breakfast?'),
                    Seg(
                      opts: same(['Good', 'Okay', 'Poor']),
                      cur: s.rated,
                      onPick: (v) {
                        s.update(() => s.rated = v);
                        s.toastMsg('Thanks. Shared with the kitchen.');
                      },
                      pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      fs: 14,
                    ),
                    T('Shared with the kitchen without your name.', s: 12, c: p.mu),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final mine = s.complaints.where((c) => c.mine).toList().reversed;
    return Scroll(
      key: ValueKey('help${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: const PageHead(kicker: 'Something wrong in your room?', title: 'Help'),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.dv))),
            child: VGap(
              gap: 12,
              children: [
                const Kicker('Raise a complaint'),
                wrap(6, [
                  for (final c in const ['WiFi', 'Water', 'Electricity', 'Cleaning', 'Food', 'Geyser', 'Other']) ChipBtn(c, on: c == s.cCat, onTap: () => s.update(() => s.cCat = c)),
                ]),
                Field(value: s.cText, onChanged: (v) => s.update(() => s.cText = v), placeholder: "What's wrong? Bathroom, floor, since when.", maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
                Cta(
                  'Send to warden',
                  height: 50,
                  px: 16,
                  fs: 15,
                  onTap: () {
                    if (s.cText.trim().isEmpty) return s.toastMsg('Tell us what is wrong first.');
                    s.update(() {
                      s.complaints = [...s.complaints, Complaint(id: DateTime.now().millisecondsSinceEpoch, by: 'Rahul V · 204', cat: s.cCat, text: s.cText.trim(), status: 'Open', date: '1 Oct', note: 'Sent to Srinivas', mine: true)];
                      s.cText = '';
                    });
                    s.toastMsg('Sent. Srinivas has 72 hours to fix it.');
                  },
                ),
                T('Not fixed in 72 hours? Hostelzy steps in.', s: 12, c: p.mu),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Your complaints')),
          for (final c in mine)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
              child: VGap(
                gap: 4,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      T(c.cat, w: 800, s: 15),
                      const SizedBox(width: 10),
                      Tag(c.status, bg: tagOf(p, c.status).bg, fg: tagOf(p, c.status).fg),
                    ],
                  ),
                  T(c.text, s: 14),
                  T('${c.date} · ${c.note.isEmpty ? 'Sent to Srinivas' : c.note}', s: 12, c: p.mu),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MoveScreen extends StatelessWidget {
  const MoveScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms['anjani']!;
    final swapBeds = <({Bed b, Room r})>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' && r.n != 204 && !b.mine && swapBeds.length < 6) swapBeds.add((b: b, r: r));
      }
    }
    Widget body;
    if (s.moveTab == 'vacate') {
      body = !s.notice
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: VGap(
                    gap: 12,
                    children: [
                      Rich([sp(context, 'Notice period is '), sp(context, '30 days', w: 800), sp(context, '. The earliest you can leave is '), sp(context, '31 Oct', w: 800), sp(context, '.')], s: 14, lh: 1.45),
                      const Padding(padding: EdgeInsets.only(top: 6), child: Kicker('Last day')),
                      Seg(opts: same(['31 Oct', '15 Nov', '30 Nov']), cur: s.vDate, onPick: (v) => s.update(() => s.vDate = v), pad: const EdgeInsets.all(12), fs: 14),
                      const Padding(padding: EdgeInsets.only(top: 6), child: Kicker('Reason')),
                      wrap(6, [
                        for (final r in const ['New job', 'Moving home', 'Found another place', 'Other']) ChipBtn(r, on: r == s.vReason, onTap: () => s.update(() => s.vReason = r)),
                      ]),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16), child: Kicker('Deposit refund')),
                const LineRow('Deposit held', '₹15,200', pad: EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
                const LineRow('Deductions', '₹0 so far, after inspection', pad: EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
                const LineRow('Estimated refund', '₹15,200 within 7 days', vw: 800, pad: EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Cta(
                    'Give notice for ${s.vDate}',
                    parts: ['Give notice for', s.vDate],
                    height: 54,
                    px: 16,
                    fs: 15,
                    onTap: () {
                      s.update(() => s.notice = true);
                      s.toastMsg('Notice sent to Srinivas.');
                    },
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
                  child: VGap(
                    gap: 8,
                    children: [
                      Kicker('Notice given', c: p.ad),
                      T('Your last day is ${s.vDate}.', w: 800, s: 28, lh: 1.05),
                      T('Srinivas has been told. Your bed goes back on Hostelzy as "free soon".', s: 14, c: p.mu),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TimelineStep(t: 'Notice given', d: 'Today, 1 Oct', bg: p.tx, bd: p.tx),
                      TimelineStep(t: 'Room check with the warden', d: 'On ${s.vDate}, 10 am', bg: transparent, bd: p.tk),
                      TimelineStep(t: 'Deposit back to your UPI', d: 'Within 7 days of leaving', bg: transparent, bd: p.tk),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tap(
                      onTap: () => s.update(() => s.notice = false),
                      child: T('Withdraw notice', w: 600, s: 14, c: p.ad),
                    ),
                  ),
                ),
              ],
            );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
            child: const T('Free beds in Anjani Residency. Rent changes from next month.', s: 14, lh: 1.45),
          ),
          for (final e in swapBeds)
            () {
              final diff = e.r.rent - 7600;
              final o = e.b.id == s.swapBed;
              return Tap(
                onTap: () => s.update(() => s.swapBed = e.b.id),
                child: InsetBar(
                  edge: Edge.left,
                  size: o ? 4 : 0,
                  color: p.ac,
                  bg: o ? p.ab : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T('Bed ${e.b.id}', w: 800, s: 16),
                              const SizedBox(height: 2),
                              T('Floor ${e.r.floor} · ${e.r.share} sharing · ${e.b.spot}', s: 12, c: p.mu),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        T(diff == 0 ? 'Same rent' : '${diff > 0 ? '+' : '−'}${fmt(diff.abs())}', w: 800, s: 14),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Cta(
              s.swapSent
                  ? 'Request sent for ${s.swapBed}'
                  : s.swapBed != null
                  ? 'Ask to move to ${s.swapBed}'
                  : 'Pick a bed to move to',
              icon: 'swap',
              height: 54,
              px: 16,
              fs: 15,
              opacity: s.swapBed != null && !s.swapSent ? 1 : .4,
              onTap: () {
                if (s.swapBed == null || s.swapSent) return;
                s.update(() => s.swapSent = true);
                s.toastMsg('Swap request sent to Srinivas.');
              },
            ),
          ),
        ],
      );
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
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker('Bed 204-B'), T('Move out or swap', w: 800, s: 22, lh: 1.1)]),
              ),
            ],
          ),
        ),
        Seg(opts: const [('vacate', 'Give notice'), ('swap', 'Swap bed')], cur: s.moveTab, onPick: (v) => s.update(() => s.moveTab = v), pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12), fs: 14, margin: const EdgeInsets.symmetric(horizontal: 16)),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(key: ValueKey('move${s.scrollEpoch}'), child: body),
          ),
        ),
      ],
    );
  }
}
