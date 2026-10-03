import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/photos/pick.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';
import 'package:image/image.dart' as img;

// F19 v1 extras: quick fixes (and Broken as a repair), one photo, muting.

Future<void> _pump(WidgetTester tester, AppState state) async {
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = const Size(410, 864);
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

/// A phone camera that always gives the same small photo.
class _Camera implements PhotoPicker {
  @override
  Future<Uint8List?> pick() async => Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 30)));
}

/// The server: records what the app sends.
class _Server extends SampleRepo {
  final calls = <String>[];
  // ignore: close_sinks
  final ctrl = StreamController<String>.broadcast();
  String? error;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me, stays: [
    {'id': 'st1', 'hostel_id': 'anjani', 'user_id': 'fb-rahul', 'name': 'Rahul V', 'confirmed': true, 'left_on': null, 'joined_on': '2026-03-01'},
  ]);
  @override
  Future<String> uploadFixPhoto(String hid, String uid, Uint8List jpg) async {
    calls.add('photo $hid $uid ${jpg.isNotEmpty}');
    return '$hid/$uid/1.jpg';
  }

  @override
  Future<String> sendQuickFix(String hid, int room, {required String item, required String issue, String note = '', String? photo}) async {
    if (error != null) throw Exception(error);
    calls.add('quick $hid $room $item $issue $note $photo');
    return 'qf-1';
  }
}

void main() {
  mapTiles = false;

  testWidgets('F19 extras: a resident quick-fixes an item (Broken = repair) with a photo; the owner starts work', (tester) async {
    final r = AppState(start: 'rHome', role: 'resident');
    r.picker = _Camera();
    await _pump(tester, r);
    r.openFixRoom(203);
    await tester.pump();
    // Tap the fan on the map: the quick fix sheet.
    await _tap(tester, find.byKey(ValueKey('ed-${r.liveLayout('anjani', 203)!.of('fan').first.id}')));
    expect((r.sheet, r.qfItem.startsWith('Fan')), ('quickFix', true));
    expect(find.text('Also goes to Srinivas as a repair'), findsOneWidget);
    await r.sendQuickFix();
    expect(r.toast, 'Pick what’s wrong.');
    await _tap(tester, find.byKey(const ValueKey('qf-broken')));
    expect(find.text('Send: Fan is broken'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('qfPhoto')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(r.fixPhoto, isNotNull);
    r.qfNote = 'Fan doesn’t turn';
    await r.sendQuickFix();
    expect((r.sheet, r.toast), (null, 'Sent to Srinivas as a repair.'));
    final f = r.fixes.last;
    expect((f.quick, f.broken, f.item, f.note, f.photo != null), (true, true, 'Fan', 'Fan doesn’t turn', true));

    // The owner: a repair card on Today, with the photo; Start work closes it.
    final o = AppState(start: 'oToday', role: 'owner');
    o.fixes = [f];
    o.fixPhotosLocal.addAll(r.fixPhotosLocal);
    await _pump(tester, o);
    expect(find.text('Broken: Fan, Room 203'), findsOneWidget);
    expect(find.textContaining('“Fan doesn’t turn” · 1 photo'), findsOneWidget);
    await _tap(tester, find.text('Start work'));
    await tester.pump();
    expect((f.status, f.repair), ('approved', 'working'));
    expect(find.text('Broken: Fan, Room 203'), findsNothing);

    // A quick fix that isn't a repair: Got it (no layout change).
    final q = LayoutFix(id: 'q2', hid: 'anjani', room: 203, snap: o.liveLayout('anjani', 203)!.snap(), at: 0, author: 'Rahul V.', kind: 'quick', issue: 'wrong_place', item: 'Window', authorId: 'me');
    o.update(() => o.fixes = [...o.fixes, q]);
    await tester.pump();
    expect(find.text('Quick fix: Window is in the wrong place, Room 203'), findsOneWidget);
    final v = o.layoutOf('anjani', 203)!.version;
    await _tap(tester, find.text('Got it'));
    expect((q.status, o.layoutOf('anjani', 203)!.version), ('approved', v));
    r.dispose();
    o.dispose();
  });

  testWidgets('F19 extras: the owner mutes a resident; they see suggestions are off; Manage turns them back on', (tester) async {
    final o = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, o);
    final f = o.fixesWaiting.first; // the sample fix from Rahul for room 203
    o.openFix(f);
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('muteLink')));
    expect(o.sheet, 'fixMute');
    expect(find.text('Unmute any time in Manage → Residents.'), findsOneWidget);
    await _tap(tester, find.text('Mute Rahul’s suggestions').last);
    await tester.pump();
    expect((f.status, o.sheet, o.mutedHere.single.name), ('rejected', null, 'Rahul V.'));
    // Manage → Residents lists them with Turn on.
    o.update(() {
      o.screen = 'oMore';
      o.moreTab = 'residents';
    });
    await tester.pump();
    expect(find.text('Layout suggestions off'.toUpperCase()), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // the mute toast goes
    await _tap(tester, find.text('Turn on'));
    expect(o.mutedHere, isEmpty);

    // A muted resident sees it on the room and can't edit.
    final r = AppState(start: 'rHome', role: 'resident');
    r.fixMutes = [(hid: 'anjani', uid: 'me', name: 'Rahul V.')];
    await _pump(tester, r);
    r.openFixRoom(203);
    await tester.pump();
    expect(find.text('Suggestions are off for this hostel'), findsOneWidget);
    expect(find.text('Edit room'), findsNothing);
    r.openFixEditor('anjani', 203);
    expect((r.screen, r.toast), ('rRoom', 'Suggestions are off for this hostel.'));
    o.dispose();
    r.dispose();
  });

  testWidgets('F19 extras: on the server the photo uploads first, then the quick fix; a mute says so', (tester) async {
    final r = AppState(start: 'rHome', role: 'resident');
    final server = _Server();
    r
      ..data = server
      ..picker = _Camera();
    r.update(() => r.account = (uid: 'fb-rahul', name: 'Rahul V', email: 'r@gmail.com'));
    await r.startLive();
    r.update(() {
      r.fixHid = 'anjani';
      r.fixRoom = 203;
      r.qfItem = 'AC unit';
      r.qfIssue = 'broken';
      r.qfNote = 'No cooling';
    });
    await r.pickFixPhoto();
    await r.sendQuickFix();
    expect(server.calls, ['photo anjani fb-rahul true', 'quick anjani 203 AC unit broken No cooling anjani/fb-rahul/1.jpg']);
    server.error = 'suggestions are off for this hostel';
    r.update(() => r.qfIssue = 'missing');
    await r.sendQuickFix();
    expect(r.toast, 'Suggestions are off for this hostel.');
    r.stopLive();
    r.dispose();
  });
}
