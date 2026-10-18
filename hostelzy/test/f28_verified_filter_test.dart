import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show cheapestRent, filtered, pinnedFeatured, sortLabels;
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F28 Part 1 (wave 1): the "Verified only" switch in Filters (H1); verified
// cards first, then UNVERIFIED, in every sort (S8); the map pins obey it (S9).

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

  testWidgets('F28 Part 1: Verified only under Food included, off by default, counted, hides UNVERIFIED, header unchanged, Clear all resets it', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('listedCard-balaji')), findsOneWidget);
    expect(find.textContaining('6 VERIFIED · 1 LISTED'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('filtersBtn')));
    expect(find.text('Verified only'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('verifiedToggle'))).dy > tester.getTopLeft(find.byKey(const ValueKey('foodToggle'))).dy, isTrue);
    expect((s.fVerified, s.filterCount), (false, 0));
    final all = filtered(s).length;
    await _tap(tester, find.byKey(const ValueKey('verifiedToggle')));
    expect((s.fVerified, s.filterCount), (true, 1));
    expect(filtered(s).length, all - 1);
    expect(filtered(s).any((h) => h.listed), isFalse);
    expect(find.text('Show ${all - 1} hostels'), findsOneWidget);
    expect(find.text('Filters · 1'), findsWidgets);
    await _tap(tester, find.textContaining('Show '));
    expect(s.sheet, isNull);
    expect(find.descendant(of: find.byKey(const ValueKey('filtersBtn')), matching: find.text('Filters · 1')), findsOneWidget);
    expect(find.byKey(const ValueKey('listedCard-balaji')), findsNothing);
    expect(find.textContaining('6 VERIFIED · 1 LISTED'), findsOneWidget);
    // Clear all resets it with the others.
    await _tap(tester, find.byKey(const ValueKey('filtersBtn')));
    await _tap(tester, find.byKey(const ValueKey('clearAll')));
    expect((s.fVerified, s.filterCount), (false, 0));
    expect(filtered(s).length, all);
    s.dispose();
  });

  test('F28 Part 1: verified first, then UNVERIFIED, in every sort', () {
    final s = AppState(start: 'explore', role: 'tenant');
    for (final sort in sortLabels.keys) {
      s.update(() => s.sortBy = sort);
      final hs = filtered(s);
      expect(hs.any((h) => h.listed), isTrue, reason: sort);
      expect(hs.skipWhile((h) => !h.listed).every((h) => h.listed), isTrue, reason: sort);
      expect(hs.last.id, 'balaji', reason: sort);
      final pin = pinnedFeatured(s, hs);
      final v = [for (final h in hs) if (!h.listed && h != pin) h];
      switch (sort) {
        case 'price':
          final p = v.map((h) => cheapestRent(s, h)).toList();
          expect(p, [...p]..sort(), reason: sort);
          // Dearer verified hostels come before the ₹7,000 listed one: no band interleave.
          expect(p.any((x) => x > 9000), isTrue);
        case 'near':
          final km = v.map(s.kmFor).toList();
          expect(km, [...km]..sort(), reason: sort);
        case 'rating':
          final r = v.map((h) => h.reviews == 0 ? -1.0 : h.rating).toList();
          expect(r, [...r]..sort((a, b) => b.compareTo(a)), reason: sort);
        default:
          break;
      }
    }
    s.dispose();
  });

  testWidgets('F28 Part 1: the map pins obey Verified only', (tester) async {
    final s = AppState(start: 'map', role: 'tenant');
    s.update(() => s.mapArea = 'Madhapur');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('pin-anjani')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-balaji')), findsOneWidget);
    s.update(() => s.fVerified = true);
    await tester.pump();
    expect(find.byKey(const ValueKey('pin-anjani')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-balaji')), findsNothing);
    s.dispose();
  });
}
