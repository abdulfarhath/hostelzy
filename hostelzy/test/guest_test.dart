import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart';
import 'package:hostelzy/ui/shell.dart';

// F21 Wave 2: look around as a guest, one "Where?" field, Filters with sort,
// the real cost on cards, and sign-in only at the first hold.

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
  await tester.pumpWidget(MaterialApp(home: AppScope(state: state, child: const HostelzyShell(bare: true))));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// F22: the first free bed on the picker's floor.
Finder freeBed(AppState s) {
  final b = s.rooms[s.hid]!.where((r) => r.floor == s.floor && AppState.fits(r, s.pR)).expand((r) => r.beds).firstWhere((b) => b.state == 'free' && !b.mine);
  return find.byKey(ValueKey('bed-${b.id}'));
}

void main() {
  mapTiles = false;

  testWidgets('F21 W2: a guest finds a bed, filters, and signs in only to hold it', (tester) async {
    final s = AppState();
    await _pump(tester, s);
    expect(find.text('No sign-in needed to look around.'), findsOneWidget);
    await _tap(tester, find.text('Find a bed'));
    expect((s.screen, s.role, s.signedIn), ('explore', 'tenant', false));
    expect(find.text('Browsing as a guest'), findsOneWidget);
    expect(find.text('Find a bed'), findsOneWidget);
    // Tabs: Saved replaces Search.
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
    // Cards: F26 #2 Price ↑ by default, the first card says so; the real cost.
    expect(find.text('Lowest price'), findsOneWidget);
    expect(find.text('#1 near you'), findsNothing);
    final c = cardCost(s, hostelById('anjani'))!;
    expect(c.move, c.fee + 3000);
    expect(find.text('${fmt(c.fee)}/mo · ${fmt(c.move)} to move in · electricity extra', findRichText: true), findsOneWidget);
    expect(find.textContaining('Ranked mostly by'), findsNothing);

    // Where?: one field for landmarks, areas and hostels.
    await _tap(tester, find.byKey(const ValueKey('whereBar')));
    expect(s.screen, 'where');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('whereQ')), matching: find.byType(TextField)), 'gach');
    await tester.pump();
    expect(find.text('LANDMARKS'), findsOneWidget);
    expect(find.text('AREAS'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('lm-Gachibowli')));
    expect((s.screen, s.lm), ('explore', 'Gachibowli'));
    expect(find.text('Near Gachibowli'), findsOneWidget);
    // A hostel by name opens its page.
    await _tap(tester, find.byKey(const ValueKey('whereBar')));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('whereQ')), matching: find.byType(TextField)), 'anjani');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('hostel-anjani')));
    expect((s.screen, s.hid), ('detail', 'anjani'));
    s.back();
    await tester.pump();

    // Filters: a count on the button, Clear all (F26 #2: sort is its own dropdown).
    await _tap(tester, find.byKey(const ValueKey('filtersBtn')));
    expect(find.text('Filters'), findsWidgets);
    expect(find.text('Sort by'), findsNothing);
    await _tap(tester, find.widgetWithText(ChipBtn, 'AC').last);
    await _tap(tester, find.widgetWithText(ChipBtn, 'Under ₹10,000'));
    expect((s.sortBy, s.filterCount), ('price', 2));
    expect(find.descendant(of: find.byKey(const ValueKey('filtersBtn')), matching: find.text('Filters · 2')), findsOneWidget);
    // Deals stay findable without a sort: "Hostelzy deals only".
    await _tap(tester, find.text('Hostelzy deals only'));
    expect(s.filterCount, 3);
    expect(filtered(s).every((h) => s.bestQuote(h.id, f: s.fR) != null), isTrue);
    await _tap(tester, find.byKey(const ValueKey('clearAll')));
    expect(s.filterCount, 0);
    await _tap(tester, find.textContaining('Show '));
    expect(s.sheet, isNull);

    // Hostel page: one table, rules folded.
    await _tap(tester, find.text('Anjani Residency'));
    expect(find.text('Hostelzy price: ₹200 off every month · ₹500 exit · Free laundry'), findsOneWidget);
    expect(find.text('Gate closes'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('houseRules')));
    expect(find.text('Exit maintenance'), findsOneWidget);

    // First hold: sign in now, then the hold goes ahead by itself.
    await _tap(tester, find.text('Pick a bed'));
    // F23: the room plan comes first; these steps use the floor view.
    if (s.mode == 'room') await _tap(tester, find.byKey(const ValueKey('floorView')));
    await _tap(tester, freeBed(s));
    final bed = s.bed!;
    await _tap(tester, find.byKey(const ValueKey('pickContinue')));
    await _tap(tester, find.text('Hold bed $bed free'));
    expect((s.sheet, s.holds.length), ('signIn', 0));
    expect(find.text('Sign in to hold this bed'), findsOneWidget);
    expect(find.text('So Srinivas knows who’s coming. We ask only once.'), findsOneWidget);
    await _tap(tester, find.text('Use on this phone only'));
    expect(s.screen, 'phone');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('myName')), matching: find.byType(TextField)), 'Asha Kumari');
    s.update(() => s.phone = '9876543210');
    await tester.pump();
    await _tap(tester, find.text('Continue'));
    expect((s.signedIn, s.role, s.screen, s.holds.length), (true, 'tenant', 'hold', 1));
    expect(s.holds.single.bed, bed);
    expect(s.hist.last, 'picker');
    s.dispose();
  });

  testWidgets('F21 W2: Welcome links ask sign-in first; closing "Sign in to hold" drops it', (tester) async {
    final s = AppState();
    await _pump(tester, s);
    await _tap(tester, find.text('I run a PG'));
    expect((s.screen, s.afterSignIn), ('login', 'owner'));
    s.back();
    await tester.pump();
    await _tap(tester, find.text('Sign in'));
    expect((s.screen, s.afterSignIn), ('login', null));
    s.dispose();

    // A guest's enquiry asks for sign-in too; the X drops what was waiting.
    final g = AppState()..browse();
    g.hid = 'anjani';
    g.enquire('anjani', 'Hi Srinivas, is a bed free?', from: 'Hostel page');
    expect((g.sheet, g.afterSignIn), ('signIn', 'enquiry'));
    expect(g.enquiries.where((e) => e.msg.contains('is a bed free')), isEmpty);
    await _pump(tester, g);
    expect(find.text('Sign in to message Srinivas'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('sheetClose')));
    expect((g.sheet, g.afterSignIn), (null, null));
    g.dispose();
  });

  test('F21 W2: app opens are counted; the water offer waits for the 3rd', () {
    final s = AppState();
    s.restore({});
    expect(s.opens, 1);
    s.restore({'opens': 2});
    expect(s.opens, 3);
    expect(s.snapshot()['opens'], 3);
    s.dispose();
  });
}
