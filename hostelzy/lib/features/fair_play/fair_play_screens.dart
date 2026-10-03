import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F07 Fair Play: the owner's rules (board 1), the owner's number after a hold
// (2), "Did you join?" (3), the tenant's report (4), the owner's case (5),
// strike notices (6) and the founder's case queue (7).

Widget _head(BuildContext context, String kicker, String title, {double size = 24, bool back = true}) {
  final s = AppScope.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [if (back) ...[BackBtn(onTap: s.back), const SizedBox(width: 12)], Expanded(child: PageHead(kicker: kicker, title: title, size: size))],
    ),
  );
}

/// The three-step strike ladder; steps up to [filled] are marked.
class StrikeLadder extends StatelessWidget {
  const StrikeLadder({super.key, this.filled = 0});
  final int filled;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      color: p.tx,
      padding: const EdgeInsets.all(2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: i < filled ? p.ad : p.bg,
                  child: Css(
                    c: i < filled ? p.ai : p.tx,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [T(strikeLadder[i].$1, s: 12, w: 800), T(strikeLadder[i].$2, s: 15, w: 800), T(strikeLadder[i].$3, s: 11)],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// F07 board 1: Fair Play rules. F21 W1 (design `Agree`): a new owner sees
/// three plain rules and ticks "I agree" (no SMS code: nothing sends one);
/// the full rules and strike ladder open from the link and from Settings.
class OwnerRulesScreen extends StatelessWidget {
  const OwnerRulesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hostel = hostelById(s.ownHid).name;
    Widget numbered(int i, Widget body) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 28, height: 28, alignment: Alignment.center, color: p.tx, child: T('$i', w: 800, s: 14, c: p.bg)),
          const SizedBox(width: 10),
          Expanded(child: body),
        ],
      ),
    );
    if (!s.fairAccepted && !s.fpFull) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, '$hostel · before you go live', 'Fair Play rules', size: 28, back: s.hist.isNotEmpty),
          Expanded(
            child: Scroll(
              key: ValueKey('oRules${s.scrollEpoch}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 2, color: p.tx),
                    for (final (i, r) in fairBasics.indexed) numbered(i + 1, T(r, s: 15, lh: 1.45)),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: Tap(onTap: () => s.update(() => s.fpFull = true), child: const T('Full rules: Settings → Fair Play ›', w: 800, s: 14))),
                    const SizedBox(height: 20),
                    Tap(
                      key: const ValueKey('fpAgree'),
                      onTap: () => s.update(() => s.fpAgree = !s.fpAgree),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: box(w: 2, c: p.tx),
                        child: Row(
                          children: [
                            Container(width: 28, height: 28, alignment: Alignment.center, decoration: box(bg: s.fpAgree ? p.tx : transparent, w: 2, c: p.tx), child: s.fpAgree ? Ic('check', size: 18, color: p.bg) : null),
                            const SizedBox(width: 12),
                            const Expanded(child: T('I agree', w: 800, s: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Cta('Agree and continue', height: 54, px: 16, fs: 15, opacity: s.fpAgree ? 1 : .4, onTap: s.acceptFairPlay),
          ),
        ],
      );
    }
    // The full rules: from the link above (before agreeing) or from Settings.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.fairAccepted ? s.back : () => s.update(() => s.fpFull = false)),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: s.fairAccepted ? '$hostel · Settings' : '$hostel · before you go live', title: 'Fair Play rules', size: 28)),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('oRulesFull${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: T('Tenants trust Hostelzy because every hostel plays by the same rules. Read them with your manager.', s: 14, c: p.mu, lh: 1.45),
                ),
                Container(height: 2, color: p.tx),
                for (var i = 0; i < fairRules.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: numbered(i + 1, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(fairRules[i].$1, w: 800, s: 15), const SizedBox(height: 2), T(fairRules[i].$2, s: 12, c: p.mu, lh: 1.4)])),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Kicker('If a rule is broken'), T('No fines', s: 12, w: 800)]),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: StrikeLadder()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: T('You always get 48 hours to explain. Fix a mistake in that time and there is no strike. 3 fixes in 6 months = 1 warning.', s: 12, c: p.mu, lh: 1.4),
                ),
                if (s.fairAccepted) const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: T('Accepted when you joined Hostelzy.', s: 13, w: 800)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// F07 board 2: the owner on the hostel page. The number shows only after a
/// hold; until then the tenant enquires through Hostelzy (F05).
class OwnerContact extends StatelessWidget {
  const OwnerContact(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final held = s.heldAt(h.id);
    final hold = s.holds.where((x) => x.hid == h.id && x.status != 'released').lastOrNull;
    final phone = ownerPhones[h.id] ?? '';
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: box(w: 2, c: p.tx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: 44, height: 44, color: p.sf, alignment: Alignment.center, child: T(initials(h.owner.isEmpty ? h.name : h.owner), w: 800)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('${h.owner}, owner', w: 800, s: 15), T(s.replyMins(h.id) == 0 ? 'Replies through Hostelzy' : 'Usually replies in ~${replyWords(s.replyMins(h.id))}', s: 12, c: p.mu)])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
            child: Row(
              children: [
                Ic(held ? 'phone' : 'lock', size: 16, color: held ? p.tx : p.mu),
                const SizedBox(width: 8),
                Expanded(child: T(held ? (phone.isEmpty ? 'Number not added yet' : phoneSpaced(phone)) : maskPhone(phone), w: 800, s: 15, c: held && phone.isNotEmpty ? p.tx : p.mu)),
                if (held && hold != null)
                  Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7), child: T('You held ${hold.bed}', s: 11, w: 800, ls: .05, upper: true, c: p.bg))
                else
                  T('Shows after a hold', s: 12, c: p.mu),
              ],
            ),
          ),
          if (!held) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Rich([sp(context, 'Owner’s number shows after you hold a bed.', w: 800), sp(context, ' Talking through Hostelzy keeps your deal and your ₹100 reward.')], s: 13, lh: 1.45),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Tap(
                onTap: () => s.enquire(h.id, 'Hi ${h.owner}, I found ${h.name} on Hostelzy. Can I come and see the rooms this evening?', from: 'Hostel page · Ask on WhatsApp'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(
                    children: [
                      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const T('Ask on WhatsApp', w: 800, s: 14), T('Saved on Hostelzy with a booking code', s: 11, w: 600, c: p.mu)])),
                      const Ic('msg', size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(child: OutlineCta('Call', icon: 'phone', height: 44, px: 14, fs: 14, onTap: () => s.call(phone))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlineCta('WhatsApp', icon: 'msg', height: 44, px: 14, fs: 14, onTap: () => s.enquire(h.id, 'Hi ${h.owner}, I held bed ${hold?.bed} at ${h.name} on Hostelzy.', bed: hold?.bed, from: 'Hold · WhatsApp owner'))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// F07 board 4: a private report.
class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const opts = ['Asked me to pay without Hostelzy', 'Offered a lower price to skip the app', 'Asked me to cancel my hold', 'Something else'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 8,
        children: [
          for (final o in opts)
            Tap(
              onTap: () => s.update(() => s.reportWhy = o),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: box(bg: s.reportWhy == o ? p.sf : transparent, w: s.reportWhy == o ? 2 : 1, c: s.reportWhy == o ? p.tx : p.dv),
                child: Row(
                  children: [
                    Container(width: 18, height: 18, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: Container(width: 8, height: 8, color: s.reportWhy == o ? p.tx : transparent)),
                    const SizedBox(width: 12),
                    Expanded(child: T(o, s: 14, w: 600)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          const T('What happened? (optional)', w: 800, s: 13),
          Field(value: s.reportNote, onChanged: (v) => s.update(() => s.reportNote = v), placeholder: 'e.g. Said I would save ₹500 if I paid cash'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Ic('shield', size: 16, color: p.mu)),
              const SizedBox(width: 8),
              Expanded(child: T('The owner never sees your name. We check our own records first, and you keep your deal and reward either way.', s: 12, c: p.mu, lh: 1.45)),
            ],
          ),
          Cta('Send report', height: 54, px: 16, fs: 15, onTap: s.sendReport),
        ],
      ),
    );
  }
}

/// F07 board 5, F22 Area 3 `oCase`: the Fair Play check. A banner with the
/// real time left, what happened (flagged steps in red), the owner's reply,
/// and "Send my reply" / "Change … to “Came from the app”".
class OwnerCaseScreen extends StatelessWidget {
  const OwnerCaseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final c = s.ownerCase ?? s.cases.where((x) => x.hid == s.ownHid).firstOrNull;
    if (c == null) return Column(children: [_head(context, 'Fair Play', 'No open cases')]);
    final open = c.status == 'waiting' || c.status == 'new';
    final first = c.resident?.split(' ').first ?? 'them';
    final left = c.hoursLeftAt(s.now);
    final hrs = left.floor(), mins = (left * 60).floor();
    final within = hrs >= 1 ? '$hrs hour${hrs == 1 ? '' : 's'}' : '$mins minute${mins == 1 ? '' : 's'}';
    final n = s.strikes[c.hid] ?? 0;
    final by = DateTime.fromMillisecondsSinceEpoch(s.now + (left * 3600000).round());
    final byTxt = '${dayName(by)}, ${by.hour % 12 == 0 ? 12 : by.hour % 12}:${by.minute.toString().padLeft(2, '0')} ${by.hour < 12 ? 'am' : 'pm'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${c.id} · ${hostelById(c.hid).name}', 'Fair Play check', size: 30),
        Expanded(
          child: Scroll(
            key: ValueKey('oCase${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('caseBanner'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: box(bg: open ? p.ab : p.sf, w: 2, c: open ? p.ad : p.tx),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Ic(open ? 'clock' : 'check', size: 20, color: open ? p.ad : p.tx),
                      const SizedBox(width: 10),
                      Expanded(
                        child: open
                            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(left <= 0 ? 'The 48 hours are over' : 'Reply within $within', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(left <= 0 ? 'You can still reply. The Hostelzy team decides.' : 'Explain or fix it by $byTxt. The Hostelzy team reads every reply before deciding.', s: 13, lh: 1.4)])
                            : T(c.result ?? (c.status == 'decide' ? 'Reply saved. The Hostelzy team decides.' : 'Closed'), w: 800, s: 14),
                      ),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: T(c.title, w: 800, s: 17, lh: 1.3)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: T('What happened, from Hostelzy records:', s: 13, c: p.mu)),
                for (final e in c.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 52, child: T(e.date, s: 13, c: p.mu)),
                        const SizedBox(width: 10),
                        Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), color: e.flag ? p.ad : p.tx),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(e.title, w: 800, s: 15), T(e.sub, s: 13, c: p.mu)])),
                      ],
                    ),
                  ),
                // F24 #18 (board `oCasePhoto`): the tenant's photo proof.
                if (c.tenantPhoto != null) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Kicker('Photo from $first', c: p.mu)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Semantics(
                          label: 'Open the photo from $first',
                          button: true,
                          child: Tap(
                            key: const ValueKey('casePhoto'),
                            onTap: () => s.openCasePhoto(c.tenantPhoto),
                            child: Container(
                              width: 96,
                              height: 72,
                              padding: const EdgeInsets.all(6),
                              alignment: Alignment.bottomLeft,
                              decoration: box(bg: p.sf, w: 1, c: p.hl),
                              child: Row(children: [Ic('camera', size: 14, color: p.mu), const SizedBox(width: 4), Flexible(child: T('Open', s: 11, w: 800, c: p.mu, ell: true))]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: T('Shown only to you and the Hostelzy team.', s: 13, c: p.mu, lh: 1.45)),
                      ],
                    ),
                  ),
                ],
                if (open)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: VGap(
                      gap: 8,
                      children: [
                        Semantics(
                          label: 'Your reply',
                          child: Field(key: const ValueKey('caseReply'), value: s.fpReply, onChanged: (v) => s.update(() => s.fpReply = v), placeholder: 'Your side, in a line or two', maxLines: 2, height: null, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
                        ),
                        OutlineCta(s.fpPhoto != null ? 'Photo added · change it' : c.ownerPhoto != null ? 'Photo sent · add another' : 'Add a photo to your reply', key: const ValueKey('casePhotoAdd'), icon: 'camera', height: 44, fs: 14, onTap: s.pickCasePhoto),
                      ],
                    ),
                  )
                else if (c.ownerReply != null) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 6), child: Kicker('Your reply')),
                  Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12), color: p.sf, child: T('“${c.ownerReply}”', s: 14, lh: 1.5)),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: T('You have $n strike${n == 1 ? '' : 's'}. ${open && c.resident != null ? 'A mistake fixed within 48 hours closes the case with no strike; 3 fixes in 6 months = 1 warning.' : '3 fixes in 6 months = 1 warning.'}', s: 13, c: p.mu, lh: 1.4),
                ),
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
              if (open) ...[
                Cta('Send my reply', height: 54, px: 16, fs: 15, onTap: () => s.replyCase(c)),
                if (c.resident != null) OutlineCta('Change $first to “Came from the app”', icon: 'check', onTap: () => s.fixCase(c)),
              ] else
                OutlineCta('Read the Fair Play rules', onTap: () => s.go('oRules')),
            ],
          ),
        ),
      ],
    );
  }
}

/// F07 board 6: what a strike means, for the owner.
class StrikeScreen extends StatelessWidget {
  const StrikeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final n = (s.strikes[h.id] ?? 0).clamp(1, 3);
    final title = switch (n) {
      1 => 'Warning: strike 1 of 3',
      2 => 'Strike 2 of 3: deals hidden for 30 days',
      _ => 'Strike 3 of 3: removed from Hostelzy',
    };
    // F24 #18: strike 2's 30 days run from the day it was given (server).
    final backOn = s.dealsBackOn(h.id) ?? appToday.add(const Duration(days: 30));
    final back = !DateTime.now().isBefore(backOn);
    final until = dayName(backOn);
    final fixes = s.strikeFromFixes(h.id);
    final body = switch (n) {
      1 => fixes ? '${h.name} fixed 3 cases within 48 hours in 6 months. Three fixes count as one warning.' : 'A Fair Play case was decided against ${h.name}. This is a warning.',
      2 when back => 'Your 30 days of hidden deals ended on $until. Tenants see your deals again. Strikes still count: a third removes the hostel.',
      2 => '${fixes ? '3 fixes in 6 months count as a strike.' : 'A second case was decided against ${h.name}.'} Until $until, tenants see walk-in prices only.',
      _ => '${h.name} is hidden from tenants. Talk to the Hostelzy team about the case.',
    };
    final changes = switch (n) {
      1 => [('Nothing changes for now', 'Your deals and listing stay as they are'), ('Next strike hides your deals', 'For 30 days')],
      2 when back => [('Deals back since ${dayMon(backOn)}', 'You’re in Best deals again'), ('A third strike removes the hostel', '')],
      2 => [('Deals hidden until ${dayMon(backOn)}', 'You drop out of Best deals'), ('Bookings and residents work as normal', 'Holds, rent and complaints keep going'), ('A third strike removes the hostel', '')],
      _ => [('Listing hidden', 'No new enquiries, holds or bookings'), ('Residents keep their records', 'Stay history and receipts stay available to them'), ('Your plan stops', 'No more invoices')],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${h.name} · Fair Play', title),
        Expanded(
          child: Scroll(
            key: ValueKey('oStrike${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: StrikeLadder(filled: n)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: T(body, s: 14, lh: 1.5)),
                const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6), child: Kicker('What changes')),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in changes)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(c.$1, w: 800, s: 15), if (c.$2.isNotEmpty) T(c.$2, s: 12, c: p.mu)]),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('Strikes come from a decided case, or from 3 fixes in 6 months (one warning). Each case gets 48 hours for your side. No fines, ever.', s: 12, c: p.mu, lh: 1.45))],
                  ),
                ),
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
              OutlineCta('See the case', icon: 'chev', height: 50, onTap: () => s.go('oCase')),
              Cta('Reply to Hostelzy', icon: 'msg', height: 50, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: () => s.openWA('Hostelzy Fair Play', 'Hi Hostelzy, about my Fair Play case: ')),
            ],
          ),
        ),
      ],
    );
  }
}
