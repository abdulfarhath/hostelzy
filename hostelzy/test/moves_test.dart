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

// F24 item 5: notice and moves go to the owner, who accepts them; moving out
// frees the bed and opens the refund, which the owner marks with the UPI
// reference and the former resident confirms.

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

Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 8; k++) {
    await tester.pump();
  }
}

class _Server extends SampleRepo {
  final calls = <String>[];
  String refund = 'sent';
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: [
    if (refund.isNotEmpty)
      {'id': 'stay-old', 'hostel_id': 'saisri', 'user_id': me, 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': '2026-09-28', 'joined_on': '2026-03-05', 'refund_amount': 4000, 'refund_status': refund, 'refund_utr': '402188341297', 'refund_sent_at': '2026-10-01T09:00:00Z', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<void> confirmRefund(String stayKey, bool got) async {
    calls.add('refund $stayKey $got');
    refund = got ? '' : 'not_received';
  }

  @override
  Future<void> giveNotice(DateTime lastDay, String reason) async => calls.add('notice ${dayMon(lastDay)} $reason');
}

void main() {
  mapTiles = false;

  testWidgets('notice goes to the owner, who accepts it; the bed shows free soon', (tester) async {
    final s = AppState(start: 'move', role: 'resident', moveTab: 'vacate');
    await _pump(tester, s);
    final day = leaveDates(s.stayHostel.terms)[1];
    await _tap(tester, find.byKey(ValueKey('vDate-$day')));
    await _tap(tester, find.text('Moving home'));
    await _tap(tester, find.text('Give notice for'));
    final n = s.myNotice!;
    expect((n.status, n.reason, dayMon(n.lastDay!)), ('open', 'Moving home', day));
    expect(find.text('Sent to Srinivas. They accept it in Hostelzy, then your bed shows "free soon".'), findsOneWidget);
    expect(find.textContaining('warden'), findsNothing);
    await tester.pump(const Duration(seconds: 4));

    // The owner sees it on Today and accepts it.
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.byKey(ValueKey('move-${n.id}')), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byKey(ValueKey('move-${n.id}')), matching: find.text('Accept')));
    expect(s.myNotice!.status, 'accepted');
    expect(s.toast, 'Accepted. Bed ${n.bed} shows free from $day.');
    await tester.pump(const Duration(seconds: 4));
    s.jump('move', 'resident');
    s.update(() => s.moveTab = 'vacate');
    await tester.pump();
    expect(find.text('NOTICE ACCEPTED'), findsOneWidget);
    s.dispose();
  });

  testWidgets('moving out frees the bed; the owner marks the refund with the UPI reference', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, s);
    final r = s.residents.firstWhere((x) => x.bed.isNotEmpty && s.findBed('anjani', x.bed).b?.state == 'booked');
    final b = s.findBed('anjani', r.bed).b!;
    // Mark as leaving from the bed sheet, then "moved out".
    s.update(() {
      s.obed = b.id;
      s.sheet = 'bed';
    });
    await tester.pump();
    await _tap(tester, find.textContaining('Mark as leaving'));
    expect(b.state, 'soon');
    await tester.pump(const Duration(seconds: 4));
    s.update(() {
      s.obed = b.id;
      s.sheet = 'bed';
    });
    await tester.pump();
    final first = r.name.split(' ').first;
    await _tap(tester, find.text('$first moved out'));
    expect((b.state, s.residents.contains(r)), ('free', false));
    final refund = s.refundsToDo.firstWhere((x) => x.name == r.name);
    expect(refund.amt, r.advance - hostelById('anjani').terms.maintenance);
    await tester.pump(const Duration(seconds: 4));

    // Today: "Refund ₹… to …" → the refund sheet (board `oRefund`).
    await _tap(tester, find.descendant(of: find.byKey(ValueKey('refund-${refund.stayKey}')), matching: find.text('Mark refunded')));
    expect(s.sheet, 'refund');
    expect(find.text('Refund $first’s advance'), findsOneWidget);
    expect(find.text('Left ${dayMon(appToday)} · Bed ${r.bed}'.toUpperCase()), findsOneWidget);
    for (final t in ['Advance', 'Kept on leaving', 'Refund', 'Pay to', 'UPI reference (UTR), 12 digits']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Mark ${fmt(refund.amt)} refunded'), findsOneWidget);
    expect(find.textContaining('Due by ${dayMon(appToday.add(const Duration(days: 7)))}, 7 days after they left.'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('refundGo')));
    expect(s.toast, 'The UPI reference is 12 digits.');
    await tester.pump(const Duration(seconds: 4));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('refundUtr')), matching: find.byType(EditableText)), '4021 8834 1297');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('refundGo')));
    expect(s.refunds.firstWhere((x) => x.stayKey == refund.stayKey).status, 'sent');
    expect((s.screen, s.sheet), ('oToday', null));
    s.dispose();
  });

  testWidgets('a former resident confirms the refund from Me', (tester) async {
    final server = _Server();
    final s = AppState(start: 'me', role: 'tenant');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    expect(find.text('₹4,000 · did it arrive?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('me-Your refund')));
    expect(s.screen, 'rRefund');
    // Board `rRefund`.
    expect(find.text('Your refund'), findsOneWidget);
    expect(find.text('Padmavathi marked it refunded · 1 Oct'.toUpperCase()), findsOneWidget);
    expect(find.text('To +91 98765 00001 · UPI ref. 4021 8834 1297'), findsOneWidget);
    for (final t in ['Advance', 'Kept on leaving', 'Due by', 'Did ₹4,000 reach your bank?', 'Yes, I got ₹4,000', 'Not received']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await _tap(tester, find.byKey(const ValueKey('refundNo')));
    await _settle(tester);
    expect(server.calls.last, 'refund stay-old false');
    expect(s.myRefund!.status, 'not_received');
    s.dispose();
  });

  testWidgets('notice on the server sends the last day', (tester) async {
    final server = _Server()..refund = '';
    final s = AppState(start: 'move', role: 'resident', moveTab: 'vacate');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    s.update(() => s.vDate = leaveDates(s.stayHostel.terms).first);
    await s.giveNotice();
    expect(server.calls.last, 'notice ${leaveDates(s.stayHostel.terms).first} ');
    expect(s.notice, isTrue);
    s.dispose();
  });

  for (final c in const ['oRefund', 'rRefund']) {
    testWidgets('moves: $c fits at 2× text', (tester) async {
      final s = AppState(start: c == 'oRefund' ? 'oToday' : 'me', role: c == 'oRefund' ? 'owner' : 'tenant');
      if (c == 'oRefund') {
        s.openRefund(s.refunds.first);
      } else {
        s.myRefund = Refund(stayKey: 'x', hid: 'anjani', name: 'Kiran', phone: '9876500001', bed: '101-A', advance: 3000, amt: 2000, status: 'sent', utr: '402188341297', leftOn: appToday);
        s.openMyRefund();
      }
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
