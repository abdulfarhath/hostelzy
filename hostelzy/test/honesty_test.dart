import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F21 Wave 1: honesty. Resident screens show the resident's real stay on the
// server (never the Anjani sample), and no screen asks for a code nobody sent.

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

/// The server for one resident, Kiran, at Sai Sri (bed 101-A, ₹9,000).
class _Server extends SampleRepo {
  final calls = <String>[];
  final payments = <Map<String, dynamic>>[];
  final ctrl = StreamController<String>.broadcast();
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: payments, stays: [
    {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<void> startRent({required String hid, required String stayKey, required int amount, required String note}) async {
    calls.add('rent $hid $stayKey $amount $note');
    payments.add({'id': 'pay-rent-1', 'hostel_id': hid, 'kind': 'rent', 'amount': amount, 'note': note, 'status': 'pending', 'payer_name': 'Kiran Rao', 'created_at': DateTime.now().toUtc().toIso8601String()});
  }
}

void main() {
  mapTiles = false;

  testWidgets('F21 W1: a real resident sees their own stay, not the sample one', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    final server = _Server();
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
      s.myName = 'Kiran Rao';
    });
    await s.startLive();
    await _pump(tester, s);
    final h = hostelById('saisri');
    expect((s.myStay?.hid, s.myStay?.bed, s.myStay?.rent, s.myStay?.joinDay), ('saisri', '101-A', 9000, 5));
    // Home: their hostel, room, bed and rent; no sample board, no sample menu.
    expect(find.text('${h.name} · Room 101 · Bed A'.toUpperCase()), findsOneWidget);
    expect(find.text('₹9,000'), findsOneWidget);
    expect(find.textContaining('Anjani'), findsNothing);
    expect(find.textContaining('Srinivas'), findsNothing);
    expect(find.textContaining('board'.toUpperCase()), findsNothing);
    expect(find.text('${h.owner} hasn’t put the menu on Hostelzy yet.'), findsOneWidget);
    expect(find.text("Today's food · $todayName".toUpperCase()), findsOneWidget);

    // Pay rent: the real amount; paying starts this month's rent on the server first.
    s.tab('rPay');
    await tester.pump();
    expect(find.textContaining('Anjani'), findsNothing);
    expect(find.text('Pay ${h.owner}'), findsOneWidget);
    expect(find.text('Rent, bed 101-A'), findsOneWidget);
    expect(find.text('I’ve paid · enter UTR'), findsNothing); // nothing to enter a UTR for yet
    expect(find.text('History'.toUpperCase()), findsNothing); // no sample history
    await s.payMyRent();
    await tester.pump();
    expect(server.calls.single, 'rent saisri stay-1 9000 ${s.rentNote}');
    expect(s.myRentPay?.id, 'pay-rent-1');
    // A second tap reuses this month's payment.
    await s.payMyRent();
    expect(server.calls.length, 1);

    // Avatar initials come from the user's name.
    s.tab('me');
    await tester.pump();
    expect(find.text('KR'), findsOneWidget);
    s.stopLive();
    s.dispose();
  });

  testWidgets('F21 W1: owners accept Fair Play with "I agree"; no code anywhere', (tester) async {
    final s = AppState(start: 'oRules', role: 'owner');
    await _pump(tester, s);
    expect(find.textContaining('code'), findsNothing);
    s.acceptFairPlay();
    expect((s.fairAccepted, s.toast), (false, 'Tick “I agree” first.'));
    await tester.tap(find.byKey(const ValueKey('fpAgree')));
    await tester.pump();
    s.acceptFairPlay();
    expect(s.fairAccepted, isTrue);
    s.dispose();
  });
}
