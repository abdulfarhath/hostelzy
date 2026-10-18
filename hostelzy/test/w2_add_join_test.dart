import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/photos/photo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';
import 'package:image/image.dart' as img;

// W2: F28 Part 2 (S92 Add a hostel, S93 Your hostel, entry points, rewards)
// and F29 Part 2 (H48 Ask to join, S94 Join form, H49 review, Today › Joining).

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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// The server as the app sees it: `add_hostel`, `my_added_hostel`, join RPCs.
class _Server extends SampleRepo {
  final calls = <String>[];
  bool dupNext = false;
  Map<String, dynamic>? mine;
  List<Map<String, dynamic>> joins = [];
  @override
  bool get remote => true;
  @override
  Future<Map<String, dynamic>> addHostel(Map<String, dynamic> p) async {
    calls.add('add ${p['name']} ${p['owner_phone']} ${p['partner_code'] ?? ''} ${p['rent'] ?? '${p['rent_min']}-${p['rent_max']}'}');
    if (dupNext) {
      dupNext = false;
      return {'duplicate': true, 'hostel_id': 'x9', 'name': 'Sri Sai PG'};
    }
    mine = {'id': 'h-new', 'name': p['name'], 'gender': p['gender'], 'area': p['area'], 'status': 'listed', 'source': p['partner_code'] == null ? 'resident' : 'partner', 'rent_min': p['rent'] ?? p['rent_min'], 'rent_max': p['rent'] ?? p['rent_max'], 'created_at': DateTime.now().toIso8601String(), 'photos': 0, 'owner_name': p['owner_name'], 'owner_phone': p['owner_phone'], 'upi': ''};
    return {'duplicate': false, 'hostel_id': 'h-new'};
  }

  @override
  Future<HostelPhoto> addPhoto(String hid, Uint8List jpg, {required String label, required int ord, required bool cover}) async {
    calls.add('photo $hid $label $ord $cover');
    return (id: 'p$ord', path: '$hid/p$ord.jpg', url: 'https://x/p$ord.jpg', label: label, ord: ord, cover: cover);
  }

  @override
  Future<Map<String, dynamic>?> myAddedHostel() async => mine;
  @override
  Future<void> askedOwner(String hid) async => calls.add('asked $hid');
  @override
  Future<void> setAdderUpi(String upi) async => calls.add('upi $upi');
  @override
  Future<String> newJoinRequest({required String bedKey, required int fee, required int advance, required DateTime movesIn, String name = ''}) async {
    calls.add('join $bedKey $fee $advance $name');
    return 'TOK4ABCDEFGH';
  }

  @override
  Future<Map<String, dynamic>?> joinRequestInfo(String token) async => token == 'BADTOKEN' ? null : {'id': 'j1', 'hostel_id': 'anjani', 'hostel': 'Anjani Residency', 'owner': 'Srinivas', 'bed': '203-A', 'fee': 6500, 'advance': 3000, 'moves_in': '2026-11-01', 'name_hint': 'Ravi', 'status': 'sent', 'taken': token == 'TAKENBED1', 'mine': false, 'id_received': 'none', 'drive': false, 'owner_phone': '9000000101'};
  @override
  Future<Map<String, dynamic>> fillJoinRequest({required String token, required String name, required String phone, required DateTime date, required String idReceived, String? idFileId}) async {
    calls.add('fill $token $name $phone ${date.day}/${date.month} $idReceived');
    return {'hostel': 'Anjani Residency', 'owner': 'Srinivas'};
  }

  @override
  Future<List<Map<String, dynamic>>> joinRequests(String hid) async => joins;
  @override
  Future<void> decideJoin(String id, bool approve, {String note = ''}) async {
    calls.add('decide $id $approve');
    joins = [];
  }

  @override
  Future<String> askIdAgain(String id) async {
    calls.add('askid $id');
    return '9876500011';
  }
}

Uint8List _jpg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 30)));

void main() {
  mapTiles = false;

  group('F28 Part 2 · Add a hostel', () {
    testWidgets('Explore end row → sign in first (guest); S92 for a signed-in tenant', (tester) async {
      final g = AppState(start: 'explore', role: 'tenant', auth: 'out');
      await _pump(tester, g);
      await _tap(tester, find.byKey(const ValueKey('addItRow')));
      expect(g.sheet, 'signIn');
      expect(g.afterSignIn, 'add');
      expect(find.text('Sign in to add a hostel'), findsOneWidget);
      g.dispose();
    });

    testWidgets('S92: checks, dedupe by name within 150 m, then the listed card and S93 "Send to your owner"', (tester) async {
      final s = AppState(start: 'explore', role: 'tenant');
      s.myName = 'Asha K';
      s.phone = '9876543210';
      await _pump(tester, s);
      await _tap(tester, find.byKey(const ValueKey('addItRow')));
      expect(s.screen, 'addHostel');
      expect(find.text('Add a hostel'), findsOneWidget);
      // Empty: the first missing thing is said.
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      expect(s.toast, 'Add the hostel’s name.');
      await tester.enterText(find.byKey(const ValueKey('addHName')), 'Anjani Residency');
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      expect(s.toast, 'Add a photo of the gate.');
      s.update(() => s.addDraft.photos.add(_jpg()));
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      expect(s.toast, 'Drop the pin on the gate.');
      // The pin (aPin in 'add' mode): the area is read off it.
      await _tap(tester, find.byKey(const ValueKey('addPin')));
      expect(s.screen, 'aPin');
      expect(s.pinFor, 'add');
      expect(find.text('ANJANI RESIDENCY'), findsOneWidget);
      s.pinPanned(posOf(hostelById('anjani')));
      await _tap(tester, find.byKey(const ValueKey('pinSave')));
      expect(s.screen, 'addHostel');
      expect(s.addDraft.pin, isNotNull);
      expect(s.addDraft.area, 'Madhapur');
      expect(find.text('Pin set · Madhapur'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('addRent')), '7500');
      await tester.enterText(find.byKey(const ValueKey('addOwnerName')), 'Srinivas Rao');
      await tester.enterText(find.byKey(const ValueKey('addOwnerPhone')), '9898989898');
      await tester.pump();
      // Same name within 150 m of Anjani: a duplicate, nothing is made.
      final before = hostels.length;
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(s.addDup, isNotNull);
      expect(find.byKey(const ValueKey('addDup')), findsOneWidget);
      expect(find.textContaining('Already on Hostelzy: Anjani Residency'), findsOneWidget);
      expect(hostels.length, before);
      expect(s.screen, 'addHostel');
      // Same owner phone as a sample owner: also a duplicate.
      await tester.enterText(find.byKey(const ValueKey('addHName')), 'New Nest PG');
      await tester.enterText(find.byKey(const ValueKey('addOwnerPhone')), '9000000102');
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(s.addDup?.$2, 'Sai Sri Ladies Hostel');
      // A new hostel: UNVERIFIED, rent = what they pay, S93 opens.
      await tester.enterText(find.byKey(const ValueKey('addOwnerPhone')), '9898989898');
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(s.screen, 'myAdd');
      expect(hostels.length, before + 1);
      final h = hostels.last;
      expect(h.listed, isTrue);
      expect(h.name, 'New Nest PG');
      expect((h.rentMin, h.rentMax), (7500, 7500));
      expect(h.area, 'Madhapur');
      expect(s.myAdd!.step, 1);
      expect(find.text('Your hostel on Hostelzy'), findsOneWidget);
      expect(find.byKey(const ValueKey('myAddCard')), findsOneWidget);
      expect(find.text('Unverified'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('honestLine')), findsOneWidget);
      expect(find.text('Paid only when the owner agrees and Hostelzy verifies the hostel.'), findsOneWidget);
      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('addStep-$i')), findsOneWidget);
      }
      expect(find.text('₹200 paid'), findsOneWidget);
      // Send to your owner: WhatsApp from this phone, the claim link inside; step 2 ticks.
      await _tap(tester, find.byKey(const ValueKey('sendToOwner')));
      expect(s.lastLink.toString(), startsWith('https://wa.me/919898989898?text='));
      final msg = Uri.decodeComponent(s.lastLink!.query.substring(5));
      expect(msg, 'Your PG New Nest PG is on Hostelzy. Agree to get it verified (free): https://farhath.me/hostelzy/app/r/?h=${h.id}&claim=1');
      expect(s.myAdd!.step, 2);
      await tester.pump();
      expect(find.byKey(const ValueKey('askedWait')), findsOneWidget);
      expect(find.byKey(const ValueKey('askAgain')), findsNothing);
      // Explore lists it as an UNVERIFIED card; Me says "Your hostel".
      s.tab('explore');
      await tester.pump();
      await tester.ensureVisible(find.byKey(ValueKey('listedCard-${h.id}')));
      s.tab('me');
      await tester.pump();
      expect(find.byKey(const ValueKey('me-Your hostel')), findsOneWidget);
      expect(find.textContaining('New Nest PG · owner asked'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('me-Your hostel')));
      expect(s.screen, 'myAdd');
      // The claim link opens the UNVERIFIED page with the claim sheet.
      s.openClaimLink(h.id);
      await tester.pump();
      expect(s.screen, 'detail');
      expect(s.sheet, 'claim');
      expect(find.byKey(const ValueKey('unverifiedPage')), findsOneWidget);
      s.dispose();
    });

    testWidgets('S93 variants: Ask again after 3 days, Still waiting at 60 days, queued (cap), paid; S22 row; demo seed', (tester) async {
      final s = AppState(start: 'me', role: 'tenant');
      // Demo: one hostel "added by you" at step "Owner asked".
      expect(s.myAdd!.id, 'balaji');
      expect(s.myAdd!.step, 2);
      await _pump(tester, s);
      expect(find.byKey(const ValueKey('me-Your hostel')), findsOneWidget);
      s.go('myAdd');
      await tester.pump();
      expect(find.byKey(const ValueKey('askedWait')), findsOneWidget);
      s.update(() => s.myAdd!.ownerAskedAt = DateTime.now().subtract(const Duration(days: 4)));
      await tester.pump();
      expect(find.byKey(const ValueKey('askAgain')), findsOneWidget);
      // Owner agreed: the UPI id is asked once.
      s.update(() => s.myAdd!.ownerAgreedAt = DateTime.now());
      await tester.pump();
      expect(s.myAdd!.step, 3);
      expect(find.byKey(const ValueKey('upiBox')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('adderUpi')), 'asha');
      await _tap(tester, find.byKey(const ValueKey('adderUpiSave')));
      expect(s.toast, 'Enter your UPI id, like name@upi.');
      await tester.enterText(find.byKey(const ValueKey('adderUpi')), 'asha@upi');
      await _tap(tester, find.byKey(const ValueKey('adderUpiSave')));
      await _settle(tester);
      expect(s.myAdd!.upi, 'asha@upi');
      expect(find.text('Paid by UPI to asha@upi'), findsOneWidget);
      // 60 days with no answer.
      final old = s.myAdd!;
      s.myAdd = MyAdd(id: old.id, name: old.name, gender: old.gender, area: old.area, status: 'listed', source: 'resident', rentMin: old.rentMin, rentMax: old.rentMax, createdAt: DateTime.now().subtract(const Duration(days: 61)), ownerAskedAt: DateTime.now().subtract(const Duration(days: 60)), ownerName: 'Balaji', ownerPhone: '9000000107');
      s.update(() {});
      await tester.pump();
      expect(find.byKey(const ValueKey('stillWaiting')), findsOneWidget);
      expect(find.byKey(const ValueKey('askAgain')), findsOneWidget);
      // Queued beyond this month's cap.
      final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
      s.myAdd = MyAdd(id: old.id, name: old.name, gender: old.gender, area: old.area, status: 'live', source: 'resident', rentMin: old.rentMin, rentMax: old.rentMax, createdAt: old.createdAt, ownerAskedAt: old.ownerAskedAt, ownerAgreedAt: DateTime.now(), liveAt: DateTime.now(), reward: 200, payMonth: next, ownerName: 'Balaji', ownerPhone: '9000000107');
      s.update(() {});
      await tester.pump();
      expect(s.myAdd!.step, 4);
      expect(find.byKey(const ValueKey('queued')), findsOneWidget);
      expect(find.textContaining('queued for ${monthYear(next)}'), findsNWidgets(1));
      expect(find.byKey(const ValueKey('sendToOwner')), findsNothing);
      // Paid: step 5.
      s.update(() => s.myAdd!.paidAt = DateTime.now());
      await tester.pump();
      expect(s.myAdd!.step, 5);
      expect(find.text('Paid ${dayMon(DateTime.now())} by UPI'), findsOneWidget);
      // S22 Rewards shows the row.
      s.go('rewards');
      await tester.pump();
      expect(find.byKey(const ValueKey('addReward')), findsOneWidget);
      expect(find.text('₹200 · Sri Balaji Men’s PG verified'), findsOneWidget);
      s.dispose();
    });

    testWidgets('S92 on the server: add_hostel, the gate photos, duplicates, partner code remembered', (tester) async {
      final srv = _Server();
      final s = AppState(start: 'explore', role: 'tenant');
      s.data = srv;
      s.account = (uid: 'u1', name: 'Asha', email: 'a@x.in');
      await _pump(tester, s);
      expect(s.myAdd, isNull); // nothing added on the server
      s.openAddPg();
      await tester.pump();
      s.update(() => s.addDraft
        ..name = 'Lakshmi Nivas'
        ..photos.addAll([_jpg(), _jpg()])
        ..pin = (17.44, 78.38)
        ..area = 'Madhapur'
        ..rent = '7000'
        ..ownerName = 'Lakshmi'
        ..ownerPhone = '9876501234');
      srv.dupNext = true;
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(s.addDup, ('x9', 'Sri Sai PG'));
      expect(find.byKey(const ValueKey('addDupShare')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(srv.calls.where((c) => c.startsWith('add ')).last, 'add Lakshmi Nivas 9876501234  7000');
      expect(srv.calls.where((c) => c.startsWith('photo ')).toList(), ['photo h-new Gate 0 true', 'photo h-new Gate 1 false']);
      expect(s.screen, 'myAdd');
      expect(s.myAdd!.id, 'h-new');
      expect(s.myAdd!.ownerPhone, '9876501234');
      await _tap(tester, find.byKey(const ValueKey('sendToOwner')));
      await _settle(tester);
      expect(srv.calls.last, 'asked h-new');
      // A partner: the range and the code, remembered on this phone.
      s.openAddPg();
      await tester.pump();
      s.update(() => s.addDraft
        ..name = 'Partner PG'
        ..photos.add(_jpg())
        ..pin = (17.45, 78.39)
        ..area = 'Madhapur'
        ..partner = true
        ..partnerCode = 'hz-part-3'
        ..rent = '6000'
        ..rentMax = '8000'
        ..ownerName = 'Owner'
        ..ownerPhone = '9876501235');
      await _tap(tester, find.byKey(const ValueKey('addGo')));
      await _settle(tester);
      expect(srv.calls.where((c) => c.startsWith('add ')).last, 'add Partner PG 9876501235 HZ-PART-3 6000-8000');
      expect(s.partnerCodeSaved, 'HZ-PART-3');
      expect(s.snapshot()['partnerCode'], 'HZ-PART-3');
      expect(s.myAdd!.partner, isTrue);
      expect(find.textContaining('Paid ₹20 after the Hostelzy team checks'), findsOneWidget);
      s.dispose();
    });
  });

  group('F29 Part 2 · Ask to join', () {
    testWidgets('H48: Manage › Residents › Ask to join → a free bed, prefilled fee and advance, WhatsApp link', (tester) async {
      final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
      await _pump(tester, s);
      expect(find.byKey(const ValueKey('resAdd')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('askJoin')));
      expect(s.sheet, 'askJoin');
      expect(find.text('Ask to join'), findsWidgets);
      final bed = s.joinDraft.bed!;
      final room = s.findBed('anjani', bed).r!;
      expect(s.joinDraft.fee, '${room.rent}');
      expect(s.joinDraft.adv, '3000');
      expect(find.byKey(ValueKey('joinBed-$bed')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('joinDay-3')));
      await tester.enterText(find.byKey(const ValueKey('joinName')), 'Ravi');
      await _tap(tester, find.byKey(const ValueKey('askJoinSend')));
      await _settle(tester);
      expect(s.sheet, isNull);
      expect(s.lastJoinToken, startsWith('DEMO-'));
      expect(s.lastLink.toString(), startsWith('https://wa.me/?text='));
      final msg = Uri.decodeComponent(s.lastLink!.query.substring(5));
      expect(msg, 'Hi Ravi! Join Anjani Residency on Hostelzy for bed $bed. Fill your details here (2 min): https://farhath.me/hostelzy/app/j/?t=${s.lastJoinToken}');
      expect(s.toast, 'Link made · bed $bed · 7 days');
      s.dispose();
    });

    testWidgets('S94: the link signs the tenant in, the form, Send ID on WhatsApp, Send to owner, done state', (tester) async {
      final g = AppState(start: 'explore', role: 'tenant', auth: 'out');
      await _pump(tester, g);
      await g.openJoinLink('DEMO-ABC123');
      await tester.pump();
      expect(g.sheet, 'signIn');
      expect(find.text('Sign in to join your hostel'), findsOneWidget);
      g.dispose();

      final s = AppState(start: 'explore', role: 'tenant');
      s.myName = 'Ravi Teja';
      s.phone = '9876500011';
      await _pump(tester, s);
      await s.openJoinLink('DEMO-ABC123');
      await tester.pump();
      expect(s.screen, 'joinForm');
      final i = s.joinInfo!;
      expect(find.text('Join Anjani Residency'), findsOneWidget);
      expect(find.text('Bed ${i.bed} · ${fmt(i.fee)}/month'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('sendIdWa')), findsOneWidget);
      expect(find.byKey(const ValueKey('idSentTick')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('sendIdWa')));
      expect(s.lastLink.toString(), 'https://wa.me/919000000101?text=${Uri.encodeComponent('Here is my ID for bed ${i.bed}')}');
      expect(s.jId, 'whatsapp');
      expect(find.byKey(const ValueKey('idSentTick')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('joinSend')));
      await _settle(tester);
      expect(s.jSent, isTrue);
      expect(find.byKey(const ValueKey('joinDone')), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Srinivas will approve · we’ll notify you'), findsOneWidget);
      // The owner's side now has it.
      expect(s.joinReqs.any((r) => r.name == 'Ravi Teja' && r.bed == i.bed && r.idReceived == 'whatsapp'), isTrue);
      s.dispose();
    });

    testWidgets('Today › Joining tab (only when non-empty) → H49: tick ID received, Approve = a resident like Add a resident', (tester) async {
      final s = AppState(start: 'oToday', role: 'owner');
      await _pump(tester, s);
      // The demo request: Ravi Teja on a free bed.
      final j = s.joinReqs.single;
      expect(j.name, 'Ravi Teja');
      await tester.ensureVisible(find.byKey(const ValueKey('needTab-joining')));
      expect(find.text('Joining'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('needTab-joining')));
      expect(find.text('Ravi wants to join'), findsOneWidget);
      expect(find.textContaining('Bed ${j.bed} · moves in ${dayMon(j.date)} · ID sent on WhatsApp'), findsOneWidget);
      await _tap(tester, find.byKey(ValueKey('join-${j.id}-btn0')));
      expect(s.sheet, 'joinReview');
      expect(find.text('Ravi wants to join'), findsNWidgets(2));
      expect(find.text('Bed ${j.bed} · moves in ${dayMon(j.date)}'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const ValueKey('idTick')), findsOneWidget);
      // Approve needs the tick.
      await _tap(tester, find.byKey(const ValueKey('joinApprove')));
      await _settle(tester);
      expect(s.toast, 'Tick “ID received” first.');
      expect(s.sheet, 'joinReview');
      await _tap(tester, find.byKey(const ValueKey('idTick')));
      expect(s.idTick, isTrue);
      // (The toast still covers the button for 2.6 s, so the action is called.)
      await s.approveJoin();
      await _settle(tester);
      expect(s.sheet, isNull);
      final r = s.residents.firstWhere((x) => x.name == 'Ravi Teja');
      expect(r.bed, j.bed);
      expect(r.amt, j.fee);
      expect(r.advance, j.advance);
      expect(r.confirmed, isTrue);
      expect(s.findBed('anjani', j.bed).b!.state, 'booked');
      expect(s.joinReqs, isEmpty);
      await tester.pump();
      expect(find.byKey(const ValueKey('needTab-joining')), findsNothing);
      expect(s.toast, 'Ravi is in · bed ${j.bed}');
      s.dispose();
    });

    testWidgets('H49 Ask again and Decline (demo); the server path calls the RPCs', (tester) async {
      final s = AppState(start: 'oToday', role: 'owner');
      await _pump(tester, s);
      final j = s.joinReqs.single;
      s.openJoinReview(j);
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('joinAskAgain')));
      await _settle(tester);
      expect(j.idReceived, 'none');
      expect(s.lastLink.toString(), startsWith('https://wa.me/919000000040?text='));
      expect(Uri.decodeComponent(s.lastLink!.query.substring(5)), 'Please re-send your ID for bed ${j.bed} at Anjani Residency.');
      expect(find.byKey(const ValueKey('idNone')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('joinApprove')));
      await _settle(tester);
      expect(s.toast, 'No ID yet. Ask again.');
      expect(find.byKey(const ValueKey('joinDecline')), findsOneWidget);
      await s.declineJoin();
      await _settle(tester);
      expect(s.joinReqs, isEmpty);
      expect(s.sheet, isNull);

      // Server: the owner's link, the tenant's form, the decision.
      final srv = _Server();
      final o = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
      o.data = srv;
      o.account = (uid: 'owner1', name: 'Srinivas', email: 's@x.in');
      await o.startLive();
      await _pump(tester, o);
      o.openAskJoin();
      await tester.pump();
      final bedId = o.joinDraft.bed!;
      final room = o.findBed('anjani', bedId).r!;
      final bi = room.beds.indexWhere((x) => x.id == bedId);
      final b0 = room.beds[bi];
      room.beds[bi] = Bed(id: b0.id, letter: b0.letter, room: b0.room, floor: b0.floor, spot: b0.spot, state: b0.state, soon: b0.soon, key: 'bed-key-1');
      await o.sendAskJoin();
      await _settle(tester);
      expect(srv.calls.single, 'join bed-key-1 ${o.findBed('anjani', bedId).r!.rent} 3000 ');
      expect(o.lastJoinToken, 'TOK4ABCDEFGH');
      expect(Uri.decodeComponent(o.lastLink!.query.substring(5)), contains('app/j/?t=TOK4ABCDEFGH'));
      // Filled requests come from the server for Today.
      srv.joins = [
        {'id': 'j1', 'hostel_id': 'anjani', 'fee': 6500, 'advance': 3000, 'moves_in': '2026-11-01', 'tenant_name': 'Kiran Kumar', 'tenant_phone': '9876500012', 'tenant_date': '2026-11-01', 'id_received': 'whatsapp', 'filled_at': DateTime.now().toIso8601String(), 'token': 'TOK4ABCDEFGH', 'beds': {'letter': 'A', 'rooms': {'number': 203, 'label': null}}},
      ];
      await o.loadJoins();
      expect(o.joinReqs.single.bed, '203-A');
      o.openJoinReview(o.joinReqs.single);
      o.update(() => o.idTick = true);
      await o.approveJoin();
      expect(srv.calls.last, 'decide j1 true');
      expect(o.joinReqs, isEmpty);

      // The tenant on the server: the info and the fill.
      final t = AppState(start: 'explore', role: 'tenant');
      t.data = srv;
      t.myName = 'Kiran Kumar';
      t.phone = '9876500012';
      await _pump(tester, t);
      await t.openJoinLink('BADTOKEN');
      expect(t.toast, 'This link isn’t valid any more. Ask your owner for a new one.');
      await t.openJoinLink('TAKENBED1');
      await tester.pump();
      expect(t.screen, 'joinForm');
      expect(find.byKey(const ValueKey('joinClosed')), findsOneWidget);
      expect(find.text('This bed was just taken, ask your owner.'), findsOneWidget);
      await t.openJoinLink('TOK4ABCDEFGH');
      await tester.pump();
      expect(t.joinInfo!.bed, '203-A');
      expect(find.text('BED 203-A · ₹6,500/MONTH'), findsOneWidget);
      t.sendIdOnWhatsApp();
      await t.sendJoinForm();
      expect(srv.calls.last, 'fill TOK4ABCDEFGH Kiran Kumar 9876500012 1/11 whatsapp');
      expect(t.jSent, isTrue);
      s.dispose();
      o.dispose();
      t.dispose();
    });
  });
}
