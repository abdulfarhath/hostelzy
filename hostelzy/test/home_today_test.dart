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
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/screens_owner.dart' show allRequests;
import 'package:hostelzy/ui/shell.dart';

// F21 Wave 3: resident Home has one job (rent and food) with three actions,
// Help sends to the owner with a photo and shows the status inline, owner
// Today is one "Needs you now" list, and Manage is one vertical list.

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

class _Picker implements PhotoPicker {
  @override
  Future<Uint8List?> pick() async => Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 300)));
}

/// The server for one resident, Kiran, at Sai Sri.
class _Server extends SampleRepo {
  final calls = <String>[];
  final complaints = <Map<String, dynamic>>[];
  final ctrl = StreamController<String>.broadcast();
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], payments: [], complaints: complaints, me: me, stays: [
    {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<String> uploadComplaintPhoto(String hid, String uid, Uint8List jpg) async {
    calls.add('upload $hid $uid ${jpg.isNotEmpty}');
    return '$hid/$uid/1.jpg';
  }

  @override
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body, String? photo}) async {
    calls.add('complaint $hid $bed $cat $body $photo');
    complaints.add({'id': '00000000-0000-0000-0000-0000000000c1', 'hostel_id': hid, 'author_id': 'fb-kiran', 'bed': bed, 'cat': cat, 'body': body, 'status': 'Open', 'note': '', 'photo': photo, 'created_at': DateTime.now().toUtc().toIso8601String()});
  }
}

void main() {
  mapTiles = false;

  testWidgets('F21 W3: resident Home is rent, three actions and food; the rest is in Me › My stay', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    s.myName = 'Rahul Varma';
    await _pump(tester, s);
    for (final a in ['Pay rent', 'Raise complaint', 'Message owner']) {
      expect(find.byKey(ValueKey('quick-$a')), findsOneWidget);
    }
    expect(find.text('Give notice'), findsNothing);
    expect(find.text('Swap bed'), findsNothing);
    expect(find.textContaining('Room layouts', findRichText: true), findsNothing);
    expect(find.text('RV'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('quick-Raise complaint')));
    expect(s.screen, 'help');
    s.tab('me');
    await tester.pump();
    expect(find.text('Bed 204-B · Anjani Residency'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('me-My stay')));
    expect(s.screen, 'rStay');
    await _tap(tester, find.text('Give notice'));
    expect((s.screen, s.moveTab), ('move', 'vacate'));
    s.dispose();
  });

  testWidgets('F21 W3: Help sends to the owner with a photo; the status shows inline; the owner sees the photo', (tester) async {
    final s = AppState(start: 'help', role: 'resident');
    s.update(() => s.complaints = s.complaints.where((c) => !c.mine).toList());
    s.picker = _Picker();
    await _pump(tester, s);
    expect(find.text('No complaints'), findsOneWidget);
    expect(find.text('When something breaks, tell Srinivas here. You’ll see when it’s fixed.'), findsOneWidget);
    await _tap(tester, find.text('Water'));
    await tester.enterText(find.byType(EditableText).first, 'Leak under the sink');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('cPhoto')));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(s.cPhoto, isNotNull);
    await _tap(tester, find.text('Send to owner'));
    final c = s.complaints.last;
    expect((c.cat, c.text, c.status, s.cPhoto, s.complaintPhotosLocal.containsKey(c.id)), ('Water', 'Leak under the sink', 'Open', null, true));
    expect(find.text('SENT'), findsOneWidget);
    expect(find.textContaining('Just now'), findsOneWidget);

    // Owner: Manage → Complaints → See photo.
    s.jump('oMore', 'owner');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('manage-Complaints')));
    await _tap(tester, find.byKey(ValueKey('cphoto-${c.id}')));
    expect(s.sheet, 'cPhoto');
    expect(find.byType(Image), findsWidgets);
    s.update(() => s.sheet = null);
    // Start work → the resident reads "Being fixed".
    await s.advanceComplaint(s.complaints.last);
    s.jump('help', 'resident');
    await tester.pump();
    expect(find.text('BEING FIXED'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F21 W3: on the server the photo goes up first, then the complaint points at it', (tester) async {
    final s = AppState(start: 'help', role: 'resident');
    final server = _Server();
    s.data = server;
    s.picker = _Picker();
    s.update(() => s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    s.update(() {
      s.cCat = 'Water';
      s.cText = 'Leak';
    });
    await tester.runAsync(s.pickComplaintPhoto);
    await tester.runAsync(s.raiseComplaint);
    await tester.pump();
    expect(server.calls, ['upload saisri fb-kiran true', 'complaint saisri 101-A Water Leak saisri/fb-kiran/1.jpg']);
    expect(s.complaints.single.photo, 'saisri/fb-kiran/1.jpg');
    expect(find.textContaining('${hostelById('saisri').owner} sees it in the app'), findsOneWidget);
    s.stopLive();
    s.dispose();
  });

  testWidgets('F21 W3: owner Today is one "Needs you now" list; Manage is one vertical list', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, s);
    final n = allRequests(s).length + s.payments.where((x) => x.hid == s.ownHid && x.status == 'waiting').length + s.enquiries.where((e) => e.hid == s.ownHid && !e.contacted).length + s.fixesWaiting.length + s.brokenThings.length + s.openMoves.length + s.refundsToDo.length;
    expect(n, greaterThan(2));
    expect(find.text('NEEDS YOU NOW · $n'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(find.text('beds taken'), findsOneWidget);
    expect(find.text('Add tenant'), findsOneWidget);
    expect(find.text('Booking'), findsNothing);
    // The first hold is the one with the least time left.
    final first = (allRequests(s)..sort((a, b) => (a.secs - (s.now - a.start) / 1000).compareTo(b.secs - (s.now - b.start) / 1000))).first;
    expect(find.text('Hold on bed ${first.bed}'), findsOneWidget);

    // Manage: one list, badges where something waits, a section opens and comes back.
    s.tab('oMore');
    s.update(() => s.moreTab = 'home');
    await tester.pump();
    for (final r in ['Enquiries', 'Residents', 'Complaints', 'Deals', 'Rates and UPI', 'Food menu', 'House rules', 'Photos', 'Room layouts', 'Reviews and ranking', 'Team', 'Your plan']) {
      expect(find.byKey(ValueKey('manage-$r')), findsOneWidget, reason: r);
    }
    await _tap(tester, find.byKey(const ValueKey('manage-Residents')));
    expect(s.moreTab, 'residents');
    // Owner words: where a resident came from.
    expect(find.textContaining('Came from the app'), findsWidgets);
    expect(find.textContaining('Via Hostelzy'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('manageBack')));
    expect(s.moreTab, 'home');
    await _tap(tester, find.byKey(const ValueKey('manage-Reviews and ranking')));
    expect(s.screen, 'oRank');
    // F22 Area 3: reviews and ranking are one page; the reviews and Reply are on it.
    expect(find.text('Reviews and ranking'), findsOneWidget);
    await _tap(tester, find.text('Reply').first);
    expect(find.text('Post reply'), findsOneWidget);
    s.dispose();
  });
}
