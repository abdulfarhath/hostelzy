import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart' show BackBtn;
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F22 Area 4: the Hostelzy team's tools. Add hostel (one wizard frame, rooms
// as floor cards, the go-live checklist), the onboarding tracker by stage,
// owner payments (match, then tap) and Fair Play cases (decide inline).

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

  testWidgets('F22 Area 4: the tracker is one list by stage, with a next-step button per row', (tester) async {
    final s = AppState(start: 'aTrack', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('HOSTELZY TEAM · LIVE 3 OF 20 THIS MONTH'), findsOneWidget);
    for (final t in ['Lead 2', 'Visited 1', 'Signed up 2', 'Live 3']) {
      expect(find.text(t), findsOneWidget);
    }
    // Lead: the button moves a hostel to the next stage.
    expect(find.text('SR Nagar · next: call Mon'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(const ValueKey('aLead-Sri Sai PG')), matching: find.text('Visited')));
    expect(s.leads.firstWhere((l) => l.name == 'Sri Sai PG').stage, 1);
    expect(find.text('Lead 1'), findsOneWidget);
    expect(find.text('Visited 2'), findsOneWidget);

    // Signed up holds "Signed up" and "Data complete"; each row says which.
    await _tap(tester, find.text('Signed up 2'));
    expect(find.text('KPHB · Signed up · next: photos missing'), findsOneWidget);
    expect(find.text('Ameerpet · Data complete · next: go live Thu'), findsOneWidget);

    // Area chips still filter.
    await _tap(tester, find.text('Madhapur / Hitec City / Kondapur'));
    expect(find.text('Signed up 0'), findsOneWidget);
    expect(find.text('No hostels at this stage.'), findsOneWidget);
    await _tap(tester, find.text('All areas'));

    // Add hostel opens the wizard on step 1.
    await _tap(tester, find.widgetWithText(Row, 'Add hostel').last);
    expect((s.screen, s.addStep), ('aAdd', 1));
    s.dispose();
  });

  testWidgets('F22 Area 4: Add hostel is one frame; rooms are floor cards; go live counts what is left', (tester) async {
    final s = AppState(start: 'aTrack', role: 'owner');
    await _pump(tester, s);
    s.openAddHostel();
    await tester.pump();
    final d = s.draft;

    // Step 1: Basics.
    expect(find.text('ADD HOSTEL · STEP 1 OF 7'), findsOneWidget);
    expect(find.text('Basics'), findsOneWidget);
    expect(d.food, '3 meals');
    await _tap(tester, find.byKey(const ValueKey('aAddFood')));
    expect(d.food, '2 meals');
    await _tap(tester, find.text('Map pin · drop it at the gate'));
    expect(s.screen, 'aPin');
    s.pinPanned((17.4622, 78.3568));
    await _tap(tester, find.byKey(const ValueKey('pinSave')));
    expect((d.pinChecked, d.pin), (true, (17.4622, 78.3568)));
    expect(find.text('Map pin · dropped at the gate'), findsOneWidget);
    await _tap(tester, find.text('Next: rooms'));

    // Step 2: floor cards with room chips.
    expect(find.text('ADD HOSTEL · STEP 2 OF 7'), findsOneWidget);
    expect(find.text('Next: rates · 10 rooms, 29 beds'), findsOneWidget);
    expect(find.byKey(const ValueKey('aFloor-0')), findsOneWidget);
    expect(find.text('No beds here · hidden from tenants'), findsOneWidget);
    // A room chip opens its editor: sharing and AC.
    await _tap(tester, find.byKey(const ValueKey('aRoom-105')));
    await _tap(tester, find.text('4 sharing'));
    await _tap(tester, find.text('AC').last);
    final r105 = d.allRooms.firstWhere((r) => r.label == '105');
    expect((r105.share, r105.ac), (4, true));
    expect(find.text('Next: rates · 10 rooms, 31 beds'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('aRoom-105')));
    expect(find.text('Remove room'), findsNothing);
    // Copy floor above: a new floor with the top floor's rooms, renumbered.
    await _tap(tester, find.text('Copy floor above'));
    expect(d.floors.length, 5);
    expect(d.floors.last.rooms.map((r) => r.label), ['401', '402']);
    await _tap(tester, find.text('Add floor'));
    expect((d.floors.length, d.floors.last.rooms.length), (6, 0));
    await _tap(tester, find.text('+ Terrace'));
    expect(d.floors.last.name, 'Terrace');
    await _tap(tester, find.text('+ Terrace'));
    expect(d.floors.where((f) => f.name == 'Terrace').length, 1);
    await tester.pump(const Duration(seconds: 3));
    // New rooms follow "New rooms: … · Change".
    await _tap(tester, find.textContaining('New rooms: 3 sharing · Non-AC'));
    expect(d.defAc, isTrue);

    // Steps 3 to 5 keep the frame.
    await _tap(tester, find.textContaining('Next: rates'));
    expect(find.text('ADD HOSTEL · STEP 3 OF 7'), findsOneWidget);
    s.update(() => s.addStep = 7);
    await tester.pump();

    // Step 7: the checklist; open items are red; the button says how many.
    expect(find.text('ADD HOSTEL · STEP 7 OF 7'), findsOneWidget);
    expect(find.text('Ready to go live?'), findsOneWidget);
    final left = s.goLiveLeft.length;
    expect(left, greaterThan(1));
    expect(find.text('Go live · $left things left'), findsOneWidget);
    await _tap(tester, find.text('Fair Play rules: owner agreed'));
    expect(d.fairPlay, isTrue);
    expect(find.text('Go live · ${left - 1} ${left - 1 == 1 ? 'thing' : 'things'} left'), findsOneWidget);
    expect(find.textContaining('The 30-day free trial starts today.'), findsOneWidget);
    // Back steps back through the wizard.
    await _tap(tester, find.byType(BackBtn));
    expect((s.screen, s.addStep), ('aAdd', 6));
    s.dispose();
  });

  testWidgets('F22 Area 4: payments: match, then Mark paid or Not received', (tester) async {
    final s = AppState(start: 'aPay', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Owner payments'), findsOneWidget);
    expect(find.text('Match each UPI reference in the bank app. Never trust screenshots.'), findsOneWidget);
    expect(find.text('To check 2'), findsOneWidget);
    expect(find.text('Late 1'), findsOneWidget);
    expect(find.text('Greenview Men\'s PG · ₹499'), findsOneWidget);
    expect(find.textContaining('HZ-INV-1019 · UPI ref 4021 7710 0532 · sent 1 Oct'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(const ValueKey('aPay-HZ-INV-1019')), matching: find.text('Mark paid')));
    expect(s.invoices.firstWhere((i) => i.ref == 'HZ-INV-1019').status, 'paid');
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.text('Not received'));
    expect(s.invoices.firstWhere((i) => i.ref == 'HZ-INV-1016').status, 'missing');
    expect(find.text('To check 0'), findsOneWidget);

    // Late: overdue and not received, each with a reminder.
    await _tap(tester, find.text('Late 2'));
    expect(find.byKey(const ValueKey('aPay-HZ-INV-0998')), findsOneWidget);
    expect(find.byKey(const ValueKey('aPay-HZ-INV-1016')), findsOneWidget);
    expect(find.textContaining('deals paused'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(const ValueKey('aPay-HZ-INV-0998')), matching: find.text('Send reminder')));
    expect(s.lastLink.toString(), contains('wa.me'));

    // Paid, then Upcoming (trial).
    await _tap(tester, find.text('Paid'));
    expect(find.byKey(const ValueKey('aPay-HZ-INV-1019')), findsOneWidget);
    expect(find.textContaining('Paid so far:'), findsOneWidget);
    await _tap(tester, find.text('Upcoming'));
    expect(find.byKey(ValueKey('aPay-${s.invoice.ref}')), findsOneWidget);
    s.dispose();
  });

  testWidgets('F22 Area 4: Fair Play cases: decide inline, open a case for its detail', (tester) async {
    final s = AppState(start: 'aCases', role: 'owner');
    s.cases.firstWhere((c) => c.id == 'FP-0142').status = 'decide';
    await _pump(tester, s);
    expect(find.text('Fair Play cases'), findsOneWidget);
    await _tap(tester, find.text('Decide 1'));
    final row = find.byKey(const ValueKey('aCase-FP-0142'));
    for (final t in ['No issue', 'Ask more', 'Strike 1']) {
      expect(find.descendant(of: row, matching: find.text(t)), findsOneWidget);
    }
    expect(find.textContaining('Decide after the 48-hour window or the owner’s reply.'), findsOneWidget);
    await _tap(tester, find.descendant(of: row, matching: find.text('Ask more')));
    expect(s.cases.firstWhere((c) => c.id == 'FP-0142').status, 'waiting');
    expect(find.text('Decide 0'), findsOneWidget);

    // A new case: tap it for the detail; decide there.
    await _tap(tester, find.text('New 3'));
    await _tap(tester, find.textContaining('FP-0139'));
    expect(find.text('OWNER HISTORY'), findsOneWidget);
    await _tap(tester, find.text('No issue'));
    expect(s.cases.firstWhere((c) => c.id == 'FP-0139').status, 'closed');
    await _tap(tester, find.text('Closed'));
    expect(find.text('Closed · no issue'), findsOneWidget);
    s.dispose();
  });

  for (final c in const [('aTrack', 0, 'light'), ('aAdd', 1, 'light'), ('aAdd', 2, 'light'), ('aAdd', 6, 'light'), ('aAdd', 7, 'light'), ('aAdd', 7, 'dark'), ('aPay', 0, 'light'), ('aCases', 0, 'dark')]) {
    testWidgets('F22 Area 4: ${c.$1}${c.$2 > 0 ? ' step ${c.$2}' : ''} (${c.$3}) fits at 2× text', (tester) async {
      final s = AppState(start: c.$1, role: 'owner', theme: c.$3);
      if (c.$2 > 0) s.addStep = c.$2;
      if (c.$1 == 'aCases') {
        s.cases.first.status = 'decide';
        s.adminTab = 'decide';
      }
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
