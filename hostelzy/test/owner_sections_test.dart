import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/owner/owner_today_screen.dart' show countBeds, occupancy;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F25 A6, A7, A8 (hub decision): sections inside existing screens, no new
// screens. A6: owner Today's "This month" card gets "N% full" and a bar
// (beds with a resident ÷ all beds; holds don't count). A7: Your plan lists
// the three plans from `planTiers`, the owner's marked "Yours". A8: Your plan
// lists this hostel's past invoices with Paid / Checking / Not paid.

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

Future<void> _see(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
}

void main() {
  mapTiles = false;

  testWidgets('F25 A6: owner Today shows how full the hostel is; holds are not full', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, s);
    final c = countBeds(s);
    final full = c.booked + c.soon;
    final pct = (full * 100 / c.t).round();
    expect(c.held, greaterThan(0)); // Anjani has holds: they must not count
    expect(occupancy(s)!.pct, pct);
    await _see(tester, find.byKey(const ValueKey('occupancy')));
    expect(find.text('$pct% full'), findsOneWidget);
    expect(find.text('$full of ${c.t} beds have a resident. Holds don’t count.'), findsOneWidget);
    // The bar is the same share of its width.
    final bar = tester.getSize(find.byKey(const ValueKey('occBar'))).width - 2; // 1px border each side
    final fill = tester.getSize(find.byKey(const ValueKey('occBarFill'))).width;
    expect(fill / bar, closeTo(full / c.t, .01));

    // A hold confirmed into a move-in: one more bed with a resident.
    final held = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'held');
    s.update(() => held.state = 'booked');
    await tester.pump();
    expect(find.text('${((full + 1) * 100 / c.t).round()}% full'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F25 A6: no beds yet → no occupancy line', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    s.layouts; // seeded from the sample rooms first, as a live owner's would be loaded
    s.rooms['anjani'] = [];
    await _pump(tester, s);
    expect(occupancy(s), isNull);
    expect(find.byKey(const ValueKey('occupancy')), findsNothing);
    expect(find.textContaining('% full'), findsNothing);
    s.dispose();
  });

  testWidgets('F25 A7: Your plan lists the three plans from planTiers, yours marked by real bed count', (tester) async {
    final s = AppState(start: 'oPlan', role: 'owner');
    await _pump(tester, s);
    await _see(tester, find.byKey(const ValueKey('allPlans')));
    expect(find.text('ALL PLANS'), findsOneWidget);
    for (final (n, t) in planTiers.indexed) {
      expect(find.byKey(ValueKey('planTier-$n')), findsOneWidget);
      expect(find.text(t.label), findsOneWidget);
      expect(find.text('${fmt(t.price)} a month'), findsOneWidget);
    }
    expect(find.text('Plus a featured spot in your area'), findsOneWidget);
    expect(find.text('Everything below'), findsNothing);
    final mine = planTierOf(s.planBeds);
    expect(find.byKey(ValueKey('planYours-$mine')), findsOneWidget);
    expect(find.text('YOURS'), findsOneWidget);

    // The tier follows the real bed count: fewer beds, then many more.
    final all = s.rooms['anjani']!;
    final small = <Room>[];
    for (final r in all) {
      if (small.fold<int>(0, (a, x) => a + x.beds.length) + r.beds.length > 30) break;
      small.add(r);
    }
    s.update(() => s.rooms['anjani'] = small);
    await tester.pump();
    expect(planTierOf(s.planBeds), 0);
    expect(find.byKey(const ValueKey('planYours-0')), findsOneWidget);
    s.update(() => s.rooms['anjani'] = [...all, ...all, ...all]);
    await tester.pump();
    expect(s.planBeds, greaterThan(featuredBeds));
    expect(find.byKey(const ValueKey('planYours-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('planYours-0')), findsNothing);
    expect(find.text('YOURS'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F25 A8: Past invoices: empty state, then this hostel’s invoices newest first with honest words', (tester) async {
    final s = AppState(start: 'oPlan', role: 'owner', plan: 'paid');
    await _pump(tester, s);
    await _see(tester, find.byKey(const ValueKey('pastInvoices')));
    expect(find.text('PAST INVOICES'), findsOneWidget);
    expect(find.text('No past invoices yet.'), findsOneWidget);
    expect(find.text('Free trial'), findsOneWidget);
    // Other hostels' invoices (the team's list) never show here.
    expect(find.byKey(const ValueKey('pastInvoice-HZ-INV-0990')), findsNothing);

    s.update(() {
      s.invoices.addAll([
        Invoice(ref: 'HZ-INV-0901', hid: 'anjani', beds: 24, amt: 499, due: DateTime(2026, 7, 31), status: 'paid', utr: '401900000001', checked: '1 Aug'),
        Invoice(ref: 'HZ-INV-0950', hid: 'anjani', beds: 24, amt: 399, due: DateTime(2026, 9), status: 'checking', utr: '401900000002'),
        Invoice(ref: 'HZ-INV-0920', hid: 'anjani', beds: 24, amt: 499, due: DateTime(2026, 8), status: 'missing', utr: '401900000003'),
        Invoice(ref: 'HZ-INV-0899', hid: 'anjani', beds: 24, amt: 499, due: DateTime(2026, 7), status: 'due', late: 20),
      ]);
    });
    await tester.pump();
    expect(find.text('No past invoices yet.'), findsNothing);
    expect(s.pastInvoices.map((i) => i.ref), ['HZ-INV-0950', 'HZ-INV-0920', 'HZ-INV-0901', 'HZ-INV-0899']);
    expect(s.pastInvoices, isNot(contains(s.invoice)));
    Finder inRow(String ref, String text) => find.descendant(of: find.byKey(ValueKey('pastInvoice-$ref')), matching: find.text(text));
    expect(inRow('HZ-INV-0950', 'September 2026'), findsOneWidget);
    expect(inRow('HZ-INV-0950', 'HZ-INV-0950 · ₹399'), findsOneWidget);
    expect(inRow('HZ-INV-0950', 'CHECKING'), findsOneWidget);
    expect(inRow('HZ-INV-0920', 'NOT PAID'), findsOneWidget);
    expect(inRow('HZ-INV-0901', 'PAID'), findsOneWidget);
    expect(inRow('HZ-INV-0899', 'NOT PAID'), findsOneWidget);
    // The rows sit in that order on screen.
    final ys = [for (final r in ['0950', '0920', '0901', '0899']) tester.getTopLeft(find.byKey(ValueKey('pastInvoice-HZ-INV-$r'))).dy];
    expect(ys, [...ys]..sort());
    s.dispose();
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('F25 A6–A8: 360 px, 2× text, $theme: no overflow', (tester) async {
      final t = AppState(start: 'oToday', role: 'owner', theme: theme);
      await _pump(tester, t, scale: 2, width: 360);
      await _see(tester, find.byKey(const ValueKey('occBar')));
      expect(tester.takeException(), isNull);
      t.dispose();

      final s = AppState(start: 'oPlan', role: 'owner', theme: theme, plan: 'paid');
      s.invoices.add(Invoice(ref: 'HZ-INV-0950', hid: 'anjani', beds: 24, amt: 1499, due: DateTime(2026, 9), status: 'checking'));
      await _pump(tester, s, scale: 2, width: 360);
      await _see(tester, find.byKey(const ValueKey('pastInvoice-HZ-INV-0950')));
      await _see(tester, find.byKey(const ValueKey('planTier-2')));
      expect(find.byKey(ValueKey('planYours-${planTierOf(s.planBeds)}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
