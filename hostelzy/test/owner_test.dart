import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F22 Area 3, Half A (Owner): Beds as floor chips and room cards, one bed
// sheet, Rent with "Still to come" and a bell per row, Residents with search
// and the invite QR, Add tenant, Invite and the enquiry sheet.

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

  testWidgets('F22 Area 3: Beds is floor chips and room cards; a bed opens one sheet', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Beds'), findsWidgets);
    final rooms = s.rooms['anjani']!;
    for (final f in floorsOf(rooms)) {
      expect(find.byKey(ValueKey('obFloor-$f')), findsOneWidget);
    }
    await _tap(tester, find.byKey(const ValueKey('obFloor-2')));
    for (final r in rooms.where((r) => r.floor == 2)) {
      expect(find.byKey(ValueKey('oRoom-${r.n}')), findsOneWidget);
    }
    expect(find.text('Rooms and rates ›'), findsOneWidget);

    // A taken bed: who, room, rent, since; Message / Mark as leaving.
    final taken = s.residents.firstWhere((r) => r.bed.startsWith('2'));
    await _tap(tester, find.byKey(ValueKey('obed-${taken.bed}')));
    expect(s.sheet, 'bed');
    expect(find.text('TAKEN'), findsOneWidget);
    expect(find.textContaining(taken.name), findsWidgets);
    expect(find.text('Message ${taken.name.split(' ').first}'), findsOneWidget);
    expect(find.textContaining('Mark as leaving'), findsOneWidget);
    expect(find.byKey(const ValueKey('bedLayout')), findsOneWidget);
    s.update(() => s.sheet = null);
    await tester.pump();

    // A free bed: add a tenant to it.
    final free = rooms.where((r) => r.floor == 2).expand((r) => r.beds).firstWhere((b) => b.state == 'free');
    await _tap(tester, find.byKey(ValueKey('obed-${free.id}')));
    await _tap(tester, find.text('Add tenant to this bed'));
    expect((s.sheet, s.addBed), ('add', free.id));
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Came from the Hostelzy app? Use the phone number they booked with, so it counts.'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('addName')), matching: find.byType(EditableText)), 'Kiran Kumar');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('addGo')));
    expect(s.residents.last.name, 'Kiran Kumar');
    expect(s.findBed('anjani', free.id).b!.state, 'booked');
    s.dispose();
  });

  testWidgets('F22 Area 3: Rent shows Collected and Still to come; Late rows have a bell', (tester) async {
    final s = AppState(start: 'oRent', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('Still to come'), findsOneWidget);
    final late = s.residents.where((r) => r.status == 'Overdue').length;
    expect(find.text('Late $late'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
    await _tap(tester, find.text('Late $late'));
    expect(s.rentF, 'Overdue');
    final r = s.residents.firstWhere((r) => r.status == 'Overdue');
    await _tap(tester, find.byKey(ValueKey('remind-${r.bed}')));
    expect(s.lastLink.toString(), startsWith('https://wa.me/'));
    // Paid rows have no bell.
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.textContaining('Paid ').first);
    final paid = s.residents.firstWhere((r) => r.status == 'Paid');
    expect(find.byKey(ValueKey('remind-${paid.bed}')), findsNothing);
    s.dispose();
  });

  testWidgets('F22 Area 3: Residents: search, plain tags, the banner, the invite QR', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
    await _pump(tester, s);
    final r = s.residents.first;
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('resSearch')), matching: find.byType(EditableText)), r.bed);
    await tester.pump();
    expect(find.text(r.name), findsOneWidget);
    expect(find.text(s.residents.firstWhere((x) => x.bed != r.bed && !x.bed.contains(r.bed)).name), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('inviteQr')));
    expect(s.screen, 'oInvite');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('inviteQrCode')), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Print poster'), findsOneWidget);
    expect(find.text('WAITING FOR YOU · ${s.signups.length}'), findsOneWidget);
    expect(find.text('Make a new code (the old one stops working)'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F22 Area 3: the enquiry sheet puts the booking code first', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'enquiries');
    await _pump(tester, s);
    final e = s.enquiries.firstWhere((x) => x.hid == s.ownHid);
    s.update(() {
      s.enqRef = e.ref;
      s.sheet = 'enq';
    });
    await tester.pump();
    expect(find.text('Booking code'), findsOneWidget);
    expect(find.text(e.ref), findsWidgets);
    expect(find.text('If ${e.name.split(' ').first} moves in, add them with this phone number so it counts.'), findsOneWidget);
    await _tap(tester, find.text('Call').last);
    expect(s.lastLink.toString(), startsWith('tel:'));
    s.dispose();
  });

  for (final c in const [('oBeds', null), ('oRent', null), ('oMore', 'residents'), ('oInvite', null)]) {
    testWidgets('F22 Area 3: ${c.$2 ?? c.$1} fits at 2× text', (tester) async {
      final s = AppState(start: c.$1, role: 'owner', moreTab: c.$2);
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }
}
