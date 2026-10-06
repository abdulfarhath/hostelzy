import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show filtered;
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 3a: owner-only areas (17), AC unit on rate changes (19), the
// featured spot in the ranking (20), deals paused while the plan is late (21).

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
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pump();
}

/// A signed-in user on the server: a manager at Anjani, with the server's flags.
class _Server extends SampleRepo {
  _Server({this.manager = true});
  final bool manager;
  Map<String, HostelFlags> serverFlags = {};
  Object? ratesError;
  // ignore: close_sinks
  final ctrl = StreamController<String>.broadcast();
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: [], staff: [
    {'hostel_id': 'anjani', 'user_id': me, 'role': manager ? 'manager' : 'owner'},
  ]);
  @override
  Future<Set<String>> managedHostels(String uid) async => manager ? {'anjani'} : {};
  @override
  Future<Map<String, HostelFlags>> flags() async => serverFlags;
  @override
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms) async {
    if (ratesError != null) throw ratesError!;
  }
}

void main() {
  mapTiles = false;

  testWidgets('a manager has no plan, deals, rates or Fair Play; a link there says only the owner can (F24 item 17)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    final srv = _Server();
    s.data = srv;
    s.update(() => s.account = (uid: 'fb-mgr', name: 'Ravi', email: 'r@gmail.com'));
    await s.startLive();
    expect(s.managerOf, {'anjani'});
    expect(s.managerHere, isTrue);
    await _pump(tester, s);
    // Manage: no Deals, Rates and UPI or Your plan rows; the rest stays.
    expect(find.byKey(const ValueKey('manage-Residents')), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-Complaints')), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-Deals')), findsNothing);
    expect(find.byKey(const ValueKey('manage-Rates and UPI')), findsNothing);
    expect(find.byKey(const ValueKey('manage-Your plan')), findsNothing);

    // A link or push to the plan, deals, rates or a Fair Play check.
    s.go('oPlan');
    await tester.pump();
    expect(find.text('Only the owner can see the Hostelzy plan and its invoices.'), findsOneWidget);
    s.openDeals();
    await tester.pump();
    expect(find.text('Only the owner can change Hostelzy deals.'), findsOneWidget);
    s.openRates();
    await tester.pump();
    expect(find.text('Only the owner can change rates, AC rooms and the UPI ID.'), findsOneWidget);
    s.go('oCase');
    await tester.pump();
    expect(find.text('Only the owner can see and answer Fair Play checks.'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('ownerOnlyBack')));
    expect((s.screen, s.moreTab), ('oMore', 'home'));
    expect(find.byKey(const ValueKey('manage-Residents')), findsOneWidget);

    // Owner Today: no plan banner for a manager, even when the plan is late.
    s.update(() => s.invoice = Invoice(ref: 'HZ-INV-2001', hid: s.ownHid, beds: 30, amt: 499, due: appToday.subtract(const Duration(days: 16)), status: 'due', late: 16));
    s.tab('oToday');
    await tester.pump();
    expect(find.textContaining('days late'), findsNothing);
    s.stopLive();
    s.dispose();
  });

  testWidgets('the owner keeps every row, and the rate card says the AC unit rule in plain words (items 17, 19)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    final srv = _Server(manager: false);
    s.data = srv;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    expect(s.managerHere, isFalse);
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('manage-Deals')), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-Rates and UPI')), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-Your plan')), findsOneWidget);

    // Room 204's published layout has no AC unit: it can't be made AC.
    await _tap(tester, find.byKey(const ValueKey('manage-Rates and UPI')));
    expect(s.moreTab, 'rates');
    expect(find.textContaining('An AC room needs an AC unit in its layout.'), findsOneWidget);
    final r204 = s.rooms['anjani']!.firstWhere((r) => r.n == 204);
    s.rateDraft![rateKey(true, r204.share)] = 9000;
    s.setRoomAc(r204, true);
    expect(s.acDraft![204], isFalse);
    expect(s.toast, 'Room 204’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC.');

    // The server says no too (another phone, an old app): its words come through.
    srv.ratesError = Exception('PostgrestException(message: room 302: an AC room needs an AC unit. Add it in the room\'s layout and publish, then make it AC)');
    s.saveRates();
    await tester.pump();
    await tester.pump();
    expect(s.toast, 'Room 302’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC.');
    srv.ratesError = Exception('only the owner changes rates and AC rooms');
    s.saveRates();
    await tester.pump();
    await tester.pump();
    expect(s.toast, 'Only the owner can change rates and AC rooms.');
    await tester.pump(const Duration(seconds: 4));
    s.stopLive();
    s.dispose();
  });

  testWidgets('80+ bed hostels: one featured spot pinned on top of every sort, marked Featured; deals paused show walk-in prices (items 20, 21)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    final before = filtered(s).map((h) => h.id).toList();
    final last = before.last;
    final rank = s.rankOf(last);
    expect(s.featured(last), isFalse);
    expect(s.bestQuote('anjani'), isNotNull);

    final srv = _Server(manager: false)
      ..serverFlags = {
        last: (beds: 96, featured: true, dealsPaused: false),
        'anjani': (beds: 40, featured: false, dealsPaused: true),
      };
    s.data = srv;
    await s.refreshListings();
    await _pump(tester, s);
    // The featured hostel is first, labelled, and its rank number is unchanged.
    expect(filtered(s).first.id, last);
    expect(s.rankOf(last), rank);
    expect(find.byKey(ValueKey('featured-$last')), findsOneWidget);
    expect(find.textContaining('Featured'), findsWidgets);
    // F26 #2: it keeps its one pinned spot in every sort; the rest follow the sort.
    s.update(() => s.sortBy = 'near');
    final near = filtered(s).map((h) => h.id).toList();
    s.flags = {};
    final plain = filtered(s).map((h) => h.id).toList();
    expect(near, [last, ...plain.where((id) => id != last)]);
    s.flags = srv.serverFlags;
    s.update(() => s.sortBy = 'price');

    // Anjani's plan is 15+ days late on the server: tenants see walk-in prices only.
    expect(s.dealsPaused('anjani'), isTrue);
    expect(s.dealsOf('anjani').on, isEmpty);
    expect(s.bestQuote('anjani'), isNull);

    // How the ranking works says so plainly.
    s.update(() => s.sheet = 'rank');
    await tester.pump();
    expect(find.byKey(const ValueKey('rankFeatured')), findsOneWidget);
    s.dispose();
  });

  testWidgets('before the SQL runs: no flags, nothing featured, deals as before', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    final before = filtered(s).map((h) => h.id).toList();
    s.data = _Server(manager: false);
    await s.refreshListings();
    expect(s.flags, isEmpty);
    expect(filtered(s).map((h) => h.id).toList(), before);
    expect(s.dealsPaused('anjani'), isFalse);
    s.dispose();
  });
}
