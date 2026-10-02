import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// The food menu on the server: the owner saves the week, residents see it on
// Home and in Food, tenants see a peek on the hostel page, and breakfast
// ratings reach the owner as counts.

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

/// Lets the fake server's futures finish (fake time: pumps, not delays).
Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 6; k++) {
    await tester.pump();
  }
}

/// A server with one resident (Kiran at Sai Sri) and a menu per hostel.
class _Server extends SampleRepo {
  final calls = <String>[];
  final weeks = <String, List<DayMenu>>{};
  bool down = false;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: [
    {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<List<DayMenu>?> menu(String hid) async => weeks[hid];
  @override
  Future<void> saveMenu(String hid, List<DayMenu> week) async {
    if (down) throw Exception('offline');
    calls.add('menu $hid ${week[0].b}');
    weeks[hid] = week;
  }

  @override
  Future<void> rateMeal(String hid, String meal, String rating) async {
    if (down) throw Exception('offline');
    calls.add('rate $hid $meal $rating');
  }

  @override
  Future<Map<String, Map<String, int>>> mealVotes(String hid) async => {'b': {'good': 4, 'poor': 2}};
}

List<DayMenu> _week(String b) => [for (var i = 0; i < 7; i++) DayMenu('$b $i', 'Rice $i', 'Chapati $i')];

void main() {
  mapTiles = false;

  testWidgets('a resident sees the owner’s saved menu on Home and in Food, and rates breakfast', (tester) async {
    final server = _Server()..weeks['saisri'] = _week('Pongal');
    final s = AppState(start: 'rHome', role: 'resident');
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
      s.myName = 'Kiran Rao';
    });
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    await tester.pump();
    // Home: today's three meals from the server, no "hasn't put the menu".
    expect(s.stayHostel.id, 'saisri');
    expect(find.text('Pongal $todayIdx'), findsOneWidget);
    expect(find.textContaining('hasn’t put the menu'), findsNothing);

    // Food: today, the week, and Good / Okay / Poor saved on the server.
    s.tab('food');
    await tester.pump();
    await _settle(tester);
    await tester.pump();
    expect(find.text('Pongal $todayIdx'), findsOneWidget);
    await _tap(tester, find.text('Good'));
    await _settle(tester);
    expect(server.calls.last, 'rate saisri b good');
    expect(s.rated, 'Good');
    final owner = hostelById('saisri').owner;
    expect(s.toast, 'Thanks. $owner sees how many said Good, not who.');
    await tester.pump(const Duration(seconds: 4));

    // Offline: the answer goes back and says so.
    server.down = true;
    await _tap(tester, find.text('Poor'));
    await _settle(tester);
    expect(s.rated, 'Good');
    expect(s.toast, 'Couldn’t save it. Check your internet and try again.');
    await tester.pump(const Duration(seconds: 4));

    // The owner changes the menu; it shows the next time Food opens.
    server.weeks['saisri'] = _week('Upma');
    s.tab('rHome');
    await tester.pump();
    s.tab('food');
    await tester.pump();
    await _settle(tester);
    await tester.pump();
    expect(find.text('Upma $todayIdx'), findsOneWidget);

    // No menu on the server: the honest empty message, no week link.
    server.weeks.remove('saisri');
    s.tab('rHome');
    await tester.pump();
    await _settle(tester);
    await tester.pump();
    expect(find.text('$owner hasn’t put the menu on Hostelzy yet.'), findsOneWidget);
    s.tab('food');
    await tester.pump();
    await _settle(tester);
    await tester.pump();
    expect(find.text('$owner hasn’t put the menu on Hostelzy yet. It shows here once they do.'), findsOneWidget);
    expect(find.byKey(const ValueKey('foodWeek')), findsNothing);
    expect(find.text('How was breakfast?'), findsNothing);
    s.dispose();
  });

  testWidgets('the owner saves the week to the server; a week typed on the phone before is kept', (tester) async {
    final server = _Server();
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com');
      // F18 kept the menu on this phone only.
      s.phoneMenu = _week('Idli');
    });
    await s.startLive();
    await _pump(tester, s);
    await _tap(tester, find.text('Food menu'));
    await _settle(tester);
    await tester.pump();
    // Nothing on the server (not the sample week): the phone's week, not saved yet.
    expect(s.menuOf(s.ownHid), isNull);
    expect(s.menuDraft![0].b, 'Idli 0');
    expect(find.text('Not saved yet. Residents and tenants see it after you tap Save.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mealVotes')), findsOneWidget);
    expect(find.text('Breakfast: 4 good · 0 okay · 2 poor'), findsOneWidget);

    // Offline: nothing is lost.
    server.down = true;
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    await _settle(tester);
    expect((s.moreTab, s.menuDirty, s.toast), ('menu', true, 'Couldn’t save it. Check your internet and try again.'));
    await tester.pump(const Duration(seconds: 4));

    server.down = false;
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    await _settle(tester);
    await tester.pump();
    expect(server.calls.last, 'menu ${s.ownHid} Idli 0');
    expect((s.moreTab, s.menuDirty, s.phoneMenu), ('home', false, null));
    expect(s.menuOf(s.ownHid)![0].b, 'Idli 0');
    expect(s.toast, 'Menu saved. Residents see it in their Food tab now.');
    await tester.pump(const Duration(seconds: 4));

    // Open again: the saved week, with Saved greyed out until something changes.
    await _tap(tester, find.text('Food menu'));
    await _settle(tester);
    await tester.pump();
    expect((s.menuDirty, s.menuDraft![1].l), (false, 'Rice 1'));
    expect(find.text('Residents and tenants see it after you tap Save.'), findsOneWidget);
    expect(find.byKey(const ValueKey('menuEmpty')), findsNothing);
    s.dispose();
  });

  testWidgets('a tenant sees today’s food on the hostel page and the week in a sheet', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('foodPeek')), findsOneWidget);
    expect(find.text('Food menu · today, $todayName'.toUpperCase()), findsOneWidget);
    expect(find.text(seedMenu[todayIdx].b), findsOneWidget);
    expect(find.text('7:30 – 9:30'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('foodMenu')));
    expect((s.screen, s.sheet, s.foodFor, s.fwDay), ('detail', 'foodWeek', 'anjani', todayIdx));
    final next = (todayIdx + 1) % 7;
    await _tap(tester, find.byKey(ValueKey('fwDay-$next')));
    expect(find.text(seedMenu[next].n), findsOneWidget);
    // Not a resident: no rating here.
    expect(find.text('How was breakfast?'), findsNothing);
    s.update(() => s.sheet = null);
    await tester.pump();

    // A hostel that serves food but has no menu says so; one without food shows nothing.
    final noMenu = hostels.firstWhere((h) => h.id != 'anjani' && h.food);
    s.update(() => s.hid = noMenu.id);
    await tester.pump();
    expect(find.byKey(const ValueKey('foodPeek')), findsOneWidget);
    expect(find.text('Menu not added yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('foodMenu')), findsNothing);
    final noFood = hostels.where((h) => !h.food).firstOrNull;
    if (noFood != null) {
      s.update(() => s.hid = noFood.id);
      await tester.pump();
      expect(find.byKey(const ValueKey('foodPeek')), findsNothing);
    }
    s.dispose();
  });

  testWidgets('removed: Confirm your stay, oReviews, the areas and joined sheets', (tester) async {
    for (final x in ['rConfirm', 'oReviews']) {
      expect(AppState.screens.contains(x), isFalse, reason: x);
    }
    final s = AppState(start: 'oRank', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Reviews and ranking'), findsOneWidget);
    s.dispose();
  });

  testWidgets('a new hostel’s menu starts empty, with placeholders and Save off', (tester) async {
    final server = _Server();
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _tap(tester, find.text('Food menu'));
    await _settle(tester);
    await tester.pump();
    expect(find.text('No menu yet. Tenants see “Menu not added yet” on your hostel page until you save one.'), findsOneWidget);
    expect(find.text('What’s for breakfast?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    expect(server.calls, isEmpty);
    s.dispose();
  });

  for (final c in const ['detail', 'food', 'menu', 'foodWeek']) {
    testWidgets('food: $c fits at 2× text', (tester) async {
      final s = c == 'menu' ? AppState(start: 'oMore', role: 'owner', moreTab: 'menu') : AppState(start: c == 'foodWeek' ? 'detail' : c, role: c == 'food' ? 'resident' : 'tenant');
      s.hid = 'anjani';
      if (c == 'foodWeek') s.openFoodFor('anjani');
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
