import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../food/save_food_screens.dart';
import '../layouts/layout_fixes_screens.dart' show FixPhotoThumb;
import '../plan/plan_screens.dart';

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

/// F25 A6: how full the hostel is. A bed counts as full when a resident is in
/// it: `booked` (taken) or `soon` (taken, the resident leaves soon). Holds are
/// not full (the tenant hasn't moved in), nor are free beds. Null when the
/// hostel has no beds yet.
({int full, int total, int pct})? occupancy(AppState s) {
  final c = countBeds(s);
  if (c.t == 0) return null;
  final full = c.booked + c.soon;
  return (full: full, total: c.t, pct: (full * 100 / c.t).round());
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
        ? HoldRequest(id: h.id, name: 'Hostelzy tenant', bed: h.bed, type: 'Free hold', secs: s.holdSecsOf(h), start: h.start, note: 'Code ${h.ref ?? ''} · placed in the Hostelzy app', hold: h.id, trusted: h.trusted)
        : HoldRequest(id: h.id, name: s.meName.isEmpty ? 'Hostelzy user' : s.meName, bed: h.bed, type: 'Free hold', secs: s.holdSecs, start: h.start, note: 'Placed from the Hostelzy app', hold: h.id, trusted: s.level == 'trusted'),
  if (s.ownHid == 'anjani' && !s.onServer) ...s.reqs,
];

class OwnerTodayScreen extends StatelessWidget {
  const OwnerTodayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final c = countBeds(s);
    final occ = occupancy(s);
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
          // F27-3: tonight's headcount, under the Fair Play pin.
          OnShow(() => s.loadFood(s.ownHid), child: const HeadcountCard()),
          // F21 W3: one list of what needs the owner, soonest first.
          const NeedsYouNow(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('This month')),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: box(w: 2, c: p.tx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
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
                // F25 A6: how full the hostel is; hidden until it has beds.
                if (occ != null) _Occupancy(occ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// F25 A6: "78% full" and the occupancy bar, inside the This month card.
class _Occupancy extends StatelessWidget {
  const _Occupancy(this.o);
  final ({int full, int total, int pct}) o;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      key: const ValueKey('occupancy'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          T('${o.pct}% full', key: const ValueKey('occFull'), w: 800, s: 20),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('occBar'),
            height: 10,
            decoration: box(bg: p.sf, w: 1, c: p.tx),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (o.full > 0) Expanded(flex: o.full, child: Container(key: const ValueKey('occBarFill'), color: p.tx)),
                if (o.total > o.full) Expanded(flex: o.total - o.full, child: const SizedBox()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          T('${o.full} of ${o.total} beds have a resident. Holds don’t count.', s: 12, c: p.mu, lh: 1.35),
        ],
      ),
    );
  }
}

/// One thing that needs the owner, with its own buttons.
typedef NeedItem = ({String key, String icon, String title, String sub, String right, bool urgent, List<(String, String, VoidCallback)> btns, Widget? badge, Widget? extra});

/// The three Today tabs (F26 #18), in this order.
const needGroups = [('holds', 'Holds'), ('payments', 'Payments'), ('fixes', 'Fixes')];

/// F26 #18 owner Today: what needs the owner in three tabs with counts.
/// Holds (hold requests, then notices and bed moves), Payments (payments to
/// confirm, refunds) and Fixes (layout fixes, quick fixes, broken things).
/// The most urgent tab opens first; all empty = "Nothing needs you now".
class NeedsYouNow extends StatefulWidget {
  const NeedsYouNow({super.key});
  @override
  State<NeedsYouNow> createState() => _NeedsYouNowState();
}

/// Each group's items, soonest first inside a group.
Map<String, List<NeedItem>> needItems(AppState s, Pal p) {
  final all = <NeedItem>[
      for (final r in [...allRequests(s)]..sort((a, b) => (a.secs - (s.now - a.start) / 1000).compareTo(b.secs - (s.now - b.start) / 1000)))
        (
          key: 'hold-${r.id}',
          icon: 'clock',
          title: 'Hold on bed ${r.bed}',
          sub: '${r.name} · ${r.type}${r.secs > freeHoldSecs ? ' · 2 h' : ''}${r.note.isEmpty ? '' : ' · “${r.note}”'}',
          right: cd(r.secs - (s.now - r.start) / 1000),
          urgent: true,
          btns: [('Confirm', 'check', () => s.confirmHoldReq(r)), ('Decline', 'x', () => s.declineHoldReq(r))],
          badge: r.trusted
              ? Tap(
                  onTap: () => s.update(() {
                    s.trustedReq = r.id;
                    s.sheet = 'trusted';
                  }),
                  child: Container(color: p.tx, padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T('Trusted tenant', s: 11, w: 800, ls: .05, upper: true, c: p.bg)),
                )
              : null,
          // F26 #9: the owner has this hold in front of them: "Owner reviewing" for the tenant.
          extra: r.hold == null ? null : OnShow(() => s.markHoldsSeen([r.hold!]), child: const SizedBox.shrink()),
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
          extra: null,
        ),
      for (final f in s.fixesWaiting)
        // F19 extras: a repair, a quick fix, or a layout fix to compare.
        (
          key: 'fix-${f.id}',
          icon: f.broken ? 'wrench' : 'grid',
          title: f.broken ? 'Broken: ${f.item}, Room ${f.room}' : f.quick ? 'Quick fix: ${f.quickLine}, Room ${f.room}' : 'Layout fix for Room ${f.room}',
          sub: [f.broken ? 'From a resident’s quick fix' : 'From ${f.author}', if (f.note.isNotEmpty) '“${f.note}”', if (f.photo != null) '1 photo'].join(' · '),
          right: ago(DateTime.now().millisecondsSinceEpoch - f.at),
          urgent: false,
          btns: f.broken
              ? [('Start work', 'wrench', () => s.setRepair(f, 'working')), ('Not broken', 'x', () => s.setRepair(f, 'not_broken'))]
              : f.quick
              ? [('Got it', 'check', () => s.ackQuickFix(f, true)), ('Not right', 'x', () => s.ackQuickFix(f, false))]
              : [('Compare', 'arrow', () => s.openFix(f))],
          badge: null,
          extra: f.photo != null ? FixPhotoThumb(f) : null,
        ),
      // F24: notices and moves from residents, waiting for an answer.
      for (final m in s.openMoves)
        (
          key: 'move-${m.id}',
          icon: m.kind == 'vacate' ? 'logout' : 'swap',
          title: m.kind == 'vacate' ? '${m.name} gave notice' : '${m.name} asks to move to bed ${m.toBed}',
          sub: [if (m.bed.isNotEmpty) 'Bed ${m.bed}', if (m.kind == 'vacate' && m.lastDay != null) 'Last day ${dayMon(m.lastDay!)}', if (m.reason.isNotEmpty) m.reason].join(' · '),
          right: m.at > 0 ? ago(s.now - m.at) : 'Today',
          urgent: false,
          btns: [('Accept', 'check', () => s.answerMove(m, true)), ('Say no', 'x', () => s.answerMove(m, false))],
          badge: null,
          extra: null,
        ),
      // F24: refunds for residents who moved out (due 7 days after leaving).
      for (final r in s.refundsToDo)
        (
          key: 'refund-${r.stayKey}',
          icon: 'wallet',
          title: r.status == 'not_received' ? '${r.name} hasn’t got the refund' : r.status == 'sent' ? 'Refund sent to ${r.name}' : 'Refund ${fmt(r.amt)} to ${r.name}',
          sub: r.status == 'sent' ? 'UPI ref ${utrSpaced(r.utr)} · waiting for them to confirm' : 'Moved out ${dayMon(r.leftOn)} · due ${dayMon(r.due)}',
          right: r.status == 'sent' ? '' : (r.due.isBefore(appToday) ? 'Late' : 'Due ${dayMon(r.due)}'),
          urgent: r.status != 'sent' && (r.status == 'not_received' || r.due.isBefore(appToday)),
          btns: r.status == 'sent' ? <(String, String, VoidCallback)>[] : [('Mark refunded', 'check', () => s.openRefund(r))],
          badge: null,
          extra: null,
        ),
      // F23: a shared thing (or a room's geyser) marked not working.
      for (final a in s.brokenThings)
        (
          key: 'broken-${a.id}',
          icon: 'wrench',
          title: 'Broken: ${a.label}, ${s.floorName(a.floor).toLowerCase()}',
          sub: [if (a.inRooms) s.amenityWhere(a), a.byResident ? 'Marked by a resident' : 'Marked by you'].join(' · '),
          right: a.at > 0 ? ago(s.now - a.at) : 'Today',
          urgent: false,
          btns: [('Fixed', 'check', () => s.setAmenityWorking(a, true))],
          badge: null,
          extra: null,
        ),
      // F26 (lead): the old Today cards are items now. Board 10: "Still N
      // free beds?" every 3 days (Holds).
      if (s.needsConfirm(s.ownHid))
        () {
          final free = s.rooms[s.ownHid]!.expand((r) => r.beds).where((b) => b.state == 'free').toList();
          final n = free.length, days = s.confirmed[s.ownHid];
          return (
            key: 'freeBeds-${s.ownHid}',
            icon: 'bed',
            title: 'Still $n free ${n == 1 ? 'bed' : 'beds'}?',
            sub: '${days == null ? 'Not confirmed yet' : 'Last confirmed $days days ago'}. Fresh beds rank higher. Not confirmed for $staleAfterDays days: tenants see “Availability not confirmed”.',
            right: '',
            urgent: false,
            btns: <(String, String, VoidCallback)>[('Yes, all $n free', 'check', () => s.confirmBeds(s.ownHid)), ('Update', 'chev', () => s.tab('oBeds'))],
            badge: null,
            extra: free.isEmpty ? null : _Chips([for (final b in free) b.id]),
          );
        }(),
      // F03 (F24 Wave 4d): "Are your rates still right?" monthly (Payments).
      if (s.needsRatesConfirm(s.ownHid))
        () {
          final at = s.ratesConfirmedAt[s.ownHid];
          final rc = s.rates[s.ownHid] ?? const <String, int>{};
          final keys = rc.keys.toList()..sort((a, b) => (a.startsWith('ac') ? 1 : 0).compareTo(b.startsWith('ac') ? 1 : 0));
          return (
            key: 'rates-${s.ownHid}',
            icon: 'wallet',
            title: 'Are your rates still right?',
            sub: '${at == null ? 'Not confirmed yet' : 'Last confirmed ${dayMon(at.toLocal())}'}. Not confirmed for a month: tenants see “Not confirmed in over a month” on your prices.',
            right: '',
            urgent: false,
            btns: <(String, String, VoidCallback)>[('Rates still right', 'check', () => s.confirmRates(s.ownHid)), ('Change', 'chev', s.openRates)],
            badge: null,
            extra: keys.isEmpty ? null : _Chips([for (final k in keys) '${k.replaceFirst(RegExp('^(ac|non)'), '')} sharing ${k.startsWith('ac') ? 'AC' : 'non-AC'} · ${fmt(rc[k]!)}']),
          );
        }(),
      // F12/F18: Hostelzy drew a new layout for a room; the owner checks and
      // publishes it (this was the "New layout" tag on the old Rooms list).
      for (final r in s.rooms[s.ownHid]!.where((r) => s.layoutOf(s.ownHid, r.n)?.pending == true))
        (
          key: 'newLayout-${r.n}',
          icon: 'room',
          title: 'New layout for Room ${r.label}',
          sub: 'Drawn by Hostelzy · check it, then publish',
          right: '',
          urgent: false,
          btns: <(String, String, VoidCallback)>[('Check', 'arrow', () => s.ownerLayout(r.n))],
          badge: null,
          extra: null,
        ),
      // F12: every 3 months, do the room layouts still match? (Fixes)
      if ((s.layoutConfirmed[s.ownHid] ?? 0) >= layoutConfirmEvery && s.layouts[s.ownHid] != null)
        (
          key: 'layouts-${s.ownHid}',
          icon: 'grid',
          title: 'Do your room layouts still match?',
          sub: 'Last confirmed ${s.layoutConfirmed[s.ownHid]} days ago. Check that beds, fans, AC and windows are still where the layouts show them.',
          right: '',
          urgent: false,
          btns: <(String, String, VoidCallback)>[('All still correct', 'check', () => s.confirmLayouts(s.ownHid)), ('Review', 'chev', () => s.go('oLayouts'))],
          badge: null,
          extra: null,
        ),
    ];
  String group(NeedItem it) => switch (it.key.split('-').first) {
    'hold' || 'move' || 'freeBeds' => 'holds',
    'pay' || 'refund' || 'rates' => 'payments',
    _ => 'fixes',
  };
  return {for (final (g, _) in needGroups) g: [for (final it in all) if (group(it) == g) it]};
}

/// The tab that opens first: the first group with something urgent (a hold's
/// countdown, a late refund), else the first with anything in it.
String urgentGroup(Map<String, List<NeedItem>> m) =>
    needGroups.map((g) => g.$1).where((g) => m[g]!.any((it) => it.urgent)).firstOrNull ?? needGroups.map((g) => g.$1).where((g) => m[g]!.isNotEmpty).firstOrNull ?? needGroups.first.$1;

class _NeedsYouNowState extends State<NeedsYouNow> {
  /// The tab the owner picked; null = the most urgent one.
  String? picked;

  /// Perf: the hold countdowns (and their order) change every second, so this
  /// card ticks on its own; the rest of Today doesn't rebuild with it.
  @override
  Widget build(BuildContext context) => Ticking(_build);

  Widget _build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final m = needItems(s, p);
    final total = m.values.fold<int>(0, (a, l) => a + l.length);
    // A picked tab that has emptied falls back to the most urgent one.
    final cur = picked != null && m[picked]!.isNotEmpty ? picked! : urgentGroup(m);
    final items = m[cur]!;
    return Column(
      key: const ValueKey('needsYou'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 6), child: Kicker('Needs you · most urgent first')) else const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: box(w: 2, c: p.tx),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (g, label) in needGroups)
                  Expanded(
                    child: Tap(
                      key: ValueKey('needTab-$g'),
                      onTap: () => setState(() => picked = g),
                      child: Semantics(
                        selected: g == cur,
                        label: '$label, ${m[g]!.length}',
                        child: ExcludeSemantics(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            color: g == cur ? p.tx : transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                T('${m[g]!.length}', key: ValueKey('needCount-$g'), w: 800, s: 18, lh: 1.1, c: g == cur ? p.bg : p.tx),
                                T(label, s: 11, w: 600, c: g == cur ? p.bg : p.tx, align: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (total == 0)
          Padding(
            key: const ValueKey('needsNothing'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Dashed(
              color: p.dv,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: VGap(
                gap: 6,
                stretch: false,
                children: [
                  const Ic('check', size: 24),
                  const T('Nothing needs you now', w: 800, s: 18),
                  T('New holds, payments and fixes show up here.', s: 13, c: p.mu, lh: 1.45),
                ],
              ),
            ),
          )
        else
          Column(
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
                                if (it.badge != null) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Align(alignment: Alignment.centerLeft, child: it.badge)),
                                T(it.sub, s: 12, c: p.mu, lh: 1.35),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          T(it.right, w: 800, s: 14, tab: true, c: it.urgent ? p.ad : p.mu),
                        ],
                      ),
                      ?it.extra,
                      Row(
                        children: [
                          for (final (i, b) in it.btns.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: Cta(b.$1, key: ValueKey('${it.key}-btn$i'), icon: b.$2, height: 40, px: 14, fs: 13, bg: i == 0 ? p.ac : transparent, fg: i == 0 ? p.ai : p.tx, border: i == 0 ? p.ac : p.tx, onTap: b.$3)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
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
                    : [T('Fair Play: strike $n of 3', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(s.strikeLine(s.ownHid), s: 13)],
              ),
            ),
            Ic('chev', size: 18, color: p.ad),
          ],
        ),
      ),
    );
  }
}

/// Small outlined chips (free beds, rate cards) under a Today item.
class _Chips extends StatelessWidget {
  const _Chips(this.labels);
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final l in labels) Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), decoration: box(w: 1, c: p.tx), child: T(l, s: 12, w: 800)),
      ],
    );
  }
}
