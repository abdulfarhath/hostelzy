import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/hostel_screen.dart' show dealHeadline;
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 0: no fake or false lines in the real build, owners draw their own
// layouts, the deal headline is the 6-month saving, Settings › Name.

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

/// A signed-in user on the server; records the name saves.
class _Server extends SampleRepo {
  final names = <String>[];
  bool fail = false;
  // ignore: close_sinks
  final ctrl = StreamController<String>.broadcast();
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: []);
  @override
  Future<void> saveName(String uid, String name) async {
    if (fail) throw Exception('offline');
    names.add('$uid $name');
  }
}

Listings _oneLive() => listingsFromRows([
  {
    'id': '10000000-0000-0000-0000-000000000009',
    'name': 'Wave Zero PG',
    'gender': 'Men',
    'area': 'Kondapur',
    'lat': 17.46,
    'lng': 78.36,
    'owner_name': 'Imran',
    'food': false,
    'ac': false,
    'only_ac': false,
    'instant': false,
    'tags': <String>[],
    'terms': {'advance': 5000, 'maintenance': 1000, 'noticeDays': 30, 'dueOnJoining': true, 'electricityExtra': true},
    'upi_id': '',
    'upi_name': '',
    'rate_cards': [
      {'ac': false, 'share': 2, 'rent': 9000},
    ],
    'rooms': [
      {
        'number': 101, 'label': null, 'floor': 1, 'share': 2, 'rent': 9000, 'ac': false, 'bath': 'Attached',
        'beds': [
          {'letter': 'A', 'spot': '', 'state': 'free', 'free_from': null},
          {'letter': 'B', 'spot': '', 'state': 'booked', 'free_from': null},
        ],
      },
    ],
    'layouts': <Map<String, dynamic>>[],
  },
]);

void main() {
  mapTiles = false;
  tearDown(() => AppState.samples = true);

  testWidgets('a live hostel never says "confirmed by the owner today" and has no made-up deal', (tester) async {
    final l = _oneLive();
    final h = l.hostels.single;
    final s = AppState(start: 'detail', role: 'tenant');
    s.applyListings(l);
    s.hid = h.id;
    // Unknown stays unknown: not "today", and not called stale either.
    expect(s.confirmed.containsKey(h.id), isFalse);
    expect(s.stale(h.id), isFalse);
    await _pump(tester, s);
    expect(find.textContaining('1 free bed', findRichText: true), findsOneWidget);
    expect(find.textContaining('confirmed by the owner', findRichText: true), findsNothing);
    expect(find.textContaining('Availability not confirmed', findRichText: true), findsNothing);
    // No deals: no green headline.
    expect(find.byKey(const ValueKey('dealHeadline')), findsNothing);
    s.dispose();
    resetSampleData();
  });

  testWidgets('deal headline = 6-month saving with its parts, from the real deals', (tester) async {
    const t = Terms(advance: 5000);
    expect(dealHeadline(DealQuote(t, 8000, const {})), isNull);
    expect(dealHeadline(DealQuote(t, 8000, const {'advance', 'monthly'})), ('Save ₹1,200 in 6 months', '₹1,000 off the advance + ₹200 off every month'));
    expect(dealHeadline(DealQuote(t, 8000, const {'advance'})), ('₹1,000 less upfront', '₹1,000 off the advance'));
    expect(dealHeadline(DealQuote(t, 8000, const {'exit'})), ('₹500 more back when you leave', '₹500 more back when you leave'));

    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    final (head, parts) = dealHeadline(s.bestQuote('anjani'))!;
    expect(head, startsWith('Save '));
    expect(head, endsWith(' in 6 months'));
    expect(parts, contains('₹200 off every month'));
    expect(find.descendant(of: find.byKey(const ValueKey('dealHeadline')), matching: find.text(head)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('dealHeadline')), matching: find.text(parts)), findsOneWidget);
    s.dispose();
  });

  testWidgets('real build: no sample "Did you join?" card; answers say only "Thanks."', (tester) async {
    AppState.samples = false;
    final s = AppState(start: 'holds', role: 'tenant');
    await _pump(tester, s);
    expect(s.endedHold, isNull);
    expect(find.byKey(const ValueKey('joinedAsk')), findsNothing);
    expect(find.textContaining('Anjani'), findsNothing);
    s.answerJoined('no');
    expect(s.toast, 'Thanks.');
    s.dispose();
  });

  testWidgets('real build: the AC repair note has no invented date', (tester) async {
    for (final f in [
      // Was lib/ui/screens_tenant.dart and lib/ui/layout.dart.
      'lib/features/explore/explore_screen.dart',
      'lib/features/explore/hostel_screen.dart',
      'lib/features/holds/holds_screens.dart',
      'lib/features/holds/picker_screen.dart',
      'lib/features/session/me_screen.dart',
      'lib/features/layouts/layout_map.dart',
      'lib/features/layouts/owner_layout_screens.dart',
      'lib/features/layouts/admin_layout_screen.dart',
    ]) {
      expect(File(f).readAsStringSync().contains('Complaint raised 30 Sep'), isFalse, reason: f);
    }
  });

  testWidgets('Settings › Name: empty field, current name as hint, saved on the server', (tester) async {
    final s = AppState(start: 'settings', role: 'tenant');
    final server = _Server();
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com');
      s.myName = 'Asha K';
    });
    await s.startLive();
    await _pump(tester, s);
    expect(find.textContaining('comes with your account'), findsNothing);
    await tester.tap(find.text('Name'));
    await tester.pump();
    expect(s.sheet, 'name');
    expect(find.text('Change your name'), findsOneWidget);
    expect(s.nameDraft, '');
    // Nothing typed: nothing saved.
    await tester.tap(find.text('Save name'));
    await tester.pump();
    expect(s.toast, 'Enter your name.');
    expect(server.names, isEmpty);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('nameEdit')), matching: find.byType(TextField)), '  Asha   Kumari ');
    await tester.pump();
    // Offline: the name stays as it was.
    server.fail = true;
    await s.saveName();
    expect((s.myName, s.sheet), ('Asha K', 'name'));
    server.fail = false;
    await s.saveName();
    await tester.pump();
    expect((s.myName, s.sheet, s.toast), ('Asha Kumari', null, 'Name saved.'));
    expect(server.names, ['fb-asha Asha Kumari']);
    s.stopLive();
    s.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('real owner, plan 15 days late: deals paused, tenants see walk-in prices only (F24 item 21: the server pauses them)', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    s.data = _Server();
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    s.update(() => s.invoice = Invoice(ref: 'HZ-INV-2001', hid: s.ownHid, beds: 30, amt: 499, due: appToday.subtract(const Duration(days: 15)), status: 'due', late: 15));
    await _pump(tester, s);
    expect(find.text('Deals paused: plan 15 days late'), findsOneWidget);
    expect(find.textContaining('Tenants see walk-in prices only'), findsOneWidget);
    s.stopLive();
    s.dispose();
  });

  test('no OTP wording and no "Hostelzy draws your layout" promises left in the app', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    final quoted = RegExp(r"'[^'\n]*'");
    for (final f in files) {
      // The SMS sign-in screen stays behind `phoneOtpLogin` (off) for later.
      if (f.path.endsWith('screens_start.dart')) continue;
      for (final m in quoted.allMatches(f.readAsStringSync())) {
        final str = m.group(0)!;
        expect(RegExp(r'\bOTP\b').hasMatch(str), isFalse, reason: '${f.path}: $str');
        expect(str.contains('Hostelzy draws its layout') || str.contains('team adds it within 48') || str.contains('team adds the AC unit'), isFalse, reason: '${f.path}: $str');
      }
    }
  });
}
