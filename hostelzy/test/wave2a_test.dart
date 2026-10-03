import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/sign_in.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 2a: Working / Not working (7), walk-in holds (8), notification
// switches and New free beds (22), the team tracker and members (29) on the
// server, and what the app does before that SQL runs.

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
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

Future<void> _settle([int n = 6]) async {
  for (var k = 0; k < n; k++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _hid = 'a3000000-0000-0000-0000-000000000001';

/// One live hostel: room 204 (AC, under repair since 2 Oct) with a fan and
/// the AC in its layout; bed A free, bed B held for a walk-in for 40 more minutes.
Map<String, dynamic> _hostelRow({bool acBroken = true, String? walkIn}) => {
  'id': _hid,
  'name': 'Wave Two PG',
  'gender': 'Men',
  'area': 'Ameerpet',
  'owner_name': 'Ravi',
  'status': 'live',
  'rate_cards': [{'ac': true, 'share': 3, 'rent': 9000}],
  'rooms': [
    {
      'number': 204, 'label': null, 'floor': 2, 'share': 3, 'rent': 9000, 'ac': true, 'ac_repair': acBroken, 'ac_repair_since': acBroken ? '2026-10-02' : null, 'bath': 'Attached',
      'beds': [
        {'id': 'bed-a', 'letter': 'A', 'spot': '', 'state': 'free'},
        {'id': 'bed-b', 'letter': 'B', 'spot': '', 'state': walkIn == null ? 'free' : 'held', 'walk_in_until': walkIn},
        {'id': 'bed-c', 'letter': 'C', 'spot': '', 'state': 'booked'},
      ],
    },
  ],
  'layouts': [
    {
      'room': 204, 'stage': 'published', 'version': 1, 'w': 12, 'h': 14, 'updated_at': '2026-10-01T10:00:00Z',
      'beds': {'A': [2, 3], 'B': [8, 3], 'C': [8, 10]},
      'items': [
        {'id': 'ac1', 'kind': 'ac', 'x': 1, 'y': 0, 'w': 3, 'h': 1, 'working': !acBroken},
        {'id': 'fan1', 'kind': 'fan', 'x': 6, 'y': 6, 'w': 1, 'h': 1, 'working': true},
      ],
    },
  ],
};

class _Server extends SampleRepo {
  _Server({this.row});
  Map<String, dynamic>? row;
  final calls = <String>[];
  bool fail = false;
  String failWith = 'offline';
  ({Map<String, bool> notify, List<String> areas})? profile;
  List<Lead> tracker = [];
  List<TeamMember> members = [];

  Future<void> _rec(String c) async {
    if (fail) throw Exception(failWith);
    calls.add(c);
  }

  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => row == null ? null : listingsFromRows([row!]);
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me, staff: [if (me == 'fb-ravi') {'hostel_id': _hid, 'user_id': 'fb-ravi', 'role': 'owner'}]);
  @override
  Future<DateTime?> setItemWorking(String hid, int room, String item, bool working) async {
    await _rec('working $room $item $working');
    return working ? null : DateTime(2026, 10, 3, 9);
  }

  @override
  Future<DateTime> holdWalkIn(String bedKey) async {
    await _rec('walkin $bedKey');
    return DateTime.now().add(const Duration(minutes: 60));
  }

  @override
  Future<void> releaseWalkIn(String bedKey) => _rec('release $bedKey');
  @override
  Future<({Map<String, bool> notify, List<String> areas})?> loadNotify(String uid) async => profile;
  @override
  Future<void> saveNotify(String uid, Map<String, bool> notify) => _rec('notify ${notify['hold']} ${notify['rent']} ${notify['beds']}');
  @override
  Future<void> saveSearchedAreas(String uid, List<String> areas) => _rec('areas ${areas.join(',')}');
  @override
  Future<void> teamHello() => _rec('hello');
  @override
  Future<List<TeamMember>> teamMembers() async => members;
  @override
  Future<void> inviteTeamMember(String name, String phone, String role) async {
    await _rec('invite $name $phone $role');
    members = [...members, (name: name, phone: phone, role: role, joined: false)];
  }

  @override
  Future<List<Lead>> teamTracker() async => tracker;
  @override
  Future<void> setLeadStage(String hid, int stage) async {
    await _rec('stage $hid ${leadStages[stage]}');
    tracker = [for (final l in tracker) l.hid == hid ? Lead(l.name, l.area, l.next, stage, hid: l.hid) : l];
  }

  @override
  Future<void> goLive(String hid) => _rec('golive $hid');
}

/// The owner (or a tenant) signed in on the fake server, with the live hostel loaded.
Future<AppState> _onServer(_Server server, {String start = 'oToday', String role = 'owner', String uid = 'fb-ravi'}) async {
  final s = AppState(start: start, role: role);
  s.data = server;
  s.update(() => s.account = (uid: uid, name: 'Ravi', email: 'r@gmail.com'));
  final l = await server.listings();
  if (l != null) s.applyListings(l);
  await s.startLive();
  return s;
}

void main() {
  mapTiles = false;

  test('7: rows give the AC repair date; drafts never lie about a date', () {
    final l = listingsFromRows([_hostelRow()]);
    final r = l.rooms[_hid]!.single;
    expect((r.acRepair, r.acSince), (true, dayMon(DateTime(2026, 10, 2))));
    final ok = listingsFromRows([_hostelRow(acBroken: false)]).rooms[_hid]!.single;
    expect((ok.acRepair, ok.acSince), (false, ''));
  });

  testWidgets('7: tenants see "AC under repair" with the real complaint date', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant', mode: 'plan');
    s.applyListings(listingsFromRows([_hostelRow()]));
    s.update(() {
      s.hid = _hid;
      s.floor = 2;
      s.room = 204;
    });
    await _pump(tester, s);
    expect(find.textContaining('AC under repair. Complaint raised ${dayMon(DateTime(2026, 10, 2))}.'), findsWidgets);
    expect(find.textContaining('30 Sep'), findsNothing);
    s.dispose();
  });

  test('7: the owner marks the AC not working and working again; the server raises and closes the complaint', () async {
    final server = _Server(row: _hostelRow(acBroken: false));
    final s = await _onServer(server);
    expect(s.ownerHostels, contains(_hid));
    final l = s.layoutOf(_hid, 204)!;
    final ac = l.items.firstWhere((i) => i.kind == 'ac');
    final room = s.rooms[_hid]!.single;
    s.setWorking(l, ac, false);
    expect((ac.working, room.acRepair), (false, true)); // shows straight away
    await _settle();
    expect(server.calls.last, 'working 204 ac1 false');
    expect(room.acSince, dayMon(DateTime(2026, 10, 3)));
    expect(s.toast, 'AC unit marked not working. A complaint is raised.');
    // no complaint invented on the phone: it comes from the server
    expect(s.complaints, isEmpty);
    s.setWorking(l, ac, true);
    await _settle();
    expect(server.calls.last, 'working 204 ac1 true');
    expect((ac.working, room.acRepair, room.acSince), (true, false, ''));
    expect(s.toast, 'AC unit working again. Its complaint is closed.');
    // before the room's layout is on the server (or offline): undone, and said why
    server
      ..fail = true
      ..failWith = 'publish this room\'s layout first, then mark it';
    final fan = l.items.firstWhere((i) => i.kind == 'fan');
    s.setWorking(l, fan, false);
    await _settle();
    expect(fan.working, isTrue);
    expect(s.toast, 'Publish this room’s layout first, then mark it.');
    server.failWith = 'offline';
    s.setWorking(l, fan, false);
    await _settle();
    expect((fan.working, s.toast), (true, 'Couldn’t save it. Check your internet and try again.'));
    s.stopLive();
    s.dispose();
  });

  test('7: sample data: not working raises one complaint, working again resolves it', () {
    final s = AppState(start: 'oToday', role: 'owner');
    final l = s.layoutOf(s.ownHid, s.rooms[s.ownHid]!.firstWhere((r) => s.layoutOf(s.ownHid, r.n)?.items.any((i) => i.kind == 'fan') ?? false).n)!;
    final fan = l.items.firstWhere((i) => i.kind == 'fan');
    final before = s.complaints.length;
    s.setWorking(l, fan, false);
    expect(s.complaints.length, before + 1);
    expect(s.complaints.first.status, 'Open');
    s.setWorking(l, fan, true);
    expect((s.complaints.length, s.complaints.first.status, s.complaints.first.note), (before + 1, 'Resolved', 'Working again'));
    s.dispose();
  });

  testWidgets('8: Hold for a walk-in is saved on the server; Release ends it there', (tester) async {
    final server = _Server(row: _hostelRow());
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'oBeds'));
    await _pump(tester, s);
    final bed = s.rooms[_hid]!.single.beds.firstWhere((b) => b.letter == 'A');
    s.update(() {
      s.obed = bed.id;
      s.sheet = 'bed';
    });
    await tester.pump();
    await _tap(tester, find.text('Hold for a walk-in'));
    await tester.runAsync(_settle);
    await tester.pump();
    expect(server.calls.last, 'walkin bed-a');
    expect(bed.state, 'held');
    expect(s.walkIns['$_hid|${bed.id}'], greaterThan(DateTime.now().millisecondsSinceEpoch + 3500 * 1000));
    s.ownerReleaseBed(_hid, bed);
    await tester.runAsync(_settle);
    expect((server.calls.last, bed.state), ('release bed-a', 'free'));
    // someone else took it first: undone and said so
    server
      ..fail = true
      ..failWith = 'that bed isn\'t free any more';
    s.holdWalkIn(_hid, bed);
    await tester.runAsync(_settle);
    expect((bed.state, s.walkIns.containsKey('$_hid|${bed.id}'), s.toast), ('free', false, 'Bed ${bed.id} isn’t free any more.'));
    s.stopLive();
    await tester.pump(const Duration(seconds: 3));
  });

  test('8: a walk-in placed on another phone shows with its countdown', () async {
    final until = DateTime.now().add(const Duration(minutes: 40));
    final server = _Server(row: _hostelRow(walkIn: until.toUtc().toIso8601String()));
    final s = await _onServer(server);
    final b = s.rooms[_hid]!.single.beds.firstWhere((b) => b.letter == 'B');
    expect(b.state, 'held');
    expect((s.walkIns['$_hid|${b.id}']! - until.millisecondsSinceEpoch).abs(), lessThan(1000));
    // tenants: the bed is held, nothing more
    final t = AppState(start: 'explore', role: 'tenant');
    t.applyListings(listingsFromRows([_hostelRow(walkIn: until.toUtc().toIso8601String())]));
    expect(t.walkIns, isEmpty);
    expect(t.rooms[_hid]!.single.beds.firstWhere((b) => b.letter == 'B').state, 'held');
    s.stopLive();
    s.dispose();
    t.dispose();
  });

  testWidgets('22: Settings switches are saved on the profile and come back on sign-in', (tester) async {
    final server = _Server()..profile = (notify: {'hold': false, 'rent': true, 'beds': true}, areas: ['Madhapur']);
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'settings', role: 'tenant', uid: 'fb-asha'));
    s.update(() => s.osPushAllowed = true);
    await tester.runAsync(() => s.loadNotifyFromServer());
    expect((s.notif['hold'], s.notif['beds']), (false, true));
    expect(s.searchedAreas, ['Madhapur']);
    await _pump(tester, s);
    await _tap(tester, find.text('Rent reminders'));
    await tester.runAsync(_settle);
    expect(server.calls.last, 'notify false false true');
    // Where? → an area: kept for New free beds (newest first, at most 5)
    s.pickWhereArea('Ameerpet');
    await tester.runAsync(_settle);
    expect(server.calls.last, 'areas Ameerpet,Madhapur');
    expect(s.searchedAreas, ['Ameerpet', 'Madhapur']);
    for (final a in ['Kondapur', 'SR Nagar', 'Hitec City', 'Gachibowli']) {
      s.pickArea(a);
    }
    expect(s.searchedAreas, ['Gachibowli', 'Hitec City', 'SR Nagar', 'Kondapur', 'Ameerpet']);
    // kept on this phone too
    final again = AppState();
    again.restore(s.snapshot());
    expect((again.notif['rent'], again.searchedAreas.first), (false, 'Gachibowli'));
    again.dispose();
    s.stopLive();
    await tester.pump(const Duration(seconds: 3));
  });

  test('22: before the SQL runs (no profile columns) the switches stay on the phone', () async {
    final server = _Server()..profile = null;
    final s = await _onServer(server, start: 'settings', role: 'tenant', uid: 'fb-asha');
    s.update(() => s.osPushAllowed = true);
    await s.loadNotifyFromServer();
    expect(s.notif, {'hold': true, 'rent': true, 'beds': false});
    server
      ..fail = true
      ..failWith = 'column profiles.notify does not exist';
    s.toggleNotif('beds');
    await _settle();
    expect(s.notif['beds'], isTrue);
    expect(s.toast, isNull);
    s.stopLive();
    s.dispose();
  });

  testWidgets('29: the real app has no sample leads or "Founder 9000000100"; the tracker and team come from the server', (tester) async {
    final keep = AppState.samples;
    AppState.samples = false;
    addTearDown(() => AppState.samples = keep);
    final server = _Server()
      ..tracker = [Lead('Sri Sai PG', 'SR Nagar', 'Visit the hostel', 0, hid: 'h-lead'), Lead('Wave Two PG', 'Ameerpet', 'Trial ends 2 Nov', 5, hid: _hid)]
      ..members = [(name: 'Farhath', phone: '9059790014', role: 'Everything', joined: true)];
    final s = AppState(start: 'aTrack', role: 'owner');
    expect(s.leads, isEmpty);
    expect(s.teamMembers, isEmpty);
    s.data = server;
    s.update(() => s.account = (uid: 'fb-hq', name: 'Farhath', email: 'f@gmail.com'));
    await tester.runAsync(s.loadTeam);
    await _pump(tester, s);
    expect(find.text('Sri Sai PG'), findsOneWidget);
    expect(find.text('Anjani Residency'), findsNothing);
    await _tap(tester, find.text('Visited'));
    await tester.runAsync(_settle);
    await tester.pump();
    expect(server.calls.last, 'stage h-lead visited');
    expect(s.leads.firstWhere((l) => l.hid == 'h-lead').stage, 1);
    // Live tab: trial and paying follow the plan, so no button there
    s.update(() => s.trackTab = 3);
    await tester.pump();
    expect(find.text('Wave Two PG'), findsOneWidget);
    expect(find.text('Paying'), findsNothing);
    // Team members: the server's rows; an invite is saved there
    s.go('aTeam');
    await tester.pump();
    expect(find.text('Farhath'), findsOneWidget);
    expect(find.textContaining('9000000100'), findsNothing);
    s.update(() {
      s.tmName = 'Sana';
      s.tmPhone = '98480 22338';
      s.tmRole = 'Visits';
    });
    await tester.runAsync(s.addTeamMember);
    await tester.pump();
    expect(server.calls.last, 'invite Sana 9848022338 Visits');
    expect(find.text('Sana'), findsOneWidget);
    expect(s.teamMembers.last.joined, isFalse);
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  test('29: opening team tools says hello to the server (the account shows Active) and loads the team', () async {
    final server = _Server()..members = [(name: 'Farhath', phone: '9059790014', role: 'Everything', joined: true)];
    final s = AppState(start: 'settings', role: 'tenant');
    s.data = server;
    s.signIn = _TeamSignIn();
    s.update(() => s.account = (uid: 'fb-hq', name: 'Farhath', email: 'f@gmail.com'));
    await s.checkTeam();
    expect((s.screen, server.calls.join(), s.teamMembers.single.name), ('aHome', 'hello', 'Farhath'));
    s.dispose();
  });
}

class _TeamSignIn extends NoSignIn {
  @override
  Future<bool> isTeam() async => true;
}
