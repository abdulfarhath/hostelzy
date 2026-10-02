import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F22 Area 3, half B (Owner): the Manage pages (Deals, Rates and UPI,
// Complaints, Food menu, House rules), Reviews and ranking on one page, Your
// plan as one screen with a state, the Fair Play check and Team.

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1}) async {
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shell = AppScope(state: state, child: const HostelzyShell(bare: true));
  await tester.pumpWidget(MaterialApp(home: scale == 1 ? shell : MediaQuery(data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)), child: shell)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  mapTiles = false;

  testWidgets('F22 Area 3: Deals are switches, up to 3, saved from the bottom', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Deals')));
    expect(s.moreTab, 'deals');
    expect(s.dealDraft, {'exit', 'monthly', 'laundry'});
    expect(find.text('Deals'), findsOneWidget);
    expect(find.text('₹200 off every month'), findsOneWidget);
    expect(find.textContaining('3 of 3 on.'), findsOneWidget);
    // A fourth is refused; switching one off makes room.
    await _tap(tester, find.byKey(const ValueKey('deal-first')));
    expect(s.toast, 'Pick up to 3. Remove one first.');
    await tester.pump(const Duration(seconds: 3)); // let the toast go
    await _tap(tester, find.byKey(const ValueKey('deal-laundry')));
    await _tap(tester, find.byKey(const ValueKey('deal-first')));
    expect(s.dealDraft, {'exit', 'monthly', 'first'});
    expect(s.dealsOf('anjani').on, {'exit', 'monthly', 'laundry'}); // not yet saved
    await _tap(tester, find.text('Save deals'));
    expect(s.dealsOf('anjani').on, {'exit', 'monthly', 'first'});
    s.dispose();
  });

  testWidgets('F22 Area 3: Rates and UPI is one table, one UPI ID, Test with ₹1, Rooms and floors', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Rates and UPI')));
    expect(s.moreTab, 'rates');
    expect(find.text('Room type'), findsOneWidget);
    expect(find.text('3 sharing AC'), findsOneWidget);
    // The Hostelzy price is the walk-in price less the monthly deal.
    final v = s.rateDraft![rateKey(false, 3)]!;
    expect(find.text(fmt(v - monthlyOff)), findsWidgets);
    // A type not offered yet can be added.
    expect(find.text('+ Add'), findsOneWidget);
    await _tap(tester, find.text('+ Add'));
    expect(find.text('+ Add'), findsNothing);
    await tester.enterText(find.bySemanticsLabel('Walk-in price, 3 sharing AC'), '9500');
    await tester.pump();
    expect(s.rateDraft![rateKey(true, 3)], 9500);
    expect(find.text('Your UPI ID'), findsOneWidget);
    await _tap(tester, find.text('Test with ₹1'));
    expect(s.lastLink!.queryParameters['am'], '1');
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.byKey(const ValueKey('saveRates')));
    expect(s.rates['anjani']![rateKey(true, 3)], 9500);
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.text('Rooms and floors ›'));
    expect(s.screen, 'oRooms');
    s.dispose();
  });

  testWidgets('F22 Area 3: Complaints are Open / Being fixed / Fixed with one action each', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'complaints');
    await _pump(tester, s);
    expect(find.text('Open 2'), findsOneWidget);
    expect(find.text('Being fixed 1'), findsOneWidget);
    expect(find.text('Room not swept for three days.'), findsOneWidget);
    expect(find.text('No hot water in bathroom 2 since Monday.'), findsNothing);
    expect(find.text('Start work'), findsNWidgets(2));
    await _tap(tester, find.text('Start work').first);
    expect(s.complaints.firstWhere((c) => c.id == 4).status, 'In progress');
    expect(find.text('Open 1'), findsOneWidget);
    await _tap(tester, find.text('Being fixed 2'));
    expect(find.text('Mark fixed'), findsNWidgets(2));
    await _tap(tester, find.text('Mark fixed').first);
    expect(s.complaints.where((c) => c.status == 'Resolved').length, 2);
    await _tap(tester, find.text('Fixed'));
    expect(find.text('Drops every night after 11 pm.'), findsOneWidget);
    expect(find.text('Start work'), findsNothing);
    expect(find.text('Mark fixed'), findsNothing);
    s.dispose();
  });

  testWidgets('F22 Area 3: Food menu is day chips, three meals, copy to the next day', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'menu');
    await _pump(tester, s);
    expect(find.text('Breakfast · 7:30 – 9:30'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('menuDay-4')));
    expect(s.mDay, 4);
    expect(find.text('Copy Friday to Saturday'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'Masala dosa');
    await tester.pump();
    final m = s.menuDraft!;
    expect(m[4].b, 'Masala dosa');
    expect(find.text('Not saved yet. Residents and tenants see it after you tap Save.'), findsOneWidget);
    await _tap(tester, find.text('Copy Friday to Saturday'));
    expect((s.menuDraft![5].b, s.menuDraft![5].l, s.menuDraft![5].n), (m[4].b, m[4].l, m[4].n));
    expect(s.toast, 'Saturday now has Friday’s menu.');
    // Sunday copies to Monday.
    await _tap(tester, find.byKey(const ValueKey('menuDay-6')));
    expect(find.text('Copy Sunday to Monday'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // let the toast go
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    expect((s.moreTab, s.menuOf('anjani')![4].b, s.menuOf('anjani')![5].b), ('home', 'Masala dosa', 'Masala dosa'));
    s.dispose();
  });

  testWidgets('F22 Area 3: House rules are plain fields with Save rules', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'rules');
    await _pump(tester, s);
    expect(find.text('Gate closes'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '11 pm');
    await tester.pump();
    expect(s.rules.first.v, '11 pm');
    await _tap(tester, find.text('Save rules'));
    expect(s.toast, 'Rules saved. Residents and new tenants see them now.');
    s.dispose();
  });

  testWidgets('F22 Area 3: Reviews and ranking on one page: tiles, To rank higher, Reply', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Reviews and ranking')));
    expect(s.screen, 'oRank');
    final h = hostelById('anjani');
    expect(find.text(jsNum(h.rating)), findsOneWidget);
    expect(find.text('${h.reviews} verified stays'), findsOneWidget);
    expect(find.text('#${s.rankOf('anjani')}'), findsOneWidget);
    expect(find.textContaining('To rank higher: '), findsOneWidget);
    // The rank tile opens how ranking works.
    await _tap(tester, find.byKey(const ValueKey('rankHow')));
    expect(s.sheet, 'rank');
    s.update(() => s.sheet = null);
    await tester.pump();
    // A Fair Play strike shows as a tip.
    s.update(() => s.strikes['anjani'] = 1);
    await tester.pump();
    expect(find.textContaining('Fair Play strikes'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F22 Area 3: Your plan is one screen; oPlan, oInvoice and oPayStatus show it', (tester) async {
    // Free trial: no actions.
    final t = AppState(start: 'oPlan', role: 'owner');
    await _pump(tester, t);
    expect(find.text('FREE TRIAL'), findsOneWidget);
    expect(find.text('${t.trialLeft} days left'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Pay to'), findsOneWidget);
    expect(find.text('Invoice'), findsOneWidget);
    expect(find.byKey(const ValueKey('planPay')), findsNothing);
    t.dispose();

    // Due: pay by UPI, or enter the UPI reference.
    final d = AppState(start: 'oInvoice', role: 'owner', plan: 'late0');
    await _pump(tester, d);
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Pay ₹999 by UPI'), findsOneWidget);
    await _tap(tester, find.text('I’ve paid · enter UPI reference'));
    expect(d.sheet, 'utr');
    d.dispose();

    // Late: a red card; deals pause only from 15 days.
    final l5 = AppState(start: 'oPlan', role: 'owner', plan: 'late5');
    await _pump(tester, l5);
    expect(find.text('5 DAYS LATE'), findsOneWidget);
    expect(find.textContaining('to keep your deals showing'), findsOneWidget);
    l5.dispose();
    final l15 = AppState(start: 'oPlan', role: 'owner', plan: 'late15');
    await _pump(tester, l15);
    expect(find.textContaining('Your deals are paused until it’s paid'), findsOneWidget);
    l15.dispose();

    // Checking: one action, WhatsApp Hostelzy.
    final c = AppState(start: 'oPayStatus', role: 'owner', plan: 'checking');
    await _pump(tester, c);
    expect(find.text('CHECKING YOUR PAYMENT'), findsOneWidget);
    expect(find.textContaining('UPI reference 4021 8834 1297'), findsOneWidget);
    await _tap(tester, find.text('WhatsApp Hostelzy'));
    expect(c.lastLink.toString(), contains('wa.me/919059790014'));
    c.dispose();

    // Paid: Share receipt; the trial is listed under Before.
    final p = AppState(start: 'oPlan', role: 'owner', plan: 'paid');
    await _pump(tester, p);
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('Free trial'), findsOneWidget);
    await _tap(tester, find.text('Share receipt'));
    expect(p.lastShare, contains(p.invoice.ref));
    p.dispose();
  });

  testWidgets('F22 Area 3: the Fair Play check shows the real time left, the timeline, a reply and the fix', (tester) async {
    final s = AppState(start: 'oCase', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Fair Play check'), findsOneWidget);
    expect(find.text('Reply within 47 hours'), findsOneWidget);
    expect(find.textContaining('Sun 4 Oct, 6:40 pm'), findsNothing); // no fixed sample deadline
    expect(find.text('Held bed 102-B'), findsOneWidget);
    expect(find.text('Add a photo as proof'), findsNothing);
    // An empty reply is refused; a written one goes to the team.
    await _tap(tester, find.text('Send my reply'));
    expect(s.toast, 'Write what happened, or fix the resident.');
    await tester.pump(const Duration(seconds: 3)); // let the toast go
    await tester.enterText(find.byType(EditableText).first, 'Teja came through a friend.');
    await tester.pump();
    await _tap(tester, find.text('Send my reply'));
    expect((s.cases.first.status, s.cases.first.ownerReply), ('decide', 'Teja came through a friend.'));
    expect(find.text('Read the Fair Play rules'), findsOneWidget);
    s.dispose();

    final f = AppState(start: 'oCase', role: 'owner');
    await _pump(tester, f);
    await _tap(tester, find.text('Change Teja to “Came from the app”'));
    expect((f.cases.first.status, f.strikes['anjani'] ?? 0), ('closed', 0));
    f.dispose();
  });

  testWidgets('F22 Area 3: Team is you plus managers, what managers can’t see, Add a manager', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Team')));
    expect(s.screen, 'oTeam');
    expect(find.text('YOU'), findsOneWidget);
    expect(find.textContaining('Managers can’t see your plan, deals, rates or Fair Play notices.'), findsOneWidget);
    await _tap(tester, find.text('Add a manager'));
    expect(s.sheet, 'manager');
    s.dispose();
  });

  for (final c in const [
    ('oMore', 'deals', null),
    ('oMore', 'rates', null),
    ('oMore', 'complaints', null),
    ('oMore', 'menu', null),
    ('oMore', 'rules', null),
    ('oRank', null, null),
    ('oPlan', null, null),
    ('oPlan', null, 'late15'),
    ('oPlan', null, 'checking'),
    ('oPlan', null, 'paid'),
    ('oPlan', null, 'missing'),
    ('oCase', null, null),
    ('oTeam', null, null),
  ]) {
    for (final theme in const ['light', 'dark']) {
      testWidgets('F22 Area 3: ${c.$1}${c.$2 != null ? ' · ${c.$2}' : ''}${c.$3 != null ? ' · ${c.$3}' : ''} fits at 2× text ($theme)', (tester) async {
        final s = AppState(start: c.$1, role: 'owner', moreTab: c.$2, plan: c.$3, theme: theme);
        await _pump(tester, s, scale: 2);
        expect(tester.takeException(), isNull);
        s.dispose();
      });
    }
  }
}
