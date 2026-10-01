import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

Future<void> _loadFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final (family, files) in [
    ('Archivo', ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']),
    ('JetBrainsMono', ['JetBrainsMono-Regular.ttf']),
  ]) {
    final l = FontLoader(family);
    for (final f in files) {
      final b = File('assets/fonts/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }
});

/// Pumps the 410×864 phone frame for [state].
Future<void> pumpApp(WidgetTester tester, AppState state) async {
  await _loadFonts(tester);
  tester.view.physicalSize = const Size(410, 864);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AppScope(state: state, child: const HostelzyShell(bare: true)),
    ),
  );
  await tester.pump();
}

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets('onboarding: phone, OTP and role lead to Explore', (tester) async {
    final s = AppState();
    await pumpApp(tester, s);
    expect(find.text('See the'), findsOneWidget);
    await tap(tester, find.text('Get started'));
    expect(find.text('Your mobile number'), findsOneWidget);
    await tap(tester, find.text('Fill a demo number'));
    await tap(tester, find.text('Send code'));
    expect(find.text('Sent to +91 98480 12345'), findsOneWidget);
    await tap(tester, find.text('Paste code from SMS'));
    await tap(tester, find.text('Verify'));
    await tap(tester, find.text('I need a bed'));
    expect(s.screen, 'explore');
    expect(find.text('Beds near Hitec City'), findsOneWidget);
    s.dispose();
  });

  testWidgets('tenant holds a bed; owner sees and confirms it', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Anjani Residency'));
    expect(s.screen, 'detail');
    await tap(tester, find.text('Pick a bed'));
    expect(s.screen, 'picker');
    await tap(tester, find.text('FREE').first);
    expect(s.bed, isNotNull);
    final bed = s.bed!;
    await tap(tester, find.text('Hold bed'));
    expect(find.text('Hold bed $bed'), findsOneWidget);
    await tap(tester, find.text('Place free hold'));
    expect(s.screen, 'hold');
    expect(find.text('WAITING FOR SRINIVAS'), findsOneWidget);
    expect(s.findBed('anjani', bed).b!.state, 'held');

    // The same hold shows up in the owner's request inbox.
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.text('Bed $bed · Free hold'), findsOneWidget);
    await tap(tester, find.text('Confirm hold').first);
    expect(s.holds.single.status, 'confirmed');
    s.dispose();
  });

  testWidgets('bed picker list and building modes', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('List'));
    expect(find.textContaining('beds you can take'.toUpperCase()), findsOneWidget);
    await tap(tester, find.text('Building'));
    expect(find.text('CROSS-SECTION · TAP ANY FREE BED'), findsOneWidget);
    s.dispose();
  });

  testWidgets('resident pays rent; owner rent list updates', (tester) async {
    final s = AppState(start: 'rPay', role: 'resident');
    await pumpApp(tester, s);
    await tap(tester, find.text('by'));
    expect(find.text('₹8,020 paid'), findsOneWidget);
    expect(s.residents.firstWhere((r) => r.bed == '204-B').status, 'Paid');
    s.dispose();
  });

  testWidgets('owner menu edits show in the resident Food tab', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'menu');
    await pumpApp(tester, s);
    await tester.enterText(find.byType(EditableText).first, 'Masala dosa');
    await tester.pump();
    expect(s.menu[3].b, 'Masala dosa');
    s.jump('rHome', 'resident');
    await tester.pump();
    expect(find.text('Masala dosa'), findsOneWidget);
    s.dispose();
  });

  testWidgets('complaint goes to the owner queue', (tester) async {
    final s = AppState(start: 'help', role: 'resident');
    await pumpApp(tester, s);
    await tester.enterText(find.byType(EditableText).first, 'Fan is broken');
    await tester.pump();
    await tap(tester, find.text('Send to warden'));
    expect(s.complaints.last.text, 'Fan is broken');
    s.jump('oMore', 'owner');
    await tester.pump();
    expect(find.text('Fan is broken'), findsOneWidget);
    s.dispose();
  });

  testWidgets('theme switch from the profile', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Dark'));
    expect(s.theme, 'dark');
    s.dispose();
  });

  testWidgets('advance model: ₹3,000 advance, maintenance kept on exit (F02)', (tester) async {
    // Tenant: hostel page rules and the hold steps.
    final s = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('₹3,000 + first month at move-in'), findsOneWidget);
    expect(find.text('₹1,000 kept from the advance'), findsOneWidget);
    expect(find.textContaining("2 months"), findsNothing);
    s.jump('hold', 'tenant');
    await tester.pump();
    expect(find.text('Pay ₹3,000 advance + first month at move-in.'), findsOneWidget);
    s.dispose();

    // Resident: Pay rent shows the advance and what comes back.
    final r = AppState(start: 'rPay', role: 'resident');
    await pumpApp(tester, r);
    expect(find.text('Due 14 Oct. The owner gets a receipt on WhatsApp.'), findsOneWidget);
    expect(find.text('₹2,000 BACK WHEN YOU LEAVE'), findsOneWidget);
    expect(find.textContaining('₹15,200'), findsNothing);

    // Move out: refund = advance − maintenance, with the notice date.
    r.go('move');
    await tester.pump();
    expect(find.text('31 Oct'), findsWidgets);
    expect(find.text('− ₹1,000'), findsOneWidget);
    expect(find.text('₹2,000 within 7 days'), findsOneWidget);
    await tap(tester, find.text('Give notice for'));
    expect(r.notice, isTrue);
    expect(find.text('₹2,000 back to your UPI'), findsOneWidget);
    r.dispose();

    // Owner: bed sheet and add booking show advance and maintenance.
    final o = AppState(start: 'oBeds', role: 'owner', sheet: 'bed');
    await pumpApp(tester, o);
    expect(find.text('₹3,000 · ₹1,000 kept on exit'), findsOneWidget);
    expect(find.text('Mark as leaving 31 Oct'), findsOneWidget);
    o.update(() {
      o.sheet = 'add';
      o.addBed = '102-A';
    });
    await tester.pump();
    final rent = o.findBed('anjani', '102-A').r!.rent;
    expect(find.text(fmt(3000 + rent)), findsOneWidget);
    o.dispose();
  });

  test('advance terms helpers', () {
    const t = Terms();
    expect(t.refund, 2000);
    expect(leaveDates(t), ['31 Oct', '15 Nov', '30 Nov']);
    expect(leaveDates(const Terms(noticeDays: 15)).first, '16 Oct');
    expect(dueNote(t, 14), 'Due 14 Oct');
    expect(dueLeft(t, 14), '13 days left');
    expect(dueNote(const Terms(dueOnJoining: false), 14), 'Due 1 Oct');
    expect(dueLeft(const Terms(dueOnJoining: false), 14), 'due today');
    expect(hostelById('saisri').terms.refund, 1500);
  });

  testWidgets('enquiry recorded before WhatsApp; owner sees and contacts it (F05)', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, s);
    final before = s.enquiries.length;
    await tap(tester, find.text('Ask on WhatsApp'));
    expect(s.sheet, 'wa');
    final ref = s.waRef!;
    expect(s.enquiries.length, before + 1);
    expect(s.enquiries.first.ref, ref);
    expect(s.enquiries.first.phone, '9848012345');
    expect(find.textContaining('has been told on Hostelzy'), findsOneWidget);
    expect(find.textContaining('hostelzy.in/r/$ref'), findsOneWidget);
    expect(s.waFull, endsWith('Ref $ref · hostelzy.in/r/$ref'));

    // Asking again about the same hostel reuses the code.
    await tap(tester, find.text('Copy message'));
    await tap(tester, find.text('Ask on WhatsApp'));
    expect(s.waRef, ref);
    expect(s.enquiries.length, before + 1);

    // Owner Today lists it, newest first, as New.
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.text('ENQUIRIES FROM HOSTELZY'), findsOneWidget);
    expect(find.text(ref), findsOneWidget);
    expect(find.text('3 new'), findsOneWidget);
    expect(find.textContaining('Not on this list = not from Hostelzy.'), findsOneWidget);

    // Calling marks it Contacted.
    await tap(tester, find.text('Call').first);
    expect(s.enquiries.first.contacted, isTrue);
    expect(find.text('2 new'), findsOneWidget);

    // Tapping an HZ code opens the enquiry sheet.
    await tap(tester, find.text('HZ-4821'));
    expect(s.sheet, 'enq');
    expect(find.text('HZ-4821 · Ravi Teja'), findsOneWidget);
    expect(find.text('98490 33121 · verified by OTP'), findsOneWidget);
    await tap(tester, find.text('Mark as contacted'));
    expect(s.enquiries.firstWhere((e) => e.ref == 'HZ-4821').contacted, isTrue);
    expect(s.sheet, isNull);
    s.dispose();
  });

  testWidgets('WhatsApp owner from a hold records the bed (F05)', (tester) async {
    final s = AppState(start: 'hold', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('WhatsApp'));
    expect(s.sheet, 'wa');
    expect(s.enquiries.first.bed, s.holds.single.bed);
    expect(s.enquiries.first.from, 'Hold · WhatsApp owner');
    s.dispose();
  });

  test('data helpers match the prototype', () {
    expect(fmt(7600), '₹7,600');
    expect(fmt(1234567), '₹12,34,567');
    expect(cd(2460), '41:00');
    expect(cd(172800), '48:00:00');
    expect(jsNum(4.0), '4');
    expect(phoneSpaced('9848012345'), '98480 12345');
    // Seeded bed layout is deterministic.
    final a = mkRooms(hostels[0], 0);
    fixAnjani(a);
    expect(a.expand((r) => r.beds).length, 36);
    expect(a.expand((r) => r.beds).where((b) => b.state == 'booked').length, 23);
  });
}
