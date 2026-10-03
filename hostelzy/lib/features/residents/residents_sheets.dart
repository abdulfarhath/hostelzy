import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// F06 board 5 + F25: the one "Add a resident" sheet (the owner's "+" tab,
/// Residents › Add and a free bed's "Add tenant to this bed"). The number is
/// matched live against Hostelzy enquiries, holds and bookings. One date:
/// in the future it's "Moves in" (a booking), today or past "Joined on".
class AddResidentSheet extends StatelessWidget {
  const AddResidentSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final missing = s.unassignedBeds;
    final free = <String>[
      for (final r in s.rooms[s.ownHid] ?? const <Room>[])
        for (final b in r.beds)
          if ((b.state == 'free' || b.state == 'soon') && !b.mine) b.id,
    ];
    // A bed picked from the bed sheet is always shown, even past the first 12.
    final shown = [...free.take(12), if (s.rBed != null && !missing.contains(s.rBed) && !free.take(12).contains(s.rBed)) s.rBed!];
    final m = s.matchFor(s.rPhone, s.rJoinAt);
    final who = s.rName.trim().isEmpty ? 'They' : s.rName.trim().split(' ')[0];
    Widget label(String t) => T(t, w: 800, s: 13);
    final terms = hostelById(s.ownHid).terms;
    final fee = int.tryParse(s.rFee) ?? 0, adv = int.tryParse(s.rAdv) ?? 0;
    Widget field(String l, String v, ValueChanged<String> on, {String? ph, bool numeric = false, Key? key}) => VGap(
      gap: 6,
      children: [label(l), Field(key: key, value: v, onChanged: on, placeholder: ph, numeric: numeric)],
    );
    String digits(String v, int n) {
      final d = v.replaceAll(RegExp(r'\D'), '');
      return d.length > n ? d.substring(0, n) : d;
    }

    Widget bedChip(String id, bool flagged) {
      final on = id == s.rBed;
      return Tap(
        onTap: () => s.pickResidentBed(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: box(bg: on ? (flagged ? p.ab : p.tx) : transparent, w: 1, c: flagged ? p.ac : (on ? p.tx : p.dv)),
          child: T(flagged ? '$id · no resident' : id, s: 13, w: 600, c: flagged ? p.ad : (on ? p.bg : p.tx)),
        ),
      );
    }

    // "Pick date": a week back or a week ahead (rPickBack < 0 = ahead).
    final days = [for (var i = 7; i >= 2; i--) i, for (var i = 2; i <= 7; i++) -i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          field('Name', s.rName, (v) => s.update(() => s.rName = v), ph: 'Full name', key: const ValueKey('addName')),
          VGap(
            gap: 6,
            children: [
              label('WhatsApp number'),
              Row(
                children: [
                  Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('+91', w: 800, s: 15)),
                  const SizedBox(width: 6),
                  Expanded(child: Field(key: const ValueKey('addPhone'), value: s.rPhone, onChanged: (v) => s.update(() => s.rPhone = digits(v, 10)), placeholder: '10 digits', numeric: true)),
                ],
              ),
            ],
          ),
          if (s.rPhone.length == 10)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: p.sf,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Ic('shield', size: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Rich(
                      m != null
                          ? [sp(context, 'Joined via Hostelzy.', w: 800), sp(context, ' This number ${m.what} on Hostelzy ${s.now - m.at < 86400000 ? 'today' : 'on ${dayMon(DateTime.fromMillisecondsSinceEpoch(m.at))}'} (${m.ref}).')]
                          : s.rBefore && s.canMarkBefore
                          ? [sp(context, 'Joined before Hostelzy.', w: 800), sp(context, ' Lived here before the hostel went live on Hostelzy.')]
                          : [sp(context, 'Direct.', w: 800), sp(context, ' No Hostelzy enquiry, hold or booking from this number in the last $matchWindowDays days.')],
                      s: 13,
                      lh: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          VGap(
            gap: 6,
            children: [
              label('Bed'),
              wrap(6, [for (final id in missing) bedChip(id, true), for (final id in shown) bedChip(id, false)]),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              Row(
                children: [
                  KeyedSubtree(key: const ValueKey('addDateLabel'), child: label(s.rFuture ? 'Moves in' : 'Joined on')),
                  const Spacer(),
                  T(dayMon(appToday.add(Duration(days: s.rDays))), s: 13, c: p.mu),
                ],
              ),
              Seg(opts: same(['Yesterday', 'Today', 'Tomorrow', 'Pick date']), cur: s.rJoin, onPick: (v) => s.update(() => s.rJoin = v), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), byLabel: true),
              if (s.rJoin == 'Pick date') wrap(6, [for (final d in days) ChipBtn(dayMon(appToday.subtract(Duration(days: d))), key: ValueKey('addDay$d'), on: s.rPickBack == d, onTap: () => s.update(() => s.rPickBack = d), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          // F24 #18: before go-live, residents already living here are
          // "Joined before Hostelzy" (never counted as joining off the app).
          if (s.canMarkBefore && !s.rFuture)
            Tap(
              key: const ValueKey('rBefore'),
              onTap: () => s.update(() => s.rBefore = !s.rBefore),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: box(w: 2, c: p.tx),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 24, height: 24, alignment: Alignment.center, decoration: box(bg: s.rBefore ? p.tx : transparent, w: 2, c: p.tx), child: s.rBefore ? Ic('check', size: 16, color: p.bg) : null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VGap(
                        gap: 2,
                        children: [
                          const T('Lived here before Hostelzy', w: 800, s: 14),
                          T('Only until ${hostelById(s.ownHid).name} goes live. After that, the Hostelzy team marks it.', s: 12, c: p.mu, lh: 1.4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field('Monthly fee', s.rFee.isEmpty ? '' : fmt(int.parse(s.rFee)), (v) => s.update(() => s.rFee = digits(v, 6)), ph: '₹', numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: field('Advance paid', s.rAdv.isEmpty ? '' : fmt(int.parse(s.rAdv)), (v) => s.update(() => s.rAdv = digits(v, 6)), ph: '₹', numeric: true)),
            ],
          ),
          if (fee > 0) T('Rent ${fmt(fee)} a month · due at move-in ${fmt(adv + fee)} (advance ${fmt(adv)}, ${fmt(terms.maintenance)} kept on exit)', s: 13, c: p.mu, lh: 1.45),
          if (s.rPhone.length < 10)
            Container(
              padding: const EdgeInsets.all(12),
              color: p.sf,
              child: const T('Came from the Hostelzy app? Use the phone number they booked with, so it counts.', s: 13, lh: 1.45),
            ),
          T(s.onServer ? '$who confirms by joining with your invite code. They count as a resident once they confirm.' : '$who confirms the details in the app. They count as a resident once they confirm.', s: 12, c: p.mu, lh: 1.4),
          Cta(s.rFuture ? 'Book the bed' : 'Add resident', key: const ValueKey('addGo'), icon: 'check', height: 54, px: 16, fs: 15, onTap: s.addResident),
        ],
      ),
    );
  }
}
