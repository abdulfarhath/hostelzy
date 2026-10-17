import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../explore/explore_screen.dart';
import 'hold_steps.dart';

// ------------------------------------------------------------ map



// ------------------------------------------------------------ holds

({Hostel hh, Room r, double left}) holdInfo(AppState s, Hold h) {
  final hh = hostelById(h.hid);
  final r = s.findBed(h.hid, h.bed).r!;
  final secs = s.holdSecsOf(h);
  return (hh: hh, r: r, left: secs - (s.now - h.start) / 1000);
}

class HoldsScreen extends StatelessWidget {
  const HoldsScreen({super.key, this.bare = false});

  /// F26 #17: inside Saved & Holds, without its own title.
  final bool bare;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const lab = {'waiting': 'Waiting for owner', 'confirmed': 'Held', 'held': 'Held', 'paying': 'Waiting for owner', 'booked': 'Booked', 'released': 'Released'};
    return Scroll(
      key: ValueKey('holds${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!bare)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
              child: const T('Holds', s: 30, w: 800, lh: 1.02, ls: -.025),
            ),
          // F21 W4: an inline error with Retry, never a silent empty list.
          if (s.liveFailed && s.onServer) InlineError('Couldn’t load your holds', onRetry: s.refreshLive),
          // F22 Area 1: one list; "Did you join …?" is asked right here (F07).
          for (final h in s.holds.reversed.where((h) => !s.releasing.contains(h.id)))
            () {
              final i = holdInfo(s, h);
              final timed = const ['waiting', 'confirmed', 'held'].contains(h.status);
              final ended = s.expiredHolds.contains(h.id) || h.status == 'released';
              // F26 #9: the owner said no: Declined, not Released.
              final tag = ended ? (h.declined ? 'Declined' : h.status == 'released' ? 'Released' : 'Ended') : (lab[h.status] ?? h.status);
              final steps = HoldSteps.shows(s, h);
              final row = Tap(
                key: ValueKey('holdRow-${h.id}'),
                onTap: () => s.update(() {
                  s.hist = [...s.hist, s.screen];
                  s.screen = 'hold';
                  s.sheet = null;
                  s.holdId = h.id;
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tag(tag, bg: ended ? p.sf : (h.status == 'booked' ? p.gb : p.ab), fg: ended ? p.mu : (h.status == 'booked' ? p.gn : p.ad)),
                            const SizedBox(height: 6),
                            T('Bed ${h.bed}', w: 800, s: 18),
                            const SizedBox(height: 2),
                            T('${i.hh.name} · ${fmt(i.r.rent)}/mo${h.ref == null ? '' : ' · ${h.ref}'}', s: 13, c: p.mu),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (timed && !ended)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Ticking((context) => T(cd(holdInfo(s, h).left), w: 800, s: 22, tab: true)), T('left', s: 12, c: p.mu)])
                      else
                        Ic('chev', size: 18, color: p.mu),
                    ],
                  ),
                ),
              );
              if (!steps) return row;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: box(w: 2, c: p.tx),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [row, HoldSteps(h)]),
              );
            }(),
          // Only about a real ended hold; the demo build may show a sample one.
          if (s.askJoined)
            Container(
              key: const ValueKey('joinedAsk'),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: box(w: 2, c: p.tx),
              child: VGap(
                gap: 8,
                children: [
                  T('Did you join ${hostelById(s.endedHold?.hid ?? 'anjani').name}?', w: 800, s: 17),
                  T('Your hold on bed ${s.endedHold?.bed ?? '102-B'} ended. One tap helps us keep owners fair.${s.onServer ? ' If you joined, your ₹100 Member reward unlocks once the owner confirms your stay.' : ' A yes unlocks your ₹100 Member reward.'}', s: 13, c: p.mu, lh: 1.4),
                  // F07 / F24 item 14: Yes / Not yet / Still deciding.
                  Cta('Yes, I joined', icon: 'check', height: 46, px: 14, fs: 14, onTap: () => s.answerJoined('yes')),
                  Row(
                    children: [
                      Expanded(child: OutlineCta('Not yet', icon: 'x', height: 46, fs: 14, onTap: () => s.answerJoined('not_yet'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlineCta('Still deciding', icon: 'clock', height: 46, fs: 14, onTap: () => s.answerJoined('deciding'))),
                    ],
                  ),
                  if (s.onServer) T('Only the Hostelzy team sees your answer, never the owner.', s: 12, c: p.mu, lh: 1.4),
                  Tap(onTap: () => s.update(() => s.sheet = 'report'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: T('The owner asked me to skip the app ›', s: 13, w: 800, c: p.ad))),
                ],
              ),
            ),
          if (s.holds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Container(width: 64, height: 64, alignment: Alignment.center, color: p.sf, child: const Ic('clock', size: 30)),
                  const SizedBox(height: 12),
                  const T('No holds yet', w: 800, s: 22, align: TextAlign.center),
                  const SizedBox(height: 8),
                  T('Hold any free bed for 1 hour while you go and see it. It costs nothing.', s: 15, c: p.mu, lh: 1.5, align: TextAlign.center),
                  const SizedBox(height: 14),
                  Cta('Find a bed', height: 50, px: 16, fs: 15, expand: false, onTap: () => s.tab('explore')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// F22 Area 1: one status card for a hold: Held / Waiting for owner / Booked /
/// Not received / Ended. A big number, one line, a few facts and one or two
/// actions.
class HoldScreen extends StatelessWidget {
  const HoldScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final hold = s.holds.where((h) => h.id == s.holdId).firstOrNull ?? s.holds.lastOrNull;
    if (hold == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back))), Padding(padding: const EdgeInsets.all(16), child: T('This hold isn’t on this phone any more.', s: 15, c: p.mu))]);
    }
    final i = holdInfo(s, hold);
    final st = hold.status;
    final owner = i.hh.owner;
    final pay = hold.opt == 'book' ? s.payOfHold(hold.id) : null;
    final amt = fmt(pay?.amt ?? hold.paid);
    final utr = utrSpaced(pay?.utr ?? '');
    final q = s.quote(hold.hid, i.r.ac, i.r.share);
    final expired = s.expiredHolds.contains(hold.id);
    final code = hold.ref;
    final timed = const ['waiting', 'confirmed', 'held'].contains(st);
    // F26 #7: a ready message with the HZ code; no enquiry is recorded.
    void wa() => s.waOwner(hold);
    void again() {
      final b = s.findBed(hold.hid, hold.bed).b;
      if (b == null || b.state != 'free') return s.toastMsg('Bed ${hold.bed} has been taken. See other beds.');
      s.update(() => s.hid = hold.hid);
      s.openPicker();
      s.update(() {
        s.bed = hold.bed;
        s.holdOpt = 'free';
        s.sheet = 'hold';
      });
    }

    void others() {
      s.update(() => s.hid = hold.hid);
      s.openPicker();
    }

    // (label, big, line, rows, primary, secondary, link, green)
    final ({String label, String big, String line, List<(String, String)> rows, (String, String, VoidCallback)? main, (String, String, VoidCallback)? alt, bool green}) v = switch (st) {
      'paying' when pay?.status == 'waiting' => (
        label: 'Waiting for $owner',
        big: amt,
        line: 'You sent the UPI reference. It says Booked only after $owner sees the money, so it’s not booked yet.',
        rows: [('UPI reference', utr), if (pay?.sent != null) ('Sent', pay!.sent!), if (code != null) ('Booking code', code)],
        main: ('Remind $owner', 'msg', () => s.whatsapp(ownerWa(pay!.hid), 'Hi $owner, I paid the ${fmt(pay.amt)} advance for bed ${pay.bed} by UPI. UPI reference ${utrSpaced(pay.utr ?? '')}, booking code ${pay.note}. Please confirm on Hostelzy.')),
        alt: ('Fix the UPI reference', 'chev', () => s.openPayUtr(pay!)),
        green: false,
      ),
      'paying' when pay?.status == 'missing' => (
        label: 'Not received',
        big: amt,
        line: '$owner didn’t see this payment. Check the UPI reference in your UPI app. If the money left your account, send $owner the UPI receipt on WhatsApp.',
        rows: [('UPI reference', utr), if (pay?.sent != null) ('Sent', pay!.sent!)],
        main: ('Fix the UPI reference', 'arrow', () => s.openPayUtr(pay!)),
        alt: ('Talk to $owner', 'msg', () => s.whatsapp(ownerWa(pay!.hid), 'Hi $owner, about my advance for bed ${pay.bed}: UPI reference ${utrSpaced(pay.utr ?? '')}, booking code ${pay.note}.')),
        green: false,
      ),
      'paying' => (
        label: 'Pay to book',
        big: amt,
        line: 'Pay $owner by UPI, then enter the UPI reference. The bed is kept for you meanwhile; it says Booked once $owner sees the money.',
        rows: [if (code != null) ('Booking code', code), ('Rent', '${fmt(hold.fixedFee > 0 ? hold.fixedFee : q.hzFee)} a month'), if (hold.perks.isNotEmpty) ('Hostelzy deal', hold.perks.join(' · '))],
        main: pay == null ? null : ('Pay $amt by UPI', 'arrow', () => s.payByUpi(pay)),
        alt: pay == null ? null : ('I’ve paid · enter UPI reference', 'chev', () => s.openPayUtr(pay)),
        green: false,
      ),
      'booked' => (
        label: 'Booked',
        big: 'Yours.',
        line: pay?.done != null ? '$owner confirmed $amt on ${pay!.done}. Show ${code ?? 'your booking code'} when you move in.' : 'Advance paid to $owner. Show ${code ?? 'your booking code'} when you move in.',
        rows: [('Pay at move-in', '${fmt(q.hzFirst)} first month'), ('Your price is fixed', '${fmt(hold.fixedFee > 0 ? hold.fixedFee : q.hzFee)} a month'), if (code != null) ('Booking code', code), if (hold.perks.isNotEmpty) ('Hostelzy deal', hold.perks.join(' · '))],
        main: ('Moving in · see what to pay', 'arrow', () => s.go('moveIn')),
        alt: ('Directions', 'pin', () => s.directions(i.hh)),
        green: true,
      ),
      'waiting' || 'confirmed' || 'held' => (
        label: st == 'waiting' ? 'Held for you · free' : 'Held · $owner confirmed',
        big: cd(i.left),
        line: st == 'waiting' ? 'Go and see it. $owner doesn’t know yet: tell them you’re coming so they keep it.' : 'Go and see it before the timer ends to keep the bed.',
        rows: [('Rent', '${fmt(q.hzFee)} a month'), ('To move in', '${fmt(q.hzMove)} · advance ${fmt(q.hzAdv)} + first month'), if (code != null) ('Booking code', code)],
        main: st == 'waiting' ? ('Tell $owner on WhatsApp', 'msg', wa) : ('Moving in · see what to pay', 'arrow', () => s.go('moveIn')),
        alt: st == 'waiting' ? ('Directions', 'pin', () => s.directions(i.hh)) : ('WhatsApp $owner', 'msg', wa),
        green: st != 'waiting',
      ),
      _ => (
        label: expired ? 'Hold ended' : (hold.declined ? 'Declined' : 'Released'),
        big: expired ? '0:00' : '—',
        line: hold.declined ? 'The owner couldn’t keep bed ${hold.bed}. Call and WhatsApp are locked again. Nothing was charged.' : 'Bed ${hold.bed} is free for everyone again. Nothing was charged.',
        rows: [('Bed', '${hold.bed} · ${i.r.share} sharing'), ('Rent', '${fmt(q.hzFee)} a month')],
        main: ('Hold it again', 'arrow', again),
        alt: ('See other beds', 'chev', others),
        green: false,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(i.hh.name), T('Bed ${hold.bed}', w: 800, s: 22, lh: 1.1)])),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('hold${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('holdCard'),
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: v.green ? p.gb : p.sf,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Kicker(v.label, c: v.green ? p.gn : p.ad),
                              const SizedBox(height: 4),
                              // Perf: a held bed's countdown is the only part that ticks.
                              if (timed) Ticking((context) => T(cd(holdInfo(s, hold).left), w: 800, s: 56, lh: 1, ls: -.03, tab: true, c: v.green ? p.gn : p.tx)) else T(v.big, w: 800, s: 56, lh: 1, ls: -.03, tab: true, c: v.green ? p.gn : p.tx),
                              const SizedBox(height: 8),
                              T(v.line, s: 14, lh: 1.45),
                            ],
                          ),
                        ),
                        for (final r in v.rows) KV(r.$1, r.$2, keyWidth: 120),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: VGap(
                            gap: 8,
                            children: [
                              if (v.main case final m?) Cta(m.$1, icon: m.$2, height: 52, px: 16, fs: 15, onTap: m.$3),
                              if (v.alt case final a?) OutlineCta(a.$1, icon: a.$2, onTap: a.$3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (HoldSteps.shows(s, hold)) Container(key: const ValueKey('holdScreenSteps'), margin: const EdgeInsets.only(top: 12), decoration: box(w: 2, c: p.tx), child: HoldSteps(hold)),
                  const SizedBox(height: 8),
                  if (st == 'paying' && pay?.status == 'missing')
                    Tap(onTap: () => s.cancelBooking(hold), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Cancel and pick another bed', w: 600, s: 14, c: p.ad))),
                  if (st == 'waiting' || st == 'confirmed' || st == 'held')
                    Tap(onTap: () => s.releaseWithUndo(hold), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: T('Release this hold', w: 600, s: 14, c: p.ad))),
                  // Demo only: never in the Play Store build (F17).
                  if (st == 'waiting' && kDebugMode)
                    Tap(
                      onTap: () {
                        s.setHold(hold.id, 'confirmed');
                        s.toastMsg('$owner confirmed on WhatsApp.');
                      },
                      child: Dashed(color: p.dv, width: 1, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), child: T('Demo: simulate the owner confirming', s: 12, c: p.mu)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
