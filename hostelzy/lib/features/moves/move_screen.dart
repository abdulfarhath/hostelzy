import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

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
      bar = OutlineCta(s.myReview('exit') != null ? 'Change your exit review' : 'Review your stay', icon: 'star', fs: 14, onTap: s.openExitReview);
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
