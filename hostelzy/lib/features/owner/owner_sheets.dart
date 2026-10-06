import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'owner_manage_screen.dart';

class BedSheet extends StatelessWidget {
  const BedSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final f = s.findBed(s.ownHid, s.obed);
    if (f.b == null) return const SizedBox();
    final b = f.b!, r = f.r!;
    final res = s.residents.where((x) => x.bed == b.id).firstOrNull;
    final terms = hostelById(s.ownHid).terms;
    final leave = leaveDates(terms).first;
    final stl = {'free': 'Free', 'soon': 'Free from ${b.soon}', 'held': 'On hold', 'booked': 'Taken'}[b.state]!;
    void done(String m) {
      s.update(() => s.sheet = null);
      s.toastMsg(m);
    }

    final first = res?.name.split(' ').first ?? '';
    final actions = <(String, VoidCallback, bool, String)>[];
    if (b.state == 'booked') {
      actions.add(('Message ${first.isEmpty ? 'resident' : first}', () => s.openWA(res != null ? res.name : 'Resident', 'Hi, this is ${s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}.', phone: res?.phone ?? ''), true, 'msg'));
      actions.add((
        'Mark as leaving $leave',
        () => res != null ? s.markLeaving(res, b, leaveDays(terms).first) : () {
          b.state = 'soon';
          b.soon = leave;
          done('Bed ${b.id} is listed as free from $leave.');
        }(),
        false,
        'logout',
      ));
    } else if (b.state == 'held') {
      actions.add((
        'Release hold',
        () {
          s.ownerReleaseBed(s.ownHid, b);
          done('Bed ${b.id} is ${b.state == 'soon' ? 'free soon' : 'free'} again.');
        },
        true,
        'x',
      ));
    } else if (b.state == 'soon' && res != null) {
      // F24: leaving: when they've gone, the bed frees and the refund is due.
      actions.add(('Message ${first.isEmpty ? 'resident' : first}', () => s.openWA(res.name, 'Hi, this is ${s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}.', phone: res.phone), false, 'msg'));
      actions.add(('${first.isEmpty ? 'They' : first} moved out', () => s.movedOut(res, b), true, 'logout'));
    } else {
      actions.add((
        'Add tenant to this bed',
        () => s.openAddResident(bed: b.id),
        true,
        'plus',
      ));
      actions.add((
        'Hold for a walk-in',
        () {
          s.holdWalkIn(s.ownHid, b);
          done('Bed ${b.id} held for 1 hour. It frees itself after that.');
        },
        false,
        'clock',
      ));
    }
    // F22 Area 3 (board `bedSheet`): who's in it, the room, the rent, since
    // when and how they came; then one main action.
    final via = res == null ? null : residentTag(p, res.tag).label.toLowerCase();
    // F24 item 13: the deal the tenant booked with, locked on the server.
    final deal = res != null && res.perks.isNotEmpty ? res.perks : s.holds.where((h) => h.hid == s.ownHid && h.bed == b.id && h.status != 'released' && h.perks.isNotEmpty).firstOrNull?.perks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // F26 #9: the owner opened this bed's hold: the tenant sees "Owner reviewing".
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: OnShow(() => s.markHoldsSeen([for (final h in s.holds) if (h.hid == s.ownHid && h.bed == b.id) h.id]), child: Kicker(stl))),
        if (b.state == 'booked') KV('Resident', res != null ? '${res.name} · rent ${res.status == 'Overdue' ? 'late' : res.status.toLowerCase()}' : 'Not added yet', keyWidth: 110),
        KV('Room', '${r.label} · ${r.share} sharing · ${b.spot}', keyWidth: 110),
        KV('Rent', '${fmt(r.rent)} a month', keyWidth: 110),
        if (res != null) KV('Since', [res.since.replaceFirst('Joined ', '').replaceFirst('Added ', ''), ?via].join(' · '), keyWidth: 110),
        KV('Advance', '${fmt(terms.advance)} · ${fmt(terms.maintenance)} kept on exit', keyWidth: 110),
        if (deal != null) KV('Hostelzy deal', 'Price fixed · ${deal.join(' · ')}', keyWidth: 110),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: VGap(
            gap: 8,
            children: [for (final a in actions) a.$3 ? Cta(a.$1, icon: a.$4, height: 54, px: 16, fs: 15, onTap: a.$2, bg: p.tx, fg: p.bg, border: p.tx) : OutlineCta(a.$1, icon: a.$4, onTap: a.$2)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              key: const ValueKey('bedLayout'),
              onTap: () {
                s.update(() => s.sheet = null);
                s.ownerLayout(r.n);
              },
              child: T('Room ${r.label} layout ›', s: 14, w: 800),
            ),
          ),
        ),
      ],
    );
  }
}
