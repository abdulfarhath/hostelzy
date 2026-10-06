import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F22 Area 2 (Resident): Rent as one card with one action, Food today first,
// Me › My stay, Give notice and Move to another bed with the action at the
// bottom, star rows for reviews, and Stay Rewards as one card and 3 steps.

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

  testWidgets('F22 Area 2: Rent is one card: Due → Waiting for owner → Paid (dark), with Paid before and the advance', (tester) async {
    final s = AppState(start: 'rPay', role: 'resident');
    await _pump(tester, s);
    expect(find.text('ANJANI RESIDENCY · BED 204-B'), findsOneWidget);
    expect(find.byKey(const ValueKey('rentCard')), findsOneWidget);
    expect(find.text('₹8,020'), findsOneWidget);
    for (final r in ['Rent', 'Electricity · 210 units ÷ 4 · ₹8/unit', 'Pay to', 'September', 'August']) {
      expect(find.text(r), findsWidgets, reason: r);
    }
    expect(find.text('PAID BEFORE'), findsOneWidget);
    expect(find.text('Advance ₹3,000 · ₹2,000 back when you leave'), findsOneWidget);
    expect(find.text('Pay ₹8,020 by UPI'), findsOneWidget);

    final rent = s.myRentPay!;
    s.update(() {
      rent.status = 'waiting';
      rent.utr = '402188341297';
    });
    await tester.pump();
    expect(find.text('WAITING FOR SRINIVAS'), findsOneWidget);
    expect(find.text('You sent UPI reference 4021 8834 1297. It says Paid once Srinivas sees it.'), findsOneWidget);
    await _tap(tester, find.text('Remind Srinivas'));
    expect(s.lastLink.toString(), startsWith('https://wa.me/'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Fix the UPI reference'), findsOneWidget);

    unawaited(s.confirmPayment(rent, true));
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('RENT · PAID'), findsOneWidget);
    final card = tester.widget<Container>(find.byKey(const ValueKey('rentCard')));
    expect(card.color, isNot(equals(Colors.transparent)));
    await _tap(tester, find.text('Share receipt'));
    expect(s.lastShare, contains('Rent receipt'));
    s.dispose();
  });

  testWidgets('F26 #4 #13: Home shows the whole week, today highlighted, no toggle; breakfast feedback is anonymous', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('homeWeek')), findsOneWidget);
    expect(find.text('FOOD THIS WEEK'), findsOneWidget);
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.textContaining(d), findsWidgets, reason: d);
    }
    // The shared week table (same as the hostel page): today's row carries "today".
    expect(find.byKey(const ValueKey('weekTable')), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('weekRow-$todayIdx')), matching: find.text('today')), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('weekRow-$todayIdx')), matching: find.text(weekDays[todayIdx][0])), findsOneWidget);
    for (final day in s.menu) {
      expect(find.text(day.b), findsWidgets);
    }
    // No Today / Full week toggle and no Food page any more.
    expect(find.text('Full week'), findsNothing);
    expect(find.text('Whole week ›'), findsNothing);
    expect(AppState.screens.contains('food'), isFalse);
    expect(find.text('How was breakfast?'), findsOneWidget);
    await _tap(tester, find.text('Good'));
    expect(s.rated, 'Good');
    expect(find.text('Srinivas sees how many said each, never your name.'), findsOneWidget);
    expect(s.toast, 'Thanks. Srinivas sees how many said Good, not who.');
    expect(s.mealVotes['b']!['good'], 10);
    s.dispose();
  });

  testWidgets('F26 #14: the My stay tab: the bed, then move, notice, refund, review, fix a layout, then Help', (tester) async {
    final s = AppState(start: 'me', role: 'resident');
    await _pump(tester, s);
    expect(find.text('Give notice'), findsNothing); // not on Me any more
    expect(find.byKey(const ValueKey('me-My stay')), findsNothing); // a tab now
    await _tap(tester, find.byKey(const ValueKey('tab-rStay')));
    expect((s.screen, s.hist.isEmpty), ('rStay', true));
    expect(find.text('Bed 204-B · Room 204'), findsOneWidget);
    expect(find.textContaining('₹7,600 a month · rent due on the 14th'), findsOneWidget);
    for (final r in ['Move to another bed', 'Give notice', 'Review your stay', 'Fix a room layout', 'Something wrong in your room?', 'Your complaints']) {
      expect(find.byKey(ValueKey('stay-$r')), findsOneWidget, reason: r);
    }
    expect(find.text('Your refund'), findsOneWidget);
    expect(find.text('₹2,000 back when you leave'), findsOneWidget);
    expect(find.text('HELP'), findsOneWidget);

    // Give notice: 3 last days, the reason is optional, the action at the bottom.
    await _tap(tester, find.text('Give notice'));
    expect((s.screen, s.moveTab), ('move', 'vacate'));
    final dates = leaveDates(s.stayHostel.terms);
    for (final d in dates) {
      expect(find.byKey(ValueKey('vDate-$d')), findsOneWidget);
    }
    expect(find.text('earliest'), findsOneWidget);
    expect(s.vReason, isNull);
    await _tap(tester, find.text('Moving home'));
    expect(s.vReason, 'Moving home');
    await _tap(tester, find.text('Moving home'));
    expect(s.vReason, isNull);
    await _tap(tester, find.byKey(ValueKey('vDate-${dates[1]}')));
    expect(s.vDate, dates[1]);
    await _tap(tester, find.text('Give notice for'));
    expect(s.notice, isTrue);
    expect(find.text('Your last day is ${dates[1]}.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // Move to another bed: rent difference from my rent, then "Ask to move to …".
    s.back();
    await tester.pump();
    await _tap(tester, find.text('Move to another bed'));
    expect((s.screen, s.moveTab), ('move', 'swap'));
    expect(find.text('New rent starts next month. Srinivas confirms the move.'), findsOneWidget);
    expect(find.text('Pick a bed to move to'), findsOneWidget);
    final free = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free' && !b.mine && b.id != '204-B');
    await _tap(tester, find.byKey(ValueKey('swap-${free.id}')));
    await _tap(tester, find.text('Ask to move to ${free.id}'));
    expect(s.swapSent, isTrue);
    s.dispose();
  });

  testWidgets('F22 Area 2: reviews are star rows and an optional line; the exit review asks about the advance first', (tester) async {
    final s = AppState(start: 'rReview', role: 'resident');
    s.myName = 'Rahul Varma';
    await _pump(tester, s);
    expect(find.text('How is your stay?'), findsOneWidget);
    for (final c in reviewCats) {
      expect(find.bySemanticsLabel('$c 5 stars'), findsOneWidget, reason: c);
    }
    await _tap(tester, find.bySemanticsLabel('Food 5 stars'));
    await _tap(tester, find.bySemanticsLabel('Owner 3 stars'));
    expect(s.rvStars, 4); // overall = the average of the rows
    await _tap(tester, find.text('Post review'));
    expect(s.reviews.first.stars, 4);
    s.dispose();

    final e = AppState(start: 'rExit', role: 'resident');
    await _pump(tester, e);
    expect(find.text('Did you get your ₹2,000 back?'), findsOneWidget);
    await _tap(tester, find.text('Post review'));
    expect(e.toast, 'Tell us if you got your advance back.');
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.byKey(const ValueKey('exAdv-all')));
    await _tap(tester, find.bySemanticsLabel('Overall 4 stars'));
    await tester.enterText(find.byType(EditableText).first, 'Got it back in 5 days.');
    await tester.pump();
    await _tap(tester, find.text('Post review'));
    final r = e.reviews.first;
    expect((r.kind, r.advance, r.stars, r.text), ('exit', 'all', 4, 'Got it back in 5 days.'));
    e.dispose();
  });

  testWidgets('F22 Area 2: Stay Rewards: one dark card, three steps, Invite a friend', (tester) async {
    final s = AppState(start: 'rewards', role: 'tenant');
    await _pump(tester, s);
    expect(find.text('NOT A MEMBER YET'), findsOneWidget);
    expect(find.text('HOW TO EARN'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('earn-$i')), findsOneWidget);
    }
    s.update(() => s.becomeMember('Anjani Residency'));
    await tester.pump();
    expect(find.text('MEMBER'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);
    expect(find.textContaining('2-hour holds'), findsWidgets);
    await _tap(tester, find.text('Invite a friend'));
    expect(s.lastShare, contains(s.referralCode));
    s.dispose();
  });

  for (final c in const ['rPay', 'rHome', 'rStay', 'move', 'rReview', 'rExit', 'rewards']) {
    testWidgets('F22 Area 2: $c fits at 2× text', (tester) async {
      final s = AppState(start: c, role: 'resident');
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
