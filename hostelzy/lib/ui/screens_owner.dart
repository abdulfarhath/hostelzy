import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data.dart';
import '../app_config.dart' show inviteLink, shortLink;
import '../state.dart';
import 'common.dart';
import 'deals.dart';
import 'kit.dart';
import 'layout.dart' show ConfirmLayoutsCard;
import 'payments.dart';
import 'plan.dart';
import 'onboarding.dart';
import 'screens_resident.dart' show WeekTable;
import 'screens_tenant.dart' show FloorTabs, RoomTypeTag;

({int t, int booked, int held, int soon, int free}) countBeds(AppState s) {
  var t = 0, booked = 0, held = 0, soon = 0, free = 0;
  for (final r in s.rooms[s.ownHid]!) {
    for (final b in r.beds) {
      t++;
      switch (b.state) {
        case 'booked':
          booked++;
        case 'held':
          held++;
        case 'soon':
          soon++;
        case 'free':
          free++;
      }
    }
  }
  return (t: t, booked: booked, held: held, soon: soon, free: free);
}

String occCounts(AppState s) {
  final c = countBeds(s);
  return '${c.free} free · ${c.held} on hold · ${c.soon} soon · ${c.booked} taken';
}

/// Hold requests: the tenant's own free holds on Anjani plus seeded ones.
/// S2: on Supabase the holds are tenants' (their name isn't shared; the HZ code is).
List<HoldRequest> allRequests(AppState s) => [
  for (final h in s.holds.where((h) => h.hid == s.ownHid && h.status == 'waiting'))
    s.onServer
        ? HoldRequest(id: h.id, name: 'Hostelzy tenant', bed: h.bed, type: 'Free hold', secs: s.holdSecs, start: h.start, note: 'Code ${h.ref ?? ''} · placed in the Hostelzy app', hold: h.id)
        : HoldRequest(id: h.id, name: s.meName.isEmpty ? 'Hostelzy user' : s.meName, bed: h.bed, type: 'Free hold', secs: s.holdSecs, start: h.start, note: 'Placed from the Hostelzy app', hold: h.id, trusted: s.level == 'trusted'),
  if (s.ownHid == 'anjani' && !s.onServer) ...s.reqs,
];

/// F05 open question: Enquiries as a KPI tile (true: replaces Complaints) or
/// only as a section (false, the approved default).
const enquiriesTile = false;

class OwnerTodayScreen extends StatelessWidget {
  const OwnerTodayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final c = countBeds(s);
    final collected = s.residents.where((r) => r.status == 'Paid').fold<int>(0, (a, r) => a + r.amt);
    final expected = s.residents.fold<int>(0, (a, r) => a + r.amt);
    final kpis = <(String, String, String)>[
      ('${c.booked} / ${c.t}', 'beds taken', 'oBeds'),
      ('${c.free}', 'free beds', 'oBeds'),
      (fmt(expected - collected), 'rent pending', 'oRent'),
    ];
    return Scroll(
      key: ValueKey('oToday${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // F14: tap the hostel name to switch hostels.
                Expanded(
                  child: Tap(onTap: () => s.update(() => s.sheet = 'switch'), child: PageHead(kicker: '${hostelById(s.ownHid).name} · ${dayName(appToday)}', title: 'Today', size: 32)),
                ),
                const SizedBox(width: 12),
                Tap(
                  onTap: () => s.go('me'),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: p.ac,
                    alignment: Alignment.center,
                    child: T(initials(s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner), w: 800, s: 15, c: p.ai),
                  ),
                ),
              ],
            ),
          ),
          const PlanBanner(),
          const _FairPlayCard(),
          // F21 W3: one list of what needs the owner, soonest first.
          const NeedsYouNow(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('This month')),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: box(w: 2, c: p.tx),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, k) in kpis.indexed)
                    Expanded(
                      child: Tap(
                        onTap: () => s.tab(k.$3),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: i > 0 ? Border(left: bs(1, p.hl)) : null),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(k.$1, w: 800, s: 20, ell: true), T(k.$2, s: 12, c: p.mu)]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const FreeBedsCard(),
          const ConfirmLayoutsCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// F21 W3 owner Today: holds with their countdown, payments to confirm, new
/// enquiries and layout fixes, each with its own buttons.
class NeedsYouNow extends StatelessWidget {
  const NeedsYouNow({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final items = <({String key, String icon, String title, String sub, String right, bool urgent, List<(String, String, VoidCallback)> btns, Widget? badge})>[
      for (final r in [...allRequests(s)]..sort((a, b) => (a.secs - (s.now - a.start) / 1000).compareTo(b.secs - (s.now - b.start) / 1000)))
        (
          key: 'hold-${r.id}',
          icon: 'clock',
          title: 'Hold on bed ${r.bed}',
          sub: '${r.name} · ${r.type}${r.secs > freeHoldSecs ? ' · 2 h' : ''}${r.note.isEmpty ? '' : ' · “${r.note}”'}',
          right: cd(r.secs - (s.now - r.start) / 1000),
          urgent: true,
          btns: [('Confirm hold', 'check', () => s.confirmHoldReq(r)), ('Decline', 'x', () => s.declineHoldReq(r))],
          badge: r.trusted
              ? Tap(
                  onTap: () => s.update(() {
                    s.trustedReq = r.id;
                    s.sheet = 'trusted';
                  }),
                  child: Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T('Trusted tenant', s: 11, w: 800, ls: .05, upper: true, c: p.bg)),
                )
              : null,
        ),
      for (final x in s.payments.where((x) => x.hid == s.ownHid && x.status == 'waiting'))
        (
          key: 'pay-${x.id}',
          icon: 'wallet',
          title: 'Received ${fmt(x.amt)}?',
          sub: '${x.who} · ${x.what}${x.kind == 'rent' ? ' · bed ${x.bed}' : ''} · UPI ref. ${utrSpaced(x.utr ?? '')}',
          right: x.at > 0 ? ago(s.now - x.at) : 'Today',
          urgent: false,
          btns: [('Yes, received', 'check', () => s.confirmPayment(x, true)), ('Not received', 'x', () => s.confirmPayment(x, false))],
          badge: null,
        ),
      for (final e in s.enquiries.where((e) => e.hid == s.ownHid && !e.contacted))
        (
          key: 'enq-${e.ref}',
          icon: 'msg',
          title: 'New enquiry · ${e.name}',
          sub: '${e.bed != null ? 'Bed ${e.bed}' : 'Any bed'} · ${e.ref}${e.msg.isEmpty ? '' : ' · “${e.msg}”'}',
          right: ago(s.now - e.at),
          urgent: false,
          btns: [
            (
              'WhatsApp',
              'msg',
              () {
                s.markContacted(e.ref);
                s.openWA(e.name, 'Hi ${e.name.split(' ')[0]}, this is ${h.owner} from ${h.name}. Got your Hostelzy enquiry (${e.ref}).', phone: e.phone);
              },
            ),
          ],
          badge: null,
        ),
      for (final f in s.fixesWaiting)
        (
          key: 'fix-${f.id}',
          icon: 'grid',
          title: 'Layout fix for Room ${f.room}',
          sub: ['From ${f.author}', if (f.note.isNotEmpty) '“${f.note}”'].join(' · '),
          right: ago(DateTime.now().millisecondsSinceEpoch - f.at),
          urgent: false,
          btns: [('Compare', 'arrow', () => s.openFix(f))],
          badge: null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Kicker('Needs you now · ${items.length}'), if (items.length > 1) T('Soonest first', s: 12, w: 800, c: p.mu)]),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final it in items)
                Container(
                  key: ValueKey(it.key),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: VGap(
                    gap: 8,
                    children: [
                      Row(
                        children: [
                          Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: Ic(it.icon, size: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(it.title, w: 800, s: 15),
                                if (it.badge != null) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Align(alignment: Alignment.centerLeft, child: it.badge!)),
                                T(it.sub, s: 12, c: p.mu, lh: 1.35),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          T(it.right, w: 800, s: 14, tab: true, c: it.urgent ? p.ad : p.mu),
                        ],
                      ),
                      Row(
                        children: [
                          for (final (i, b) in it.btns.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: Cta(b.$1, icon: b.$2, height: 40, px: 14, fs: 13, bg: i == 0 ? p.ac : transparent, fg: i == 0 ? p.ai : p.tx, border: i == 0 ? p.ac : p.tx, onTap: b.$3)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: T('Nothing waiting. New holds, payments and enquiries show up here and as notifications.', s: 14, c: p.mu, lh: 1.4),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// F07: an open Fair Play case or a strike, at the top of owner Today.
class _FairPlayCard extends StatelessWidget {
  const _FairPlayCard();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final c = s.ownerCase;
    final n = s.strikes[s.ownHid] ?? 0;
    if (c == null && n == 0) return const SizedBox();
    return Tap(
      onTap: () => s.go(c != null ? 'oCase' : 'oStrike'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: box(bg: p.ab, w: 2, c: p.ad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ic(c != null ? 'clock' : 'flag', size: 20, color: p.ad),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: c != null
                    ? [T('Fair Play check ${c.id}', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(c.status == 'decide' ? '${c.title}. Your reply is with the founder.' : '${c.title}. 47 h left to explain or fix it.', s: 13, lh: 1.4)]
                    : [T('Fair Play: strike $n of 3', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(strikeLadder[(n - 1).clamp(0, 2)].$2, s: 13)],
              ),
            ),
            Ic('chev', size: 18, color: p.ad),
          ],
        ),
      ),
    );
  }
}

/// F05 board 2: enquiries Hostelzy recorded before the tenant's WhatsApp
/// opened. The phone is typed by the tenant and not verified yet (no SMS
/// check until billing works, DECISIONS 2026-10-02).
class _Enquiries extends StatelessWidget {
  const _Enquiries();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = s.enquiries.where((e) => e.hid == s.ownHid).toList();
    final fresh = list.where((e) => !e.contacted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [const Kicker('Enquiries from Hostelzy'), T(fresh > 0 ? '$fresh new' : 'All replied', s: 12, w: 800, c: p.ad)],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in list) _EnquiryRow(e),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 1), child: Ic('shield', size: 16, color: p.mu)),
                    const SizedBox(width: 8),
                    Expanded(child: Rich([sp(context, 'Not on this list = not from Hostelzy.', w: 800, c: p.tx), sp(context, ' Someone says they found you on Hostelzy? Ask for their booking code (HZ-…).')], s: 12, c: p.mu, lh: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnquiryRow extends StatelessWidget {
  const _EnquiryRow(this.e);
  final Enquiry e;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final first = e.name.split(' ')[0];
    final d = e.contacted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: VGap(
        gap: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(e.name, w: 800, s: 16),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Ic('check', size: 14),
                        const SizedBox(width: 5),
                        Rich([sp(context, phoneSpaced(e.phone)), sp(context, ' · not verified', c: p.mu)], s: 13),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        T('${e.bed != null ? 'Bed ${e.bed}' : 'Any bed'} · ', s: 13, c: p.mu),
                        Tap(onTap: () => s.openEnquiry(e.ref), child: T(e.ref, s: 13, w: 600, c: p.ad)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                    decoration: box(bg: d ? transparent : p.ab, w: 1, c: d ? p.dv : p.ab),
                    child: T(d ? 'Contacted' : 'New', s: 11, w: 800, ls: .06, upper: true, c: d ? p.mu : p.ad),
                  ),
                  const SizedBox(height: 4),
                  T(ago(s.now - e.at), s: 12, c: p.mu),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Cta(
                  'WhatsApp',
                  icon: 'msg',
                  height: 44,
                  px: 12,
                  fs: 14,
                  bg: d ? transparent : p.ac,
                  fg: d ? p.tx : p.ai,
                  border: d ? p.tx : p.ac,
                  onTap: () {
                    s.markContacted(e.ref);
                    s.openWA(e.name, 'Hi $first, this is ${hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}. Got your Hostelzy enquiry (${e.ref}).', phone: e.phone);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Cta(
                  'Call',
                  icon: 'phone',
                  height: 44,
                  px: 12,
                  fs: 14,
                  bg: transparent,
                  fg: p.tx,
                  border: p.tx,
                  onTap: () {
                    s.markContacted(e.ref);
                    s.call(e.phone);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const ownerLegend = [('Free', 'free'), ('Free soon', 'soon'), ('On hold', 'held'), ('Taken', 'booked')];

class OwnerBedsScreen extends StatelessWidget {
  const OwnerBedsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms[s.ownHid]!;
    final floors = floorsOf(a);
    int freeOn(int f) => a.where((r) => r.floor == f).fold<int>(0, (x, r) => x + r.beds.where((b) => b.state == 'free').length);
    void openBed(Bed b) => s.update(() {
      s.sheet = 'bed';
      s.obed = b.id;
    });

    Widget planRoom(Room r, int i) {
      final cols = r.share == 3 ? 3 : 2;
      final rows = <Widget>[];
      for (var k = 0; k < r.beds.length; k += cols) {
        if (k > 0) rows.add(const SizedBox(height: 6));
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: 6),
                  Expanded(
                    child: k + j < r.beds.length
                        ? () {
                            final b = r.beds[k + j];
                            final res = s.residents.where((x) => x.bed == b.id).firstOrNull;
                            final label = res != null ? initials(res.name) : const {'free': 'Free', 'held': 'Hold', 'booked': 'Taken'}[b.state] ?? b.soon;
                            return Tap(
                              onTap: () => openBed(b),
                              child: BedBox(
                                look: bedState(p, b.state),
                                minHeight: 52,
                                padding: const EdgeInsets.all(6),
                                child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(b.letter, w: 800, s: 15, lh: 1), T(label, s: 10, w: 600, lh: 1.2, ell: true)]),
                              ),
                            );
                          }()
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: i > 0 ? Border(left: bs(2, p.tx)) : null),
          child: VGap(
            gap: 8,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  T(r.label, w: 800, s: 16, nowrap: true),
                  const SizedBox(width: 6),
                  T('${r.share} sharing', s: 11, c: p.mu, nowrap: true),
                ],
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
              T('${r.bath} bath · ${fmt(r.rent)}', s: 11, c: p.mu),
              // F12/F18: the room's layout; red when Hostelzy drew a version for the owner to publish.
              () {
                final wait = s.layoutOf(s.ownHid, r.n)?.pending == true;
                return Tap(
                  onTap: () => s.ownerLayout(r.n),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: box(bg: wait ? p.ac : null, w: 2, c: wait ? p.ac : p.tx),
                    child: Row(children: [Ic('room', size: 14, color: wait ? p.ai : p.tx), const SizedBox(width: 6), Expanded(child: T(wait ? 'New layout' : 'Room layout', s: 12, w: 800, c: wait ? p.ai : p.tx, ell: true))]),
                  ),
                );
              }(),
            ],
          ),
        ),
      );
    }

    Widget planHalf(List<Room> rs) => IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < rs.length; i++) planRoom(rs[i], i)]),
    );

    Widget label10(String t) => T(t, s: 10, w: 600, ls: .1, upper: true, lh: 1.3, c: p.mu, nowrap: true);

    final fr = a.where((r) => r.floor == s.obFloor).toList();
    if (fr.isEmpty && floors.isNotEmpty) fr.addAll(a.where((r) => r.floor == floors.first));
    // Uneven floors: the street side takes the first half of the rooms, the courtyard side the rest.
    final top = (fr.length + 1) ~/ 2;
    return Scroll(
      key: ValueKey('oBeds${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: PageHead(kicker: occCounts(s), title: 'Bed map')),
                const SizedBox(width: 12),
                Tap(
                  onTap: s.openRates,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: box(w: 2, c: p.tx),
                    child: const Row(children: [Ic('wallet', size: 16), SizedBox(width: 8), T('Rooms and rent', w: 800, s: 13)]),
                  ),
                ),
              ],
            ),
          ),
          Seg(opts: const [('plan', 'Floor plan'), ('grid', 'All floors')], cur: s.obView, onPick: (v) => s.update(() => s.obView = v), margin: const EdgeInsets.fromLTRB(16, 0, 16, 14)),
          if (s.obView == 'plan') ...[
            FloorTabs(
              items: [
                for (final f in floors) (f, freeOn(f)),
              ],
              cur: fr.isNotEmpty ? fr.first.floor : s.obFloor,
              onPick: (f) => s.update(() => s.obFloor = f),
              borderTop: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [label10('Windows · street'), const SizedBox(width: 8), label10('Floor ${s.obFloor}')]),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, c) => Container(
                      height: 6,
                      margin: EdgeInsets.symmetric(horizontal: c.maxWidth * .18),
                      color: p.tx,
                    ),
                  ),
                  Container(
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        planHalf(fr.sublist(0, top)),
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 52,
                                decoration: BoxDecoration(border: Border(right: bs(2, p.tx))),
                                child: CustomPaint(painter: Hatch(p.tk, 2, 7, angle: 90)),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [label10('← Stairs'), label10('Corridor')]),
                                ),
                              ),
                              Container(
                                width: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(border: Border(left: bs(2, p.tx))),
                                child: T('WC', s: 11, w: 800, c: p.mu),
                              ),
                            ],
                          ),
                        ),
                        if (fr.length > top) planHalf(fr.sublist(top)) else const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [label10('Courtyard'), const SizedBox(width: 8), label10('Tap a bed to manage')]),
                ],
              ),
            ),
          ],
          if (s.obView == 'grid')
            for (final f in floors)
              Container(
                decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Css(
                        s: 12,
                        child: CssRow(
                          children: [
                            T('Floor $f', w: 800, s: 15),
                            T('${freeOn(f)} free', c: p.mu),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: p.hl,
                        border: Border(top: bs(1, p.hl)),
                      ),
                      child: () {
                        final rs = a.where((r) => r.floor == f).toList();
                        Widget cell(Room r) => Expanded(
                          child: Container(
                            color: p.bg,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                            child: VGap(
                              gap: 8,
                              children: [
                                Css(
                                  s: 12,
                                  child: CssRow(
                                    children: [
                                      T('Room ${r.n}', w: 800, s: 14),
                                      T('${r.share} sharing · ${fmt(r.rent)}', c: p.mu),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (var i = 0; i < r.beds.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 5),
                                      Tap(
                                        onTap: () => openBed(r.beds[i]),
                                        child: BedBox(
                                          look: bedState(p, r.beds[i].state),
                                          width: 34,
                                          height: 46,
                                          child: Center(child: T(r.beds[i].letter, w: 800, s: 13)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        // Two rooms per row, whatever the floor has.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var k = 0; k < rs.length; k += 2) ...[
                              if (k > 0) const SizedBox(height: 1),
                              IntrinsicHeight(
                                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cell(rs[k]), const SizedBox(width: 1), k + 1 < rs.length ? cell(rs[k + 1]) : Expanded(child: Container(color: p.bg))]),
                              ),
                            ],
                          ],
                        );
                      }(),
                    ),
                  ],
                ),
              ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: const Legend(items: ownerLegend),
          ),
        ],
      ),
    );
  }
}

class OwnerRentScreen extends StatelessWidget {
  const OwnerRentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final collected = s.residents.where((r) => r.status == 'Paid').fold<int>(0, (a, r) => a + r.amt);
    final expected = s.residents.fold<int>(0, (a, r) => a + r.amt);
    final rows = s.residents.where((r) => s.rentF == 'All' || r.status == s.rentF);
    return Scroll(
      key: ValueKey('oRent${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageHead(kicker: monthYear(appToday), title: 'Rent'),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: bs(2, p.tx), bottom: bs(2, p.tx)),
            ),
            child: VGap(
              gap: 10,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        T('Collected', s: 11, w: 600, ls: .08, upper: true, lh: 1.3, c: p.mu),
                        T(fmt(collected), w: 800, s: 34, ls: -.02, c: p.gn),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        T('Pending', s: 11, w: 600, ls: .08, upper: true, lh: 1.3, c: p.mu),
                        T(fmt(expected - collected), w: 800, s: 22, c: p.ad),
                      ],
                    ),
                  ],
                ),
                Container(
                  height: 10,
                  decoration: box(w: 2, c: p.tx),
                  child: LayoutBuilder(
                    builder: (context, c) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Container(width: expected == 0 ? 0 : c.maxWidth * collected / expected, color: p.gn)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Seg(opts: same(['All', 'Due', 'Overdue', 'Paid']), cur: s.rentF, onPick: (v) => s.update(() => s.rentF = v), pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 8), fs: 12, margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              T(r.name, w: 800, s: 15),
                              const SizedBox(height: 2),
                              T('Bed ${r.bed} · ${fmt(r.amt)} · ${r.note}', s: 12, c: p.mu),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tag(r.status, bg: tagOf(p, r.status).bg, fg: tagOf(p, r.status).fg),
                            if (r.status != 'Paid') ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Remind on WhatsApp',
                                child: Tap(
                                  onTap: () => s.whatsapp(r.phone, 'Hi ${r.name.split(' ')[0]}, a reminder: your rent of ${fmt(r.amt)} for bed ${r.bed} is due. Thanks, ${hostelById(s.ownHid).owner}'),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: box(w: 2, c: p.tx),
                                    child: const Ic('bell', size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerManageScreen extends StatelessWidget {
  const OwnerManageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const next = {'Open': 'Start work', 'In progress': 'Mark resolved'};
    Widget body;
    if (s.moreTab == 'residents') {
      body = const _Residents();
    } else if (s.moreTab == 'enquiries') {
      body = const _Enquiries();
    } else if (s.moreTab == 'deals') {
      body = const OwnerDeals();
    } else if (s.moreTab == 'rates') {
      body = const RateCard();
    } else if (s.moreTab == 'complaints') {
      final sorted = s.complaints.asMap().entries.toList()
        ..sort((x, y) {
          final a = x.value.status == 'Resolved' ? 1 : 0, b = y.value.status == 'Resolved' ? 1 : 0;
          return a != b ? a - b : x.key - y.key;
        });
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in sorted)
            () {
              final c = e.value;
              final t = tagOf(p, c.status);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: VGap(
                  gap: 6,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Rich([sp(context, c.cat), sp(context, ' · ${c.by} · ${c.date}', w: 400, s: 12, c: p.mu)], w: 800, s: 15)),
                        const SizedBox(width: 10),
                        Tag(c.status, bg: t.bg, fg: t.fg),
                      ],
                    ),
                    T(c.text, s: 14),
                    // F21 W3: the resident's photo, if they added one.
                    if (c.photo != null || s.complaintPhotosLocal[c.id] != null)
                      Tap(key: ValueKey('cphoto-${c.id}'), onTap: () => s.openComplaintPhoto(c), child: Row(children: [Ic('camera', size: 14, color: p.ad), const SizedBox(width: 6), T('See photo', s: 13, w: 800, c: p.ad)])),
                    if (next[c.status] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Tap(
                            onTap: () async {
                              await s.advanceComplaint(c);
                              s.toastMsg('Updated. ${c.by.split(' ')[0]} sees it in the app.');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                              decoration: box(w: 2, c: p.tx),
                              child: T(next[c.status]!, w: 800, s: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }(),
        ],
      );
    } else if (s.moreTab == 'menu') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Seg(opts: const [('day', 'Edit by day'), ('week', 'Week table')], cur: s.mView, onPick: (v) => s.update(() => s.mView = v), margin: const EdgeInsets.fromLTRB(16, 0, 16, 14)),
          if (s.mView == 'week') ...[
            WeekTable(
              onPick: (i) => s.update(() {
                s.mDay = i;
                s.mView = 'day';
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: T('Tap a day to edit it.', s: 12, c: p.mu),
            ),
          ],
          if (s.mView == 'day') ...[
            Container(
              decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < weekDays.length; i++)
                      Expanded(
                        child: Tap(
                          onTap: () => s.update(() => s.mDay = i),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 10, 0, 9),
                            decoration: BoxDecoration(
                              color: i == s.mDay ? p.tx : transparent,
                              border: i > 0 ? Border(left: bs(1, p.hl)) : null,
                            ),
                            child: T(weekDays[i][0], s: 12, w: 600, c: i == s.mDay ? p.bg : p.tx),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: VGap(
                gap: 16,
                children: [
                  for (final m in meals)
                    VGap(
                      gap: 6,
                      children: [
                        Css(
                          s: 12,
                          child: CssRow(
                            children: [
                              T(m[1], w: 800, s: 14),
                              T(m[2], c: p.mu),
                            ],
                          ),
                        ),
                        Field(
                          key: ValueKey('menu-${s.mDay}-${m[0]}'),
                          value: s.menu[s.mDay].of(m[0]),
                          onChanged: (v) => s.update(() {
                            final menu = List.of(s.menu);
                            menu[s.mDay] = menu[s.mDay].withMeal(m[0], v);
                            s.menu = menu;
                          }),
                        ),
                      ],
                    ),
                  T('Residents see changes right away in their Food tab.', s: 12, c: p.mu),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: VGap(
          gap: 14,
          children: [
            for (var i = 0; i < s.rules.length; i++)
              VGap(
                gap: 6,
                children: [
                  T(s.rules[i].k, w: 800, s: 14),
                  Field(
                    value: s.rules[i].v,
                    onChanged: (v) => s.update(() {
                      final rules = List.of(s.rules);
                      rules[i] = Rule(rules[i].k, v);
                      s.rules = rules;
                    }),
                  ),
                ],
              ),
            Cta('Save rules', icon: 'check', height: 52, px: 16, fs: 15, onTap: s.saveRules),
          ],
        ),
      );
    }
    // F18: while typing, the header makes room for the field and keyboard.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (s.moreTab == 'home') return const _ManageList();
    const titles = {'enquiries': 'Enquiries', 'residents': 'Residents', 'complaints': 'Complaints', 'deals': 'Deals', 'rates': 'Rates and UPI', 'menu': 'Food menu', 'rules': 'House rules'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                BackBtn(key: const ValueKey('manageBack'), onTap: () => s.update(() => s.moreTab = 'home')),
                const SizedBox(width: 12),
                Expanded(child: PageHead(kicker: '${hostelById(s.ownHid).name} · Manage', title: titles[s.moreTab] ?? 'Manage', size: 26, gap: 2)),
              ],
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
            child: Scroll(key: ValueKey('oMore${s.scrollEpoch}'), child: body),
          ),
        ),
      ],
    );
  }
}

/// F21 W3: Manage is one vertical list: icon, name, a one-line status and a
/// red count when something needs the owner.
class _ManageList extends StatelessWidget {
  const _ManageList();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final waiting = s.residents.where((r) => r.tag == 'wait').length;
    final open = s.complaints.where((c) => c.status == 'Open').length, fixing = s.complaints.where((c) => c.status == 'In progress').length;
    final deals = s.dealsOf(h.id).on.length;
    final upi = s.ownerUpi[h.id]?.id ?? '';
    final types = s.rates[h.id]?.length ?? 0;
    final photos = s.photosOf[h.id]?.length;
    final live = s.layouts[h.id]?.length ?? 0;
    final fixes = s.fixesWaiting.length;
    final inv = s.invoice;
    final myE = s.enquiries.where((e) => e.hid == h.id).toList();
    final newE = myE.where((e) => !e.contacted).length;
    void section(String t) => t == 'deals' ? s.openDeals() : t == 'rates' ? s.openRates() : s.update(() => s.moreTab = t);
    final rows = <(String, String, String, int, VoidCallback)>[
      ('userPlus', 'Residents', '${s.residents.length}${waiting > 0 ? ' · $waiting waiting for you' : ''}', waiting, () => section('residents')),
      ('msg', 'Enquiries', newE == 0 ? '${myE.length} from Hostelzy · all replied' : '$newE new · ${myE.length} from Hostelzy', newE, () => section('enquiries')),
      ('wrench', 'Complaints', open + fixing == 0 ? 'None open' : [if (open > 0) '$open open', if (fixing > 0) '$fixing being fixed'].join(' · '), open, () => section('complaints')),
      ('star', 'Deals', deals == 0 ? 'None yet' : '$deals active', 0, () => section('deals')),
      ('wallet', 'Rates and UPI', '$types room type${types == 1 ? '' : 's'}${upi.isEmpty ? ' · no UPI ID yet' : ' · $upi'}', 0, () => section('rates')),
      ('utensils', 'Food menu', 'Breakfast, lunch and dinner, by day', 0, () => section('menu')),
      ('doc', 'House rules', s.rules.isEmpty ? 'None yet' : '${s.rules.first.k} ${s.rules.first.v}', 0, () => section('rules')),
      ('camera', 'Photos', photos == null ? 'Your hostel’s photos' : '$photos photo${photos == 1 ? '' : 's'}', 0, s.openPhotos),
      ('grid', 'Room layouts', '$live live${fixes > 0 ? ' · $fixes fix${fixes == 1 ? '' : 'es'} to check' : ''}', fixes, () => s.go('oLayouts')),
      ('chart', 'Reviews and ranking', '${h.reviews == 0 ? 'No reviews yet' : jsNum(h.rating)} · #${s.rankOf(h.id)} near ${s.lm}', 0, () => s.go('oRank')),
      ('user', 'Team', 'Managers who help you run it', 0, () => s.go('oTeam')),
      ('shield', 'Your plan', s.trialLeft > 0 ? 'Trial · ${s.trialLeft} days left' : switch (inv.status) { 'paid' => 'Paid', 'checking' => 'Checking your payment', 'missing' => 'Payment not found', _ => inv.late > 0 ? '${inv.late} days late' : 'Due' }, inv.late > 0 ? 1 : 0, () => s.go('oPlan')),
    ];
    return Scroll(
      key: ValueKey('oMoreList${s.scrollEpoch}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: Tap(onTap: () => s.update(() => s.sheet = 'switch'), child: PageHead(kicker: h.name, title: 'Manage'))),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows)
                  Tap(
                    key: ValueKey('manage-${r.$2}'),
                    onTap: r.$5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: Ic(r.$1, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(r.$2, w: 800, s: 16), T(r.$3, s: 13, c: p.mu, ell: true)])),
                          if (r.$4 > 0) ...[const SizedBox(width: 8), Container(color: p.ac, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), child: T('${r.$4}', s: 12, w: 800, c: p.ai))],
                          const SizedBox(width: 8),
                          Ic('chev', size: 18, color: p.mu),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ F06 residents

/// Resident tag looks (F06 board 4).
({String label, Color bg, Color fg, Color bd}) residentTag(Pal p, String k) => switch (k) {
  'hz' => (label: 'Came from the app', bg: p.tx, fg: p.bg, bd: p.tx),
  'direct' => (label: 'Walked in', bg: transparent, fg: p.tx, bd: p.tx),
  'wait' => (label: 'Not confirmed', bg: p.ab, fg: p.ad, bd: p.ab),
  _ => (label: 'Joined before Hostelzy', bg: transparent, fg: p.mu, bd: p.dv),
};

class _Residents extends StatelessWidget {
  const _Residents();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final missing = s.unassignedBeds;
    const filters = [('All', null), ('Came from the app', 'hz'), ('Walked in', 'direct'), ('Not confirmed', 'wait'), ('Joined before Hostelzy', 'before')];
    final cur = filters.firstWhere((f) => f.$1 == s.resF).$2;
    // Waiting for their code first, then joins since Hostelzy, then the first import.
    const order = {'wait': 0, 'hz': 1, 'direct': 1, 'before': 2};
    final rows = s.residents.where((r) => cur == null || r.tag == cur).toList();
    mergeSort(rows, compare: (a, b) => order[a.tag]! - order[b.tag]!);
    final by = dayName(appToday.add(const Duration(days: addResidentDays)));
    String beds(List<String> b) => b.length == 1 ? 'Bed ${b[0]}' : 'Beds ${b.sublist(0, b.length - 1).join(', ')} and ${b.last}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missing.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: box(bg: p.ab, w: 2, c: p.ad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Ic('warn', size: 20, color: p.ad)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('${missing.length} taken bed${missing.length == 1 ? ' has' : 's have'} no resident', w: 800, s: 14, c: p.ad),
                      const SizedBox(height: 2),
                      T("${beds(missing)}. Add who's staying there by $by.", s: 13, lh: 1.4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16).copyWith(top: 12, bottom: 12),
          child: Row(
            children: [
              Expanded(child: Cta('Add resident', icon: 'plus', height: 50, px: 16, fs: 15, onTap: s.openAddResident)),
              const SizedBox(width: 8),
              Tap(
                onTap: () => s.go('oInvite'),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: box(w: 2, c: p.tx),
                  child: const Row(children: [Ic('qr', size: 18), SizedBox(width: 10), T('Invite QR', w: 800, s: 15)]),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (final f in filters) ...[
                if (f != filters.first) const SizedBox(width: 6),
                Tap(
                  onTap: () => s.update(() => s.resF = f.$1),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: box(bg: f.$1 == s.resF ? p.tx : transparent, w: 1, c: f.$1 == s.resF ? p.tx : p.dv),
                    child: T('${f.$1} ${s.residents.where((r) => f.$2 == null || r.tag == f.$2).length}', s: 13, w: 600, c: f.$1 == s.resF ? p.bg : p.tx),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: Row(
                    children: [
                      Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: T(initials(r.name), w: 800, s: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            T(r.name, w: 800, s: 15),
                            const SizedBox(height: 1),
                            T('Bed ${r.bed} · ${r.since}${r.confirmed && r.ref != null ? ' · ${r.ref}' : ''}', s: 12, c: p.mu),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (r.lateDays > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                          decoration: box(bg: p.ab, w: 1, c: p.ab),
                          child: T('Late · ${r.lateDays}d', s: 11, w: 800, ls: .04, upper: true, nowrap: true, c: p.ad),
                        ),
                        const SizedBox(width: 6),
                      ],
                      () {
                        final t = residentTag(p, r.tag);
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                          decoration: box(bg: t.bg, w: 1, c: t.bd),
                          child: T(t.label, s: 11, w: 800, ls: .04, upper: true, nowrap: true, c: t.fg),
                        );
                      }(),
                    ],
                  ),
                ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: T('No one here yet.', s: 14, c: p.mu),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// F06 board 6: invite residents by QR, then approve who signs up.
class OwnerInviteScreen extends StatelessWidget {
  const OwnerInviteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // C: the code comes from the server (sample data: the sample code).
    final code = s.inviteCode;
    final link = code == null ? '' : inviteLink(code);
    Widget step(String t, String d) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(t, w: 800, s: 13), const SizedBox(height: 2), T(d, s: 12, c: p.mu)]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: '${hostelById(s.ownHid).name} · Residents', title: 'Invite residents', size: 28)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('oInvite${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      children: [
                        if (code == null)
                          OnShow(s.loadInvite, child: SizedBox(height: 203, child: Center(child: T('Getting your invite code…', s: 14, c: p.mu))))
                        else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: box(bg: const Color(0xFFFFFFFF), w: 2, c: p.tx),
                          child: QrImageView(data: link, size: 175, padding: EdgeInsets.zero, backgroundColor: const Color(0xFFFFFFFF), eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF201E1D)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF201E1D))),
                        ),
                        const SizedBox(height: 12),
                        if (code != null) ...[
                          T(shortLink(link), w: 800, s: 15),
                          const SizedBox(height: 2),
                          T("Stick it at the front desk or send it in your residents' group. Code $code.", s: 13, c: p.mu, align: TextAlign.center),
                          const SizedBox(height: 6),
                          Tap(onTap: () => s.loadInvite(renew: true), child: T('Make a new code (the old link stops working)', s: 12, w: 800, c: p.ad)),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Cta('Share link', icon: 'msg', height: 50, px: 14, fs: 14, bg: p.tx, fg: p.bg, opacity: code == null ? .4 : 1, onTap: code == null ? null : () => s.share('Join ${hostelById(s.ownHid).name} on Hostelzy to pay rent, raise complaints and see the food menu: $link'))),
                        const SizedBox(width: 8),
                        Expanded(child: Cta('Poster PDF', icon: 'print', height: 50, px: 14, fs: 14, bg: transparent, fg: p.tx, border: p.tx, opacity: code == null ? .4 : 1, onTap: code == null ? null : () => s.sharePoster(link))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [step('1 · Scan', 'Name, phone, bed'), step('2 · Sign in', 'With Google'), step('3 · You approve', 'Then they count')]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [const Kicker('Waiting for you'), if (s.signups.isNotEmpty) T('${s.signups.length} to approve', s: 12, w: 800, c: p.ad)],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final g in s.signups)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [T(g.name, w: 800, s: 15), const SizedBox(height: 1), T('Bed ${g.bed} · signed in · phone not verified · ${g.ago}', s: 12, c: p.mu)],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tap(
                                  onTap: () => s.approveSignup(g),
                                  child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, color: p.ac, child: T('Approve', w: 800, s: 14, c: p.ai)),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: 'Not my resident',
                                  button: true,
                                  child: Tap(
                                    onTap: () => s.rejectSignup(g),
                                    child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const Ic('x', size: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (s.signups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: T('No one waiting. New sign-ups show up here.', s: 14, c: p.mu),
                          ),
                      ],
                    ),
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

/// Placeholder QR (25×25 modules, three finder squares), as in the design.
/// The real code comes with the backend.

// ------------------------------------------------------------ F16 rate card

/// F16 board 5: rate card (sharing × AC / non-AC) and each room's type.
/// Lives in Manage → Rates (DECISIONS 2026-10-02, design follow-ups).
class RateCard extends StatelessWidget {
  const RateCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.rateDraft ?? s.rates[s.ownHid]!;
    final acd = s.acDraft ?? {for (final r in s.rooms[s.ownHid]!) r.n: r.ac};
    final rooms = s.rooms[s.ownHid]!.where((r) => r.floor == s.rcFloor).toList();
    final deal = s.dealsOf(s.ownHid);
    Widget head(String t, {Color? c}) => T(t, s: 10, w: 600, ls: .08, upper: true, c: c ?? p.mu);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                  // F14: add or remove rooms and floors after go-live.
                  Tap(
                    onTap: () => s.go('oRooms'),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: box(w: 2, c: p.tx),
                      child: Row(children: [const Ic('room', size: 18), const SizedBox(width: 10), const Expanded(child: T('Rooms · add or remove rooms and floors', w: 800, s: 14)), Ic('chev', size: 18, color: p.mu)]),
                    ),
                  ),
                  // F17: where tenants pay the owner.
                  const UpiCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [const Kicker('Rate card · per month'), T('One price per type', s: 12, c: p.mu)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(children: [Expanded(child: head('Room type')), const SizedBox(width: 8), SizedBox(width: 104, child: head('Walk-in')), const SizedBox(width: 8), SizedBox(width: 86, child: head('Hostelzy'))]),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final n in [2, 3, 4])
                          for (final ac in [false, true])
                            Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                              child: Row(
                                children: [
                                  Expanded(child: Row(children: [T('$n sharing', w: 800, s: 14), const SizedBox(width: 6), RoomTypeTag(ac)])),
                                  const SizedBox(width: 8),
                                  if (d[rateKey(ac, n)] case final v?) ...[
                                    SizedBox(
                                      width: 104,
                                      child: Semantics(
                                        label: 'Walk-in price, $n sharing ${ac ? 'AC' : 'Non-AC'}',
                                        child: Field(
                                          value: fmt(v),
                                          height: 40,
                                          fs: 14,
                                          w: 600,
                                          pad: const EdgeInsets.symmetric(horizontal: 8),
                                          numeric: true,
                                          onChanged: (t) {
                                            final dg = t.replaceAll(RegExp(r'\D'), '');
                                            s.update(() => s.rateDraft![rateKey(ac, n)] = int.tryParse(dg.length > 6 ? dg.substring(0, 6) : dg) ?? 0);
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // F03: the Hostelzy price is the walk-in price minus any monthly deal.
                                    () {
                                      final off = deal.covers(ac) && deal.on.contains('monthly');
                                      return SizedBox(
                                        width: 86,
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(fmt(off ? v - monthlyOff : v), w: 800, s: 15, c: off ? p.gn : p.tx), T(off ? '${fmt(monthlyOff)} off' : 'Same as walk-in', s: 11, c: p.mu)]),
                                      );
                                    }(),
                                  ] else
                                    SizedBox(
                                      width: 198,
                                      child: Tap(
                                        onTap: () => s.addRate(ac, n),
                                        child: Dashed(
                                          color: p.dv,
                                          width: 1,
                                          child: Container(
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            alignment: Alignment.centerLeft,
                                            child: Row(children: [T('Not offered · ', s: 13, w: 600, c: p.mu), T('+ Add', s: 13, w: 800, c: p.ad)]),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                  Tap(
                    onTap: s.openDeals,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      color: deal.on.isEmpty ? p.sf : p.gb,
                      child: Row(
                        children: [
                          Expanded(child: T(deal.on.isEmpty ? 'No Hostelzy deal yet' : 'Deal: ${deal.summary} · ${deal.targetText}', s: 13, w: 800, c: deal.on.isEmpty ? p.tx : p.gn)),
                          const SizedBox(width: 8),
                          T(deal.on.isEmpty ? 'Add' : 'Change', s: 13, w: 800, c: deal.on.isEmpty ? p.ad : p.gn, underline: true),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Kicker('Rooms · Floor ${s.rcFloor}'),
                        Row(
                          children: [
                            T('Floor ', s: 12, c: p.mu),
                            for (final f in floorsOf(s.rooms[s.ownHid]!)) ...[
                              if (f != floorsOf(s.rooms[s.ownHid]!).firstOrNull) T(' · ', s: 12, c: p.mu),
                              Tap(onTap: () => s.update(() => s.rcFloor = f), child: T('$f', s: 12, w: f == s.rcFloor ? 800 : 400, c: f == s.rcFloor ? p.tx : p.mu, underline: f == s.rcFloor)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final r in rooms)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      T('Room ${r.n}', w: 800, s: 15),
                                      const SizedBox(height: 1),
                                      T('${r.share} sharing · ${d[rateKey(acd[r.n]!, r.share)] != null ? '${fmt(d[rateKey(acd[r.n]!, r.share)]!)} walk-in' : 'no price yet'}', s: 12, c: p.mu),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 150,
                                  child: Seg(opts: const [('non', 'Non-AC'), ('ac', 'AC')], cur: acd[r.n]! ? 'ac' : 'non', onPick: (v) => s.setRoomAc(r, v == 'ac'), pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 6)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: T('AC rooms need an AC unit in the layout. The Hostelzy team adds it within 48 hours.', s: 12, c: p.mu, lh: 1.4),
                  ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Cta('Save rate card', icon: 'check', height: 52, px: 16, fs: 15, onTap: s.saveRates),
        ),
      ],
    );
  }
}
