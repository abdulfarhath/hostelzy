import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:hostelzy/app_config.dart' show dataSource, supabaseUrl, supabaseAnonKey, hostelzyUpiId, supportWhatsApp, webBase, privacyUrl, deleteAccountUrl, enquiryLink, inviteLink;
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/push.dart';
import 'package:hostelzy/sign_in.dart';
import 'package:hostelzy/store.dart';
import 'package:hostelzy/locate.dart';
import 'package:hostelzy/features/photos/photo.dart';
import 'package:hostelzy/features/photos/pick.dart';
import 'package:image/image.dart' as img;
import 'package:hostelzy/data.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/kit.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hostelzy/ui/screens_tenant.dart' show filtered;
import 'package:hostelzy/ui/shell.dart';
import 'package:hostelzy/router.dart';

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
  testWidgets('onboarding: sign in, phone and role lead to Explore', (tester) async {
    final s = AppState();
    await pumpApp(tester, s);
    expect(find.text('See the'), findsOneWidget);
    await tap(tester, find.text('Get started'));
    expect(s.screen, 'login');
    // No Google sign-in in tests: it says so, and the local fallback works.
    await tap(tester, find.text('Continue with Google'));
    await tester.pump();
    expect(s.toast, 'Google sign-in works in the Android app. Use Hostelzy on this phone for now.');
    await tester.pump(const Duration(seconds: 3)); // toast gone
    await tap(tester, find.text('Use on this phone only'));
    expect(find.text('About you'), findsOneWidget);
    // F18: no sample name; the user types their own.
    expect(s.myName, '');
    await tap(tester, find.text('Debug: fill a test number'));
    await tap(tester, find.text('Continue'));
    expect((s.screen, s.toast), ('phone', 'Enter your name.'));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('myName')), matching: find.byType(TextField)), 'Asha Kumari');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Continue'));
    expect((s.screen, s.signedIn, s.account, s.phoneVerified, s.meName, s.meShort), ('role', true, null, false, 'Asha Kumari', 'Asha K.'));
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
    s..phone = '9000000001'..myName = 'Rahul Varma'; // a signed-in user (F18: no sample identity)
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
    expect(find.text('90000 00029 · not verified'), findsWidgets);
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
    s..phone = '9000000001'..myName = 'Rahul Varma'; // a signed-in user (F18: no sample identity)
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
    expect(find.text('farhath.me/hostelzy/app/j/?c=ANJ-7Q2'), findsOneWidget);
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
    s..phone = '9000000001'..myName = 'Rahul Varma'; // a signed-in user (F18: no sample identity)
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
    s..phone = '9000000001'..myName = 'Rahul Varma'; // a signed-in user (F18: no sample identity)
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

    // Invoice: a real UPI QR to Hostelzy's UPI ID (DECISIONS 2026-10-02).
    await tap(tester, find.text('HZ-INV-1024 · due 1 Nov'));
    expect(s.screen, 'oInvoice');
    expect(find.text('₹899 due 1 Nov'), findsOneWidget);
    expect((hostelzyUpiId, supportWhatsApp), ('9059790014@axl', '9059790014'));
    expect(find.text('Hostelzy · 9059790014@axl'), findsOneWidget);
    expect(find.textContaining('Sample QR'), findsNothing);
    await tap(tester, find.text('Open UPI app'));
    expect(s.lastLink?.queryParameters['pa'], '9059790014@axl');
    expect(s.lastLink?.queryParameters['am'], '899');
    await tester.pump(const Duration(seconds: 3));
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
    await tap(tester, find.text('New layout'));
    expect((w.screen, w.lRoom), ('oLayout', 204));
    expect(find.text('Hostelzy drew a new version · check and publish'), findsOneWidget);
    final l = w.layoutOf('anjani', 204)!;
    expect(l.live, isTrue); // tenants keep seeing v1 until approval
    await tap(tester, find.text('Not working').last);
    expect(l.of('fan').last.working, isFalse);
    expect(w.complaints.first.text, 'Fan 2 in room 204 marked not working.');
    expect(find.text('FAN · NOT WORKING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Publish v2'));
    expect(l.pending, isFalse);
    expect(find.text('Live for tenants'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    // Ask Hostelzy for help: saved as pending (no backend yet).
    await tap(tester, find.text('Ask Hostelzy'));
    expect(w.sheet, 'layoutReq');
    await tap(tester, find.text('Send request'));
    expect(l.request, isNull);
    await tester.enterText(find.byType(TextField).first, 'Bed C is against the washroom wall.');
    await tap(tester, find.text('Send request'));
    expect(l.request?.text, 'Bed C is against the washroom wall.');
    expect(l.request?.added, isEmpty); // no fake photos: they go on WhatsApp
    expect(find.text('Help requested · Hostelzy replies within 48 h'), findsOneWidget);

    // Hostelzy admin: sees the request, mirrors, sends v3 for approval.
    w.update(() => w.screen = 'aLayout');
    await tester.pump();
    expect(find.text('“Bed C is against the washroom wall.”'), findsOneWidget);
    final before = l.bedRect('A');
    await tap(tester, find.text('Mirror ↔'));
    expect(l.bedRect('A').left, l.w - before.right);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Send to owner'));
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
    await tester.pump();
    await tap(tester, find.text('Call it'));
    expect(s.lastLink.toString(), 'tel:+919000000009');
    await tap(tester, find.text('The owner’s phone rang'));
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
    // F18 (C1): Terms and Privacy policy are real links.
    await tap(tester, find.text('Privacy policy'));
    expect(l.lastLink.toString(), 'https://farhath.me/hostelzy/app/privacy/');
    await tap(tester, find.text('Terms'));
    expect(l.lastLink.toString(), 'https://farhath.me/hostelzy/app/terms/');
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.byType(TextField).first, 'Asha');
    await tester.enterText(find.byType(TextField).last, '5000000001');
    await tester.pump();
    // F18: Indian mobiles start with 6–9.
    await tap(tester, find.text('Continue'));
    expect((l.screen, l.toast), ('phone', 'Mobile numbers start with 6, 7, 8 or 9.'));
    await tester.enterText(find.byType(TextField).last, '9000000001');
    await tester.pump(const Duration(seconds: 3));
    // F13: no SMS codes yet; the number is typed and stays not verified.
    await tap(tester, find.text('Continue'));
    expect((l.screen, l.phoneVerified), ('role', false));
    // The OTP screen (behind phoneOtpLogin) keeps its resend timer.
    l.sendCode();
    await tester.pump();
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
    await tap(tester, find.text(fmt(hostelById('greenview').from)));
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
    expect(s.lastLink.toString(), 'https://farhath.me/hostelzy/app/privacy/');
    await tester.pump(const Duration(seconds: 3));
    // Help opens WhatsApp to Hostelzy's support number.
    await tap(tester, find.text('Help on WhatsApp'));
    expect(s.lastLink.toString(), startsWith('https://wa.me/919059790014?text='));
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
    await tap(tester, find.text('Use my location'));
    expect((m.screen, m.sheet), ('map', 'loc'));
    expect(find.text('Use your location?'), findsOneWidget);
    await tap(tester, find.text('Pick an area instead'));
    expect((m.screen, m.sheet, m.myPos), ('map', 'areas', null));
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
    expect(find.text('DRAFT'), findsOneWidget); // room 204: Hostelzy's v2 to publish
    expect(find.text('LIVE'), findsWidgets);
    await tap(tester, find.text('Room 201'));
    expect((o.screen, o.lRoom), ('oLayout', 201));

    // Team mode (B7): only a Google account with the team claim.
    o.update(() => o.screen = 'settings');
    await tester.pump();
    await tap(tester, find.text('Hostelzy team'));
    expect(o.sheet, 'team');
    expect(find.text('Sign in with your Hostelzy team Google account, then come back here.'), findsOneWidget);
    final fs = _FakeSignIn(null);
    o.update(() {
      o.signIn = fs;
      o.account = (uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com');
    });
    await tester.pump();
    await tap(tester, find.text('Open team tools'));
    await tester.pump();
    expect((o.teamUnlocked, o.toast), (false, 'asha@gmail.com isn’t a Hostelzy team account.'));
    await tester.pump(const Duration(seconds: 3));
    fs.team = true;
    await tap(tester, find.text('Open team tools'));
    await tester.pump();
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
    await tap(tester, find.text('Send to owner'));
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
    await tap(tester, find.text('New layout'));
    await tap(tester, find.text('Publish v3'));
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
    await tester.runAsync(() => o.sharePoster(inviteLink('ANJ-7Q2')));
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

  testWidgets('wide screens get a left rail; owner screens follow the selected hostel (F17)', (tester) async {
    await _loadFonts(tester);
    HostelzyShell.prototypeFrame = false;
    addTearDown(() => HostelzyShell.prototypeFrame = true);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = AppState(start: 'explore', role: 'tenant');
    await tester.pumpWidget(MaterialApp(home: AppScope(state: w, child: const HostelzyShell())));
    await tester.pump();
    // Tabs live in the rail, not in a bottom bar as well.
    expect(find.byKey(const ValueKey('rail-holds')), findsOneWidget);
    expect(find.text('Holds'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rail-holds')));
    await tester.pump();
    expect(w.screen, 'holds');
    await tester.tap(find.byKey(const ValueKey('rail-action')));
    await tester.pump();
    expect(w.sheet, 'search');
    // No rail on screens without tabs.
    w.update(() {
      w.sheet = null;
      w.screen = 'detail';
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('rail-holds')), findsNothing);
    w.dispose();

    // Owner switches to another hostel: Manage, rates and enquiries follow it.
    final o = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, o);
    o.openRates();
    o.switchHostel('saisri');
    expect(o.rateDraft, isNull);
    o.openRates();
    await tester.pump();
    expect(o.rateDraft, o.rates['saisri']);
    expect(find.textContaining(RegExp('Sai Sri Ladies Hostel', caseSensitive: false)), findsWidgets);
    expect(find.textContaining(RegExp('Anjani', caseSensitive: false)), findsNothing);
    o.dispose();
  });

  test('backend config: sample data by default, only the public anon key (F13)', () {
    expect(dataSource, 'sample');
    expect(supabaseUrl, 'https://oafiaczotlilomlvhphp.supabase.co');
    // The repo is public: the key in the app must be the anon key, never service_role.
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(supabaseAnonKey.split('.')[1])))) as Map;
    expect((claims['role'], claims['ref']), ('anon', 'oafiaczotlilomlvhphp'));
    final rs = settingsFromRows([
      {'key': 'min_supported_build', 'value': '3'},
      {'key': 'maintenance_until', 'value': ''},
    ]);
    expect((rs.minBuild, rs.maintenanceUntil), (3, ''));
    // Public pages and links all hang off one base (DECISIONS "Web address for now").
    expect(webBase, 'https://farhath.me/hostelzy/app');
    expect((privacyUrl, deleteAccountUrl), ('$webBase/privacy/', '$webBase/delete-account/'));
    expect(enquiryLink('HZ-5001'), 'https://farhath.me/hostelzy/app/r/?c=HZ-5001');
    expect(inviteLink('ANJ-7Q2'), 'https://farhath.me/hostelzy/app/j/?c=ANJ-7Q2');
    // Each page exists in the repo's app/ folder.
    for (final f in ['index.html', 'privacy/index.html', 'terms/index.html', 'delete-account/index.html', 'r/index.html', 'j/index.html']) {
      expect(File('../app/$f').existsSync(), isTrue, reason: f);
    }
  });

  testWidgets('live hostels from Supabase replace the samples for tenants (F13)', (tester) async {
    final l = listingsFromRows([
      {
        'id': '10000000-0000-0000-0000-000000000001',
        'name': 'Real Test PG',
        'gender': 'Men',
        'area': 'Kondapur',
        'lat': 17.46,
        'lng': 78.36,
        'owner_name': 'Imran',
        'food': true,
        'ac': false,
        'only_ac': false,
        'instant': false,
        'tags': ['Wi-Fi'],
        'terms': {'advance': 5000, 'maintenance': 1000, 'noticeDays': 15, 'dueOnJoining': false, 'electricityExtra': true},
        'upi_id': '',
        'upi_name': '',
        'rate_cards': [
          {'ac': false, 'share': 2, 'rent': 9000},
          {'ac': false, 'share': 3, 'rent': 7500},
        ],
        'rooms': [
          {
            'number': 102, 'label': null, 'floor': 1, 'share': 3, 'rent': 7500, 'ac': false, 'ac_repair': false, 'bath': 'Attached',
            'beds': [
              {'letter': 'B', 'spot': 'Door side', 'state': 'soon', 'free_from': '2026-10-12'},
              {'letter': 'A', 'spot': 'Window side', 'state': 'free', 'free_from': null},
              {'letter': 'C', 'spot': '', 'state': 'booked', 'free_from': null},
            ],
          },
          {'number': 101, 'label': '101A', 'floor': 1, 'share': 2, 'rent': 9000, 'ac': false, 'bath': 'Shared', 'beds': []},
        ],
        'layouts': [
          {
            'room': 102, 'stage': 'published', 'version': 3, 'w': 12, 'h': 10, 'updated_at': '2026-09-30T10:00:00Z',
            'beds': {'A': [2, 3], 'B': [8, 3], 'C': [8, 3]},
            'items': [
              {'id': 'd1', 'kind': 'door', 'x': 0, 'y': 4, 'w': 0.5, 'h': 3, 'facing': 'E'},
              {'id': 'f1', 'kind': 'fan', 'x': 6, 'y': 5, 'w': 1, 'h': 1, 'working': false},
            ],
            'bunks': {'C': 'B'},
          },
          {'room': 101, 'stage': 'draft', 'version': 1, 'w': 10, 'h': 10, 'beds': {}, 'items': []},
        ],
      },
    ]);
    final lay = l.layouts.values.single;
    expect(lay.keys, [102]); // drafts never reach tenants
    final r102 = lay[102]!;
    expect((r102.version, r102.w, r102.beds['A'], r102.upperOn('B'), r102.drawn), (3, 12.0, const Offset(2, 3), 'C', '30 Sep'));
    expect(r102.items.map((i) => '${i.kind} ${i.working}'), ['door true', 'fan false']);
    final h = l.hostels.single;
    expect((h.name, h.from, h.owner, h.terms.advance, h.terms.dueOnJoining, h.rating), ('Real Test PG', 7500, 'Imran', 5000, false, 0.0));
    final rs = l.rooms[h.id]!;
    expect(rs.map((r) => r.label), ['101A', '102']);
    expect(rs[1].beds.map((b) => '${b.id} ${b.state} ${b.soon}'), ['102-A free ', '102-B soon 12 Oct', '102-C booked ']);
    expect(l.rates[h.id], {'non2': 9000, 'non3': 7500});

    final s = AppState(start: 'explore', role: 'tenant');
    s.applyListings(l);
    expect(filtered(s).map((x) => x.name), ['Real Test PG']);
    expect(posOf(h), (17.46, 78.36));
    expect(hostelById('anjani').name, 'Anjani Residency'); // owner/resident samples still work
    await pumpApp(tester, s);
    expect(find.text('Real Test PG'), findsWidgets);
    expect(find.text('Anjani Residency'), findsNothing);
    // No UPI ID yet: say so instead of opening an empty UPI link.
    s.lastLink = null;
    s.payByUpi(Payment(id: 'p1', kind: 'advance', hid: h.id, who: 'You', what: 'Advance', bed: '102-A', amt: 5000, note: 'HZ'));
    expect(s.lastLink, isNull);
    expect(s.toast, 'Imran hasn’t added a UPI ID yet. Ask them on WhatsApp.');
    // Remote switch: a too-old build has to update.
    s.applySettings((minBuild: 99, maintenanceUntil: ''));
    expect((s.screen, s.gateKind), ('gate', 'update'));
    s.dispose();
    resetSampleData();
    expect(browsable.length, 6);

    // Real APK, Supabase reachable but no hostels yet: an honest empty state, no samples.
    final e = AppState(start: 'explore', role: 'tenant');
    e.applyListings((hostels: const [], rooms: const {}, rates: const {}, pos: const {}, upi: const {}, layouts: const {}));
    await pumpApp(tester, e);
    expect(find.text('No hostels in this area yet'), findsOneWidget);
    expect(find.text('Anjani Residency'), findsNothing);
    await tap(tester, find.text('Pick another area'));
    expect(e.sheet, 'areas');
    e.dispose();
    resetSampleData();
  });

  testWidgets('push: explainer, then Android asks; allowed gets a token, denied says how to fix (F13)', (tester) async {
    for (final allow in [true, false]) {
      final s = AppState(start: 'settings', role: 'tenant');
      final fake = _FakePush(allow);
      s.push = fake;
      s.update(() => s.notif.updateAll((k, v) => false));
      await pumpApp(tester, s);
      await tap(tester, find.text('Rent reminders').first);
      expect(find.text('Turn on notifications?'), findsOneWidget);
      expect(fake.asked, 0); // the app's explainer comes before Android's prompt
      await tap(tester, find.text('Turn on'));
      await tester.pump();
      expect(fake.asked, 1);
      if (allow) {
        expect((s.pushToken, s.notif['rent'], s.notif['beds']), ('fcm-token', true, false));
        expect(s.toast, 'Notifications allowed. Hostelzy starts sending them once your account is online.');
      } else {
        expect((s.pushToken, s.notif['rent']), (null, false));
        expect(s.toast, 'Notifications are off. Turn them on in your phone’s settings → Apps → Hostelzy.');
      }
      await tester.pump(const Duration(seconds: 3));
      s.dispose();
    }
  });

  testWidgets('Sign in with Google: account, phone not verified, profile saved (F13)', (tester) async {
    final s = AppState(start: 'login');
    final data = _FakeData();
    s.signIn = _FakeSignIn(null);
    s.data = data;
    await pumpApp(tester, s);
    expect(find.text('Continue with Google'), findsOneWidget);
    // Not switched on in Firebase yet: honest message, nothing pretends.
    (s.signIn as _FakeSignIn).fail = SignInFail.notSetUp;
    await tap(tester, find.text('Continue with Google'));
    await tester.pump();
    expect((s.screen, s.account), ('login', null));
    expect(s.toast, 'Google sign-in isn’t switched on yet. Use Hostelzy on this phone for now.');
    (s.signIn as _FakeSignIn).fail = SignInFail.cancelled;
    await tap(tester, find.text('Continue with Google'));
    await tester.pump();
    expect(s.toast, 'Sign-in cancelled.');
    await tester.pump(const Duration(seconds: 3)); // toast gone
    // Works.
    (s.signIn as _FakeSignIn).fail = null;
    await tap(tester, find.text('Continue with Google'));
    await tester.pump();
    expect((s.screen, s.account?.email), ('phone', 'asha@gmail.com'));
    expect(find.textContaining('Signed in as asha@gmail.com.'), findsOneWidget);
    expect(find.textContaining('“not verified”'), findsOneWidget);
    // The Google name is prefilled but editable.
    expect(s.myName, 'Asha K');
    await tester.enterText(find.byType(TextField).last, '9000000007');
    await tester.pump();
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('I run a hostel'));
    await tester.pump();
    expect(data.profile, (name: 'Asha K', email: 'asha@gmail.com', phone: '9000000007', role: 'owner'));
    // Push token goes to the account once signed in.
    s.push = _FakePush(true);
    await s.enablePush();
    expect(data.tokens, ['fcm-token']);
    // Log out signs out of Google too.
    s.logOut();
    expect(((s.signIn as _FakeSignIn).signedOut, s.account), (true, null));
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  testWidgets('back button, stay logged in, own name and phone (F18)', (tester) async {
    // Android back: sheet → previous screen → home tab → "press again to exit".
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    s.go('detail');
    s.update(() => s.sheet = 'search');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect((s.screen, s.sheet), ('detail', null));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(s.screen, 'explore');
    s.tab('holds');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(s.screen, 'explore');
    expect(s.handleBack(), isFalse);
    expect(s.toast, 'Press back again to exit');
    expect(s.handleBack(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    s.dispose();

    // Sign up once; reopening the app keeps you signed in on your own home.
    final mem = MemoryStore();
    final a = AppState();
    expect((a.screen, a.signedIn), ('welcome', false));
    a.store = mem;
    a.continueOnPhone();
    a.update(() {
      a.myName = '  Asha Kumari ';
      a.phone = '9876543210';
    });
    a.savePhone();
    a.update(() {
      a.role = 'tenant';
      a.screen = 'explore';
      a.saved['nest42'] = true;
      a.holds = [Hold(id: 'h9', hid: 'saisri', bed: a.rooms['saisri']!.first.beds.first.id, room: a.rooms['saisri']!.first.n, opt: 'free', start: a.now, status: 'waiting')];
    });
    expect((mem.data['name'], mem.data['phone'], mem.data['signedIn'], (mem.data['saved'] as List).join()), ('Asha Kumari', '9876543210', true, 'nest42'));
    a.dispose();

    final b = AppState();
    b.store = mem;
    b.restore(await mem.load());
    final bed = b.findBed('saisri', b.holds.single.bed).b!;
    expect((b.screen, b.signedIn, b.meName, b.phone, b.saved['nest42'], bed.mine, bed.state), ('explore', true, 'Asha Kumari', '9876543210', true, true, 'held'));
    await pumpApp(tester, b);
    b.tab('me');
    await tester.pump();
    expect(find.text('Asha Kumari'), findsOneWidget);
    expect(find.textContaining('+91 98765 43210'), findsOneWidget);
    // Logging out forgets everything on this phone.
    b.logOut();
    await tester.pump();
    expect((mem.data.isEmpty, b.meName, b.phone, b.holds.isEmpty, b.saved.isEmpty, bed.mine, b.screen), (true, '', '', true, true, false, 'welcome'));
    b.dispose();

    // No sample identity: Me says "Add your number", never a dummy one.
    final c = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, c);
    expect(find.textContaining('Add your number'), findsOneWidget);
    expect(find.textContaining('90000 00001'), findsNothing);
    expect(find.text('Rahul Varma'), findsNothing);
    c.dispose();
  });

  testWidgets('gated roles, no fake contacts, small phones, crash guards (F18)', (tester) async {
    // Play Store build: no sample people, and roles that need someone else are gated.
    AppState.samples = false;
    AppState.demoBanner = true;
    addTearDown(() {
      AppState.samples = true;
      AppState.demoBanner = false;
    });
    final s = AppState(start: 'role', role: 'tenant');
    expect([s.residents, s.enquiries, s.cases, s.signups, s.payments, s.complaints, s.reqs].map((l) => l.length), [0, 0, 0, 0, 0, 0, 0]);
    await pumpApp(tester, s);
    await tap(tester, find.text('I live in a Hostelzy PG'));
    expect((s.screen, s.roleGate), ('roleGate', 'resident'));
    expect(find.text('Ask your owner to add you'), findsOneWidget);
    s.update(() => s.phone = '9876543210');
    await tester.pump();
    expect(find.text('+91 98765 43210'), findsOneWidget);
    await tap(tester, find.text('Send it to your owner on WhatsApp'));
    expect(s.lastLink.toString(), contains('98765%2043210'));
    await tester.pump(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tap(tester, find.text('I run a hostel'));
    expect(find.text('List your hostel'), findsOneWidget);
    await tap(tester, find.text('Request a visit').last);
    expect(s.toast, 'Enter your hostel’s name.');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('gateHostel')), matching: find.byType(TextField)), 'Sri Sai Men’s PG');
    await tap(tester, find.text('Kondapur'));
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Request a visit').last);
    expect(s.lastLink.toString(), startsWith('https://wa.me/919059790014'));
    expect(Uri.decodeComponent(s.lastLink.toString()), contains('Area: Kondapur'));
    await tester.pump(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tap(tester, find.text('I live in a Hostelzy PG'));
    await tap(tester, find.text('Not in a PG yet? Find a bed'));
    expect((s.screen, s.role), ('explore', 'tenant'));
    // The demo APK says it is on sample listings; the real one never does.
    expect(find.text('Sample data. Nothing you do here is real.'), findsOneWidget);
    s.update(() => AppState.demoBanner = false);
    await tester.pump();
    expect(find.text('Sample data. Nothing you do here is real.'), findsNothing);
    // Team mode opens the owner screens.
    s.update(() => s.teamUnlocked = true);
    expect(s.canOwner, isTrue);

    // No WhatsApp, calls or UPI to sample numbers / IDs.
    s.lastLink = null;
    s.whatsapp(ownerPhones['anjani']!, 'Hi');
    expect((s.lastLink, s.toast), (null, 'This is a sample listing, so there’s no real number yet.'));
    s.call(ownerPhones['saisri']!);
    expect(s.lastLink, isNull);
    s.payByUpi(Payment(id: 'x', kind: 'advance', hid: 'anjani', who: 'You', what: 'Advance', bed: '204-D', amt: 3000, note: 'HZ'));
    expect((s.lastLink, s.toast), (null, 'This is a sample listing, so it has no real UPI ID. Don’t pay it.'));
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
    AppState.samples = true;

    // Small phone with the keyboard open: sign-up, role and permission screens scroll.
    HostelzyShell.prototypeFrame = false;
    addTearDown(() => HostelzyShell.prototypeFrame = true);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    for (final start in ['phone', 'login', 'role', 'perm', 'oMore']) {
      final m = AppState(start: start, role: start == 'oMore' ? 'owner' : 'tenant');
      await tester.pumpWidget(MaterialApp(home: AppScope(state: m, child: const HostelzyShell())));
      await tester.pump();
      final err = tester.takeException();
      expect(err == null ? null : '$start: $err', isNull);
      m.dispose();
    }
    tester.view.resetViewInsets();
    // No keyboard: Manage's header buttons and the photo screens fit too.
    for (final start in ['oMore', 'oPhotos', 'gallery']) {
      final m = AppState(start: start, role: start == 'gallery' ? 'tenant' : 'owner');
      await tester.pumpWidget(MaterialApp(home: AppScope(state: m, child: const HostelzyShell())));
      await tester.pump();
      final err = tester.takeException();
      expect(err == null ? null : '$start: $err', isNull);
      m.dispose();
    }
    tester.view.reset();

    // Crash guards.
    final c = AppState(start: 'explore', role: 'tenant');
    expect(hostelById('gone').name, 'Hostel no longer listed');
    hostels.add(Hostel(id: 'tagless', name: 'Tagless PG', gender: 'Men', area: 'Ameerpet', from: 5000, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: const {}, x: 50, y: 50, tags: const ['Wi-Fi']));
    c.rooms['tagless'] = mkRooms(hostels.last, 6);
    c.rates['tagless'] = seedRates(hostels.last);
    c.stats['tagless'] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
    await pumpApp(tester, c);
    c.update(() {
      c.hid = 'tagless';
      c.screen = 'detail';
    });
    await tester.pump();
    expect(find.text('Wi-Fi'), findsOneWidget); // one tag, no RangeError
    // Owner opens the editor for a room that has no layout yet: one is made.
    final room = c.rooms['anjani']!.last;
    c.layouts['anjani']!.remove(room.n);
    c.update(() => c.role = 'owner');
    c.openLayout(room.n, editor: true);
    await tester.pump();
    expect((c.screen, c.layoutOf('anjani', room.n) != null), ('aLayout', true));
    // Go live needs at least one room with beds.
    c.openAddHostel();
    expect(c.goLiveLeft, isNot(contains('At least one room with beds')));
    for (final f in c.draft.floors) {
      f.noBeds = true;
    }
    expect(c.goLiveLeft, contains('At least one room with beds'));
    c.dispose();
    resetSampleData();
  });

  testWidgets('map v2: area picker, search this area, use my location (F18)', (tester) async {
    final s = AppState(start: 'map', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('All areas'), findsOneWidget);
    // Pick an area: only hostels there, on the map and in Explore.
    await tap(tester, find.byKey(const ValueKey('mapArea')));
    expect(s.sheet, 'areas');
    expect(find.text('Soon'), findsWidgets); // areas with no hostels yet
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('areaQ')), matching: find.byType(TextField)), 'kond');
    await tester.pump();
    expect(find.text('Ameerpet'), findsNothing);
    await tap(tester, find.text('Kondapur'));
    expect((s.mapArea, s.sheet), ('Kondapur', null));
    expect(filtered(s).map((h) => h.area).toSet(), {'Kondapur'});
    expect(find.text(fmt(hostelById('anjani').from)), findsNothing); // Madhapur pin hidden
    s.tab('explore');
    await tester.pump();
    expect(find.text('Anjani Residency'), findsNothing);
    s.tab('map');
    await tester.pump();

    // Use my location: explainer first, then the map centres on you and sorts by distance.
    final loc = _FakeLocator((17.4610, 78.3610));
    s.locator = loc;
    await tap(tester, find.text('Use my location'));
    expect((s.sheet, loc.asked), ('loc', 0));
    await tap(tester, find.text('Allow location'));
    await tester.pump();
    expect((loc.asked, s.myPos, s.mapArea, s.sortBy, s.mapAreaLabel), (1, (17.4610, 78.3610), null, 'near', 'Near me'));
    expect(find.byKey(const ValueKey('youAreHere')), findsOneWidget);
    expect(find.textContaining('km from you'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    // Denied: no position is invented; the area picker opens instead.
    final d = AppState(start: 'map', role: 'tenant')..locator = _FakeLocator(null, LocateFail.denied);
    await d.useMyLocation();
    expect((d.myPos, d.sheet, d.toast), (null, 'areas', 'No problem. Pick an area instead.'));
    d.dispose();

    // Search this area: after a pan, hostels within 3 km of the new centre.
    s.mapPanned(posOf(hostelById('lakshmi')));
    await tester.pump();
    await tap(tester, find.text('Search this area'));
    expect((s.mapAreaLabel, s.mapMoved), ('This area', false));
    expect(filtered(s).map((h) => h.id), ['lakshmi']);
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  testWidgets('owner edits and publishes layouts without approval (F18)', (tester) async {
    final s = AppState(start: 'oLayouts', role: 'owner');
    final room = s.rooms['anjani']!.last;
    s.layouts['anjani']!.remove(room.n);
    await pumpApp(tester, s);
    expect(find.text('You edit and publish your own layouts. Want help? The Hostelzy team can draw one for you.'), findsOneWidget);
    await tap(tester, find.text('No layout 1'));
    expect(find.text('Room ${room.label}'), findsOneWidget);
    // No layout yet → Create a layout.
    await tap(tester, find.text('Room ${room.label}'));
    expect(s.screen, 'oCreate');
    expect(find.text('Create a layout'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('clLen')), matching: find.byType(TextField)), '3');
    await tap(tester, find.text('Start drawing'));
    expect(s.toast, 'Enter the room size in feet (6 to 60).');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('clLen')), matching: find.byType(TextField)), '16');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Start drawing'));
    final l = s.layoutOf('anjani', room.n)!;
    expect((s.screen, s.edOwner, l.w, l.live), ('aLayout', true, 16.0, false));
    expect(s.liveLayout('anjani', room.n), isNull); // tenants: "Layout coming soon"
    // Publish: live straight away, no approval.
    await tap(tester, find.text('Publish'));
    expect((s.screen, l.live, l.pending), ('oPublished', true, false));
    expect(find.text('Live for tenants'), findsOneWidget);
    expect(s.liveLayout('anjani', room.n), isNotNull);
    // Undo: hidden again.
    await tap(tester, find.text('Undo publish · hide it again'));
    expect((l.live, s.liveLayout('anjani', room.n)), (false, null));
    await tester.pump(const Duration(seconds: 3));

    // Editing a live layout: tenants keep v1 until the owner publishes v2.
    final r101 = s.layoutOf('anjani', 101)!;
    expect((r101.live, r101.pending), (true, false));
    s.openLayout(101, editor: true, owner: true);
    await tester.pump();
    final w0 = r101.w;
    await tap(tester, find.byKey(const ValueKey('w+')));
    expect(s.liveLayout('anjani', 101)!.w, w0);
    await tap(tester, find.text('Publish'));
    expect((r101.version, s.liveLayout('anjani', 101)!.w), (2, w0 + 1));
    await tap(tester, find.text('Undo publish · go back to v1'));
    expect((r101.version, r101.w, s.liveLayout('anjani', 101)!.w), (1, w0, w0));
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  testWidgets('smaller fixes: holds, walk-ins, saved list, prices, UPI ID, team sign-in (F18)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.update(() => s.phone = '9876543210');
    // A bed that was "free soon" goes back to "free soon" when released (D10).
    final soon = s.rooms['saisri']!.expand((r) => r.beds).firstWhere((b) => b.state == 'soon');
    s.update(() {
      s.hid = 'saisri';
      s.bed = soon.id;
    });
    s.placeHold('free');
    expect(soon.state, 'held');
    s.releaseHold(s.holds.last);
    expect((soon.state, soon.mine, s.holds.last.status), ('soon', false, 'released'));
    // At most two active holds (D12).
    final free = s.rooms['nest42']!.expand((r) => r.beds).where((b) => b.state == 'free').take(3).toList();
    for (final b in free) {
      s.update(() {
        s.hid = 'nest42';
        s.bed = b.id;
      });
      s.placeHold('free');
    }
    expect((s.activeHolds, free[2].state, s.toast), (2, 'free', 'You can hold 2 beds at a time. Release one in Holds first.'));
    // The owner releasing the bed updates the tenant's hold record too (F9).
    s.ownerReleaseBed('nest42', free[0]);
    expect((free[0].state, s.holds.firstWhere((h) => h.bed == free[0].id).status), ('free', 'released'));
    // Walk-in holds free themselves after an hour (F8).
    final w = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free');
    s.holdWalkIn('anjani', w);
    expect(w.state, 'held');
    s.walkIns['anjani|${w.id}'] = 0;
    await tester.pump(const Duration(seconds: 2)); // the app's 1-second ticker
    expect(w.state, 'free');

    // Saved hostels list (D9).
    s.update(() => s.saved['orchid'] = true);
    await pumpApp(tester, s);
    s.tab('me');
    await tester.pump();
    await tap(tester, find.text('Saved hostels · 1'));
    expect(s.screen, 'saved');
    expect(find.text('Orchid Women\'s PG'), findsOneWidget);
    // Fair Play hours run from when the case opened (F4).
    final c = FairCase(id: 'x', hid: 'anjani', title: 't', signal: 's', status: 'new', openedAt: s.now - 10 * 3600000);
    expect(c.hoursLeftAt(s.now).round(), 38);
    // UPI IDs look like name@bank (F11).
    expect((validUpiId('srinivas@okaxis'), validUpiId('9059790014@axl'), validUpiId('srinivas'), validUpiId('a@1')), (true, true, false, false));
    await tester.pump(const Duration(seconds: 3));
    s.dispose();

    // Owner: a ₹0 price can't be saved; "from ₹X" follows the rate card (D8).
    final o = AppState(start: 'oToday', role: 'owner');
    o.openRates();
    final k0 = o.rateDraft!.keys.first;
    o.rateDraft![k0] = 0;
    o.saveRates();
    expect(o.toast, startsWith('Set a price for'));
    o.openRates();
    final cheapest = o.fromOf(hostelById('anjani'));
    for (final k in o.rateDraft!.keys.toList()) {
      o.rateDraft![k] = o.rateDraft![k]! + 500;
    }
    o.saveRates();
    expect(o.fromOf(hostelById('anjani')), cheapest + 500);
    // No passcode exists any more (B7).
    o.update(() => o.account = null);
    await o.checkTeam();
    expect(o.toast, 'Sign in with your Hostelzy team Google account first.');
    o.dispose();
  });

  test('B7: photos are cropped and compressed on the phone', () {
    Uint8List png(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));
    final a = img.decodeJpg(prepPhoto(png(1000, 1000), '4:3')!)!;
    expect((a.width, a.height), (1000, 750));
    final b = img.decodeJpg(prepPhoto(png(4000, 3000), 'free')!)!;
    expect((b.width, b.height), (1600, 1200));
    final c = img.decodeJpg(prepPhoto(png(900, 1200), '1:1')!)!;
    expect((c.width, c.height), (900, 900));
    expect(prepPhoto(Uint8List.fromList([1, 2, 3]), '4:3'), isNull);
    expect(photoUrl('https://p.supabase.co', 'h1/a.jpg'), 'https://p.supabase.co/storage/v1/object/public/hostel-photos/h1/a.jpg');
  });

  testWidgets('B7: owner adds, orders and removes photos; tenants see the gallery', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner');
    final fake = _FakePhotos();
    s.data = fake;
    s.picker = _FakePicker(1200, 1200);
    await pumpApp(tester, s);
    await tap(tester, find.byKey(const ValueKey('managePhotos')));
    expect(s.screen, 'oPhotos');
    expect(find.text('0 of 8 minimum'), findsOneWidget);
    expect(find.text('Drag to reorder. The first is the cover.'), findsOneWidget);
    // Add → crop (square, cover) → Use: uploads a compressed JPEG.
    await tap(tester, find.byKey(const ValueKey('addPhoto')));
    expect((s.screen, s.cropCover, s.cropLabel), ('oCrop', true, 'Front'));
    await tap(tester, find.text('Square'));
    await tap(tester, find.byKey(const ValueKey('useCrop')));
    await tester.pump();
    expect(s.screen, 'oPhotos');
    expect(fake.uploaded.length, 1);
    final up = img.decodeJpg(fake.uploaded.single)!;
    expect((up.width, up.height), (1200, 1200));
    expect(find.text('COVER'), findsOneWidget);
    expect(find.text('1 of 8 minimum'), findsOneWidget);
    // Second photo: a washroom; the upload fails, then Retry works.
    fake.failNext = true;
    await tap(tester, find.byKey(const ValueKey('addPhoto')));
    expect(s.cropCover, isFalse);
    await tap(tester, find.text('Front ▾'));
    await tap(tester, find.text('Room ▾'));
    expect(s.cropLabel, 'Washroom');
    await tap(tester, find.byKey(const ValueKey('useCrop')));
    await tester.pump();
    expect(find.text('Failed · Retry'), findsOneWidget);
    await tap(tester, find.text('Failed · Retry'));
    await tester.pump();
    expect(find.text('Failed · Retry'), findsNothing);
    expect(s.photosIn(s.ownHid, 'Hostel').map((p) => p.label), ['Front', 'Washroom']);
    // Make the washroom the cover: it moves first and the order is saved.
    await tap(tester, find.text('Washroom'));
    expect(s.sheet, 'photo');
    await tap(tester, find.text('Make it the cover'));
    await tester.pump();
    expect(s.photosIn(s.ownHid, 'Hostel').map((p) => p.label), ['Washroom', 'Front']);
    expect(fake.lastOrder, ['ph1', 'ph0']);
    expect(fake.lastCover, 'ph1');
    // Remove the old front photo.
    await tap(tester, find.text('Front'));
    await tap(tester, find.text('Remove photo'));
    await tester.pump();
    expect(fake.rows.map((p) => p.id), ['ph1']);
    await tap(tester, find.text('Done'));
    expect(s.screen, 'oMore');

    // Sample data never pretends to upload.
    final demo = AppState(start: 'oPhotos', role: 'owner');
    demo.picker = _FakePicker(400, 300);
    await pumpApp(tester, demo);
    await tap(tester, find.byKey(const ValueKey('addPhoto')));
    await tap(tester, find.byKey(const ValueKey('useCrop')));
    await tester.pump();
    expect(demo.toast, 'Photos upload in the real Hostelzy app. This is sample data.');
    expect(demo.photosOf[demo.ownHid] ?? const [], isEmpty);
    await tester.pump(const Duration(seconds: 3));

    // A tenant opens the hostel: cover, "See 2 photos", the gallery.
    fake.rows
      ..clear()
      ..addAll([
        (id: 'a', path: 'x/a.jpg', url: 'https://x.test/a.jpg', label: 'Front', ord: 0, cover: true),
        (id: 'b', path: 'x/b.jpg', url: 'https://x.test/b.jpg', label: '3 sharing', ord: 1, cover: false),
      ]);
    final t = AppState(start: 'explore', role: 'tenant');
    t.data = fake;
    await pumpApp(tester, t);
    t.update(() {
      t.hid = 'anjani';
      t.screen = 'detail';
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('See 2 photos'), findsOneWidget);
    await tap(tester, find.text('See 2 photos'));
    expect(t.screen, 'gallery');
    expect(find.text('1 / 2 · Front'), findsOneWidget);
    expect(find.text('Rooms 1'), findsOneWidget);
    await tap(tester, find.text('Rooms 1'));
    expect(find.text('1 / 1 · 3 sharing'), findsOneWidget);
    await tap(tester, find.text('All 2'));
    expect(find.text('Photos by the owner'), findsOneWidget);
    s.dispose();
    demo.dispose();
    t.dispose();
  });

  test('B6: live rows map server statuses to the app', () {
    final l = liveFromRows(
      holds: [
        {'id': 'h1', 'hostel_id': 'x', 'opt': 'advance', 'status': 'waiting', 'ref': 'HZ-5002', 'started_at': '2026-10-02T10:00:00Z', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
        {'id': 'h2', 'hostel_id': 'x', 'opt': 'free', 'status': 'expired', 'ref': 'HZ-5003', 'started_at': '2026-10-02T09:00:00Z', 'beds': {'letter': 'B', 'rooms': {'number': 204, 'label': '204A'}}},
      ],
      enquiries: [
        {'ref': 'HZ-5001', 'name': 'Kiran', 'phone': '9111111111', 'hostel_id': 'x', 'bed': '101-A', 'created_at': '2026-10-02T08:00:00Z', 'source': 'Hostel page · Ask on WhatsApp', 'msg': 'Hi', 'contacted': false},
      ],
      payments: [
        {'id': 'p1', 'hostel_id': 'x', 'kind': 'advance', 'amount': 3000, 'note': 'HZ-5002', 'hold_id': 'h1', 'status': 'pending', 'utr': null, 'created_at': '2026-10-02T10:00:00Z', 'confirmed_at': null, 'holds': {'beds': {'letter': 'A', 'rooms': {'number': 101}}}},
      ],
      complaints: [
        {'id': '0000002a-0000-0000-0000-000000000000', 'author_id': 'me', 'bed': '101-A', 'cat': 'WiFi', 'body': 'Slow', 'status': 'Fixed', 'note': 'Router reset', 'created_at': '2026-10-01T08:00:00Z'},
      ],
      me: 'me',
    );
    expect(l.holds.map((h) => '${h.bed} ${h.room} ${h.opt} ${h.status} ${h.ref}'), ['101-A 101 book waiting HZ-5002', '204A-B 204 free released HZ-5003']);
    expect(l.expired, {'h2'});
    expect((l.enquiries.single.ref, l.enquiries.single.bed, l.enquiries.single.hid), ('HZ-5001', '101-A', 'x'));
    final p = l.payments.single;
    expect((p.status, p.what, p.bed, p.holdId, p.utr), ('due', 'Advance for bed 101-A', '101-A', 'h1', null));
    final c = l.complaints.single;
    expect((c.id, c.status, c.mine, c.date), (42, 'Resolved', true, '1 Oct'));
  });

  test('B6: signed in on Supabase, lists are live and refetch on Realtime changes', () async {
    final s = AppState(start: 'oToday', role: 'owner');
    final empty = liveFromRows(holds: [], enquiries: [], payments: [], complaints: []);
    final fake = _FakeLive(empty);
    s.data = fake;
    // Not signed in with Google: nothing is fetched.
    await s.startLive();
    expect(fake.fetches, 0);
    s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@x.in');
    await s.startLive();
    expect((fake.fetches, fake.askedAs), (1, 'fb-owner'));
    expect([s.enquiries.length, s.holds.length, s.payments.length, s.complaints.length], [0, 0, 0, 0]); // samples replaced, never mixed
    // A tenant enquires: Realtime says "enquiries changed"; three quick changes, one refetch.
    fake.rows = liveFromRows(holds: [], enquiries: [
      {'ref': 'HZ-5009', 'name': 'Asha', 'phone': '9000000001', 'hostel_id': 'x', 'created_at': '2026-10-02T11:00:00Z'},
    ], payments: [], complaints: []);
    fake.ctrl..add('enquiries')..add('holds')..add('enquiries');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(fake.fetches, 2);
    expect(s.enquiries.single.ref, 'HZ-5009');
    // Logged out: no more updates.
    s.stopLive();
    fake.ctrl.add('enquiries');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(fake.fetches, 2);
    s.dispose();
  });

  testWidgets('go_router deep links: enquiry and invite links open the right place', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    final r = appRouter(s, (_) => const HostelzyShell(bare: true));
    addTearDown(r.dispose);
    await _loadFonts(tester);
    tester.view.physicalSize = const Size(410, 864);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: r, builder: (c, child) => AppScope(state: s, child: child!)));
    await tester.pump();
    expect(find.byType(HostelzyShell), findsOneWidget);
    // An owner opens a tenant's enquiry link: Today, with that enquiry open.
    s.update(() => s.screen = 'oRent');
    r.go('/r?c=hz-4821');
    await tester.pumpAndSettle();
    expect((s.screen, s.sheet, s.enqRef), ('oToday', 'enq', 'HZ-4821'));
    expect(r.routerDelegate.currentConfiguration.uri.path, '/');
    // Not this account's code: say so, stay put.
    s.update(() => s.sheet = null);
    r.go('/hostelzy/app/r?c=HZ-9999');
    await tester.pumpAndSettle();
    expect((s.screen, s.toast), ('oToday', 'HZ-9999 isn’t in this account. Sign in with the account that sent or got it.'));
    r.go('/r?c=nonsense');
    await tester.pumpAndSettle();
    expect(s.toast, 'That link has no HZ code.');
    // A resident invite is kept for sign-up.
    r.go('/j?c=anj-7q2');
    await tester.pumpAndSettle();
    expect((s.pendingInvite, s.toast), ('ANJ-7Q2', 'Invite ANJ-7Q2 saved. Sign in and pick “I live in a Hostelzy PG”.'));
    // Any other link just opens the app.
    r.go('/somewhere/else');
    await tester.pumpAndSettle();
    expect(find.byType(HostelzyShell), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });
}

class _FakePush implements Push {
  _FakePush(this.allow);
  final bool allow;
  int asked = 0;
  @override
  Future<PushAsk> ask() async {
    asked++;
    return allow ? PushAsk.allowed : PushAsk.denied;
  }

  @override
  Future<String?> token() async => 'fcm-token';
  @override
  Stream<(String, String)> get foreground => const Stream.empty();
}

class _FakeSignIn implements SignIn {
  _FakeSignIn(this.fail);
  SignInFail? fail;
  bool signedOut = false;
  @override
  bool get available => true;
  @override
  Future<(Account?, SignInFail?)> google() async => fail != null ? (null, fail) : ((uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com'), null);
  @override
  Future<String?> idToken() async => 'id-token';
  bool team = false;
  @override
  Future<bool> isTeam() async => team;
  @override
  Account? get current => null;
  @override
  Future<void> signOut() async => signedOut = true;
}

class _FakeData extends SampleRepo {
  ({String name, String email, String phone, String role})? profile;
  final tokens = <String>[];
  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) async => profile = (name: name, email: email, phone: phone, role: role);
  @override
  Future<void> savePushToken(String token) async => tokens.add(token);
}

/// B7: Storage stand-in. [failNext] makes the next upload fail once.
class _FakePhotos extends SampleRepo {
  final rows = <HostelPhoto>[];
  final uploaded = <Uint8List>[];
  bool failNext = false;
  List<String>? lastOrder;
  String? lastCover;
  @override
  Future<List<HostelPhoto>> photos(String hid) async => sortPhotos(rows);
  @override
  Future<HostelPhoto> addPhoto(String hid, Uint8List jpg, {required String label, required int ord, required bool cover}) async {
    if (failNext) {
      failNext = false;
      throw Exception('network');
    }
    uploaded.add(jpg);
    final p = (id: 'ph${rows.length}', path: '$hid/ph${rows.length}.jpg', url: 'https://x.test/ph${rows.length}.jpg', label: label, ord: ord, cover: cover);
    rows.add(p);
    return p;
  }

  @override
  Future<void> removePhoto(HostelPhoto p) async => rows.removeWhere((x) => x.id == p.id);
  @override
  Future<void> savePhotoOrder(List<HostelPhoto> ordered, String coverId) async {
    lastOrder = [for (final p in ordered) p.id];
    lastCover = coverId;
  }
}

class _FakePicker implements PhotoPicker {
  _FakePicker(this.w, this.h);
  final int w, h;
  @override
  Future<Uint8List?> pick() async => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));
}

/// B6: a Supabase stand-in with live rows and a Realtime change stream.
class _FakeLive extends SampleRepo {
  _FakeLive(this.rows);
  LiveRows rows;
  int fetches = 0;
  String? askedAs;
  final ctrl = StreamController<String>.broadcast();
  @override
  Future<LiveRows?> live({String? me}) async {
    fetches++;
    askedAs = me;
    return rows;
  }

  @override
  Stream<String> changes() => ctrl.stream;
}

class _FakeLocator implements Locator {
  _FakeLocator(this.pos, [this.fail]);
  final (double, double)? pos;
  final LocateFail? fail;
  int asked = 0;
  @override
  Future<((double, double)?, LocateFail?)> locate() async {
    asked++;
    return (pos, fail);
  }
}
