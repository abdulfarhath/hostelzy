import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F25 (hub decision): one new screen, the Building view, with the floors'
// shared things on top of each floor row. Tenants: the picker's Building tab
// and the hostel page. Owners: Beds › Rooms · Building, the same component.

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

  testWidgets('F25: Building view from the hostel page: floors, chips, pick a free bed, Continue; a floor opens its sheet', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s
      ..hid = 'anjani'
      ..phone = '9000000001'
      ..myName = 'Ravi Teja';
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('seeBuilding')));
    expect((s.screen, s.mode), ('picker', 'building'));
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    final rooms = s.rooms['anjani']!;
    // Every floor, top floor first; G only because the data has things on floor 0.
    for (final f in floorsOf(rooms)) {
      expect(find.byKey(ValueKey('bFloorRow-$f')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('bFloorRow-0')), findsOneWidget);
    expect(find.textContaining('Reception'), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('bFloorRow-3'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('bFloorRow-1'))).dy));
    // Shared things on top of each floor; broken ones in red words.
    expect(find.descendant(of: find.byKey(const ValueKey('bThings-2')), matching: find.text('WASHING MACHINE · NOT WORKING')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('bThings-0')), matching: find.text('LIFT')), findsOneWidget);
    // In-room things (the geyser) aren't floor chips.
    expect(find.descendant(of: find.byKey(const ValueKey('bThings-2')), matching: find.text('GEYSER')), findsNothing);
    for (final r in rooms) {
      expect(find.byKey(ValueKey('bRoom-${r.n}')), findsOneWidget);
    }
    // A taken bed says so; a free bed is picked and Continue opens the hold.
    final taken = rooms.expand((r) => r.beds).firstWhere((b) => b.state == 'booked');
    await _tap(tester, find.byKey(ValueKey('bBed-${taken.id}')));
    expect((s.bed, s.toast), (null, 'This bed is taken.'));
    await tester.pump(const Duration(seconds: 3));
    final free = rooms.expand((r) => r.beds).firstWhere((b) => b.state == 'free' && !b.mine);
    await _tap(tester, find.byKey(ValueKey('bBed-${free.id}')));
    expect(s.bed, free.id);
    expect(find.textContaining('Bed ${free.id} · '), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('pickContinue')));
    expect(s.sheet, 'hold');
    s.update(() => s.sheet = null);
    await tester.pump();
    // A floor opens the existing floor sheet (H42).
    await _tap(tester, find.byKey(const ValueKey('bFloor-2')));
    expect((s.sheet, s.amFloor), ('amFloor', 2));
    s.update(() => s.sheet = null);
    await tester.pump();
    // Tabs: Plan, Room, Building.
    await _tap(tester, find.byKey(const ValueKey('floorView')));
    expect(s.mode, 'plan');
    await _tap(tester, find.byKey(const ValueKey('pickTab-room')));
    expect(s.mode, 'room');
    await _tap(tester, find.byKey(const ValueKey('pickTab-building')));
    expect(s.mode, 'building');
    s.dispose();
  });

  testWidgets('F25: a women\'s PG shows the Building view only after a hold', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    s.hid = 'saisri';
    s.openPicker();
    s.update(() => s.mode = 'building');
    await _pump(tester, s);
    expect(find.text('Floor plan shows after you hold a bed'), findsOneWidget);
    expect(find.byKey(const ValueKey('buildingView')), findsNothing);
    s.update(() => s.holds = [Hold(id: 'x', hid: 'saisri', bed: '102-A', room: 102, opt: 'free', start: s.now, status: 'waiting')]);
    await tester.pump();
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    s.dispose();
  });

  testWidgets('F25/F26 #19: owner Beds is the Building view; a bed opens the bed sheet', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    expect(find.text('Rooms'), findsNothing); // the Rooms · Building toggle is gone
    final res = s.residents.firstWhere((r) => r.bed.startsWith('2'));
    await _tap(tester, find.byKey(ValueKey('bBed-${res.bed}')));
    expect((s.sheet, s.obed), ('bed', res.bed));
    expect(find.textContaining(res.name), findsWidgets);
    s.dispose();
  });

  testWidgets('F25: Building view fits at 2× text on a 360-px phone, light and dark', (tester) async {
    for (final dark in [false, true]) {
      final t = AppState(start: 'picker', role: 'tenant');
      t.hid = 'anjani';
      t.openPicker();
      t.theme = dark ? 'dark' : 'light';
      t.update(() => t.mode = 'building');
      await _pump(tester, t, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      t.dispose();
      final o = AppState(start: 'oBeds', role: 'owner');
      o.theme = dark ? 'dark' : 'light';
      await _pump(tester, o, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      o.dispose();
    }
  });
}
