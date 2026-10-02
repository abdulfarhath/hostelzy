import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

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

class _Timeline extends StatelessWidget {
  const _Timeline(this.events);
  final List<CaseEvent> events;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 62, child: T(e.date, s: 12, c: p.mu)),
                Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4, right: 12), color: e.flag ? p.ad : p.tx),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(e.title, w: 800, s: 14), T(e.sub, s: 12, c: p.mu)])),
              ],
            ),
          ),
      ],
    );
  }
}

/// F07 board 1: Fair Play rules, accepted with a code (owner sign-up).
class OwnerRulesScreen extends StatelessWidget {
  const OwnerRulesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final cells = <Widget>[];
    for (var i = 0; i < 6; i++) {
      if (i > 0) cells.add(const SizedBox(width: 8));
      cells.add(
        Expanded(
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: box(w: 2, c: i == s.fpOtp.length ? p.ac : p.tx),
            child: T(i < s.fpOtp.length ? s.fpOtp[i] : '', w: 800, s: 22),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, '${hostelById(s.ownHid).name} · step 3 of 4', 'Fair Play rules', size: 30, back: s.fairAccepted),
        Expanded(
          child: Scroll(
            key: ValueKey('oRules${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: T('Tenants trust Hostelzy because every hostel plays by the same rules. Read them with your manager.', s: 14, c: p.mu, lh: 1.45),
                ),
                Container(height: 2, color: p.tx),
                for (var i = 0; i < fairRules.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 28, height: 28, alignment: Alignment.center, color: p.tx, child: T('${i + 1}', w: 800, s: 14, c: p.bg)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(fairRules[i].$1, w: 800, s: 15), const SizedBox(height: 2), T(fairRules[i].$2, s: 12, c: p.mu, lh: 1.4)])),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('If a rule is broken'), T('No fines', s: 12, w: 800)]),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: StrikeLadder()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: T('You always get 48 hours to explain. Fix a mistake in that time and there is no strike. 3 fixes in 6 months = 1 warning.', s: 12, c: p.mu, lh: 1.4),
                ),
                if (!s.fairAccepted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: VGap(
                      gap: 8,
                      children: [
                        T('Type the code sent to ${phoneSpaced(ownerPhones[s.ownHid]!)} to accept', w: 800, s: 13),
                        Stack(
                          children: [
                            Row(children: cells),
                            Positioned.fill(
                              child: Field(
                                value: s.fpOtp,
                                onChanged: (v) => s.update(() {
                                  final d = v.replaceAll(RegExp(r'\D'), '');
                                  s.fpOtp = d.length > 6 ? d.substring(0, 6) : d;
                                }),
                                numeric: true,
                                border: false,
                                height: null,
                                pad: EdgeInsets.zero,
                                hiddenText: true,
                              ),
                            ),
                          ],
                        ),
                        Tap(onTap: () => s.update(() => s.fpOtp = '553014'), child: T('Paste code from SMS', s: 12, w: 600, c: p.ad)),
                      ],
                    ),
                  )
                else
                  Padding(padding: const EdgeInsets.all(16), child: T('Accepted when you joined Hostelzy.', s: 13, w: 800)),
              ],
            ),
          ),
        ),
        if (!s.fairAccepted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Cta('I accept the Fair Play rules', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.acceptFairPlay),
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
    final phone = ownerPhones[h.id]!;
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
                Container(width: 44, height: 44, color: p.sf, alignment: Alignment.center, child: T(h.owner.substring(0, 2).toUpperCase(), w: 800)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('${h.owner}, owner', w: 800, s: 15), T('Usually replies in ~${h.reply} min', s: 12, c: p.mu)])),
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
                Expanded(child: T(held ? phoneSpaced(phone) : maskPhone(phone), w: 800, s: 15, c: held ? p.tx : p.mu)),
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
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(
                    children: [
                      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const T('Ask on WhatsApp', w: 800, s: 14), T('Saved on Hostelzy with an HZ code', s: 11, w: 600, c: p.mu)])),
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
                  Expanded(child: OutlineCta('Call', icon: 'phone', height: 44, px: 14, fs: 14, onTap: () => s.toastMsg('Calling ${h.owner} on +91 ${phoneSpaced(phone)}…'))),
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

/// F07 board 3: asked after a hold ends.
class JoinedSheet extends StatelessWidget {
  const JoinedSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          Rich([sp(context, 'You held '), sp(context, 'bed 102-B', w: 800), sp(context, ' on 11 Sep. Your answer keeps deals honest and unlocks your '), sp(context, '₹100 Member reward', w: 800, c: p.gn), sp(context, ' for your next stay.')], s: 14, lh: 1.45),
          Cta('Yes, I joined', icon: 'check', height: 54, px: 16, fs: 15, onTap: () => s.answerJoined('yes')),
          OutlineCta('No, I didn’t join', icon: 'x', height: 50, onTap: () => s.answerJoined('no')),
          OutlineCta('Still deciding', icon: 'clock', height: 50, onTap: () => s.answerJoined('later')),
          Tap(
            onTap: () => s.update(() => s.sheet = 'report'),
            child: SizedBox(height: 44, child: Row(children: [Ic('flag', size: 16, color: p.ad), const SizedBox(width: 8), T('The owner asked me to skip the app', s: 14, w: 800, c: p.ad)])),
          ),
          T('Only Hostelzy sees your answer.', s: 12, c: p.mu),
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

/// F07 board 5: the owner's case, 48 hours to explain or fix.
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
    final h = c.hoursLeft.floor(), m = ((c.hoursLeft - h) * 60).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, 'Fair Play check · ${c.id}', c.title),
        Expanded(
          child: Scroll(
            key: ValueKey('oCase${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: box(bg: open ? p.ab : p.sf, w: 2, c: open ? p.ad : p.tx),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Ic(open ? 'clock' : 'check', size: 20, color: open ? p.ad : p.tx),
                      const SizedBox(width: 10),
                      Expanded(
                        child: open
                            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('$h h $m min left to explain', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T('Reply before Sun 4 Oct, 6:40 pm. The founder reads every reply before deciding.', s: 13, lh: 1.4)])
                            : T(c.result ?? (c.status == 'decide' ? 'Reply sent. The founder is deciding.' : 'Closed'), w: 800, s: 14),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Kicker('What we saw'), T('From Hostelzy records', s: 12, w: 800, c: p.mu)]),
                ),
                Container(decoration: BoxDecoration(border: Border(top: bs(2, p.dv))), padding: const EdgeInsets.only(top: 4), child: _Timeline(c.events)),
                if (open) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 6), child: Kicker('Your side')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: VGap(
                      gap: 8,
                      children: [
                        if (c.resident != null)
                          Tap(
                            onTap: () => s.fixCase(c),
                            child: Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              color: p.ac,
                              child: Row(
                                children: [
                                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [T('Change $first to Via Hostelzy', w: 800, s: 15, c: p.ai), T('A mistake fixed within 48 h: case closed, no strike', s: 11, w: 600, c: p.ai)])),
                                  Ic('check', size: 18, color: p.ai),
                                ],
                              ),
                            ),
                          ),
                        const T('Or explain what happened', w: 800, s: 13),
                        Field(value: s.fpReply, onChanged: (v) => s.update(() => s.fpReply = v), placeholder: 'e.g. $first came through a friend before the enquiry'),
                        OutlineCta('Add a photo as proof', icon: 'plus', height: 44, fs: 14, onTap: () => s.toastMsg('Photo upload comes with the backend.')),
                      ],
                    ),
                  ),
                ] else if (c.ownerReply != null) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 6), child: Kicker('Your reply')),
                  Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12), color: p.sf, child: T('“${c.ownerReply}”', s: 14, lh: 1.5)),
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [T('You have ${s.strikes[c.hid] ?? 0} strikes', s: 12, c: p.mu), T('3 fixes in 6 months = 1 warning', s: 12, c: p.mu)]),
              if (open) Cta('Send my reply', height: 50, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: () => s.replyCase(c)) else OutlineCta('Read the Fair Play rules', height: 50, onTap: () => s.go('oRules')),
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
    final until = dayName(appToday.add(const Duration(days: 30)));
    final body = switch (n) {
      1 => 'A Fair Play case was decided against ${h.name}. This is a warning.',
      2 => 'A second case was decided against ${h.name}. Until $until, tenants see walk-in prices only.',
      _ => '${h.name} is hidden from tenants from ${dayName(appToday)}.',
    };
    final changes = switch (n) {
      1 => [('Nothing changes for now', 'Your deals and listing stay as they are'), ('Next strike hides your deals', 'For 30 days')],
      2 => [('Deals hidden until ${until.split(' ').skip(1).join(' ')}', 'You drop out of Best deals'), ('Bookings and residents work as normal', 'Holds, rent and complaints keep going'), ('A third strike removes the hostel', '')],
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
                    children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('Strikes come only from a decided case. Each case gets 48 hours for your side. No fines, ever.', s: 12, c: p.mu, lh: 1.45))],
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

/// F07 board 7: the founder's case queue. The design is a 1440 px desk
/// screen; in the app it is one column (queue, then the open case).
class AdminCasesScreen extends StatelessWidget {
  const AdminCasesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    int count(String t) => s.cases.where((c) => c.status == t).length;
    final list = s.cases.where((c) => c.status == s.adminTab).toList();
    final open = s.cases.where((c) => c.id == s.adminCase).firstOrNull;
    String tag(String st) => switch (st) {
      'new' => 'New',
      'waiting' => 'Waiting',
      'decide' => 'Decide',
      _ => 'Closed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Rich([sp(context, 'Hostelzy '), sp(context, 'admin', c: p.ac)], w: 800, s: 20),
              const SizedBox(height: 2),
              T('Fair Play cases · Strikes: 1 warning · 2 deals hidden 30 days · 3 removed. No fines.', s: 12, c: p.mu),
            ],
          ),
        ),
        Seg(
          opts: [('new', 'New ${count('new')}'), ('waiting', 'Waiting ${count('waiting')}'), ('decide', 'Decide ${count('decide')}'), ('closed', 'Closed')],
          cur: s.adminTab,
          onPick: (v) => s.update(() {
            s.adminTab = v;
            s.adminCase = null;
          }),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          center: true,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(
              key: ValueKey('aCases${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in list) ...[
                    Tap(
                      onTap: () => s.update(() => s.adminCase = s.adminCase == c.id ? null : c.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(color: c.id == s.adminCase ? p.ab : null, border: Border(bottom: bs(1, p.hl))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [Expanded(child: T('${c.id} · ${hostelById(c.hid).name}', w: 800, s: 14)), Container(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7), decoration: box(bg: c.status == 'decide' ? p.ab : transparent, w: 1, c: c.status == 'decide' ? p.ab : p.dv), child: T(tag(c.status), s: 11, w: 800, ls: .05, upper: true, c: c.status == 'decide' ? p.ad : p.mu))]),
                            const SizedBox(height: 4),
                            T(c.result ?? c.signal, s: 13, c: p.mu),
                          ],
                        ),
                      ),
                    ),
                    if (open == c) _AdminCase(c),
                  ],
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('No cases here.', s: 14, c: p.mu)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminCase extends StatelessWidget {
  const _AdminCase(this.c);
  final FairCase c;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(c.hid);
    final n = (s.strikes[c.hid] ?? 0) + 1;
    final residents = c.hid == 'anjani' ? s.residents : const <Resident>[];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: T('${h.name}: ${c.title}', w: 800, s: 20, lh: 1.1)),
          if (c.events.isNotEmpty) ...[const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Kicker('Signals')), _Timeline(c.events)],
          const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 6), child: Kicker('Owner’s reply')),
          Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12), color: p.sf, child: T(c.ownerReply != null ? '“${c.ownerReply}”' : 'No reply yet. 48 hours from the notice.', s: 14, lh: 1.5)),
          if (c.tenantNote != null) ...[
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: Kicker('Tenant')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: T('“${c.tenantNote}”', s: 14, w: 800, lh: 1.5)),
          ],
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: Kicker('Owner history')),
          for (final (k, v) in [('Strikes', '${s.strikes[c.hid] ?? 0} of 3'), ('Live since', '1 Oct 2026'), if (residents.isNotEmpty) ('Residents', '${residents.length} · ${residents.where((r) => r.via == 'hz').length} via Hostelzy')])
            KV(k, v, keyWidth: 110),
          Padding(
            padding: const EdgeInsets.all(16),
            child: T('Decide only after the 48-hour window or the owner’s reply. A proven fake “Direct” for an app tenant is one strike. The tenant’s answer and our records outweigh messages and screenshots.', s: 12, c: p.mu, lh: 1.5),
          ),
          if (c.status != 'closed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VGap(
                gap: 8,
                children: [
                  OutlineCta('Close · no issue', icon: 'check', height: 50, onTap: () => s.decideCase(c, 'close')),
                  OutlineCta('Ask for more', icon: 'msg', height: 50, onTap: () => s.decideCase(c, 'more')),
                  Cta('Strike $n · ${strikeLadder[(n - 1).clamp(0, 2)].$2.toLowerCase()}', icon: 'flag', height: 50, px: 16, fs: 15, onTap: () => s.decideCase(c, 'strike')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
