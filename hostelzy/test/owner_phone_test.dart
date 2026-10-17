import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 item 1: the owner's number comes from the server, and only for hostels
// where this user holds a bed, enquired or stays (DECISIONS F07).

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

Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 6; k++) {
    await tester.pump();
  }
}

class _Server extends SampleRepo {
  /// Hostels the server would give a number for, and what it was asked.
  final allowed = <String, String>{};
  final asked = <List<String>>[];
  bool resident = true;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: [
    if (resident)
      {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) async {
    allowed[hid] = '9123456789';
    return 'HZ-7001';
  }

  @override
  Future<Map<String, ({String phone, String wa})>> ownerContacts(List<String> hids) async {
    asked.add(hids);
    return {for (final h in hids) if (allowed[h] != null) h: (phone: allowed[h]!, wa: '')};
  }
}

void main() {
  mapTiles = false;
  // On the server the sample owners' numbers are never there.
  final saved = Map.of(ownerPhones);
  setUp(ownerPhones.clear);
  tearDown(() => ownerPhones
    ..clear()
    ..addAll(saved));

  testWidgets('a resident messages their owner on the owner’s real number', (tester) async {
    final server = _Server()..allowed['saisri'] = '9876543210';
    final s = AppState(start: 'rHome', role: 'resident');
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
      s.myName = 'Kiran Rao';
    });
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    expect(server.asked.first, ['saisri']);
    expect(s.stayOwnerPhone, '9876543210');
    await tester.tap(find.text('Message owner'));
    await tester.pump();
    expect((s.sheet, s.waPhone), ('wa', '9876543210'));
    s.dispose();
  });

  testWidgets('a tenant gets the number once their enquiry is recorded, not before', (tester) async {
    final server = _Server()..resident = false;
    final s = AppState(start: 'detail', role: 'tenant');
    s.data = server;
    s.update(() {
      s.hid = 'nest42';
      s.account = (uid: 'fb-asha', name: 'Asha', email: 'a@gmail.com');
      s.myName = 'Asha';
      s.phone = '9876500002';
    });
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    // Nothing held or asked: nothing asked for, the number stays hidden.
    expect(server.asked, isEmpty);
    // F26 #7: locked, and no enquiry to unlock it.
    expect(find.text('Message and call the owner after you hold a bed'), findsOneWidget);
    expect(find.text('Ask on WhatsApp'), findsNothing);
    s.dispose();
  });
}
