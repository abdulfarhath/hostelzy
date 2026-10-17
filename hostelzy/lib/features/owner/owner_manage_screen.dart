import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';

import '../../data.dart';
import '../../reminders.dart' show clock;
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../meter/stay_tools_screens.dart';
import 'owner_deals.dart';
import 'rate_card.dart';

class OwnerManageScreen extends StatelessWidget {
  const OwnerManageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    if (s.moreTab == 'home') return const _ManageList();
    // F22 Area 3: each Manage page is one job, with its one action pinned at the bottom.
    final (Widget body, Widget? foot) = switch (s.moreTab) {
      'residents' => (const _Residents(), null),
      'deals' => (const OwnerDeals(), Cta('Save deals', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.publishDeals)),
      'rates' => (const RateCard(), Cta('Save', key: const ValueKey('saveRates'), icon: 'check', height: 54, px: 16, fs: 15, onTap: s.saveRates)),
      'complaints' => (const _Complaints(), null),
      'menu' => (const _MenuEditor(), Cta('Save menu', key: const ValueKey('menuSave'), icon: 'check', height: 54, px: 16, fs: 15, opacity: s.menuDirty ? 1 : .4, onTap: s.menuDirty ? s.saveMenu : null)),
      _ => (const _HouseRules(), Cta('Save rules', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.saveRules)),
    };
    // F18: while typing, the header makes room for the field and keyboard.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    const titles = {'residents': 'Residents', 'complaints': 'Complaints', 'deals': 'Deals', 'rates': 'Rates and UPI', 'menu': 'Food menu', 'rules': 'House rules'};
    // Residents keeps its rule under the header; the F22 Area 3 pages draw their own.
    final ruled = s.moreTab == 'residents';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BackBtn(key: const ValueKey('manageBack'), onTap: () => s.update(() => s.moreTab = 'home')),
                const SizedBox(width: 12),
                Expanded(child: PageHead(kicker: '${hostelById(s.ownHid).name} · Manage', title: titles[s.moreTab] ?? 'Manage', gap: 2)),
              ],
            ),
          ),
        Expanded(
          child: Container(
            decoration: ruled ? BoxDecoration(border: Border(top: bs(2, p.dv))) : null,
            child: Scroll(key: ValueKey('oMore${s.scrollEpoch}'), child: body),
          ),
        ),
        if (foot != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: foot,
          ),
      ],
    );
  }
}

/// F22 Area 3: a small outlined action inside a row (`height:40px; border:2px`).
class RowAction extends StatelessWidget {
  const RowAction(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tap(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: box(w: 2, c: p.tx),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [T(label, w: 800, s: 13)]),
        ),
      ),
    );
  }
}

/// F22 Area 3 `complaints`: Open / Being fixed / Fixed, one action per row.
class _Complaints extends StatefulWidget {
  const _Complaints();
  @override
  State<_Complaints> createState() => _ComplaintsState();
}

class _ComplaintsState extends State<_Complaints> {
  String tab = 'Open';
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const next = {'Open': 'Start work', 'In progress': 'Mark fixed'};
    const label = {'Open': 'Open', 'In progress': 'Being fixed', 'Resolved': 'Fixed'};
    int count(String st) => s.complaints.where((c) => c.status == st).length;
    final open = count('Open'), fixing = count('In progress');
    // Newest first.
    final list = s.complaints.where((c) => c.status == tab).toList().reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Seg(
          opts: [('Open', open > 0 ? 'Open $open' : 'Open'), ('In progress', fixing > 0 ? 'Being fixed $fixing' : 'Being fixed'), ('Resolved', 'Fixed')],
          cur: tab,
          onPick: (v) => setState(() => tab = v),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          center: true,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in list)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                  child: VGap(
                    gap: 6,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Rich([sp(context, c.cat), sp(context, ' · ${c.by} · ${c.date}', w: 400, s: 13, c: p.mu)], w: 800, s: 16)),
                          const SizedBox(width: 10),
                          c.status == 'Resolved' ? Tag(label[c.status]!, bg: p.sf, fg: p.mu) : Tag(label[c.status] ?? c.status, bg: p.ab, fg: p.ad),
                        ],
                      ),
                      T(c.text, s: 15),
                      // F21 W3: the resident's photo, if they added one.
                      if (c.photo != null || s.complaintPhotosLocal[c.id] != null)
                        Tap(key: ValueKey('cphoto-${c.id}'), onTap: () => s.openComplaintPhoto(c), child: Row(children: [Ic('camera', size: 14, color: p.ad), const SizedBox(width: 6), T('See photo', s: 13, w: 800, c: p.ad)])),
                      if (c.status == 'Resolved' && c.note.isNotEmpty) T(c.note, s: 13, c: p.mu),
                      if (next[c.status] != null)
                        RowAction(next[c.status]!, onTap: () async {
                          await s.advanceComplaint(c);
                          s.toastMsg('Updated. ${c.by.split(' ')[0]} sees it in the app.');
                        }),
                    ],
                  ),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: T(switch (tab) { 'Open' => 'No open complaints.', 'In progress' => 'Nothing being fixed right now.', _ => 'Nothing fixed yet.' }, s: 14, c: p.mu),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// F22 Area 3 `menu`: day chips, the day's three meals, copy to the next day.
/// F25 NEW-4 (board `w4-oMenuWeek`): a seg *Edit by day · Week table* on top.
class _MenuEditor extends StatelessWidget {
  const _MenuEditor();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final seg = Seg(
      key: const ValueKey('menuView'),
      opts: const [('day', 'Edit by day'), ('week', 'Week table')],
      cur: s.mView,
      onPick: (v) => s.update(() => s.mView = v),
      pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      center: true,
    );
    if (s.mView == 'week') return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: seg), const _MenuWeek()]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: seg), const _MenuDay()]);
  }
}

/// F25 NEW-4 `w4-oMenuWeek`: Mon–Sun × breakfast / lunch / dinner from the
/// week being typed (saved or not), today's row highlighted, empty slots say
/// "Not set". Tap a day to edit it. Fits a 360 px phone without sideways
/// scrolling.
class _MenuWeek extends StatelessWidget {
  const _MenuWeek();
  static const _full = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final week = s.menuDraft ?? blankWeek;
    final empty = weekEmpty(week);
    final unset = [
      for (var i = 0; i < week.length; i++)
        for (final m in meals)
          if (week[i].of(m[0]).trim().isEmpty) '${_full[i]} ${m[1].toLowerCase()}',
    ];
    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: w);
    Widget cell(Widget child, {double? width}) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: child,
    );
    return Container(
      decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            child: Row(
              children: [
                const SizedBox(width: 44),
                for (final m in meals) Expanded(child: cell(fit(Kicker(m[1], nowrap: true)))),
              ],
            ),
          ),
          for (var i = 0; i < week.length; i++)
            Tap(
              key: ValueKey('menuWeek-$i'),
              onTap: () => s.update(() {
                s.mDay = i;
                s.mView = 'day';
              }),
              child: Container(
                decoration: BoxDecoration(color: i == todayIdx ? p.ab : transparent, border: Border(bottom: bs(1, p.hl))),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(fit(T(weekDays[i][0], s: 12, w: 800, c: i == todayIdx ? p.ad : p.tx, nowrap: true)), width: 44),
                      for (final m in meals)
                        Expanded(
                          child: cell(
                            week[i].of(m[0]).trim().isEmpty
                                ? T('Not set', key: ValueKey('menuSlot-$i-${m[0]}'), s: 12, c: p.mu, lh: 1.35)
                                : T(week[i].of(m[0]), key: ValueKey('menuSlot-$i-${m[0]}'), s: 12, lh: 1.35),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 16),
            child: VGap(
              gap: 6,
              children: [
                T('Today is highlighted. Tap a day to edit it. Residents and tenants see the same week.', s: 12, c: p.mu, lh: 1.45),
                if (empty)
                  T('No menu yet. Tenants see “Menu not added yet” on your hostel page until you save one.', key: const ValueKey('menuWeekNote'), s: 12, c: p.ad, w: 600, lh: 1.45)
                else if (unset.isNotEmpty)
                  T(unset.length == 1 ? '${unset.first} is not set yet.' : '${unset.length} meals are not set yet.', key: const ValueKey('menuWeekNote'), s: 12, c: p.ad, w: 600, lh: 1.45),
                if (s.menuDirty) T('Not saved yet. Residents and tenants see it after you tap Save.', s: 12, c: p.ad),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// F22 Area 3 `menu`, Edit by day.
class _MenuDay extends StatelessWidget {
  const _MenuDay();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const full = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final d = s.mDay, to = (s.mDay + 1) % 7;
    final week = s.menuDraft ?? blankWeek;
    // This week's ratings from residents: counts only, never names.
    final votes = [
      for (final m in meals)
        if (s.mealVotes[m[0]] case final v? when v.values.any((n) => n > 0)) '${m[1]}: ${v['good'] ?? 0} good · ${v['okay'] ?? 0} okay · ${v['poor'] ?? 0} poor',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: VGap(
        gap: 12,
        children: [
          if (votes.isNotEmpty)
            Container(
              key: const ValueKey('mealVotes'),
              padding: const EdgeInsets.all(12),
              decoration: box(w: 2, c: p.tx),
              child: VGap(gap: 4, children: [const Kicker('Residents this week'), for (final v in votes) T(v, s: 14, w: 600), T('Counts only. Hostelzy never shows who said what.', s: 12, c: p.mu)]),
            ),
          const _MealTimes(),
          if (s.menuOf(s.ownHid) == null && !s.menuDirty)
            T('No menu yet. Tenants see “Menu not added yet” on your hostel page until you save one.', key: const ValueKey('menuEmpty'), s: 13, c: p.mu, lh: 1.4),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Tap(
                    key: ValueKey('menuDay-$i'),
                    onTap: () => s.update(() => s.mDay = i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: box(bg: i == d ? p.tx : transparent, w: 1, c: i == d ? p.tx : p.dv),
                      child: FittedBox(fit: BoxFit.scaleDown, child: T(weekDays[i][0], s: 13, w: 800, c: i == d ? p.bg : p.tx, nowrap: true)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          for (final m in meals)
            VGap(
              gap: 6,
              children: [
                T('${m[1]} · ${mealSpan(s.timesDraft[m[0]] ?? usualMealTimes[m[0]]!)}', w: 800, s: 13),
                Field(
                  key: ValueKey('menu-$d-${m[0]}'),
                  value: week[d].of(m[0]),
                  placeholder: 'What’s for ${m[1].toLowerCase()}?',
                  onChanged: (v) => s.setMenuMeal(d, m[0], v),
                ),
              ],
            ),
          T(s.menuDirty ? 'Not saved yet. Residents and tenants see it after you tap Save.' : 'Residents and tenants see it after you tap Save.', key: const ValueKey('menuNote'), s: 13, c: s.menuDirty ? p.ad : p.mu),
          OutlineCta(
            'Copy ${full[d]} to ${full[to]}',
            icon: 'copy',
            height: 48,
            fs: 14,
            onTap: () {
              s.copyMenuDay(d, to);
              s.toastMsg('${full[to]} now has ${full[d]}’s menu.');
            },
          ),
        ],
      ),
    );
  }
}

/// F22 Area 3 `rules`: plain fields.
class _HouseRules extends StatelessWidget {
  const _HouseRules();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: VGap(
        gap: 12,
        children: [
          for (var i = 0; i < s.rules.length; i++)
            if (s.rules[i].k != laundryKey)
            VGap(
              gap: 6,
              children: [
                T(s.rules[i].k, w: 800, s: 13),
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
          // F24 #26 (board `oLaundry`).
          const LaundryRow(),
          T('Tenants see these under House rules › on your hostel page.', s: 13, c: p.mu),
        ],
      ),
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
    void section(String t) => t == 'deals' ? s.openDeals() : t == 'rates' ? s.openRates() : t == 'menu' ? s.openMenu() : s.update(() => s.moreTab = t);
    final rows = <(String, String, String, int, VoidCallback)>[
      ('userPlus', 'Residents', '${s.residents.length}${waiting > 0 ? ' · $waiting waiting for you' : ''}', waiting, () => section('residents')),
      ('wrench', 'Complaints', open + fixing == 0 ? 'None open' : [if (open > 0) '$open open', if (fixing > 0) '$fixing being fixed'].join(' · '), open, () => section('complaints')),
      // F24 item 17 (F14): deals, rates and the plan are the owner's.
      if (!s.managerHere) ('star', 'Deals', deals == 0 ? 'None yet' : '$deals active', 0, () => section('deals')),
      if (!s.managerHere) ('wallet', 'Rates and UPI', '$types room type${types == 1 ? '' : 's'}${upi.isEmpty ? ' · no UPI ID yet' : ' · $upi'}', 0, () => section('rates')),
      ('utensils', 'Food menu', 'Breakfast, lunch and dinner, by day', 0, () => section('menu')),
      ('doc', 'House rules', s.rules.isEmpty ? 'None yet' : '${s.rules.first.k} ${s.rules.first.v}', 0, () => section('rules')),
      ('camera', 'Photos', photos == null ? 'Your hostel’s photos' : '$photos photo${photos == 1 ? '' : 's'}', 0, s.openPhotos),
      ('grid', 'Room layouts', '$live live${fixes > 0 ? ' · $fixes fix${fixes == 1 ? '' : 'es'} to check' : ''}', fixes, () {
        s.go('oLayouts');
        s.loadShapeRequests(s.ownHid);
      }),
      ('chart', 'Reviews and ranking', '${h.reviews == 0 ? 'No reviews yet' : jsNum(h.rating)} · #${s.rankOf(h.id)} near ${s.lm}', 0, () => s.go('oRank')),
      ('user', 'Team', 'Managers who help you run it', 0, () => s.go('oTeam')),
      if (!s.managerHere) ('shield', 'Your plan', s.trialLeft > 0 ? 'Trial · ${s.trialLeft} days left' : switch (inv.status) { 'paid' => 'Paid', 'checking' => 'Checking your payment', 'missing' => 'Payment not found', _ => inv.late > 0 ? '${inv.late} days late' : 'Due' }, inv.late > 0 ? 1 : 0, () => s.go('oPlan')),
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
    final q = s.resQ.trim().toLowerCase();
    final rows = s.residents.where((r) => (cur == null || r.tag == cur) && (q.isEmpty || r.name.toLowerCase().contains(q) || r.phone.contains(q.replaceAll(' ', '')) || r.bed.toLowerCase().contains(q))).toList();
    mergeSort(rows, compare: (a, b) => order[a.tag]! - order[b.tag]!);
    final by = dayName(appToday.add(const Duration(days: addResidentDays)));
    String beds(List<String> b) => b.length == 1 ? 'Bed ${b[0]}' : 'Beds ${b.sublist(0, b.length - 1).join(', ')} and ${b.last}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // F22 Area 3: search, and the invite QR one tap away.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(child: Field(key: const ValueKey('resSearch'), value: s.resQ, onChanged: (v) => s.update(() => s.resQ = v), placeholder: 'Search name, phone or bed', height: 48)),
              const SizedBox(width: 8),
              Tap(
                key: const ValueKey('inviteQr'),
                onTap: () => s.go('oInvite'),
                child: Semantics(label: 'Invite QR', child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const Ic('qr', size: 20))),
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
        if (missing.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: Cta('Add resident', icon: 'plus', height: 44, px: 14, fs: 14, expand: false, gap: 10, onTap: s.openAddResident)),
                    ],
                  ),
                ),
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
                            // F24 item 13: the perks locked when they booked.
                            if (r.perks.isNotEmpty) T('Hostelzy deal · price fixed · ${r.perks.join(' · ')}', s: 12, c: p.gn, lh: 1.35),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (r.lateDays > 0) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                            decoration: box(bg: p.ab, w: 1, c: p.ab),
                            child: T('Late · ${r.lateDays}d', s: 11, w: 800, ls: .04, upper: true, ell: true, c: p.ad),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // F22 Area 3: short plain tags; they shrink at large text sizes.
                      Flexible(
                        child: () {
                          final t = residentTag(p, r.tag);
                          final short = const {'Came from the app': 'From the app', 'Joined before Hostelzy': 'Before Hostelzy'}[t.label] ?? t.label;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                            decoration: box(bg: t.bg, w: 1, c: t.bd),
                            child: T(short, s: 11, w: 800, ls: .04, upper: true, ell: true, c: t.fg),
                          );
                        }(),
                      ),
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
        // F19 extras: residents whose layout suggestions are off.
        if (s.mutedHere.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('Layout suggestions off')),
          for (final m in s.mutedHere)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
              child: Row(
                children: [
                  Expanded(child: T(m.name.isEmpty ? 'A resident' : m.name, w: 800, s: 15)),
                  Tap(onTap: () => s.unmuteFixAuthor(m), child: Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), decoration: box(w: 2, c: p.tx), child: const T('Turn on', w: 800, s: 12))),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// F24 Wave 4c: Food menu › Meal times. Residents' meal reminders ring at
/// these; until they're set the app uses the usual times and says so.
class _MealTimes extends StatelessWidget {
  const _MealTimes();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final t = s.timesDraft;
    Widget step(String key, VoidCallback on, String label) => Tap(
      key: ValueKey(key),
      onTap: on,
      child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: T(label, w: 800, s: 18)),
    );
    Widget clockStep(String k, bool end, int m) => Row(
      children: [
        step('mt-$k-${end ? 'e' : 's'}-', () => s.nudgeMealTime(k, end: end, by: -15), '−'),
        Expanded(child: Center(child: T(clock(m), w: 800, s: 14, nowrap: true))),
        step('mt-$k-${end ? 'e' : 's'}+', () => s.nudgeMealTime(k, end: end, by: 15), '+'),
      ],
    );
    return Container(
      key: const ValueKey('mealTimes'),
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: VGap(
        gap: 10,
        children: [
          const Kicker('Meal times'),
          if (t.isEmpty) ...[
            T('Not set. Residents’ meal reminders use the usual times: breakfast 7:30, lunch 12:30, dinner 8:00.', s: 13, c: p.mu, lh: 1.4),
            OutlineCta('Set meal times', key: const ValueKey('mealTimesSet'), icon: 'clock', height: 46, fs: 14, onTap: s.startMealTimes),
          ] else ...[
            for (final m in meals)
              VGap(
                gap: 6,
                children: [
                  T(m[1], w: 800, s: 13),
                  Row(
                    children: [
                      Expanded(child: clockStep(m[0], false, (t[m[0]] ?? usualMealTimes[m[0]]!).$1)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: T('to', s: 13, c: p.mu)),
                      Expanded(child: clockStep(m[0], true, (t[m[0]] ?? usualMealTimes[m[0]]!).$2)),
                    ],
                  ),
                ],
              ),
            T('Residents’ meal reminders ring at the start time.', s: 12, c: p.mu),
            Tap(key: const ValueKey('mealTimesClear'), onTap: s.clearMealTimes, child: T('Use the usual times', s: 13, w: 700, c: p.ad, underline: true)),
          ],
        ],
      ),
    );
  }
}
