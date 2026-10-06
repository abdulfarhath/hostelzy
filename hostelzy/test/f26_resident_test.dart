import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F26 (resident): the tab bar Home · Rent · My stay · Find a bed · Me; Find a
// bed is the tenant app with Saved & Holds and a way back; the red dot on
// Holds when a hold was kept or declined; tenants keep their five tabs.

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1}) async {
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

List<String> _tabKeys(WidgetTester tester) => [for (final e in tester.widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('tab-')))) (e.key! as ValueKey<String>).value.substring(4)];

void main() {
  mapTiles = false;

  testWidgets('F26 #13 #14 #15 #17: resident tabs; Find a bed is the tenant app; a resident can hold a bed elsewhere; My stay goes back', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    expect(_tabKeys(tester), ['rHome', 'rPay', 'rStay', '+find', 'me']);
    for (final l in ['Home', 'Rent', 'My stay', 'Find a bed', 'Me']) {
      expect(
        find.descendant(of: find.byKey(ValueKey('tab-${const {'Home': 'rHome', 'Rent': 'rPay', 'My stay': 'rStay', 'Find a bed': '+find', 'Me': 'me'}[l]}')), matching: find.text(l)),
        findsOneWidget,
        reason: l,
      );
    }
    // Home keeps its red Pay button; Rent is a plain tab.
    expect(find.text('Pay'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('tab-rPay')));
    expect(s.screen, 'rPay');

    // Find a bed: the tenant screens with Saved & Holds and My stay.
    await _tap(tester, find.byKey(const ValueKey('tab-+find')));
    expect((s.screen, s.inFindBed, s.role), ('explore', true, 'resident'));
    expect(_tabKeys(tester), ['explore', 'map', 'savedHolds', '+stay', 'me']);
    expect(find.text('Saved & Holds'), findsOneWidget);
    // Back on Explore's root stays in Find a bed.
    s.handleBack();
    expect(s.screen, 'explore');

    // Hold a bed at another hostel: it shows under Saved & Holds › Holds.
    final other = hostels.firstWhere((h) => h.id != s.stayHostel.id && (s.rooms[h.id] ?? const []).expand((r) => r.beds).any((b) => b.state == 'free'));
    final bed = s.rooms[other.id]!.expand((r) => r.beds).firstWhere((b) => b.state == 'free');
    s.update(() {
      s.hid = other.id;
      s.bed = bed.id;
    });
    s.placeHold('free');
    await tester.pump();
    expect((s.screen, s.holds.single.hid), ('hold', other.id));
    expect(s.myStay?.hid, 'anjani'); // the stay doesn't change
    await tester.pump(const Duration(seconds: 4));
    s.back();
    await tester.pump();
    expect((s.screen, s.inFindBed), ('explore', true));
    await _tap(tester, find.byKey(const ValueKey('tab-savedHolds')));
    expect(find.byKey(const ValueKey('shSeg')), findsOneWidget);
    await _tap(tester, find.text('Holds · 1'));
    expect(s.shSeg, 'holds');
    expect(find.byKey(ValueKey('holdRow-${s.holds.single.id}')), findsOneWidget);
    await _tap(tester, find.text('Saved · 0'));
    expect(find.text('Nothing saved yet'), findsOneWidget);

    // Me inside Find a bed keeps the Find a bed bar; My stay goes back.
    await _tap(tester, find.byKey(const ValueKey('tab-me')));
    expect((s.screen, s.inFindBed), ('me', true));
    expect(_tabKeys(tester), contains('+stay'));
    await _tap(tester, find.byKey(const ValueKey('tab-+stay')));
    expect((s.screen, s.inFindBed), ('rStay', false));
    expect(_tabKeys(tester), ['rHome', 'rPay', 'rStay', '+find', 'me']);
    expect(AppState.screens.contains('food') || AppState.screens.contains('help'), isFalse);
    s.dispose();
  });

  testWidgets('F26 #16: a red dot on Holds when a hold is kept or declined, until Holds is opened (tenant and resident)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await _pump(tester, s);
    // A plain tenant keeps five tabs.
    expect(_tabKeys(tester), ['explore', 'map', 'saved', 'holds', 'me']);
    final h0 = hostels.first;
    final bed = s.rooms[h0.id]!.expand((r) => r.beds).firstWhere((b) => b.state == 'free');
    s.update(() {
      s.hid = h0.id;
      s.bed = bed.id;
    });
    s.placeHold('free');
    await tester.pump();
    await tester.pump();
    final id = s.holds.single.id;
    expect(s.holdSeen[id], 'waiting');
    s.tab('explore');
    await tester.pump();
    expect(find.byKey(const ValueKey('holdsDot-holds')), findsNothing);
    // The owner keeps it: the dot shows until Holds is opened.
    s.setHold(id, 'confirmed');
    await tester.pump();
    expect(s.holdsDot, isTrue);
    expect(find.byKey(const ValueKey('holdsDot-holds')), findsOneWidget);
    expect(s.snapshot()['holdSeen'], {id: 'waiting'}); // kept on the phone
    await _tap(tester, find.byKey(const ValueKey('tab-holds')));
    await tester.pump();
    expect(s.holdsDot, isFalse);
    expect(find.byKey(const ValueKey('holdsDot-holds')), findsNothing);
    // Declined later, seen from elsewhere: the dot again.
    s.tab('me');
    // A release that isn't the owner's decline (an expiry) gets no dot.
    s.setHold(id, 'released');
    await tester.pump();
    expect(find.byKey(const ValueKey('holdsDot-holds')), findsNothing);
    // The owner's decline (F26 #9: released + declined) does.
    s.update(() => s.holds = [for (final x in s.holds) x.id == id ? x.withStatus('released', declined: true) : x]);
    await tester.pump();
    expect(s.holdsDot, isTrue);
    expect(find.byKey(const ValueKey('holdsDot-holds')), findsOneWidget);

    // A resident in Find a bed: the dot is on Saved & Holds, which opens on Holds.
    s.jump('rHome', 'resident');
    s.openFindBed();
    await tester.pump();
    expect(find.byKey(const ValueKey('holdsDot-savedHolds')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('tab-savedHolds')));
    await tester.pump();
    expect((s.screen, s.shSeg, s.holdsDot), ('savedHolds', 'holds', false));
    expect(find.byKey(const ValueKey('holdsDot-savedHolds')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    s.dispose();
  });

  testWidgets('F26 #10 #11: Me has no Saved, Holds or My stay rows; Log out is red and logs out', (tester) async {
    final s = AppState(start: 'me', role: 'resident');
    await _pump(tester, s);
    for (final r in ['Saved', 'Holds', 'My stay']) {
      expect(find.byKey(ValueKey('me-$r')), findsNothing, reason: r);
    }
    await _tap(tester, find.byKey(const ValueKey('me-logout')));
    expect((s.signedIn, s.screen, s.role, s.inFindBed), (false, 'welcome', 'tenant', false));
    s.dispose();
  });

  for (final c in const [('rHome', false), ('rStay', false), ('savedHolds', true), ('me', true)]) {
    testWidgets('F26: ${c.$1} fits a 360-px phone at 2× text${c.$2 ? ' (Find a bed)' : ''}', (tester) async {
      final s = AppState(start: c.$1, role: 'resident');
      s.inFindBed = c.$2;
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
