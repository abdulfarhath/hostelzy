import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/links/scan.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 4b: a women's PG's floor on the server (F12), one editor at a
// time (F12), "Tell me when it's ready" (F24 #27), scan the invite QR (F14)
// and the brand's push icon + dark splash.

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
  await tester.runAsync(() async {
    for (var k = 0; k < 6; k++) {
      await Future<void>.delayed(Duration.zero);
    }
  });
  await tester.pump();
}

const _w = 'a7000000-0000-0000-0000-000000000001';
const _m = 'a7000000-0000-0000-0000-000000000002';

Map<String, dynamic> _room(int n) => {
  'number': n, 'label': null, 'floor': 1, 'share': 1, 'rent': 9000, 'ac': false, 'bath': 'Shared',
  'beds': [{'id': 'bed-$n', 'letter': 'A', 'spot': '', 'state': 'free'}],
};

Map<String, dynamic> _layout(int n) => {'room': n, 'stage': 'published', 'version': 1, 'w': 10, 'h': 12, 'beds': {'A': [1, 1]}, 'items': [], 'updated_at': '2026-10-01T10:00:00Z'};

/// A women's PG (its layouts not in the list: RLS) and a men's PG whose room
/// 204 has no layout yet.
List<Map<String, dynamic>> _rows() => [
  {'id': _w, 'name': 'Lotus Women PG', 'gender': 'Women', 'area': 'KPHB', 'owner_name': 'Lalitha', 'status': 'live', 'rate_cards': [{'ac': false, 'share': 1, 'rent': 9000}], 'rooms': [_room(101), _room(102)], 'layouts': []},
  {'id': _m, 'name': 'Lotus Men PG', 'gender': 'Men', 'area': 'KPHB', 'owner_name': 'Raju', 'status': 'live', 'rate_cards': [{'ac': false, 'share': 1, 'rent': 9000}], 'rooms': [_room(204), _room(205)], 'layouts': [_layout(205)]},
];

class _Server extends SampleRepo {
  final calls = <String>[];
  ({String name, bool mine}) lock = (name: 'Ravi', mine: true);
  String? publishFails;
  Set<String> waits = {};

  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => listingsFromRows(_rows());
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me, staff: [if (me == 'fb-raju') {'hostel_id': _m, 'user_id': 'fb-raju', 'role': 'owner'}]);

  @override
  Future<RoomLayout?> roomLayout(String hid, int room) async {
    calls.add('room $room');
    if (room == 102) throw Exception('hold a bed to see more rooms here');
    return layoutFromRow(hid, _layout(room));
  }

  @override
  Future<void> waitForLayout(String hid, int room) async => calls.add('wait $room');
  @override
  Future<Set<String>> layoutWaits() async => waits;

  @override
  Future<({String name, bool mine})> lockLayout(String hid, int room) async {
    calls.add('lock $room');
    return lock;
  }

  @override
  Future<void> unlockLayout(String hid, int room) async => calls.add('unlock $room');

  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) async {
    if (publishFails != null) throw Exception(publishFails);
    calls.add('publish $room');
  }

  @override
  Future<String> joinWithInvite(String code, {required String name, required String phone, String bed = ''}) async {
    calls.add('join $code');
    return 'Lotus Women PG';
  }
}

Future<AppState> _onServer(_Server server, {String start = 'picker', String role = 'tenant', String uid = 'fb-tenant'}) async {
  final s = AppState(start: start, role: role);
  s.data = server;
  s.update(() => s.account = (uid: uid, name: 'Divya', email: 'd@gmail.com'));
  final l = await server.listings();
  if (l != null) s.applyListings(l);
  await s.startLive();
  return s;
}

/// A scanner without a camera: a button that "reads" [code].
class _FakeScanner implements QrScanner {
  _FakeScanner(this.code);
  String code;
  @override
  bool get available => true;
  @override
  Widget view(void Function(String raw) onCode, Widget Function(bool denied) onError) => GestureDetector(key: const ValueKey('fakeQr'), behavior: HitTestBehavior.opaque, onTap: () => onCode(code), child: const SizedBox.expand());
}

void main() {
  mapTiles = false;

  testWidgets('F12: a women\'s PG\'s room comes from the server one by one; past the day\'s rooms it asks for a hold', (tester) async {
    final server = _Server();
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server));
    expect(s.layoutOf(_w, 101), isNull); // not in the list
    s.update(() {
      s.hid = _w;
      s.floor = 1;
      s.room = 101;
      s.mode = 'room';
    });
    await _pump(tester, s);
    await _settle(tester);
    expect(server.calls, contains('room 101'));
    expect(s.liveLayout(_w, 101), isNotNull);
    expect(find.text('Layout coming soon'), findsNothing);
    expect(find.textContaining('10 × 12 ft'), findsOneWidget);
    // the next room: the server wants a hold first
    s.update(() => s.room = 102);
    await tester.pump();
    await _settle(tester);
    expect(server.calls, contains('room 102'));
    expect(find.byKey(const ValueKey('roomCapped')), findsOneWidget);
    expect(find.text('Floor plan shows after you hold a bed'), findsOneWidget);
    // asked once: no loop of requests
    await tester.pump();
    expect(server.calls.where((c) => c == 'room 102').length, 1);
    s.stopLive();
    s.dispose();
  });

  testWidgets('F24 #27: "Tell me when it\'s ready" is saved on the server and shows "We\'ll tell you"', (tester) async {
    final server = _Server()..waits = {'$_m|205'};
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server));
    s.update(() {
      s.hid = _m;
      s.floor = 1;
      s.room = 204;
      s.mode = 'room';
    });
    await _pump(tester, s);
    await _settle(tester);
    expect(find.text('Layout coming soon'), findsOneWidget);
    expect(find.textContaining('Alerts come once the app is online'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('layoutNotify')));
    await _settle(tester);
    expect(server.calls, contains('wait 204'));
    expect(find.byKey(const ValueKey('layoutWaiting')), findsOneWidget);
    expect(find.text('We’ll tell you'), findsOneWidget);
    expect(s.toast, 'We’ll tell you when room 204’s layout is ready.');
    // the server's list came in too
    expect(s.waitingForLayout(_m, 205), isTrue);
    s.stopLive();
    s.dispose();
  });

  test('F24 #27: sample data keeps it on this phone', () async {
    final s = AppState(start: 'picker', role: 'tenant');
    final h = s.rooms.keys.first;
    final n = s.rooms[h]!.first.n;
    await s.tellMeWhenReady(h, n);
    expect(s.waitingForLayout(h, n), isTrue);
    s.dispose();
  });

  testWidgets('F12: one editor at a time: someone else\'s lock blocks Publish until it\'s free', (tester) async {
    final server = _Server()..lock = (name: 'Lalitha', mine: false);
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'oLayouts', role: 'owner', uid: 'fb-raju'));
    s.update(() => s.ownHid = _m);
    await _pump(tester, s);
    s.openLayout(205, editor: true, owner: true);
    await _settle(tester);
    expect(server.calls, contains('lock 205'));
    expect(find.byKey(const ValueKey('edLocked')), findsOneWidget);
    expect(find.text('Lalitha is editing this room'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('edPublish')));
    expect(s.toast, 'Lalitha is editing this room. Try again when they’re done.');
    expect(server.calls.where((c) => c.startsWith('publish')), isEmpty);
    // she is done: Check again takes it
    server.lock = (name: 'Raju', mine: true);
    await _tap(tester, find.byKey(const ValueKey('edLockRetry')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('edLocked')), findsNothing);
    // the server still refuses when someone took it in between
    server.publishFails = 'PostgrestException(message: Lalitha is editing this room. Try again when they\'re done., code: P0001)';
    await _tap(tester, find.byKey(const ValueKey('edPublish')));
    await _settle(tester);
    expect(s.toast, 'Lalitha is editing this room. Try again when they’re done.');
    expect(find.text('Lalitha is editing this room'), findsOneWidget);
    // free again: publish goes through and the lock is let go
    server
      ..publishFails = null
      ..lock = (name: 'Raju', mine: true);
    await _tap(tester, find.byKey(const ValueKey('edLockRetry')));
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('edPublish')));
    await _settle(tester);
    expect(server.calls, containsAllInOrder(['publish 205', 'unlock 205']));
    expect(s.screen, 'oPublished');
    expect(s.edLock, isNull);
    s.stopLive();
    s.dispose();
  });

  testWidgets('F12: leaving the editor or switching rooms lets the lock go', (tester) async {
    final server = _Server();
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'oLayouts', role: 'owner', uid: 'fb-raju'));
    s.update(() => s.ownHid = _m);
    await _pump(tester, s);
    s.openLayout(205, editor: true, owner: true);
    await _settle(tester);
    s.edSwitchRoom(204);
    await _settle(tester);
    expect(server.calls, containsAllInOrder(['lock 205', 'unlock 205', 'lock 204']));
    s.back();
    await _settle(tester);
    expect(server.calls.last, 'unlock 204');
    s.stopLive();
    s.dispose();
  });

  test('F14: the invite code in a scanned QR', () {
    expect(inviteCodeFromQr('https://abdulfarhath.github.io/hostelzy/app/j/?c=ANJ-7Q2'), 'ANJ-7Q2');
    expect(inviteCodeFromQr('hostelzy://app/j?c=anj-7q2'), 'ANJ-7Q2');
    expect(inviteCodeFromQr(' ANJ-7Q2 '), 'ANJ-7Q2');
    expect(inviteCodeFromQr('https://abdulfarhath.github.io/hostelzy/app/r/?c=HZ-1234'), isNull);
    expect(inviteCodeFromQr('https://example.com/?c=ANJ-7Q2'), isNull);
    expect(inviteCodeFromQr('hello'), isNull);
  });

  testWidgets('F14: Scan the QR: explainer first, then the camera; the code fills in and joins', (tester) async {
    final server = _Server();
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'roleGate'));
    final cam = _FakeScanner('https://example.org/x');
    s
      ..scanner = cam
      ..phone = '9876543210';
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('scanQr')));
    expect(s.sheet, 'scanCam');
    expect(find.text('Use your camera?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('allowCamera')));
    expect((s.screen, s.camAsked), ('scan', true));
    // another app's QR: said so, still scanning
    await _tap(tester, find.byKey(const ValueKey('fakeQr')));
    expect(s.toast, 'That QR isn’t a Hostelzy invite. Scan the poster at your PG.');
    expect(s.screen, 'scan');
    // the poster's QR
    cam.code = 'https://abdulfarhath.github.io/hostelzy/app/j/?c=ANJ-7Q2';
    await _tap(tester, find.byKey(const ValueKey('fakeQr')));
    await _settle(tester);
    expect(s.screen, 'roleGate');
    expect(server.calls, contains('join ANJ-7Q2'));
    expect(s.toast, 'Asked to join Lotus Women PG. Your owner approves it, then your stay opens here.');
    // next time: straight to the camera
    await _tap(tester, find.byKey(const ValueKey('scanQr')));
    expect((s.sheet, s.screen), (null, 'scan'));
    await _tap(tester, find.byKey(const ValueKey('scanType')));
    expect(s.screen, 'roleGate');
    s.stopLive();
    s.dispose();
  });

  testWidgets('F14: without an in-app camera it says how to use the phone\'s', (tester) async {
    final s = AppState(start: 'roleGate', role: 'tenant');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('scanQr')));
    expect(s.toast, 'Open your phone camera and point it at the poster. It opens the invite link.');
    s.dispose();
  });

  testWidgets('F14: the scan screen when the camera is off', (tester) async {
    final s = AppState(start: 'scan', role: 'tenant');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('scanError')), findsOneWidget);
    expect(find.text('Scan the QR'), findsOneWidget);
    s.dispose();
  });

  test('Brand: server pushes and the splash use the brand assets', () {
    const res = 'android/app/src/main/res';
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('com.google.firebase.messaging.default_notification_icon'));
    expect(manifest, contains('@drawable/ic_stat_hostelzy'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(File('$res/drawable/ic_stat_hostelzy.xml').existsSync(), isTrue);
    expect(File('$res/drawable-mdpi/ic_stat_hostelzy.png').existsSync(), isFalse);
    expect(File('$res/values/colors.xml').readAsStringSync(), contains('#F3F2F2'));
    expect(File('$res/values-night/colors.xml').readAsStringSync(), contains('#161514'));
    for (final d in ['drawable-xxhdpi', 'drawable-night-xxhdpi']) {
      expect(File('$res/$d/splash_icon.png').existsSync(), isTrue, reason: d);
    }
    expect(File('$res/values-night-v31/styles.xml').readAsStringSync(), contains('windowSplashScreenBackground'));
    expect(File('../supabase/functions/_shared/fcm.ts').readAsStringSync(), contains("PUSH_ICON = 'ic_stat_hostelzy'"));
  });
}
