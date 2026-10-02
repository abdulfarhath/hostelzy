import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart';
import 'package:hostelzy/ui/kit.dart';
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
    await tap(tester, find.text('Book with deal'));
    expect(s.screen, 'picker');
    await tap(tester, find.text('FREE').first);
    expect(s.bed, isNotNull);
    final bed = s.bed!;
    await tap(tester, find.text('Hold bed'));
    expect(find.text('Book bed $bed'), findsOneWidget);
    await tap(tester, find.text('Hold free'));
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
    await tester.enterText(find.byType(EditableText).at(1), '98480 12345');
    await tester.pump();
    expect(find.textContaining('Joined via Hostelzy.'), findsOneWidget);
    expect(find.textContaining('($ref)'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(1), '9000000000');
    await tester.pump();
    expect(find.textContaining('No Hostelzy enquiry, hold or booking from this number in the last 60 days.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(1), '9848012345');
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
    final h = s.holds.single;
    expect((h.opt, h.status, h.ref, h.paid), ('book', 'booked', ref, 3000));
    expect(s.findBed('anjani', bed).b!.state, 'booked');
    expect(find.text('BOOKED'), findsOneWidget);
    expect(find.text(ref), findsOneWidget);

    // The booking is on the owner's Hostelzy list, and matches the phone (F05/F06).
    expect(s.enquiries.first.ref, ref);
    expect(s.enquiries.first.from, 'Book · Pay advance');
    expect(s.matchFor('9848012345', s.now)?.ref, ref);
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
    expect(find.text('98••• •••••'), findsOneWidget);
    expect(find.text('Shows after a hold'), findsOneWidget);
    s.update(() => s.bed = '204-D');
    s.placeHold('free');
    s.jump('detail', 'tenant');
    await tester.pump();
    expect(find.text('98480 11223'), findsOneWidget);
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
