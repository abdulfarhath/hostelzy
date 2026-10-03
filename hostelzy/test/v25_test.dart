import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// Canvas v25: deals paused line on the hostel page (w1-dealsPaused); the oMeter
// footer example worded exactly like the resident's rent line (rentMeter).

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

  testWidgets('paused or hidden deals: tenants see a plain line, not vanished deals', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('dealsPaused')), findsNothing);
    // Strike 2 (no server dates in the demo: hidden).
    s.update(() => s.strikes['anjani'] = 2);
    await tester.pump();
    expect(find.text('Hostelzy deals are paused for this hostel. Walk-in prices shown.'), findsOneWidget);
    expect(find.byKey(const ValueKey('dealHeadline')), findsNothing);
    s.dispose();
  });

  testWidgets('the meter page example reads like the resident rent line', (tester) async {
    final s = AppState(start: 'oMeter', role: 'owner');
    await _pump(tester, s);
    expect(find.textContaining('“Electricity · 70 units ÷ 4 · ₹8/unit  ₹140”'), findsOneWidget);
    expect(find.textContaining('“Electricity  Not added yet”'), findsOneWidget);
    s.dispose();
  });
}
