import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// F21 W2: two equal ways to take a bed: hold free for an hour (picked
/// first) or pay the advance to book. One button, one verb.
class HoldSheet extends StatelessWidget {
  const HoldSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    if (sb?.b == null) return const SizedBox();
    final b = sb!.b!, r = sb.r!;
    final q = s.quote(h.id, r.ac, r.share);
    final perks = s.lockedPerks(q, h);
    final book = s.holdOpt == 'book';
    Widget card(String opt, String title, String sub, List<String> ticks) {
      final on = s.holdOpt == opt;
      return Expanded(
        child: Tap(
          key: ValueKey('opt-$opt'),
          onTap: () => s.update(() => s.holdOpt = opt),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: box(bg: on ? p.ab : null, w: 2, c: on ? p.ac : p.tx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: T(title, w: 800, s: 17, lh: 1.2)),
                    const SizedBox(width: 6),
                    Container(width: 18, height: 22, decoration: box(w: 2, c: p.tx), padding: const EdgeInsets.all(3), child: on ? Container(color: p.tx) : null),
                  ],
                ),
                const SizedBox(height: 6),
                T(sub, s: 13, c: p.mu),
                const SizedBox(height: 8),
                for (final t in ticks)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 2), child: Ic('check', size: 13)), const SizedBox(width: 6), Expanded(child: T(t, s: 13, lh: 1.35))]),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card('free', 'Hold free · ${s.isMember ? '2 hours' : '1 hour'}', 'Go and see it first', const ['₹0 now', 'Bed kept for you', 'Ends on its own']),
                const SizedBox(width: 10),
                card('book', 'Pay ${fmt(q.hzAdv)} to book', 'Sure already', ['Bed is yours once ${h.owner} confirms', 'Your price is fixed']),
              ],
            ),
          ),
          Container(
            color: p.sf,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Rich([
              sp(context, 'Bed ${b.id} · ${fmt(q.hzFee)}/mo', w: 800, c: p.tx),
              sp(context, ' · ${r.share} sharing${h.ac ? ' · ${r.type}' : ''} · Advance ${fmt(q.hzAdv)} · ${fmt(q.hzBack)} back when you leave'),
            ], s: 13, c: p.mu, lh: 1.45),
          ),
          if (book && q.any)
            Container(
              color: p.gb,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Rich([sp(context, 'Hostelzy deal: ', w: 800), sp(context, perks.join(' · ')), sp(context, ' · booking code ${s.peekRef}', w: 800)], s: 13, c: p.gn, lh: 1.45),
            ),
          Cta(book ? 'Pay ${fmt(q.hzAdv)} to book' : 'Hold bed ${b.id} free', key: const ValueKey('holdGo'), px: 16, fs: 15, onTap: () => s.placeHold(s.holdOpt)),
          T(book ? 'You pay by UPI straight to ${h.owner}. Hostelzy never holds your money.' : 'If ${h.owner} doesn’t keep it within the hour, the bed is free again. You pay nothing.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

class WaSheet extends StatelessWidget {
  const WaSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ref = s.waRef;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          // F22 Area 1: the message with the booking code; nothing is sent from here.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: box(w: 2, c: p.tx),
            child: T(s.waFull, s: 15, lh: 1.45),
          ),
          Cta(
            'Open WhatsApp',
            icon: 'msg',
            height: 54,
            px: 16,
            fs: 15,
            onTap: () {
              final text = s.waFull, phone = s.waPhone;
              s.update(() => s.sheet = null);
              s.whatsapp(phone, text);
            },
          ),
          OutlineCta(
            'Copy message',
            icon: 'check',
            height: 50,
            onTap: () {
              s.copyText(s.waFull);
              s.update(() => s.sheet = null);
              s.toastMsg('Message copied.');
            },
          ),
          if (ref != null) T('The booking code keeps your Hostelzy price.', s: 12, c: p.mu, lh: 1.45),
          T('Nothing is sent until you press send in WhatsApp.', s: 12, c: p.mu, lh: 1.45),
        ],
      ),
    );
  }
}
