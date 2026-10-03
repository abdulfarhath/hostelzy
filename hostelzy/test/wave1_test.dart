import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/reminders.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 1 (Main design v22): electricity by meter (oMeter, rentMeter),
// laundry day (oLaundry), the case photo (oCasePhoto), Trusted perks
// (trustedPerks), the manager join (mgrJoin). Refunds are in moves_test.

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

Future<void> _type(WidgetTester tester, String key, String text) async {
  final f = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

final _month = DateTime(appToday.year, appToday.month);
String _ymd(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-01';

/// One owner (Sai Sri, rooms 101 and 102) and one resident (Kiran, 101-A).
class _Server extends SampleRepo {
  _Server({this.owner = false});
  final bool owner;
  final calls = <String>[];
  final payments = <Map<String, dynamic>>[];
  bool meterReady = true;
  Level? level;
  List<Map<String, dynamic>> holdRows = [];
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: holdRows, enquiries: [], complaints: [], me: me, payments: payments, staff: [if (owner) {'hostel_id': 'saisri', 'user_id': me, 'role': 'owner'}], stays: [
    {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': owner ? 'fb-kiran' : me, 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
    {'id': 'stay-2', 'hostel_id': 'saisri', 'user_id': 'fb-ravi', 'name': 'Ravi Teja', 'phone': '9876500002', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'B', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<List<MeterRow>> meters(String hid, DateTime month) async {
    if (!meterReady) throw Exception('relation "public.meter_readings" does not exist');
    calls.add('meters $hid ${_ymd(month)}');
    return [
      meterFromRow({'rooms': {'number': 101}, 'month': _ymd(DateTime(month.year, month.month - 1)), 'reading': 1870, 'rate': 8, 'units': null, 'people': 2, 'each_amt': null}),
      if (!owner) meterFromRow({'rooms': {'number': 101}, 'month': _ymd(month), 'reading': 1940, 'rate': 8, 'units': 70, 'people': 2, 'each_amt': 280}),
    ];
  }

  @override
  Future<int> saveMeter(String hid, DateTime month, double rate, List<({int room, int reading})> rows) async {
    if (!meterReady) throw Exception('Could not find the function public.save_meter');
    calls.add('save $hid ${_ymd(month)} $rate ${[for (final r in rows) '${r.room}:${r.reading}'].join(',')}');
    return rows.length;
  }

  @override
  Future<void> startRent({required String hid, required String stayKey, required int amount, required String note}) async {
    calls.add('rent $amount');
    payments.add({'id': 'pay-rent-1', 'hostel_id': hid, 'kind': 'rent', 'amount': amount, 'note': note, 'status': 'pending', 'payer_name': 'Kiran Rao', 'created_at': DateTime.now().toUtc().toIso8601String()});
  }

  @override
  Future<Level?> myLevel() async => level;
  @override
  Future<String> uploadCasePhoto(String hid, String uid, Uint8List jpg) async {
    calls.add('upload $hid $uid ${jpg.length}');
    return '$hid/$uid/1.jpg';
  }

  @override
  Future<void> addCasePhoto(String caseKey, String path) async => calls.add('casePhoto $caseKey $path');
  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) async => calls.add('reply $key $reply');
}

Future<AppState> _signedIn(WidgetTester tester, _Server server, {required String start, required String role}) async {
  final s = AppState(start: start, role: role);
  s.data = server;
  s.update(() {
    s.account = (uid: server.owner ? 'fb-owner' : 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
    s.myName = 'Kiran Rao';
  });
  await s.startLive();
  await _pump(tester, s);
  for (var k = 0; k < 6; k++) {
    await tester.pump();
  }
  return s;
}

void main() {
  mapTiles = false;

  testWidgets('#25 owner: Rent › Electricity, one reading per room, split by the residents', (tester) async {
    final s = AppState(start: 'oRent', role: 'owner');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('meterOpen')));
    expect(s.screen, 'oMeter');
    final month = monthYear(appToday).split(' ').first;
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('Anjani Residency · Rent · $month'.toUpperCase()), findsOneWidget);
    expect(find.text('Type each room’s meter now. We split it between the residents in the room.'), findsOneWidget);
    expect(s.meterRate, '8');
    expect(find.text('1,870'), findsOneWidget); // room 204 last month
    final all = s.rooms['anjani']!.length;
    expect(find.text('Add to $month rent · 0 of $all rooms'), findsOneWidget);
    // Type room 204: 70 units, split between the residents in it.
    await _type(tester, 'meter-204', '1940');
    final n = s.peopleIn(204);
    expect(n, greaterThan(0));
    expect(find.descendant(of: find.byKey(const ValueKey('meterRow-204')), matching: find.text('70 units')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('meterRow-204')), matching: find.text('${fmt((70 * 8 / n).ceil())} each')), findsOneWidget);
    expect(find.text('Add to $month rent · 1 of $all rooms'), findsOneWidget);
    // A reading below last month's is caught.
    await _type(tester, 'meter-204', '1800');
    expect(find.descendant(of: find.byKey(const ValueKey('meterRow-204')), matching: find.text('Check it')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('meterGo')));
    expect(s.toast, 'Room 204: the reading is lower than last month’s (1,870).');
    await tester.pump(const Duration(seconds: 3));
    await _type(tester, 'meter-204', '1940');
    await _tap(tester, find.byKey(const ValueKey('meterGo')));
    expect(s.screen, 'oRent');
    expect(s.toast, 'Added to $month rent for 1 room. Residents see their share on their rent.');
    expect(s.meterOf(204)!.units, 70);
    s.dispose();
  });

  testWidgets('#25 on the server: the owner saves readings; before the SQL runs it says so', (tester) async {
    final server = _Server(owner: true);
    final s = await _signedIn(tester, server, start: 'oRent', role: 'owner');
    s.switchHostel('saisri');
    s.tab('oRent');
    await tester.pump();
    s.openMeter();
    for (var k = 0; k < 4; k++) {
      await tester.pump();
    }
    expect(server.calls, contains('meters saisri ${_ymd(_month)}'));
    expect(s.meterRate, '8');
    expect(s.peopleIn(101), 2); // Kiran and Ravi share room 101's meter
    await _type(tester, 'meter-101', '1940');
    await _tap(tester, find.byKey(const ValueKey('meterGo')));
    for (var k = 0; k < 4; k++) {
      await tester.pump();
    }
    expect(server.calls.where((c) => c.startsWith('save')).single, 'save saisri ${_ymd(_month)} 8.0 101:1940');
    await tester.pump(const Duration(seconds: 3));
    // Before the server has meter readings: a plain note, nothing invented.
    server.meterReady = false;
    s.openMeter();
    for (var k = 0; k < 4; k++) {
      await tester.pump();
    }
    expect(s.meterOff, isTrue);
    expect(find.textContaining('starts after Hostelzy’s next server update'), findsOneWidget);
    s.dispose();
  });

  testWidgets('#25 resident: the meter line on the rent (board rentMeter), paid with the rent', (tester) async {
    // Demo build: the sample line.
    final d = AppState(start: 'rPay', role: 'resident');
    await _pump(tester, d);
    expect(find.text('Electricity · 210 units ÷ 4 · ₹8/unit'), findsOneWidget);
    expect(find.text('₹420'), findsOneWidget);
    expect(find.text('₹7,600'), findsOneWidget);
    d.dispose();

    final server = _Server();
    final s = await _signedIn(tester, server, start: 'rPay', role: 'resident');
    expect(s.myMeter?.each, 280);
    await tester.pump();
    expect(find.byKey(const ValueKey('rentMeter')), findsOneWidget);
    expect(find.text('Electricity · 70 units ÷ 2 · ₹8/unit'), findsOneWidget);
    expect(find.text('₹280'), findsOneWidget);
    expect(find.text('₹9,280'), findsWidgets);
    await s.payMyRent();
    expect(server.calls.where((c) => c.startsWith('rent')).single, 'rent 9280');
    s.dispose();

    // Not added yet (or before the SQL runs): it says so, no number.
    final none = _Server()..meterReady = false;
    final r = await _signedIn(tester, none, start: 'rPay', role: 'resident');
    expect(find.text('Not added yet'), findsOneWidget);
    expect(find.text('₹9,000'), findsWidgets);
    r.dispose();
  });

  testWidgets('#26 laundry day: the owner sets it; residents turn on the reminder', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'rules');
    final rem = NoReminders(available: true);
    await s.startReminders(rem);
    await _pump(tester, s);
    expect(find.text('Not set · residents can get a reminder'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('laundryOpen')));
    expect(s.sheet, 'laundry');
    expect(find.text('Machine free'), findsOneWidget);
    expect(find.text('Residents who turn on the Laundry reminder get it at 8 pm the evening before.'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('laundryDay-6')));
    await _tap(tester, find.text('Evening'));
    await _tap(tester, find.byKey(const ValueKey('laundrySave')));
    expect(s.sheet, isNull);
    expect(s.rules.where((r) => r.k == 'Laundry day').single.v, 'Saturday · Evening');
    expect(s.toast, 'Laundry day saved: Saturday, Evening. Residents with the reminder on get it at 8 pm on Friday.');
    expect(find.text('Saturday · Evening'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // The resident sees it in Reminders and turns it on: Friday 8 pm, every week.
    s.jump('reminders', 'resident');
    await tester.pump();
    expect(find.text('Saturday, Evening · reminder 8 pm Friday'), findsOneWidget);
    expect(rem.applied.where((r) => r.kind == 'laundry'), isEmpty);
    await _tap(tester, find.byKey(const ValueKey('remLaundry')));
    await tester.pump();
    final ring = rem.applied.where((r) => r.kind == 'laundry').single;
    expect((ring.weekday, ring.minute, ring.title), (5, 20 * 60, 'Laundry day tomorrow'));
    expect(ring.body, 'Anjani Residency: the machine is free in the evening.');
    expect(s.remJson()['laundry'], isTrue);
    s.dispose();
  });

  testWidgets('#18 case photo: the tenant’s photo shows; the owner adds one to the reply', (tester) async {
    final s = AppState(start: 'oCase', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Photo from Teja'.toUpperCase()), findsOneWidget);
    expect(find.text('Shown only to you and the Hostelzy team.'), findsOneWidget);
    expect(find.text('Add a photo to your reply'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('casePhoto')));
    expect(s.toast, 'Photos open from the server in the real app. This is sample data.');
    s.dispose();

    // On the server: the photo goes up, onto the case, then the reply.
    final server = _Server(owner: true);
    final o = await _signedIn(tester, server, start: 'oToday', role: 'owner');
    final c = FairCase(id: 'FP-0150', hid: 'saisri', title: 'Ravi was added as Walked in', signal: 'x', status: 'waiting', resident: 'Ravi Teja', key: 'case-1', openedAt: DateTime.now().millisecondsSinceEpoch);
    o.update(() {
      o.fpReply = 'He walked in himself.';
      o.fpPhoto = Uint8List.fromList(List.filled(10, 1));
    });
    o.replyCase(c);
    for (var k = 0; k < 6; k++) {
      await tester.pump();
    }
    expect(server.calls.where((x) => x.startsWith('upload') || x.startsWith('casePhoto') || x.startsWith('reply')).toList(), ['upload saisri fb-owner 10', 'casePhoto case-1 saisri/fb-owner/1.jpg', 'reply case-1 He walked in himself.']);
    expect(o.fpPhoto, isNull);
    expect(o.toast, 'Reply and photo saved. The Hostelzy team reads them before deciding.');
    o.dispose();
  });

  testWidgets('#16 Trusted perks: the level comes from the server; only perks that work', (tester) async {
    final s = AppState(start: 'rewards', role: 'tenant');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('perksOpen')));
    expect(s.sheet, 'perks');
    expect(find.text('What Trusted tenants get'), findsOneWidget);
    for (final t in ['First look at new free beds', '2-hour holds', 'Owners see “Trusted tenant”']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('advance'), findsNothing);
    s.dispose();

    // Server: Trusted from my_level(); local counters don't count.
    final server = _Server()..level = (level: 'trusted', months: 7, late: 0);
    final t = await _signedIn(tester, server, start: 'rewards', role: 'tenant');
    expect((t.level, t.monthsOnTime), ('trusted', 7));
    t.openPerks();
    await tester.pump();
    expect(find.text('You’re a Trusted tenant'), findsOneWidget);
    t.dispose();
    final plain = _Server()..level = (level: 'member', months: 2, late: 0);
    final m = await _signedIn(tester, plain, start: 'rewards', role: 'tenant');
    m.update(() => m.monthsOnTime = 12);
    expect(m.level, 'member');
    // A bed that just turned free: the first hour is for Trusted tenants.
    final b = Bed(id: '101-C', letter: 'C', room: 101, floor: 1, spot: '', state: 'free', soon: '')..freedAt = DateTime.now().subtract(const Duration(minutes: 10));
    expect(m.firstLookBlock(b), startsWith('Trusted tenants get the first hour on this bed. It opens to you at '));
    b.freedAt = DateTime.now().subtract(const Duration(minutes: 61));
    expect(m.firstLookBlock(b), isNull);
    m.dispose();
  });

  testWidgets('#16 owners see "Trusted tenant" and the real hold length from the server', (tester) async {
    final server = _Server(owner: true);
    final now = DateTime.now().toUtc();
    server.holdRows = [
      {'id': 'h-1', 'hostel_id': 'saisri', 'status': 'waiting', 'opt': 'free', 'ref': 'HZ-5001', 'trusted': true, 'started_at': now.toIso8601String(), 'expires_at': now.add(const Duration(hours: 2)).toIso8601String(), 'beds': {'letter': 'B', 'rooms': {'number': 102, 'label': null}}},
    ];
    final s = await _signedIn(tester, server, start: 'oToday', role: 'owner');
    final h = s.holds.single;
    expect((h.trusted, s.holdSecsOf(h)), (true, 7200));
    s.dispose();
  });

  testWidgets('mgrJoin: a manager joins with the MGR- code from "I run a PG"', (tester) async {
    final s = AppState(start: 'role', role: 'tenant');
    await _pump(tester, s);
    s.update(() {
      s.roleGate = 'owner';
      s.screen = 'roleGate';
    });
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('mgrJoinOpen')));
    expect(find.text('Join your PG'), findsOneWidget);
    expect(find.text('I live in a PG'.toUpperCase()), findsOneWidget);
    expect(find.text('MGR-'), findsOneWidget);
    expect(find.byKey(const ValueKey('mgrHint')), findsOneWidget);
    expect(find.text('Manager codes start with MGR. The owner sends it on WhatsApp; it works once, for 7 days.'), findsOneWidget);
    expect(find.text('Scan the QR'), findsNothing);
    s.dispose();
  });

  for (final c in const ['oMeter', 'laundry', 'perks', 'oCase']) {
    testWidgets('wave 1: $c fits at 2× text', (tester) async {
      final s = switch (c) {
        'oMeter' => AppState(start: 'oMeter', role: 'owner'),
        'laundry' => AppState(start: 'oMore', role: 'owner', moreTab: 'rules', sheet: 'laundry'),
        'perks' => AppState(start: 'rewards', role: 'tenant', sheet: 'perks'),
        _ => AppState(start: 'oCase', role: 'owner', theme: 'dark'),
      };
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
