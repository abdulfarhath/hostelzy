import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart' show RoomLayout;
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/owner/owner_rent_screen.dart' show rentReminder;
import 'package:hostelzy/features/owner/owner_today_screen.dart' show allRequests;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';

// F26 owner screens: #18 Today in Holds · Payments · Fixes tabs with counts
// (most urgent first, Fair Play pinned, "Nothing needs you now"), #19 Beds as
// the Building view only (bed → sheet, room → layout, Layouts ›), #20 Rent
// with Call + WhatsApp and Paid green / Late red / Due plain. Enquiries are
// gone from the owner side.

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

String _count(WidgetTester tester, String g) => tester.widget<T>(find.byKey(ValueKey('needCount-$g'))).text;

/// Nothing waits for the owner of [s]'s hostel.
void _clear(AppState s) {
  s.reqs = [];
  s.holds = [];
  s.payments = [];
  s.fixes = [];
  s.moves = [];
  s.refunds = [];
  s.amenities = s.amenities.where((a) => a.working).toList();
  s.confirmed[s.ownHid] = 0;
  s.layoutConfirmed[s.ownHid] = 0;
  s.ratesNeverConfirmed.remove(s.ownHid);
  s.ratesConfirmedAt.remove(s.ownHid);
  for (final l in s.layouts[s.ownHid]?.values ?? const <RoomLayout>[]) {
    l.pending = false;
  }
}

void main() {
  mapTiles = false;

  testWidgets('#18 Today: three tabs with counts, holds first, Confirm keeps the wording, no enquiries', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await _pump(tester, s);
    for (final g in ['holds', 'payments', 'fixes']) {
      expect(find.byKey(ValueKey('needTab-$g')), findsOneWidget);
    }
    expect(find.text('Holds'), findsWidgets);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Fixes'), findsOneWidget);
    expect(find.textContaining('nquir'), findsNothing);
    // Holds have a countdown, so the Holds tab opens first.
    final reqs = allRequests(s);
    expect(reqs, isNotEmpty);
    expect(int.parse(_count(tester, 'holds')), greaterThanOrEqualTo(reqs.length));
    final first = (reqs..sort((a, b) => (a.secs - (s.now - a.start) / 1000).compareTo(b.secs - (s.now - b.start) / 1000))).first;
    expect(find.text('Hold on bed ${first.bed}'), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('hold-${first.id}')), matching: find.text('Confirm')), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('hold-${first.id}')), matching: find.text('Decline')), findsOneWidget);

    // Payments: what's waiting for a yes/no shows only in its tab.
    final pays = s.payments.where((x) => x.hid == s.ownHid && x.status == 'waiting').length;
    await _tap(tester, find.byKey(const ValueKey('needTab-payments')));
    expect(find.text('Hold on bed ${first.bed}'), findsNothing);
    expect(int.parse(_count(tester, 'payments')), greaterThanOrEqualTo(pays));

    // Confirm a hold: its count drops by one.
    await _tap(tester, find.byKey(const ValueKey('needTab-holds')));
    final before = int.parse(_count(tester, 'holds'));
    await _tap(tester, find.byKey(ValueKey('hold-${first.id}-btn0')));
    await tester.pump();
    expect(int.parse(_count(tester, 'holds')), before - 1);

    // Manage has no Enquiries row.
    s.tab('oMore');
    s.update(() => s.moreTab = 'home');
    await tester.pump();
    expect(find.byKey(const ValueKey('manage-Enquiries')), findsNothing);
    expect(find.byKey(const ValueKey('manage-Residents')), findsOneWidget);
    s.dispose();
  });

  testWidgets('#18 Today: the most urgent group opens first; Fair Play is pinned above; empty says so', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    _clear(s);
    s.cases = [];
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('needsNothing')), findsOneWidget);
    expect(find.text('Nothing needs you now'), findsOneWidget);
    expect(find.text('New holds, payments and fixes show up here.'), findsOneWidget);
    for (final g in ['holds', 'payments', 'fixes']) {
      expect(_count(tester, g), '0');
    }
    // This month stays under the groups.
    expect(find.text('THIS MONTH'), findsOneWidget);

    // Only a fix waits: the Fixes tab opens on its own.
    final a = s.amenities.firstWhere((x) => x.hid == s.ownHid);
    await s.setAmenityWorking(a, false);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Nothing needs you now'), findsNothing);
    expect(_count(tester, 'fixes'), '1');
    expect(find.byKey(ValueKey('broken-${a.id}')), findsOneWidget);

    // A strike pins the Fair Play card above the tabs.
    s.update(() => s.strikes[s.ownHid] = 1);
    await tester.pump();
    final fp = find.text('Fair Play: strike 1 of 3');
    expect(fp, findsOneWidget);
    expect(tester.getTopLeft(fp).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('needTab-holds'))).dy));
    s.dispose();
  });

  testWidgets('#18 Today: free beds, rates and layouts checks sit in Holds, Payments and Fixes', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    _clear(s);
    s.confirmed[s.ownHid] = 5;
    s.layoutConfirmed[s.ownHid] = 100;
    s.ratesNeverConfirmed.add(s.ownHid);
    await _pump(tester, s);
    expect(find.textContaining('free bed'), findsWidgets);
    expect(find.byKey(ValueKey('freeBeds-${s.ownHid}')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('needTab-payments')));
    expect(find.text('Are your rates still right?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('needTab-fixes')));
    expect(find.text('Do your room layouts still match?'), findsOneWidget);
    await _tap(tester, find.text('All still correct'));
    expect(s.layoutConfirmed[s.ownHid], 0);
    s.dispose();
  });

  testWidgets('#19 Beds: Building view only; a bed opens the sheet, a room its layout, Layouts › stays', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('buildingView')), findsOneWidget);
    expect(find.text('Rooms'), findsNothing);
    expect(find.text('Tap a bed for its bed sheet. Tap a room number for its layout.'), findsOneWidget);
    final res = s.residents.firstWhere((r) => r.bed.startsWith('2'));
    await _tap(tester, find.byKey(ValueKey('bBed-${res.bed}')));
    expect((s.sheet, s.obed), ('bed', res.bed));
    s.update(() => s.sheet = null);
    await tester.pump();
    // A room with a layout opens it; one without opens "Create a layout".
    final withL = s.rooms[s.ownHid]!.firstWhere((r) => s.layoutOf(s.ownHid, r.n) != null);
    await _tap(tester, find.byKey(ValueKey('bRoomOpen-${withL.n}')));
    expect((s.screen, s.lRoom), ('oLayout', withL.n));
    s.update(() {
      s.screen = 'oBeds';
      s.hist = [];
    });
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('obLayouts')));
    expect(s.screen, 'oLayouts');
    s.dispose();
  });

  testWidgets('#20 Rent: Call + WhatsApp with a ready reminder; Paid green, Late red, Due plain', (tester) async {
    final s = AppState(start: 'oRent', role: 'owner');
    await _pump(tester, s);
    const p = Pal.light;
    final late = s.residents.firstWhere((r) => r.status == 'Overdue');
    final due = s.residents.firstWhere((r) => r.status == 'Due');
    final paid = s.residents.firstWhere((r) => r.status == 'Paid');
    Decoration deco(String bed) => tester.widget<Container>(find.descendant(of: find.byKey(ValueKey('rentTag-$bed')), matching: find.byType(Container)).first).decoration!;
    expect((deco(paid.bed) as BoxDecoration).color, p.gb);
    expect((deco(late.bed) as BoxDecoration).color, p.ab);
    expect((deco(due.bed) as BoxDecoration).color, transparent);
    expect((deco(due.bed) as BoxDecoration).border, isNotNull);
    expect(find.byIcon(Icons.notifications), findsNothing);

    // WhatsApp: the resident's real number and a ready reminder.
    final text = rentReminder(s, late);
    expect(text, startsWith('Hi ${late.name.split(' ').first}, '));
    expect(text, contains('rent ₹'));
    expect(text, contains('for bed ${late.bed} is ${late.note}'));
    expect(text, contains('Pay in the Hostelzy app'));
    await _tap(tester, find.byKey(ValueKey('rentWa-${late.bed}')));
    expect(s.lastLink.toString(), 'https://wa.me/91${late.phone}?text=${Uri.encodeComponent(text)}');
    await _tap(tester, find.byKey(ValueKey('rentCall-${due.bed}')));
    expect(s.lastLink.toString(), 'tel:+91${due.phone}');
    expect(rentReminder(s, due), contains('is due ${due.note.substring(4)}'));
    expect(find.byKey(ValueKey('rentWa-${paid.bed}')), findsNothing);
    s.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('F26 owner Today, Beds and Rent fit 360 px at 2× text (${dark ? 'dark' : 'light'})', (tester) async {
      for (final screen in ['oToday', 'oBeds', 'oRent']) {
        final s = AppState(start: screen, role: 'owner');
        s.theme = dark ? 'dark' : 'light';
        await _pump(tester, s, scale: 2, width: 360);
        expect(tester.takeException(), isNull, reason: screen);
        s.dispose();
      }
      final e = AppState(start: 'oToday', role: 'owner');
      _clear(e);
      e.theme = dark ? 'dark' : 'light';
      await _pump(tester, e, scale: 2, width: 360);
      expect(tester.takeException(), isNull);
      expect(find.text('Nothing needs you now'), findsOneWidget);
      e.dispose();
    });
  }
}
