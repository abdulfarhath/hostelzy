import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/kit.dart' show Pal;
import 'package:hostelzy/ui/shell.dart';

// F22 Area 1 (Tenant): Me as one list with status lines, Settings in three
// groups, Saved and Holds lists, one status card per hold, the pay and
// WhatsApp sheets, the picker as room cards, the Room view and Reviews.

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

void main() {
  mapTiles = false;

  testWidgets('F22 Area 1: Me is one list with a status on each row; Settings has three groups', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    s
      ..phone = '9000000001'
      ..myName = 'Ravi Teja';
    s.saved['anjani'] = true;
    s.saved['orchid'] = true;
    await _pump(tester, s);
    expect(find.text('RT'), findsOneWidget);
    expect(find.text('Ravi Teja'), findsOneWidget);
    expect(find.text('+91 90000 00001 · not verified'), findsOneWidget);
    // F26 #10: Saved and Holds are tabs, not rows; F26 #11: Log out in red at the end.
    expect(find.text('2 hostels'), findsNothing);
    expect(find.byKey(const ValueKey('me-Saved')), findsNothing);
    expect(find.byKey(const ValueKey('me-Holds')), findsNothing);
    expect(find.text('Not a member yet'), findsOneWidget);
    expect(find.text('Language, notifications, log out'), findsOneWidget);
    expect(find.byKey(const ValueKey('me-logout')), findsOneWidget);
    expect(tester.widget<Text>(find.text('Log out')).style?.color, Pal.light.ad);
    await _tap(tester, find.byKey(const ValueKey('switchRole')));
    s.update(() => s.screen = 'me');
    await tester.pump();

    await _tap(tester, find.byKey(const ValueKey('me-Settings')));
    expect(s.screen, 'settings');
    for (final g in ['YOU', 'NOTIFICATIONS', 'APP']) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    expect(find.text('Holds and bookings'), findsOneWidget);
    expect(find.text('Help on WhatsApp'), findsNothing);
    await _tap(tester, find.text('Dark'));
    expect(s.theme, 'dark');
    await _tap(tester, find.text('Auto'));
    expect(s.theme, 'system');
    expect(find.text('Delete account'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F22 Area 1: Saved unsaves with Undo; Holds lists each hold and asks "Did you join?" inline', (tester) async {
    final s = AppState(start: 'saved', role: 'tenant');
    s.saved['anjani'] = true;
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('savedRow-anjani')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('unsave-anjani')));
    expect((s.saved['anjani'], s.toast), (false, 'Removed Anjani Residency'));
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('undo')));
    expect(s.saved['anjani'], isTrue);
    await tester.pump(const Duration(seconds: 6));
    s.dispose();

    final hs = AppState(start: 'hold', role: 'tenant');
    await _pump(tester, hs);
    hs.tab('holds');
    await tester.pump();
    final h = hs.holds.single;
    expect(find.byKey(ValueKey('holdRow-${h.id}')), findsOneWidget);
    expect(find.text('WAITING FOR OWNER'), findsOneWidget);
    // When it ends: "Did you join?" right on the list.
    hs.expireHoldsAt(h.start + hs.holdSecs * 1000);
    await tester.pump();
    expect(find.byKey(const ValueKey('joinedAsk')), findsOneWidget);
    await _tap(tester, find.text('The owner asked me to skip the app ›'));
    expect(hs.sheet, 'report');
    hs.dispose();

    final e = AppState(start: 'holds', role: 'tenant');
    e.holds = [];
    await _pump(tester, e);
    expect(find.text('No holds yet'), findsOneWidget);
    await _tap(tester, find.text('Find a bed'));
    expect(e.screen, 'explore');
    e.dispose();
  });

  testWidgets('F22 Area 1: one status card per hold: held, pay to book, booked, ended', (tester) async {
    final s = AppState(start: 'hold', role: 'tenant');
    await _pump(tester, s);
    final h = s.holds.single;
    expect(find.byKey(const ValueKey('holdCard')), findsOneWidget);
    expect(find.text('HELD FOR YOU · FREE'), findsOneWidget);
    expect(find.text('Tell Srinivas on WhatsApp'), findsOneWidget);
    // F26 #7: WhatsApp opens straight away with a ready message (no enquiry sheet).
    await _tap(tester, find.text('Tell Srinivas on WhatsApp'));
    expect(s.sheet, isNull);
    expect(Uri.decodeFull(s.lastLink.toString()), contains('I held bed ${h.bed} at Anjani Residency on Hostelzy.'));

    // Owner confirms: still held, now with "owner confirmed".
    s.setHold(h.id, 'confirmed');
    await tester.pump();
    expect(find.text('HELD · SRINIVAS CONFIRMED'), findsOneWidget);
    // Ended: 0:00, and "Hold it again".
    s.expireHoldsAt(h.start + s.holdSecs * 1000);
    await tester.pump();
    expect(find.text('HOLD ENDED'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Hold it again'), findsOneWidget);
    s.dispose();

    // Pay to book: the pay sheet says where the money goes.
    final b = AppState(start: 'picker', role: 'tenant');
    b
      ..phone = '9000000001'
      ..myName = 'Ravi Teja';
    await _pump(tester, b);
    final free = b.rooms['anjani']!.expand((r) => r.beds).firstWhere((x) => x.state == 'free' && !x.mine);
    b.update(() {
      b.floor = int.parse(free.id.substring(0, 1));
      b.bed = free.id;
      b.sheet = 'hold';
      b.holdOpt = 'book';
    });
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('holdGo')));
    expect(b.sheet, 'payAdv');
    expect(find.text('Pay to Srinivas'), findsOneWidget);
    expect(find.text('Pay with a UPI app'), findsOneWidget);
    expect(find.text('Hostelzy never holds your money. It goes straight to the owner.'), findsOneWidget);
    b.update(() => b.sheet = null);
    await tester.pump();
    expect(find.text('PAY TO BOOK'), findsOneWidget);
    b.dispose();
  });

  testWidgets('F22 Area 1: picker is floors as chips and rooms as cards; Room view shows one bed', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    s
      ..phone = '9000000001'
      ..myName = 'Ravi Teja';
    await _pump(tester, s);
    expect(find.text('Pick a bed'), findsOneWidget);
    for (final f in floorsOf(s.rooms['anjani']!)) {
      expect(find.byKey(ValueKey('floor-$f')), findsOneWidget);
    }
    await _tap(tester, find.byKey(const ValueKey('floor-2')));
    expect(s.floor, 2);
    final onFloor = s.rooms['anjani']!.where((r) => r.floor == 2).toList();
    for (final r in onFloor) {
      expect(find.byKey(ValueKey('roomCard-${r.n}')), findsOneWidget);
    }
    expect(find.text('No bed picked'), findsOneWidget);
    // Continue with no bed says so.
    await _tap(tester, find.byKey(const ValueKey('pickContinue')));
    expect((s.sheet, s.toast), (null, 'Pick a free bed first.'));
    await tester.pump(const Duration(seconds: 3));
    final r = onFloor.firstWhere((r) => r.beds.any((b) => b.state == 'free' && !b.mine));
    final b = r.beds.firstWhere((b) => b.state == 'free' && !b.mine);
    await _tap(tester, find.byKey(ValueKey('bed-${b.id}')));
    expect(s.bed, b.id);
    expect(find.text('Bed ${b.id} · ${fmt(r.rent)}/mo'), findsOneWidget);
    expect(find.text('Floor ${r.floor} · ${b.spot}'), findsOneWidget);
    // A taken bed can't be picked.
    final taken = s.rooms['anjani']!.where((x) => x.floor == 2).expand((x) => x.beds).where((x) => x.state == 'booked').firstOrNull;
    if (taken != null) {
      await _tap(tester, find.byKey(ValueKey('bed-${taken.id}')));
      expect((s.bed, s.toast), (b.id, 'This bed is taken.'));
      await tester.pump(const Duration(seconds: 3));
    }
    await _tap(tester, find.byKey(const ValueKey('pickContinue')));
    expect(s.sheet, 'hold');
    s.update(() => s.sheet = null);
    // F26 #8: no cheapest-beds list; every room with its price is on the scroll.
    expect(find.text('See cheapest beds ›'), findsNothing);

    // The room name opens the Room view: the room in the title, one bed's facts.
    await _tap(tester, find.byKey(const ValueKey('floor-3')));
    await _tap(tester, find.descendant(of: find.byKey(const ValueKey('roomCard-304')), matching: find.text('Room 304')));
    expect((s.mode, s.room), ('room', 304));
    expect(find.text('Room 304'), findsOneWidget);
    expect(find.byKey(const ValueKey('bedFacts')), findsOneWidget);
    expect(find.text('Same price for every bed here'), findsOneWidget);
    expect(find.text('Compare with another bed ›'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('roomContinue')));
    expect(s.sheet, 'hold');
    s.dispose();
  });

  testWidgets('F22 Area 1: Reviews: the score beside the bars, stays with owner replies, the rule', (tester) async {
    final s = AppState(start: 'reviews', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    final h = hostelById('anjani');
    expect(find.text('${h.reviews} verified stays'), findsOneWidget);
    for (final c in reviewCats) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    expect(find.text('Exit review · Stayed 8 months · left Aug 2026'), findsOneWidget);
    expect(find.textContaining('Srinivas replied: ', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Only people who stayed here can review. Owners can reply, not delete.'), 200);
    expect(find.text('Only people who stayed here can review. Owners can reply, not delete.'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F22 Area 1: the notifications ask promises only what the app does', (tester) async {
    final s = AppState(start: 'perm', role: 'tenant');
    await _pump(tester, s);
    expect(find.text('Turn on notifications?'), findsOneWidget);
    expect(find.text('When the owner confirms your hold'), findsOneWidget);
    expect(find.text('Rent reminders, 3 days before'), findsOneWidget);
    expect(find.textContaining('about to end'), findsNothing);
    s.dispose();
  });
}
