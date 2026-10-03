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
      // F24 4a: opens after 30 days; the resident's own review comes back to change.
      ('star', 'Review your stay', s.myReview('30-day') != null ? 'Change your 30-day review' : s.reviewOpensOn != null ? 'Opens ${dayMon(s.reviewOpensOn!)} · after 30 days' : '30-day review', s.openReview),
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
