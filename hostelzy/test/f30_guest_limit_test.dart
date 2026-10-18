import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show filtered;
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/sign_in.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F30 (wave 1): guests open 3 verified hostel pages per phone, then the
// sign-in wall (T34 `signInWall`); the S8 first-visit hint. UNVERIFIED pages
// (T32) stay free; re-opening one of the 3 is free; signed in = no limit.

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1, double width = 390}) async {
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shell = AppScope(state: state, child: const HostelzyShell(bare: true));
  await tester.pumpWidget(MaterialApp(home: scale == 1 ? shell : MediaQuery(data: MediaQueryData(size: Size(width, 844), textScaler: TextScaler.linear(scale)), child: shell)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// Google sign-in that works (the Android app).
class _Google implements SignIn {
  @override
  bool get available => true;
  @override
  Future<(Account?, SignInFail?)> google() async => ((uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com'), null);
  @override
  Future<String?> idToken() async => 'id-token';
  @override
  Future<bool> isTeam() async => false;
  @override
  Account? get current => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<SignInFail?> reauth() async => null;
  @override
  Future<void> deleteUser() async {}
  @override
  String? get lastError => null;
}

/// The sample verified hostels, in Explore's order.
List<String> _verified(AppState s) => [for (final h in filtered(s)) if (!h.listed) h.id];

void main() {
  mapTiles = false;

  testWidgets('F30: 3 verified hostels are free, the 4th shows the wall, re-opening is free, Not now goes to Explore, a listed page never walls', (tester) async {
    final s = AppState()..browse();
    await _pump(tester, s);
    expect((s.signedIn, s.screen), (false, 'explore'));
    final ids = _verified(s);
    expect(ids.length >= 4, isTrue);
    for (final id in ids.take(3)) {
      await _tap(tester, find.text(hostelById(id).name));
      expect((s.screen, s.hid), ('detail', id));
      expect(find.byKey(const ValueKey('signInWall')), findsNothing);
      expect(find.text('Pick a bed'), findsOneWidget);
      s.back();
      await tester.pump();
    }
    expect(s.guestHostels, ids.take(3).toList());
    // One of the 3 again: free, not counted twice.
    await _tap(tester, find.text(hostelById(ids[0]).name));
    expect(find.byKey(const ValueKey('signInWall')), findsNothing);
    expect(s.guestHostels.length, 3);
    s.back();
    await tester.pump();
    // The 4th: T34 instead of the page, with the live count and the three names.
    await _tap(tester, find.text(hostelById(ids[3]).name));
    expect((s.screen, s.hid), ('detail', ids[3]));
    expect(find.byKey(const ValueKey('signInWall')), findsOneWidget);
    expect(find.text('Sign in to see all ${s.tierCounts(null).verified} hostels'), findsOneWidget);
    expect(find.text('Your 3 free hostels: ${ids.take(3).map((id) => hostelById(id).name).join(', ')}.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Pick a bed'), findsNothing);
    expect(find.textContaining('Login required'), findsNothing);
    expect(s.guestHostels.length, 3);
    // Not now: back to Explore.
    await _tap(tester, find.byKey(const ValueKey('wallNotNow')));
    expect((s.screen, s.sheet), ('explore', null));
    // An UNVERIFIED page is free, and never counts.
    await _tap(tester, find.byKey(const ValueKey('listedCard-balaji')));
    expect(find.byKey(const ValueKey('unverifiedPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('signInWall')), findsNothing);
    expect(s.guestHostels.length, 3);
    s.back();
    await tester.pump();
    // Kept on this phone.
    expect(s.snapshot()['guestHostels'], ids.take(3).toList());
    s.dispose();
  });

  testWidgets('F30: Continue with Google signs in and lands on the hostel; sign-in clears the count (sample path and Google)', (tester) async {
    // Builds without Google sign-in (the demo APK): the existing sample path, About you.
    final s = AppState()..browse();
    final ids = _verified(s);
    s.update(() => s.guestHostels = ids.take(3).toList());
    await _pump(tester, s);
    await _tap(tester, find.text(hostelById(ids[3]).name));
    expect(find.byKey(const ValueKey('signInWall')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('wallGoogle')));
    expect((s.screen, s.afterSignIn, s.signedIn), ('phone', 'wall', false));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('myName')), matching: find.byType(TextField)), 'Asha Kumari');
    s.update(() => s.phone = '9876543210');
    await tester.pump();
    await _tap(tester, find.text('Continue'));
    expect((s.signedIn, s.role, s.screen, s.hid, s.afterSignIn), (true, 'tenant', 'detail', ids[3], null));
    expect(s.guestHostels, isEmpty);
    expect(find.byKey(const ValueKey('signInWall')), findsNothing);
    expect(find.text('Pick a bed'), findsOneWidget);
    // Signed in: no limit.
    s.back();
    await tester.pump();
    for (final id in ids.take(4)) {
      await _tap(tester, find.text(hostelById(id).name));
      expect(find.byKey(const ValueKey('signInWall')), findsNothing);
      s.back();
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('guestHint')), findsNothing);
    s.dispose();

    // The Android app: Google, then About you, then the hostel.
    final g = AppState()..browse();
    g.signIn = _Google();
    g.update(() => g.guestHostels = ids.take(3).toList());
    await _pump(tester, g);
    await _tap(tester, find.text(hostelById(ids[3]).name));
    expect(find.byKey(const ValueKey('signInWall')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('wallGoogle')));
    await tester.pump();
    expect((g.screen, g.account?.uid, g.afterSignIn), ('phone', 'fb-asha', 'wall'));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('myName')), matching: find.byType(TextField)), 'Asha K');
    g.update(() => g.phone = '9876543210');
    await tester.pump();
    await _tap(tester, find.text('Continue'));
    expect((g.signedIn, g.screen, g.hid), (true, 'detail', ids[3]));
    expect(g.guestHostels, isEmpty);
    expect(find.byKey(const ValueKey('signInWall')), findsNothing);
    g.dispose();
  });

  testWidgets('F30: the map card, Saved and Where? count an open too', (tester) async {
    final s = AppState()..browse();
    s.update(() => s.saved['anjani'] = true);
    await _pump(tester, s);
    s.tab('map');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('mapView')));
    expect((s.screen, s.hid), ('detail', 'anjani'));
    expect(s.guestHostels, ['anjani']);
    s.back();
    await tester.pump();
    s.tab('saved');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('savedRow-anjani')));
    expect(s.screen, 'detail');
    expect(s.guestHostels, ['anjani']);
    s.back();
    await tester.pump();
    s.tab('explore');
    await tester.pump();
    s.openWhere();
    await tester.pump();
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('whereQ')), matching: find.byType(TextField)), 'sai');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('hostel-saisri')));
    expect((s.screen, s.hid), ('detail', 'saisri'));
    expect(s.guestHostels, ['anjani', 'saisri']);
    s.dispose();
  });

  test('F30: the count and the hint are kept on this phone; the rules', () {
    final s = AppState();
    s.restore({'guestHostels': ['anjani', 'saisri', 7], 'guestHint': true});
    expect(s.guestHostels, ['anjani', 'saisri']);
    expect(s.guestHintOff, isTrue);
    expect(s.snapshot()['guestHostels'], ['anjani', 'saisri']);
    expect(s.snapshot()['guestHint'], true);
    expect(s.canOpenHostel(hostelById('nest42')), isTrue);
    s.update(() => s.guestHostels = ['anjani', 'saisri', 'nest42']);
    expect(s.canOpenHostel(hostelById('anjani')), isTrue);
    expect(s.canOpenHostel(hostelById('balaji')), isTrue);
    expect(s.wallFor(hostelById('orchid')), isTrue);
    // Opening the 4th does not count it; it walls.
    s.openHostel('orchid');
    expect((s.screen, s.hid, s.guestHostels.length), ('detail', 'orchid', 3));
    s.update(() => s.signedIn = true);
    expect(s.wallFor(hostelById('orchid')), isFalse);
    s.dispose();
  });

  testWidgets('F30: the Explore hint shows for a guest until dismissed, never when signed in', (tester) async {
    final s = AppState()..browse();
    await _pump(tester, s);
    expect(find.text('3 hostels free to open, then sign in (free)'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('guestHintClose')));
    expect(find.byKey(const ValueKey('guestHint')), findsNothing);
    expect(s.snapshot()['guestHint'], true);
    s.dispose();
    final t = AppState(start: 'explore', role: 'tenant');
    await _pump(tester, t);
    expect(find.byKey(const ValueKey('guestHint')), findsNothing);
    t.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('F30: the wall fits 360 px at 2× text (${dark ? 'dark' : 'light'})', (tester) async {
      final s = AppState()..browse();
      s.update(() {
        s.guestHostels = ['anjani', 'saisri', 'nest42'];
        s.theme = dark ? 'dark' : 'light';
      });
      s.openHostel('orchid');
      await _pump(tester, s, scale: 2, width: 360);
      expect(find.byKey(const ValueKey('signInWall')), findsOneWidget);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
