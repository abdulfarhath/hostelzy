import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show filtered, sortLabels;
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/locate.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';

// F26 (founder review, rounds 1–3), tenant Explore + hostel page:
// #1 📍 inside the search field · #2 one row Near me ✓ · Price ↑ ▾ · Filters · n,
// one Featured pinned on top · #3 the building inline (80+ beds: See all N rooms ›)
// · #4 the whole week's food table · #5 ✓ VERIFIED only after a team visit · #6 no tag boxes.

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

class _Locator implements Locator {
  _Locator(this.pos);
  final (double, double)? pos;
  @override
  Future<((double, double)?, LocateFail?)> locate({bool exact = false}) async => (pos, pos == null ? LocateFail.denied : null);
}

/// 6 floors × 6 rooms × 3 beds = 108 beds (an 80+ bed hostel).
List<Room> _bigHostel() => [
  for (var f = 1; f <= 6; f++)
    for (var i = 1; i <= 6; i++)
      Room(
        n: f * 100 + i,
        floor: f,
        share: 3,
        rent: 6800,
        bath: 'Shared',
        beds: [for (final l in ['A', 'B', 'C']) Bed(id: '${f * 100 + i}-$l', letter: l, room: f * 100 + i, floor: f, spot: 'Window', state: l == 'A' ? 'free' : 'booked', soon: '')],
      ),
];

void main() {
  mapTiles = false;

  testWidgets('F26 #1 #2: the pin in the search field, Near me, the sort dropdown and Filters · n', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.locator = _Locator((17.4483, 78.3915));
    await _pump(tester, s);
    // One row: Near me · Price ↑ · Filters. Men / Women / Co-living / AC aren't on Explore.
    expect(find.byKey(const ValueKey('wherePin')), findsOneWidget);
    expect(find.byKey(const ValueKey('nearMeChip')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('sortBtn')), matching: find.text('Price ↑')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('filtersBtn')), matching: find.text('Filters')), findsOneWidget);
    for (final x in ['Men', 'Women', 'Co-living', 'AC', 'Under ₹8,000', 'Hostelzy deals']) {
      expect(find.text(x), findsNothing, reason: x);
    }
    expect(s.sortBy, 'price');

    // #1: the pin → the map, with the location explainer first.
    await _tap(tester, find.byKey(const ValueKey('wherePin')));
    expect((s.screen, s.sheet), ('map', 'loc'));
    s.tab('explore');
    await tester.pump();

    // #2: Near me (off) → the explainer; Allow → on, with ✓; the sort stays Price ↑.
    await _tap(tester, find.byKey(const ValueKey('nearMeChip')));
    expect((s.screen, s.sheet), ('explore', 'loc'));
    await _tap(tester, find.text('Allow location'));
    await tester.pump();
    expect((s.myPos, s.sortBy, s.screen), ((17.4483, 78.3915), 'price', 'explore'));
    await tester.pump(const Duration(seconds: 3));
    // Near me tapped again → Pick a place (the Where? field).
    await _tap(tester, find.byKey(const ValueKey('nearMeChip')));
    expect(s.screen, 'where');
    s.back();
    await tester.pump();
    // The pin with location on: straight to the map, no explainer.
    await _tap(tester, find.byKey(const ValueKey('wherePin')));
    expect((s.screen, s.sheet), ('map', null));
    s.tab('explore');
    await tester.pump();

    // The sort dropdown: Price ↑ · Distance · Rating · Best deals.
    await _tap(tester, find.byKey(const ValueKey('sortBtn')));
    expect(s.sheet, 'sort');
    for (final l in sortLabels.values) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    await _tap(tester, find.byKey(const ValueKey('sort-rating')));
    expect((s.sortBy, s.sheet), ('rating', null));
    expect(find.descendant(of: find.byKey(const ValueKey('sortBtn')), matching: find.text('Rating')), findsOneWidget);
    final rated = filtered(s).where((h) => h.reviews > 0).map((h) => h.rating).toList();
    for (var i = 1; i < rated.length; i++) {
      expect(rated[i - 1] >= rated[i], isTrue);
    }
    s.update(() => s.sortBy = 'near');
    // F26 #21 (integration): nearest first within each tier; listed (UNVERIFIED) after every verified hostel.
    final near = filtered(s);
    expect(near.skipWhile((h) => !h.listed).every((h) => h.listed), isTrue);
    for (final tier in [near.where((h) => !h.listed), near.where((h) => h.listed)]) {
      final km = tier.map(s.kmFor).toList();
      for (var i = 1; i < km.length; i++) {
        expect(km[i - 1] <= km[i], isTrue);
      }
    }
    s.update(() => s.sortBy = 'price');
    await tester.pump();
    expect(find.text('Lowest price'), findsOneWidget);

    // Filters: Who / Room / Food / Rent inside the sheet; the count on the button.
    await _tap(tester, find.byKey(const ValueKey('filtersBtn')));
    expect(s.sheet, 'search');
    await _tap(tester, find.byKey(const ValueKey('fG-Women')));
    await _tap(tester, find.byKey(const ValueKey('noFood')));
    expect((s.fG, s.fNoFood, s.filterCount), ('Women', true, 2));
    expect(filtered(s).every((h) => h.gender == 'Women' && !h.food), isTrue);
    await _tap(tester, find.byKey(const ValueKey('foodToggle')));
    expect((s.fFood, s.fNoFood), (true, false));
    await _tap(tester, find.textContaining('Show '));
    expect(find.descendant(of: find.byKey(const ValueKey('filtersBtn')), matching: find.text('Filters · 2')), findsOneWidget);
    s.clearFilters();
    s.dispose();
  });

  testWidgets('F26 #2: one featured (80+ bed) hostel pinned on top, tagged Featured, then the sort', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    final plain = filtered(s).map((h) => h.id).toList();
    final last = plain.last;
    s.flags = {for (final id in plain.take(2)) id: (beds: 0, featured: false, dealsPaused: false), last: (beds: 96, featured: true, dealsPaused: false)};
    await _pump(tester, s);
    final ids = filtered(s).map((h) => h.id).toList();
    expect(ids, [last, ...plain.where((id) => id != last)]);
    expect(find.byKey(ValueKey('featured-$last')), findsOneWidget);
    expect(find.text('FEATURED'), findsOneWidget);
    expect(find.text('THEN BY PRICE, LOWEST FIRST'), findsOneWidget);
    // Only one is pinned, even with two featured hostels.
    final other = plain.first;
    s.update(() => s.flags = {...s.flags, other: (beds: 90, featured: true, dealsPaused: false)});
    await tester.pump();
    expect(find.textContaining('FEATURED'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F26 #3 #5 #6: hostel page: ✓ VERIFIED only after a visit, no tag boxes, building inline', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    final h = hostelById('anjani');
    expect(find.byKey(const ValueKey('verifiedBadge')), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Beds and prices checked by Hostelzy · ${s.visited['anjani']}'), findsOneWidget);
    expect(find.textContaining('Visited by Hostelzy'), findsNothing);
    // The badge is navy, white text.
    final badge = tester.widget<Container>(find.byKey(const ValueKey('verifiedBadge')));
    expect(badge.color, Pal.light.vf);
    expect(Pal.light.vf, const Color(0xFF1F3A5F));
    expect(Pal.dark.vf, const Color(0xFF33598A));
    // #6: the tag boxes are gone.
    for (final t in h.tags) {
      expect(find.text(t), findsNothing, reason: t);
    }
    // #3: the building inline, no "On each floor" list, no "See the whole building" link.
    expect(find.byKey(const ValueKey('inlineBuilding')), findsOneWidget);
    expect(find.byKey(const ValueKey('onEachFloor')), findsNothing);
    expect(find.byKey(const ValueKey('seeBuilding')), findsNothing);

    // A hostel the team hasn't visited: no badge, no line.
    final notVisited = hostels.firstWhere((x) => s.visited[x.id] == null && s.rooms[x.id]!.isNotEmpty);
    s.update(() => s.hid = notVisited.id);
    await tester.pump();
    expect(find.byKey(const ValueKey('verifiedBadge')), findsNothing);
    expect(find.byKey(const ValueKey('verifiedLine')), findsNothing);
    s.dispose();
  });

  testWidgets('F26 #3: an 80+ bed hostel collapses to See all N rooms › (its own page)', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    s.rooms['anjani'] = _bigHostel();
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('inlineBuilding')), findsNothing);
    expect(find.text('See all 36 rooms ›'), findsOneWidget);
    expect(find.text('108 beds on 6 floors · 36 free'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('seeAllRooms')));
    expect(s.screen, 'building');
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    expect(find.text('ALL 36 ROOMS'), findsOneWidget);
    // A free bed opens the picker on it; back returns to the building page.
    await _tap(tester, find.byKey(const ValueKey('bBed-601-A')));
    expect((s.screen, s.bed), ('picker', '601-A'));
    s.back();
    await tester.pump();
    expect(s.screen, 'building');
    s.back();
    await tester.pump();
    expect(s.screen, 'detail');
    resetSampleData();
    s.dispose();
  });

  for (final dark in [false, true]) {
    for (final c in const ['explore', 'detail', 'building', 'sort']) {
      testWidgets('F26 tenant: $c fits at 360 px and 2× text (${dark ? 'dark' : 'light'})', (tester) async {
        final s = AppState(start: c == 'sort' ? 'explore' : c, role: 'tenant');
        s.hid = 'anjani';
        s.theme = dark ? 'dark' : 'light';
        if (c == 'sort') s.sheet = 'sort';
        await _pump(tester, s, scale: 2, width: 360);
        expect(tester.takeException(), isNull);
        s.dispose();
      });
    }
  }
}
