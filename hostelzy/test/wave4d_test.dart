import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show FiltersBtn, filtered;
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 4d (audit §3, F03): the "Best deals" sort in Explore, and rates
// "Confirmed by the owner · date" with the monthly "Are your rates still right?".

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

/// A live hostel as the server sends it; [cards] are its rate cards.
Map<String, dynamic> _hostel(String id, List<Map<String, dynamic>> cards) => {
  'id': id,
  'name': 'Real PG',
  'gender': 'Men',
  'area': 'Madhapur',
  'status': 'live',
  'owner_name': 'Ravi',
  'terms': {'advance': 3000, 'maintenance': 1000},
  'rate_cards': cards,
  'deals': null,
  'reviews': [],
  'rooms': [
    {
      'number': 101, 'floor': 1, 'share': 2, 'rent': 8000,
      'beds': [
        {'id': '$id-a', 'letter': 'A', 'state': 'free'},
        {'id': '$id-b', 'letter': 'B', 'state': 'booked'},
      ],
    },
  ],
  'layouts': [],
};

Map<String, dynamic> _card(int rent, {Object? at = 'none'}) => {
  'ac': false,
  'share': 2,
  'rent': rent,
  if (at != 'none') 'confirmed_at': at,
};

class _Server extends SampleRepo {
  final calls = <String>[];
  List<Map<String, dynamic>> hostels = [];
  bool down = false;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => listingsFromRows(hostels);
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: []);
  @override
  Future<void> confirmRates(String hid) async {
    if (down) throw Exception('offline');
    calls.add('rates $hid');
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

  testWidgets('Best deals sorts by the 6-month saving; paused deals count as none; featured only leads Recommended', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await _pump(tester, s);
    // The Filters sheet offers it (the owner's Deals screen promises it).
    await _tap(tester, find.byType(FiltersBtn));
    await _settle(tester);
    await _tap(tester, find.text('Best deals'));
    expect(s.sortBy, 'deals');
    expect(tester.takeException(), isNull);

    int save(String id) => s.bestQuote(id)?.save6 ?? 0;
    var ids = [for (final h in filtered(s)) h.id];
    expect(ids.first, 'anjani');
    for (var i = 1; i < ids.length; i++) {
      expect(save(ids[i - 1]) >= save(ids[i]), isTrue, reason: '${ids[i - 1]} before ${ids[i]}');
    }
    // The same number as the ribbon and the hostel page headline.
    expect(save('anjani'), greaterThan(0));
    final noDeal = ids.where((id) => s.bestQuote(id) == null).toList();
    expect(noDeal, isNotEmpty);
    expect(ids.sublist(ids.length - noDeal.length), noDeal);

    // Deals paused (plan 15+ days late): no deal, so it drops to the bottom.
    s.update(() => s.flags = {'anjani': (beds: 120, featured: true, dealsPaused: true)});
    ids = [for (final h in filtered(s)) h.id];
    expect(s.bestQuote('anjani'), isNull);
    expect(ids.indexOf('anjani'), greaterThanOrEqualTo(ids.length - noDeal.length - 1));

    // Featured leads Recommended only, never Best deals.
    s.update(() => s.flags = {'lakshmi': (beds: 120, featured: true, dealsPaused: false)});
    expect(s.bestQuote('lakshmi'), isNull);
    s.update(() => s.sortBy = 'rec');
    expect(filtered(s).first.id, 'lakshmi');
    s.update(() => s.sortBy = 'deals');
    expect(filtered(s).first.id, 'anjani');
    expect(filtered(s).last.id == 'lakshmi' || s.bestQuote(filtered(s).last.id) == null, isTrue);
    expect(filtered(s).indexWhere((h) => h.id == 'lakshmi'), greaterThan(0));
    s.dispose();
  });

  testWidgets('tenants see when the owner last confirmed the rates (demo dates)', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    final at = dayMon(appToday.subtract(const Duration(days: 12)));
    final line = find.byKey(const ValueKey('ratesConfirmed'));
    await tester.ensureVisible(line);
    expect(find.textContaining('Confirmed by the owner · $at', findRichText: true), findsOneWidget);
    // Greenview: 40 days, so no date, just "not confirmed".
    s.update(() => s.hid = 'greenview');
    await tester.pump();
    expect(find.textContaining('Not confirmed in over a month', findRichText: true), findsOneWidget);
    expect(find.textContaining('Confirmed by the owner', findRichText: true), findsNothing);
    s.dispose();
  });

  testWidgets('rates from the server: date, never confirmed, and before the SQL runs', (tester) async {
    final server = _Server()
      ..hostels = [
        _hostel('real1', [_card(8000, at: '2026-09-20T09:00:00Z')]),
        _hostel('real2', [_card(8000, at: null)]),
        _hostel('real3', [_card(8000)]),
        _hostel('real4', [_card(8000, at: '2026-08-01T09:00:00Z')]),
      ];
    final s = AppState(start: 'detail', role: 'tenant');
    s.data = server;
    s.hid = 'real1';
    await s.refreshListings();
    await _pump(tester, s);
    expect(s.ratesConfirmedAt['real1'], isNotNull);
    expect(find.textContaining('Confirmed by the owner · 20 Sep', findRichText: true), findsOneWidget);
    // Never confirmed, or the server doesn't keep it yet: no date and no warning.
    for (final id in ['real2', 'real3']) {
      s.update(() => s.hid = id);
      await tester.pump();
      expect(find.byKey(const ValueKey('ratesConfirmed')), findsNothing);
    }
    expect(s.ratesNeverConfirmed, {'real2'});
    // Two months ago: over a month.
    s.update(() => s.hid = 'real4');
    await tester.pump();
    expect(find.textContaining('Not confirmed in over a month', findRichText: true), findsOneWidget);
    s.dispose();
  });

  testWidgets('owner Today asks monthly; "Rates still right" is saved on the server', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', [_card(8000, at: '2026-08-25T09:00:00Z')])];
    final s = await _owner(tester, server);
    expect(s.ratesDays('real1'), 37);
    // F26 #18: the rates check is an item in Today's Payments tab.
    await _tap(tester, find.byKey(const ValueKey('needTab-payments')));
    final card = find.byKey(const ValueKey('rates-real1'));
    await tester.ensureVisible(card);
    expect(find.text('Are your rates still right?'), findsOneWidget);
    expect(find.textContaining('Last confirmed 25 Aug.'), findsOneWidget);
    expect(find.text('2 sharing non-AC · ₹8,000'), findsOneWidget);

    // Offline: nothing changes.
    server.down = true;
    await _tap(tester, find.text('Rates still right'));
    await _settle(tester);
    expect(find.text('Are your rates still right?'), findsOneWidget);

    server.down = false;
    await _tap(tester, find.text('Rates still right'));
    await _settle(tester);
    expect(server.calls, ['rates real1']);
    expect(s.ratesDays('real1'), 0);
    expect(find.text('Are your rates still right?'), findsNothing);
    s.dispose();
  });

  testWidgets('never confirmed: the owner is asked at once; a manager never is', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', [_card(8000, at: null)])];
    final s = await _owner(tester, server);
    await _tap(tester, find.byKey(const ValueKey('needTab-payments')));
    await tester.ensureVisible(find.byKey(const ValueKey('rates-real1')));
    expect(find.textContaining('Not confirmed yet. Not confirmed for a month'), findsOneWidget);
    s.update(() => s.managerOf.add('real1'));
    await tester.pump();
    expect(find.byKey(const ValueKey('rates-real1')), findsNothing);
    s.dispose();
  });

  testWidgets('before the SQL runs: no card and no date', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', [_card(8000)])];
    final s = await _owner(tester, server);
    expect(s.needsRatesConfirm('real1'), isFalse);
    expect(find.byKey(const ValueKey('rates-real1')), findsNothing);
    s.dispose();
  });
}
