import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// F06 board 5: the owner adds a resident; the number is matched live
/// against Hostelzy enquiries, holds and bookings.
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
          if (b.state == 'free' && !b.mine) b.id,
    ];
    final m = s.matchFor(s.rPhone, s.rJoinAt);
    final who = s.rName.trim().isEmpty ? 'They' : s.rName.trim().split(' ')[0];
    Widget label(String t) => T(t, w: 800, s: 13);
    Widget field(String l, String v, ValueChanged<String> on, {String? ph, bool numeric = false}) => VGap(
      gap: 6,
      children: [label(l), Field(value: v, onChanged: on, placeholder: ph, numeric: numeric)],
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

    final past = [for (var i = 2; i <= 7; i++) i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          field('Name', s.rName, (v) => s.update(() => s.rName = v), ph: 'Full name'),
          field('WhatsApp number', s.rPhone, (v) => s.update(() => s.rPhone = digits(v, 10)), ph: '10 digits', numeric: true),
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
              wrap(6, [for (final id in missing) bedChip(id, true), for (final id in free.take(8)) bedChip(id, false)]),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Joined on'),
              Seg(opts: same(['Today', 'Yesterday', 'Pick date']), cur: s.rJoin, onPick: (v) => s.update(() => s.rJoin = v), pad: const EdgeInsets.all(10)),
              if (s.rJoin == 'Pick date') wrap(6, [for (final d in past) ChipBtn(dayMon(appToday.subtract(Duration(days: d))), on: s.rPickBack == d, onTap: () => s.update(() => s.rPickBack = d), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          // F24 #18: before go-live, residents already living here are
          // "Joined before Hostelzy" (never counted as joining off the app).
          if (s.canMarkBefore)
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
          T(s.onServer ? '$who confirms by joining with your invite code. They count as a resident once they confirm.' : '$who confirms the details in the app. They count as a resident once they confirm.', s: 12, c: p.mu, lh: 1.4),
          Cta('Add resident', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.addResident),
        ],
      ),
    );
  }
}
