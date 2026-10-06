import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F25 (hub decision): one new screen, the Building view, with the floors'
// shared things on top of each floor row. Tenants: the hostel page (F26: no
// longer a picker tab). Owners: Beds › Rooms · Building, the same component.

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

void main() {
  mapTiles = false;

  testWidgets('F26 #8: the picker has no Building tab; "See the whole building" opens every room, women\'s PGs too, no lock', (tester) async {
    for (final hid in ['anjani', 'saisri']) {
      final s = AppState(start: 'detail', role: 'tenant');
      s
        ..hid = hid
        ..phone = '9000000001'
        ..myName = 'Ravi Teja';
      await _pump(tester, s);
      s.openBuilding();
      await tester.pump();
      expect((s.screen, s.mode), ('picker', 'plan'));
      expect(find.byKey(const ValueKey('pickTab-building')), findsNothing);
      expect(find.byKey(const ValueKey('buildingView')), findsNothing);
      expect(find.text('Floor plan shows after you hold a bed'), findsNothing);
      for (final r in s.rooms[hid]!) {
        expect(find.byKey(ValueKey('roomCard-${r.n}')), findsOneWidget);
      }
      s.dispose();
    }
  });

  testWidgets('F25: owner Beds › Building is the same view; a bed opens the bed sheet', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    await _pump(tester, s);
    expect(s.obView, 'rooms');
    expect(find.byKey(const ValueKey('buildingView')), findsNothing);
    await _tap(tester, find.text('Building'));
    expect(s.obView, 'building');
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    final res = s.residents.firstWhere((r) => r.bed.startsWith('2'));
    await _tap(tester, find.byKey(ValueKey('bBed-${res.bed}')));
    expect((s.sheet, s.obed), ('bed', res.bed));
    expect(find.textContaining(res.name), findsWidgets);
    s.update(() => s.sheet = null);
    await tester.pump();
    await _tap(tester, find.text('Rooms'));
    expect(find.byKey(const ValueKey('oRoom-201')), findsOneWidget);
    s.dispose();
  });

  testWidgets('F25: Building view fits at 2× text on a 360-px phone, light and dark', (tester) async {
    for (final dark in [false, true]) {
      // F26 #8: the tenant picker (every room drawn) at 2× too.
      final t = AppState(start: 'picker', role: 'tenant');
      t.hid = 'anjani';
      t.openPicker();
      t.theme = dark ? 'dark' : 'light';
      await _pump(tester, t, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      t.dispose();
      final o = AppState(start: 'oBeds', role: 'owner');
      o.theme = dark ? 'dark' : 'light';
      o.obView = 'building';
      await _pump(tester, o, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      o.dispose();
    }
  });
}
