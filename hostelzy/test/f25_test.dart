import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/sample_repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F25: the Building view (cross-section), the floor map with shared things
// placed, the owner's Beds › Floor plan, and placing a thing on the floor.

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

/// The server before FOUNDER-TODO 4zk2: spots can't be saved yet.
class _NotReady extends SampleRepo {
  int calls = 0;
  @override
  Future<bool> placeAmenity(String key, int? x, int? y) async {
    calls++;
    return false;
  }
}

void main() {
  mapTiles = false;

  testWidgets('F25 NEW-1: Building view from the hostel page; pick a free bed, Continue', (tester) async {
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
    expect(find.text('G'), findsOneWidget);
    expect(find.textContaining('Reception'), findsNothing);
    final y3 = tester.getTopLeft(find.byKey(const ValueKey('bFloorRow-3'))).dy, y1 = tester.getTopLeft(find.byKey(const ValueKey('bFloorRow-1'))).dy;
    expect(y3, lessThan(y1));
    // Shared things sit on top of each floor; broken ones say so.
    expect(find.descendant(of: find.byKey(const ValueKey('bThings-2')), matching: find.text('WASHING MACHINE · NOT WORKING')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('bThings-0')), matching: find.text('LIFT')), findsOneWidget);
    // Every room with every bed.
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
    // A floor's label opens it on the floor map.
    await _tap(tester, find.byKey(const ValueKey('bFloor-2')));
    expect((s.mode, s.floor), ('plan', 2));
    expect(find.byKey(const ValueKey('floorMap-2')), findsOneWidget);
    // Tabs: Room and back to Building.
    await _tap(tester, find.byKey(const ValueKey('pickTab-room')));
    expect(s.mode, 'room');
    await _tap(tester, find.byKey(const ValueKey('pickTab-building')));
    expect(s.mode, 'building');
    s.dispose();
  });

  testWidgets('F25 NEW-2: floor map: things placed, broken in red, the rest Not placed yet; a thing opens the floor sheet', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    s.hid = 'anjani';
    s.openPicker();
    s.update(() {
      s.mode = 'plan';
      s.floor = 2;
    });
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('corridor')), findsOneWidget);
    final on2 = s.amenitiesOn('anjani', 2);
    final fridge = on2.firstWhere((a) => a.kind == 'fridge'), washer = on2.firstWhere((a) => a.kind == 'washer');
    expect(find.byKey(ValueKey('thing-${fridge.id}')), findsOneWidget);
    expect(find.text('WASHING MACHINE · NOT WORKING'), findsOneWidget);
    // The geyser is in the room washrooms: a line, not a spot.
    expect(find.text('Geyser in the room washroom of 201, 203'), findsOneWidget);
    // Stairs only because the hostel has more than one floor; WC only because rooms share a bath.
    expect(find.byKey(const ValueKey('stairs')), findsOneWidget);
    expect(find.byKey(const ValueKey('wc')), findsOneWidget);
    expect(find.byKey(const ValueKey('notPlaced')), findsNothing);
    await _tap(tester, find.byKey(ValueKey('thing-${washer.id}')));
    expect((s.sheet, s.amFloor), ('amFloor', 2));
    s.update(() => s.sheet = null);
    // Floor 1: the RO and washer have no spot yet; they're listed, never guessed.
    await _tap(tester, find.byKey(const ValueKey('floor-1')));
    expect(find.byKey(const ValueKey('notPlaced')), findsOneWidget);
    final ro1 = s.amenitiesOn('anjani', 1).firstWhere((a) => a.kind == 'ro');
    expect(find.byKey(ValueKey('unplaced-${ro1.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('thing-${ro1.id}')), findsNothing);
    // Picking a bed on the map.
    final free = s.rooms['anjani']!.where((r) => r.floor == 1).expand((r) => r.beds).firstWhere((b) => b.state == 'free' && !b.mine);
    await _tap(tester, find.byKey(ValueKey('bed-${free.id}')));
    expect(s.bed, free.id);
    s.dispose();
  });

  testWidgets('F25: a women\'s PG shows Plan and Building only after a hold', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    s.hid = 'saisri';
    s.openPicker();
    s.update(() => s.mode = 'building');
    await _pump(tester, s);
    expect(find.text('Floor plan shows after you hold a bed'), findsOneWidget);
    expect(find.byKey(const ValueKey('buildingView')), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('floorView')));
    expect(find.text('Floor plan shows after you hold a bed'), findsOneWidget);
    expect(find.byKey(const ValueKey('corridor')), findsNothing);
    s.update(() {
      s.holds = [Hold(id: 'x', hid: 'saisri', bed: '102-A', room: 102, opt: 'free', start: s.now, status: 'waiting')];
      s.mode = 'building';
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    s.dispose();
  });

  testWidgets('F25 NEW-3: owner Beds › Floor plan: initials, Free, Hold, the date; a bed opens its sheet; Mark Fixed', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    s.obFloor = 2;
    await _pump(tester, s);
    expect(s.obView, 'plan');
    expect(find.byKey(const ValueKey('corridor')), findsOneWidget);
    final beds = s.rooms['anjani']!.where((r) => r.floor == 2).expand((r) => r.beds).toList();
    final res = s.residents.firstWhere((r) => r.bed.startsWith('2'));
    final parts = res.name.split(' ');
    expect(tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('obedWord-${res.bed}')), matching: find.byType(Text))).data, '${parts[0][0]}${parts[1][0]}'.toUpperCase());
    final free = beds.firstWhere((b) => b.state == 'free');
    expect(tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('obedWord-${free.id}')), matching: find.byType(Text))).data, 'Free');
    for (final b in beds.where((b) => b.state == 'soon')) {
      expect(tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('obedWord-${b.id}')), matching: find.byType(Text))).data, b.soon);
    }
    // A bed opens the bed sheet.
    await _tap(tester, find.byKey(ValueKey('obed-${res.bed}')));
    expect((s.sheet, s.obed), ('bed', res.bed));
    s.update(() => s.sheet = null);
    await tester.pump();
    // The broken washing machine: red on the map, Mark Fixed below it.
    final washer = s.amenitiesOn('anjani', 2).firstWhere((a) => a.kind == 'washer');
    expect(find.byKey(ValueKey('brokenLine-${washer.id}')), findsOneWidget);
    await _tap(tester, find.byKey(ValueKey('markFixed-${washer.id}')));
    await tester.pump();
    expect(s.amenities.firstWhere((a) => a.id == washer.id).working, isTrue);
    expect(find.byKey(ValueKey('brokenLine-${washer.id}')), findsNothing);
    expect(s.sheet, isNull);
    await tester.pump(const Duration(seconds: 3));
    // All floors: every floor's rooms as cards.
    await _tap(tester, find.text('All floors'));
    expect(s.obView, 'all');
    for (final f in floorsOf(s.rooms['anjani']!)) {
      expect(find.byKey(ValueKey('obAllFloor-$f')), findsOneWidget);
    }
    // Layouts › Building: the same cross-section for owners; a bed opens the bed sheet.
    s.update(() {
      s.screen = 'oLayouts';
      s.amOwnerTab = 'building';
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    await _tap(tester, find.byKey(ValueKey('bBed-${res.bed}')));
    expect((s.sheet, s.obed), ('bed', res.bed));
    s.dispose();
  });

  testWidgets('F25: owner places a thing on the floor map from Layouts › Shared things', (tester) async {
    final s = AppState(start: 'oLayouts', role: 'owner');
    s.amOwnerTab = 'things';
    s.amFloor = 1;
    await _pump(tester, s);
    final ro = s.amenitiesOn('anjani', 1).firstWhere((a) => a.kind == 'ro');
    expect(find.descendant(of: find.byKey(ValueKey('ownSpot-${ro.id}')), matching: find.text('Not placed yet')), findsOneWidget);
    await _tap(tester, find.byKey(ValueKey('ownPlace-${ro.id}')));
    expect(s.sheet, 'amPlace');
    // Save needs a spot first.
    await _tap(tester, find.byKey(const ValueKey('amPlaceSave')));
    expect(s.toast, 'Tap the spot on the floor where it is.');
    final box = tester.getRect(find.byKey(const ValueKey('corridorTap')));
    await tester.tapAt(Offset(box.left + box.width * .5, box.top + box.height * .75));
    await tester.pump();
    expect(s.amPlaceSpot!.$1, inInclusiveRange(45, 55));
    expect(s.amPlaceSpot!.$2, inInclusiveRange(70, 80));
    expect(find.byKey(const ValueKey('placingTag')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('amPlaceSave')));
    expect(s.sheet, isNull);
    expect(ro.placed, isTrue);
    expect(s.toast, 'Saved: RO water on the floor 1 map.');
    expect(s.unplacedOn('anjani', 1).map((a) => a.id), isNot(contains(ro.id)));
    await tester.pump(const Duration(seconds: 3));
    // Take it off again.
    await _tap(tester, find.byKey(ValueKey('ownPlace-${ro.id}')));
    await _tap(tester, find.byKey(const ValueKey('amPlaceClear')));
    expect(ro.placed, isFalse);
    s.dispose();
  });

  testWidgets('F25: before the server has spots, nothing is saved and it says so', (tester) async {
    final s = AppState(start: 'oLayouts', role: 'owner');
    final repo = _NotReady();
    s.data = repo;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    expect(s.onServer, isTrue);
    final a = s.amenities.firstWhere((x) => x.hid == s.ownHid && !x.inRooms && !x.placed);
    final withKey = Amenity(id: a.id, key: 'srv-1', hid: a.hid, floor: a.floor, kind: a.kind);
    s.update(() => s.amenities = [...s.amenities.where((x) => x.id != a.id), withKey]);
    s.openPlaceThing(withKey);
    s.update(() => s.amPlaceSpot = (20, 50));
    await s.savePlace();
    expect(repo.calls, 1);
    expect(withKey.placed, isFalse);
    expect(s.toast, contains('Spots can’t be saved yet'));
    expect(s.unplacedOn(a.hid, a.floor).map((x) => x.id), contains(a.id));
    s.dispose();
  });

  testWidgets('F25: Building, floor map and owner floor plan fit at 2× text on a 360-px phone, light and dark', (tester) async {
    for (final dark in [false, true]) {
      final t = AppState(start: 'picker', role: 'tenant');
      t.hid = 'anjani';
      t.openPicker();
      t.theme = dark ? 'dark' : 'light';
      t.update(() => t.mode = 'building');
      await _pump(tester, t, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      t.update(() {
        t.mode = 'plan';
        t.floor = 2;
      });
      await tester.pump();
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
