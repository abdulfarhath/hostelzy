import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';

// F25 NEW-4 (board `w4-oMenuWeek`): the owner's Food menu gets a seg
// *Edit by day · Week table*. The table is Mon–Sun × breakfast / lunch /
// dinner from the week being typed, today highlighted, empty slots "Not set",
// and a tap on a day opens Edit by day on it.

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1, double width = 390}) async {
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shell = AppScope(state: state, child: const HostelzyShell(bare: true));
  await tester.pumpWidget(MaterialApp(home: scale == 1 ? shell : MediaQuery(data: MediaQueryData(size: Size(width, 844), textScaler: TextScaler.linear(scale)), child: shell)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// The owner on Manage › Food menu with the saved week loaded.
Future<AppState> _open(WidgetTester tester, {String theme = 'light', double scale = 1, double width = 390}) async {
  final s = AppState(start: 'oMore', role: 'owner', theme: theme);
  await _pump(tester, s, scale: scale, width: width);
  s.openMenu();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  return s;
}

Color? _rowColor(WidgetTester tester, int i) {
  final c = tester.widget<Container>(find.descendant(of: find.byKey(ValueKey('menuWeek-$i')), matching: find.byType(Container)).first);
  return (c.decoration as BoxDecoration?)?.color;
}

void main() {
  mapTiles = false;

  testWidgets('F25 NEW-4: Week table, Not set, today highlighted, tap a day to edit it', (tester) async {
    final s = await _open(tester);
    expect(s.mView, 'day');
    expect(find.text('Edit by day'), findsOneWidget);
    expect(find.byKey(const ValueKey('menuDay-0')), findsOneWidget);

    // An unsaved edit: Sunday dinner cleared. The table shows the draft.
    s.setMenuMeal(6, 'n', '');
    await tester.pump();

    await _tap(tester, find.text('Week table'));
    expect(s.mView, 'week');
    expect(find.byKey(const ValueKey('menuDay-0')), findsNothing);
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey('menuWeek-$i')), findsOneWidget);
    }
    expect(find.text('BREAKFAST'), findsOneWidget);
    expect(find.text(seedMenu[0].b), findsOneWidget);
    expect(find.text(seedMenu[4].l), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('menuSlot-6-n')), matching: find.text('Not set')), findsOneWidget);
    expect(find.text('Sunday dinner is not set yet.'), findsOneWidget);
    expect(find.text('Not saved yet. Residents and tenants see it after you tap Save.'), findsOneWidget);

    // Today (Thursday 1 Oct in tests) is highlighted, other days are not.
    expect(todayIdx, 3);
    final p = PalScope.of(tester.element(find.byKey(const ValueKey('menuWeek-0'))));
    expect(_rowColor(tester, 3), p.ab);
    expect(_rowColor(tester, 0), isNot(p.ab));

    // Tap Saturday → Edit by day on Saturday.
    await _tap(tester, find.byKey(const ValueKey('menuWeek-5')));
    expect((s.mView, s.mDay), ('day', 5));
    expect(find.text('Copy Saturday to Sunday'), findsOneWidget);
    expect(find.byKey(const ValueKey('menuWeek-5')), findsNothing);

    // Unsaved edits behave as before: Save menu saves the draft.
    expect(s.menuDirty, isTrue);
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    expect(s.menuOf('anjani')![6].n, '');
    s.dispose();
  });

  testWidgets('F25 NEW-4: an empty week says No menu yet and every slot is Not set', (tester) async {
    final s = await _open(tester);
    s.update(() {
      s.menuDraft = List.of(blankWeek);
      s.mView = 'week';
    });
    await tester.pump();
    expect(find.text('Not set'), findsNWidgets(21));
    expect(find.textContaining('No menu yet.'), findsOneWidget);
    s.dispose();
  });

  for (final theme in const ['light', 'dark']) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('F25 NEW-4: Week table fits 360 px at ${scale}x text ($theme)', (tester) async {
        final s = await _open(tester, theme: theme, scale: scale, width: 360);
        s.update(() => s.mView = 'week');
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('menuWeek-6')), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('menuWeek-6')));
        expect((s.mView, s.mDay), ('day', 6));
        expect(tester.takeException(), isNull);
        s.dispose();
      });
    }
  }
}
