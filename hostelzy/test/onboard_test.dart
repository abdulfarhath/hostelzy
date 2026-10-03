import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/photos/photo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 items 2 and 3: the team's Add hostel wizard saves the hostel on the
// server, links the owner's account with a one-time link, and goes live with
// the 30-day trial; owners' room changes are saved too.

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
  Map<String, dynamic>? saved;
  bool linked = false;
  String? goLiveError, roomsError;
  int photoCount = 0;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<String> saveHostel(String? id, Map<String, dynamic> p) async {
    calls.add('save ${id ?? 'new'}');
    saved = p;
    return 'h-new';
  }

  @override
  Future<List<HostelPhoto>> photos(String hid) async => [
    for (var i = 0; i < photoCount; i++) (id: 'p$i', path: '$hid/p$i.jpg', url: '', label: 'Front', ord: i, cover: i == 0),
  ];
  @override
  Future<String> ownerInvite(String hid, String name, String phone) async {
    calls.add('invite $hid $name $phone');
    return 'OWN-ABCD2345';
  }

  @override
  Future<bool> ownerLinked(String hid) async => linked;
  @override
  Future<void> goLive(String hid) async {
    if (goLiveError != null) throw Exception(goLiveError);
    calls.add('live $hid');
  }

  @override
  Future<String> joinAsOwner(String code) async {
    calls.add('join $code');
    return 'Sri Sai Annex';
  }

  @override
  Future<void> saveRooms(String hid, List<Map<String, dynamic>> rooms) async {
    if (roomsError != null) throw Exception(roomsError);
    calls.add('rooms $hid ${rooms.length}');
  }
}

Future<AppState> _onServer(WidgetTester tester, _Server server, {String start = 'aAdd', String role = 'owner'}) async {
  final s = AppState(start: start, role: role);
  s.data = server;
  s.update(() => s.account = (uid: 'fb-hq', name: 'Hostelzy team', email: 'hq@gmail.com'));
  await s.startLive();
  await _pump(tester, s);
  return s;
}

void main() {
  mapTiles = false;

  test('a real hostel starts from an empty draft, not the sample one', () {
    final d = HostelDraft.blank();
    expect((d.name, d.area, d.ownerName, d.roomCount, d.prices.isEmpty, d.photos.isEmpty), ('', '', '', 0, true, true));
    expect(d.floors.map((f) => f.name), ['Ground floor', '1st floor']);
  });

  testWidgets('the wizard saves the draft, adds real photos, links the owner and goes live', (tester) async {
    final server = _Server();
    final s = await _onServer(tester, server);
    expect(find.text('Add hostel · step 1 of 7'.toUpperCase()), findsOneWidget);
    s.update(() => s.addStep = 3);
    await tester.pump();

    // Rate card → photos: saved on the server first.
    await _tap(tester, find.text('Next: photos'));
    await _settle(tester);
    expect(server.calls, ['save new']);
    expect((s.draft.serverId, s.addStep), ('h-new', 4));
    final p = server.saved!;
    expect((p['name'], p['owner_name'], (p['rooms'] as List).length, (p['rates'] as List).length), ('Anjani Annex', 'Srinivas', s.draft.roomCount, 3));
    final r204a = (p['rooms'] as List).cast<Map<String, dynamic>>().firstWhere((r) => r['label'] == '204A');
    expect((r204a['floor'], r204a['share'], r204a['rent']), (2, 2, 8100));

    // Photos: real uploads, counted from the server.
    expect(find.text('0 of 8 photos'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('draftPhotos')));
    expect((s.screen, s.photoHid), ('oPhotos', 'h-new'));
    server.photoCount = 8;
    s.back();
    await s.loadPhotos('h-new', again: true);
    await tester.pump();
    expect(s.draftPhotos, 8);

    // Residents → owner account.
    await _tap(tester, find.text('Next: residents'));
    await _tap(tester, find.text('Next: owner account'));
    await _settle(tester);
    expect(s.addStep, 6);
    expect(find.text('Not linked yet'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('ownerPhone6')), matching: find.byType(EditableText)), '98765 11111');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('ownerLink')));
    await _settle(tester);
    expect(server.calls.last, 'invite h-new Srinivas 9876511111');
    expect(Uri.decodeFull(s.lastLink.toString()), contains('/j/?c=OWN-ABCD2345'));
    expect(find.text('Link sent · waiting for Srinivas'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('ownerCheck')));
    await _settle(tester);
    expect((s.draft.ownerLinked, s.toast), (false, 'Not yet. Ask Srinivas to open the link and sign in.'));
    server.linked = true;
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, find.byKey(const ValueKey('ownerCheck')));
    await _settle(tester);
    expect(s.draft.ownerLinked, isTrue);
    expect(find.text('Linked'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Go live: the checklist has the owner row; the server says what's missing.
    await _tap(tester, find.text('Next: go live'));
    expect(find.text('Owner account linked'), findsOneWidget);
    s.update(() {
      s.draft
        ..ownerVerified = true
        ..fairPlay = true
        ..bedsChecked = true
        ..pinChecked = true
        ..pin = (17.4622, 78.3568);
      s.draft.prices['non4'] = 6500;
    });
    expect(s.goLiveLeft, isEmpty);
    server.goLiveError = 'PostgrestException(message: add 8 photos first, code: P0001)';
    s.goLive();
    await _settle(tester);
    expect((s.screen, s.toast), ('aAdd', 'Add 8 photos first.'));
    await tester.pump(const Duration(seconds: 4));
    server.goLiveError = null;
    s.goLive();
    await _settle(tester);
    expect(server.calls.last, 'live h-new');
    expect((s.screen, s.toast), ('aTrack', 'Anjani Annex is live. The 30-day trial starts today.'));
    s.dispose();
  });

  testWidgets('the owner opens their link and runs the PG', (tester) async {
    final server = _Server();
    final s = await _onServer(tester, server, start: 'roleGate', role: 'tenant');
    s.openInviteLink('own-abcd2345');
    expect(s.toast, 'Owner link saved. Sign in and pick “I run a PG”.');
    s.update(() => s.roleGate = 'owner');
    await tester.pump();
    expect(find.byKey(const ValueKey('ownerJoin')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('ownerJoinGo')));
    await _settle(tester);
    expect(server.calls.last, 'join OWN-ABCD2345');
    expect((s.role, s.screen, s.pendingInvite), ('owner', 'oToday', null));
    expect(s.toast, 'You run Sri Sai Annex on Hostelzy now.');
    s.dispose();
  });

  testWidgets('an owner’s room change is saved, and undone if the server says no', (tester) async {
    final server = _Server();
    final s = await _onServer(tester, server, start: 'oRooms');
    final n = s.rooms['anjani']!.length;
    s.openAddRoom('anjani', 3);
    final label = s.nrLabel;
    s.addRoom('anjani');
    await _settle(tester);
    expect(server.calls.last, 'rooms anjani ${n + 1}');
    expect(s.rooms['anjani']!.length, n + 1);
    await tester.pump(const Duration(seconds: 4));

    // Someone took a bed there meanwhile: the server says no and it comes back.
    server.roomsError = 'PostgrestException(message: room $label has someone in it, code: P0001)';
    final added = s.rooms['anjani']!.firstWhere((r) => r.label == label);
    s.removeRoom('anjani', added.n);
    await _settle(tester);
    expect(s.rooms['anjani']!.length, n + 1);
    expect(s.toast, 'Not saved: room $label has someone in it.');
    s.dispose();
  });

  for (final st in const [4, 6]) {
    testWidgets('onboarding: step $st fits at 2× text on the server', (tester) async {
      final s = await _onServer(tester, _Server());
      s.update(() {
        s.draft.serverId = 'h-new';
        s.addStep = st;
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
