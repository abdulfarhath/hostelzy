import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/reminders.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';

// F27 Save food: the resident's next-meal card (Eating / Skip) above the week
// table, Plan your meals, the owner's headcount on Today and the Meals page,
// the meal ask push with Eating / Skip, plates saved on Stay Rewards and the
// hostel page chip. Tests run at 2:30 pm on Thu 1 Oct 2026 (the sample day).

final _live = <AppState>[];

/// Stops every state's timers (toasts, the hold clock) at the end of a test.
void _done() {
  for (final s in _live) {
    s.dispose();
  }
  _live.clear();
}

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1}) async {
  _live.add(state);
  await tester.runAsync(() async {
    final l = FontLoader('Archivo');
    for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  });
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shell = AppScope(state: state, child: const HostelzyShell());
  await tester.pumpWidget(
    MaterialApp(
      home: scale == 1
          ? shell
          : MediaQuery(
              data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(scale)),
              child: shell,
            ),
    ),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

String _text(WidgetTester tester, Key k) => tester.widget<T>(find.byKey(k)).text;

/// The server after FOUNDER-TODO 4zf27 (or before it: [board] null).
class _Server extends SampleRepo {
  _Server({this.board});
  FoodBoard? board;
  final answers = <Map<String, bool>>[];
  final cutoffs = <int>[];
  Map<String, int> plates = {};
  bool closed = false;
  @override
  bool get remote => true;
  @override
  Future<FoodBoard?> foodBoard(String hid, DateTime from, int days) async => board;
  @override
  Future<void> answerMeals(String hid, Map<String, bool> a) async {
    if (closed) throw Exception('the count for that meal has closed');
    answers.add(a);
    board = board?.answer(a);
  }

  @override
  Future<void> setMealCutoff(String hid, int hours) async => cutoffs.add(hours);
  @override
  Future<Map<String, int>> hostelPlates(List<String> hids) async => plates;
}

void main() {
  mapTiles = false;
  final today = DateTime(2026, 10);

  testWidgets('F27-1: next meal card above the week table; Eating / Skip; closes at; you saved', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('nextMeal')), findsOneWidget);
    // 2:30 pm: breakfast and lunch have closed; dinner at 8 closes at 5 (3 h).
    expect(_text(tester, const ValueKey('nextMealTitle')), 'Dinner · 8:00 pm');
    expect(find.text('Chapati, chana masala'), findsWidgets);
    expect(_text(tester, const ValueKey('nextMealCloses')), 'Closes at 5:00 pm · 34 eating so far');
    expect(find.text('You saved 3 plates this week'), findsOneWidget);
    // The card sits above the week table (F26's table stays on Home).
    expect(tester.getTopLeft(find.byKey(const ValueKey('nextMeal'))).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('homeWeek'))).dy));
    expect(s.eatingAt('anjani', today, 'n'), isTrue);

    await _tap(tester, find.byKey(const ValueKey('skipBtn')));
    expect(s.eatingAt('anjani', today, 'n'), isFalse);
    expect(s.toast, 'Dinner skipped. The kitchen cooks one plate less.');
    expect(_text(tester, const ValueKey('nextMealCloses')), 'Closes at 5:00 pm · 33 eating so far');
    await _tap(tester, find.byKey(const ValueKey('eatBtn')));
    expect(s.eatingAt('anjani', today, 'n'), isTrue);
    expect(_text(tester, const ValueKey('nextMealCloses')), 'Closes at 5:00 pm · 34 eating so far');

    // After 5 pm dinner is locked: the card moves on to tomorrow's breakfast.
    s.update(() => s.foodClock = DateTime(2026, 10, 1, 17, 5));
    await tester.pump();
    expect(_text(tester, const ValueKey('nextMealTitle')), 'Breakfast · tomorrow · 7:30 am');
    expect(_text(tester, const ValueKey('nextMealCloses')), startsWith('Closes at 4:30 am'));
    await s.setEating('anjani', today, 'n', false);
    expect(s.eatingAt('anjani', today, 'n'), isTrue);
    expect(s.toast, 'The count for that meal has closed. Your answer counts from the next meal.');
    _done();
  });

  testWidgets('F27-2 (S90): Plan your meals: 7 days from today, toggle, locked meals, Skip all weekend', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('planWeek')));
    expect(s.screen, 'rMeals');
    expect(find.text('Plan your meals'), findsOneWidget);
    expect(find.text('Thu · today'), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      for (final k in ['b', 'l', 'n']) {
        expect(find.byKey(ValueKey('plan-$i-$k')), findsOneWidget);
      }
    }
    // Sample: the weekend, Tuesday dinner and Wednesday lunch are skips.
    expect(find.text('This week you’re saving 8 plates'), findsOneWidget);
    expect(find.text('Each meal closes 3 h before it is served. A skip after that counts from the next meal.'), findsOneWidget);

    // Today's breakfast closed at 4:30 am: locked.
    await _tap(tester, find.byKey(const ValueKey('plan-0-b')));
    expect(s.eatingAt('anjani', today, 'b'), isTrue);
    expect(s.toast, 'The count for breakfast on Thu has closed.');
    // Friday breakfast: tap to skip, tap again to eat.
    final fri = DateTime(2026, 10, 2);
    await _tap(tester, find.byKey(const ValueKey('plan-1-b')));
    expect(s.eatingAt('anjani', fri, 'b'), isFalse);
    expect(find.text('This week you’re saving 9 plates'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('plan-1-b')));
    expect(s.eatingAt('anjani', fri, 'b'), isTrue);

    // The weekend is already skipped: the button eats it again, then skips it.
    expect(find.text('Eat all weekend'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('skipWeekend')));
    expect(s.eatingAt('anjani', DateTime(2026, 10, 3), 'l'), isTrue);
    expect(find.text('This week you’re saving 2 plates'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('skipWeekend')));
    expect(s.toast, 'Weekend skipped: 6 meals. The kitchen cooks for the rest.');
    expect(s.eatingAt('anjani', DateTime(2026, 10, 4), 'n'), isFalse);
    s.back();
    await tester.pump();
    expect(s.screen, 'rHome');
    _done();
  });

  testWidgets('F27-3 + F27-4 (S91): owner headcount under the Fair Play pin; Meals with skippers, 7 days, cut-off 2/3/4 h', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, s);
    final card = find.byKey(const ValueKey('headcountCard'));
    expect(card, findsOneWidget);
    expect(find.text('DINNER TONIGHT'), findsOneWidget);
    expect(find.text('Closes 5:00 pm'), findsOneWidget);
    expect(_text(tester, const ValueKey('headcount')), '34 of 40 eating');
    expect(find.text('6 skipping · cook for 34'), findsOneWidget);
    // Above the Today groups.
    expect(tester.getTopLeft(card).dy, lessThan(tester.getTopLeft(find.text('Holds').first).dy));

    await _tap(tester, card);
    expect(s.screen, 'oMeals');
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('TODAY · OF 40 RESIDENTS'), findsOneWidget);
    expect(find.text('Closed 4:30 am'), findsOneWidget);
    expect(find.text('Open · closes 5:00 pm'), findsOneWidget);
    expect(find.text('WHO’S SKIPPING DINNER · 6'), findsOneWidget);
    expect(_text(tester, const ValueKey('skippers')), startsWith('Arjun R. 204-A · Sai K. 204-C'));
    expect(find.byKey(const ValueKey('mealWeek')), findsOneWidget);

    await _tap(tester, find.text('4 h'));
    expect(s.foodOf('anjani')!.cutoff, 4);
    expect(s.toast, 'The count now closes 4 h before each meal. Residents see the new time.');
    expect(find.text('Open · closes 4:00 pm'), findsOneWidget);

    // From Manage too.
    s.tab('oMore');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('manage-Meals')));
    expect(s.screen, 'oMeals');
    _done();
  });

  testWidgets('F27 on the server: answers saved, a closed meal rolls back, cut-off saved; before 4zf27 nothing shows', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    final srv = _Server(board: FoodBoard(counts: {mealKey(today, 'n'): (12, 2)}));
    s.data = srv;
    await _pump(tester, s);
    await s.loadFood('anjani');
    await tester.pump();
    expect(_text(tester, const ValueKey('nextMealCloses')), 'Closes at 5:00 pm · 10 eating so far');
    // No fake "you saved" before anything was saved.
    expect(find.byKey(const ValueKey('savedWeek')), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('skipBtn')));
    await tester.pump();
    expect(srv.answers.single, {mealKey(today, 'n'): false});
    expect(s.eatingAt('anjani', today, 'n'), isFalse);

    // The server says the count closed meanwhile: back as it was, said plainly.
    srv.closed = true;
    await _tap(tester, find.byKey(const ValueKey('eatBtn')));
    await tester.pump();
    expect(s.eatingAt('anjani', today, 'n'), isFalse);
    expect(s.toast, 'The count for that meal has closed. Your answer counts from the next meal.');

    // Before the SQL runs: no card, no Meals row, no chip.
    srv.board = null;
    await s.loadFood('anjani');
    await tester.pump();
    expect(find.byKey(const ValueKey('nextMeal')), findsNothing);
    expect(find.text('FOOD THIS WEEK'), findsOneWidget);

    final o = AppState(start: 'oMore', role: 'owner');
    o.data = _Server();
    await _pump(tester, o);
    await o.loadFood('anjani');
    await tester.pump();
    expect(find.byKey(const ValueKey('manage-Meals')), findsNothing);
    o.tab('oToday');
    await tester.pump();
    expect(find.byKey(const ValueKey('headcountCard')), findsNothing);

    final c = AppState(start: 'oMeals', role: 'owner');
    final cs = _Server(board: const FoodBoard());
    c.data = cs;
    await _pump(tester, c);
    await c.loadFood('anjani');
    await tester.pump();
    await _tap(tester, find.text('2 h'));
    await tester.pump();
    expect(cs.cutoffs, [2]);
    _done();
  });

  testWidgets('F27-5: the meal ask push: Eating / Skip from the notification', (tester) async {
    final d = {'ask': 'food', 'kind': 'food', 'title': 'Dinner at 8 · Eating?', 'body': 'Chapati, dal. Tap Skip if you won’t be here. Closes at 5:00 pm.', 'hostel': 'anjani', 'day': '2026-10-01', 'meal': 'n'};
    final a = FoodAsk.fromData(d)!;
    expect(a.payload, 'food|anjani|2026-10-01|n');
    expect(a.id, 6002);
    expect(FoodAsk.fromData({...d, 'ask': ''}), isNull);
    expect(FoodAsk.fromData({...d, 'meal': 'x'}), isNull);
    expect(tapArg(a.payload, 'skip'), 'food|anjani|2026-10-01|n|skip');
    expect(tapArg(a.payload, null), 'food|anjani|2026-10-01|n|open');
    expect(tapArg('meal|Lunch|x', 'open'), 'meal');
    expect(parseFoodTap('food|anjani|2026-10-01|n|skip'), (hid: 'anjani', day: '2026-10-01', meal: 'n', action: 'skip'));
    expect(parseFoodTap('meal'), isNull);

    final s = AppState(start: 'rPay', role: 'resident');
    s.signedIn = true;
    await _pump(tester, s);
    await s.openFoodTap(parseFoodTap('food|anjani|2026-10-01|n|skip')!);
    await tester.pump();
    expect(s.screen, 'rHome');
    expect(s.eatingAt('anjani', today, 'n'), isFalse);
    expect(s.toast, 'Dinner skipped. The kitchen cooks one plate less.');
    await s.openFoodTap(parseFoodTap('food|anjani|2026-10-01|n|eat')!);
    expect(s.eatingAt('anjani', today, 'n'), isTrue);
    // A tap on the notification itself just opens Home.
    s.tab('rPay');
    await s.openFoodTap(parseFoodTap('food|anjani|2026-10-01|n|open')!);
    expect(s.screen, 'rHome');
    expect(s.eatingAt('anjani', today, 'n'), isTrue);
    _done();
  });

  testWidgets('F27-6 + F27-7: plates saved on Stay Rewards; Cooks to count on the hostel page only with real numbers', (tester) async {
    final s = AppState(start: 'rewards', role: 'resident');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('platesSaved')), findsOneWidget);
    expect(find.text('23 plates'), findsOneWidget);
    expect(find.text('Anjani Residency saved'), findsOneWidget);
    expect(find.text('9,870'), findsOneWidget);
    expect(find.text('1 skip = 1 plate the kitchen didn’t cook. No ranking of people: nobody is judged for eating.'), findsOneWidget);
    // Green only on the numbers.
    final p = PalScope.of(tester.element(find.byKey(const ValueKey('platesSaved'))));
    expect(tester.widget<Container>(find.byKey(const ValueKey('platesSaved'))).color, p.gb);

    // A tenant doesn't get the card.
    final t = AppState(start: 'rewards', role: 'tenant');
    await _pump(tester, t);
    expect(find.byKey(const ValueKey('platesSaved')), findsNothing);

    final h = AppState(start: 'detail', role: 'tenant');
    h.hid = 'anjani';
    await _pump(tester, h);
    await tester.ensureVisible(find.byKey(const ValueKey('foodWeekSection')));
    expect(find.text('Cooks to count · 412 plates saved'), findsOneWidget);
    // On the server: only the real number; none yet = no chip.
    h.data = _Server();
    await h.loadPlates('anjani');
    await tester.pump();
    expect(find.byKey(const ValueKey('cooksToCount')), findsNothing);
    final srv = _Server()..plates = {'anjani': 17};
    h.data = srv;
    await h.loadPlates('anjani');
    await tester.pump();
    expect(find.text('Cooks to count · 17 plates saved'), findsOneWidget);
    _done();
  });

  testWidgets('F27: Settings › Meals switch for residents and owners, not tenants', (tester) async {
    final s = AppState(start: 'settings', role: 'resident');
    await _pump(tester, s);
    expect(find.text('Meals'), findsOneWidget);
    expect(s.notif['food'], isTrue);
    final t = AppState(start: 'settings', role: 'tenant');
    await _pump(tester, t);
    expect(find.text('Meals'), findsNothing);
    _done();
  });

  testWidgets('F27: dark and 2× text at 360 px', (tester) async {
    for (final (start, role) in [('rHome', 'resident'), ('rMeals', 'resident'), ('oToday', 'owner'), ('oMeals', 'owner'), ('rewards', 'resident')]) {
      final s = AppState(start: start, role: role, theme: 'dark');
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull, reason: start);
    }
    _done();
  });
}
