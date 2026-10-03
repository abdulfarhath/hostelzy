import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 #15: "Layouts checked by N residents" on the hostel page, from the server.

Future<void> _pump(WidgetTester tester, AppState state) async {
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
  await tester.pumpWidget(MaterialApp(home: AppScope(state: state, child: const HostelzyShell(bare: true))));
  await tester.pump();
}

void main() {
  mapTiles = false;

  test('the per-hostel count comes through with the listings', () {
    expect(listingsFromRows(const [], checkers: {'h1': 6}).checkers['h1'], 6);
  });

  testWidgets('the hostel page says how many residents checked its layouts, and nothing when none did', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('hostelChecked')), findsNothing);
    s.update(() => s.hostelCheckers['anjani'] = 6);
    await tester.pump();
    expect(find.text('Layouts checked by 6 residents'), findsOneWidget);
    s.update(() => s.hostelCheckers['anjani'] = 1);
    await tester.pump();
    expect(find.text('Layouts checked by a resident'), findsOneWidget);
    s.dispose();
  });
}
