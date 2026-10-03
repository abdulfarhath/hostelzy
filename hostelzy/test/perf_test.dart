import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/photos/photo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// Perf (no behaviour or UI change): photos batched per frame, one refetch at
// a time, a Realtime burst is one refetch, payments indexed once, and the
// 1-second clock rebuilds only the countdowns.

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

class _Server extends SampleRepo {
  _Server();
  final calls = <String>[];
  // Closed by the test that uses it.
  // ignore: close_sinks
  final changes$ = StreamController<String>.broadcast();
  Completer<void>? gate;

  @override
  bool get remote => true;

  @override
  Future<List<HostelPhoto>> photos(String hid) async {
    calls.add('photos $hid');
    return [(id: 'p-$hid', path: '$hid/1.jpg', url: 'https://x/$hid/1.jpg', label: '', ord: 0, cover: true)];
  }

  @override
  Future<Map<String, List<HostelPhoto>>> photosOfMany(List<String> hids) async {
    calls.add('photosOfMany ${hids.join(',')}');
    return {for (final h in hids) h: [(id: 'p-$h', path: '$h/1.jpg', url: 'https://x/$h/1.jpg', label: '', ord: 0, cover: true)]};
  }

  @override
  Future<LiveRows?> live({String? me}) async {
    calls.add('live');
    final g = gate;
    if (g != null) await g.future;
    return liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me);
  }

  @override
  Stream<String> changes() => changes$.stream;
}

void main() {
  test('photos asked for in the same frame come in one query', () async {
    final s = AppState(start: 'explore', role: 'tenant');
    final server = _Server();
    s.data = server;
    await Future.wait([s.loadPhotos('anjani'), s.loadPhotos('greenview'), s.loadPhotos('anjani')]);
    expect(server.calls, ['photosOfMany anjani,greenview']);
    expect(s.photosOf['anjani']!.single.id, 'p-anjani');
    expect(s.photosOf['greenview']!.single.id, 'p-greenview');
    // Loaded once: not asked again; a single hostel uses the plain query.
    await s.loadPhotos('anjani');
    await s.loadPhotos('anjani', again: true);
    expect(server.calls.last, 'photos anjani');
    expect(server.calls.length, 2);
    s.dispose();
  });

  test('refetches never run side by side; callers meanwhile share one follow-up', () async {
    final s = AppState(start: 'explore', role: 'tenant');
    final server = _Server()..gate = Completer<void>();
    s.data = server;
    final first = s.refreshLive();
    final a = s.refreshLive(), b = s.refreshLive(), c = s.refreshLive();
    await Future<void>.delayed(Duration.zero);
    expect(server.calls.where((x) => x == 'live').length, 1);
    server.gate!.complete();
    server.gate = null;
    await Future.wait([first, a, b, c]);
    // The first one, then exactly one more for everyone who asked during it.
    expect(server.calls.where((x) => x == 'live').length, 2);
    s.dispose();
  });

  testWidgets('a burst of Realtime changes is one refetch (400 ms quiet, 2 s at most)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    final server = _Server();
    s.data = server;
    s.account = (uid: 'u1', name: 'Kiran Rao', email: 'k@gmail.com');
    await s.startLive();
    int lives() => server.calls.where((x) => x == 'live').length;
    expect(lives(), 1);
    // 50 rows change at once.
    for (var i = 0; i < 50; i++) {
      server.changes$.add('payments');
    }
    await tester.pump(const Duration(milliseconds: 399));
    expect(lives(), 1);
    await tester.pump(const Duration(milliseconds: 2));
    expect(lives(), 2);
    // Changes every 100 ms for 3 s: refetched every 2 s, not never.
    for (var i = 0; i < 30; i++) {
      server.changes$.add('holds');
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(lives(), 3);
    await tester.pump(const Duration(milliseconds: 500));
    expect(lives(), 4);
    s.stopLive();
    await server.changes$.close();
    s.dispose();
  });

  test('payments are matched to holds and stays as before', () {
    final l = liveFromRows(
      me: 'me',
      holds: [
        {'id': 'h1', 'hostel_id': 'x', 'status': 'waiting', 'opt': 'advance', 'started_at': '2026-10-01T10:00:00Z'},
        {'id': 'h2', 'hostel_id': 'x', 'status': 'waiting', 'opt': 'free', 'started_at': '2026-10-01T10:00:00Z'},
      ],
      enquiries: [],
      complaints: [],
      payments: [
        {'id': 'p0', 'hostel_id': 'x', 'hold_id': 'h1', 'kind': 'advance', 'status': 'cancelled', 'amount': 1, 'created_at': '2026-10-01T10:00:00Z'},
        {'id': 'p1', 'hostel_id': 'x', 'hold_id': 'h1', 'kind': 'advance', 'status': 'waiting', 'amount': 5000, 'created_at': '2026-10-01T10:00:00Z'},
        {'id': 'p2', 'hostel_id': 'x', 'hold_id': 'h1', 'kind': 'advance', 'status': 'paid', 'amount': 6000, 'created_at': '2026-10-01T10:00:00Z'},
        {'id': 'p3', 'hostel_id': 'x', 'stay_id': 's1', 'kind': 'rent', 'status': 'paid', 'amount': 8000, 'created_at': '2026-09-01T10:00:00Z'},
        {'id': 'p4', 'hostel_id': 'x', 'stay_id': 's1', 'kind': 'rent', 'status': 'waiting', 'amount': 8000, 'created_at': '2026-10-01T10:00:00Z'},
        {'id': 'p5', 'hostel_id': 'x', 'stay_id': 's1', 'kind': 'rent', 'status': 'cancelled', 'amount': 8000, 'created_at': '2026-10-02T10:00:00Z'},
      ],
      stays: [
        {'id': 's1', 'hostel_id': 'x', 'name': 'Teja', 'rent': 8000, 'joined_on': '2026-08-01', 'confirmed': true},
        {'id': 's2', 'hostel_id': 'x', 'name': 'Ravi', 'rent': 7000, 'joined_on': '2026-08-01', 'confirmed': true},
      ],
    );
    expect([for (final h in l.holds) h.paid], [5000, 0]);
    expect([for (final r in l.residents) r.status], ['Waiting', 'Due']);
  });

  testWidgets('the 1-second clock rebuilds the countdown, not the whole app', (tester) async {
    final s = AppState(start: 'phone', role: 'tenant');
    await _pump(tester, s);
    s.sendCode();
    await tester.pump();
    expect(s.screen, 'otp');
    expect(find.text('Resend in ${cd(30)}'), findsOneWidget);
    var notified = 0;
    void count() => notified++;
    s.addListener(count);
    // (The tick reads the wall clock, so the code is made 3 s older.)
    s.codeSentAt -= 3000;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(notified, 0);
    expect(find.text('Resend in ${cd(27)}'), findsOneWidget);
    // With a sheet open everything rebuilds each second, as before.
    s.update(() => s.sheet = 'lang');
    notified = 0;
    await tester.pump(const Duration(seconds: 1));
    expect(notified, 1);
    s.removeListener(count);
    s.dispose();
  });
}
