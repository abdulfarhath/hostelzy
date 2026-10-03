import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'reminders.dart';

class ResidentHomeScreen extends StatelessWidget {
  const ResidentHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // F21: the resident's real stay (the sample one only in demo builds).
    final st = s.myStay;
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final terms = h.terms;
    final tm = s.menu[todayIdx];
    final rentAmt = s.myRentPay?.amt ?? (st == null ? 0 : st.rent + s.myElectricity);
    // Meals: done once they're over, the next one, then later.
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final mealEnds = [9 * 60 + 30, 14 * 60, 22 * 60];
    final nextMeal = mealEnds.indexWhere((e) => nowMin < e);
    // F21 W3: three actions right under the rent card. Notice, swap and room
    // layouts live in Me › My stay.
    final quick = <(String, String, VoidCallback)>[
      ('Pay rent', 'wallet', () => s.tab('rPay')),
      ('Raise complaint', 'wrench', () => s.tab('help')),
      ('Message owner', 'msg', () => s.openWA(owner, 'Hi $owner, this is ${s.meFirst.isEmpty ? 'your resident' : s.meFirst}${s.stayRoom.isEmpty ? '' : ' from room ${s.stayRoom}'}.', phone: s.stayOwnerPhone)),
    ];
    return Scroll(
      key: ValueKey('rHome${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnShow(() {
            s.maybeOfferReminders();
            s.loadMenu(h.id);
          }, child: const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PageHead(kicker: st == null ? 'Your stay' : s.stayLine, title: s.meFirst.isEmpty ? 'Hello' : 'Hello, ${s.meFirst}', size: 30)),
                const SizedBox(width: 12),
                Tap(onTap: () => s.tab('me'), child: Container(width: 44, height: 44, color: p.ac, alignment: Alignment.center, child: s.meName.isEmpty ? Ic('user', size: 20, color: p.ai) : T(initials(s.meName), w: 800, s: 15, c: p.ai))),
              ],
            ),
          ),
          if (s.showToday) const TodayCard(),
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
                      Kicker('${monthNames[appToday.month - 1]} rent'),
                      const SizedBox(height: 4),
                      T(fmt(rentAmt), w: 800, s: 34, ls: -.02, lh: 1.05),
                      const SizedBox(height: 2),
                      T(s.paid ? 'Paid. Thank you.' : '${dueNote(terms, st?.joinDay ?? 1)} · ${dueLeft(terms, st?.joinDay ?? 1)}', s: 13, w: 600, c: s.paid ? p.gn : p.ad),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Cta(s.paid ? 'Receipt' : 'Pay', onTap: () => s.tab('rPay'), height: 44, px: 14, fs: 14, iconSize: 14, expand: false, gap: 10, bg: s.paid ? transparent : p.ac, fg: s.paid ? p.tx : p.ai, border: s.paid ? p.tx : p.ac),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, q) in quick.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Tap(
                      key: ValueKey('quick-${q.$1}'),
                      onTap: q.$3,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 72),
                        padding: const EdgeInsets.all(10),
                        decoration: box(w: 2, c: p.tx),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Ic(q.$2, size: 20, color: p.ad), const SizedBox(height: 6), T(q.$1, w: 800, s: 13, lh: 1.15)]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
          // F08: the 30-day review (one per stay).
          if (!s.reviews.any((r) => r.name == s.meShort && r.kind == '30-day'))
            Tap(
              onTap: () => s.go('rReview'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: box(w: 1, c: p.dv),
                child: Row(
                  children: [
                    const Ic('star', size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Rich([sp(context, 'How is your stay so far? ', w: 800), sp(context, 'Rate ${h.name.split(' ').first} for other tenants.', c: p.mu)], s: 14, lh: 1.35)),
                    const Ic('chev', size: 18),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Kicker("Today's food · $todayName")),
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
                if (s.menuOf(h.id) == null)
                  Padding(padding: const EdgeInsets.all(16), child: T('$owner hasn’t put the menu on Hostelzy yet.', s: 14, c: p.mu))
                else
                for (var i = 0; i < meals.length; i++)
                  Opacity(
                    opacity: nextMeal == -1 || i < nextMeal ? .55 : 1,
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
                              child: T(s.mealTimeText(h.id, meals[i][0]), s: 12, c: p.mu),
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
                          Tag(nextMeal == -1 || i < nextMeal ? 'Done' : (i == nextMeal ? 'Next' : 'Later'), bg: i == nextMeal ? p.ac : p.sf, fg: i == nextMeal ? p.ai : p.tx),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// F22 Area 2 (board `rPay`): one amount card, a few rows, one or two
/// actions at the bottom. Due → Waiting for owner → Paid (card goes dark).
class RentPayScreen extends StatelessWidget {
  const RentPayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final st = s.myStay;
    if (st == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: PageHead(kicker: 'Your stay', title: 'Rent'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: T('Your stay isn’t on Hostelzy yet. Once your owner adds you, your rent shows here.', s: 14, c: p.mu, lh: 1.45),
          ),
        ],
      );
    }
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final terms = h.terms;
    // F21: the month's real rent; on the server nothing exists until the resident starts paying.
    // F24 #25: this month's electricity (board `rentMeter`) is added to the rent.
    final meter = s.myMeter;
    final elec = s.myElectricity;
    final rent = s.myRentPay ?? Payment(id: '', kind: 'rent', hid: st.hid, who: s.meShort, what: 'Rent', bed: st.bed, amt: st.rent + elec, note: s.rentNote);
    final started = rent.id.isNotEmpty;
    final sample = !s.onServer;
    final history = sample ? [('September', '₹8,040 · confirmed 3 Sep'), ('August', '₹7,980 · confirmed 4 Aug'), ('July', '₹8,110 · confirmed 2 Jul')] : const <(String, String)>[];
    final advance = sample ? terms.advance : s.myStayRow?.advance ?? 0;
    final upi = s.ownerUpi[st.hid]?.id ?? '';
    final month = monthYear(appToday).split(' ').first;
    final paid = rent.status == 'paid';
    final (label, line) = switch (rent.status) {
      'paid' => ('$month rent · Paid', '$owner confirmed on ${rent.done}. Thank you.'),
      'waiting' => ('Waiting for $owner', 'You sent UPI reference ${utrSpaced(rent.utr ?? '')}. It says Paid once $owner sees it.'),
      'missing' => ('Not received', '$owner couldn’t find UPI reference ${utrSpaced(rent.utr ?? '')}. Check it in your UPI app.'),
      _ => ('$month rent', '${dueNote(terms, st.joinDay)} · ${dueLeft(terms, st.joinDay)}'),
    };
    void remind() => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, I paid ${fmt(rent.amt)} rent for bed ${st.bed} by UPI. UPI reference ${utrSpaced(rent.utr ?? '')}. Please confirm on Hostelzy.');
    final actions = <Widget>[
      if (rent.status == 'due') ...[
        Cta('Pay ${fmt(rent.amt)} by UPI', height: 54, px: 16, fs: 15, onTap: s.payMyRent),
        if (started) OutlineCta('I’ve paid · enter UPI reference', icon: 'chev', onTap: () => s.openPayUtr(rent)),
      ],
      if (rent.status == 'waiting') ...[
        Cta('Remind $owner', icon: 'msg', height: 54, px: 16, fs: 15, onTap: remind),
        OutlineCta('Fix the UPI reference', icon: 'chev', onTap: () => s.openPayUtr(rent)),
      ],
      if (rent.status == 'missing') ...[
        Cta('Fix the UPI reference', height: 54, px: 16, fs: 15, onTap: () => s.openPayUtr(rent)),
        OutlineCta('Talk to $owner on WhatsApp', icon: 'msg', onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, about my rent for bed ${st.bed}: UPI reference ${utrSpaced(rent.utr ?? '')}.')),
      ],
      if (paid)
        Cta(
          'Share receipt',
          icon: 'msg',
          height: 54,
          px: 16,
          fs: 15,
          onTap: () => s.share('Rent receipt · ${h.name} · bed ${st.bed} · ${monthYear(appToday)} · ${fmt(rent.amt)} · UPI ref. ${utrSpaced(rent.utr ?? '')} · confirmed by $owner on ${rent.done}'),
        ),
    ];
    Widget row(String k, String v) => KV(k, v, keyWidth: 130);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scroll(
            key: ValueKey('rPay${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: PageHead(kicker: '${h.name}${st.bed.isEmpty ? '' : ' · Bed ${st.bed}'}', title: 'Rent'),
                ),
                Container(
                  key: const ValueKey('rentCard'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  padding: const EdgeInsets.all(16),
                  color: paid ? p.tx : p.sf,
                  child: Css(
                    c: paid ? p.bg : p.tx,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Kicker(label, c: paid ? p.bg : p.tx),
                        const SizedBox(height: 4),
                        T(fmt(rent.amt), w: 800, s: 52, lh: 1.05, ls: -.03, tab: true),
                        const SizedBox(height: 6),
                        T(line, s: 14, w: rent.status == 'due' || rent.status == 'missing' ? 800 : 400, c: paid ? p.bg : (rent.status == 'waiting' ? p.tx : p.ad), lh: 1.4),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row('Rent', fmt(sample ? rent.amt - elec : st.rent)),
                      if (meter != null)
                        KV('Electricity · ${meter.units} units ÷ ${meter.people} · ${perUnit(meter.rate)}/unit', fmt(elec), key: const ValueKey('rentMeter'), keyWidth: 150)
                      else if (terms.electricityExtra)
                        row('Electricity', 'Not added yet'),
                      row('Pay to', upi.isEmpty ? '$owner hasn’t added a UPI ID yet' : upi),
                    ],
                  ),
                ),
                if (history.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Paid before')),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final x in history) row(x.$1, x.$2)]),
                  ),
                ],
                if (advance > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: T('Advance ${fmt(advance)} · ${fmt(math.max(0, advance - terms.maintenance))} back when you leave', s: 14),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: T('You pay $owner directly. Hostelzy never holds the money.', s: 12, c: p.mu, lh: 1.4),
                ),
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: p.bg,
              border: Border(top: bs(2, p.tx)),
            ),
            child: VGap(gap: 8, children: actions),
          ),
      ],
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

/// F21 W3: complaint words a resident reads ("Sent", "Being fixed", "Fixed").
String complaintWord(String status) => switch (status) {
  'Open' => 'Sent',
  'In progress' => 'Being fixed',
  _ => 'Fixed',
};

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final owner = s.stayOwner;
    final mine = s.complaints.where((c) => c.mine).toList().reversed.toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    return Scroll(
      key: ValueKey('help${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: const T('Help', s: 30, w: 800, lh: 1.02, ls: -.025),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: VGap(
              gap: 10,
              children: [
                const Kicker('Something wrong in your room?'),
                wrap(6, [
                  for (final c in const ['Wi-Fi', 'Water', 'Electricity', 'Cleaning', 'Food', 'Other']) ChipBtn(c, on: c == s.cCat, pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 12), onTap: () => s.update(() => s.cCat = c)),
                ]),
                Field(value: s.cText, onChanged: (v) => s.update(() => s.cText = v), placeholder: 'What’s wrong? Where, and since when.', maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
                Row(
                  children: [
                    Tap(
                      key: const ValueKey('cPhoto'),
                      onTap: s.cPhoto == null ? s.pickComplaintPhoto : () => s.update(() => s.cPhoto = null),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: box(w: 2, c: p.tx),
                        alignment: Alignment.center,
                        child: s.cPhoto == null ? const Ic('camera', size: 20) : Stack(fit: StackFit.expand, children: [Image.memory(s.cPhoto!, fit: BoxFit.cover), Align(alignment: Alignment.topRight, child: Container(color: p.bg, child: const Ic('x', size: 14)))]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Cta('Send to owner', height: 54, px: 16, fs: 15, onTap: s.raiseComplaint)),
                  ],
                ),
              ],
            ),
          ),
          if (mine.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
              child: VGap(gap: 6, children: [const T('No complaints', w: 800, s: 17), T('When something breaks, tell $owner here. You’ll see when it’s fixed.', s: 14, c: p.mu, lh: 1.4)]),
            )
          else ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: Kicker('Your complaints')),
            Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in mine)
                    () {
                      final fresh = c.status == 'Open' && c.at != null && now - c.at! < 10 * 60 * 1000;
                      final word = complaintWord(c.status);
                      final when = fresh ? 'Just now' : c.date;
                      final line = c.status == 'Open' && s.onServer ? '$owner sees it in the app' : (c.note.isEmpty ? 'Sent to $owner' : (c.status == 'Open' ? c.note : '“${c.note}”'));
                      return Container(
                        color: fresh ? p.sf : null,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: null,
                        child: VGap(
                          gap: 4,
                          children: [
                            Row(
                              children: [
                                Expanded(child: T(c.cat, w: 800, s: 15)),
                                if (c.photo != null || s.complaintPhotosLocal[c.id] != null) ...[Ic('camera', size: 14, color: p.mu), const SizedBox(width: 8)],
                                word == 'Fixed' ? Tag(word, bg: transparent, fg: p.mu) : Tag(word, bg: p.ab, fg: p.ad),
                              ],
                            ),
                            T(c.text, s: 14),
                            T('$when · $line', s: 12, c: p.mu),
                          ],
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// F22 Area 2 (board `stay`): Me › My stay. The bed, then the things a
/// resident does once in a while: move, give notice, review, fix a layout.
class StayScreen extends StatelessWidget {
  const StayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final st = s.myStay;
    final h = s.stayHostel;
    final terms = h.terms;
    final sample = !s.onServer;
    final rent = sample ? 7600 : st?.rent ?? 0;
    final free = (s.rooms[h.id] ?? const <Room>[]).expand((r) => r.beds).where((b) => b.state == 'free' && !b.mine).length;
    final advance = sample ? terms.advance : s.myStayRow?.advance ?? 0;
    final since = sample ? 'Since $residentJoined ${appToday.year}' : s.myStayRow?.since ?? '';
    void move(String t) => s.update(() {
      s.hist = [...s.hist, s.screen];
      s.screen = 'move';
      s.sheet = null;
      s.moveTab = t;
    });
    final rows = <(String, String, String, VoidCallback)>[
      ('swap', 'Move to another bed', free == 0 ? 'No free beds right now' : '$free free bed${free == 1 ? '' : 's'} here', () => move('swap')),
      ('logout', 'Give notice', '${terms.noticeDays} days · earliest last day ${leaveDates(terms).first}', () => move('vacate')),
      ('star', 'Review your stay', '30-day review', () => s.go('rReview')),
      ('pencil', 'Fix a room layout', 'Any room in ${h.name}', () => s.openFixRoom(s.myRoomLabel.isEmpty ? (s.rooms[h.id]?.first.n ?? 101) : int.tryParse(s.myRoomLabel) ?? 101)),
    ];
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(h.name), const T('My stay', w: 800, s: 26, lh: 1.1)]),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rStay${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (st == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: T('Your stay isn’t on Hostelzy yet. Once ${s.stayOwner} adds you, it shows here.', s: 14, c: p.mu, lh: 1.45),
                  )
                else
                  Container(
                    key: const ValueKey('stayCard'),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        T(st.bed.isEmpty ? h.name : 'Bed ${st.bed} · Room ${s.stayRoom}', w: 800, s: 20),
                        const SizedBox(height: 2),
                        T([if (since.isNotEmpty) since, if (rent > 0) '${fmt(rent)} a month', 'rent due on the ${ordinal(terms.dueDay(st.joinDay))}'].join(' · '), s: 14, c: p.mu, lh: 1.4),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final r in rows)
                        Tap(
                          key: ValueKey('stay-${r.$2}'),
                          onTap: r.$4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  color: p.sf,
                                  alignment: Alignment.center,
                                  child: Ic(r.$1, size: 18, color: p.tx),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      T(r.$2, w: 800, s: 16),
                                      T(r.$3, s: 13, c: p.mu),
                                    ],
                                  ),
                                ),
                                Ic('chev', size: 16, color: p.mu),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (advance > 0) Padding(padding: const EdgeInsets.all(16), child: T('Advance ${fmt(advance)} · ${fmt(math.max(0, advance - terms.maintenance))} back when you leave', s: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// F22 Area 2 (boards `notice` and `swap`): one job each, the action at the
/// bottom. On the server notice and moves go to the owner on WhatsApp
/// (nothing pretends to be saved on Hostelzy).
class MoveScreen extends StatelessWidget {
  const MoveScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final bed = s.myStay?.bed ?? '';
    final myRent = !s.onServer ? 7600 : s.myStay?.rent ?? 0;
    final terms = h.terms;
    final dates = leaveDates(terms);
    final a = s.rooms[h.id] ?? const <Room>[];
    final swapBeds = <({Bed b, Room r})>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' && b.id != bed && !b.mine && swapBeds.length < 6) swapBeds.add((b: b, r: r));
      }
    }
    final vacate = s.moveTab == 'vacate';
    final who = s.meFirst.isEmpty ? 'your resident' : s.meFirst;
    final from = bed.isEmpty ? '' : ' from bed $bed';
    Widget body;
    Widget? bar;
    // F24: the notice on the server (open, accepted or declined).
    final n = s.myNotice;
    final given = s.notice || (n != null && n.status != 'declined');
    final lastDay = n?.lastDay != null ? dayMon(n!.lastDay!) : s.vDate;
    if (vacate && !given) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: VGap(
          gap: 10,
          children: [
            T('Notice is ${terms.noticeDays} days. Pick your last day.', s: 15, c: p.mu, lh: 1.5),
            for (var i = 0; i < dates.length; i++)
              Tap(
                key: ValueKey('vDate-${dates[i]}'),
                onTap: () => s.update(() => s.vDate = dates[i]),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: box(bg: s.vDate == dates[i] ? p.ab : transparent, w: 2, c: s.vDate == dates[i] ? p.ac : p.tx),
                  child: Row(
                    children: [
                      Expanded(child: T(dates[i], w: 800, s: 15)),
                      if (i == 0) T('earliest', s: 13, c: p.mu),
                    ],
                  ),
                ),
              ),
            const Padding(padding: EdgeInsets.only(top: 6), child: T('Why are you leaving? (optional)', w: 800, s: 13)),
            wrap(6, [
              for (final r in const ['New job', 'Moving home', 'Found another place', 'Other']) ChipBtn(r, on: r == s.vReason, onTap: () => s.update(() => s.vReason = s.vReason == r ? null : r)),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              color: p.sf,
              child: Rich(
                [sp(context, '${fmt(terms.refund)} back', w: 800), sp(context, ' to your UPI within 7 days of leaving (advance ${fmt(terms.advance)} minus ${fmt(terms.maintenance)} maintenance).')],
                s: 14,
                lh: 1.5,
              ),
            ),
          ],
        ),
      );
      bar = Cta(
        'Give notice for ${s.vDate}',
        parts: ['Give notice for', s.vDate],
        height: 54,
        px: 16,
        fs: 15,
        onTap: s.giveNotice,
      );
    } else if (vacate) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: VGap(
              gap: 8,
              children: [
                Kicker(n?.status == 'accepted' ? 'Notice accepted' : 'Notice given', c: p.ad),
                T('Your last day is $lastDay.', w: 800, s: 28, lh: 1.05),
                T(
                  key: const ValueKey('noticeStatus'),
                  n?.status == 'accepted' ? 'Accepted by $owner. Your bed shows "free soon" on Hostelzy.' : 'Sent to $owner. They accept it in Hostelzy, then your bed shows "free soon".',
                  s: 14,
                  c: p.mu,
                ),
                OutlineCta(
                  'Tell $owner on WhatsApp',
                  icon: 'msg',
                  height: 48,
                  onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, this is $who$from. I gave notice on Hostelzy: my last day is $lastDay.'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimelineStep(t: 'Notice given', d: n != null && n.at > 0 ? dayMon(DateTime.fromMillisecondsSinceEpoch(n.at)) : 'Today, ${dayMon(appToday)}', bg: p.tx, bd: p.tx),
                TimelineStep(t: '$owner accepts it', d: n?.status == 'accepted' ? 'Done' : 'In Hostelzy', bg: n?.status == 'accepted' ? p.tx : transparent, bd: n?.status == 'accepted' ? p.tx : p.tk),
                TimelineStep(t: '${fmt(terms.refund)} back to your UPI', d: 'Advance minus ${fmt(terms.maintenance)} maintenance, within 7 days of leaving. Hostelzy asks you when it arrives.', bg: transparent, bd: p.tk),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                key: const ValueKey('withdrawNotice'),
                onTap: () => n != null && n.status == 'open' ? s.withdrawMove(n) : s.update(() => s.notice = false),
                child: T('Withdraw notice', w: 600, s: 14, c: p.ad),
              ),
            ),
          ),
        ],
      );
      // F08: exit review with the advance check.
      bar = OutlineCta('Review your stay', icon: 'star', height: 52, fs: 14, onTap: () => s.go('rExit'));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: T('New rent starts next month. $owner confirms the move.', s: 14, c: p.mu, lh: 1.45),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (swapBeds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: T('No free beds in ${h.name} right now.', s: 14, c: p.mu),
                  ),
                for (final e in swapBeds)
                  () {
                    final diff = e.r.rent - myRent;
                    final o = e.b.id == s.swapBed;
                    return Tap(
                      key: ValueKey('swap-${e.b.id}'),
                      onTap: () => s.update(() => s.swapBed = e.b.id),
                      child: InsetBar(
                        edge: Edge.left,
                        size: o ? 4 : 0,
                        color: p.ac,
                        bg: o ? p.ab : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    T('Bed ${e.b.id}', w: 800, s: 16),
                                    const SizedBox(height: 2),
                                    T(['Floor ${e.r.floor}', '${e.r.share} sharing${e.r.ac ? ' AC' : ''}', e.b.spot, if ('${e.r.n}' == s.stayRoom) 'same room'].join(' · '), s: 13, c: p.mu),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              T(
                                myRent == 0
                                    ? fmt(e.r.rent)
                                    : diff == 0
                                    ? 'Same rent'
                                    : '${diff > 0 ? '+ ' : '− '}${fmt(diff.abs())}',
                                w: 800,
                                s: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ],
      );
      bar = Cta(
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
          s.askMove();
        },
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Kicker(vacate && bed.isNotEmpty ? 'Bed $bed' : h.name), T(vacate ? 'Give notice' : 'Move to another bed', w: 800, s: 26, lh: 1.1)],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scroll(key: ValueKey('move${s.scrollEpoch}'), child: body),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: bs(2, p.tx)),
          ),
          child: bar,
        ),
      ],
    );
  }
}

