import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'payments.dart';
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
    final rentAmt = s.myRentPay?.amt ?? st?.rent ?? 0;
    // Meals: done once they're over, the next one, then later.
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final mealEnds = [9 * 60 + 30, 14 * 60, 22 * 60];
    final nextMeal = mealEnds.indexWhere((e) => nowMin < e);
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
      ('Message owner', 'msg', () => s.openWA(owner, 'Hi $owner, this is ${s.meFirst.isEmpty ? 'your resident' : s.meFirst}${s.stayRoom.isEmpty ? '' : ' from room ${s.stayRoom}'}.', phone: s.stayOwnerPhone)),
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
          OnShow(s.maybeOfferReminders, child: const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageHead(kicker: st == null ? 'Your stay' : s.stayLine, title: s.meFirst.isEmpty ? 'Hello' : 'Hello, ${s.meFirst}', size: 32),
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
          // F19: residents fix any room's layout at their hostel.
          Tap(
            onTap: () => s.openFixRoom(s.myRoomLabel.isEmpty ? (s.rooms[s.homeHid ?? 'anjani']?.first.n ?? 101) : int.tryParse(s.myRoomLabel) ?? 101),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: box(w: 1, c: p.dv),
              child: Row(
                children: [
                  const Ic('pencil', size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Rich([sp(context, 'Room layouts. ', w: 800), sp(context, 'Something in the wrong place? Fix any room here.', c: p.mu)], s: 14, lh: 1.35)),
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
                Kicker("Today's food · $todayName", nowrap: true),
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
                // F21: the menu lives on the owner's phone until it's on the server; never show the sample one.
                if (s.onServer)
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
                          Tag(nextMeal == -1 || i < nextMeal ? 'Done' : (i == nextMeal ? 'Next' : 'Later'), bg: i == nextMeal ? p.ac : p.sf, fg: i == nextMeal ? p.ai : p.tx),
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
    final st = s.myStay;
    if (st == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 18), child: PageHead(kicker: 'Your stay', title: 'Pay rent')),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: T('Your stay isn’t on Hostelzy yet. Once your owner adds you, your rent shows here.', s: 14, c: p.mu, lh: 1.45)),
        ],
      );
    }
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final terms = h.terms;
    // F21: the month's real rent; on the server nothing exists until the resident starts paying.
    final rent = s.myRentPay ?? Payment(id: '', kind: 'rent', hid: st.hid, who: s.meShort, what: 'Rent', bed: st.bed, amt: st.rent, note: s.rentNote);
    final started = rent.id.isNotEmpty;
    final sample = !s.onServer;
    final history = sample ? [('September 2026', '₹8,040', 'Confirmed by Srinivas on 3 Sep'), ('August 2026', '₹7,980', 'Confirmed by Srinivas on 4 Aug'), ('July 2026', '₹8,110', 'Confirmed by Srinivas on 2 Jul')] : const <(String, String, String)>[];
    final advance = sample ? terms.advance : s.myStayRow?.advance ?? 0;
    final upi = s.ownerUpi[st.hid]?.id ?? '';
    return Scroll(
      key: ValueKey('rPay${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: PageHead(kicker: '${st.bed.isEmpty ? '' : 'Bed ${st.bed} · '}${h.name}', title: 'Pay rent'),
          ),
          // F17: pay the owner by UPI → UTR → the owner confirms → Paid.
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: PaySteps4(rent)),
          if (rent.status != 'paid') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(children: [Expanded(child: T(switch (rent.status) {
                'waiting' => 'Waiting for $owner',
                'missing' => '$owner couldn’t find this UPI reference',
                _ => dueNote(terms, st.joinDay),
              }, w: 800, s: 15, c: rent.status == 'missing' ? p.ad : p.tx)), T(rent.status == 'waiting' ? 'UPI reference ${utrSpaced(rent.utr ?? '')} sent' : 'Pay straight to $owner', s: 12, c: p.mu)]),
            ),
            if (sample) ...[
              const LineRow('Rent, bed 204-B', '₹7,600'),
              const LineRow('Electricity · by meter, from Srinivas', '₹420'),
              const LineRow('Late fee', '₹0'),
            ] else
              LineRow('Rent${st.bed.isEmpty ? '' : ', bed ${st.bed}'}', fmt(rent.amt)),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Flexible(child: T('Pay $owner', w: 800, s: 16)), const SizedBox(width: 12), T(fmt(rent.amt), w: 800, s: 26)]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: VGap(
                gap: 8,
                children: [
                  if (rent.status == 'due') ...[
                    Cta('Pay ${fmt(rent.amt)} by UPI', onTap: s.payMyRent),
                    if (started) OutlineCta('I’ve paid · enter UPI reference', icon: 'chev', onTap: () => s.openPayUtr(rent)),
                  ],
                  if (rent.status == 'waiting')
                    Cta('Remind $owner on WhatsApp', icon: 'msg', bg: p.tx, fg: p.bg, onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, I paid ${fmt(rent.amt)} rent for bed ${st.bed} by UPI. UPI reference ${utrSpaced(rent.utr ?? '')}. Please confirm on Hostelzy.')),
                  if (rent.status == 'missing') ...[
                    Cta('Fix the UPI reference', onTap: () => s.openPayUtr(rent)),
                    OutlineCta('Talk to $owner on WhatsApp', icon: 'msg', onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, about my rent for bed ${st.bed}: UPI reference ${utrSpaced(rent.utr ?? '')}.')),
                  ],
                  T(upi.isEmpty ? '$owner hasn’t added a UPI ID yet. Hostelzy never holds the money.' : 'You pay $upi directly. Hostelzy never holds the money; $owner confirms when it arrives.', s: 12, c: p.mu, lh: 1.4),
                ],
              ),
            ),
          ],
          if (rent.status == 'paid')
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
                    T('${fmt(rent.amt)} paid', w: 800, s: 40, ls: -.03, lh: 1),
                    const SizedBox(height: 8),
                    T('${monthYear(appToday)} · $owner confirmed on ${rent.done}', s: 14, w: 600),
                    const SizedBox(height: 12),
                    Cta('Share receipt', icon: 'msg', height: 46, px: 14, fs: 14, bg: p.ai, fg: p.gn, onTap: () => s.share('Rent receipt · ${h.name} · bed ${st.bed} · ${monthYear(appToday)} · ${fmt(rent.amt)} · UPI ref. ${utrSpaced(rent.utr ?? '')} · confirmed by $owner on ${rent.done}')),
                  ],
                ),
              ),
            ),
          if (advance > 0) ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('Advance')),
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
                    Flexible(child: Rich([sp(context, fmt(advance), w: 800), sp(context, ' '), sp(context, sample ? 'paid $residentJoined' : 'paid when you joined', c: p.mu)])),
                    const SizedBox(width: 8),
                    Tag('${fmt(math.max(0, advance - terms.maintenance))} back when you leave', bg: p.sf),
                  ],
                ),
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageHead(kicker: 'This week · ${s.stayHostel.name}', title: 'Food'),
          ),
          if (s.onServer && s.role == 'resident')
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: T('${s.stayOwner} hasn’t put the menu on Hostelzy yet. It shows here once they do.', s: 14, c: p.mu, lh: 1.45))
          else ...[
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
                              size: i == todayIdx ? 4 : 0,
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
            if (s.day == todayIdx)
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
                        s.toastMsg('Thanks. Saved for ${s.stayOwner} and the kitchen, without your name.');
                      },
                      pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      fs: 14,
                    ),
                    T('Goes to ${s.stayOwner} and the kitchen without your name.', s: 12, c: p.mu),
                  ],
                ),
              ),
          ],
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
                  onTap: s.raiseComplaint,
                ),
                T('Not fixed? Raise it again, or WhatsApp ${s.stayOwner}.', s: 12, c: p.mu),
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
                  T('${c.date} · ${c.note.isEmpty ? 'Sent to ${s.stayOwner}' : c.note}', s: 12, c: p.mu),
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
    // F21: the resident's own hostel and bed; on the server notice and swaps
    // go to the owner on WhatsApp (nothing pretends to be saved on Hostelzy).
    final h = s.stayHostel;
    final owner = s.stayOwner;
    final bed = s.myStay?.bed ?? '';
    final terms = h.terms;
    final dates = leaveDates(terms);
    final a = s.rooms[h.id] ?? const <Room>[];
    final swapBeds = <({Bed b, Room r})>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' && '${r.n}' != s.stayRoom && !b.mine && swapBeds.length < 6) swapBeds.add((b: b, r: r));
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
                      Rich([sp(context, 'Notice period is '), sp(context, '${terms.noticeDays} days', w: 800), sp(context, '. The earliest you can leave is '), sp(context, dates.first, w: 800), sp(context, '.')], s: 14, lh: 1.45),
                      const Padding(padding: EdgeInsets.only(top: 6), child: Kicker('Last day')),
                      Seg(opts: same(dates), cur: s.vDate, onPick: (v) => s.update(() => s.vDate = v), pad: const EdgeInsets.all(12), fs: 14),
                      const Padding(padding: EdgeInsets.only(top: 6), child: Kicker('Reason')),
                      wrap(6, [
                        for (final r in const ['New job', 'Moving home', 'Found another place', 'Other']) ChipBtn(r, on: r == s.vReason, onTap: () => s.update(() => s.vReason = r)),
                      ]),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16), child: Kicker('Advance refund')),
                LineRow('Advance paid', fmt(terms.advance), pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
                LineRow('Exit maintenance', '− ${fmt(terms.maintenance)}', pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
                LineRow('Refund', '${fmt(terms.refund)} within 7 days', vw: 800, pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 16)),
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
                      if (s.onServer) {
                        s.whatsapp(s.stayOwnerPhone, 'Hi $owner, this is ${s.meFirst.isEmpty ? 'your resident' : s.meFirst}${bed.isEmpty ? '' : ' from bed $bed'}. I am giving notice: my last day is ${s.vDate}.');
                      } else {
                        s.toastMsg('Notice saved. Tell $owner on WhatsApp too.');
                      }
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
                      T(s.onServer ? 'Sent to $owner on WhatsApp. They mark your bed "free soon" on Hostelzy.' : 'Saved on Hostelzy. Tell $owner on WhatsApp too. Your bed goes back on Hostelzy as "free soon".', s: 14, c: p.mu),
                      OutlineCta('Tell $owner on WhatsApp', icon: 'msg', height: 48, onTap: () => s.whatsapp(s.stayOwnerPhone, 'Hi $owner, this is ${s.meFirst.isEmpty ? 'your resident' : s.meFirst}${bed.isEmpty ? '' : ' from bed $bed'}. I am giving notice: my last day is ${s.vDate}.')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TimelineStep(t: 'Notice given', d: 'Today, ${dayMon(appToday)}', bg: p.tx, bd: p.tx),
                      TimelineStep(t: 'Room check with the warden', d: 'On ${s.vDate}, 10 am', bg: transparent, bd: p.tk),
                      TimelineStep(t: '${fmt(terms.refund)} back to your UPI', d: 'Advance minus ${fmt(terms.maintenance)} maintenance, within 7 days of leaving', bg: transparent, bd: p.tk),
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
                // F08: exit review with the advance check.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: OutlineCta('Review your stay', icon: 'star', height: 52, fs: 14, onTap: () => s.go('rExit')),
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
            child: T('Free beds in ${h.name}. Rent changes from next month.', s: 14, lh: 1.45),
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
                if (s.onServer) {
                  s.whatsapp(s.stayOwnerPhone, 'Hi $owner, this is ${s.meFirst.isEmpty ? 'your resident' : s.meFirst}${bed.isEmpty ? '' : ' from bed $bed'}. Can I move to bed ${s.swapBed}?');
                } else {
                  s.toastMsg('Swap request saved. Ask $owner on WhatsApp too.');
                }
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(bed.isEmpty ? h.name : 'Bed $bed'), const T('Move out or swap', w: 800, s: 22, lh: 1.1)]),
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

/// F06 board 7: the resident confirms what the owner added. F21 W1 (design
/// `Stay`): three plain lines and "This is correct", no fake code. On the
/// server they confirm by joining with the hostel's invite code.
class ConfirmStayScreen extends StatelessWidget {
  const ConfirmStayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final r = s.toConfirm;
    final h = s.stayHostel;
    final t = h.terms;
    if (r == null) {
      return Padding(padding: const EdgeInsets.all(16), child: T('Nothing to confirm right now.', s: 14, c: p.mu));
    }
    final owner = h.owner.trim().isEmpty ? 'your owner' : h.owner;
    final joined = r.joinAt != null ? DateTime.fromMillisecondsSinceEpoch(r.joinAt!) : appToday;
    final due = t.dueDay(joined.day);
    final done = r.confirmed;
    final lines = [
      'You live in ${h.name}, bed ${r.bed}.',
      'Rent ${fmt(r.amt)} a month, due on the ${ordinal(due)}.',
      'Advance ${fmt(r.advance)} · ${fmt(math.max(0, r.advance - t.maintenance))} back when you leave.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Bed ${r.bed}', title: done ? 'You’re confirmed' : 'Confirm your stay', size: 28))],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rConfirm${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 2, color: p.tx),
                  for (final (i, l) in lines.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 28, height: 28, alignment: Alignment.center, color: p.tx, child: T('${i + 1}', w: 800, s: 14, c: p.bg)),
                          const SizedBox(width: 10),
                          Expanded(child: T(l, s: 15, lh: 1.45)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Tap(onTap: () => s.openWA(owner, 'Hi $owner, the details you added for me on Hostelzy are not right: ', phone: s.stayOwnerPhone), child: T('Something wrong? Message $owner ›', w: 800, s: 14)),
                  ),
                  const SizedBox(height: 20),
                  if (done)
                    T('Pay rent, see the food menu and raise complaints from the app. The exit rules above are saved on Hostelzy.', s: 14, c: p.mu, lh: 1.45)
                  else ...[
                    Tap(
                      key: const ValueKey('stayAgree'),
                      onTap: () => s.update(() => s.cAgree = !s.cAgree),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: box(w: 2, c: p.tx),
                        child: Row(
                          children: [
                            Container(width: 28, height: 28, alignment: Alignment.center, decoration: box(bg: s.cAgree ? p.tx : transparent, w: 2, c: p.tx), child: s.cAgree ? Ic('check', size: 18, color: p.bg) : null),
                            const SizedBox(width: 12),
                            const Expanded(child: T('This is correct', w: 800, s: 16)),
                          ],
                        ),
                      ),
                    ),
                    if (s.onServer) Padding(padding: const EdgeInsets.only(top: 10), child: T('To confirm on Hostelzy, join with the invite code $owner gives you.', s: 12, c: p.mu, lh: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: done
              ? Cta('Go to my stay', height: 54, px: 16, fs: 15, onTap: () => s.jump('rHome', 'resident'))
              : Cta('Yes, that’s right', height: 54, px: 16, fs: 15, opacity: s.cAgree ? 1 : .4, onTap: s.confirmStay),
        ),
      ],
    );
  }
}
