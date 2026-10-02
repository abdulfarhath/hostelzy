import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F22 Areas 4 and 5: sign in with one button (or keep browsing), About you
// with two fields, "What brings you here?", Join your PG / List your PG, the
// permission asks and Delete account as two short lists.

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

void main() {
  mapTiles = false;

  testWidgets('F22 Area 4: sign in says why; a guest can keep browsing', (tester) async {
    final s = AppState(start: 'login');
    await _pump(tester, s);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Use on this phone only'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('keepGuest')));
    expect((s.screen, s.signedIn), ('explore', false));
    s.dispose();

    final o = AppState(start: 'login');
    o.afterSignIn = 'owner';
    await _pump(tester, o);
    expect(find.text('Sign in to list your PG'), findsOneWidget);
    o.dispose();
  });

  testWidgets('F22 Area 4: About you has two fields; the role picker has three rows', (tester) async {
    final s = AppState(start: 'phone');
    await _pump(tester, s);
    expect(find.text('About you'), findsWidgets);
    expect(find.text('Owners use this to call or WhatsApp you.'), findsOneWidget);
    expect(find.text('NOT VERIFIED'), findsOneWidget);
    expect(find.text('We’ll check it by SMS later. Until then owners see “not verified”.'), findsOneWidget);
    s.dispose();

    final r = AppState(start: 'role');
    r.signedIn = true;
    r.myName = 'Ravi Teja';
    await _pump(tester, r);
    expect(find.text('WELCOME, RAVI'), findsOneWidget);
    expect(find.text('What brings you here?'), findsOneWidget);
    for (final k in ['tenant', 'resident', 'owner']) {
      expect(find.byKey(ValueKey('role-$k')), findsOneWidget);
    }
    expect(find.text('You can switch later in Me.'), findsOneWidget);
    r.dispose();
  });

  testWidgets('F22 Area 4: Join your PG with a code, or send your number; List your PG', (tester) async {
    final s = AppState(start: 'roleGate');
    s.update(() {
      s.roleGate = 'resident';
      s.phone = '9000000001';
    });
    await _pump(tester, s);
    expect(find.text('Join your PG'), findsOneWidget);
    expect(find.byKey(const ValueKey('inviteCode')), findsOneWidget);
    expect(find.text('Scan the poster QR'), findsOneWidget);
    expect(find.text('Ask your owner to add you with +91 90000 00001.'), findsOneWidget);
    await _tap(tester, find.text('Send my number on WhatsApp'));
    expect(Uri.decodeComponent(s.lastLink.toString()), contains('+91 90000 00001'));
    s.dispose();

    final o = AppState(start: 'roleGate');
    o.roleGate = 'owner';
    await _pump(tester, o);
    expect(find.text('List your PG'), findsOneWidget);
    expect(find.text('We visit, take photos and set it up with you. 30 days free, then from ₹499 a month. No commission.'), findsOneWidget);
    expect(find.text('WhatsApp Hostelzy'), findsOneWidget);
    o.dispose();
  });

  testWidgets('F22 Area 5: the one permission ask is notifications; Delete account is two lists', (tester) async {
    // Photos come from the phone's picker (no camera permission); location from the Near me sheet.
    final s = AppState(start: 'perm');
    await _pump(tester, s);
    expect(find.text('Turn on notifications?'), findsOneWidget);
    expect(find.text('Your phone asks next. Change it any time in Settings.'), findsOneWidget);
    expect(find.textContaining('camera'), findsNothing);
    expect(find.textContaining('later update'), findsNothing);
    s.dispose();

    final d = AppState(start: 'delAcc', role: 'tenant');
    d.holds = [];
    await _pump(tester, d);
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Kept, without your name'), findsOneWidget);
    expect(find.text('Your reviews, shown as “Former resident”'), findsOneWidget);
    expect(find.text('Keep my account'), findsOneWidget);
    d.dispose();
  });

  for (final c in const ['login', 'phone', 'role', 'perm', 'delAcc']) {
    testWidgets('F22 Areas 4–5: $c fits at 2× text', (tester) async {
      final s = AppState(start: c);
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
