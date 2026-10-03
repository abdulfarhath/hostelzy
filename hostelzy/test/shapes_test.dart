import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/photos/pick.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/layout.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 items 10 and 11: the Fan / AC layer chips (off by default, F12), room
// shapes in "Create a layout", and "Ask Hostelzy to draw it" tracked in the
// app (request → the team's drawing → Publish v1).

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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 6; k++) {
    await tester.pump();
  }
}

class _Camera implements PhotoPicker {
  @override
  Future<Uint8List?> pick() async => Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 30)));
}

/// The server: keeps shape requests and records what the app sends.
class _Server extends SampleRepo {
  final calls = <String>[];
  final reqs = <ShapeRequest>[];
  final published = <String, Map<String, dynamic>>{};
  bool down = false;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me, stays: []);
  @override
  Future<String> uploadFixPhoto(String hid, String uid, Uint8List jpg) async {
    calls.add('photo $hid $uid');
    return '$hid/$uid/${calls.length}.jpg';
  }

  @override
  Future<List<ShapeRequest>> shapeRequests(String hid) async {
    if (down) throw Exception('relation "shape_requests" does not exist');
    return reqs.where((q) => q.hid == hid).toList();
  }

  @override
  Future<String> requestShape(String hid, int room, {required String shape, String note = '', double w = 0, double h = 0, List<String> photos = const []}) async {
    calls.add('request $hid $room $shape $note ${w.round()}x${h.round()} ${photos.join(',')}');
    reqs.add(ShapeRequest(id: 'sr1', hid: hid, room: room, shape: shape, note: note, w: w, h: h, photos: photos, at: DateTime.now().millisecondsSinceEpoch));
    return 'sr1';
  }

  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) async {
    calls.add('publish $hid $room ${layout['shape']}');
    published['$hid|$room'] = layout;
    // The server closes the room's sent request.
    for (final q in reqs.where((q) => q.hid == hid && q.room == room && q.status == 'sent')) {
      q.status = 'published';
    }
  }
}

void main() {
  mapTiles = false;

  test('shapes: outlines, inside the walls, saved and read back', () {
    expect(shapeOutline('Rectangle', 14, 12), isNull);
    expect(shapeOutline('L shape', 14, 12), const [Offset.zero, Offset(7.5, 0), Offset(7.5, 5.5), Offset(14, 5.5), Offset(14, 12), Offset(0, 12)]);
    for (final sh in layoutShapes.where((x) => x != 'Rectangle' && x != 'Custom')) {
      final o = shapeOutline(sh, 18, 15)!;
      expect(o.every((p) => p.dx >= 0 && p.dx <= 18 && p.dy >= 0 && p.dy <= 15), isTrue, reason: sh);
    }
    final rs = mkRooms(hostels[0], 0);
    final room = rs.firstWhere((r) => r.share == 3);
    final l = mkLayout('anjani', room, street: true)..setShape('L shape');
    // The cut-out corner is outside the walls; the rest of the room inside.
    expect(l.fits(Rect.fromLTWH(l.w - 3, 1, bedW, bedH)), isFalse);
    expect(l.fits(const Rect.fromLTWH(1, 1, bedW, bedH)), isTrue);
    expect(l.fits(Rect.fromLTWH(1, 0, 4, .3), onWall: true), isTrue);
    l.fitInside();
    expect(l.outside, isEmpty);
    expect(wallsCheck(l, room.label), (true, 'Everything inside the L shape walls'));
    // Saved with the layout and read back (a row from before shapes stays a rectangle).
    final j = layoutJson(l.snap());
    expect((j['shape'], (j['outline'] as List).length), ('L shape', 6));
    final back = snapFromJson(j);
    expect(back.shape, 'L shape');
    expect(back.outline, l.outline);
    final row = layoutFromRow('anjani', {'room': room.n, 'w': 18, 'h': 15, 'beds': {}, 'items': [], 'shape': 'L shape', 'outline': j['outline']});
    expect((row.shape, row.outline?.length), ('L shape', 6));
    final old = layoutFromRow('anjani', {'room': room.n, 'w': 18, 'h': 15, 'beds': {}, 'items': []});
    expect((old.shape, old.outline), ('Rectangle', null));
    expect(layoutJson(old.snap()).containsKey('outline'), isFalse);
    // Mirroring flips the walls too; a diff names the new shape.
    final m = RoomLayout(hid: 'anjani', room: room.n, w: l.w, h: l.h, beds: {}, items: [])..restore(l.snap());
    m.mirror();
    expect(m.outline!.contains(Offset(m.w - l.outline![1].dx, 0)), isTrue);
    expect(layoutDiff(old.snap(), l.snap()).lines, contains(('Shape', 'Rectangle → L shape')));
  });

  testWidgets('Room tab: fan reach and AC airflow show only when the layer is on (F12)', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant', mode: 'room');
    await _pump(tester, s);
    LayoutMap map() => tester.widget<LayoutMap>(find.byType(LayoutMap).first);
    expect(find.text('SHOW'), findsOneWidget);
    expect((map().fan, map().ac), (false, false));
    // Icons with labels stay.
    expect(find.text('FAN'), findsWidgets);
    await _tap(tester, find.byKey(const ValueKey('layerFan')));
    expect((s.showFan, map().fan, map().ac), (true, true, false));
    final acRoom = s.rooms[s.hid]!.where((r) => r.ac && s.liveLayout(s.hid, r.n) != null).firstOrNull;
    if (acRoom != null) {
      s.update(() => s.room = acRoom.n);
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('layerAc')));
      expect((map().fan, map().ac), (true, true));
    }
    s.dispose();
  });

  testWidgets('owner creates an L-shaped room: things start inside, can’t leave the walls, tenants see the shape', (tester) async {
    final s = AppState(start: 'oLayouts', role: 'owner');
    await _pump(tester, s);
    final room = s.rooms['anjani']!.firstWhere((r) => r.share == 3);
    s.layouts['anjani']!.remove(room.n);
    s.ownerLayout(room.n);
    await tester.pump();
    expect(s.screen, 'oCreate');
    expect(find.text('Room shape'), findsOneWidget);
    for (final sh in layoutShapes) {
      expect(find.byKey(ValueKey('shape-$sh')), findsOneWidget);
    }
    await _tap(tester, find.byKey(const ValueKey('shape-L shape')));
    expect(find.text('Start drawing · L shape'), findsOneWidget);
    await _tap(tester, find.text('Start drawing · L shape'));
    expect((s.screen, s.edOwner), ('aLayout', true));
    final l = s.layoutOf('anjani', room.n)!;
    expect((l.shape, l.outline?.length, l.outside.isEmpty), ('L shape', 6, true));
    expect(find.text('Everything inside the L shape walls'), findsOneWidget);
    // A bed can't be pushed into the cut-out corner.
    final cutX = l.outline![1].dx;
    final b = l.beds.keys.firstWhere((k) => l.bedRect(k).top < l.outline![2].dy);
    s.edSelect('bed:$b');
    var tries = 0;
    while (l.bedRect(b).right < cutX && tries++ < 30) {
      s.edNudge(l, 1, 0);
    }
    expect(l.bedRect(b).right <= cutX + .01, isTrue);
    expect(s.toast, 'That’s outside the walls.');
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, find.text('Publish'));
    expect(s.screen, 'oPublished');
    expect(s.liveLayout('anjani', room.n)?.shape, 'L shape');
    s.dispose();

    // A tenant's Room tab draws the same walls and says the shape.
    final t = AppState(start: 'picker', role: 'tenant', mode: 'room');
    t.layouts['anjani']![room.n] = RoomLayout(hid: 'anjani', room: room.n, w: l.w, h: l.h, beds: {}, items: [])..restore(l.snap());
    t.update(() {
      t.hid = 'anjani';
      t.room = room.n;
    });
    await _pump(tester, t);
    expect(find.text('${l.w.round()} × ${l.h.round()} ft · L shape'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('L shape')), findsWidgets);
    t.dispose();
  });

  testWidgets('Custom: Ask Hostelzy to draw it, tracked in the app; the drawing comes back; Publish v1', (tester) async {
    final server = _Server();
    final s = AppState(start: 'oLayouts', role: 'owner');
    s.data = server;
    s.picker = _Camera();
    s.update(() => s.account = (uid: 'fb-sai', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    final room = s.rooms['anjani']!.firstWhere((r) => r.share == 2);
    s.layouts['anjani']!.remove(room.n);
    s.ownerLayout(room.n);
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('shape-Custom')));
    expect((s.sheet, s.lReqShape), ('layoutReq', 'Custom'));
    expect(find.text('Ask Hostelzy to draw it'), findsWidgets);
    expect(find.textContaining('WhatsApp'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('lReqText')), 'Slanted wall near the balcony.');
    await _tap(tester, find.byKey(const ValueKey('shapePhoto')));
    await _settle(tester);
    expect(s.lReqPhotos.length, 1);
    await _tap(tester, find.text('Send request'));
    await _settle(tester);
    expect(server.calls, ['photo anjani fb-sai', 'request anjani ${room.n} Custom Slanted wall near the balcony. 14x12 anjani/fb-sai/1.jpg']);
    expect(s.toast, 'Sent. The Hostelzy team draws it within 48 hours. You get a notification.');
    expect(s.shapeReqFor('anjani', room.n)?.status, 'requested');
    await tester.pump(const Duration(seconds: 4));

    // The room's status: asked, with the hours left.
    s.ownerLayout(room.n);
    await _settle(tester);
    expect(s.screen, 'oLayout');
    expect(find.textContaining('Asked Hostelzy · 4'), findsOneWidget);
    expect(find.text('Hostelzy is drawing it'), findsOneWidget);

    // The team sends the walls back (console): the app fits the beds inside.
    server.reqs.single
      ..status = 'sent'
      ..sentAt = DateTime.now().millisecondsSinceEpoch
      ..drawing = {'w': 14, 'h': 12, 'shape': 'Custom', 'outline': [[0, 0], [14, 0], [14, 8], [10, 12], [0, 12]]};
    await s.loadShapeRequests('anjani');
    await tester.pump();
    expect(find.text('Hostelzy drew a new version · check and publish'), findsOneWidget);
    expect(find.text('v1 · drawn by Hostelzy, ${dayMon(DateTime.now())}'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('publishDrawn')));
    await _settle(tester);
    expect(server.calls.last, 'publish anjani ${room.n} Custom');
    final sent = snapFromJson(server.published['anjani|${room.n}']!);
    final check = RoomLayout(hid: 'anjani', room: room.n, w: 0, h: 0, beds: {}, items: [])..restore(sent);
    expect((sent.outline?.length, sent.beds.length, check.outside.isEmpty), (5, room.share, true));
    expect(s.screen, 'oPublished');
    expect(s.shapeReqFor('anjani', room.n), isNull);

    // Until the SQL runs, the list just stays as it was.
    server.down = true;
    await s.loadShapeRequests('anjani');
    expect(s.shapeReqs.length, 1);
    s.dispose();
  });
}
