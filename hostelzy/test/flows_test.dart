import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/app_config.dart' show teamPasscode;
import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/kit.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hostelzy/ui/screens_tenant.dart' show filtered;
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
  mapTiles = false; // no network in flow tests
  testWidgets('onboarding: phone, OTP and role lead to Explore', (tester) async {
    final s = AppState();
    await pumpApp(tester, s);
    expect(find.text('See the'), findsOneWidget);
    await tap(tester, find.text('Get started'));
    expect(find.text('Your mobile number'), findsOneWidget);
    await tap(tester, find.text('Debug: fill a test number'));
    await tap(tester, find.text('Send code'));
    expect(find.text('Sent by SMS to +91 90000 00001. Android can fill it in for you.'), findsOneWidget);
    expect(find.text('Resend in 0:30'), findsOneWidget);
    await tap(tester, find.text('Debug: fill'));
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
    await tap(tester, find.text('Book with deal'));
    expect(s.screen, 'picker');
    await tap(tester, find.text('FREE').first);
    expect(s.bed, isNotNull);
    final bed = s.bed!;
    await tap(tester, find.text('Hold bed'));
    expect(find.text('Book bed $bed'), findsOneWidget);
    await tap(tester, find.text('Hold free'));
    expect(s.screen, 'hold');
    expect(find.text('FREE HOLD'), findsOneWidget);
    expect(find.text('Tell Srinivas on WhatsApp'), findsOneWidget);
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
    // F17: pay Srinivas by UPI → UTR → Srinivas confirms → Paid.
    final s = AppState(start: 'rPay', role: 'resident');
    await pumpApp(tester, s);
    await tap(tester, find.text('Pay ₹8,020 by UPI'));
    expect(s.lastLink.toString(), 'upi://pay?pa=sample.owner%40upi&pn=Srinivas&am=8020&tn=Rent+Oct+%C2%B7+204-B&cu=INR');
    expect(s.sheet, 'payUtr');
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField).last, '4021 9910 2299');
    await tester.pump();
    await tap(tester, find.text('Send to Srinivas'));
    expect((s.myRent.status, s.paid), ('waiting', false));
    expect(find.text('Waiting for Srinivas'), findsOneWidget);
    expect(s.residents.firstWhere((r) => r.bed == '204-B').status, 'Waiting');
    await tester.pump(const Duration(seconds: 3));
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.text('Received ₹8,020?'), findsOneWidget);
    await tap(tester, find.text('Yes, received').first);
    expect(s.residents.firstWhere((r) => r.bed == '204-B').status, 'Paid');
    s.jump('rPay', 'resident');
    await tester.pump();
    expect(find.text('₹8,020 paid'), findsOneWidget);
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
    await tap(tester, find.text('Complaints'));
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

  testWidgets('enquiry recorded before WhatsApp; owner sees and contacts it (F05)', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, s);
    final before = s.enquiries.length;
    await tap(tester, find.text('Ask on WhatsApp'));
    expect(s.sheet, 'wa');
    final ref = s.waRef!;
    expect(s.enquiries.length, before + 1);
    expect(s.enquiries.first.ref, ref);
    expect(s.enquiries.first.phone, '9000000001');
    // F17: honest. Nothing reaches the owner until the tenant sends it in WhatsApp.
    expect(find.text('Ask Srinivas on WhatsApp'), findsOneWidget);
    expect(find.text('Nothing is sent until you press send in WhatsApp.'), findsOneWidget);
    expect(s.waFull, endsWith('Ref $ref'));
    await tap(tester, find.text('Send on WhatsApp'));
    expect(s.lastLink.toString(), startsWith('https://wa.me/919000000101?text=Hi%20Srinivas'));
    await tester.pump(const Duration(seconds: 3));

    // Asking again about the same hostel reuses the code.
    await tap(tester, find.text('Ask on WhatsApp'));
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
    expect(find.text('90000 00029 · verified by OTP'), findsOneWidget);
    await tap(tester, find.text('Mark as contacted'));
    expect(s.enquiries.firstWhere((e) => e.ref == 'HZ-4821').contacted, isTrue);
    expect(s.sheet, isNull);
    s.dispose();
  });

  testWidgets('WhatsApp owner from a hold records the bed (F05)', (tester) async {
    final s = AppState(start: 'hold', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Tell Srinivas on WhatsApp'));
    expect(s.sheet, 'wa');
    expect(s.enquiries.first.bed, s.holds.single.bed);
    expect(s.enquiries.first.from, 'Hold · WhatsApp owner');
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
    expect(find.text('Due 14 Oct'), findsOneWidget);
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

  testWidgets('owner adds a resident; phone matched to the enquiry; resident confirms (F06)', (tester) async {
    // A tenant enquires first, from the demo number.
    final s = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Ask on WhatsApp'));
    final ref = s.waRef!;

    // Owner: Manage opens on Residents, with the unassigned-beds banner.
    s.jump('oMore', 'owner');
    await tester.pump();
    expect(s.moreTab, 'residents');
    expect(s.unassignedBeds, ['103-A', '202-B']);
    expect(find.text('2 taken beds have no resident'), findsOneWidget);
    expect(find.text("Beds 103-A and 202-B. Add who's staying there by Sat 3 Oct."), findsOneWidget);

    // Filter chips count and filter.
    await tap(tester, find.text('Waiting OTP 1'));
    expect(find.text('Ravi Teja'), findsOneWidget);
    expect(find.text('Rahul Varma'), findsNothing);
    await tap(tester, find.text('All 21'));

    // Add a resident with the tenant's number: matched live.
    await tap(tester, find.text('Add resident'));
    expect(s.sheet, 'addR');
    expect(s.rBed, '103-A');
    await tester.enterText(find.byType(EditableText).at(0), 'Rahul Varma');
    await tester.enterText(find.byType(EditableText).at(1), '90000 00001');
    await tester.pump();
    expect(find.textContaining('Joined via Hostelzy.'), findsOneWidget);
    expect(find.textContaining('($ref)'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(1), '9000000000');
    await tester.pump();
    expect(find.textContaining('No Hostelzy enquiry, hold or booking from this number in the last 60 days.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(1), '9000000001');
    await tester.pump();
    await tap(tester, find.text('Add and send code'));
    expect(s.sheet, isNull);
    final added = s.residents.first;
    expect(added.bed, '103-A');
    expect(added.confirmed, isFalse);
    expect(added.tag, 'wait');
    expect(added.ref, ref);
    expect(s.unassignedBeds, ['202-B']);
    expect(find.text('1 taken bed has no resident'), findsOneWidget);

    // Resident confirms with the WhatsApp code; now counted as Via Hostelzy.
    s.jump('rConfirm', 'resident');
    await tester.pump();
    expect(find.text('Srinivas added you at Anjani Residency'), findsOneWidget);
    expect(find.text('₹1,000 kept · ₹2,000 back · 30 days notice'), findsOneWidget);
    await tap(tester, find.text('Yes, this is me'));
    expect(added.confirmed, isFalse);
    await tap(tester, find.text('Paste code from WhatsApp'));
    await tap(tester, find.text('Yes, this is me'));
    expect(added.confirmed, isTrue);
    expect(added.tag, 'hz');
    expect(find.text("You're confirmed"), findsOneWidget);
    s.dispose();
  });

  testWidgets('invite QR: owner approves or removes sign-ups (F06)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await pumpApp(tester, s);
    await tap(tester, find.text('Invite QR'));
    expect(s.screen, 'oInvite');
    expect(find.text('hostelzy.in/j/ANJ-7Q2'), findsOneWidget);
    expect(find.text('2 to approve'), findsOneWidget);
    await tap(tester, find.text('Approve').first);
    final r = s.residents.first;
    expect(r.name, 'Abhishek P');
    expect(r.confirmed, isTrue);
    expect(r.tag, 'direct');
    await tap(tester, find.bySemanticsLabel('Not my resident'));
    expect(s.signups, isEmpty);
    expect(find.text('No one waiting. New sign-ups show up here.'), findsOneWidget);
    expect(s.unassignedBeds, ['202-B']);
    s.dispose();
  });

  test('matching window is 60 days (F06)', () {
    final s = AppState();
    const day = 86400000;
    s.enquiries = [
      Enquiry(ref: 'HZ-1', name: 'A', phone: '9000000001', hid: 'anjani', at: s.now - 45 * day, from: '', msg: ''),
      Enquiry(ref: 'HZ-2', name: 'B', phone: '9000000002', hid: 'anjani', at: s.now - 61 * day, from: '', msg: ''),
    ];
    expect(s.matchFor('9000000001', s.now)?.ref, 'HZ-1');
    expect(s.matchFor('9000000002', s.now), isNull);
    s.dispose();
  });

  testWidgets('AC / non-AC: filter, price grid, picker, owner rate card (F16)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('Sai Sri Ladies Hostel'), findsOneWidget);
    await tap(tester, find.widgetWithText(ChipBtn, 'AC'));
    expect(s.fR, 'AC');
    expect(find.text('Sai Sri Ladies Hostel'), findsNothing);
    expect(find.text('NON-AC'), findsNothing);
    await tap(tester, find.widgetWithText(ChipBtn, 'Non-AC'));
    expect(find.text('Nest 42 Co-living'), findsNothing);
    expect(find.text('Sai Sri Ladies Hostel'), findsOneWidget);
    await tap(tester, find.widgetWithText(ChipBtn, 'Non-AC'));
    expect(s.fR, 'Any');

    // Hostel page: sharing × type grid.
    await tap(tester, find.text('Anjani Residency'));
    expect(find.text('Not offered'), findsOneWidget);
    expect(find.text('₹11,000'), findsOneWidget);
    expect(find.text('Every bed in a room type costs the same. Window or door, upper or lower.'), findsOneWidget);

    // Picker: AC filter skips non-AC rooms.
    await tap(tester, find.text('Book with deal'));
    await tap(tester, find.widgetWithText(ChipBtn, 'Non-AC'));
    expect(s.findBed('anjani', '${s.room}-A').r!.ac, isFalse);
    await tap(tester, find.widgetWithText(ChipBtn, 'AC'));
    final r = s.rooms['anjani']!.firstWhere((x) => x.n == s.room);
    expect(r.ac, isTrue);
    expect(find.textContaining('${r.share} sharing · AC · '), findsOneWidget);
    s.dispose();

    // Owner: edit the rate card and a room's type.
    final o = AppState(start: 'oBeds', role: 'owner');
    await pumpApp(tester, o);
    await tap(tester, find.text('Rooms and rent'));
    expect((o.screen, o.moreTab), ('oMore', 'rates'));
    await tester.enterText(find.bySemanticsLabel('Walk-in price, 3 sharing AC'), '9500');
    await tester.pump();
    final r204 = o.rooms['anjani']!.firstWhere((x) => x.n == 204);
    o.setRoomAc(r204, true);
    await tester.pump();
    expect(o.acDraft![204], isFalse);
    await tap(tester, find.text('+ Add'));
    expect(o.rateDraft![rateKey(true, 4)], 7600 + 1200);
    o.setRoomAc(r204, true);
    await tester.pump(const Duration(seconds: 3)); // let the "Add a price first" toast go
    await tap(tester, find.text('Save rate card'));
    expect(o.rooms['anjani']!.firstWhere((x) => x.n == 201).rent, 9500);
    expect(r204.ac, isTrue);
    expect(r204.rent, 8800);
    o.dispose();
  });

  testWidgets('Hostelzy deals: Explore badges, deal table, owner picks deals (F03)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('Save ₹1,200 in 6 mo'), findsWidgets);
    expect(find.text('₹1,000 less upfront'), findsOneWidget);
    await tap(tester, find.widgetWithText(ChipBtn, 'Best deals'));
    expect(filtered(s).first.id, 'anjani');
    expect(s.bestQuote(filtered(s).last.id), isNull);

    // Hostel page: With Hostelzy vs Walk in, 6-month headline.
    await tap(tester, find.text('Anjani Residency'));
    expect(find.text('Hostelzy deal · Non-AC'), findsOneWidget);
    expect(find.text('YOU SAVE IN THE FIRST 6 MONTHS'), findsOneWidget);
    expect(find.text('₹200 less to move in + ₹200/month'), findsOneWidget);
    expect(find.text('Plus ₹500 more'), findsOneWidget);
    expect(find.text('Free laundry weekly'), findsOneWidget);
    expect(find.text('Book with deal'), findsOneWidget);
    expect(find.text('Hostelzy deal: ₹200 off every month · all rooms'), findsOneWidget);

    // Owner: max 3 deals, AC rooms only.
    s.jump('oMore', 'owner');
    await tester.pump();
    await tap(tester, find.text('Deals'));
    expect(s.moreTab, 'deals');
    s.toggleDeal('first');
    expect(s.dealDraft, {'exit', 'monthly', 'laundry'});
    s.toggleDeal('laundry');
    s.toggleDeal('first');
    await tester.pump(const Duration(seconds: 3)); // let the "Pick up to 3" toast go
    await tap(tester, find.text('AC only'));
    await tap(tester, find.text('Publish deals'));
    expect(s.dealsOf('anjani').on, {'exit', 'monthly', 'first'});
    expect(s.dealsOf('anjani').covers(false), isFalse);

    // Tenant: the non-AC table now points to the AC deal.
    s.jump('detail', 'tenant');
    s.update(() => s.dealAc = false);
    await tester.pump();
    expect(find.text('No Hostelzy deal on non-AC rooms'), findsOneWidget);
    await tap(tester, find.text('See the deal on AC rooms'));
    expect(find.text('Hostelzy deal · AC'), findsOneWidget);
    s.dispose();
  });

  test('deal quote maths (F03)', () {
    final q = DealQuote(const Terms(), 8700, {'exit', 'monthly'});
    expect((q.hzFee, q.move, q.hzMove, q.save6, q.upfront, q.moreBack, q.hzBack), (8500, 11700, 11500, 1200, 200, 500, 2500));
    final a = DealQuote(const Terms(maintenance: 1500), 8200, {'exit', 'advance'});
    expect((a.save6, a.upfront, a.ribbon), (0, 1000, '₹1,000 less upfront'));
    final f = DealQuote(const Terms(), 6400, {'first', 'noadmin'});
    expect((f.save6, f.ribbon), (1500, 'Save ₹1,500 in 6 mo'));
  });

  testWidgets('book with the advance: deal locked, HZ code, owner sees it (F04)', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Book with deal'));
    expect(s.screen, 'picker');
    await tap(tester, find.text('FREE').first);
    final bed = s.bed!;
    final r = s.findBed('anjani', bed).r!;
    await tap(tester, find.text('Hold bed'));
    expect(find.text('Book bed $bed'), findsOneWidget);
    expect(find.text('Pay Srinivas today'), findsOneWidget);
    expect(find.text('Your deal is locked'), findsOneWidget);
    expect(find.text('${fmt(r.rent - 200)} monthly'), findsOneWidget);
    expect(find.text('₹500 exit only'), findsOneWidget);
    expect(find.text('1 hour · 2 h for Members'), findsOneWidget);
    expect(find.textContaining('₹299'), findsNothing);
    final ref = s.peekRef;
    await tap(tester, find.text('Pay advance'));
    // F17: not booked until Srinivas confirms the advance arrived.
    var h = s.holds.single;
    expect((h.opt, h.status, h.ref, h.paid, s.sheet), ('book', 'paying', ref, 3000, 'payAdv'));
    expect(s.findBed('anjani', bed).b!.state, 'held');
    expect(find.text('Srinivas · sample.owner@upi'), findsOneWidget);
    await tap(tester, find.text('I’ve already paid · enter UTR').last);
    expect(s.sheet, 'payUtr');
    await tester.enterText(find.byType(TextField).last, '402188341297');
    await tester.pump();
    await tap(tester, find.text('Send to Srinivas'));
    expect(s.payOfHold(h.id)!.status, 'waiting');
    expect(find.text('WAITING FOR SRINIVAS'), findsOneWidget);
    expect(find.textContaining('not booked yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.text('Received ₹3,000?'), findsOneWidget);
    await tap(tester, find.text('Yes, received').last);
    s.jump('holds', 'tenant');
    s.update(() {
      s.screen = 'hold';
      s.holdId = h.id;
    });
    await tester.pump();
    h = s.holds.single;
    expect(h.status, 'booked');
    expect(s.findBed('anjani', bed).b!.state, 'booked');
    expect(find.text('BOOKED'), findsOneWidget);
    expect(find.text(ref), findsOneWidget);

    // The booking is on the owner's Hostelzy list, and matches the phone (F05/F06).
    expect(s.enquiries.first.ref, ref);
    expect(s.enquiries.first.from, 'Book · Pay advance');
    expect(s.matchFor('9000000001', s.now)?.ref, ref);
    s.dispose();
  });

  testWidgets('uneven floors: picker and owner bed map follow each floor', (tester) async {
    // Lakshmi: floor 1 has 2 rooms, floor 2 none, floor 3 has 5.
    final s = AppState(start: 'explore', role: 'tenant');
    s.hid = 'lakshmi';
    await pumpApp(tester, s);
    expect(floorsOf(s.rooms['lakshmi']!), [1, 3]);
    s.openPicker();
    await tester.pump();
    expect(find.text('Floor 1'), findsOneWidget);
    expect(find.text('Floor 2'), findsNothing);
    await tap(tester, find.text('Floor 3'));
    expect(s.floor, 3);
    for (final n in [301, 302, 303, 304, 305]) {
      expect(find.text('$n'), findsOneWidget);
    }
    await tap(tester, find.text('Building'));
    expect(find.text('F2'), findsNothing);
    expect(find.text('F3'), findsOneWidget);
    s.dispose();

    // Owner bed map: Sai Sri has 3, 5 and 2 rooms per floor.
    final o = AppState(start: 'oBeds', role: 'owner');
    o.ownHid = 'saisri';
    await pumpApp(tester, o);
    await tap(tester, find.text('Floor 2'));
    expect(find.text('205'), findsOneWidget);
    await tap(tester, find.text('All floors'));
    expect(find.text('Room 305'), findsNothing);
    expect(find.text('Room 302'), findsOneWidget);
    expect(find.text('Room 205'), findsOneWidget);
    o.dispose();
  });

  testWidgets('verified reviews, ranking and owner replies (F08)', (tester) async {
    // Explore: Recommended is the default sort; rank and reasons, never a score.
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    expect(s.sortBy, 'rec');
    expect(filtered(s).first.id, 'anjani');
    expect(s.rankOf('anjani'), 1);
    expect(s.rankReasons('anjani'), 'Quick replies, beds kept up to date');
    expect(find.text('#1'), findsOneWidget);
    expect(s.rankReasons('nest42'), startsWith('Few reviews yet'));

    // Hostel page → Reviews.
    await tap(tester, find.text('Anjani Residency'));
    await tap(tester, find.text('verified reviews'));
    expect(s.screen, 'reviews');
    expect(find.text('35 of 36'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('Thanks Naveen. We’re fitting a booster pump on 10 Oct.', findRichText: true), findsNothing);

    // Resident: 30-day review.
    s.jump('rHome', 'resident');
    await tester.pump();
    await tap(tester, find.textContaining('How is your stay so far?', findRichText: true));
    expect(s.screen, 'rReview');
    await tap(tester, find.text('Post review'));
    expect(s.screen, 'rReview');
    await tester.pump(const Duration(seconds: 3)); // the "Tap the stars" toast goes
    await tap(tester, find.bySemanticsLabel('4 stars'));
    await tester.enterText(find.byType(EditableText).first, 'Food is good.');
    await tester.pump();
    await tap(tester, find.text('Yes'));
    await tap(tester, find.text('Post review'));
    final mine = s.reviews.first;
    expect((mine.name, mine.stars, mine.text, mine.layout), ('Rahul V.', 4, 'Food is good.', 'Yes'));

    // Resident: exit review feeds the "advance returned" record.
    s.jump('rExit', 'resident');
    await tester.pump();
    expect(find.text('₹2,000'), findsWidgets);
    await tap(tester, find.text('Not yet'));
    await tap(tester, find.bySemanticsLabel('3 stars'));
    await tap(tester, find.text('Post review'));
    expect((s.stats['anjani']!.advFull, s.stats['anjani']!.advLeft), (35, 37));

    // Owner: ranking and replying.
    s.jump('oRank', 'owner');
    await tester.pump();
    expect(find.text('0 · rank not lowered'), findsOneWidget);
    s.jump('oReviews', 'owner');
    await tester.pump();
    expect(find.text('New 4'), findsOneWidget);
    await tap(tester, find.text('Reply').first);
    await tester.enterText(find.byType(EditableText).first, 'Thanks Rahul.');
    await tester.pump();
    await tap(tester, find.text('Post reply'));
    expect(s.reviews.where((r) => r.reply == 'Thanks Rahul.').length, 1);
    expect(find.text('New 3'), findsOneWidget);

    // Fair Play strikes lower the rank.
    s.strikes['anjani'] = 2;
    expect(s.rankOf('anjani'), greaterThan(1));
    s.dispose();
  });

  testWidgets('Fair Play: rules, owner number after a hold, case, strikes (F07)', (tester) async {
    // A new owner accepts the rules with a code.
    final s = AppState(start: 'role');
    await pumpApp(tester, s);
    await tap(tester, find.text('I run a hostel'));
    expect(s.screen, 'oRules');
    await tap(tester, find.text('I accept the Fair Play rules'));
    expect(s.fairAccepted, isFalse);
    await tester.pump(const Duration(seconds: 3)); // the "Enter the code" toast goes
    await tap(tester, find.text('Paste code from SMS'));
    await tap(tester, find.text('I accept the Fair Play rules'));
    expect((s.fairAccepted, s.screen), (true, 'oToday'));
    expect(find.text('Fair Play check FP-0142'), findsOneWidget);

    // Owner fixes the mistake within 48 h: no strike.
    await tap(tester, find.text('Fair Play check FP-0142'));
    expect(s.screen, 'oCase');
    await tap(tester, find.text('Change Teja to Via Hostelzy'));
    expect(s.residents.firstWhere((r) => r.name == 'Teja Naidu').via, 'hz');
    expect(s.cases.first.status, 'closed');
    expect(s.strikes['anjani'] ?? 0, 0);
    expect(s.ownerFixes, 1);

    // Tenant: the owner's number is hidden until a hold.
    s.jump('detail', 'tenant');
    await tester.pump();
    expect(find.text('90••• •••••'), findsOneWidget);
    expect(find.text('Shows after a hold'), findsOneWidget);
    s.update(() => s.bed = '204-D');
    s.placeHold('free');
    s.jump('detail', 'tenant');
    await tester.pump();
    expect(find.text('90000 00101'), findsOneWidget);
    expect(find.text('YOU HELD 204-D'), findsOneWidget);

    // "Did you join?" and a private report.
    s.jump('holds', 'tenant');
    await tester.pump();
    await tap(tester, find.text('Anjani Residency · 102-B'));
    expect(s.sheet, 'joined');
    await tap(tester, find.text('The owner asked me to skip the app'));
    expect(s.sheet, 'report');
    await tap(tester, find.text('Offered a lower price to skip the app'));
    await tap(tester, find.text('Send report'));
    expect(s.cases.first.signal, 'Tenant report: offered a lower price to skip the app');
    expect(s.cases.first.status, 'new');

    // Founder: strikes. Strike 2 hides deals, strike 3 removes the hostel.
    s.jump('aCases', 'owner');
    await tester.pump();
    await tap(tester, find.text('New 4'));
    await tap(tester, find.textContaining('FP-0143'));
    await tap(tester, find.text('Strike 1 · warning'));
    expect(s.strikes['anjani'], 1);
    expect(s.dealsOf('anjani').on, isNotEmpty);
    s.decideCase(s.cases.firstWhere((c) => c.id == 'FP-0139'), 'strike');
    s.strikes['anjani'] = 2;
    expect(s.dealsOf('anjani').on, isEmpty);
    s.strikes['anjani'] = 3;
    expect(filtered(s).any((h) => h.id == 'anjani'), isFalse);
    s.dispose();
  });

  testWidgets('Stay Rewards: Member, 2-hour holds, ₹100 at move-in, Trusted badge (F09)', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Stay Rewards · not a member yet'));
    expect(find.text('Not a member yet'), findsOneWidget);
    expect(s.holdSecs, 3600);

    // "Yes, I joined" (F07) makes the tenant a Member.
    s.update(() => s.sheet = 'joined');
    await tester.pump();
    await tap(tester, find.text('Yes, I joined'));
    expect(s.level, 'member');
    expect(s.holdSecs, 7200);
    await tester.pump();
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('RAHUL-100'), findsOneWidget);

    // A Member's free hold lasts 2 hours.
    s.update(() {
      s.hid = 'greenview';
      s.bed = s.rooms['greenview']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free').id;
      s.sheet = 'hold';
    });
    await tester.pump();
    expect(find.text('2 hours · Member perk'), findsOneWidget);
    await tap(tester, find.text('Pay advance'));
    final hold = s.holds.single;
    s.confirmPayment(s.payOfHold(hold.id)!, true); // the owner saw the money
    s.update(() => s.sheet = null);
    await tester.pump(const Duration(seconds: 3));

    // Move-in: ₹100 off the first month, credited to the owner.
    await tap(tester, find.text('Moving in · see what to pay'));
    expect(s.screen, 'moveIn');
    expect(find.text('− ₹100'), findsOneWidget);
    final r = s.findBed('greenview', hold.bed).r!;
    final q = s.quote('greenview', r.ac, r.share);
    expect(find.text(fmt(q.hzFirst - 100)), findsOneWidget);
    await tap(tester, find.text("I've moved in · open My stay"));
    expect((s.rewardUsed, s.role, s.ownerCredits.single.amt, s.ownerCredits.single.hid), (true, 'resident', 100, 'greenview'));
    s.dispose();

    // Owner: Trusted tenant badge on a hold request.
    final o = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, o);
    await tap(tester, find.text('TRUSTED TENANT'));
    expect(o.sheet, 'trusted');
    expect(find.text('Karthik M is a Trusted tenant'), findsOneWidget);
    await tap(tester, find.text('Confirm hold').last); // the sheet's button, above the cards
    expect(o.reqs.any((x) => x.id == 'k1'), isFalse);
    o.dispose();
  });

  testWidgets('owner plan: trial, invoice QR, UTR, founder check, overdue pauses deals (F10)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    await pumpApp(tester, s);
    await tap(tester, find.text('Your plan'));
    expect(s.screen, 'oPlan');
    expect(find.text('${s.trialLeft} days left'), findsOneWidget);
    expect(find.text('You have 36 beds'), findsOneWidget);
    expect(s.planPrice, 999);

    // A Member reward given at move-in (F09) comes off the invoice.
    s.update(() => s.ownerCredits.add((hid: 'anjani', what: 'Member reward · 204-B', amt: 100)));
    await tester.pump();
    expect(find.text('− ₹100'), findsOneWidget);
    expect(s.invoiceAmt, 899);

    // Invoice: UPI QR with the placeholder UPI ID until the founder sets it.
    await tap(tester, find.text('HZ-INV-1024 · due 1 Nov'));
    expect(s.screen, 'oInvoice');
    expect(find.text('₹899 due 1 Nov'), findsOneWidget);
    expect(find.text('Hostelzy · $hostelzyUpiId'), findsOneWidget);
    await tap(tester, find.text('I’ve paid'));
    expect(s.sheet, 'utr');
    await tap(tester, find.text('Send UTR'));
    expect(s.invoice.status, 'upcoming'); // needs all 12 digits
    await tester.enterText(find.byType(TextField).last, '4021 8834 1297');
    await tester.pump();
    await tap(tester, find.text('Send UTR'));
    expect((s.screen, s.sheet, s.invoice.status, s.invoice.utr, s.invoice.amt), ('oPayStatus', null, 'checking', '402188341297', 899));
    expect(find.text('Checking your payment'), findsOneWidget);
    s.dispose();

    // Founder: match the UTR in the bank, mark paid or not received.
    final a = AppState(start: 'aPay', role: 'owner');
    await pumpApp(tester, a);
    expect(find.text('Check 2'), findsOneWidget);
    await tap(tester, find.text('Mark paid').first);
    expect(a.invoices.firstWhere((i) => i.ref == 'HZ-INV-1019').status, 'paid');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Not received'));
    expect(a.invoices.firstWhere((i) => i.ref == 'HZ-INV-1016').status, 'missing');
    // Orchid is 15 days late: its deals are paused, the listing stays.
    expect(a.dealsOf('orchid').on, isEmpty);
    expect(a.dealsPaused('orchid'), isTrue);
    a.markPaid(a.invoices.firstWhere((i) => i.ref == 'HZ-INV-0998'));
    expect(a.dealsOf('orchid').on, {'monthly'});
    a.dispose();

    // Owner Today: reminder at 5 days late, deals paused at 15.
    final l5 = AppState(start: 'oToday', role: 'owner', plan: 'late5');
    await pumpApp(tester, l5);
    expect(find.text('Your Hostelzy plan is 5 days late'), findsOneWidget);
    expect(l5.dealsOf('anjani').on, isNotEmpty);
    l5.dispose();
    final l15 = AppState(start: 'oToday', role: 'owner', plan: 'late15');
    await pumpApp(tester, l15);
    expect(find.text('Deals paused: plan 15 days late'), findsOneWidget);
    expect(l15.dealsOf('anjani').on, isEmpty);
    await tap(tester, find.text('Pay ₹999 by UPI'));
    expect(l15.screen, 'oInvoice');
    l15.markPaid(l15.invoice);
    expect(l15.dealsOf('anjani').on, isNotEmpty);
    l15.dispose();

    // Not received: the owner fixes the UTR.
    final m = AppState(start: 'oPayStatus', role: 'owner', plan: 'missing');
    await pumpApp(tester, m);
    expect(find.text('We couldn’t find this payment'), findsOneWidget);
    await tap(tester, find.text('Fix the UTR'));
    expect((m.sheet, m.utrDraft), ('utr', '402188341297'));
    m.dispose();
  });

  testWidgets('room layouts: Room tab, bed facts, compare, locked states, owner approval, admin (F12)', (tester) async {
    // Plan stays the default; tapping a room opens it in Room.
    final s = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, s);
    expect(s.mode, 'plan');
    await tap(tester, find.text('Floor 3'));
    await tap(tester, find.text('304'));
    expect((s.mode, s.room), ('room', 304));
    expect(find.text('Room 304'), findsOneWidget);
    expect(find.text('Sample layout · real ones after a visit'), findsOneWidget);
    // Layers are off by default; never priced by position.
    expect(s.showFan || s.showAc, isFalse);
    await tap(tester, find.text('Show AC airflow'));
    expect(s.showAc, isTrue);
    expect(find.text('Same price as every bed here'), findsOneWidget);
    expect(find.text('Bed 304-A · Free'), findsOneWidget);
    expect(find.text('Corner bed · walls on two sides'), findsOneWidget);
    // Tap bed B (free soon) like a seat: its facts show.
    await tap(tester, find.text('B').first);
    expect(s.bed, '304-B');
    expect(find.text('Under a fan'), findsOneWidget);
    expect(find.text('Window side · faces courtyard'), findsOneWidget);
    expect(find.text('In the AC airflow'), findsOneWidget);

    // Compare the two open beds.
    await tap(tester, find.text('Compare beds'));
    expect((s.screen, s.cmpA, s.cmpB), ('compare', 'B', 'A'));
    expect(find.text('Bed B'), findsOneWidget);
    expect(find.text('No fan overhead'), findsOneWidget);
    expect(find.text('₹9,900/mo'), findsNWidgets(2));
    await tap(tester, find.text('Hold B'));
    expect((s.sheet, s.bed), ('hold', '304-B'));
    s.update(() => s.sheet = null);

    // No layout yet: "Layout coming soon".
    s.update(() {
      s.hid = 'greenview';
      s.screen = 'picker';
      s.room = 101;
      s.mode = 'room';
    });
    await tester.pump();
    expect(find.text('Layout coming soon'), findsOneWidget);
    expect(find.text('Compare beds'), findsNothing);

    // Women's PG: floor plan only after a hold; room layouts stay.
    s.update(() {
      s.hid = 'saisri';
      s.room = 102;
      s.mode = 'plan';
    });
    await tester.pump();
    expect(find.text('Floor plan shows after you hold a bed'), findsOneWidget);
    await tap(tester, find.text('See rooms in the Room tab'));
    expect(s.mode, 'room');
    expect(find.text('Room 102'), findsOneWidget);
    s.update(() => s.holds = [Hold(id: 'x', hid: 'saisri', bed: '102-A', room: 102, opt: 'free', start: s.now, status: 'waiting')]);
    expect(s.floorLocked('saisri'), isFalse);
    s.dispose();

    // Signed out: layouts need a verified phone.
    final o = AppState(start: 'picker', role: 'tenant', mode: 'room', auth: 'out');
    await pumpApp(tester, o);
    expect(find.text('Sign in to see room layouts'), findsOneWidget);
    await tap(tester, find.text('Verify my phone'));
    expect(o.screen, 'phone');
    o.dispose();

    // Owner: Beds → room 204 → mark a fan not working → approve.
    final w = AppState(start: 'oBeds', role: 'owner');
    await pumpApp(tester, w);
    await tap(tester, find.text('Approve layout'));
    expect((w.screen, w.lRoom), ('oLayout', 204));
    expect(find.text('Check it and approve to go live'), findsOneWidget);
    final l = w.layoutOf('anjani', 204)!;
    expect(l.live, isTrue); // tenants keep seeing v1 until approval
    await tap(tester, find.text('Not working').last);
    expect(l.of('fan').last.working, isFalse);
    expect(w.complaints.first.text, 'Fan 2 in room 204 marked not working.');
    expect(find.text('FAN · NOT WORKING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Approve layout'));
    expect(l.pending, isFalse);
    expect(find.text('Approved · live for tenants'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    // Request a change: saved as pending (no backend yet).
    await tap(tester, find.text('Request a change'));
    expect(w.sheet, 'layoutReq');
    await tap(tester, find.text('Send request'));
    expect(l.request, isNull);
    await tester.enterText(find.byType(TextField).first, 'Bed C is against the washroom wall.');
    await tap(tester, find.text('Room photo'));
    await tap(tester, find.text('Send request'));
    expect(l.request?.text, 'Bed C is against the washroom wall.');
    expect(l.request?.added, {'photo'});
    expect(find.text('Change requested · new version within 48 h'), findsOneWidget);

    // Hostelzy admin: sees the request, mirrors, sends v3 for approval.
    w.update(() => w.screen = 'aLayout');
    await tester.pump();
    expect(find.text('“Bed C is against the washroom wall.”'), findsOneWidget);
    final before = l.bedRect('A');
    await tap(tester, find.text('Mirror ↔'));
    expect(l.bedRect('A').left, l.w - before.right);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Send to owner for approval'));
    expect((l.version, l.pending, l.request), (3, true, null));
    w.dispose();
  });

  testWidgets('onboarding: add hostel on a visit, go live, switcher, free beds, managers (F14)', (tester) async {
    // Founder's tracker → Add hostel (admin mode).
    final s = AppState(start: 'aTrack', role: 'owner');
    await pumpApp(tester, s);
    expect(find.text('Onboarding · Live 3 of 20 this month'), findsOneWidget);
    await tap(tester, find.text('Add hostel ›'));
    expect((s.screen, s.addStep), ('aAdd', 1));
    expect(find.text('HOSTELZY ADMIN MODE'), findsOneWidget);
    await tap(tester, find.text('Kondapur · tap when checked at the gate'));
    expect(s.draft.pinChecked, isTrue);
    await tap(tester, find.text('Next: rooms'));

    // Uneven floors: Ground 0, 1st 3, 2nd 5, 3rd 2 = 10 rooms, 29 beds.
    expect(find.text('10 rooms · 29 beds'), findsOneWidget);
    expect(find.text('No beds here (kitchen, office) · hidden from tenants'), findsOneWidget);
    await tap(tester, find.text('+').last);
    expect(s.draft.floors[3].rooms.last.label, '303');
    await tap(tester, find.text('−').last);
    await tap(tester, find.text('Create 10 rooms, 29 beds'));

    // Rate card: only the types used; 4 sharing is missing.
    expect(s.draft.missingPrices, ['non4']);
    expect(find.text('Room 202: 4 sharing Non-AC. Add its price.'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('ratenon4')), matching: find.byType(TextField)), '6400');
    await tester.pump();
    expect(s.draft.missingPrices, isEmpty);
    await tap(tester, find.text('Next: photos'));

    // Photos: 8 minimum.
    expect(find.text('4 of 8 minimum'), findsOneWidget);
    for (final t in ['3 sharing', '3 sharing AC', '4 sharing', 'Gate sticker']) {
      await tap(tester, find.text(t).first);
    }
    expect(s.draft.photoCount, 8);
    await tap(tester, find.text('Next: residents'));

    // Residents: grandfathered as Before Hostelzy.
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('resName')), matching: find.byType(TextField)), 'Ravi Kumar');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('resPhone')), matching: find.byType(TextField)), '9000000001');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('resBed')), matching: find.byType(TextField)), '101-a');
    await tester.pump();
    await tap(tester, find.text('Add resident'));
    expect(s.draft.residents.single.bed, '101-A');
    await tap(tester, find.text('Next: go live'));

    // Go live stays locked until all six are done.
    expect(find.text('Go live · 3 things left'), findsOneWidget);
    await tap(tester, find.text('Go live · 3 things left'));
    expect(s.screen, 'aAdd');
    await tap(tester, find.text('Fair Play rules accepted'));
    await tap(tester, find.text('Bed status checked on the visit'));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('ownerPhone')), matching: find.byType(TextField)), '9000000009');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('ownerOtp')), matching: find.byType(TextField)), '123456');
    await tester.pump();
    await tap(tester, find.text('Verify owner'));
    expect(s.goLiveLeft, isEmpty);
    await tap(tester, find.text('Go live'));
    final h = hostels.last;
    expect((s.screen, h.name, h.area, h.reviews), ('aTrack', 'Anjani Annex', 'Kondapur', 0));
    final rs = s.rooms[h.id]!;
    expect((rs.length, rs.fold<int>(0, (a, r) => a + r.beds.length)), (10, 29));
    expect(rs.firstWhere((r) => r.label == '204A').share, 2);
    expect(s.findBed(h.id, '101-A').b!.state, 'booked');
    expect(floorsOf(rs), [1, 2, 3]); // the Ground floor is hidden from tenants
    expect(s.visited[h.id], '1 Oct 2026');
    expect(s.leads.last.stage, 5);
    await tester.pump(const Duration(seconds: 3));

    // Tenants see it in Explore as new.
    expect(filtered(s).any((x) => x.id == h.id), isTrue);

    // Owner: switch hostels.
    s.update(() {
      s.role = 'owner';
      s.screen = 'oToday';
      s.ownerHostels.remove(h.id);
      s.ownerHostels.add(h.id);
    });
    await tester.pump();
    await tap(tester, find.text('ANJANI RESIDENCY · THU 1 OCT'));
    expect(s.sheet, 'switch');
    expect(find.text('Anjani Annex'), findsOneWidget);
    await tap(tester, find.text('Anjani Annex'));
    expect(s.ownHid, h.id);
    s.dispose();
    // A new session starts from the sample data again (no backend yet).
    AppState().dispose();
    expect(hostels.any((x) => x.name == 'Anjani Annex'), isFalse);

    // Tenant: Visited badge and availability.
    final t = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, t);
    expect(find.text('Visited by Hostelzy · 1 Oct 2026'), findsOneWidget);
    expect(t.stale('greenview'), isTrue);
    expect(t.rankOf('greenview'), greaterThan(t.rankOf('anjani')));
    t.dispose();

    // Owner: "Still 9 free beds?" every 3 days.
    final o = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, o);
    expect(find.text('Still 9 free beds?'), findsOneWidget);
    await tap(tester, find.text('Yes, all 9 free'));
    expect(o.confirmed['anjani'], 0);
    expect(find.text('Still 9 free beds?'), findsNothing);
    await tester.pump(const Duration(seconds: 3));

    // Manage → Team → add a manager: the invite is pending until they sign in.
    o.update(() => o.screen = 'oTeam');
    await tester.pump();
    await tap(tester, find.text('Add a manager'));
    await tester.enterText(find.byType(TextField).first, 'Prakash');
    await tester.enterText(find.byType(TextField).last, '90000 00002');
    await tester.pump();
    await tap(tester, find.text('Send invite'));
    expect(o.managers.single, (name: 'Prakash', phone: '9000000002', joined: false));
    expect(find.text('INVITE PENDING'), findsOneWidget);
    o.dispose();
  });

  testWidgets('honest app: links open WhatsApp, phone and maps; holds expire; login resend (F17)', (tester) async {
    // A free hold says the owner doesn't know yet, and ends at 0:00.
    final s = AppState(start: 'hold', role: 'tenant');
    await pumpApp(tester, s);
    final h = s.holds.single;
    expect(find.textContaining('doesn’t know yet'), findsOneWidget);
    expect(find.text('Demo: simulate the owner confirming'), findsOneWidget); // debug builds only
    await tap(tester, find.text('Directions'));
    expect(s.lastLink.toString(), 'https://www.google.com/maps/dir/?api=1&destination=17.4483,78.3915');
    await tester.pump(const Duration(seconds: 3));
    expect(s.expireHoldsAt(h.start + s.holdSecs * 1000 - 5000), isFalse);
    expect(s.expireHoldsAt(h.start + s.holdSecs * 1000), isTrue);
    await tester.pump();
    expect(s.holds.single.status, 'released');
    expect(s.findBed('anjani', h.bed).b!.state, 'free');
    expect(find.text('HOLD EXPIRED'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    await tap(tester, find.text('Hold ${h.bed} again'));
    expect((s.screen, s.sheet, s.bed), ('picker', 'hold', h.bed));
    s.dispose();

    // Owner: Call opens the phone app; reminders open WhatsApp with the text.
    final o = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, o);
    await tap(tester, find.text('Call').first);
    expect(o.lastLink.toString(), startsWith('tel:+91'));
    o.dispose();

    // Login: no demo fill in release; the resend timer counts down.
    final l = AppState(start: 'phone', role: 'tenant');
    await pumpApp(tester, l);
    expect(find.text('Privacy policy', findRichText: true), findsNothing);
    expect(find.textContaining('Privacy policy', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextField), '9000000001');
    await tester.pump();
    await tap(tester, find.text('Send code'));
    expect(l.screen, 'otp');
    expect(find.text('Resend in 0:30'), findsOneWidget);
    l.update(() => l.now += 31000);
    await tester.pump();
    expect(find.text('Resend code'), findsOneWidget);
    l.dispose();
  });

  testWidgets('payments: owner says not received; tenant fixes or cancels; owner UPI ID (F17)', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, s);
    s.update(() {
      s.bed = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free').id;
      s.sheet = 'hold';
    });
    await tester.pump();
    await tap(tester, find.text('Pay advance'));
    final h = s.holds.single;
    final pay = s.payOfHold(h.id)!;
    await tap(tester, find.text('Pay ₹3,000 by UPI').last);
    expect(s.lastLink!.scheme, 'upi');
    expect(s.lastLink!.queryParameters, {'pa': 'sample.owner@upi', 'pn': 'Srinivas', 'am': '3000', 'tn': h.ref, 'cu': 'INR'});
    s.update(() => s.payUtr = '402188341297');
    s.sendPayUtr();
    s.confirmPayment(pay, false);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('NOT RECEIVED'), findsOneWidget);
    expect(h.status, 'paying');
    expect(s.findBed('anjani', h.bed).b!.state, 'held');
    await tap(tester, find.text('Cancel and pick another bed'));
    expect(s.screen, 'picker');
    expect(s.findBed('anjani', h.bed).b!.state, 'free');
    expect(s.payments.where((x) => x.holdId == h.id), isEmpty);
    s.dispose();

    // Owner: Manage → Rates has "Where tenants pay you".
    final o = AppState(start: 'oMore', role: 'owner', moreTab: 'rates');
    await pumpApp(tester, o);
    expect(find.text('This is a sample ID. Type your own before tenants pay you.'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('upiId')), matching: find.byType(TextField)), 'srinivas.anjani@okbank');
    await tester.pump();
    expect(o.ownerUpi['anjani']!.id, 'srinivas.anjani@okbank');
    await tap(tester, find.text('Test with ₹1'));
    expect(o.lastLink!.queryParameters['am'], '1');
    o.dispose();
  });

  testWidgets('real map and the large-screen layout (F17)', (tester) async {
    final s = AppState(start: 'map', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Gachibowli'), findsOneWidget); // other landmarks are labelled
    final mh = hostelById(s.mapSel);
    expect(find.text('${kmLabel(kmTo(mh, 'Hitec City'))} from Hitec City · rated ${jsNum(mh.rating)} · ${s.freeOf(mh.id).f} free'), findsOneWidget);
    await tap(tester, find.text('₹${(hostelById('greenview').from / 1000).toStringAsFixed(1)}k'));
    expect(s.mapSel, 'greenview');
    await tap(tester, find.text('Directions'));
    expect(s.lastLink.toString(), 'https://www.google.com/maps/dir/?api=1&destination=17.464,78.356');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('View hostel'));
    expect((s.screen, s.hid), ('detail', 'greenview'));
    s.dispose();

    // Release layout on a laptop: app column + map, no phone frame or jump list.
    HostelzyShell.prototypeFrame = false;
    addTearDown(() => HostelzyShell.prototypeFrame = true);
    tester.view.physicalSize = const Size(1280, 800);
    final w = AppState(start: 'explore', role: 'tenant');
    await tester.pumpWidget(MaterialApp(home: AppScope(state: w, child: const HostelzyShell())));
    await tester.pump();
    expect(find.text('Beds near Hitec City'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('9:41'), findsNothing);
    expect(find.textContaining('Mobile prototype'), findsNothing);
    w.dispose();
  });

  testWidgets('honest leftovers: fake sample numbers, owner rules, real QR, joined prompt (F17)', (tester) async {
    // No real-looking phone numbers in the sample data.
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'rules');
    expect([...ownerPhones.values, ...s.residents.map((r) => r.phone).where((x) => x.isNotEmpty), ...s.enquiries.map((e) => e.phone)].every((x) => x.startsWith('90000')), isTrue);
    await pumpApp(tester, s);
    // The owner's own house rules show on the hostel page.
    await tester.enterText(find.byType(TextField).first, '11 pm');
    await tester.pump();
    s.update(() {
      s.role = 'tenant';
      s.screen = 'detail';
      s.hid = 'anjani';
    });
    await tester.pump();
    expect(find.text('11 pm'), findsOneWidget);
    s.dispose();

    // Invite QR is a real QR code of the link.
    final o = AppState(start: 'oInvite', role: 'owner');
    await pumpApp(tester, o);
    expect(find.byType(QrImageView), findsOneWidget);
    o.dispose();

    // "Did you join?" asks about the tenant's own ended hold.
    final h = AppState(start: 'hold', role: 'tenant');
    await pumpApp(tester, h);
    final hold = h.holds.single;
    h.expireHoldsAt(hold.start + h.holdSecs * 1000);
    h.update(() => h.screen = 'holds');
    await tester.pump();
    expect(find.text('Anjani Residency · ${hold.bed}'), findsOneWidget);
    h.dispose();
  });

  testWidgets('Play Store: settings, delete account (blocked, code, done), permission explainer (F15)', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Settings'));
    expect(s.screen, 'settings');
    expect(find.text('Hostelzy 1.0.0 (1) · Made in Hyderabad'), findsOneWidget);
    // Appearance: Phone setting follows the phone.
    await tap(tester, find.text('Phone setting'));
    expect(s.theme, 'system');
    expect(s.isDark(Brightness.dark), isTrue);
    expect(s.isDark(Brightness.light), isFalse);
    // Turning a notification on shows the explainer first.
    await tap(tester, find.text('New free beds'));
    expect((s.screen, s.permKind), ('perm', 'notifications'));
    expect(find.text('Turn on notifications?'), findsOneWidget);
    await tap(tester, find.text('Turn on'));
    expect(s.screen, 'settings');
    await tester.pump(const Duration(seconds: 3));
    // Privacy policy opens the web page.
    await tap(tester, find.text('Privacy policy'));
    expect(s.lastLink.toString(), 'https://hostelzy.in/privacy');
    await tester.pump(const Duration(seconds: 3));

    // Delete account: blocked while a hold is open.
    s.update(() => s.holds = [Hold(id: 'x', hid: 'anjani', bed: '204-D', room: 204, opt: 'free', start: s.now, status: 'waiting')]);
    await tap(tester, find.text('Delete account'));
    expect(find.text('You have an open hold'), findsOneWidget);
    expect(find.text('You can’t delete your account yet'), findsOneWidget);
    await tap(tester, find.text('Back to settings'));
    s.update(() => s.holds = []);
    await tap(tester, find.text('Delete account'));
    expect(find.text('Delete your account?'), findsOneWidget);
    await tap(tester, find.text('Continue'));
    expect(s.screen, 'delOtp');
    await tap(tester, find.text('Delete my account'));
    expect(s.screen, 'delOtp'); // needs the code
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tap(tester, find.text('Delete my account'));
    expect((s.screen, s.phone, s.signedIn, s.level), ('delDone', '', false, 'none'));
    expect(find.text('Your account is deleted'), findsOneWidget);
    await tap(tester, find.text('Close'));
    expect(s.screen, 'welcome');
    s.dispose();

    // Owners with an unpaid plan can't delete yet.
    final o = AppState(start: 'delAcc', role: 'owner', plan: 'late5');
    await pumpApp(tester, o);
    expect(find.text('Your Hostelzy plan is unpaid'), findsOneWidget);
    await tap(tester, find.text('Open invoice'));
    expect(o.screen, 'oInvoice');
    o.dispose();

    // The map's my-location button explains before asking; it never fakes a spot.
    final m = AppState(start: 'map', role: 'tenant');
    await pumpApp(tester, m);
    await tap(tester, find.byWidgetPredicate((w) => w is Ic && w.name == 'pin' && w.size == 20).first);
    expect((m.screen, m.permKind), ('perm', 'location'));
    await tap(tester, find.text('Pick an area instead'));
    expect((m.screen, m.sheet), ('map', 'search'));
    m.dispose();
  });

  testWidgets('layout access: owner Beds + Manage, team passcode, editor moves a fan, approval', (tester) async {
    // Owner: a visible Room layout button on each room in Beds.
    final o = AppState(start: 'oBeds', role: 'owner');
    await pumpApp(tester, o);
    expect(find.text('Room layout'), findsWidgets);
    await tap(tester, find.text('Room layout').first);
    expect(o.screen, 'oLayout');
    // ...and Manage → Layouts lists every room with its state.
    o.tab('oMore');
    await tester.pump();
    await tap(tester, find.text('Layouts'));
    expect(o.screen, 'oLayouts');
    expect(find.text('WAITING FOR APPROVAL'), findsOneWidget); // room 204, v2
    expect(find.text('LIVE'), findsWidgets);
    await tap(tester, find.text('Room 201'));
    expect((o.screen, o.lRoom), ('oLayout', 201));

    // Team mode: Settings → Hostelzy team → passcode → team home.
    o.update(() => o.screen = 'settings');
    await tester.pump();
    await tap(tester, find.text('Hostelzy team'));
    expect(o.sheet, 'team');
    await tester.enterText(find.byType(TextField).last, '1111');
    await tester.pump();
    await tap(tester, find.text('Open team tools'));
    expect(o.teamUnlocked, isFalse);
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField).last, teamPasscode);
    await tester.pump();
    await tap(tester, find.text('Open team tools'));
    expect((o.teamUnlocked, o.screen), (true, 'aHome'));
    expect(find.text('TEAM TOOLS · SAMPLE DATA UNTIL THE BACKEND IS CONNECTED'), findsOneWidget);
    for (final t in ['Add hostel', 'Onboarding tracker', 'Payments check', 'Fair Play cases']) {
      expect(find.text(t), findsOneWidget);
    }

    // Layout editor: room 204 (Anjani, 4 sharing). Move fan 1 next to bed A.
    o.update(() => o.lRoom = 204);
    await tap(tester, find.text('Layout editor'));
    expect(o.screen, 'aLayout');
    final l = o.layoutOf('anjani', 204)!;
    final room = o.rooms['anjani']!.firstWhere((r) => r.n == 204);
    expect(bedTraits(l, room, 'A').fan, 'No fan overhead');
    final before = l.items.firstWhere((i) => i.id == 'fan1').x;
    final k = 390 / l.w; // map width ≈ phone width − gutters; only the sign matters
    await tester.drag(find.byKey(const ValueKey('ed-fan1')), Offset(-9 * k, 0));
    await tester.pump();
    final after = l.items.firstWhere((i) => i.id == 'fan1').x;
    expect(after, lessThan(before - 5));
    expect(after, after.roundToDouble()); // on the 1-ft grid
    expect(o.edSel, 'fan1');
    expect(bedTraits(l, room, 'A').fan, 'Under a fan');
    expect(find.textContaining('Under a fan'), findsWidgets); // live bed facts
    // Nudge, then undo / redo.
    await tap(tester, find.byKey(const ValueKey('nudge-right')));
    expect(l.items.firstWhere((i) => i.id == 'fan1').x, after + 1);
    await tap(tester, find.text('Undo'));
    expect(l.items.firstWhere((i) => i.id == 'fan1').x, after);
    await tap(tester, find.text('Redo'));
    expect(l.items.firstWhere((i) => i.id == 'fan1').x, after + 1);
    // A bed with a resident can't be deleted.
    o.edSelect('bed:A');
    await tap(tester, find.text('Delete'));
    expect(l.beds.containsKey('A'), isTrue);
    await tester.pump(const Duration(seconds: 3));
    // Add a pillar, turn it, delete it; resize the room.
    await tap(tester, find.text('+ Pillar'));
    expect(l.of('pillar').length, 1);
    await tap(tester, find.text('Delete'));
    expect(l.of('pillar'), isEmpty);
    final w0 = l.w;
    await tap(tester, find.byKey(const ValueKey('w+')));
    expect(l.w, w0 + 1);

    // Send to the owner: tenants keep the old version until it's approved.
    l.pending = false; // pretend v2 was approved earlier, so this is v3
    l.published = null;
    o.edSelect('fan1');
    await tap(tester, find.byKey(const ValueKey('nudge-left')));
    expect(o.liveLayout('anjani', 204)!.w, w0 + 1); // published copy taken before this edit
    await tap(tester, find.text('Send to owner for approval'));
    expect((l.pending, l.version), (true, 3));
    expect(o.liveLayout('anjani', 204)!.items.firstWhere((i) => i.id == 'fan1').x, isNot(l.items.firstWhere((i) => i.id == 'fan1').x));
    await tester.pump(const Duration(seconds: 3));

    // Owner approves on Beds; tenants now see it.
    o.update(() {
      o.teamUnlocked = false;
      o.screen = 'oBeds';
      o.hist = [];
      o.obFloor = 2;
    });
    await tester.pump();
    await tap(tester, find.text('Approve layout'));
    await tap(tester, find.text('Approve layout').last);
    expect(l.pending, isFalse);
    expect(o.liveLayout('anjani', 204)!.items.firstWhere((i) => i.id == 'fan1').x, l.items.firstWhere((i) => i.id == 'fan1').x);
    o.dispose();
  });

  testWidgets('F12 extras: bunk beds, copy to same rooms, resident says not accurate, 3-monthly confirm', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    // Sample bunk: Nest 42 room 101, D over C.
    final n = s.layoutOf('nest42', 101)!;
    final nr = s.rooms['nest42']!.firstWhere((r) => r.n == 101);
    expect(bedFacts(n, nr, 'D').first, 'Upper bunk');
    expect(bedFacts(n, nr, 'C').first, 'Lower bunk');
    expect(bedTraits(n, nr, 'A').bunk, 'Single bed');
    // The owner is asked every 3 months whether the layouts still match.
    await pumpApp(tester, s);
    expect(find.text('Do your room layouts still match?'), findsOneWidget);
    await tap(tester, find.text('All still correct'));
    expect(s.layoutConfirmed['anjani'], 0);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Do your room layouts still match?'), findsNothing);

    // Editor: stack two beds into a bunk and move them as one; take apart.
    s.update(() {
      s.teamUnlocked = true;
      s.lRoom = 101;
    });
    s.openLayout(101, editor: true);
    await tester.pump();
    final l = s.layoutOf('anjani', 101)!;
    final room = s.rooms['anjani']!.firstWhere((r) => r.n == 101);
    s.edSelect('bed:A');
    await tap(tester, find.text('Stack as bunk'));
    final upper = l.bunks.keys.single;
    expect(l.bunks[upper], 'A');
    expect(l.beds[upper], l.beds['A']);
    expect(bedTraits(l, room, 'A').bunk, 'Lower bunk');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.byKey(const ValueKey('nudge-down')));
    expect(l.beds[upper], l.beds['A']); // moved together
    await tap(tester, find.text('Unstack bunk'));
    expect(l.bunks, isEmpty);
    expect(l.beds[upper], isNot(l.beds['A']));
    await tester.pump(const Duration(seconds: 3));

    // Copy to the other rooms of the same type, as new versions.
    final same = s.rooms['anjani']!.where((r) => r.n != 101 && r.share == room.share && r.ac == room.ac).toList();
    expect(same, isNotEmpty);
    await tap(tester, find.text('Copy to same rooms'));
    for (final r in same) {
      final t = s.layoutOf('anjani', r.n)!;
      expect(t.pending, isTrue);
      expect(t.beds['A'], l.beds['A']);
    }
    s.dispose();

    // Resident's 30-day review: "No" flags the layout for the team.
    final r = AppState(start: 'rReview', role: 'resident');
    await pumpApp(tester, r);
    r.update(() {
      r.rvStars = 4;
      r.rvLayout = 'No';
    });
    r.postReview();
    expect(r.layoutOf('anjani', 204)!.disputes, 1);
    r.dispose();
  });

  testWidgets('3-day rule: a Hostelzy resident added late shows Late and opens a Fair Play signal (F06/F07)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
    await pumpApp(tester, s);
    final cases0 = s.cases.length;
    // On time: moved in yesterday, added today.
    s.openAddResident();
    s.update(() {
      s.rName = 'Ravi Teja';
      s.rPhone = s.enquiries.firstWhere((e) => e.hid == 'anjani').phone;
      s.rJoin = 'Yesterday';
    });
    s.addResident();
    expect(s.residents.first.lateDays, 0);
    expect(s.cases.length, cases0);
    await tester.pump(const Duration(seconds: 3));
    // Late: came through Hostelzy, moved in 5 days ago, added only now.
    final e = Enquiry(ref: 'HZ-4700', name: 'Sandeep Kumar', phone: '9000000077', hid: 'anjani', at: s.now - 10 * 86400000, from: 'Hostel page', msg: '');
    s.update(() => s.enquiries = [...s.enquiries, e]);
    s.openAddResident();
    s.update(() {
      s.rName = 'Sandeep Kumar';
      s.rPhone = e.phone;
      s.rJoin = 'Pick';
      s.rPickBack = 5;
    });
    s.addResident();
    final r = s.residents.first;
    expect((r.name, r.via, r.lateDays), ('Sandeep Kumar', 'hz', 5));
    expect(s.cases.length, cases0 + 1);
    expect(s.cases.first.title, 'Sandeep Kumar added 5 days after moving in');
    expect(s.cases.first.status, 'new');
    await tester.pump();
    expect(find.text('LATE · 5D'), findsOneWidget);
    // A Direct resident (no Hostelzy match) added late is not a Fair Play matter.
    s.openAddResident();
    s.update(() {
      s.rName = 'Walk In';
      s.rBed = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free').id;
      s.rPhone = '9000000088';
      s.rJoin = 'Pick';
      s.rPickBack = 6;
    });
    s.addResident();
    expect((s.residents.first.via, s.residents.first.lateDays), ('direct', 0));
    expect(s.cases.length, cases0 + 1);
    s.dispose();
  });

  testWidgets('Stay Rewards: share my code, Trusted tenant earned from the stay (F09)', (tester) async {
    final s = AppState(start: 'rewards', role: 'tenant');
    await pumpApp(tester, s);
    expect(s.level, 'none');
    s.update(() => s.becomeMember('Anjani Residency'));
    expect(s.level, 'member');
    await tester.pump();
    await tap(tester, find.text('Share'));
    expect(s.lastShare, contains(s.referralCode));
    await tester.pump(const Duration(seconds: 3));
    // Six months, rent always on time, no owner complaints: Trusted.
    s.update(() => s.monthsOnTime = 6);
    expect(s.level, 'trusted');
    // One late month or an owner complaint keeps you a Member.
    s.update(() => s.lateRentMonths = 1);
    expect(s.level, 'member');
    s.update(() {
      s.lateRentMonths = 0;
      s.ownerComplaints = 1;
    });
    expect(s.level, 'member');
    s.update(() => s.monthsOnTime = 4);
    await tester.pump();
    expect(find.text('1 complaint from the owner'), findsOneWidget);
    s.dispose();
  });

  testWidgets('after go-live: add / remove rooms and floors, poster PDF, team members (F14)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'rates');
    await pumpApp(tester, s);
    await tap(tester, find.text('Rooms · add or remove rooms and floors'));
    expect(s.screen, 'oRooms');
    final rs = s.rooms['anjani']!;
    final n0 = rs.length;
    // A room with a resident can't be removed.
    final busy = rs.firstWhere((r) => r.n == 204);
    expect(s.roomBlock('anjani', 204), 'Has a resident');
    s.removeRoom('anjani', 204);
    expect(rs.any((r) => r == busy), isTrue);
    await tester.pump(const Duration(seconds: 3));
    // Add room 105 (2 sharing, AC) on floor 1.
    await tap(tester, find.text('+ Add a room on floor 1'));
    expect((s.sheet, s.nrLabel), ('addRoom', '105'));
    s.update(() {
      s.nrShare = 2;
      s.nrAc = true;
    });
    await tester.pump();
    await tap(tester, find.text('Add room'));
    final r105 = rs.firstWhere((r) => r.label == '105');
    expect((r105.share, r105.ac, rs.length), (2, true, n0 + 1));
    expect(r105.beds.every((b) => b.state == 'free'), isTrue);
    expect(r105.rent, s.rates['anjani']![rateKey(true, 2)]);
    await tester.pump(const Duration(seconds: 3));
    // ... and remove it again (empty room).
    s.removeRoom('anjani', r105.n);
    expect(rs.length, n0);
    // A new floor 4, then remove it.
    s.addFloor('anjani');
    expect(s.nrFloor, 4);
    s.addRoom('anjani');
    expect(floorsOf(rs), contains(4));
    s.removeFloor('anjani', 4);
    expect(floorsOf(rs), isNot(contains(4)));
    // A floor with residents can't go.
    s.removeFloor('anjani', 2);
    expect(floorsOf(rs), contains(2));
    s.dispose();

    // Resident QR poster: a real A4 PDF.
    final o = AppState(start: 'oInvite', role: 'owner');
    await pumpApp(tester, o);
    await tester.runAsync(() => o.sharePoster('https://hostelzy.in/j/ANJ-7Q2'));
    expect(o.lastPosterBytes, greaterThan(1000));
    o.dispose();

    // Team mode: team members, invites pending.
    final t = AppState(start: 'aTeam', role: 'owner');
    await pumpApp(tester, t);
    expect(find.text('Founder'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('tmName')), matching: find.byType(TextField)), 'Imran');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('tmPhone')), matching: find.byType(TextField)), '9000000201');
    await tester.pump();
    await tap(tester, find.text('Layouts'));
    await tap(tester, find.text('Send invite'));
    expect(t.teamMembers.last, (name: 'Imran', phone: '9000000201', role: 'Layouts', joined: false));
    expect(find.text('INVITE PENDING'), findsOneWidget);
    t.dispose();
  });

  testWidgets('app icon and room mark (logo B3-a2)', (tester) async {
    final s = AppState();
    await pumpApp(tester, s);
    expect(find.byType(BrandMark), findsOneWidget);
    s.dispose();
    for (final f in [
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      'android/app/src/main/res/values/ic_launcher_background.xml',
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) ...['android/app/src/main/res/mipmap-$d/ic_launcher_foreground.png', 'android/app/src/main/res/mipmap-$d/ic_launcher_monochrome.png'],
      'assets/brand/mark-light.svg',
      'assets/brand/mark-dark.svg',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
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
