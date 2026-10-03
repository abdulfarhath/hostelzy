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

// F24 Wave 3b (item 18): Fair Play hardening. The rules "I agree" kept on the
// server; "Joined before Hostelzy" only before go-live; strike 2 hides deals
// for 30 days, then they come back; 3 fixes in 6 months = 1 warning; strike
// labels say what each strike means.

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

Map<String, dynamic> _hostel(String id, {String status = 'live'}) => {
  'id': id,
  'name': 'Real PG',
  'gender': 'Men',
  'area': 'Madhapur',
  'status': status,
  'owner_name': 'Ravi',
  'terms': {'advance': 3000, 'maintenance': 1000},
  'rate_cards': [],
  'deals': {'deals_on': ['monthly'], 'target': 'all'},
  'reviews': [],
  'rooms': [
    {
      'number': 101, 'floor': 1, 'share': 2, 'rent': 8000,
      'beds': [
        {'id': '$id-a', 'letter': 'A', 'state': 'free'},
        {'id': '$id-b', 'letter': 'B', 'state': 'free'},
      ],
    },
  ],
  'layouts': [],
};

class _Server extends SampleRepo {
  final calls = <String>[];
  List<Map<String, dynamic>> hostels = [];
  Map<String, int> strikes = {};
  Map<String, Standing> standing = {};
  List<Map<String, dynamic>> cases = [];
  bool? accepted;
  String? stayError;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => listingsFromRows(hostels, strikes: strikes, standing: standing);
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], cases: cases);
  @override
  Future<void> acceptFairPlay() async => calls.add('accept');
  @override
  Future<bool?> fairAccepted() async => accepted;
  @override
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn, bool before = false}) async {
    if (stayError != null) throw Exception(stayError);
    calls.add('stay $hid $name${before ? ' before' : ''}');
    return (via: before ? 'before' : 'direct', lateDays: 0);
  }

  @override
  Future<void> fixCase(String key) async {
    calls.add('fix $key');
    // The third fix in 6 months: the server adds a warning.
    strikes = {'real1': 1};
    standing = {'real1': (until: null, dealsHidden: false, removed: false, why: 'fixes')};
  }
}

final _states = <AppState>[];

/// Lets the toasts end and stops every state's timers.
Future<void> _done(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpWidget(const SizedBox());
  for (final s in _states) {
    s.dispose();
  }
  _states.clear();
}

Future<AppState> _owner(WidgetTester tester, _Server server, {bool accepted = true, String start = 'oToday'}) async {
  final s = AppState(start: start, role: 'owner');
  _states.add(s);
  s.data = server;
  s.fairAccepted = accepted;
  s.update(() => s.account = (uid: 'fb-ravi', name: 'Ravi', email: 'r@gmail.com'));
  s.update(() {
    s.ownHid = 'real1';
    s.ownerHostels
      ..clear()
      ..add('real1');
  });
  await s.refreshListings();
  await s.startLive();
  await _pump(tester, s);
  await _settle(tester);
  return s;
}

void main() {
  mapTiles = false;

  testWidgets('the Fair Play "I agree" is kept on the server and not asked again', (tester) async {
    // Agreed on another phone: this one skips the rules.
    final server = _Server()
      ..hostels = [_hostel('real1')]
      ..accepted = true;
    final s = await _owner(tester, server, accepted: false, start: 'oRules');
    expect(s.fairAccepted, isTrue);
    expect(s.screen, 'oToday');

    // A new owner agrees here: it goes to the server.
    final fresh = _Server()
      ..hostels = [_hostel('real1')]
      ..accepted = false;
    final f = await _owner(tester, fresh, accepted: false, start: 'oRules');
    expect(f.screen, 'oRules');
    await _tap(tester, find.byKey(const ValueKey('fpAgree')));
    await _tap(tester, find.text('Agree and continue'));
    await _settle(tester);
    expect(fresh.calls, contains('accept'));
    expect(f.fairAccepted, isTrue);

    // Agreed on this phone before the server had it: sent on the next start.
    final late = _Server()
      ..hostels = [_hostel('real1')]
      ..accepted = false;
    await _owner(tester, late);
    expect(late.calls, contains('accept'));
    await _done(tester);
  });

  testWidgets('"Lived here before Hostelzy" only before go-live, and the server decides', (tester) async {
    final server = _Server()..hostels = [_hostel('real1', status: 'draft')];
    final s = await _owner(tester, server);
    expect(s.canMarkBefore, isTrue);
    s.openAddResident();
    await _settle(tester);
    expect(find.text('Lived here before Hostelzy'), findsOneWidget);
    s.update(() {
      s.rName = 'Old Timer';
      s.rPhone = '9000000001';
    });
    s.pickResidentBed('101-A');
    await _settle(tester);
    expect(find.textContaining('Direct.', findRichText: true), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('rBefore')));
    expect(s.rBefore, isTrue);
    expect(find.textContaining('Joined before Hostelzy.', findRichText: true), findsOneWidget);
    s.addResident();
    await _settle(tester);
    expect(server.calls, contains('stay real1 Old Timer before'));
    expect(s.toast, 'Added as joined before Hostelzy. Old confirms by joining with your invite code.');

    // The hostel went live meanwhile: the server says no, in plain words.
    server.stayError = 'after go-live, only the Hostelzy team marks a resident as joined before Hostelzy';
    s.openAddResident();
    s.update(() {
      s.rName = 'Second';
      s.rPhone = '9000000002';
      s.rBefore = true;
    });
    s.pickResidentBed('101-B');
    s.addResident();
    await _settle(tester);
    expect(s.toast, 'Your hostel is live now, so only the Hostelzy team can mark someone as joined before Hostelzy. Message the team.');

    // A live hostel: no choice on the sheet; residents are Direct or from the app.
    final live = _Server()..hostels = [_hostel('real1')];
    final l = await _owner(tester, live);
    expect(l.canMarkBefore, isFalse);
    l.openAddResident();
    await _settle(tester);
    expect(find.text('Lived here before Hostelzy'), findsNothing);
    l.update(() {
      l.rName = 'New One';
      l.rPhone = '9000000003';
      l.rBefore = true; // left over: ignored once live
    });
    l.pickResidentBed('101-A');
    l.addResident();
    await _settle(tester);
    expect(live.calls, contains('stay real1 New One'));
    await _done(tester);
  });

  testWidgets('strike 2 hides deals for 30 days from the server, then they come back', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 12));
    final server = _Server()
      ..hostels = [_hostel('real1')]
      ..strikes = {'real1': 2}
      ..standing = {'real1': (until: soon, dealsHidden: true, removed: false, why: 'case')};
    final s = await _owner(tester, server);
    expect(s.dealsHidden('real1'), isTrue);
    expect(s.dealsOf('real1').on, isEmpty);
    expect(s.strikeLine('real1'), 'Deals hidden until ${dayMon(soon)}');
    expect(find.text('Fair Play: strike 2 of 3'), findsOneWidget);
    expect(find.text('Deals hidden until ${dayMon(soon)}'), findsOneWidget);
    s.go('oStrike');
    await _settle(tester);
    expect(find.text('Strike 2 of 3: deals hidden for 30 days'), findsOneWidget);
    expect(find.text('Deals hidden until ${dayMon(soon)}'), findsOneWidget);

    // 30 days on: deals are back; the strike still counts.
    final ended = DateTime.now().subtract(const Duration(days: 1));
    server.standing = {'real1': (until: ended, dealsHidden: false, removed: false, why: 'case')};
    await s.refreshListings();
    await _settle(tester);
    expect(s.strikes['real1'], 2);
    expect(s.dealsHidden('real1'), isFalse);
    expect(s.dealsOf('real1').on, {'monthly'});
    expect(s.strikeLine('real1'), 'Deals back since ${dayMon(ended)}');
    expect(find.text('Deals back since ${dayMon(ended)}'), findsOneWidget);

    // Before the server sends dates (or on sample data) strike 2 keeps them hidden.
    server.standing = {};
    await s.refreshListings();
    expect(s.dealsHidden('real1'), isTrue);
    // Strike 3: removed.
    server.strikes = {'real1': 3};
    await s.refreshListings();
    expect(s.removed('real1'), isTrue);
    expect(s.strikeLine('real1'), 'Removed from Hostelzy');
    await _done(tester);
  });

  test('fair_standing rows and strike words', () {
    final st = standingFromRows([
      {'hostel_id': 'h1', 'n': 2, 'deals_hidden': true, 'hidden_until': '2026-11-02T10:00:00Z', 'removed': false, 'last_reason': 'case'},
      {'hostel_id': 'h2', 'n': 3, 'deals_hidden': true, 'hidden_until': null, 'removed': true, 'last_reason': 'fixes'},
    ]);
    expect(st['h1']!.until!.toUtc(), DateTime.utc(2026, 11, 2, 10));
    expect((st['h2']!.removed, st['h2']!.why), (true, 'fixes'));
    expect([for (var n = 1; n <= 3; n++) strikeDecision(n)], ['Strike 1 · warning', 'Strike 2 · deals hidden for 30 days', 'Strike 3 · removed from Hostelzy']);
  });

  testWidgets('the team\'s strike says what it means (sample data)', (tester) async {
    final s = AppState(start: 'aCases', role: 'tenant');
    _states.add(s);
    await _pump(tester, s);
    final c = s.cases.firstWhere((c) => c.hid == 'anjani');
    s.update(() => s.strikes['anjani'] = 1);
    s.decideCase(c, 'strike');
    expect(c.result, 'Strike 2 · deals hidden for 30 days');
    expect(s.dealsOf('anjani').on, isEmpty);
    await _done(tester);
  });

  testWidgets('the third fix in 6 months is a warning, counted on the server', (tester) async {
    final server = _Server()
      ..hostels = [_hostel('real1')]
      ..cases = [
        {'id': 'case-1', 'ref': 'FP-0150', 'hostel_id': 'real1', 'title': 'Teja added as Direct', 'signal': 'Held, then added as Direct', 'status': 'new', 'resident': 'Teja', 'events': [], 'created_at': DateTime.now().toUtc().toIso8601String()},
      ];
    final s = await _owner(tester, server);
    final c = s.cases.firstWhere((c) => c.key == 'case-1');
    s.fixCase(c);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(server.calls, contains('fix case-1'));
    expect(s.toast, 'Teja now shows as came from the app. Case closed. That’s 3 fixes in 6 months, which counts as one warning (strike 1 of 3).');
    expect(s.strikeFromFixes('real1'), isTrue);
    s.go('oStrike');
    await _settle(tester);
    expect(find.textContaining('Three fixes count as one warning'), findsOneWidget);
    await _done(tester);
  });
}
