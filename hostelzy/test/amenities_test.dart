import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show filtered;
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F23: shared things on each floor (fridge, washing machine, RO…) and room
// items (a geyser in the room washroom); the room plan comes first.

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

  testWidgets('F23 / F26 #3: the hostel page shows the building inline with each floor’s shared things; tenants only see them', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    // F26 #3: the "On each floor" list is gone; the chips sit on each floor of the building.
    expect(find.byKey(const ValueKey('onEachFloor')), findsNothing);
    expect(find.byKey(const ValueKey('inlineBuilding')), findsOneWidget);
    expect(find.byKey(const ValueKey('bThings-2')), findsOneWidget);
    expect(find.textContaining('NOT WORKING'), findsOneWidget); // the washing machine on floor 2
    await _tap(tester, find.byKey(const ValueKey('bFloor-2')));
    expect((s.sheet, s.amFloor), ('amFloor', 2));
    expect(find.text('In the room washroom of 201, 203'), findsOneWidget);
    expect(find.textContaining('Added by a resident'), findsOneWidget);
    // A tenant can't change it.
    expect(find.byKey(const ValueKey('amAddBtn')), findsNothing);
    expect(find.textContaining('keep this list up to date'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F23: the room plan comes first, with the floor strip and the washroom geyser', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s
      ..hid = 'anjani'
      ..phone = '9000000001'
      ..myName = 'Ravi Teja';
    await _pump(tester, s);
    await _tap(tester, find.text('Pick a bed'));
    expect((s.screen, s.mode), ('picker', 'room'));
    // Room 203 has the geyser in its washroom.
    await _tap(tester, find.byKey(const ValueKey('roomChip-203')));
    expect(s.room, 203);
    expect(find.byKey(const ValueKey('floorStrip')), findsOneWidget);
    expect(find.text('WASHROOM · GEYSER'), findsOneWidget);
    expect(find.text('Geyser in washroom'), findsOneWidget);
    // The floor view is one tap away.
    await _tap(tester, find.byKey(const ValueKey('floorView')));
    expect(s.mode, 'plan');
    s.dispose();

    // A guest starts on the floor view (room plans need sign-in).
    final g = AppState(start: 'explore', role: 'tenant')..signedIn = false;
    g.hid = 'anjani';
    g.openPicker();
    expect(g.mode, 'plan');
    g.dispose();
  });

  testWidgets('F23: a resident adds a thing and marks one broken; the owner is told', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    s.openFloorSheet('anjani', 2);
    await tester.pump();
    expect(find.text('Residents can add or fix this list. Srinivas sees every change.'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('amAddBtn')));
    expect(s.sheet, 'amAdd');
    expect(find.text('Pick what it is'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('amKind-microwave')));
    await _tap(tester, find.byKey(const ValueKey('amSave')));
    final m = s.amenities.lastWhere((a) => a.kind == 'microwave');
    expect((m.floor, m.place, m.byResident, m.working), (2, 'floor', true, true));
    expect(s.toast, 'Saved: Microwave on floor 2. Srinivas sees the change.');
    expect(s.sheet, 'amFloor');
    await tester.pump(const Duration(seconds: 4));

    // Something broke: tap the fridge.
    await _tap(tester, find.byKey(const ValueKey('amBreakBtn')));
    final fridge = s.amenitiesOn('anjani', 2).firstWhere((a) => a.kind == 'fridge');
    await _tap(tester, find.byKey(ValueKey('amRow-${fridge.id}')));
    expect(s.amenities.firstWhere((a) => a.id == fridge.id).working, isFalse);
    expect(s.amBreak, isFalse);
    s.dispose();

    // Another hostel's list is not theirs to change.
    final r = AppState(start: 'rHome', role: 'resident');
    expect(r.canEditAmenities('saisri'), isFalse);
    r.dispose();
  });

  testWidgets('F23: owner Layouts → Shared things; a geyser goes in the room washrooms; Fixed on Today', (tester) async {
    final s = AppState(start: 'oLayouts', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.text('Shared things ${s.amenities.where((a) => a.hid == 'anjani').length}'));
    expect(s.amOwnerTab, 'things');
    await _tap(tester, find.byKey(const ValueKey('ownFloor-2')));
    expect(find.byKey(const ValueKey('residentChanged')), findsOneWidget);
    expect(find.text('Broken things also show on Today as a repair.'), findsOneWidget);

    // Add a geyser: it goes in the room washrooms of rooms with an attached bath.
    await _tap(tester, find.byKey(const ValueKey('ownAddThing')));
    await _tap(tester, find.byKey(const ValueKey('amKind-geyser')));
    final d = s.amDraft!;
    expect(d.place, 'washroom');
    final attached = s.roomsOnFloor('anjani', 2).where((r) => r.bath == 'Attached').length;
    expect(find.text('Save · Geyser in $attached room washroom${attached == 1 ? '' : 's'}'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('amPlus')));
    expect(d.qty, 2);
    // A room thing needs rooms.
    s.update(() => d.rooms = []);
    await _tap(tester, find.byKey(const ValueKey('amSave')));
    expect(s.toast, 'Pick the rooms that have it.');
    await tester.pump(const Duration(seconds: 3));
    s.allAmenityRooms();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('amSave')));
    expect(s.amenities.where((a) => a.hid == 'anjani' && a.kind == 'geyser').length, 2);
    expect(s.amenities.last.byResident, isFalse);
    await tester.pump(const Duration(seconds: 3));

    // The broken washing machine is on Today; Fixed marks it working.
    final broken = s.brokenThings.single;
    s.tab('oToday');
    await tester.pump();
    expect(find.byKey(ValueKey('broken-${broken.id}')), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(ValueKey('broken-${broken.id}')), matching: find.text('Fixed')));
    expect(s.brokenThings, isEmpty);
    s.dispose();
  });

  test('F23: filters keep only hostels with working things; the geyser one means the room washroom', () {
    final s = AppState(start: 'explore', role: 'tenant');
    final before = filtered(s).length;
    s.fAm = {'washer'};
    expect(s.filterCount, 1);
    final withWasher = filtered(s).map((h) => h.id).toSet();
    expect(withWasher.contains('anjani'), isTrue); // floor 1's works, even though floor 2's doesn't
    expect(withWasher.length, lessThan(before));
    s.fAm = {'geyser'};
    expect(filtered(s).map((h) => h.id).toList(), ['anjani']);
    s.clearFilters();
    expect((s.fAm.isEmpty, filtered(s).length), (true, before));
    s.dispose();
  });

  test('F23: amenity rows from the server', () {
    final a = amenityFromRow({'id': 'x1', 'hostel_id': 'h1', 'floor': 2, 'kind': 'geyser', 'name': '', 'qty': 1, 'working': false, 'place': 'washroom', 'rooms': [201, 204], 'by_role': 'resident', 'created_at': '2026-10-01T10:00:00Z', 'updated_at': '2026-10-02T10:00:00Z'});
    expect((a.key, a.hid, a.floor, a.inRooms, a.byResident, a.working, a.label), ('x1', 'h1', 2, true, true, false, 'Geyser'));
    expect(a.rooms, [201, 204]);
  });

  for (final c in const ['amFloor', 'amAdd']) {
    testWidgets('F23: $c fits at 2× text', (tester) async {
      final s = AppState(start: 'oBeds', role: 'owner');
      await _pump(tester, s, scale: 2);
      if (c == 'amFloor') {
        s.openFloorSheet('anjani', 2);
      } else {
        s.openAddAmenity(hid: 'anjani', floor: 2);
        s.pickAmenityKind('geyser');
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
