import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/reminders.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F20 Reminders: flow tests (the scheduler is a [NoReminders] that keeps
// what would ring).

Future<void> _pump(WidgetTester tester, AppState state) async {
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = const Size(410, 864);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppScope(state: state, child: const HostelzyShell(bare: true)),
    ),
  );
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

  test('F20: water rings every interval inside the awake hours', () {
    expect(const WaterPlan().slots.length, 28); // design: "That's 28 reminders a day"
    expect(const WaterPlan(every: 20).slots.length, 42);
    expect(const WaterPlan(every: 90).slots, [480, 570, 660, 750, 840, 930, 1020, 1110, 1200, 1290]);
    expect(const WaterPlan(every: 120, from: 9 * 60, to: 21 * 60).slots.last, 19 * 60);
    expect((clock(16 * 60 + 30), clock(21 * 60, short: true), clock(0), clock(12 * 60)), ('4:30 pm', '9 pm', '12:00 am', '12:00 pm'));
  });

  testWidgets('F20: water on, change it, add and delete my reminder, count a glass', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    final rem = NoReminders(available: true);
    await s.startReminders(rem);
    await _pump(tester, s);
    expect(rem.applied, isEmpty); // off by default

    await _tap(tester, find.text('Reminders · off'));
    expect(s.screen, 'reminders');
    expect(find.text('Every 30 min · 8 am – 10 pm'), findsOneWidget);
    expect(find.text('Reminders ring from this phone, even offline. Nothing rings outside your awake hours.'), findsOneWidget);
    // A tenant has no hostel reminders.
    expect(find.textContaining('From Anjani'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('waterSwitch')));
    await tester.pump();
    expect(s.water.on, isTrue);
    expect(rem.applied.where((r) => r.kind == 'water').length, 28);
    expect(rem.applied.first.title, 'Time for a glass of water');
    expect(s.toast, 'Water reminders on: every 30 min, 8 am – 10 pm.');

    // Water sheet: every 60 min, goal 9.
    await _tap(tester, find.text('Change'));
    expect(s.sheet, 'water');
    await _tap(tester, find.text('60 min'));
    await _tap(tester, find.bySemanticsLabel('One more'));
    expect(find.textContaining('14 reminders a day', findRichText: true), findsOneWidget);
    await _tap(tester, find.text('Save'));
    await tester.pump();
    expect((s.sheet, s.water.every, s.water.goal), (null, 60, 9));
    expect(rem.applied.where((r) => r.kind == 'water').length, 14);
    expect(rem.applied.map((r) => r.id).toSet().length, rem.applied.length); // ids unique

    // A glass from the app.
    await _tap(tester, find.text('I had a glass'));
    await tester.pump();
    expect((s.glasses, await rem.glasses()), (1, 1));
    expect(find.text('1 of 9 glasses today'), findsOneWidget);

    // My reminder: quick add Medicine (9 pm, every day).
    await _tap(tester, find.text('+ Add'));
    expect(s.sheet, 'addRem');
    await _tap(tester, find.text('Medicine'));
    await _tap(tester, find.text('Add reminder'));
    await tester.pump();
    expect(s.myRems.single.name, 'Take medicine');
    expect(s.toast, 'Added: Take medicine at 9:00 pm, every day.');
    final med = rem.applied.where((r) => r.kind == 'mine').single;
    expect((med.title, med.minute, med.weekday), ('Take medicine', 21 * 60, null));
    expect(find.text('9:00 pm · every day'), findsOneWidget);

    // Weekdays: one ring per day; switching it off stops them.
    await _tap(tester, find.text('+ Add'));
    await _tap(tester, find.text('Lunch'));
    await _tap(tester, find.text('Weekdays'));
    await _tap(tester, find.text('Add reminder'));
    await tester.pump();
    expect(rem.applied.where((r) => r.title == 'Lunch').map((r) => r.weekday).toList(), [1, 2, 3, 4, 5]);
    await s.toggleRem(s.myRems.last.id);
    expect(rem.applied.where((r) => r.title == 'Lunch'), isEmpty);

    // Outside the awake hours: refused, with why.
    s.openAddRem();
    s.remName = 'Late';
    s.remAt = 23 * 60 + 30;
    await s.saveRem();
    expect(s.toast, 'That’s outside your awake hours (8 am – 10 pm). Change them under Drink water first.');
    s.update(() => s.sheet = null);
    await tester.pump();

    // Delete from the edit sheet.
    await _tap(tester, find.text('Take medicine'));
    expect((s.sheet, s.remEdit), ('addRem', s.myRems.first.id));
    await _tap(tester, find.text('Delete reminder'));
    await tester.pump();
    expect(s.myRems.map((r) => r.name), ['Lunch']);
    expect(rem.applied.where((r) => r.kind == 'mine'), isEmpty);

    // Saved on the phone and brought back.
    final again = AppState();
    again.restore(s.snapshot());
    expect((again.water.on, again.water.every, again.water.goal, again.myRems.single.name, again.myRems.single.on), (true, 60, 9, 'Lunch', false));
    s.dispose();
    again.dispose();
  });

  testWidgets('F20: residents also get meal times and rent due; each can be turned off', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    final rem = NoReminders(available: true);
    await s.startReminders(rem);
    await _pump(tester, s);
    // Nothing on yet: no Today card, no rings except the hostel's own.
    expect(find.text('Next glass'), findsNothing);
    expect(rem.applied.where((r) => r.kind == 'meal').map((r) => r.title).toList(), ['Lunch is served till 2 pm', 'Dinner is served till 10 pm']);
    final rent = rem.applied.where((r) => r.kind == 'rent').toList();
    expect(rent.map((r) => (r.title, r.at)).toList(), [('Rent due in 3 days', DateTime(2026, 10, 11, 9)), ('Rent due today', DateTime(2026, 10, 14, 9))]);
    expect(rent.first.body, '₹8,020 to Srinivas by 14 Oct');

    s.go('reminders');
    await tester.pump();
    expect(find.text('From Anjani Residency'.toUpperCase()), findsOneWidget);
    // Breakfast (7:30) is before the default awake hours (8 am), so it isn't promised.
    expect(find.text('From the food menu · lunch 12:30, dinner 8:00'), findsOneWidget);
    expect(find.text('3 days before and on the day · next 14 Oct'), findsOneWidget);
    expect(find.text('When Srinivas sets one'), findsOneWidget);
    await s.toggleHostelRem('meals');
    await s.toggleHostelRem('rent');
    expect(rem.applied.where((r) => r.kind == 'meal' || r.kind == 'rent'), isEmpty);

    // With water on, the Today card shows on Home with a + Glass button.
    await s.toggleWater();
    s.tab('rHome');
    await tester.pump();
    expect(find.text('0 of 8 glasses'), findsOneWidget);
    await _tap(tester, find.text('Glass'));
    await tester.pump();
    expect(find.text('1 of 8 glasses'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F20: the first-time offer shows once after sign-in, only where reminders ring', (tester) async {
    // Where reminders can't ring (web, desktop, tests): no offer.
    final web = AppState(start: 'explore', role: 'tenant');
    await web.startReminders(NoReminders());
    await _pump(tester, web);
    await tester.pump();
    expect(web.sheet, isNull);
    web.dispose();
  });

  testWidgets('F20: the offer, accepted, turns water on and never comes back', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    final rem = NoReminders(available: true);
    await s.startReminders(rem);
    // F21 W2: not on first arrival; from the 3rd app open.
    s.opens = 2;
    await _pump(tester, s);
    await tester.pump();
    expect(s.sheet, isNull);
    s.opens = 3;
    s.maybeOfferReminders(); // what Explore does each time it shows
    await tester.pump();
    expect(s.sheet, 'waterOffer');
    expect(find.text('Want water reminders?'), findsOneWidget);
    expect(find.text('Change it any time in Me → Reminders. Runs on this phone.'), findsOneWidget);
    await _tap(tester, find.text('Turn on water reminders'));
    await tester.pump();
    expect((s.sheet, s.water.on, rem.applied.length), (null, true, 28));
    // Explore shows the Today card; the offer never comes back.
    expect(find.text('0 of 8 glasses'), findsOneWidget);
    s.tab('me');
    await tester.pump();
    s.tab('explore');
    await tester.pump();
    await tester.pump();
    expect(s.sheet, isNull);
    expect(s.snapshot()['rem']['offered'], isTrue);
    s.dispose();
  });

  test('F20: signed in on the server, settings are backed up and a new phone gets them back', () async {
    final server = _BackupRepo();
    final s = AppState(start: 'me', role: 'tenant');
    s.data = server;
    s.account = (uid: 'fb-rahul', name: 'Rahul', email: 'r@gmail.com');
    final rem = NoReminders(available: true);
    await s.startReminders(rem);
    await s.toggleWater();
    s.openAddRem();
    s.quickRem(quickRems.first);
    await s.saveRem();
    expect(server.saved['fb-rahul']!['water']['on'], isTrue);
    expect((server.saved['fb-rahul']!['mine'] as List).single['name'], 'Take medicine');

    // A new phone: nothing set yet, so the backup comes back and rings.
    final phone2 = AppState(start: 'me', role: 'tenant');
    phone2.data = server;
    phone2.account = s.account;
    final rem2 = NoReminders(available: true);
    await phone2.startReminders(rem2);
    await phone2.restoreRemFromServer();
    expect((phone2.water.on, phone2.myRems.single.name), (true, 'Take medicine'));
    expect(rem2.applied.where((r) => r.kind == 'water').length, 28);

    // A phone that already has its own settings keeps them.
    final phone3 = AppState(start: 'me', role: 'tenant');
    phone3.data = server;
    phone3.account = s.account;
    phone3.myRems = [const MyReminder(id: 'x', name: 'Call home', at: 1140)];
    await phone3.restoreRemFromServer();
    expect((phone3.water.on, phone3.myRems.single.name), (false, 'Call home'));

    // Not signed in on the server: nothing leaves the phone.
    final local = AppState(start: 'me', role: 'tenant');
    await local.startReminders(NoReminders(available: true));
    await local.toggleWater();
    expect(server.saved.length, 1);
    for (final x in [s, phone2, phone3, local]) {
      x.dispose();
    }
  });
}

/// The server's profile backup, in memory.
class _BackupRepo extends SampleRepo {
  final saved = <String, Map<String, dynamic>>{};
  @override
  bool get remote => true;
  @override
  Future<void> saveReminders(String uid, Map<String, dynamic> settings) async => saved[uid] = settings;
  @override
  Future<Map<String, dynamic>?> loadReminders(String uid) async => saved[uid];
}
