import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/app_config.dart' show dataSource, supabaseUrl, supabaseAnonKey, hostelzyUpiId, supportWhatsApp, webBase, privacyUrl, deleteAccountUrl, enquiryLink, inviteLink;
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart' show filtered;
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/owner/owner_today_screen.dart' show allRequests;
import 'package:hostelzy/features/photos/photo.dart';
import 'package:hostelzy/features/photos/pick.dart';
import 'package:hostelzy/locate.dart';
import 'package:hostelzy/push.dart';
import 'package:hostelzy/router.dart';
import 'package:hostelzy/sign_in.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/store.dart';
import 'package:hostelzy/ui/common.dart';
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

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

/// F22: the first free bed on the picker's floor.
Finder freeBed(AppState s) {
  final b = s.rooms[s.hid]!.where((r) => r.floor == s.floor && AppState.fits(r, s.pR)).expand((r) => r.beds).firstWhere((b) => b.state == 'free' && !b.mine);
  return find.byKey(ValueKey('bed-${b.id}'));
}

void main() {
  mapTiles = false; // no network in flow tests
  testWidgets('onboarding: sign in, phone and role lead to Explore', (tester) async {
    final s = AppState();
    await pumpApp(tester, s);
    expect(find.text('See the'), findsOneWidget);
    await tap(tester, find.text('Sign in'));
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
    expect(find.text('Find a bed'), findsOneWidget);
    s.dispose();
  });

  testWidgets('tenant holds a bed; owner sees and confirms it', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Anjani Residency'));
    expect(s.screen, 'detail');
    await tap(tester, find.text('Pick a bed'));
    // F23: the room plan comes first; these steps use the floor view.
    if (s.mode == 'room') await tap(tester, find.byKey(const ValueKey('floorView')));
    expect(s.screen, 'picker');
    await tap(tester, freeBed(s));
    expect(s.bed, isNotNull);
    final bed = s.bed!;
    await tap(tester, find.byKey(const ValueKey('pickContinue')));
    expect((s.sheet, s.holdOpt), ('hold', 'free'));
    await tap(tester, find.text('Hold bed $bed free'));
    expect(s.screen, 'hold');
    expect(find.text('HELD FOR YOU · FREE'), findsOneWidget);
    expect(find.text('Tell Srinivas on WhatsApp'), findsOneWidget);
    expect(s.findBed('anjani', bed).b!.state, 'held');

    // The same hold shows up in the owner's request inbox.
    s.jump('oToday', 'owner');
    await tester.pump();
    // F21 W3: it's in "Needs you now" with its countdown.
    expect(find.text('Hold on bed $bed'), findsOneWidget);
    await tap(tester, find.text('Confirm hold').last); // soonest first: the new hold has the most time left
    expect(s.holds.single.status, 'confirmed');
    s.dispose();
  });

  testWidgets('bed picker: Plan · Room · Building tabs, cheapest beds as a link (F21 W2, F25)', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, s);
    // F25 (founder): the Building tab is back; the list stays a link.
    expect(find.byKey(const ValueKey('pickTab-building')), findsOneWidget);
    expect(find.text('List'), findsNothing);
    await tap(tester, find.text('See cheapest beds ›'));
    expect(find.textContaining('beds you can take'.toUpperCase()), findsOneWidget);
    await tap(tester, find.text('‹ Back to the plan'));
    expect(s.mode, 'plan');
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
    expect(find.text('WAITING FOR SRINIVAS'), findsOneWidget);
    expect(find.text('Remind Srinivas'), findsOneWidget);
    expect(s.residents.firstWhere((r) => r.bed == '204-B').status, 'Waiting');
    await tester.pump(const Duration(seconds: 3));
    s.jump('oToday', 'owner');
    await tester.pump();
    expect(find.text('Received ₹8,020?'), findsOneWidget);
    await tap(tester, find.text('Yes, received').first);
    expect(s.residents.firstWhere((r) => r.bed == '204-B').status, 'Paid');
    s.jump('rPay', 'resident');
    await tester.pump();
    expect(find.textContaining('RENT · PAID'), findsOneWidget);
    expect(find.text('Share receipt'), findsOneWidget);
    s.dispose();
  });

  testWidgets('owner menu edits show in the resident Food tab', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'menu');
    await pumpApp(tester, s);
    s.update(() => s.mDay = todayIdx);
    await tester.pump();
    await tester.enterText(find.byType(EditableText).first, 'Masala dosa');
    await tester.pump();
    expect(s.menuDraft![todayIdx].b, 'Masala dosa');
    // Not on the resident's side until it's saved.
    expect(s.menuOf('anjani')![todayIdx].b, isNot('Masala dosa'));
    await tap(tester, find.byKey(const ValueKey('menuSave')));
    expect((s.menuOf('anjani')![todayIdx].b, s.moreTab, s.menuDirty), ('Masala dosa', 'home', false));
    expect(s.toast, 'Menu saved. Residents see it in their Food tab now.');
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
    await tap(tester, find.text('Send to owner'));
    expect(s.complaints.last.text, 'Fan is broken');
    // F21 W3: it shows inline as Sent.
    expect(find.text('SENT'), findsWidgets);
    s.jump('oMore', 'owner');
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('manage-Complaints')));
    expect(find.text('Fan is broken'), findsOneWidget);
    s.dispose();
  });

  testWidgets('theme switch in Settings (F21 W4: only there)', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('Dark'), findsNothing);
    expect(find.text('Log out'), findsNothing);
    await tap(tester, find.text('Settings'));
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
    expect(find.text('Ask Srinivas'), findsOneWidget);
    expect(find.text('Nothing is sent until you press send in WhatsApp.'), findsOneWidget);
    // F24 4a: the message ends with the enquiry's link the owner can open.
    expect(s.waFull, endsWith('Booking code $ref\n${enquiryLink(ref)}'));
    expect(find.text(s.waFull), findsOneWidget);
    await tap(tester, find.text('Open WhatsApp'));
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
    // F21 W3: new ones in "Needs you now"; the full list in Manage → Enquiries.
    expect(find.text('New enquiry · ${s.enquiries.first.name}'), findsOneWidget);
    s.update(() {
      s.screen = 'oMore';
      s.moreTab = 'enquiries';
    });
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
    // F21 W2: the refund sits next to the rent; rules are folded.
    expect(find.text('Advance ₹3,000 · ₹2,500 back when you leave'), findsOneWidget);
    await tap(tester, find.text('House rules'));
    expect(find.text('₹3,000 + first month at move-in'), findsOneWidget);
    expect(find.text('₹1,000 kept from the advance'), findsOneWidget);
    expect(find.textContaining('2 months'), findsNothing);
    s.jump('hold', 'tenant');
    await tester.pump();
    expect(find.textContaining('advance ₹3,000 + first month'), findsOneWidget);
    s.dispose();

    // Resident: Pay rent shows the advance and what comes back.
    final r = AppState(start: 'rPay', role: 'resident');
    await pumpApp(tester, r);
    expect(find.textContaining('Due 14 Oct'), findsOneWidget);
    expect(find.text('Advance ₹3,000 · ₹2,000 back when you leave'), findsOneWidget);
    expect(find.textContaining('₹15,200'), findsNothing);

    // Move out: refund = advance − maintenance, with the notice date.
    r.go('move');
    await tester.pump();
    expect(find.text('31 Oct'), findsWidgets);
    expect(find.textContaining('(advance ₹3,000 minus ₹1,000 maintenance)', findRichText: true), findsOneWidget);
    await tap(tester, find.text('Give notice for'));
    expect(r.notice, isTrue);
    expect(find.text('₹2,000 back to your UPI'), findsOneWidget);
    r.dispose();

    // Owner: bed sheet and add booking show advance and maintenance.
    final o = AppState(start: 'oBeds', role: 'owner', sheet: 'bed');
    await pumpApp(tester, o);
    expect(find.text('₹3,000 · ₹1,000 kept on exit'), findsOneWidget);
    expect(find.text('Mark as leaving 31 Oct'), findsOneWidget);
    o.openAddResident(bed: '102-A');
    await tester.pump();
    final rent = o.findBed('anjani', '102-A').r!.rent;
    expect(find.textContaining('due at move-in ${fmt(3000 + rent)} (advance ₹3,000, ₹1,000 kept on exit)'), findsOneWidget);
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

    // Owner: Manage opens on its list (F21 W3); Residents has the unassigned-beds banner.
    s.jump('oMore', 'owner');
    await tester.pump();
    expect(s.moreTab, 'home');
    expect(find.text('Residents'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('manage-Residents')));
    expect(s.moreTab, 'residents');
    expect(s.unassignedBeds, ['103-A', '202-B']);
    expect(find.text('2 taken beds have no resident'), findsOneWidget);
    expect(find.text("Beds 103-A and 202-B. Add who's staying there by Sat 3 Oct."), findsOneWidget);

    // Filter chips count and filter.
    await tap(tester, find.text('Not confirmed 1'));
    expect(find.text('Ravi Teja'), findsOneWidget);
    expect(find.text('Rahul Varma'), findsNothing);
    await tap(tester, find.text('All 21'));

    // Add a resident with the tenant's number: matched live.
    await tap(tester, find.text('Add resident'));
    expect(s.sheet, 'addR');
    expect(s.rBed, '103-A');
    // F22: the Residents search field comes first.
    await tester.enterText(find.byType(EditableText).at(1), 'Rahul Varma');
    await tester.enterText(find.byType(EditableText).at(2), '90000 00001');
    await tester.pump();
    expect(find.textContaining('Joined via Hostelzy.'), findsOneWidget);
    expect(find.textContaining('($ref)'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(2), '9000000000');
    await tester.pump();
    expect(find.textContaining('No Hostelzy enquiry, hold or booking from this number in the last 60 days.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(2), '9000000001');
    await tester.pump();
    await tap(tester, find.text('Add resident').last);
    expect(s.sheet, isNull);
    final added = s.residents.first;
    expect(added.bed, '103-A');
    expect(added.confirmed, isFalse);
    expect(added.tag, 'wait');
    expect(added.ref, ref);
    expect(s.unassignedBeds, ['202-B']);
    expect(find.text('1 taken bed has no resident'), findsOneWidget);

    s.dispose();
  });

  testWidgets('invite QR: owner approves or removes sign-ups (F06)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
    await pumpApp(tester, s);
    await tap(tester, find.byKey(const ValueKey('inviteQr')));
    expect(s.screen, 'oInvite');
    await tester.pump();
    await tester.pump();
    expect(find.text('farhath.me/hostelzy/app/j/?c=ANJ-7Q2'), findsOneWidget);
    expect(find.text('WAITING FOR YOU · 2'), findsOneWidget);
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
    // F26 #2: AC lives in the Filters sheet.
    await tap(tester, find.byKey(const ValueKey('filtersBtn')));
    await tap(tester, find.widgetWithText(ChipBtn, 'AC'));
    expect(s.fR, 'AC');
    await tap(tester, find.textContaining('Show '));
    expect(find.text('Sai Sri Ladies Hostel'), findsNothing);
    expect(find.text('NON-AC'), findsNothing);
    // F21 W2: Non-AC lives in the Filters sheet.
    await tap(tester, find.byKey(const ValueKey('filtersBtn')));
    await tap(tester, find.widgetWithText(ChipBtn, 'Non-AC'));
    expect(s.fR, 'Non-AC');
    await tap(tester, find.textContaining('Show '));
    expect(find.text('Nest 42 Co-living'), findsNothing);
    expect(find.text('Sai Sri Ladies Hostel'), findsOneWidget);
    s.clearFilters();
    expect(s.fR, 'Any');
    await tester.pump();

    // Hostel page: sharing × type grid, the Hostelzy price with walk-in struck through.
    await tap(tester, find.text('Anjani Residency'));
    expect(find.text('Not offered'), findsOneWidget);
    expect(find.text('₹10,800'), findsOneWidget);
    expect(find.text('₹11,000 walk in'), findsOneWidget);
    expect(find.text('Same price for every bed of a type. Food included. Electricity extra, by meter.'), findsOneWidget);

    // Picker: AC filter skips non-AC rooms.
    await tap(tester, find.text('Pick a bed'));
    // F23: the room plan comes first; these steps use the floor view.
    if (s.mode == 'room') await tap(tester, find.byKey(const ValueKey('floorView')));
    await tap(tester, find.widgetWithText(ChipBtn, 'Non-AC'));
    expect(s.findBed('anjani', '${s.room}-A').r!.ac, isFalse);
    await tap(tester, find.widgetWithText(ChipBtn, 'AC'));
    final r = s.rooms['anjani']!.firstWhere((x) => x.n == s.room);
    expect(r.ac, isTrue);
    expect(find.textContaining('${r.share} sharing AC · '), findsWidgets);
    s.dispose();

    // Owner: edit the rate card and a room's type.
    final o = AppState(start: 'oBeds', role: 'owner');
    await pumpApp(tester, o);
    await tap(tester, find.text('Rooms and rates ›'));
    expect((o.screen, o.moreTab), ('oMore', 'rates'));
    await tester.enterText(find.bySemanticsLabel('Walk-in price, 3 sharing AC'), '9500');
    await tester.pump();
    final r204 = o.rooms['anjani']!.firstWhere((x) => x.n == 204);
    o.setRoomAc(r204, true);
    await tester.pump();
    expect(o.acDraft![204], isFalse);
    await tap(tester, find.text('+ Add'));
    expect(o.rateDraft![rateKey(true, 4)], 7600 + 1200);
    // F24 item 19: 204's layout has no AC unit, so it can't be made AC yet.
    o.setRoomAc(r204, true);
    await tester.pump();
    expect(o.acDraft![204], isFalse);
    expect(o.toast, 'Room 204’s layout has no AC unit. Add it in the room’s layout and publish, then make the room AC.');
    // With the AC unit in its published layout, it can.
    final l204 = o.layoutOf('anjani', 204)!;
    l204.items.add(LItem('ac1', 'ac', 1, 0, 3, 1));
    l204.published?.items.add(LItem('ac1', 'ac', 1, 0, 3, 1));
    expect(o.liveLayout('anjani', 204)!.ac, isNotNull);
    o.setRoomAc(r204, true);
    await tester.pump(const Duration(seconds: 3)); // let the "Add a price first" toast go
    await tap(tester, find.byKey(const ValueKey('saveRates')));
    expect(o.rooms['anjani']!.firstWhere((x) => x.n == 201).rent, 9500);
    expect(r204.ac, isTrue);
    expect(r204.rent, 8800);
    o.dispose();
  });

  testWidgets('Hostelzy deals: Explore badges, deal table, owner picks deals (F03)', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await pumpApp(tester, s);
    // F21 W2: the green ribbon shows the Hostelzy price (or the deal's headline).
    expect(find.textContaining('Hostelzy price ₹'), findsWidgets);
    expect(find.text('₹1,000 less upfront'), findsOneWidget);
    s.update(() => s.sortBy = 'deals');
    expect(filtered(s).first.id, 'anjani');
    expect(s.bestQuote(filtered(s).last.id), isNull);
    s.update(() => s.sortBy = 'rec');

    // Hostel page: the deal sits in the rent table.
    await tap(tester, find.text('Anjani Residency'));
    expect(find.text('Hostelzy price: ₹200 off every month · ₹500 exit · Free laundry'), findsOneWidget);
    expect(find.text('Pick a bed'), findsOneWidget);

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
    await tap(tester, find.text('Save deals'));
    expect(s.dealsOf('anjani').on, {'exit', 'monthly', 'first'});
    expect(s.dealsOf('anjani').covers(false), isFalse);

    // Tenant: the table says the deal is for AC rooms only.
    s.jump('detail', 'tenant');
    await tester.pump();
    expect(find.text('Hostelzy price: ₹200 off every month · ₹500 exit · ₹500 off first month · AC rooms only'), findsOneWidget);
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
    await tap(tester, find.text('Pick a bed'));
    // F23: the room plan comes first; these steps use the floor view.
    if (s.mode == 'room') await tap(tester, find.byKey(const ValueKey('floorView')));
    expect(s.screen, 'picker');
    await tap(tester, freeBed(s));
    final bed = s.bed!;
    final r = s.findBed('anjani', bed).r!;
    await tap(tester, find.byKey(const ValueKey('pickContinue')));
    // F21 W2: two equal options, free hold picked first.
    expect((s.sheet, s.holdOpt), ('hold', 'free'));
    expect(find.text('Hold free · 1 hour'), findsOneWidget);
    expect(find.text('Hold bed $bed free'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('opt-book')));
    expect(find.text('Pay ₹3,000 to book'), findsNWidgets(2));
    expect(find.text('Your price is fixed'), findsOneWidget);
    expect(find.textContaining('${fmt(r.rent - 200)} monthly'), findsOneWidget);
    expect(find.textContaining('₹500 exit only'), findsOneWidget);
    expect(find.textContaining('₹299'), findsNothing);
    final ref = s.peekRef;
    await tap(tester, find.byKey(const ValueKey('holdGo')));
    // F17: not booked until Srinivas confirms the advance arrived.
    var h = s.holds.single;
    expect((h.opt, h.status, h.ref, h.paid, s.sheet), ('book', 'paying', ref, 3000, 'payAdv'));
    expect(s.findBed('anjani', bed).b!.state, 'held');
    expect(find.text('Pay to Srinivas'), findsOneWidget);
    expect(find.text('sample.owner@upi'), findsOneWidget);
    await tap(tester, find.text('I’ve paid · enter UPI reference').last);
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
    expect(find.byKey(const ValueKey('floor-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('floor-2')), findsNothing);
    await tap(tester, find.byKey(const ValueKey('floor-3')));
    expect(s.floor, 3);
    for (final n in [301, 302, 303, 304, 305]) {
      expect(find.byKey(ValueKey('roomCard-$n')), findsOneWidget);
    }
    s.dispose();

    // Owner bed map: Sai Sri has 3, 5 and 2 rooms per floor.
    final o = AppState(start: 'oBeds', role: 'owner');
    o.ownHid = 'saisri';
    await pumpApp(tester, o);
    await tap(tester, find.byKey(const ValueKey('obFloor-2')));
    expect(find.text('Room 205'), findsOneWidget);
    expect(find.text('Room 302'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('obFloor-3')));
    expect(find.text('Room 302'), findsOneWidget);
    expect(find.text('Room 205'), findsNothing);
    o.dispose();
  });

  testWidgets('verified reviews, ranking and owner replies (F08)', (tester) async {
    // Explore: F26 #2 Price ↑ is the default sort; rank and reasons, never a score.
    final s = AppState(start: 'explore', role: 'tenant');
    s..phone = '9000000001'..myName = 'Rahul Varma'; // a signed-in user (F18: no sample identity)
    await pumpApp(tester, s);
    expect(s.sortBy, 'price');
    expect(s.rankOf('anjani'), 1);
    expect(s.rankReasons('anjani'), 'Quick replies, beds kept up to date');
    expect(find.text('#1 near you'), findsNothing);
    expect(s.rankReasons('nest42'), startsWith('Few reviews yet'));

    // Hostel page → Reviews.
    await tap(tester, find.text('Anjani Residency'));
    await tap(tester, find.text('verified reviews'));
    expect(s.screen, 'reviews');
    expect(find.textContaining('Advance back in full: 35 of 36 who left'), findsOneWidget);
    expect(find.textContaining('Layout accurate: 92%'), findsOneWidget);
    expect(find.text('Thanks Naveen. We’re fitting a booster pump on 10 Oct.', findRichText: true), findsNothing);

    // Resident: 30-day review.
    s.jump('rHome', 'resident');
    await tester.pump();
    await tap(tester, find.textContaining('How is your stay so far?', findRichText: true));
    expect(s.screen, 'rReview');
    await tap(tester, find.text('Post review'));
    expect(s.screen, 'rReview');
    await tester.pump(const Duration(seconds: 3)); // the "Tap the stars" toast goes
    for (final c in reviewCats) {
      await tap(tester, find.bySemanticsLabel('$c 4 stars'));
    }
    await tester.enterText(find.byType(EditableText).first, 'Food is good.');
    await tester.pump();
    await tap(tester, find.text('Yes'));
    await tap(tester, find.text('Post review'));
    final mine = s.reviews.first;
    expect((mine.name, mine.stars, mine.text, mine.layout), ('Rahul V.', 4, 'Food is good.', 'Yes'));

    // Resident: exit review feeds the "advance returned" record.
    s.jump('rExit', 'resident');
    await tester.pump();
    expect(find.text('Did you get your ₹2,000 back?'), findsOneWidget);
    await tap(tester, find.text('Not yet'));
    await tap(tester, find.bySemanticsLabel('Overall 3 stars'));
    await tap(tester, find.text('Post review'));
    expect((s.stats['anjani']!.advFull, s.stats['anjani']!.advLeft), (35, 37));

    // Owner: ranking and replying.
    s.jump('oRank', 'owner');
    await tester.pump();
    // F22 Area 3: one page; no strikes, so no strike tip.
    expect(find.textContaining('To rank higher: '), findsOneWidget);
    expect(find.textContaining('Fair Play strikes'), findsNothing);
    s.jump('oRank', 'owner');
    await tester.pump();
    final waiting = s.reviews.where((r) => r.hid == 'anjani' && r.reply == null).length;
    expect(find.text('Reply'), findsNWidgets(waiting));
    await tap(tester, find.text('Reply').first);
    await tester.enterText(find.byType(EditableText).first, 'Thanks Rahul.');
    await tester.pump();
    await tap(tester, find.text('Post reply'));
    expect(s.reviews.where((r) => r.reply == 'Thanks Rahul.').length, 1);
    expect(find.text('Reply'), findsNWidgets(waiting - 1));

    // Fair Play strikes lower the rank.
    s.strikes['anjani'] = 2;
    expect(s.rankOf('anjani'), greaterThan(1));
    s.dispose();
  });

  testWidgets('Fair Play: rules, owner number after a hold, case, strikes (F07)', (tester) async {
    // A new owner accepts the rules with "I agree" (F21: no fake SMS code).
    final s = AppState(start: 'role');
    s.signedIn = true; // the role picker comes after sign-in
    await pumpApp(tester, s);
    await tap(tester, find.text('I run a PG'));
    expect(s.screen, 'oRules');
    await tap(tester, find.text('Agree and continue'));
    expect(s.fairAccepted, isFalse);
    expect(s.toast, 'Tick “I agree” first.');
    await tester.pump(const Duration(seconds: 3)); // the toast goes
    await tap(tester, find.byKey(const ValueKey('fpAgree')));
    await tap(tester, find.text('Agree and continue'));
    expect((s.fairAccepted, s.screen), (true, 'oToday'));
    expect(find.text('Fair Play check FP-0142'), findsOneWidget);

    // Owner fixes the mistake within 48 h: no strike.
    await tap(tester, find.text('Fair Play check FP-0142'));
    expect(s.screen, 'oCase');
    await tap(tester, find.text('Change Teja to “Came from the app”'));
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
    // F22: asked inline on Holds, with the report link under it.
    expect(find.text('Did you join Anjani Residency?'), findsOneWidget);
    await tap(tester, find.text('The owner asked me to skip the app ›'));
    expect(s.sheet, 'report');
    await tap(tester, find.text('Offered a lower price to skip the app'));
    await tap(tester, find.text('Send report'));
    expect(s.cases.first.signal, 'Tenant report: offered a lower price to skip the app');
    expect(s.cases.first.status, 'new');

    // Founder: strikes (decided in the team console, F25). Strike 1 is a
    // warning, strike 2 hides deals, strike 3 removes the hostel.
    s.update(() => s.strikes['anjani'] = 1);
    expect(s.dealsOf('anjani').on, isNotEmpty);
    s.strikes['anjani'] = 2;
    expect(s.dealsOf('anjani').on, isEmpty);
    s.strikes['anjani'] = 3;
    expect(filtered(s).any((h) => h.id == 'anjani'), isFalse);
    s.dispose();
  });

  testWidgets('Stay Rewards: Member, 2-hour holds, ₹100 at move-in, Trusted badge (F09)', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    expect(find.text('Not a member yet'), findsOneWidget); // the status line on Me
    await tap(tester, find.byKey(const ValueKey('me-Stay Rewards')));
    expect(find.text('NOT A MEMBER YET'), findsOneWidget);
    expect(s.holdSecs, 3600);

    // "Yes, I joined" (F07) makes the tenant a Member.
    s.answerJoined('yes');
    expect(s.level, 'member');
    expect(s.holdSecs, 7200);
    await tester.pump();
    expect(find.text('MEMBER'), findsOneWidget);
    expect(find.text('RAHUL-100', findRichText: true), findsNothing);
    expect(find.textContaining('RAHUL-100', findRichText: true), findsOneWidget);

    // A Member's free hold lasts 2 hours.
    s.update(() {
      s.hid = 'greenview';
      s.bed = s.rooms['greenview']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free').id;
      s.sheet = 'hold';
    });
    await tester.pump();
    expect(find.text('Hold free · 2 hours'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // the reward toast goes
    await tap(tester, find.byKey(const ValueKey('opt-book')));
    await tap(tester, find.byKey(const ValueKey('holdGo')));
    final hold = s.holds.single;
    unawaited(s.confirmPayment(s.payOfHold(hold.id)!, true)); // the owner saw the money
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
    expect(find.text('36 beds · ₹999 a month'), findsOneWidget);
    expect(s.planPrice, 999);
    // F22 Area 3: the trial has nothing to pay yet.
    expect(find.byKey(const ValueKey('planPay')), findsNothing);

    // A Member reward given at move-in (F09) comes off the invoice.
    s.update(() => s.ownerCredits.add((hid: 'anjani', what: 'Member reward · 204-B', amt: 100)));
    await tester.pump();
    expect(find.text('− ₹100'), findsOneWidget);
    expect(s.invoiceAmt, 899);

    // The invoice is due: the same screen (also at 'oInvoice') pays it by UPI
    // to Hostelzy's UPI ID (DECISIONS 2026-10-02), with a real QR.
    s.update(() => s.invoice.status = 'due');
    s.go('oInvoice');
    await tester.pump();
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('₹899'), findsOneWidget);
    expect(find.text('Due 1 Nov · pay to Hostelzy by UPI'), findsOneWidget);
    expect((hostelzyUpiId, supportWhatsApp), ('9059790014@axl', '9059790014'));
    expect(find.text('9059790014@axl'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('planQr')));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Sample QR'), findsNothing);
    await tap(tester, find.text('Pay ₹899 by UPI'));
    expect(s.lastLink?.queryParameters['pa'], '9059790014@axl');
    expect(s.lastLink?.queryParameters['am'], '899');
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('I’ve paid · enter UPI reference'));
    expect(s.sheet, 'utr');
    await tap(tester, find.text('Send UPI reference'));
    expect(s.invoice.status, 'due'); // needs all 12 digits
    await tester.enterText(find.byType(TextField).last, '4021 8834 1297');
    await tester.pump();
    await tap(tester, find.text('Send UPI reference'));
    expect((s.screen, s.sheet, s.invoice.status, s.invoice.utr, s.invoice.amt), ('oPayStatus', null, 'checking', '402188341297', 899));
    expect(find.text('CHECKING YOUR PAYMENT'), findsOneWidget);
    s.dispose();

    // Founder: the team matches the UTR in the console (F25). Orchid is 15
    // days late: its deals are paused, the listing stays, until it's paid.
    final a = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, a);
    expect(a.dealsOf('orchid').on, isEmpty);
    expect(a.dealsPaused('orchid'), isTrue);
    a.update(() => a.invoices.firstWhere((i) => i.ref == 'HZ-INV-0998')
      ..status = 'paid'
      ..late = 0);
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
    l15.update(() => l15.invoice
      ..status = 'paid'
      ..late = 0);
    expect(l15.dealsOf('anjani').on, isNotEmpty);
    l15.dispose();

    // Not received: the owner fixes the UTR.
    final m = AppState(start: 'oPayStatus', role: 'owner', plan: 'missing');
    await pumpApp(tester, m);
    expect(find.textContaining('We couldn’t find a payment with UPI reference 4021 8834 1297'), findsOneWidget);
    await tap(tester, find.text('Fix the UPI reference'));
    expect((m.sheet, m.utrDraft), ('utr', '402188341297'));
    m.dispose();
  });

  testWidgets('room layouts: Room tab, bed facts, compare, locked states, owner approval, admin (F12)', (tester) async {
    // Plan stays the default; tapping a room opens it in Room.
    final s = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, s);
    expect(s.mode, 'plan');
    await tap(tester, find.byKey(const ValueKey('floor-3')));
    await tap(tester, find.descendant(of: find.byKey(const ValueKey('roomCard-304')), matching: find.text('Room 304')));
    expect((s.mode, s.room), ('room', 304));
    expect(find.text('Room 304'), findsOneWidget);
    expect(find.text('Sample layout'), findsOneWidget);
    // F22: fan reach and AC airflow are always drawn; never priced by position.
    expect(find.text('Same price for every bed here'), findsOneWidget);
    expect(find.text('Bed A · free'), findsOneWidget);
    expect(find.textContaining('Corner bed · walls on two sides'), findsOneWidget);
    // Tap bed B (free soon) like a seat: its facts show.
    await tap(tester, find.text('B').first);
    expect(s.bed, '304-B');
    expect(find.textContaining('Under a fan'), findsOneWidget);
    expect(find.textContaining('Window side · faces courtyard'), findsOneWidget);
    expect(find.textContaining('In the AC airflow'), findsOneWidget);

    // Compare the two open beds.
    await tap(tester, find.text('Compare with another bed ›'));
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
    expect(find.text('Compare with another bed ›'), findsNothing);

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

    // Signed out: layouts need sign-in.
    final o = AppState(start: 'picker', role: 'tenant', mode: 'room', auth: 'out');
    await pumpApp(tester, o);
    expect(find.text('Sign in to see room layouts'), findsOneWidget);
    await tap(tester, find.text('Sign in'));
    expect(o.screen, 'login');
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
    // Ask Hostelzy to draw it (F24): saved in the app, done within 48 h.
    await tap(tester, find.text('Ask Hostelzy'));
    expect(w.sheet, 'layoutReq');
    await tap(tester, find.text('Send request'));
    expect(w.shapeReqFor('anjani', 204), isNull);
    await tester.enterText(find.byType(TextField).first, 'Bed C is against the washroom wall.');
    await tap(tester, find.text('Send request'));
    final q = w.shapeReqFor('anjani', 204)!;
    expect((q.note, q.photos.length, q.status), ('Bed C is against the washroom wall.', 0, 'requested'));
    expect(find.textContaining('Asked Hostelzy · '), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Hostelzy team: sees the request, mirrors, sends it back to the owner.
    w.update(() => w.screen = 'aLayout');
    await tester.pump();
    expect(find.text('“Bed C is against the washroom wall.”'), findsOneWidget);
    final before = l.bedRect('A');
    await tap(tester, find.text('Mirror ↔'));
    expect(l.bedRect('A').left, l.w - before.right);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.text('Send to owner'));
    // Tenants keep v2 until the owner publishes the drawing.
    expect((l.version, l.pending, q.status), (2, false, 'sent'));
    expect(l.bedRect('A'), before);
    await tester.pump(const Duration(seconds: 4));
    w.update(() => w.screen = 'oLayout');
    await tester.pump();
    expect(find.text('Hostelzy drew a new version · check and publish'), findsOneWidget);
    await tap(tester, find.text('Publish v3'));
    expect((l.version, l.live, q.status, w.screen), (3, true, 'published', 'oPublished'));
    expect(l.bedRect('A').left, l.w - before.right);
    w.dispose();
  });

  testWidgets('onboarding: add hostel on a visit, go live, switcher, free beds, managers (F14)', (tester) async {
    // Founder's tracker → Add hostel (admin mode).
    final s = AppState(start: 'aTrack', role: 'owner');
    await pumpApp(tester, s);
    expect(find.text('HOSTELZY TEAM · LIVE 3 OF 20 THIS MONTH'), findsOneWidget);
    await tap(tester, find.text('Add hostel'));
    expect((s.screen, s.addStep), ('aAdd', 1));
    expect(find.text('ADD HOSTEL · STEP 1 OF 7'), findsOneWidget);
    await tap(tester, find.text('Map pin · drop it at the gate'));
    s.pinPanned((17.4622, 78.3568));
    await tap(tester, find.byKey(const ValueKey('pinSave')));
    expect(s.draft.pinChecked, isTrue);
    await tap(tester, find.text('Next: rooms'));

    // Uneven floors: Ground 0, 1st 3, 2nd 5, 3rd 2 = 10 rooms, 29 beds.
    expect(find.text('Next: rates · 10 rooms, 29 beds'), findsOneWidget);
    expect(find.text('No beds here · hidden from tenants'), findsOneWidget);
    await tap(tester, find.text('+ Room').last);
    expect(s.draft.floors[3].rooms.last.label, '303');
    await tap(tester, find.byKey(const ValueKey('aRoom-303')));
    await tap(tester, find.text('Remove room'));
    await tap(tester, find.text('Next: rates · 10 rooms, 29 beds'));

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
    await tap(tester, find.text('Next: owner account'));

    // F24: the owner's account (the demo marks it linked).
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('ownerPhone6')), matching: find.byType(TextField)), '9000000009');
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('ownerLink')));
    expect(s.draft.ownerLinked, isTrue);
    await tap(tester, find.text('Next: go live'));

    // Go live stays locked until all six are done.
    expect(find.text('Go live · 3 things left'), findsOneWidget);
    await tap(tester, find.text('Go live · 3 things left'));
    expect(s.screen, 'aAdd');
    await tap(tester, find.text('Fair Play rules: owner agreed'));
    await tap(tester, find.text('Bed status checked on the visit'));
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

    // Tenant: F26 #5 ✓ VERIFIED (the team visit) and availability.
    final t = AppState(start: 'detail', role: 'tenant');
    await pumpApp(tester, t);
    expect(find.byKey(const ValueKey('verifiedBadge')), findsOneWidget);
    expect(find.text('Beds and prices checked by Hostelzy · 1 Oct 2026'), findsOneWidget);
    expect(find.textContaining('Visited by Hostelzy'), findsNothing);
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
    expect(find.text('HOLD ENDED'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    await tap(tester, find.text('Hold it again'));
    expect((s.screen, s.sheet, s.bed), ('picker', 'hold', h.bed));
    s.dispose();

    // Owner: Call opens the phone app (Manage → Enquiries, F21 W3).
    final o = AppState(start: 'oMore', role: 'owner', moreTab: 'enquiries');
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
      s.holdOpt = 'book';
    });
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('holdGo')));
    final h = s.holds.single;
    final pay = s.payOfHold(h.id)!;
    await tap(tester, find.text('Pay with a UPI app'));
    expect(s.lastLink!.scheme, 'upi');
    expect(s.lastLink!.queryParameters, {'pa': 'sample.owner@upi', 'pn': 'Srinivas', 'am': '3000', 'tn': h.ref, 'cu': 'INR'});
    s.update(() => s.payUtr = '402188341297');
    unawaited(s.sendPayUtr());
    unawaited(s.confirmPayment(pay, false));
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
    // F22 Area 1: one card with one facts line, the real cost and View.
    expect(find.text('${mh.gender} · ${kmLabel(kmTo(mh, 'Hitec City'))} · ${jsNum(mh.rating)} · ${s.freeOf(mh.id).f} free'), findsOneWidget);
    await tap(tester, find.text(fmt(hostelById('greenview').from)));
    expect(s.mapSel, 'greenview');
    await tap(tester, find.byKey(const ValueKey('mapView')));
    expect((s.screen, s.hid), ('detail', 'greenview'));
    s.dispose();

    // Release layout on a laptop: app column + map, no phone frame or jump list.
    HostelzyShell.prototypeFrame = false;
    addTearDown(() => HostelzyShell.prototypeFrame = true);
    tester.view.physicalSize = const Size(1280, 800);
    final w = AppState(start: 'explore', role: 'tenant');
    await tester.pumpWidget(MaterialApp(home: AppScope(state: w, child: const HostelzyShell())));
    await tester.pump();
    expect(find.text('Find a bed'), findsOneWidget);
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
    await tap(tester, find.text('House rules'));
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
    expect(find.byKey(const ValueKey('joinedAsk')), findsOneWidget);
    expect(find.text('Did you join Anjani Residency?'), findsOneWidget);
    h.dispose();
  });

  testWidgets('Play Store: settings, delete account (blocked, code, done), permission explainer (F15)', (tester) async {
    final s = AppState(start: 'me', role: 'tenant');
    await pumpApp(tester, s);
    await tap(tester, find.text('Settings'));
    expect(s.screen, 'settings');
    expect(find.text('Hostelzy 1.0.0 (1) · Made in Hyderabad'), findsOneWidget);
    // Look: Auto follows the phone.
    await tap(tester, find.text('Auto'));
    expect(s.theme, 'system');
    expect(s.isDark(Brightness.dark), isTrue);
    expect(s.isDark(Brightness.light), isFalse);
    // No push on this device (tests, web): turning one on says so honestly.
    await tap(tester, find.text('New free beds'));
    await tester.pump();
    expect((s.screen, s.toast), ('settings', 'Saved. Notifications work in the Android app.'));
    await tester.pump(const Duration(seconds: 3));
    // Privacy policy opens the web page.
    await tap(tester, find.text('Privacy policy'));
    expect(s.lastLink.toString(), 'https://farhath.me/hostelzy/app/privacy/');
    await tester.pump(const Duration(seconds: 3));
    // Help opens WhatsApp to Hostelzy's support number (F22: from Me).
    s.back();
    await tester.pump();
    await tap(tester, find.text('Help on WhatsApp'));
    expect(s.lastLink.toString(), startsWith('https://wa.me/919059790014?text='));
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, find.byKey(const ValueKey('me-Settings')));

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
    expect(s.screen, 'delConfirm');
    // Not signed in with Google: only this phone's data exists, and goes.
    expect(find.text('Delete from this phone'), findsOneWidget);
    await tap(tester, find.text('Delete from this phone'));
    expect((s.screen, s.phone, s.signedIn, s.level), ('delDone', '', false, 'none'));
    expect(find.text('Your account is deleted'), findsOneWidget);
    expect(find.text('We removed your name, phone, Google sign-in, holds, saved hostels and rewards. Reviews stay as “Former resident”.'), findsOneWidget);
    await tap(tester, find.text('Close Hostelzy'));
    expect(s.screen, 'welcome');
    s.dispose();

    // Signed in with Google: confirm with Google, then the server, then Firebase.
    final g = AppState(start: 'delConfirm', role: 'tenant');
    final gs = _FakeSignIn(null);
    final gd = _FakeData();
    g.signIn = gs;
    g.data = gd;
    g.update(() => g.account = (uid: 'fb-asha', name: 'Asha Kiran', email: 'asha@gmail.com'));
    await pumpApp(tester, g);
    expect(find.text('Confirm it’s you'), findsOneWidget);
    expect(find.text('AK'), findsOneWidget);
    expect(find.text('asha@gmail.com'), findsOneWidget);
    gs.reauthFail = SignInFail.cancelled;
    await tap(tester, find.text('Confirm with Google'));
    await tester.pump();
    expect((g.screen, g.toast, gd.deleted), ('delConfirm', 'Not deleted. You closed Google.', false));
    await tester.pump(const Duration(seconds: 3));
    gs.reauthFail = SignInFail.otherAccount;
    await tap(tester, find.text('Confirm with Google'));
    await tester.pump();
    expect(g.toast, 'That’s a different Google account. Pick asha@gmail.com.');
    await tester.pump(const Duration(seconds: 3));
    gs.reauthFail = null;
    gd.deleteError = 'P0001: Owners: ask Hostelzy to close or hand over your hostel first.';
    await tap(tester, find.text('Confirm with Google'));
    await tester.pump();
    expect((g.screen, g.toast, gs.userDeleted), ('delConfirm', 'Owners: ask Hostelzy to close or hand over your hostel first.', false));
    await tester.pump(const Duration(seconds: 3));
    gd.deleteError = null;
    await tap(tester, find.text('Confirm with Google'));
    await tester.pump();
    expect((g.screen, gd.deleted, gs.userDeleted, g.account), ('delDone', true, true, null));
    g.dispose();

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
    await tap(tester, find.byKey(const ValueKey('mapLoc')));
    expect((m.screen, m.sheet), ('map', 'loc'));
    expect(find.text('Use your location?'), findsOneWidget);
    await tap(tester, find.text('Type an area instead'));
    expect((m.screen, m.sheet, m.myPos), ('where', null, null));
    m.dispose();
  });

  testWidgets('layout access: owner Beds + Manage, team passcode, editor moves a fan, approval', (tester) async {
    // Owner: Beds → a bed → "Room … layout ›" (F22: in the bed sheet).
    final o = AppState(start: 'oBeds', role: 'owner');
    await pumpApp(tester, o);
    final first = o.rooms['anjani']!.firstWhere((r) => r.floor == o.obFloor || o.obFloor == 0);
    await tap(tester, find.byKey(ValueKey('obed-${first.beds.first.id}')));
    expect(o.sheet, 'bed');
    await tap(tester, find.byKey(const ValueKey('bedLayout')));
    expect(o.screen, 'oLayout');
    // ...and Manage → Layouts lists every room with its state.
    o.tab('oMore');
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('manage-Room layouts')));
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
    expect(find.text('TEAM TOOLS · SAMPLE DATA'), findsOneWidget);
    for (final t in ['Add hostel', 'Onboarding tracker', 'Layout editor', 'Team members']) {
      expect(find.text(t), findsOneWidget);
    }
    // F25: payments and Fair Play cases are in the team console only.
    for (final t in ['Payments check', 'Fair Play cases']) {
      expect(find.text(t), findsNothing);
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
    await tap(tester, find.text('Invite a friend'));
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
    expect(find.text('4 of 6 · Trusted tenant badge next · 1 complaint from the owner'), findsOneWidget);
    s.dispose();
  });

  testWidgets('after go-live: add / remove rooms and floors, poster PDF, team members (F14)', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'rates');
    await pumpApp(tester, s);
    await tap(tester, find.text('Rooms and floors ›'));
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
    await tester.tap(find.byKey(const ValueKey('rail-saved')));
    await tester.pump();
    expect(w.screen, 'saved');
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
    e.applyListings((hostels: const [], rooms: const {}, rates: const {}, pos: const {}, upi: const {}, layouts: const {}, deals: const {}, rules: const {}, reviews: const {}, strikes: const {}, checks: const {}, checkers: const {}, amenities: const {}, standing: const {}));
    await pumpApp(tester, e);
    expect(find.text('No hostels in this area yet'), findsOneWidget);
    expect(find.text('Anjani Residency'), findsNothing);
    await tap(tester, find.text('Pick another area'));
    expect(e.screen, 'where');
    e.dispose();
    resetSampleData();
  });

  testWidgets('push: the Settings switch asks Android right away; allowed or denied is said honestly (F13)', (tester) async {
    for (final allow in [true, false]) {
      final s = AppState(start: 'settings', role: 'tenant');
      final fake = _FakePush(allow);
      s.push = fake;
      s.update(() => s.notif.updateAll((k, v) => false));
      await pumpApp(tester, s);
      await tap(tester, find.text('Rent reminders').first);
      await tester.pump();
      expect(fake.asked, 1);
      if (allow) {
        expect((s.osPushAllowed, s.notif['rent'], s.notif['beds']), (true, true, false));
        // Not signed in with Google: allowed, but nothing to send to yet.
        expect((s.pushToken, s.toast), (null, 'Notifications allowed. Sign in with Google to get them.'));
      } else {
        expect((s.osPushAllowed, s.notifOn('rent')), (false, false));
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
    expect(find.text('asha@gmail.com'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('“not verified”'), findsOneWidget);
    // F24 item 23: never pre-filled; the Google name is only the hint.
    expect(s.myName, '');
    expect(find.text('Asha K'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('myName')), matching: find.byType(TextField)), 'Asha Kumari');
    await tester.enterText(find.byType(TextField).last, '9000000007');
    await tester.pump();
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('I run a PG'));
    await tester.pump();
    expect(data.profile, (name: 'Asha Kumari', email: 'asha@gmail.com', phone: '9000000007', role: 'owner'));
    // Push token goes to the account once signed in.
    final fp = _FakePush(true);
    s.push = fp;
    await s.enablePush();
    expect(data.tokens, ['fcm-token']);
    expect(s.toast, 'Notifications are on for this phone.');
    // Log out: the server forgets this phone's token, then Google signs out.
    s.logOut();
    await tester.pump();
    expect(data.removed, ['fcm-token']);
    expect((fp.deleted, (s.signIn as _FakeSignIn).signedOut, s.account), (1, true, null));
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
    await tap(tester, find.text('I live in a PG'));
    expect((s.screen, s.roleGate), ('roleGate', 'resident'));
    expect(find.text('Join your PG'), findsOneWidget);
    s.update(() => s.phone = '9876543210');
    await tester.pump();
    expect(find.text('Ask your owner to add you with +91 98765 43210.'), findsOneWidget);
    await tap(tester, find.text('Send my number on WhatsApp'));
    expect(s.lastLink.toString(), contains('98765%2043210'));
    await tester.pump(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tap(tester, find.text('I run a PG'));
    expect(find.text('List your PG'), findsOneWidget);
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
    await tap(tester, find.text('I live in a PG'));
    await tap(tester, find.text('Not in a PG yet? Find a bed ›'));
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
    hostels.add(const Hostel(id: 'tagless', name: 'Tagless PG', gender: 'Men', area: 'Ameerpet', from: 5000, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: {}, x: 50, y: 50, tags: ['Wi-Fi']));
    c.rooms['tagless'] = mkRooms(hostels.last, 6);
    c.rates['tagless'] = seedRates(hostels.last);
    c.stats['tagless'] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
    await pumpApp(tester, c);
    c.update(() {
      c.hid = 'tagless';
      c.screen = 'detail';
    });
    await tester.pump();
    expect(find.text('Wi-Fi'), findsNothing); // F26 #6: no tag boxes on the hostel page
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
    // F21 W2: the same "Where?" field as Explore.
    expect(find.text('Area, landmark or hostel'), findsOneWidget);
    // Pick an area: only hostels there, on the map and in Explore.
    await tap(tester, find.byKey(const ValueKey('mapArea')));
    expect(s.screen, 'where');
    expect(find.text('Coming soon'), findsWidgets); // areas with no hostels yet
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('whereQ')), matching: find.byType(TextField)), 'kond');
    await tester.pump();
    expect(find.text('Ameerpet'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('area-Kondapur')));
    expect((s.mapArea, s.screen), ('Kondapur', 'map'));
    expect(find.text('Kondapur'), findsWidgets);
    expect(filtered(s).map((h) => h.area).toSet(), {'Kondapur'});
    expect(find.text(fmt(hostelById('anjani').from)), findsNothing); // Madhapur pin hidden
    s.tab('explore');
    await tester.pump();
    expect(find.text('Anjani Residency'), findsNothing);
    s.tab('map');
    await tester.pump();

    // Use my location: explainer first, then the map centres on you (F26 #2: the sort stays Price ↑).
    final loc = _FakeLocator((17.4610, 78.3610));
    s.locator = loc;
    await tap(tester, find.byKey(const ValueKey('mapLoc')));
    expect((s.sheet, loc.asked), ('loc', 0));
    await tap(tester, find.text('Allow location'));
    await tester.pump();
    expect((loc.asked, s.myPos, s.mapArea, s.sortBy, s.mapAreaLabel), (1, (17.4610, 78.3610), null, 'price', 'Near me'));
    expect(find.byKey(const ValueKey('youAreHere')), findsOneWidget);
    expect(s.kmFrom, 'from you');
    await tester.pump(const Duration(seconds: 3));
    // Denied: no position is invented; the area picker opens instead.
    final d = AppState(start: 'map', role: 'tenant')..locator = _FakeLocator(null, LocateFail.denied);
    await d.useMyLocation();
    expect((d.myPos, d.screen, d.toast), (null, 'where', 'No problem. Type an area instead.'));
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
    await tap(tester, find.byKey(const ValueKey('me-Saved')));
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
    await tap(tester, find.byKey(const ValueKey('manage-Photos')));
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
    expect(l.holds.map((h) => '${h.bed} ${h.room} ${h.opt} ${h.status} ${h.ref}'), ['101-A 101 book paying HZ-5002', '204A-B 204 free released HZ-5003']);
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
    expect(s.toast, 'That link has no booking code.');
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

  test('C: on Supabase, enquiries, payments and complaints are written to the server', () async {
    final s = AppState(start: 'explore', role: 'tenant');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [
      {'id': 'p-uuid', 'hostel_id': 'h1', 'kind': 'advance', 'amount': 3000, 'note': 'HZ-5002', 'hold_id': 'hold-uuid', 'status': 'pending', 'created_at': '2026-10-02T10:00:00Z'},
    ], complaints: [], me: 'fb-asha'));
    s.data = fake;
    s.update(() {
      s.account = (uid: 'fb-asha', name: 'Asha K', email: 'a@gmail.com');
      s.myName = 'Asha K';
      s.phone = '9876543210';
    });
    // Samples aren't on the server: nothing is written for them.
    s.enquire('anjani', 'Hi Imran, is a bed free?', bed: '204-A', from: 'Hostel page');
    expect(fake.calls, isEmpty);
    expect(s.waRef, isNotNull);
    await s.startLive();
    expect(s.onServer, isTrue);
    // Enquiry: the server's HZ code goes into the WhatsApp message; asking again reuses it.
    s.enquire('anjani', 'Hi Imran, is a bed free?', bed: '204-A', from: 'Hostel page');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['enquiry anjani 204-A Asha K 9876543210']);
    expect((s.sheet, s.waRef), ('wa', 'HZ-5009'));
    s.enquire('anjani', 'Hi again', bed: '204-A', from: 'Hostel page');
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.length, 1);
    // UTR, then the owner confirms: the hold becomes a booking on the server.
    final p = s.payments.single;
    s.update(() {
      s.payId = p.id;
      s.payUtr = '123456789012';
    });
    await s.sendPayUtr();
    await s.confirmPayment(p, true);
    expect(fake.calls.sublist(1), ['utr p-uuid 123456789012', 'confirm p-uuid true hold-uuid']);
    s.markContacted('HZ-5009');
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'contacted HZ-5009');
    // Complaints need a stay on the server.
    s.update(() => s.cText = 'No water');
    await s.raiseComplaint();
    expect(s.toast, 'Your owner hasn’t added you yet. Complaints open once you’re a resident here.');
    s.update(() => s.myHostel = 'h1');
    await s.raiseComplaint();
    expect((fake.calls.last, s.cText), ('complaint h1 Wi-Fi No water', ''));
    final c = Complaint(id: 1, by: '101-A', cat: 'WiFi', text: 'Slow', status: 'Open', date: '1 Oct', note: '', key: 'c-uuid');
    s.update(() => s.complaints = [c]);
    await s.advanceComplaint(c);
    expect(fake.calls.last, 'complaint c-uuid In progress'); // then the list is refetched from the server
    // Offline: nothing is said to be sent.
    fake.fail = true;
    s.update(() => s.payUtr = '999999999999');
    await s.sendPayUtr();
    expect(s.toast, 'Couldn’t save it. Check your internet and try again.');
    expect(s.payments.single.utr, isNot('999999999999'));
    s.stopLive();
    s.dispose();
  });

  test('S1: on Supabase, holds and bookings are placed on the server', () async {
    expect(listingsFromRows([
      {'id': 'h1', 'name': 'Sai PG', 'gender': 'Men', 'area': 'Ameerpet', 'rooms': [
        {'number': 101, 'floor': 1, 'share': 2, 'rent': 8000, 'beds': [{'id': 'bed-uuid', 'letter': 'A', 'state': 'free'}]},
      ]},
    ]).rooms['h1']!.single.beds.single.key, 'bed-uuid');
    // An advance hold waiting for the owner shows as "paying", with its advance.
    final l = liveFromRows(holds: [
      {'id': 'x1', 'hostel_id': 'h1', 'opt': 'advance', 'status': 'waiting', 'ref': 'HZ-1', 'started_at': '2026-10-02T10:00:00Z', 'beds': {'letter': 'A', 'rooms': {'number': 101}}},
    ], enquiries: [], payments: [
      {'id': 'p1', 'hostel_id': 'h1', 'kind': 'advance', 'amount': 2500, 'hold_id': 'x1', 'status': 'pending', 'created_at': '2026-10-02T10:00:00Z'},
    ], complaints: []);
    expect((l.holds.single.status, l.holds.single.paid, l.holds.single.opt), ('paying', 2500, 'book'));

    final s = AppState(start: 'explore', role: 'tenant');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-asha'));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha K', email: 'a@gmail.com'));
    await s.startLive();
    // Give two free beds their server ids.
    Bed keyed(String key) {
      final r = s.rooms['anjani']!.firstWhere((r) => r.beds.any((b) => b.state == 'free' && b.key == null));
      final i = r.beds.indexWhere((b) => b.state == 'free' && b.key == null);
      final b = r.beds[i];
      return r.beds[i] = Bed(id: b.id, letter: b.letter, room: b.room, floor: b.floor, spot: b.spot, state: 'free', soon: '', key: key);
    }
    final b1 = keyed('bed-uuid-1');
    s.update(() {
      s.hid = 'anjani';
      s.bed = b1.id;
    });
    // Book with the advance: the server makes the hold and the payment; the pay sheet opens.
    s.placeHold('book');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.single, startsWith('hold anjani bed-uuid-1 book '));
    expect((s.screen, s.sheet, s.holdId, s.payId), ('hold', 'payAdv', 'hold-uuid-1', 'pay-uuid-1'));
    expect((b1.state, b1.mine), ('held', true));
    expect(s.holds.single.status, 'paying');
    // The server refuses a bed someone else just took: said plainly, nothing placed.
    final o = keyed('bed-uuid-2');
    fake.holdError = 'that bed is not free any more';
    s.update(() => s.bed = o.id);
    s.placeHold('free');
    await Future<void>.delayed(Duration.zero);
    expect(s.toast, 'Someone just took this bed. Pick another one.');
    expect(s.holds.length, 1);
    // A free hold, then the tenant releases it on the server (and its advance, if any).
    fake.holdError = null;
    s.placeHold('free');
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.calls.last, 'hold anjani bed-uuid-2 free 0');
    expect(s.toast, contains('sees it in Hostelzy'));
    final free = s.holds.firstWhere((h) => h.id == 'hold-uuid-2');
    s.releaseHold(free, msg: 'Hold released.');
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((fake.calls.last, s.toast), ('release hold-uuid-2 true', 'Hold released.'));
    expect(s.holds.firstWhere((h) => h.id == 'hold-uuid-2').status, 'released');
    // Server holds don't expire on the phone; the server ends them.
    expect(s.expireHoldsAt(DateTime.now().millisecondsSinceEpoch + 3 * 3600 * 1000), isFalse);
    s.stopLive();
    s.dispose();
  });

  test('S2: on Supabase, the owner\'s residents and hold decisions are on the server', () async {
    // Stays → resident rows: rent from the latest rent payment, not the owner's own stay.
    final l = liveFromRows(holds: [], enquiries: [], complaints: [], me: 'fb-owner', payments: [
      {'id': 'p1', 'hostel_id': 'h1', 'kind': 'rent', 'amount': 8000, 'stay_id': 's1', 'status': 'waiting', 'created_at': '2026-10-02T10:00:00Z'},
      {'id': 'p0', 'hostel_id': 'h1', 'kind': 'rent', 'amount': 8000, 'stay_id': 's1', 'status': 'paid', 'created_at': '2026-09-02T10:00:00Z'},
    ], stays: [
      {'id': 's1', 'hostel_id': 'h1', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'via': 'hz', 'ref': 'HZ-5001', 'rent': 8000, 'advance': 3000, 'joined_on': '2026-09-01', 'late_days': 0, 'confirmed': true, 'left_on': null, 'beds': {'letter': 'C', 'rooms': {'number': 101}}},
      {'id': 's2', 'hostel_id': 'h1', 'user_id': null, 'name': 'Ravi', 'phone': '9876500002', 'via': 'direct', 'rent': 7000, 'advance': 0, 'joined_on': '2026-10-02', 'confirmed': false, 'left_on': null, 'beds': null},
      {'id': 's3', 'hostel_id': 'h9', 'user_id': 'fb-owner', 'name': 'Me', 'confirmed': true, 'joined_on': '2026-01-01', 'left_on': null},
    ]);
    expect(l.residents.map((r) => '${r.key} ${r.name} ${r.bed} ${r.status} ${r.tag} ${r.since}'), ['s1 Kiran Rao 101-C Waiting hz Joined 1 Oct'.replaceFirst('1 Oct', dayMon(DateTime(2026, 9))), 's2 Ravi  Due wait Added ${dayMon(DateTime(2026, 10, 2))}']);
    expect(l.myHostel, 'h9');

    final s = AppState(start: 'oToday', role: 'owner');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner'));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    expect(s.residents, isEmpty); // no sample residents on the server
    // Add a resident on a bed that has a server id.
    final r0 = s.rooms[s.ownHid]!.firstWhere((r) => r.beds.any((b) => b.state == 'free'));
    final i = r0.beds.indexWhere((b) => b.state == 'free');
    final b0 = r0.beds[i];
    r0.beds[i] = Bed(id: b0.id, letter: b0.letter, room: b0.room, floor: b0.floor, spot: b0.spot, state: 'free', soon: '', key: 'bed-key');
    s.update(() {
      s.rName = 'Ravi Kumar';
      s.rPhone = '9876500002';
      s.rBed = b0.id;
      s.rFee = '7000';
      s.rAdv = '3000';
      s.sheet = 'addR';
    });
    s.addResident();
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.calls.single, 'stay ${s.ownHid} bed-key Ravi Kumar 9876500002 7000 3000');
    expect((s.residents.single.name, s.sheet, r0.beds[i].state), ('Ravi Kumar', null, 'booked'));
    expect(s.toast, 'Added. Ravi confirms by joining with your invite code.');
    // A tenant's free hold: the owner confirms it, or declines it (no advance is touched).
    final h = Hold(id: 'hold-x', hid: s.ownHid, bed: '101-A', room: 101, opt: 'free', start: DateTime.now().millisecondsSinceEpoch, status: 'waiting', ref: 'HZ-5020');
    s.update(() => s.holds = [h]);
    final req = allRequests(s).single;
    expect((req.name, req.note), ('Hostelzy tenant', 'Code HZ-5020 · placed in the Hostelzy app'));
    s.confirmHoldReq(req);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'holdstatus hold-x held');
    s.update(() => s.holds = [h]);
    s.declineHoldReq(req);
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((fake.calls.last, s.toast), ('release hold-x false', 'Declined. Bed 101-A is free again.'));
    s.stopLive();
    s.dispose();
  });

  test('S3: on Supabase, owner edits (rates, deals, rules, UPI ID) are saved on the server', () async {
    final l = listingsFromRows([
      {'id': 'h1', 'name': 'Sai PG', 'gender': 'Men', 'area': 'Ameerpet', 'rules': [{'k': 'Gate closes', 'v': '11 pm'}], 'deals': {'deals_on': ['monthly', 'exit'], 'target': 'ac', 'confirmed_at': '2026-10-01T10:00:00Z'}},
      {'id': 'h2', 'name': 'Other', 'gender': 'Men', 'area': 'Ameerpet', 'deals': []},
    ]);
    expect(l.deals['h1']!.on, {'monthly', 'exit'});
    expect(l.deals['h1']!.target, 'ac');
    expect(l.deals['h2']!.on, isEmpty);
    expect(l.rules['h1']!.single.v, '11 pm');
    expect(l.rules['h2'], isNull);

    final s = AppState(start: 'oMore', role: 'owner');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner'));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    // Rate card: written first, then the phone shows it.
    s.openRates();
    final key = s.rateDraft!.keys.first;
    s.update(() => s.rateDraft![key] = s.rateDraft![key]! + 500);
    s.saveRates();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'rates ${s.ownHid} ${s.rateDraft!.length} ${s.rooms[s.ownHid]!.length}');
    expect(s.rates[s.ownHid]![key], s.rateDraft![key]);
    // Deals
    s.update(() => s.dealDraft = {'monthly'});
    s.publishDeals();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'deals ${s.ownHid} monthly ${s.dealTarget}');
    expect(s.deals[s.ownHid]!.on, {'monthly'});
    // Rules: the hostel page shows the saved ones.
    s.update(() => s.rules = [const Rule('Gate closes', '11 pm')]);
    s.saveRules();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect((fake.calls.last, s.toast), ('rules ${s.ownHid} Gate closes=11 pm', 'Rules saved. Residents and new tenants see them now.'));
    expect(s.hostelRules[s.ownHid]!.single.v, '11 pm');
    // UPI ID: nothing saved while it isn't one; saved once it is and they pause.
    s.setOwnerUpi('imran@', 'Imran');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(fake.calls.last, startsWith('rules'));
    s.setOwnerUpi('imran@okaxis', 'Imran');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect((fake.calls.last, s.toast), ('upi ${s.ownHid} imran@okaxis Imran', 'UPI ID saved. Tenants pay you here.'));
    // Offline: nothing changes on the phone and it says so.
    fake.fail = true;
    s.update(() => s.dealDraft = {'exit'});
    s.publishDeals();
    await Future<void>.delayed(Duration.zero);
    expect(s.deals[s.ownHid]!.on, {'monthly'});
    expect(s.toast, 'Couldn’t save it. Check your internet and try again.');
    s.stopLive();
    s.dispose();
  });

  test('S7: on Supabase, the owner\'s plan invoice comes from the server', () async {
    final l = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], invoices: [
      {'id': 'inv-1', 'ref': 'HZ-INV-1100', 'hostel_id': 'anjani', 'beds': 40, 'amount': 899, 'due': '2026-11-05', 'status': 'due', 'late': 0},
      {'id': 'inv-0', 'ref': 'HZ-INV-1001', 'hostel_id': 'anjani', 'beds': 40, 'amount': 999, 'due': '2026-10-05', 'status': 'paid', 'late': 0},
    ], plans: [{'hostel_id': 'anjani', 'trial_ends': '2026-10-31'}]);
    expect(l.invoices.map((i) => '${i.ref} ${i.status} ${i.key}'), ['HZ-INV-1100 due inv-1', 'HZ-INV-1001 paid inv-0']);
    expect(l.trialEnds['anjani'], DateTime(2026, 10, 31));

    final s = AppState(start: 'oPlan', role: 'owner');
    // Before the first invoice: the trial, and paying early isn't possible.
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner', plans: [{'hostel_id': s.ownHid, 'trial_ends': '2026-10-31'}]));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    expect((s.invoice.status, s.invoice.key, s.trialEnd), ('upcoming', null, DateTime(2026, 10, 31)));
    expect(s.invoices, isEmpty); // no sample invoices on the server
    s.update(() => s.utrDraft = '123456789012');
    s.sendUtr();
    expect(s.toast, 'Your first invoice isn’t out yet. You pay once it arrives.');
    expect(fake.calls, isEmpty);
    // The invoice arrives: its amount is the server's; the UTR goes to the server.
    fake.rows = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner', invoices: [
      {'id': 'inv-1', 'ref': 'HZ-INV-1100', 'hostel_id': s.ownHid, 'beds': 40, 'amount': 899, 'due': '2026-11-05', 'status': 'due', 'late': 0},
    ]);
    await s.refreshLive();
    expect((s.invoice.ref, s.invoiceAmt), ('HZ-INV-1100', 899));
    s.sendUtr();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect((fake.calls.single, s.screen, s.toast), ('invutr inv-1 123456789012', 'oPayStatus', 'UPI reference saved. Hostelzy checks it against the bank record.'));
    // The team marks it paid in the team console (F25: not in the app).
    s.stopLive();
    s.dispose();
  });

  test('S4: on Supabase, reviews come from the server, residents post them and owners reply', () async {
    final l = listingsFromRows([
      {'id': 'h1', 'name': 'Sai PG', 'gender': 'Men', 'area': 'Ameerpet', 'reviews': [
        {'id': 'rv1', 'hostel_id': 'h1', 'author_name': 'Teja N.', 'kind': 'stay', 'stars': 4, 'body': 'Good food', 'cats': {'Food': 5, 'Owner': 3}, 'layout': 'Mostly', 'created_at': '2026-09-20T10:00:00Z'},
        {'id': 'rv2', 'hostel_id': 'h1', 'author_name': 'Arjun R.', 'kind': 'exit', 'stars': 5, 'body': '', 'cats': {'Food': 4}, 'layout': 'Yes', 'advance': 'all', 'again': 'Yes', 'reply': 'Thanks', 'replied_at': '2026-10-01T10:00:00Z', 'created_at': '2026-09-30T10:00:00Z'},
      ]},
    ]);
    final rv = l.reviews['h1']!;
    expect(rv.map((r) => '${r.id} ${r.kind} ${r.fresh}'), ['rv2 exit false', 'rv1 30-day true']);
    expect((l.hostels.single.rating, l.hostels.single.reviews), (4.5, 2));
    final st = statsOf(rv);
    expect((st.cats[0], st.advFull, st.advLeft, st.layoutPct), (4.5, 1, 1, 75));

    final s = AppState(start: 'rReview', role: 'resident');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-teja'));
    s.data = fake;
    s.update(() {
      s.account = (uid: 'fb-teja', name: 'Teja N', email: 't@gmail.com');
      s.myName = 'Teja Naidu';
    });
    await s.startLive();
    // Not a resident on the server yet: the review isn't sent.
    s.update(() => s.rvStars = 4);
    s.postReview();
    await Future<void>.delayed(Duration.zero);
    expect(s.toast, 'Your owner hasn’t added you yet. Reviews open once you’re a resident here.');
    expect(fake.calls, isEmpty);
    // A confirmed resident: posted to their hostel, then the hostels are fetched again.
    fake.rows = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-teja', stays: [
      {'id': 'st1', 'hostel_id': 'h1', 'user_id': 'fb-teja', 'name': 'Teja N', 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-01'},
    ]);
    await s.refreshLive();
    expect(s.myHostel, 'h1');
    s.update(() {
      s.rvText = 'Good food';
      s.rvCats = {'Food': 5};
      s.rvLayout = 'Mostly';
    });
    s.postReview();
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.calls.single, 'review h1 ${s.meShort} stay 4 Good food 1 Mostly null null');
    expect(fake.listingsFetched, 1);
    expect((s.toast, s.rvStars), ('Review posted as ${s.meShort} · verified resident.', 0));
    // Exit review
    s.update(() {
      s.exAdv = 'part';
      s.exStars = 3;
      s.exAgain = 'No';
    });
    s.postExitReview();
    for (var k = 0; k < 8; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.calls.last, 'review h1 ${s.meShort} exit 3  0 null part No');
    // The owner replies to a server review.
    s.update(() => s.replyText = 'Thanks Teja');
    s.postReply(rv.last);
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((fake.calls.last, s.toast), ('reply rv1 Thanks Teja', 'Reply posted under Teja’s review.'));
    s.stopLive();
    s.dispose();
  });

  test('S5: on Supabase, Fair Play cases, replies, fixes, decisions and reports go to the server', () async {
    final l = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], cases: [
      {'id': 'c1', 'ref': 'FP-0201', 'hostel_id': 'h1', 'title': 'Larry added late', 'signal': 'Signal', 'status': 'new', 'resident': 'Late Larry', 'events': [{'on': '1 Oct', 'what': 'Moved in', 'detail': '', 'flag': true}], 'created_at': '2026-10-02T10:00:00Z'},
      {'id': 'c2', 'ref': 'FP-0200', 'hostel_id': 'h1', 'title': 'Report', 'signal': 'Tenant report', 'status': 'new', 'owner_reply': 'He paid me directly', 'created_at': '2026-10-01T10:00:00Z'},
      {'id': 'c3', 'ref': 'FP-0199', 'hostel_id': 'h1', 'title': 'Old', 'signal': 'S', 'status': 'decided', 'decision': 'Strike 1 · warning', 'created_at': '2026-09-01T10:00:00Z'},
    ]);
    expect(l.cases.map((c) => '${c.id} ${c.status} ${c.events.length}'), ['FP-0201 new 1', 'FP-0200 decide 0', 'FP-0199 closed 0']);
    expect(listingsFromRows(const [], strikes: {'h1': 2}).strikes['h1'], 2);

    final s = AppState(start: 'oToday', role: 'owner');
    final fake = _FakeLive(l);
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    expect(s.cases.length, 3); // only the server's cases
    final c1 = s.cases.first, c2 = s.cases[1];
    // The owner fixes within 48 hours: the server switches the resident and closes it.
    s.fixCase(c1);
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect((fake.calls.last, s.toast), ('fix c1', 'Late Larry now shows as came from the app. Case closed, no strike.'));
    fake.fixError = 'the 48 hours are over; reply instead';
    s.fixCase(c1);
    for (var k = 0; k < 4; k++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(s.toast, 'The 48 hours are over. Reply instead and the Hostelzy team decides.');
    // A reply to a case the team sent back goes back to the team.
    final w = FairCase(id: 'FP-0202', hid: 'h1', title: 't', signal: 's', status: 'waiting', key: 'c4');
    s.update(() => s.fpReply = 'He moved in on the 3rd');
    s.replyCase(w);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'casereply c4 He moved in on the 3rd true');
    // The team decides in the team console (F25: not in the app).
    expect(c2.key, isNotNull);
    // A tenant's private report needs the hostel of an ended hold.
    s.update(() {
      s.role = 'tenant';
      s.reportWhy = 'Owner asked me to skip the app';
      s.holds = [];
    });
    s.sendReport();
    expect(s.toast, 'Reports are about a hostel you held a bed at. Hold one first.');
    s.update(() => s.holds = [Hold(id: 'x', hid: 'h1', bed: '101-A', room: 101, opt: 'free', start: 0, status: 'released')]);
    s.sendReport();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect((fake.calls.last, s.toast), ('report h1 Owner asked me to skip the app ', 'Report sent to the Hostelzy team. The owner never sees your name.'));
    s.stopLive();
    s.dispose();
  });

  testWidgets('S8: on Supabase, owners see the hostels they run; managers join with a one-time code', (tester) async {
    final l = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner', staff: [
      {'hostel_id': 'h1', 'user_id': 'fb-owner', 'role': 'owner'},
      {'hostel_id': 'h2', 'user_id': 'fb-owner', 'role': 'manager'},
      {'hostel_id': 'h1', 'user_id': 'fb-ravi', 'role': 'manager'},
    ], managers: [
      {'hostel_id': 'h1', 'name': 'Ravi', 'phone': '9876500011', 'used_by': 'fb-ravi'},
      {'hostel_id': 'h2', 'name': 'Other', 'phone': '9876500012', 'used_by': null},
    ]);
    expect(l.myHostels, ['h1', 'h2']);

    final s = AppState(start: 'welcome', role: 'tenant');
    final fake = _FakeLive(l);
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    // Hostels whose rooms aren't loaded yet are fetched once more, never opened empty.
    await s.startLive();
    await tester.pump();
    expect(fake.listingsFetched, 1);
    expect(s.ownHid, 'anjani');
    for (final h in ['h1', 'h2']) {
      s.rooms[h] = List.of(s.rooms['anjani']!);
      s.rates[h] = Map.of(s.rates['anjani']!);
    }
    await s.refreshLive();
    // The switcher lists the server's hostels; the owner screens follow the first.
    expect(s.ownerHostels, ['h1', 'h2']);
    expect(s.ownHid, 'h1');
    expect(s.canOwner, isTrue);
    expect(s.managers.map((m) => '${m.name} ${m.joined}'), ['Ravi true']);
    // Residents: only once the owner has confirmed a stay on the server.
    expect(s.canResident, AppState.samples);
    // Adding a manager: a one-time code from the server, sent on WhatsApp.
    s.update(() {
      s.mgrName = 'Sunil K';
      s.mgrPhone = '98765 00013';
    });
    s.addManager();
    await tester.pump();
    await tester.pump();
    expect(fake.calls.last, 'mgr h1 Sunil K 9876500013');
    expect(s.lastLink.toString(), contains('MGR-ABCD2345'));
    expect(s.toast, 'WhatsApp opened with Sunil’s invite. They join once they open it and sign in.');
    expect(s.managers.last.joined, isFalse);
    // The manager opens the link and joins.
    s.update(() => s.inviteDraft = 'mgr-abcd2345');
    await s.joinInvite();
    expect(fake.calls.last, 'joinmgr MGR-ABCD2345');
    expect(s.toast, 'You’re a manager at Sai PG now. Pick “I run a PG” to start.');
    expect(s.screen, 'role');
    s.stopLive();
    s.dispose();
  });

  test('S6: on Supabase, Stay Rewards come from the server ledger; nothing is granted by the phone', () async {
    final r = rewardsFrom({'member': true, 'member_since': '2026-09-01T10:00:00Z', 'ref_code': 'ASHA-4K7Q', 'referred_by': null}, [
      {'id': 'l1', 'kind': 'member', 'user_id': 'fb-asha', 'amount': 100},
      {'id': 'l2', 'kind': 'referral_referrer', 'user_id': 'fb-asha', 'amount': 100},
      {'id': 'l3', 'kind': 'spend', 'user_id': 'fb-asha', 'amount': -100},
      {'id': 'l4', 'kind': 'owner_credit', 'hostel_id': 'h1', 'amount': 100, 'reason': 'given at move-in'},
      {'id': 'l5', 'kind': 'member', 'user_id': 'fb-other', 'amount': 100},
    ], me: 'fb-asha');
    expect((r.member, r.code, r.balance, r.friends, r.used, r.referred), (true, 'ASHA-4K7Q', 100, 1, true, false));
    expect(r.ownerCredits.single.amt, 100);
    expect(r.since, startsWith('Since '));

    // A new tenant: not a Member yet; their code comes from the server; a friend's code is used once.
    final s = AppState(start: 'rewards', role: 'tenant');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-ravi', profile: [{'member': false, 'ref_code': null, 'referred_by': null}]));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-ravi', name: 'Ravi', email: 'r@gmail.com'));
    await s.startLive();
    expect((s.isMember, s.referralCode), (false, '…'));
    await s.loadReferralCode();
    await s.loadReferralCode(); // asked once
    expect((s.referralCode, fake.calls.where((c) => c == 'refcode').length), ('ASHA-4K7Q', 1));
    s.update(() => s.friendCode = 'nope');
    await s.useFriendCode();
    expect(s.toast, 'Enter your friend’s code, like ASHA-4K7Q.');
    fake.friendError = 'that code isn\'t valid';
    s.update(() => s.friendCode = 'ABCD-1234');
    await s.useFriendCode();
    expect(s.toast, 'That code isn’t valid. Check it with your friend.');
    fake.friendError = null;
    await s.useFriendCode();
    expect((fake.calls.last, s.referred), ('usecode ABCD-1234', true));
    expect(s.toast, 'Code saved. You and Ravi each get ${fmt(referralReward)} after your first month at a Hostelzy hostel.');
    // "Yes, I joined" and "I've moved in" never grant a reward from the phone.
    s.answerJoined('yes');
    expect((s.isMember, s.toast), (false, 'Thanks. Your ₹100 Member reward unlocks once your owner confirms your stay.'));
    s.moveIn(Hold(id: 'x', hid: 'anjani', bed: '101-A', room: 101, opt: 'book', start: 0, status: 'booked'));
    expect((s.role, s.rewardUsed), ('tenant', false));
    // The server says: Member now, ₹100 balance; the owner's credit shows on their plan.
    fake.rows = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-ravi', profile: [{'member': true, 'member_since': '2026-10-02T10:00:00Z', 'ref_code': 'ASHA-4K7Q', 'referred_by': 'fb-asha'}], ledger: [
      {'id': 'l1', 'kind': 'member', 'user_id': 'fb-ravi', 'amount': 100},
      {'id': 'l9', 'kind': 'owner_credit', 'hostel_id': 'anjani', 'amount': 100, 'reason': 'given at move-in'},
    ]);
    await s.refreshLive();
    expect((s.isMember, s.rewardBalance, s.referred), (true, 100, true));
    expect(s.planCredit, 100); // ownHid is anjani in the sample
    s.stopLive();
    s.dispose();
  });

  testWidgets('F19: residents fix room layouts; others see the residents-only sheet; the owner compares and decides', (tester) async {
    final owner = hostelById('anjani').owner;
    // A tenant browsing Anjani: Edit room → only residents can fix it.
    final t = AppState(start: 'picker', role: 'tenant');
    await pumpApp(tester, t);
    t.update(() {
      t.hid = 'anjani';
      t.room = 203;
      t.floor = 2;
      t.mode = 'room';
    });
    await tester.pump();
    // F19 extras: they can try the editor (nothing is saved); only Send is locked.
    await tap(tester, find.text('Edit room'));
    expect((t.screen, t.fixTry, t.sheet), ('rFix', true, null));
    expect(find.text('Try mode · play freely, nothing is saved'), findsOneWidget);
    await tap(tester, find.text('Send · residents only'));
    expect(t.sheet, 'fixLock');
    expect(find.text('Only residents of Anjani Residency can fix room layouts'), findsOneWidget);
    expect(find.textContaining('Ask your owner for your invite code.', findRichText: true), findsOneWidget);
    // Leaving discards the try.
    t.update(() => t.sheet = null);
    t.leaveFixEditor();
    expect((t.fixTry, t.fixDrafts.isEmpty), (false, true));
    t.dispose();

    // A resident: their room screen → Edit room → the suggestion editor.
    final r = AppState(start: 'me', role: 'resident');
    await pumpApp(tester, r);
    // F22: Me › My stay › Fix a room layout.
    await tap(tester, find.byKey(const ValueKey('me-My stay')));
    await tap(tester, find.text('Fix a room layout'));
    expect((r.screen, r.fixHid, r.fixRoom), ('rRoom', 'anjani', 204));
    await tap(tester, find.text('203'));
    expect(find.text('Something in the wrong place?'), findsOneWidget);
    await tap(tester, find.text('Edit room'));
    expect(r.screen, 'rFix');
    expect(find.text('Only you see this until you send it'), findsOneWidget);
    final live = r.liveLayout('anjani', 203)!;
    final v0 = live.version;
    // Nothing changed yet: not sent.
    await tap(tester, find.text('Send to owner'));
    expect(r.toast, 'Nothing changed yet. Move things to where they really are.');
    // Move the fan one foot and mark it not working; the live layout doesn't change.
    final fan = r.fixLayout!.of('fan').first;
    r.edSelect(fan.id);
    await tester.pump();
    final x0 = fan.x;
    await tap(tester, find.byKey(const ValueKey('fix-right')));
    final moved = fan.x;
    expect(moved, isNot(x0)); // on the 1-ft grid
    expect(live.of('fan').first.x, x0);
    await tap(tester, find.text('Not working'));
    expect(fan.working, isFalse);
    expect(live.of('fan').first.working, isTrue);
    // The draft stays on this phone when leaving, and comes back.
    r.leaveFixEditor();
    expect(r.snapshot()['fixDrafts'], contains('anjani|203'));
    r.openFixEditor('anjani', 203);
    expect(r.fixLayout!.of('fan').first.x, moved);
    // Send: what changed, an optional note, then "Waiting for owner".
    await tester.pump();
    await tap(tester, find.text('Send to owner'));
    expect(r.sheet, 'fixSend');
    expect(find.textContaining('not working'), findsWidgets);
    r.update(() => r.fixNote = 'Fan is over bed A');
    await tap(tester, find.text('Send to owner').last);
    await tester.pump();
    expect((r.screen, r.sheet), ('rRoom', null));
    expect(r.toast, 'Sent to $owner. You get a notification when they decide.');
    expect(find.text('Waiting for $owner'), findsOneWidget);
    expect(r.fixDrafts.containsKey('anjani|203'), isFalse);
    final mine = r.myFixFor('anjani', 203)!;
    expect((mine.status, mine.note), ('pending', 'Fan is over bed A'));
    // 3 waiting at once is the most.
    for (final n in [301, 302]) {
      r.fixes.add(LayoutFix(id: 'x$n', hid: 'anjani', room: n, snap: live.snap(), at: 0, mine: true));
    }
    r.openFixEditor('anjani', 304);
    expect(r.sheet, 'fixLimit');
    await tester.pump();
    expect(find.text('You have 3 fixes waiting at Anjani Residency'), findsOneWidget);
    // Withdraw it.
    r.update(() => r.sheet = null);
    await r.withdrawFix(mine);
    expect((mine.status, r.toast), ('withdrawn', 'Withdrawn. Nothing changes for tenants.'));
    r.dispose();

    // The owner: Today card → compare side by side → approve & publish.
    final o = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, o);
    // F21 W3: in "Needs you now".
    expect(find.text('Layout fix for Room 203'), findsOneWidget);
    await tap(tester, find.text('Compare'));
    expect(o.screen, 'oFix');
    expect(find.text('SUGGESTED'), findsOneWidget);
    expect(find.textContaining('WHAT CHANGED'), findsOneWidget);
    final ol = o.layoutOf('anjani', 203)!;
    final ov = ol.version;
    await tap(tester, find.text('Approve & publish'));
    await tester.pump();
    expect(o.screen, 'oFixDone');
    expect(find.text('Live for tenants'), findsOneWidget);
    expect(ol.version, ov + 1);
    expect(o.checkedLabel('anjani', 203), 'Checked by a resident · ${dayMon(appToday)}');
    expect(o.fixesWaiting, isEmpty);
    // Undo publish goes back; the check is taken away again.
    await tap(tester, find.textContaining('Undo publish'));
    expect(ol.version, ov);
    expect(o.checkedLabel('anjani', 203), isNull);
    // Reject with a reason the resident sees.
    final f2 = LayoutFix(id: 'fx9', hid: 'anjani', room: 203, snap: ol.snap(), at: 0, author: 'Teja N.', authorBed: '201-A');
    o.update(() => o.fixes = [...o.fixes, f2]);
    o.openFix(f2);
    await tester.pump();
    await tap(tester, find.text('Reject'));
    expect(o.sheet, 'fixReject');
    await tap(tester, find.text('It was moved back'));
    await tap(tester, find.text('Reject the fix'));
    expect((f2.status, f2.reason), ('rejected', 'It was moved back'));
    expect(o.toast, 'Rejected. The current layout stays live. Teja can send a new fix.');
    expect(v0, isNonZero);
    o.dispose();
  });

  test('F19: on Supabase, fixes go to the server; owners publish their own layouts there', () async {
    // Rows from the server, and the public "checked" counts.
    final row = {'id': 'lf-1', 'hostel_id': 'h1', 'room': 101, 'author_id': 'fb-rahul', 'author_name': 'Rahul Varma', 'author_bed': '204-B', 'layout': {'w': 18, 'h': 15, 'beds': {'A': [1, 1]}, 'items': [{'id': 'fan1', 'kind': 'fan', 'x': 2, 'y': 7, 'w': 1, 'h': 1}]}, 'note': 'Fan', 'status': 'pending', 'base_version': 1, 'created_at': '2026-10-02T10:00:00Z'};
    final f = fixFromRow(row, me: 'fb-rahul');
    expect((f.author, f.mine, f.snap.items.single.x, f.snap.beds['A']), ('Rahul V.', true, 2.0, const Offset(1, 1)));
    expect(fixFromRow(row, me: 'fb-owner').mine, isFalse);
    expect(listingsFromRows(const [], checks: {'h1': {101: (3, '2 Oct')}}).checks['h1']![101], (3, '2 Oct'));
    final j = layoutJson(f.snap);
    expect(snapFromJson(j).items.single.id, 'fan1');

    final s = AppState(start: 'rHome', role: 'resident');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-rahul', stays: [
      {'id': 'st1', 'hostel_id': 'anjani', 'user_id': 'fb-rahul', 'name': 'Rahul Varma', 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-01'},
    ]));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-rahul', name: 'Rahul', email: 'r@gmail.com'));
    await s.startLive();
    expect(s.myHostel, 'anjani');
    s.openFixEditor('anjani', 203);
    final fan = s.fixLayout!.of('fan').first;
    s.edSelect(fan.id);
    s.edNudge(s.fixLayout!, 1, 0);
    s.openSendFix();
    s.update(() => s.fixNote = 'Fan moved');
    await s.sendFix();
    expect(fake.calls.single, startsWith('fix anjani 203 '));
    expect(s.screen, 'rRoom');
    // The owner decides on the server.
    s.update(() {
      s.role = 'owner';
      s.fixes = [LayoutFix(id: 'lf-2', hid: 'anjani', room: 203, snap: s.layoutOf('anjani', 203)!.snap(), at: 0, author: 'Rahul V.')];
    });
    await s.approveFix(s.fixes.single);
    expect(fake.calls.last, 'fixdecide lf-2 true ');
    expect(s.screen, 'oFixDone');
    s.update(() => s.fixReason = 'Not accurate');
    await s.rejectFix(LayoutFix(id: 'lf-3', hid: 'anjani', room: 203, snap: s.layoutOf('anjani', 203)!.snap(), at: 0, author: 'Rahul V.'));
    expect(fake.calls.last, 'fixdecide lf-3 false Not accurate');
    // Owners publish their own edits straight to the server.
    s.publishLayout(s.layoutOf('anjani', 204)!);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls.last, 'publish anjani 204');
    s.stopLive();
    s.dispose();
  });

  test('sign-in errors: the real code is shown and sent to Crashlytics, never hidden', () async {
    final s = AppState(start: 'login', role: 'tenant');
    final gs = _FakeSignIn(SignInFail.failed);
    final push = _FakePush(false);
    s
      ..signIn = gs
      ..push = push;
    // No code known: the plain message, nothing reported.
    await s.continueWithGoogle();
    expect(s.toast, 'Couldn’t sign in. Check your internet and try again.');
    expect(push.reported, isEmpty);
    // A real code: in the toast and in Crashlytics.
    gs.lastError = 'firebase: internal-error · Requests from this Android client application app.hostelzy.hostelzy.demo are blocked.';
    await s.continueWithGoogle();
    expect(s.toast, 'Couldn’t sign in (${gs.lastError}). Try again.');
    expect(push.reported.single, contains('app.hostelzy.hostelzy.demo are blocked'));
    gs
      ..fail = SignInFail.notSetUp
      ..lastError = 'google: clientConfigurationError';
    await s.continueWithGoogle();
    expect(s.toast, 'Google sign-in isn’t set up for this app (google: clientConfigurationError). Use Hostelzy on this phone for now.');
    // Closing Google isn't an error.
    gs
      ..fail = SignInFail.cancelled
      ..lastError = 'google: canceled';
    await s.continueWithGoogle();
    expect((s.toast, push.reported.length), ('Sign-in cancelled.', 2));
    s.dispose();
  });

  test('C: on Supabase, the owner sees server sign-ups and approving or removing goes to the server', () async {
    final rows = liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner', signups: [
      {'id': 'su-1', 'name': 'Ravi Teja', 'phone': '9000000040', 'bed': '101-B', 'status': 'pending', 'user_id': 'fb-ravi', 'created_at': '2026-10-02T10:00:00Z'},
      {'id': 'su-2', 'name': 'Old One', 'phone': '9000000041', 'bed': null, 'status': 'approved', 'user_id': 'fb-old', 'created_at': '2026-10-01T10:00:00Z'},
      {'id': 'su-3', 'name': 'Me Myself', 'phone': '9000000042', 'bed': '', 'status': 'pending', 'user_id': 'fb-owner', 'created_at': '2026-10-02T10:00:00Z'},
    ], now: DateTime.parse('2026-10-02T12:00:00Z').millisecondsSinceEpoch);
    // Only pending sign-ups from other people are listed.
    expect(rows.signups.map((g) => (g.id, g.name, g.bed)), [('su-1', 'Ravi Teja', '101-B')]);
    final s = AppState(start: 'oInvite', role: 'owner');
    final fake = _FakeLive(rows);
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    expect(s.signups.single.name, 'Ravi Teja');
    final before = s.residents.length;
    s.approveSignup(s.signups.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, ['signup su-1 true']);
    expect(s.toast, 'Ravi is now a resident here.');
    expect(s.residents.length, before); // no local stand-in: the server makes the stay
    s.rejectSignup(s.signups.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect((fake.calls.last, s.toast), ('signup su-1 false', 'Removed.'));
    // Offline: nothing is said to be done.
    fake.fail = true;
    s.approveSignup(s.signups.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(s.toast, 'Couldn’t save it. Check your internet and try again.');
    expect(fake.calls.length, 2);
    s.stopLive();
    s.dispose();
  });

  testWidgets('C: server invite codes: owner gets one, a resident asks to join', (tester) async {
    // Owner on Supabase: the code comes from the server; a new one replaces it.
    final o = AppState(start: 'oInvite', role: 'owner');
    final od = _FakeInvites();
    o.data = od;
    await pumpApp(tester, o);
    await tester.pump();
    await tester.pump();
    expect(find.text('farhath.me/hostelzy/app/j/?c=VAS-7Q2'), findsOneWidget);
    await tap(tester, find.text('Make a new code (the old one stops working)'));
    await tester.pump();
    expect((o.inviteCode, o.toast), ('VAS-K9P', 'New code VAS-K9P. The old link and poster stop working.'));
    o.dispose();

    // Resident gate: the code from the invite link is filled in; joining needs Google.
    final r = AppState(start: 'roleGate', role: 'tenant');
    r.data = od;
    r.update(() {
      r.roleGate = 'resident';
      r.pendingInvite = 'VAS-K9P';
      r.myName = 'Kiran Rao';
      r.phone = '9876543210';
    });
    await pumpApp(tester, r);
    expect(find.byKey(const ValueKey('inviteCode')), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('joinGo')));
    expect(r.toast, 'Sign in with Google to join with a code.');
    await tester.pump(const Duration(seconds: 3));
    r.update(() => r.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com'));
    await tap(tester, find.byKey(const ValueKey('joinGo')));
    await tester.pump();
    expect(od.joined, ('VAS-K9P', 'Kiran Rao', '9876543210'));
    expect((r.toast, r.pendingInvite), ('Asked to join Vasavi Boys Hostel. Your owner approves it, then your stay opens here.', null));
    await tester.pump(const Duration(seconds: 3));
    // A retired code: the server's reason, in plain words.
    od.joinError = 'P0001: that invite code isn\'t valid any more; ask your owner for the new one';
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('inviteCode')), matching: find.byType(TextField)), 'vas-7q2');
    await tap(tester, find.byKey(const ValueKey('joinGo')));
    await tester.pump();
    expect(r.toast, 'That code isn’t valid any more. Ask your owner for the new one.');
    await tester.pump(const Duration(seconds: 3));
    // Sample data never pretends to send it.
    r.data = const SampleRepo();
    await tap(tester, find.byKey(const ValueKey('joinGo')));
    await tester.pump();
    expect(r.toast, 'Invites work in the real Hostelzy app. This is sample data.');
    await tester.pump(const Duration(seconds: 3));
    r.dispose();
  });

  testWidgets('push fix: after sign-in the app offers once, saves the token every start, and says when it fails', (tester) async {
    final s = AppState(start: 'role', role: 'tenant');
    final data = _FakeData();
    final fp = _FakePush(true);
    s
      ..data = data
      ..push = fp
      ..signIn = _FakeSignIn(null);
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com'));
    s.watchPushToken();
    await pumpApp(tester, s);
    // F21 W2: no prompt on arrival; tenants are asked after their first hold, once.
    s.pickRole('tenant');
    await tester.pump();
    await tester.pump();
    expect((s.screen, s.pushAsked), ('explore', false));
    await s.askPushAfterHold();
    await tester.pump();
    expect((s.sheet, s.pushAsked), ('holdNotify', true));
    expect(find.text('Turn on notifications so the owner’s reply reaches you.'), findsOneWidget);
    await tap(tester, find.text('Not now'));
    expect((s.sheet, fp.asked), (null, 0));
    expect(data.tokens, isEmpty);
    // "Not now" is remembered, also on the phone.
    expect(s.snapshot()['pushAsked'], isTrue);
    await s.askPushAfterHold();
    expect(s.sheet, isNull);
    // Settings shows the switch off while Android has it off; tapping asks right away.
    s.update(() => s.screen = 'settings');
    await tester.pump();
    expect(s.notifOn('hold'), isFalse);
    await tap(tester, find.text('Holds and bookings'));
    await tester.pump();
    expect((fp.asked, s.notifOn('hold')), (1, true));
    expect(data.tokens, ['fcm-token']);
    await tester.pump(const Duration(seconds: 3));
    // Allowed some other way (phone settings): the next start just saves the token.
    final again = AppState(start: 'explore', role: 'tenant');
    final d2 = _FakeData();
    again
      ..data = d2
      ..push = _FakePush(false, granted: true);
    again.update(() => again.account = (uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com'));
    expect(await again.syncPushToken(), isTrue);
    expect(d2.tokens, ['fcm-token']);
    // FCM rotates the token: the server gets the new one.
    fp.refresh.add('fcm-token-2');
    await tester.pump();
    expect(data.tokens.last, 'fcm-token-2');
    // A failed save is said out loud, never silent.
    d2.failTokens = true;
    expect(await again.syncPushToken(force: true), isFalse);
    expect(again.toast, 'Couldn’t turn on notifications for this phone. Check your internet; we’ll try again when you open the app.');
    // Not signed in: no prompt, nothing saved.
    final anon = AppState(start: 'role', role: 'tenant');
    anon.push = _FakePush(true);
    anon.pickRole('tenant');
    await tester.pump();
    expect(anon.screen, 'explore');
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
    again.dispose();
    anon.dispose();
  });

  testWidgets('F25: a tenant never sees both notification asks; residents and owners keep the explainer', (tester) async {
    final s = AppState(start: 'role', role: 'tenant');
    s
      ..data = _FakeData()
      ..push = _FakePush(true)
      ..signIn = _FakeSignIn(null);
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha K', email: 'asha@gmail.com'));
    await pumpApp(tester, s);
    s.pickRole('tenant');
    // Even asked directly, the role-pick explainer (S82 perm) never opens for a tenant.
    await s.offerPush();
    await tester.pump();
    expect((s.screen, s.pushAsked, s.hist.contains('perm')), ('explore', false, false));
    // The tenant's one ask is H5 after the first hold.
    await s.askPushAfterHold();
    await tester.pump();
    expect((s.sheet, s.pushAsked, s.screen), ('holdNotify', true, 'explore'));
    expect(find.text('Turn on notifications?'), findsNothing);

    // An owner (or resident) gets S82 at role pick, and then never H5.
    final o = AppState(start: 'oToday', role: 'owner');
    o
      ..data = _FakeData()
      ..push = _FakePush(true)
      ..signIn = _FakeSignIn(null);
    o.update(() => o.account = (uid: 'fb-imran', name: 'Imran', email: 'i@gmail.com'));
    await o.offerPush();
    expect((o.screen, o.pushAsked), ('perm', true));
    await o.askPushAfterHold();
    expect(o.sheet, isNull);
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
    o.dispose();
  });

  testWidgets('F25: one "Add a resident" sheet from the + tab and Residents › Add; the date says Moves in or Joined on', (tester) async {
    final s = AppState(start: 'oToday', role: 'owner');
    await pumpApp(tester, s);
    String dateLabel() => tester.widget<T>(find.descendant(of: find.byKey(const ValueKey('addDateLabel')), matching: find.byType(T))).text;
    // The sheet scrolls: let the scroll settle before tapping.
    Future<void> tapS(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(f);
      await tester.pump();
    }

    // The toast sits over the button: let it go first.
    Future<void> go() async {
      await tester.pump(const Duration(seconds: 3));
      await tapS(find.byKey(const ValueKey('addGo')));
    }

    // Entry 1: the centre "+" tab.
    await tap(tester, find.text('Add tenant'));
    expect(s.sheet, 'addR');
    expect(find.text('Add a resident'), findsOneWidget);
    expect(find.text('Add tenant'), findsOneWidget); // only the tab label: no second sheet
    expect(dateLabel(), 'Joined on'); // today
    await tapS(find.text('Tomorrow'));
    expect((dateLabel(), s.rFuture), ('Moves in', true));
    expect(find.byKey(const ValueKey('rBefore')), findsNothing); // only for people already living here
    await tapS(find.text('Yesterday'));
    expect((dateLabel(), s.rFuture), ('Joined on', false));
    await tapS(find.text('Pick date'));
    await tapS(find.byKey(const ValueKey('addDay-3')));
    expect((dateLabel(), s.rJoinAt > s.now), ('Moves in', true));
    await tapS(find.byKey(const ValueKey('addDay5')));
    expect((dateLabel(), s.rJoinAt < s.now), ('Joined on', true));

    // The merged checks: a name, a real mobile number, a bed.
    await go();
    expect(s.toast, 'Add the resident’s name.');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('addName')), matching: find.byType(EditableText)), 'Kiran Kumar');
    await tester.pump();
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('addPhone')), matching: find.byType(EditableText)), '12345');
    await tester.pump();
    await go();
    expect(s.toast, 'Add their 10-digit WhatsApp number.');
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('addPhone')), matching: find.byType(EditableText)), '1234567890');
    await tester.pump();
    await go();
    expect(s.toast, 'That mobile number doesn’t look right (10 digits, 6–9 first).');

    // A future date is a booking (demo): Due, "Moves in …", the welcome toast.
    final free = s.rooms['anjani']!.expand((r) => r.beds).firstWhere((b) => b.state == 'free').id;
    s.pickResidentBed(free);
    FocusManager.instance.primaryFocus?.unfocus();
    s.update(() => s.rPhone = '9876500031');
    await tester.pump(const Duration(seconds: 3));
    await tapS(find.text('Tomorrow'));
    expect(find.text('Book the bed'), findsOneWidget);
    await go();
    final r = s.residents.first;
    expect((r.name, r.bed, r.status, r.note, r.confirmed, s.sheet), ('Kiran Kumar', free, 'Due', 'Moves in ${dayMon(appToday.add(const Duration(days: 1)))}', false, null));
    expect(s.toast, 'Booked bed $free. Send them a welcome on WhatsApp.');
    expect(s.findBed('anjani', free).b!.state, 'booked');
    // The same bed can't be added twice.
    s.openAddResident(bed: free);
    s.update(() {
      s.rName = 'Someone Else';
      s.rPhone = '9876500032';
    });
    s.addResident();
    expect(s.toast, 'Bed $free is already taken.');
    s.update(() => s.sheet = null);
    await tester.pump(const Duration(seconds: 3));

    // Entry 2: Manage › Residents › Add opens the same sheet.
    s.jump('oMore', 'owner');
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('manage-Residents')));
    await tap(tester, find.text('Add resident'));
    expect(s.sheet, 'addR');
    expect(find.text('Add a resident'), findsOneWidget);
    expect(dateLabel(), 'Joined on');
    await tester.pump(const Duration(seconds: 3));
    s.dispose();
  });

  test('F25: "Add a resident" saves through addStayLive: a future date is a booking, a past one a stay', () async {
    final s = AppState(start: 'oToday', role: 'owner');
    final fake = _FakeLive(liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: 'fb-owner'));
    s.data = fake;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Imran', email: 'i@gmail.com'));
    await s.startLive();
    final ids = <String>[], rents = <int>[];
    for (final r in s.rooms[s.ownHid]!) {
      for (var i = 0; i < r.beds.length && ids.length < 2; i++) {
        final b = r.beds[i];
        if (b.state != 'free') continue;
        r.beds[i] = Bed(id: b.id, letter: b.letter, room: b.room, floor: b.floor, spot: b.spot, state: 'free', soon: '', key: 'bed-${ids.length}');
        ids.add(b.id);
        rents.add(r.rent);
      }
    }
    expect(ids.length, 2);
    Future<void> settle() async {
      for (var k = 0; k < 4; k++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    // Like the "+" tab or a free bed's "Add tenant to this bed": moves in tomorrow.
    s.openAddResident(bed: ids[0]);
    s.update(() {
      s.rName = 'Ravi Kumar';
      s.rPhone = '9876500002';
      s.rJoin = 'Tomorrow';
    });
    s.addResident();
    await settle();
    expect(fake.calls.single, 'stay ${s.ownHid} bed-0 Ravi Kumar 9876500002 ${rents[0]} 3000');
    expect(fake.stayJoinedOn!.difference(DateTime.fromMillisecondsSinceEpoch(s.now)).inHours, inInclusiveRange(23, 24));
    expect((s.sheet, s.toast), (null, 'Booked bed ${ids[0]}. Send them a welcome on WhatsApp.'));

    // Like Residents › Add: joined 5 days ago.
    s.openAddResident(bed: ids[1]);
    s.update(() {
      s.rName = 'Sai Teja';
      s.rPhone = '9876500003';
      s.rJoin = 'Pick date';
      s.rPickBack = 5;
    });
    s.addResident();
    await settle();
    expect(fake.calls.last, 'stay ${s.ownHid} bed-1 Sai Teja 9876500003 ${rents[1]} 3000');
    expect(DateTime.fromMillisecondsSinceEpoch(s.now).difference(fake.stayJoinedOn!).inDays, 5);
    expect(s.toast, 'Added. Sai confirms by joining with your invite code.');
    s.stopLive();
    s.dispose();
  });
}

class _FakePush implements Push {
  _FakePush(this.allow, {this.granted = false});
  final bool allow;

  /// Android's permission right now.
  bool granted;
  int asked = 0, deleted = 0;
  // ignore: close_sinks
  final refresh = StreamController<String>.broadcast();
  @override
  Future<PushAsk> ask() async {
    asked++;
    if (allow) granted = true;
    return allow ? PushAsk.allowed : PushAsk.denied;
  }

  @override
  Future<String?> token() async => 'fcm-token';
  @override
  Future<bool?> allowed() async => granted;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Future<void> deleteToken() async => deleted++;
  @override
  Stream<(String, String)> get foreground => const Stream.empty();
  final reported = <String>[];
  @override
  void report(Object error, {String? reason}) => reported.add('$reason $error');
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
  SignInFail? reauthFail;
  bool userDeleted = false;
  @override
  Future<SignInFail?> reauth() async => reauthFail;
  @override
  Future<void> deleteUser() async => userDeleted = true;
  @override
  String? lastError;
}

class _FakeData extends SampleRepo {
  ({String name, String email, String phone, String role})? profile;
  @override
  bool get remote => true;
  final tokens = <String>[], removed = <String>[];
  bool failTokens = false;
  @override
  Future<void> removePushToken(String token) async => removed.add(token);
  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) async => profile = (name: name, email: email, phone: phone, role: role);
  @override
  Future<void> savePushToken(String token) async {
    if (failTokens) throw Exception('offline');
    tokens.add(token);
  }
  bool deleted = false;
  String? deleteError;
  @override
  Future<void> deleteMyAccount() async {
    if (deleteError != null) throw Exception(deleteError);
    deleted = true;
  }
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
  // ignore: close_sinks
  final ctrl = StreamController<String>.broadcast();
  @override
  Future<LiveRows?> live({String? me}) async {
    fetches++;
    askedAs = me;
    return rows;
  }

  @override
  Stream<String> changes() => ctrl.stream;

  // C: live writes, recorded.
  final calls = <String>[];

  /// F25: the date the last added stay was saved with.
  DateTime? stayJoinedOn;
  bool fail = false;
  Future<void> _rec(String c) async {
    if (fail) throw Exception('offline');
    calls.add(c);
  }

  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) async {
    await _rec('enquiry $hid $bed $name $phone');
    rows = (holds: rows.holds, enquiries: [Enquiry(ref: 'HZ-5009', name: name, phone: phone, hid: hid, bed: bed, at: 0, from: source, msg: msg), ...rows.enquiries], payments: rows.payments, complaints: rows.complaints, expired: rows.expired, myHostel: rows.myHostel, signups: rows.signups, residents: rows.residents, invoices: rows.invoices, trialEnds: rows.trialEnds, cases: rows.cases, myHostels: rows.myHostels, managers: rows.managers, fixes: rows.fixes, rewards: rows.rewards, mutes: rows.mutes, myStay: rows.myStay, moves: rows.moves, refunds: rows.refunds, myRefund: rows.myRefund);
    return 'HZ-5009';
  }

  @override
  Future<void> markContacted(String ref) => _rec('contacted $ref');
  @override
  Future<void> sendUtr(String paymentId, String utr) => _rec('utr $paymentId $utr');
  @override
  Future<void> confirmPayment(String paymentId, bool received, {String? holdId}) => _rec('confirm $paymentId $received $holdId');
  @override
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body, String? photo}) => _rec('complaint $hid $cat $body${photo != null ? ' $photo' : ''}');
  @override
  Future<void> updateComplaint(String key, {required String status, required String note}) => _rec('complaint $key $status');
  @override
  Future<void> decideSignup(String id, bool approve) => _rec('signup $id $approve');

  // S1: holds placed on the server.
  String? holdError;
  @override
  Future<({String id, String ref, String? payId})> placeHold({required String hid, required String bedKey, required String opt, int advance = 0}) async {
    if (holdError != null) throw Exception(holdError);
    await _rec('hold $hid $bedKey $opt $advance');
    final n = calls.where((c) => c.startsWith('hold ')).length;
    final id = 'hold-uuid-$n', payId = opt == 'book' ? 'pay-uuid-$n' : null;
    rows = (
      holds: [...rows.holds, Hold(id: id, hid: hid, bed: '101-A', room: 101, opt: opt, start: 0, status: opt == 'book' ? 'paying' : 'waiting', ref: 'HZ-501$n', paid: advance)],
      enquiries: rows.enquiries,
      payments: [...rows.payments, if (payId != null) Payment(id: payId, kind: 'advance', hid: hid, who: 'Asha', what: 'Advance for bed 101-A', bed: '101-A', amt: advance, note: 'HZ-501$n', holdId: id)],
      complaints: rows.complaints, expired: rows.expired, myHostel: rows.myHostel, signups: rows.signups, residents: rows.residents, invoices: rows.invoices, trialEnds: rows.trialEnds, cases: rows.cases, myHostels: rows.myHostels, managers: rows.managers, fixes: rows.fixes, rewards: rows.rewards, mutes: rows.mutes, myStay: rows.myStay, moves: rows.moves, refunds: rows.refunds, myRefund: rows.myRefund,
    );
    return (id: id, ref: 'HZ-501$n', payId: payId);
  }

  // S6: Stay Rewards.
  String? friendError;
  @override
  Future<String> referralCode() async {
    await _rec('refcode');
    return 'ASHA-4K7Q';
  }

  @override
  Future<String> useReferralCode(String code) async {
    if (friendError != null) throw Exception(friendError);
    await _rec('usecode $code');
    return 'Ravi';
  }
  // F19: layout fixes.
  @override
  Future<String> sendLayoutFix(String hid, int room, Map<String, dynamic> layout, String note, {String? photo}) async {
    await _rec('fix $hid $room ${(layout['items'] as List).length} $note');
    return 'lf-1';
  }

  @override
  Future<void> withdrawLayoutFix(String id) => _rec('fixwithdraw $id');
  @override
  Future<void> decideLayoutFix(String id, bool approve, {String reason = ''}) => _rec('fixdecide $id $approve $reason');
  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) => _rec('publish $hid $room');
  @override
  Future<void> undoLayoutPublish(String hid, int room) => _rec('undo $hid $room');

  // S8: managers.
  @override
  Future<String> managerInvite(String hid, String name, String phone) async {
    await _rec('mgr $hid $name $phone');
    return 'MGR-ABCD2345';
  }

  @override
  Future<String> joinAsManager(String code) async {
    await _rec('joinmgr $code');
    return 'Sai PG';
  }

  // S5: Fair Play.
  @override
  Future<void> sendReport(String hid, String why, String note) => _rec('report $hid $why $note');
  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) => _rec('casereply $key $reply $reopen');
  String? fixError;
  @override
  Future<void> fixCase(String key) async {
    if (fixError != null) throw Exception(fixError);
    await _rec('fix $key');
  }


  // S4: reviews.
  @override
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) =>
      _rec('review $hid $name $kind $stars $body ${cats.length} $layout $advance $again');
  @override
  Future<void> replyReview(String id, String reply) => _rec('reply $id $reply');
  int listingsFetched = 0;
  @override
  Future<Listings?> listings() async {
    listingsFetched++;
    return null;
  }

  // S7: plan invoices.
  @override
  Future<void> sendInvoiceUtr(String key, String utr) => _rec('invutr $key $utr');

  // S3: owner edits.
  @override
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms) => _rec('rates $hid ${rates.length} ${rooms.length}');
  @override
  Future<void> saveDeals(String hid, Deals d) => _rec('deals $hid ${(d.on.toList()..sort()).join(',')} ${d.target}');
  @override
  Future<void> saveRules(String hid, List<Rule> rules) => _rec('rules $hid ${rules.map((r) => '${r.k}=${r.v}').join(';')}');
  @override
  Future<void> saveUpi(String hid, String id, String name) => _rec('upi $hid $id $name');

  // S2: the owner's residents and hold decisions.
  @override
  Future<void> setHoldStatus(String id, String status) => _rec('holdstatus $id $status');
  @override
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn, bool before = false}) async {
    stayJoinedOn = joinedOn;
    await _rec('stay $hid $bedKey $name $phone $rent $advance${before ? ' before' : ''}');
    rows = (holds: rows.holds, enquiries: rows.enquiries, payments: rows.payments, complaints: rows.complaints, expired: rows.expired, myHostel: rows.myHostel, signups: rows.signups, residents: [
      Resident(name: name, bed: '101-A', amt: rent, status: 'Due', note: '', phone: phone, via: 'direct', since: 'Added today', confirmed: false, key: 'stay-uuid'),
      ...rows.residents,
    ], invoices: rows.invoices, trialEnds: rows.trialEnds, cases: rows.cases, myHostels: rows.myHostels, managers: rows.managers, fixes: rows.fixes, rewards: rows.rewards, mutes: rows.mutes, myStay: rows.myStay, moves: rows.moves, refunds: rows.refunds, myRefund: rows.myRefund);
    return (via: 'direct', lateDays: 0);
  }

  @override
  Future<void> releaseHold(String id, {bool cancelPay = true}) async {
    await _rec('release $id $cancelPay');
    rows = (holds: [for (final h in rows.holds) h.id == id ? h.withStatus('released') : h], enquiries: rows.enquiries, payments: rows.payments, complaints: rows.complaints, expired: rows.expired, myHostel: rows.myHostel, signups: rows.signups, residents: rows.residents, invoices: rows.invoices, trialEnds: rows.trialEnds, cases: rows.cases, myHostels: rows.myHostels, managers: rows.managers, fixes: rows.fixes, rewards: rows.rewards, mutes: rows.mutes, myStay: rows.myStay, moves: rows.moves, refunds: rows.refunds, myRefund: rows.myRefund);
  }
}

/// C: server invites stand-in.
class _FakeInvites extends SampleRepo {
  int calls = 0;
  (String, String, String)? joined;
  String? joinError;
  @override
  Future<String?> inviteCode(String hid, {bool renew = false}) async => renew ? 'VAS-K9P' : 'VAS-7Q2';
  @override
  Future<String> joinWithInvite(String code, {required String name, required String phone, String bed = ''}) async {
    if (joinError != null) throw Exception(joinError);
    joined = (code, name, phone);
    return 'Vasavi Boys Hostel';
  }
}

class _FakeLocator implements Locator {
  _FakeLocator(this.pos, [this.fail]);
  final (double, double)? pos;
  final LocateFail? fail;
  int asked = 0;
  @override
  Future<((double, double)?, LocateFail?)> locate({bool exact = false}) async {
    asked++;
    return (pos, fail);
  }
}
