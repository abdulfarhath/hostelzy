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

// F24 Wave 2b: "Still N free beds?" and the layouts check saved on the server
// (item 9); the deal a booking locked, kept on the server (item 13); "Did you
// join?" answered Yes / Not yet / Still deciding, for the team only (item 14).

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
  for (var k = 0; k < 8; k++) {
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// A live hostel as the server sends it: two free beds and one taken.
Map<String, dynamic> _hostel(String id, {String? bedsAt, String? layoutAt}) => {
  'id': id,
  'name': 'Real PG',
  'gender': 'Men',
  'area': 'Madhapur',
  'status': 'live',
  'owner_name': 'Ravi',
  'terms': {'advance': 3000, 'maintenance': 1000},
  'rate_cards': [],
  'deals': null,
  'reviews': [],
  'rooms': [
    {
      'number': 101, 'floor': 1, 'share': 3, 'rent': 8000,
      'beds': [
        {'id': '$id-a', 'letter': 'A', 'state': 'free', 'confirmed_at': bedsAt},
        {'id': '$id-b', 'letter': 'B', 'state': 'free', 'confirmed_at': bedsAt},
        {'id': '$id-c', 'letter': 'C', 'state': 'booked', 'confirmed_at': bedsAt},
      ],
    },
  ],
  'layouts': [
    if (layoutAt != null) {'room': 101, 'stage': 'published', 'w': 12, 'h': 10, 'beds': {}, 'items': [], 'version': 1, 'updated_at': layoutAt, 'confirmed_at': layoutAt},
  ],
};

class _Server extends SampleRepo {
  final calls = <String>[];
  List<Map<String, dynamic>> hostels = [];
  List<Map<String, dynamic>> holds = [];
  Set<String> answered = {};
  bool down = false;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => listingsFromRows(hostels);
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: holds, enquiries: [], complaints: [], me: me, payments: []);
  @override
  Future<void> confirmBeds(String hid) async => calls.add('beds $hid');
  @override
  Future<void> confirmLayouts(String hid) async => calls.add('layouts $hid');
  @override
  Future<void> answerJoined(String holdId, String answer) async {
    if (down) throw Exception('offline');
    calls.add('join $holdId $answer');
  }

  @override
  Future<Set<String>> joinAnswers() async {
    calls.add('answers');
    return answered;
  }
}

Future<AppState> _owner(WidgetTester tester, _Server server) async {
  final s = AppState(start: 'oToday', role: 'owner');
  s.data = server;
  s.update(() => s.account = (uid: 'fb-ravi', name: 'Ravi', email: 'r@gmail.com'));
  await s.refreshListings();
  await s.startLive();
  s.update(() {
    s.ownHid = 'real1';
    s.ownerHostels
      ..clear()
      ..add('real1');
  });
  await _pump(tester, s);
  await _settle(tester);
  return s;
}

void main() {
  mapTiles = false;

  testWidgets('tenants see when the owner last confirmed the free beds, from the server', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', bedsAt: '2026-09-28T09:00:00Z'), _hostel('real2')];
    final s = AppState(start: 'detail', role: 'tenant');
    s.data = server;
    s.hid = 'real1';
    await s.refreshListings();
    await _pump(tester, s);
    expect(s.confirmed['real1'], 3);
    expect(find.textContaining('2 free beds · confirmed by the owner 3 days ago', findRichText: true), findsOneWidget);
    // Never confirmed: just the count, never "today" and never "not confirmed".
    s.update(() => s.hid = 'real2');
    await tester.pump();
    expect(s.confirmed['real2'], isNull);
    expect(find.textContaining('confirmed by the owner', findRichText: true), findsNothing);
    expect(find.textContaining('Availability not confirmed', findRichText: true), findsNothing);
    // 9 days: stale after the DECISIONS threshold.
    server.hostels = [_hostel('real2', bedsAt: '2026-09-22T09:00:00Z')];
    await s.refreshListings();
    await tester.pump();
    expect(s.stale('real2'), isTrue);
    expect(find.textContaining('Availability not confirmed', findRichText: true), findsOneWidget);
    s.dispose();
  });

  testWidgets('the owner confirms free beds and layouts on the server from Today', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', bedsAt: '2026-09-27T09:00:00Z', layoutAt: '2026-06-01T09:00:00Z')];
    final s = await _owner(tester, server);
    expect((s.confirmed['real1'], s.layoutConfirmed['real1']), (4, 122));
    expect(find.text('Still 2 free beds?'), findsOneWidget);
    expect(find.text('Last confirmed 4 days ago. Fresh beds rank higher.'), findsOneWidget);
    await _tap(tester, find.text('Yes, all 2 free'));
    await _settle(tester);
    expect(server.calls, contains('beds real1'));
    expect(s.toast, 'Thanks. Tenants see your free beds as confirmed today.');
    expect(find.text('Still 2 free beds?'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Do your room layouts still match?'), findsOneWidget);
    await _tap(tester, find.text('All still correct'));
    await _settle(tester);
    expect(server.calls, contains('layouts real1'));
    expect(find.text('Do your room layouts still match?'), findsNothing);
    s.dispose();
  });

  testWidgets('a real hostel never confirmed asks on Today right away', (tester) async {
    final server = _Server()..hostels = [_hostel('real1')];
    final s = await _owner(tester, server);
    expect(s.needsConfirm('real1'), isTrue);
    expect(find.text('Still 2 free beds?'), findsOneWidget);
    expect(find.text('Not confirmed yet. Fresh beds rank higher.'), findsOneWidget);
    s.dispose();
  });

  test('the locked deal from the server becomes the perks and the fixed rent', () {
    final d = lockedDeal({'on': ['monthly', 'advance'], 'fee': 8000, 'advance': 3000, 'maintenance': 1000, 'notice': 30});
    expect(d!.fee, 7800);
    expect(d.perks, ['₹7,800 monthly', '₹2,000 advance', '30 days notice']);
    expect(lockedDeal({'on': [], 'fee': 9500})!.perks, isEmpty);
    expect(lockedDeal(null), isNull);
    final h = holdFromRow({'id': 'h1', 'hostel_id': 'anjani', 'opt': 'advance', 'status': 'booked', 'started_at': '2026-09-30T10:00:00Z', 'ref': 'HZ-5001', 'beds': {'letter': 'A', 'rooms': {'number': 102}}, 'deal': {'on': ['monthly'], 'fee': 8000, 'advance': 3000, 'maintenance': 1000, 'notice': 30}});
    expect(h.fixedFee, 7800);
    expect(h.perks, ['₹7,800 monthly', '30 days notice']);
    final r = residentFromRow({'id': 's1', 'name': 'Teja', 'rent': 7800, 'joined_on': '2026-09-30', 'confirmed': true, 'deal': {'on': ['advance'], 'fee': 8000}}, []);
    expect(r.perks, ['₹2,000 advance', '30 days notice']);
  });

  testWidgets('the tenant sees the price the server fixed; the owner sees the deal on the bed', (tester) async {
    final h = holdFromRow({'id': 'h1', 'hostel_id': 'anjani', 'opt': 'advance', 'status': 'booked', 'started_at': '2026-09-30T10:00:00Z', 'ref': 'HZ-5001', 'beds': {'letter': 'A', 'rooms': {'number': 102}}, 'deal': {'on': ['monthly'], 'fee': 6400, 'advance': 3000, 'maintenance': 1000, 'notice': 30}});
    final s = AppState(start: 'hold', role: 'tenant');
    s.update(() {
      s.holds = [h];
      s.holdId = 'h1';
    });
    await _pump(tester, s);
    expect(find.text('₹6,200 a month'), findsOneWidget);
    expect(find.text('₹6,200 monthly · 30 days notice'), findsOneWidget);

    // Owner: a resident who booked with a deal.
    s.jump('oToday', 'owner');
    final r = s.residents.firstWhere((x) => s.findBed('anjani', x.bed).b?.state == 'booked');
    r.perks = ['₹7,800 monthly', '30 days notice'];
    s.update(() {
      s.obed = r.bed;
      s.sheet = 'bed';
    });
    await tester.pump();
    expect(find.text('Price fixed · ₹7,800 monthly · 30 days notice'), findsOneWidget);
    s.dispose();
  });

  testWidgets('"Did you join?" saves Yes / Not yet / Still deciding for the team only', (tester) async {
    final server = _Server()..holds = [
      {'id': 'h9', 'hostel_id': 'anjani', 'opt': 'free', 'status': 'expired', 'started_at': '2026-09-29T10:00:00Z', 'ref': 'HZ-5009', 'beds': {'letter': 'B', 'rooms': {'number': 102}}},
    ];
    final s = AppState(start: 'holds', role: 'tenant');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha', email: 'a@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    expect(server.calls, contains('answers'));
    expect(find.byKey(const ValueKey('joinedAsk')), findsOneWidget);
    for (final t in ['Yes, I joined', 'Not yet', 'Still deciding']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('No'), findsNothing);
    expect(find.text('Only the Hostelzy team sees your answer, never the owner.'), findsOneWidget);

    // Offline: nothing claimed, the card stays.
    server.down = true;
    await _tap(tester, find.text('Still deciding'));
    await _settle(tester);
    expect(s.toast, 'Couldn’t save your answer. Check your internet and try again.');
    expect(find.byKey(const ValueKey('joinedAsk')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    server.down = false;
    await _tap(tester, find.text('Still deciding'));
    await _settle(tester);
    expect(server.calls, contains('join h9 deciding'));
    expect(s.toast, 'Thanks. Only the Hostelzy team sees your answer.');
    expect(find.byKey(const ValueKey('joinedAsk')), findsNothing);
    s.dispose();
  });

  testWidgets('an answered hold isn’t asked about again', (tester) async {
    final server = _Server()
      ..answered = {'h9'}
      ..holds = [
        {'id': 'h9', 'hostel_id': 'anjani', 'opt': 'free', 'status': 'expired', 'started_at': '2026-09-29T10:00:00Z', 'ref': 'HZ-5009', 'beds': {'letter': 'B', 'rooms': {'number': 102}}},
      ];
    final s = AppState(start: 'holds', role: 'tenant');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha', email: 'a@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    expect(find.byKey(const ValueKey('joinedAsk')), findsNothing);
    s.dispose();
  });
}
