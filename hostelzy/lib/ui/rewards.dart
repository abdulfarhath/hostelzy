import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F09 Stay Rewards: Me → Stay Rewards (board 1), the Trusted tenant badge for
// owners (2), the Member hold length (3, in the hold sheet) and the ₹100
// reward at move-in (4).

class _Perk extends StatelessWidget {
  const _Perk(this.title, this.sub, {this.amt, this.tag});
  final String title, sub;
  final String? amt, tag;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(title, w: 800, s: 15), const SizedBox(height: 2), T(sub, s: 12, c: p.mu, lh: 1.35)])),
          if (amt != null) T(amt!, w: 800, s: 18, c: p.gn),
          if (tag != null) Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7), child: T(tag!, s: 11, w: 800, ls: .05, upper: true, c: p.bg)),
        ],
      ),
    );
  }
}

/// F09 board 1: Me → Stay Rewards.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final levelName = switch (s.level) {
      'trusted' => 'Trusted tenant',
      'member' => 'Member',
      _ => 'Not a member yet',
    };
    Widget check(bool on, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 18, height: 18, alignment: Alignment.center, decoration: box(bg: on ? p.tx : transparent, w: 2, c: p.tx), child: on ? Ic('check', size: 12, color: p.bg) : null),
          const SizedBox(width: 8),
          Expanded(child: T(t, s: 13)),
        ],
      ),
    );
    final perks = switch (s.level) {
      'trusted' => [
        const _Perk('Badge owners see', 'On your holds and enquiries', tag: 'Trusted'),
        const _Perk('Lower-advance deals', 'From owners who offer them to trusted tenants'),
        const _Perk('First look at free beds', 'Before everyone else'),
        _Perk('${fmt(memberReward)} off your next hostel', 'First month', amt: fmt(memberReward)),
        const _Perk('2-hour free holds', 'Everyone else gets 1 hour'),
      ],
      'member' => [
        _Perk('${fmt(memberReward)} off your next hostel', s.rewardUsed ? 'Used on your first month here' : 'First month at your next Hostelzy hostel', amt: fmt(memberReward)),
        const _Perk('2-hour free holds', 'Everyone else gets 1 hour'),
      ],
      _ => [
        _Perk('${fmt(memberReward)} off your next hostel', 'After your first stay through Hostelzy', amt: fmt(memberReward)),
        const _Perk('2-hour free holds', 'Instead of 1 hour'),
        const _Perk('Trusted tenant after 6 months', 'Badge, lower-advance deals, first look at free beds'),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: PageHead(kicker: 'Rahul Varma · Me', title: 'Stay Rewards', size: 28))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('rewards${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: box(bg: s.isMember ? p.tx : transparent, w: 2, c: p.tx),
                  child: Css(
                    c: s.isMember ? p.bg : p.tx,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Kicker('Your level', c: s.isMember ? p.bg : p.mu),
                        const SizedBox(height: 4),
                        T(levelName, w: 800, s: 28, lh: 1.05),
                        const SizedBox(height: 4),
                        T(s.isMember ? s.memberSince : 'Join a hostel through Hostelzy to become a Member', s: 13),
                      ],
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker(s.isMember ? 'Your perks' : 'What you get')),
                Container(decoration: BoxDecoration(border: Border(top: bs(2, p.dv))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: perks)),
                if (s.level == 'member') ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('Trusted tenant'), T('${s.monthsOnTime} of $trustedMonths months', s: 12, w: 800)]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 10, decoration: box(w: 2, c: p.tx), child: LayoutBuilder(builder: (context, c) => Row(children: [Container(width: c.maxWidth * s.monthsOnTime / trustedMonths, color: p.tx)]))),
                        const SizedBox(height: 8),
                        check(s.lateRentMonths == 0, s.lateRentMonths == 0 ? 'Rent paid on time · ${s.monthsOnTime} of ${s.monthsOnTime} months' : 'Rent late in ${s.lateRentMonths} of ${s.monthsOnTime} months'),
                        check(s.ownerComplaints == 0, s.ownerComplaints == 0 ? 'No complaints from the owner' : '${s.ownerComplaints} complaint from the owner'),
                        check(false, '$trustedMonths months in a Hostelzy hostel · ${trustedMonths - s.monthsOnTime} to go'),
                        const SizedBox(height: 4),
                        T('Then: a badge owners see, lower-advance deals and first look at newly free beds.', s: 12, c: p.mu, lh: 1.4),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('Invite a friend'), T('${fmt(referralReward)} each', s: 12, w: 800, c: p.gn)]),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Kicker('Your code'), T(s.referralCode, w: 800, s: 22, ls: .04)])),
                      Cta('Share', icon: 'msg', height: 44, px: 14, fs: 14, expand: false, gap: 10, bg: p.tx, fg: p.bg, onTap: () => s.share(s.referralText)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Rich([sp(context, 'You both get ${fmt(referralReward)} after your friend’s first month. '), sp(context, '${s.friendsJoined} friend joined · ${fmt(referralReward)} on the way.', w: 800, c: p.tx)], s: 12, c: p.mu, lh: 1.45),
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
          check('Phone verified by OTP'),
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
