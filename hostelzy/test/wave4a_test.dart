import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/app_config.dart' show enquiryLink;
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 4a (audit §3): the enquiry's WhatsApp message ends with its link;
// one enquiry per bed and one review per stay; the 30-day review opens after
// 30 days and can be changed; the owner replies once and can report abuse;
// "layout is wrong" flags the room for the owner.

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

Future<void> _settle([int n = 8]) async {
  for (var k = 0; k < n; k++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _hid = 'a4a00000-0000-0000-0000-000000000001';

Map<String, dynamic> _hostelRow({List<Map<String, dynamic>> reviews = const [], int disputes = 0}) => {
  'id': _hid,
  'name': 'Wave Four PG',
  'gender': 'Men',
  'area': 'Ameerpet',
  'owner_name': 'Ravi',
  'status': 'live',
  'rate_cards': [{'ac': false, 'share': 2, 'rent': 8000}],
  'rooms': [
    {
      'number': 301, 'label': null, 'floor': 3, 'share': 2, 'rent': 8000, 'ac': false, 'bath': 'Attached',
      'beds': [
        {'id': 'bed-a', 'letter': 'A', 'spot': '', 'state': 'booked'},
        {'id': 'bed-b', 'letter': 'B', 'spot': '', 'state': 'free'},
      ],
    },
  ],
  'layouts': [
    {'room': 301, 'stage': 'published', 'version': 1, 'w': 12, 'h': 10, 'updated_at': '2026-09-01T10:00:00Z', 'beds': {'A': [2, 3], 'B': [8, 3]}, 'items': [], 'disputes': disputes},
  ],
  'reviews': reviews,
};

Map<String, dynamic> _review(String id, String author, {String body = 'Good food', String? reply, bool hidden = false, String? layout, String? edited}) => {
  'id': id, 'hostel_id': _hid, 'author_id': author, 'author_name': 'Teja N.', 'kind': 'stay', 'stars': 4, 'body': body, 'cats': {'Food': 4},
  'layout': layout, 'reply': reply, 'replied_at': reply == null ? null : '2026-09-30T10:00:00Z', 'created_at': '2026-09-29T10:00:00Z', 'hidden': hidden, 'edited_at': edited,
};

class _Server extends SampleRepo {
  _Server({this.joined = '2026-08-20', this.reviews = const [], this.enquiries = const []});
  String joined;
  List<Map<String, dynamic>> reviews;
  List<Map<String, dynamic>> enquiries;
  final calls = <String>[];
  String? failWith;

  Future<void> _rec(String c) async {
    if (failWith != null) throw Exception(failWith);
    calls.add(c);
  }

  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<Listings?> listings() async => listingsFromRows([_hostelRow(reviews: reviews)]);
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(
    holds: [],
    enquiries: enquiries,
    payments: [],
    complaints: [],
    me: me,
    staff: [if (me == 'fb-ravi') {'hostel_id': _hid, 'user_id': 'fb-ravi', 'role': 'owner'}],
    stays: [
      if (me == 'fb-teja')
        {'id': 'stay-1', 'hostel_id': _hid, 'user_id': me, 'name': 'Teja N', 'phone': '9876500001', 'rent': 8000, 'advance': 3000, 'confirmed': true, 'joined_on': joined, 'beds': {'letter': 'A', 'rooms': {'number': 301, 'label': null}}},
    ],
  );
  @override
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) => _rec('post $kind $stars $layout');
  @override
  Future<void> editReview(String id, {required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) => _rec('edit $id $stars $body $layout');
  @override
  Future<void> replyReview(String id, String reply) => _rec('reply $id $reply');
  @override
  Future<void> reportReview(String id, String why) => _rec('report $id $why');
  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) async {
    await _rec('enquiry $bed');
    return 'HZ-5001';
  }
}

Future<AppState> _onServer(_Server server, {String start = 'rHome', String role = 'resident', String uid = 'fb-teja'}) async {
  final s = AppState(start: start, role: role);
  s.data = server;
  s.update(() => s.account = (uid: uid, name: 'Teja', email: 't@gmail.com'));
  final l = await server.listings();
  if (l != null) s.applyListings(l);
  await s.startLive();
  return s;
}

void main() {
  mapTiles = false;

  testWidgets('F05: the WhatsApp message ends with the enquiry link the owner can open', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    await _pump(tester, s);
    s.enquire('anjani', 'Hi Srinivas, is a bed free?', bed: '204-B', from: 'Hostel page · Ask on WhatsApp');
    await tester.pump();
    final ref = s.waRef!;
    expect(s.waFull, endsWith('Booking code $ref\n${enquiryLink(ref)}'));
    expect(enquiryLink(ref), 'https://farhath.me/hostelzy/app/r/?c=$ref');
    expect(find.text(s.waFull), findsOneWidget);
    // Asking again about the same bed reuses the code (one enquiry per bed).
    s.update(() => s.sheet = null);
    final n = s.enquiries.length;
    s.enquire('anjani', 'Hi Srinivas, is a bed free?', bed: '204-B', from: 'Hostel page · Ask on WhatsApp');
    expect((s.enquiries.length, s.waRef), (n, ref));
    s.dispose();
  });

  test('F05: on the server a second enquiry for the same bed reuses the open one, said plainly', () async {
    final server = _Server(enquiries: [
      {'id': 'e1', 'hostel_id': _hid, 'tenant_id': 'fb-asha', 'ref': 'HZ-4999', 'name': 'Asha', 'phone': '', 'bed': '301-B', 'source': '', 'msg': '', 'contacted': false, 'created_at': '2026-10-01T09:00:00Z'},
    ]);
    final s = await _onServer(server, start: 'explore', role: 'tenant', uid: 'fb-asha');
    // the phone's list said nothing (e.g. it was cleared); the server refuses a duplicate
    s.update(() => s.enquiries = []);
    server.failWith = 'duplicate key value violates unique constraint "enquiries_one_open" (23505)';
    await s.enquireLive(_hid, 'Hi Ravi, is 301-B free?', bed: '301-B', from: 'Hostel page');
    expect((s.sheet, s.waRef), ('wa', 'HZ-4999'));
    expect(s.toast, 'You already asked about this bed, so it’s the same booking code: HZ-4999.');
    expect(s.waFull, endsWith(enquiryLink('HZ-4999')));
    s.stopLive();
    s.dispose();
  });

  test('F08: rows drop hidden reviews and read edits and layout flags', () {
    final l = listingsFromRows([_hostelRow(reviews: [_review('r1', 'fb-teja', edited: '2026-09-30T10:00:00Z'), _review('r2', 'fb-x', hidden: true)], disputes: 2)]);
    expect(l.reviews[_hid]!.map((r) => r.id), ['r1']);
    expect((l.reviews[_hid]!.single.edited, l.reviews[_hid]!.single.author), (true, 'fb-teja'));
    expect(l.layouts[_hid]![301]!.disputes, 2);
  });

  testWidgets('F08: the 30-day review opens after 30 days of the stay (server)', (tester) async {
    final server = _Server(joined: '2026-09-21');
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'rStay'));
    await _pump(tester, s);
    expect(s.reviewOpensOn, DateTime(2026, 10, 21));
    expect(find.text('Opens 21 Oct · after 30 days'), findsOneWidget);
    await _tap(tester, find.text('Review your stay'));
    expect(s.screen, 'rStay');
    expect(s.toast, 'Reviews open after 30 days of your stay, on 21 Oct.');
    // the server says the same if the phone's clock is off
    s.update(() => s.rvStars = 4);
    server.failWith = 'reviews open after 30 days of your stay, on 21 Oct';
    s.postReview();
    await tester.runAsync(_settle);
    expect(s.toast, 'Reviews open after 30 days of your stay.');
    s.stopLive();
    s.dispose();
  });

  testWidgets('F08: the resident changes their own review on the server', (tester) async {
    final server = _Server(reviews: [_review('r1', 'fb-teja', layout: 'Yes'), _review('r2', 'fb-other', body: 'Fine')]);
    late AppState s;
    await tester.runAsync(() async => s = await _onServer(server, start: 'rStay'));
    await _pump(tester, s);
    expect(s.reviewOpensOn, isNull);
    expect(s.myReview('30-day')?.id, 'r1');
    expect(find.text('Change your 30-day review'), findsOneWidget);
    await _tap(tester, find.text('Review your stay'));
    expect(s.screen, 'rReview');
    expect((s.rvStars, s.rvText, s.rvLayout), (4, 'Good food', 'Yes'));
    expect(find.text('Save changes'), findsOneWidget);
    s.update(() {
      s.rvText = 'Beds are not where the map says';
      s.rvLayout = 'No';
    });
    await _tap(tester, find.text('Save changes'));
    await tester.runAsync(_settle);
    await tester.pump();
    expect(server.calls, contains('edit r1 4 Beds are not where the map says No'));
    expect(server.calls.where((c) => c.startsWith('post')), isEmpty);
    expect(s.toast, 'Review updated. It shows as edited.');
    // a second post from another phone: the server's rule, in plain words
    server.failWith = 'you already reviewed this stay';
    server.reviews = [];
    await tester.runAsync(() => s.refreshListings());
    s.update(() => s.rvStars = 5);
    s.postReview();
    await tester.runAsync(_settle);
    expect(s.toast, 'You already reviewed this stay. Open your review to change it.');
    s.stopLive();
    s.dispose();
  });

  testWidgets('F08 sample: post, change it (one per stay); "layout is wrong" flags the room for the owner', (tester) async {
    final s = AppState(start: 'rHome', role: 'resident');
    await _pump(tester, s);
    final l = s.layoutOf('anjani', 204)!;
    final before = l.disputes;
    final n = s.reviews.length;
    s.openReview();
    expect(s.screen, 'rReview');
    s.update(() {
      s.rvCats = {'Food': 4};
      s.rvStars = 4;
      s.rvLayout = 'No';
    });
    s.postReview();
    expect((s.reviews.length, l.disputes, s.myReview('30-day')?.layout), (n + 1, before + 1, 'No'));
    // the home card is gone; opening it again brings the review back to change
    s.openReview();
    expect((s.rvStars, s.rvLayout), (4, 'No'));
    s.update(() => s.rvLayout = 'Yes');
    s.postReview();
    expect((s.reviews.length, l.disputes, s.myReview('30-day')!.edited), (n + 1, before, true));
    s.openReview();
    s.update(() => s.rvLayout = 'No');
    s.postReview();
    expect(l.disputes, before + 1);
    // the owner sees it on the room
    s.jump('oLayouts', 'owner');
    await tester.pump();
    expect(find.text('Residents say this layout is wrong'), findsWidgets);
    s.update(() {
      s.lRoom = 204;
      s.screen = 'oLayout';
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('layoutDisputed')), findsOneWidget);
    s.dispose();
  });

  testWidgets('F08: the owner replies once and reports abuse to the team', (tester) async {
    final s = AppState(start: 'oRank', role: 'owner');
    await _pump(tester, s);
    final r = s.reviews.firstWhere((x) => x.hid == s.ownHid && x.reply == null);
    s.update(() {
      s.replyFor = r.id;
      s.replyText = 'Thanks, fixed';
    });
    s.postReply(r);
    expect(r.reply, 'Thanks, fixed');
    s.update(() {
      s.replyFor = r.id;
      s.replyText = 'Again';
    });
    s.postReply(r);
    expect((r.reply, s.toast), ('Thanks, fixed', 'You already replied to this review. Each review gets one reply.'));
    s.update(() => s.replyFor = null);
    await tester.pump();
    await _tap(tester, find.byKey(ValueKey('report-${r.id}')));
    expect(s.sheet, 'revReport');
    expect(find.text('Report this review'), findsOneWidget);
    await _tap(tester, find.text('Send to Hostelzy'));
    expect(s.toast, 'Pick what is wrong with it.');
    await _tap(tester, find.text('Abusive or rude words'));
    await _tap(tester, find.text('Send to Hostelzy'));
    expect(s.sheet, isNull);
    expect(s.toast, 'Sent to the Hostelzy team. They hide it if it breaks the rules.');
    await tester.pump();
    expect(find.text('Reported to Hostelzy'), findsOneWidget);
    s.dispose();
  });

  test('F08: on the server the report goes to the team; a second reply is refused plainly', () async {
    final server = _Server(reviews: [_review('r1', 'fb-teja', reply: 'Thanks')]);
    final s = await _onServer(server, start: 'oRank', role: 'owner', uid: 'fb-ravi');
    final r = s.reviews.firstWhere((x) => x.id == 'r1');
    s.openReviewReport(r);
    s.update(() => s.revReportWhy = reviewReportReasons[1]);
    await s.sendReviewReport();
    expect(server.calls.last, 'report r1 ${reviewReportReasons[1]}');
    expect(s.reportedReviews, contains('r1'));
    // the reply rule on the server (another phone replied first)
    final r2 = Review(id: 'r9', hid: _hid, name: 'X', stars: 3, text: '', stay: '');
    server.failWith = 'you already replied to this review';
    s.update(() => s.replyText = 'Late reply');
    s.postReply(r2);
    await _settle();
    expect(s.toast, 'You already replied to this review. Each review gets one reply.');
    s.stopLive();
    s.dispose();
  });
}
