import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F09 Stay Rewards: Me → Stay Rewards (board 1), the Trusted tenant badge for
// owners (2), the Member hold length (3, in the hold sheet) and the ₹100
// reward at move-in (4).

/// F09 board 1, F22 Area 2 (`rewards`): one dark status card, three steps to
/// earn, Invite a friend.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // S6: the code comes from the server, made once.
    if (s.onServer && s.serverRefCode == null) WidgetsBinding.instance.addPostFrameCallback((_) => s.loadReferralCode());
    final p = PalScope.of(context);
    final trusted = s.level == 'trusted';
    final levelName = switch (s.level) {
      'trusted' => 'Trusted tenant',
      'member' => 'Member',
      _ => 'Not a member yet',
    };
    final cardLine = !s.isMember
        ? 'off your next Hostelzy stay, once you move in through Hostelzy'
        : s.rewardUsed
        ? 'used on your first month here · 2-hour holds'
        : 'off your next Hostelzy stay · 2-hour holds${trusted ? ' · Trusted badge' : ''}';
    // S6: on the server, only rewards that were really given.
    final friends = s.friendsJoined;
    final steps = <(bool, String, String)>[
      (s.isMember, 'Move in through Hostelzy', s.isMember ? '${fmt(memberReward)} credit · ${s.memberSince}' : '${fmt(memberReward)} off your next stay, and 2-hour holds'),
      (
        trusted,
        'Pay rent on time for $trustedMonths months',
        trusted
            ? 'Trusted tenant badge · lower-advance deals'
            : [
                '${s.isMember ? s.monthsOnTime : 0} of $trustedMonths · Trusted tenant badge next',
                // What keeps you from Trusted, said plainly.
                if (s.isMember && s.lateRentMonths > 0) 'rent late in ${s.lateRentMonths} ${s.lateRentMonths == 1 ? 'month' : 'months'}',
                if (s.isMember && s.ownerComplaints > 0) '${s.ownerComplaints} complaint from the owner',
              ].join(' · '),
      ),
      (friends > 0 && s.onServer, 'Invite a friend who moves in', friends > 0 ? '$friends ${friends == 1 ? 'friend' : 'friends'} joined · ${fmt(referralReward)} each after their first month' : '${fmt(referralReward)} for each of you, after their first month'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: T('Stay Rewards', w: 800, s: 28, lh: 1.05))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rewards${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('rewardCard'),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  color: p.tx,
                  child: Css(
                    c: p.bg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Kicker(levelName, c: p.bg),
                        const SizedBox(height: 2),
                        T(s.rewardUsed ? 'Used' : fmt(memberReward), w: 800, s: 48, lh: 1.05, ls: -.03),
                        const SizedBox(height: 2),
                        T(cardLine, s: 14, lh: 1.4),
                      ],
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('How to earn')),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        Container(
                          key: ValueKey('earn-$i'),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                color: steps[i].$1 ? p.tx : p.sf,
                                child: steps[i].$1 ? Ic('check', size: 16, color: p.bg) : T('${i + 1}', w: 800, s: 15),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(steps[i].$2, w: 800, s: 16), T(steps[i].$3, s: 13, c: p.mu, lh: 1.35)])),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: OutlineCta('Invite a friend', icon: 'msg', onTap: () => s.share(s.referralText)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Rich([sp(context, 'Your code '), sp(context, s.referralCode, w: 800, c: p.tx)], s: 13, c: p.mu),
                ),
                // S6: a new tenant uses a friend's code before their first stay.
                if (s.onServer && !s.isMember && !s.referred)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Row(
                      children: [
                        Expanded(child: Field(value: s.friendCode, onChanged: (v) => s.update(() => s.friendCode = v), placeholder: 'A friend’s code, like ASHA-4K7Q')),
                        const SizedBox(width: 8),
                        Cta('Use', height: 46, px: 14, fs: 14, expand: false, gap: 8, onTap: s.useFriendCode),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// F09 board 4: what to pay at move-in, with the Member reward.
class MoveInScreen extends StatelessWidget {
  const MoveInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hold = s.holds.where((h) => h.id == s.holdId).firstOrNull ?? s.holds.lastOrNull;
    if (hold == null) return const SizedBox();
    final h = hostelById(hold.hid);
    final r = s.findBed(hold.hid, hold.bed).r!;
    final q = s.quote(hold.hid, r.ac, r.share);
    final reward = s.isMember && !s.rewardUsed ? memberReward : 0;
    final paid = hold.opt == 'book';
    final due = q.hzFirst + (paid ? 0 : q.hzAdv) - reward;
    Widget line(String k, String v, {Color? bg, Color? fg, bool bold = false}) => Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: null,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T(k, s: 14, w: bold ? 800 : 400, c: fg ?? p.mu), T(v, s: 14, w: 800, c: fg)]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · bed ${hold.bed}', title: 'Your move-in', size: 26))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('moveIn${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: box(w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))), child: line(paid ? 'Advance (paid)' : 'Advance', fmt(paid ? hold.paid : q.hzAdv))),
                      Container(decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))), child: line('First month fee', fmt(q.hzFirst))),
                      if (reward > 0)
                        Container(
                          color: p.gb,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Ic('star', size: 16, color: p.gn), const SizedBox(width: 8), T('Member reward', s: 14, w: 800, c: p.gn)]), T('− ${fmt(reward)}', s: 14, w: 800, c: p.gn)]),
                        ),
                      Container(
                        color: p.tx,
                        padding: const EdgeInsets.all(12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [T('Pay at move-in', w: 800, s: 15, c: p.bg), T(fmt(due), w: 800, s: 26, c: p.bg)]),
                      ),
                    ],
                  ),
                ),
                if (reward > 0) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('${h.owner} gives you ${fmt(reward)} off. Hostelzy credits that ${fmt(reward)} on ${h.owner}’s next Hostelzy invoice, so the hostel loses nothing.', s: 12, c: p.mu, lh: 1.45))],
                    ),
                  ),
                  const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Your reward')),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      children: [
                        KV('From', s.memberSince.contains(' at ') ? 'Your stay at ${s.memberSince.split(' at ').last}' : 'Your first stay', keyWidth: 110),
                        const KV('Used on', 'First month here', keyWidth: 110),
                        KV('Next', 'Another ${fmt(memberReward)} for your next hostel after this stay', keyWidth: 110),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 8,
            children: [
              if (hold.ref != null) T('Show ${hold.ref} at the hostel.', s: 13, w: 800),
              Cta("I've moved in · open My stay", icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.moveIn(hold)),
            ],
          ),
        ),
      ],
    );
  }
}

/// F09 board 2: what "Trusted tenant" means, for the owner.
class TrustedSheet extends StatelessWidget {
  const TrustedSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final first = s.reqs.where((r) => r.id == s.trustedReq).firstOrNull?.name.split(' ').first ?? 'They';
    Widget check(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Container(width: 18, height: 18, alignment: Alignment.center, color: p.tx, child: Ic('check', size: 12, color: p.bg)), const SizedBox(width: 8), T(t, s: 13)]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 4,
        children: [
          check('6 months in Hostelzy hostels'),
          check('Rent paid on time every month'),
          check('No complaints from owners'),
          check('Signed in to Hostelzy'),
          Padding(padding: const EdgeInsets.only(top: 10), child: T('Hostelzy checks this from real stays. We don’t share which hostels $first stayed at before.', s: 13, c: p.mu, lh: 1.45)),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Cta('Confirm hold', icon: 'check', height: 54, px: 16, fs: 15, onTap: () {
              final id = s.trustedReq;
              s.update(() {
                s.reqs = s.reqs.where((x) => x.id != id).toList();
                s.sheet = null;
              });
              s.toastMsg('Hold confirmed. Let $first know on WhatsApp.');
            }),
          ),
        ],
      ),
    );
  }
}
