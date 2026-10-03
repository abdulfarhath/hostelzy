import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'owner_manage_screen.dart';

/// F05 board 3: one enquiry, opened from its HZ code on owner Today.
class EnquirySheet extends StatelessWidget {
  const EnquirySheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final e = s.enquiries.where((x) => x.ref == s.enqRef).firstOrNull;
    if (e == null) return const SizedBox();
    final first = e.name.split(' ')[0];
    final r = e.bed != null ? s.findBed(e.hid, e.bed).r : null;
    void contact(String how) {
      s.markContacted(e.ref);
      if (how == 'wa') {
        s.openWA(e.name, 'Hi $first, this is ${hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}. Got your Hostelzy enquiry (${e.ref}).', phone: e.phone);
      } else {
        s.update(() => s.sheet = null);
        how == 'call' ? s.call(e.phone) : s.toastMsg('Marked as contacted.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // F22 Area 3 (board `enquiry`): the booking code first, then two actions.
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Kicker(e.contacted ? 'Enquiry from the app · contacted' : 'Enquiry from the app')),
        KV('Booking code', e.ref, keyWidth: 110),
        KV('Phone', '+91 ${phoneSpaced(e.phone)} · not verified', keyWidth: 110),
        KV('Asked about', '${e.bed != null ? 'Bed ${e.bed}${r != null ? ' · ${r.share} sharing' : ''}' : 'Any bed'} · ${clockTime(e.at)}', keyWidth: 110),
        KV('Message', '“${e.msg}”', keyWidth: 110),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(child: Cta('WhatsApp', icon: 'msg', height: 50, px: 14, fs: 15, onTap: () => contact('wa'))),
              const SizedBox(width: 8),
              Expanded(child: OutlineCta('Call', icon: 'phone', height: 50, px: 14, onTap: () => contact('call'))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: T('If $first moves in, add them with this phone number so it counts.', s: 13, c: p.mu, lh: 1.4),
        ),
        if (!e.contacted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                onTap: () => contact('mark'),
                child: const SizedBox(
                  height: 44,
                  child: Center(child: T('Mark as contacted', w: 800, s: 14, underline: true)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AddSheet extends StatelessWidget {
  const AddSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms[s.ownHid] ?? const <Room>[];
    final freeA = <Bed>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' || b.state == 'soon') freeA.add(b);
      }
    }
    final sel = s.addBed != null ? s.findBed(s.ownHid, s.addBed) : null;
    final terms = hostelById(s.ownHid).terms;
    Widget label(String t) => T(t, w: 800, s: 13);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 14,
        children: [
          VGap(
            gap: 6,
            children: [
              label('Name'),
              Field(key: const ValueKey('addName'), value: s.addName, onChanged: (v) => s.update(() => s.addName = v), placeholder: 'Full name'),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Phone'),
              Row(
                children: [
                  Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('+91', w: 800, s: 15)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Field(
                      key: const ValueKey('addPhone'),
                      value: s.addPhone,
                      onChanged: (v) => s.update(() {
                        final d = v.replaceAll(RegExp(r'\D'), '');
                        s.addPhone = d.length > 10 ? d.substring(0, 10) : d;
                      }),
                      placeholder: 'WhatsApp number, 10 digits',
                      numeric: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Bed'),
              wrap(6, [for (final b in freeA.take(12)) ChipBtn(b.id, on: b.id == s.addBed, onTap: () => s.update(() => s.addBed = b.id), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Moves in'),
              Seg(opts: same(['Today', 'Tomorrow', dayMon(appToday.add(const Duration(days: 4)))]), cur: s.addDate, onPick: (v) => s.update(() => s.addDate = v), pad: const EdgeInsets.all(10)),
            ],
          ),
          T(sel?.r != null ? 'Rent ${fmt(sel!.r!.rent)} a month · due at move-in ${fmt(terms.advance + sel.r!.rent)} (advance ${fmt(terms.advance)}, ${fmt(terms.maintenance)} kept on exit)' : 'Pick a bed to see the rent.', s: 13, c: p.mu, lh: 1.45),
          // F22: the board asks "How did they find you?" and a booking code; the
          // server already links a tenant who came from the app by phone number.
          Container(
            padding: const EdgeInsets.all(12),
            color: p.sf,
            child: const T('Came from the Hostelzy app? Use the phone number they booked with, so it counts.', s: 13, lh: 1.45),
          ),
          Cta(
            'Add tenant',
            key: const ValueKey('addGo'),
            icon: 'check',
            height: 54,
            px: 16,
            fs: 15,
            onTap: () {
              // F18 (F10): a real name, a real mobile number and a free bed.
              if (s.addName.trim().length < 2) return s.toastMsg('Add the tenant’s name.');
              if (s.addPhone.isNotEmpty && !AppState.validPhone(s.addPhone)) return s.toastMsg('That mobile number doesn’t look right (10 digits, 6–9 first).');
              if (sel == null || sel.b == null) return s.toastMsg('Pick a bed.');
              if (sel.b!.state == 'booked') return s.toastMsg('Bed ${sel.b!.id} is already taken.');
              final name = s.addName.trim();
              if (s.onServer) {
                // S2: the booking is a stay on the server (moving in on the chosen day).
                final days = switch (s.addDate) { 'Today' => 0, 'Tomorrow' => 1, _ => 4 };
                s.addStayLive(name, s.addPhone, sel.b!.id, sel.r!.rent, terms.advance, appToday.add(Duration(days: days)), booking: true).then((ok) {
                  if (!ok) return;
                  s.update(() {
                    s.addName = '';
                    s.addPhone = '';
                    s.addBed = null;
                    s.addDate = 'Today';
                  });
                });
                return;
              }
              sel.b!.state = 'booked';
              s.update(() {
                s.sheet = null;
                final m = s.matchFor(s.addPhone, s.now);
                // F06: a new booking waits for the tenant's WhatsApp code like any added resident.
                s.residents = [...s.residents, Resident(name: name, bed: sel.b!.id, amt: sel.r!.rent, status: 'Due', note: 'Moves in ${s.addDate}', phone: s.addPhone, via: m != null ? 'hz' : 'direct', since: 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: false)];
                s.addName = '';
                s.addPhone = '';
                s.addBed = null;
                s.addDate = 'Today';
              });
              s.toastMsg('Booked bed ${sel.b!.id}. Send them a welcome on WhatsApp.');
            },
          ),
        ],
      ),
    );
  }
}

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
        () => s.update(() {
          s.sheet = 'add';
          s.addBed = b.id;
        }),
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
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Kicker(stl)),
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
