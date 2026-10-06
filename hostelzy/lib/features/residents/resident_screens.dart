import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../reminders/reminders_screens.dart';

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
    final rentAmt = s.myRentPay?.amt ?? (st == null ? 0 : st.rent + s.myElectricity);
    // F21 W3: three actions right under the rent card. Notice, swap and room
    // layouts live in the My stay tab (F26 #14).
    final quick = <(String, String, VoidCallback)>[
      ('Pay rent', 'wallet', () => s.tab('rPay')),
      ('Raise complaint', 'wrench', () => s.update(() => s.sheet = 'complaint')),
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
                Expanded(child: PageHead(kicker: st == null ? 'Your stay' : s.stayLine, title: s.meFirst.isEmpty ? 'Hello' : 'Hello, ${s.meFirst}')),
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
          // F08: the 30-day review (one per stay), once 30 days in (F24 4a).
          if (s.myReview('30-day') == null && s.reviewOpensOn == null)
            Tap(
              onTap: s.openReview,
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
          // F26 #4 #13: the whole week, always open, today highlighted.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(child: Kicker('Food this week')),
                if (s.menuOf(h.id) != null) Flexible(child: T('From ${owner == 'your owner' ? 'your owner' : '$owner’s'} menu', s: 12, c: p.mu, align: TextAlign.right)),
              ],
            ),
          ),
          if (s.menuOf(h.id) == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
              child: T('${owner == 'your owner' ? 'Your owner' : owner} hasn’t put the menu on Hostelzy yet.', s: 14, c: p.mu),
            )
          else ...[
            HomeWeek(hid: h.id),
            // The owner's breakfast ratings come from here now that Food is gone.
            Container(
              key: const ValueKey('rateBreakfast'),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: box(w: 2, c: p.tx),
              child: VGap(
                gap: 8,
                children: [
                  const T('How was breakfast?', w: 800, s: 15),
                  Seg(opts: same(['Good', 'Okay', 'Poor']), cur: s.rated, onPick: (v) => s.rateMeal('b', v), pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12), fs: 14, center: true, dividers: true),
                  T('$owner sees how many said each, never your name.', s: 13, c: p.mu),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
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

/// F26 #4 #13: Monday–Sunday × breakfast / lunch / dinner, all on screen,
/// today's row highlighted. The lead may swap in the shared food week table.
class HomeWeek extends StatelessWidget {
  const HomeWeek({super.key, required this.hid});
  final String hid;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final week = s.menuOf(hid) ?? blankWeek;
    final days = weekDays;
    Widget cell(String t, {bool head = false, bool today = false, double? width}) {
      final c = Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(border: Border(left: width == null ? bs(1, p.hl) : BorderSide.none)),
        child: T(t, s: head ? 11 : 12, w: head || today ? 800 : 400, lh: 1.3, c: head ? p.mu : (today ? p.ad : p.tx)),
      );
      return width == null ? Expanded(child: c) : SizedBox(width: width, child: c);
    }
    return Container(
      key: const ValueKey('homeWeek'),
      decoration: BoxDecoration(border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cell('', head: true, width: 58),
                  for (final m in meals) cell('${m[1]} · ${s.mealTimeText(hid, m[0]).split(' – ').first}', head: true),
                ],
              ),
            ),
          ),
          for (var i = 0; i < week.length; i++)
            Container(
              key: i == todayIdx ? const ValueKey('weekToday') : null,
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(color: i == todayIdx ? p.ab : null, border: Border(bottom: bs(1, p.hl))),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cell(i == todayIdx ? '${days[i][0]} · today' : days[i][0], today: i == todayIdx, width: 58),
                    cell(week[i].b),
                    cell(week[i].l),
                    cell(week[i].n),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// F26 #14 (board `f26-stay`): the My stay tab. The bed, the things a
/// resident does once in a while (move, notice, refund, review, layout fix),
/// then Help (the old Help tab folds in here as two sheets).
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
    final mine = s.complaints.where((c) => c.mine).toList().reversed.toList();
    final fixing = mine.where((c) => c.status == 'In progress').length, sent = mine.where((c) => c.status == 'Open').length;
    final openOne = mine.where((c) => c.status == 'Open' || c.status == 'In progress').firstOrNull;
    void move(String t) => s.update(() {
      s.hist = [...s.hist, s.screen];
      s.screen = 'move';
      s.sheet = null;
      s.moveTab = t;
    });
    final bedRows = <(String, String, String, VoidCallback?, bool)>[
      ('swap', 'Move to another bed', free == 0 ? 'No free beds right now' : '$free free bed${free == 1 ? '' : 's'} here', () => move('swap'), false),
      ('logout', 'Give notice', '${terms.noticeDays} days · earliest last day ${leaveDates(terms).first}', () => move('vacate'), false),
      // F24: an advance refund still open after moving out; else what comes back.
      if (s.myRefund case final r?)
        ('wallet', 'Your refund', '${fmt(r.amt)} · ${r.status == 'sent' ? 'did it arrive?' : r.status == 'not_received' ? 'not received' : 'due ${dayMon(r.due)}'}', s.openMyRefund, false)
      else if (advance > 0)
        ('wallet', 'Your refund', '${fmt(math.max(0, advance - terms.maintenance))} back when you leave', null, false),
      // F24 4a: opens after 30 days; the resident's own review comes back to change.
      ('star', 'Review your stay', s.myReview('30-day') != null ? 'Change your 30-day review' : s.reviewOpensOn != null ? 'Opens ${dayMon(s.reviewOpensOn!)} · after 30 days' : '30-day review', s.openReview, false),
      ('pencil', 'Fix a room layout', 'Any room in ${h.name}', () => s.openFixRoom(s.myRoomLabel.isEmpty ? (s.rooms[h.id]?.first.n ?? 101) : int.tryParse(s.myRoomLabel) ?? 101), false),
    ];
    final helpRows = <(String, String, String, VoidCallback?, bool)>[
      ('wrench', 'Something wrong in your room?', 'Wi-Fi, water, electricity, cleaning, food', () => s.update(() => s.sheet = 'complaint'), false),
      (
        'msg',
        'Your complaints',
        mine.isEmpty ? 'None yet' : openOne == null ? 'All fixed' : [if (fixing > 0) '$fixing being fixed', if (sent > 0) '$sent sent', openOne.cat].join(' · '),
        () => s.update(() => s.sheet = 'complaints'),
        openOne != null,
      ),
    ];
    Widget row((String, String, String, VoidCallback?, bool) r) {
      final body = Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: Row(
          children: [
            Container(width: 36, height: 36, color: p.sf, alignment: Alignment.center, child: Ic(r.$1, size: 18, color: p.tx)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [T(r.$2, w: 800, s: 16), T(r.$3, s: 13, c: r.$5 ? p.ad : p.mu, w: r.$5 ? 600 : 400)],
              ),
            ),
            if (r.$4 != null) Ic('chev', size: 16, color: p.mu),
          ],
        ),
      );
      return r.$4 == null ? body : Tap(key: ValueKey('stay-${r.$2}'), onTap: r.$4, child: body);
    }
    Widget kicker(String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker(t));
    return Scroll(
      key: ValueKey('rStay${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: PageHead(kicker: h.name, title: 'My stay'),
          ),
          if (st == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: T('Your stay isn’t on Hostelzy yet. Once ${s.stayOwner} adds you, it shows here.', s: 14, c: p.mu, lh: 1.45),
            )
          else
            Container(
              key: const ValueKey('stayCard'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
          kicker('Your bed'),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in bedRows) row(r)]),
          ),
          kicker('Help'),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in helpRows) row(r)]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
