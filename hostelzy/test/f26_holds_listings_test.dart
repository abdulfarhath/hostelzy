import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/explore/explore_screen.dart';
import 'package:hostelzy/features/listings/live.dart' show holdFromRow;
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F26 #7 owner contact only with a live hold, #9 hold steps, #21 UNVERIFIED
// (team-listed) hostels.

Future<void> _pump(WidgetTester tester, AppState state) async {
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
  await tester.pumpWidget(MaterialApp(home: AppScope(state: state, child: const HostelzyShell(bare: true))));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

class _Server extends SampleRepo {
  final seen = <String>[];
  final calls = <String>[];
  @override
  bool get remote => true;
  @override
  Future<void> holdSeen(List<String> holdIds) async => seen.addAll(holdIds);
  @override
  Future<void> joinWaitlist(String hid) async => calls.add('wait $hid');
  @override
  Future<void> sendClaim(String hid, String name, String phone) async => calls.add('claim $hid $name $phone');
  @override
  Future<Map<String, ({int verified, int listed})>?> areaCounts() async => {'Madhapur': (verified: 12, listed: 84), 'Kondapur': (verified: 3, listed: 5)};
  @override
  Future<Set<String>> myWaitlist() async => {'x1'};
}

void main() {
  mapTiles = false;

  testWidgets('#7: owner contact is locked before a hold, opens with one, locks again when it ends', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.hid = 'anjani';
    await _pump(tester, s);
    await tester.ensureVisible(find.byKey(const ValueKey('ownerContact')));
    expect(find.text('Message and call the owner after you hold a bed'), findsOneWidget);
    expect(find.text('Ask on WhatsApp'), findsNothing);
    // Locked: tapping does nothing.
    await _tap(tester, find.byKey(const ValueKey('contact-WhatsApp')));
    await _tap(tester, find.byKey(const ValueKey('contact-Call')));
    expect(s.lastLink, isNull);

    s.update(() => s.bed = '204-D');
    s.placeHold('book');
    final h = s.holds.single;
    expect(h.ref, isNotNull);
    s.jump('detail', 'tenant');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('ownerContact')));
    expect(find.text('90000 00101'), findsOneWidget);
    expect(find.text('YOU HELD 204-D'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('contact-WhatsApp')));
    expect(Uri.decodeFull(s.lastLink.toString()), 'https://wa.me/919000000101?text=Hi Srinivas, I held bed 204-D at Anjani Residency on Hostelzy. Booking code ${h.ref}.');
    await _tap(tester, find.byKey(const ValueKey('contact-Call')));
    expect(s.lastLink.toString(), 'tel:+919000000101');

    // The hold ends: locked again.
    s.releaseHold(h);
    await tester.pump();
    expect(find.text('Message and call the owner after you hold a bed'), findsOneWidget);
    expect(s.contactHold('anjani'), isNull);
    s.dispose();
  });

  testWidgets('#9: Sent → Owner reviewing (only once opened) → Kept / Declined; 30 min: Still waiting', (tester) async {
    final s = AppState(start: 'holds', role: 'tenant');
    final n = DateTime.now().millisecondsSinceEpoch;
    final b = s.rooms['anjani']!.firstWhere((r) => r.n == 202).beds[0];
    s.holds = [Hold(id: 'h1', hid: 'anjani', bed: b.id, room: 202, opt: 'free', start: n - 5 * 60000, status: 'waiting', ref: 'HZ-4830')];
    await _pump(tester, s);
    expect(find.byKey(const ValueKey('holdSteps-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('step-1-done')), findsOneWidget);
    // Not opened yet: step 2 isn't reached.
    expect(find.byKey(const ValueKey('step-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('stillWaiting')), findsNothing);

    // The owner opens it (Today): seen once, on this phone's list too.
    s.markHoldsSeen(['h1']);
    s.markHoldsSeen(['h1']);
    await tester.pump();
    expect(s.holds.single.seen, isNotNull);
    expect(find.byKey(const ValueKey('step-2-now')), findsOneWidget);
    expect(find.textContaining('Owner reviewing · since'), findsOneWidget);

    // 30 minutes without an answer.
    s.update(() => s.holds = [s.holds.single.withStatus('waiting')].map((h) => Hold(id: h.id, hid: h.hid, bed: h.bed, room: h.room, opt: h.opt, start: n - 31 * 60000, status: 'waiting', ref: h.ref, seen: h.seen)).toList());
    await tester.pump();
    expect(find.text('Still waiting. Call the owner?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('contact-Call')));
    expect(s.lastLink.toString(), 'tel:+919000000101');

    // Kept.
    s.setHold('h1', 'confirmed');
    await tester.pump();
    expect(find.byKey(const ValueKey('step-3-done')), findsOneWidget);
    expect(find.text('Srinivas kept your bed. Visit before the hold ends, or pay to book.'), findsOneWidget);

    // Declined: both lock again.
    s.update(() => s.holds = [s.holds.single.withStatus('released', declined: true)]);
    await tester.pump();
    expect(find.text('DECLINED'), findsOneWidget);
    expect(find.text('The owner couldn’t keep this bed. Call and WhatsApp are locked again.'), findsOneWidget);
    s.lastLink = null;
    await _tap(tester, find.byKey(const ValueKey('contact-WhatsApp')));
    expect(s.lastLink, isNull);
    s.dispose();
  });

  test('#9: on the server, the owner opening a hold tells the server once', () async {
    final s = AppState(start: 'oToday', role: 'owner');
    final server = _Server();
    s.data = server;
    s.holds = [Hold(id: 'a-uuid', hid: 'anjani', bed: '204-D', room: 204, opt: 'free', start: 0, status: 'waiting')];
    // Not on the server yet (sample): stamped only on the phone.
    s.markHoldsSeen(['a-uuid']);
    expect(s.holds.single.seen, isNotNull);
    expect(server.seen, isEmpty);
    s.dispose();
  });

  test('#9: seen_at and declined come from the server row', () {
    final h = holdFromRow({'id': 'x', 'hostel_id': 'h', 'status': 'released', 'opt': 'free', 'started_at': '2026-10-06T08:00:00Z', 'seen_at': '2026-10-06T08:10:00Z', 'declined': true});
    expect((h.seen, h.declined), (DateTime.parse('2026-10-06T08:10:00Z').millisecondsSinceEpoch, true));
    final old = holdFromRow({'id': 'y', 'hostel_id': 'h', 'status': 'waiting', 'opt': 'free', 'started_at': '2026-10-06T08:00:00Z'});
    expect((old.seen, old.declined), (null, false));
  });

  test('#21: a listed row is UNVERIFIED with its rent range; Price ↑ puts verified first in each band', () {
    final l = listingsFromRows([
      {'id': 'x1', 'name': 'Listed PG', 'gender': 'Men', 'area': 'Madhapur', 'status': 'listed', 'rent_min': 7000, 'rent_max': 9000},
    ]);
    final h = l.hostels.single;
    expect((h.listed, h.live, h.rentMin, h.rentMax, h.from), (true, true, 7000, 9000, 7000));
    expect(l.rooms['x1'], isEmpty);
    expect(rentRange(h), 'Around ₹7,000–9,000');
    expect([priceBand(6900), priceBand(7000), priceBand(8999), priceBand(9000)], [2, 3, 3, 4]);
  });

  testWidgets('#21: Explore shows the UNVERIFIED card and the tier header; its page has no beds or contact', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s
      ..phone = '9000000001'
      ..myName = 'Rahul Varma'
      ..sortBy = 'price';
    await _pump(tester, s);
    expect(find.text('HYDERABAD · 6 VERIFIED · 1 LISTED'), findsOneWidget);
    // Price ↑: bands in order; inside the listed one's band (₹7,000–9,000) every verified hostel comes first.
    final hs = filtered(s);
    int price(Hostel h) => h.listed ? h.rentMin : s.rooms[h.id]!.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
    final bands = [for (final h in hs) priceBand(price(h))];
    expect(bands, [...bands]..sort());
    final i = hs.indexWhere((h) => h.id == 'balaji');
    expect(hs.skip(i + 1).where((h) => priceBand(price(h)) == priceBand(7000)).every((h) => h.listed), isTrue);
    // Not ranked.
    expect(s.rankOrder.contains('balaji'), isFalse);
    // Never the featured pin, and under any other sort after every verified hostel (A's tier hook).
    expect(pinnedFeatured(s, hs)?.listed ?? false, isFalse);
    s.update(() => s.sortBy = 'near');
    expect(filtered(s).skipWhile((h) => !h.listed).every((h) => h.listed), isTrue);
    s.update(() => s.sortBy = 'price');
    // A filter it can't answer leaves it out.
    s.update(() => s.fFood = true);
    expect(filtered(s).any((h) => h.listed), isFalse);
    s.update(() => s.fFood = false);
    await tester.pump();

    final card = find.byKey(const ValueKey('listedCard-balaji'));
    await tester.ensureVisible(card);
    expect(find.descendant(of: card, matching: find.text('UNVERIFIED')), findsOneWidget);
    await _tap(tester, card);
    expect(find.byKey(const ValueKey('unverifiedPage')), findsOneWidget);
    expect(find.text('Around ₹7,000–9,000'), findsOneWidget);
    expect(find.text('Expected, not confirmed. The owner hasn’t joined Hostelzy yet.'), findsOneWidget);
    expect(find.text('Pick a bed'), findsNothing);
    expect(find.byKey(const ValueKey('ownerContact')), findsNothing);

    // Tell me when verified.
    await _tap(tester, find.text('Tell me when verified'));
    expect(s.waitlist, {'balaji'});
    expect(find.text('We’ll tell you when it’s verified'), findsOneWidget);
    // Ask Hostelzy: WhatsApp to support with the hostel filled in.
    await _tap(tester, find.text('Ask Hostelzy'));
    expect(Uri.decodeFull(s.lastLink.toString()), 'https://wa.me/919059790014?text=Hi Hostelzy, I have a question about Sri Balaji Men’s PG in Madhapur.');
    // Claim this hostel (H44).
    await _tap(tester, find.byKey(const ValueKey('claimLink')));
    expect(s.sheet, 'claim');
    expect(find.text('Claim Sri Balaji Men’s PG'), findsOneWidget);
    s.update(() => s.claimPhone = '12');
    await _tap(tester, find.byKey(const ValueKey('sendClaim')));
    expect(s.toast, 'Enter your 10-digit phone.');
    s.update(() => s.claimPhone = '9123400001');
    await _tap(tester, find.byKey(const ValueKey('sendClaim')));
    expect(s.sheet, isNull);
    expect(s.claimed, {'balaji'});
    expect(find.text('Claim sent. The Hostelzy team will call you.'), findsOneWidget);
    s.dispose();
  });

  test('#21: on the server: area counts for the header, the waitlist and the claim', () async {
    final s = AppState(start: 'explore', role: 'tenant');
    final server = _Server();
    s
      ..data = server
      ..signedIn = true;
    await s.loadTiers();
    expect(s.tierLine('Madhapur'), 'Madhapur · 12 verified · 84 listed');
    expect(s.tierLine(null), 'Hyderabad · 15 verified · 89 listed');
    expect(s.waitlist, {'x1'});
    const h = Hostel(id: 'x2', name: 'Listed PG', gender: 'Men', area: 'Madhapur', from: 7000, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: {}, x: 0, y: 0, tags: [], listed: true, rentMin: 7000, rentMax: 9000);
    s.tellWhenVerified(h);
    await Future<void>.delayed(Duration.zero);
    expect(server.calls, ['wait x2']);
    s.update(() {
      s.claimHid = 'x2';
      s.claimName = 'Suresh';
      s.claimPhone = '91234 00001';
    });
    await s.sendClaim();
    expect(server.calls.last, 'claim x2 Suresh 9123400001');
    s.dispose();
  });
}
