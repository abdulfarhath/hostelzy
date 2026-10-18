import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/owner/owner_rent_screen.dart' show rentReminder, rentThanks, rentWhatsApp;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F29 Part 1 (wave 1): Call · WhatsApp on every Rent row (S38, the text by
// status); Call · WhatsApp · Notify on every resident row (S40), Notify off
// for a resident who is not on the app.

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

/// One owner (Sai Sri) with two residents: Kiran (no account) and Ravi (on
/// the app, August rent paid).
class _Server extends SampleRepo {
  final calls = <String>[];
  bool ready = true;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(
    holds: [],
    enquiries: [],
    complaints: [],
    me: me,
    payments: [
      {'id': 'p1', 'hostel_id': 'saisri', 'kind': 'rent', 'amount': 9000, 'stay_id': 'stay-2', 'status': 'paid', 'created_at': '2026-08-03T10:00:00Z', 'confirmed_at': '2026-08-04T10:00:00Z'},
    ],
    staff: [{'hostel_id': 'saisri', 'user_id': me, 'role': 'owner'}],
    stays: [
      {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': null, 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
      {'id': 'stay-2', 'hostel_id': 'saisri', 'user_id': 'fb-ravi', 'name': 'Ravi Teja', 'phone': '9876500002', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'B', 'rooms': {'number': 101, 'label': null}}},
    ],
  );
  @override
  Future<void> notifyResident(String stayKey, String note) async {
    if (!ready) throw UnsupportedError('not on the server yet');
    calls.add('$stayKey|$note');
  }
}

void main() {
  mapTiles = false;

  testWidgets('F29 Part 1 (S38): Call · WhatsApp on every Rent row; paid rows send a thanks with the month, the rest the reminder', (tester) async {
    final s = AppState(start: 'oRent', role: 'owner');
    await _pump(tester, s);
    final paid = s.residents.firstWhere((r) => r.status == 'Paid');
    final due = s.residents.firstWhere((r) => r.status == 'Due');
    final late = s.residents.firstWhere((r) => r.status == 'Overdue');
    for (final r in [paid, due, late]) {
      expect(find.byKey(ValueKey('rentCall-${r.bed}')), findsOneWidget, reason: r.name);
      expect(find.byKey(ValueKey('rentWa-${r.bed}')), findsOneWidget, reason: r.name);
    }
    expect((paid.name, paid.paidOn), ('Arjun Reddy', DateTime(2026, 9, 29)));
    expect(rentThanks(s, paid), 'Hi Arjun, thanks, September rent received. – Anjani Residency');
    expect(rentWhatsApp(s, paid), rentThanks(s, paid));
    expect(rentWhatsApp(s, due), rentReminder(s, due));
    expect(rentWhatsApp(s, late), rentReminder(s, late));
    await _tap(tester, find.byKey(ValueKey('rentWa-${paid.bed}')));
    expect(s.lastLink.toString(), 'https://wa.me/91${paid.phone}?text=${Uri.encodeComponent(rentThanks(s, paid))}');
    await _tap(tester, find.byKey(ValueKey('rentCall-${paid.bed}')));
    expect(s.lastLink.toString(), 'tel:+91${paid.phone}');
    await _tap(tester, find.byKey(ValueKey('rentWa-${late.bed}')));
    expect(s.lastLink.toString(), 'https://wa.me/91${late.phone}?text=${Uri.encodeComponent(rentReminder(s, late))}');
    // Under the Paid filter too.
    s.update(() => s.rentF = 'Paid');
    await tester.pump();
    expect(find.byKey(ValueKey('rentWa-${paid.bed}')), findsOneWidget);
    expect(find.byKey(ValueKey('rentWa-${due.bed}')), findsNothing);
    // The month is the payment's; nothing paid yet → this month.
    expect(rentThanks(s, Resident(name: 'Ravi Teja', bed: '1-A', amt: 1, status: 'Paid', note: 'x', paidOn: DateTime(2026, 8, 3))), 'Hi Ravi, thanks, August rent received. – Anjani Residency');
    expect(rentThanks(s, Resident(name: 'Ravi Teja', bed: '1-A', amt: 1, status: 'Paid', note: 'x')), 'Hi Ravi, thanks, October rent received. – Anjani Residency');
    s.dispose();
  });

  testWidgets('F29 Part 1 (S40): Call · WhatsApp · Notify on every resident row; Notify off with "Not on the app yet · Ask to join"; the note sheet sends', (tester) async {
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
    await _pump(tester, s);
    final onApp = s.residents.firstWhere((r) => r.name == 'Rahul Varma');
    final offApp = s.residents.firstWhere((r) => r.name == 'Arjun Reddy');
    expect((onApp.onApp, offApp.onApp), (true, false));
    for (final r in s.residents) {
      for (final k in ['resCall', 'resWa', 'resNotify']) {
        expect(find.byKey(ValueKey('$k-${r.bed}')), findsOneWidget, reason: '$k ${r.name}');
      }
      expect(find.byKey(ValueKey('resNoApp-${r.bed}')), r.onApp ? findsNothing : findsOneWidget, reason: r.name);
    }
    expect(find.text('Not on the app yet · Ask to join'), findsNWidgets(s.residents.where((r) => !r.onApp).length));
    // Call.
    await _tap(tester, find.byKey(ValueKey('resCall-${onApp.bed}')));
    expect(s.lastLink.toString(), 'tel:+91${onApp.phone}');
    // WhatsApp: the H6 sheet with the greeting, as Beds › Message resident.
    await _tap(tester, find.byKey(ValueKey('resWa-${onApp.bed}')));
    expect((s.sheet, s.waMode, s.waTo, s.waPhone), ('wa', 'wa', onApp.name, onApp.phone));
    expect(find.text('Message ${onApp.name}'), findsOneWidget);
    expect(find.text('Hi, this is Srinivas from Anjani Residency.'), findsOneWidget);
    await _tap(tester, find.text('Open WhatsApp'));
    expect(s.sheet, isNull);
    expect(s.lastLink.toString(), startsWith('https://wa.me/91${onApp.phone}?text='));
    // Notify is off for a resident without the app: nothing opens.
    await _tap(tester, find.byKey(ValueKey('resNotify-${offApp.bed}')));
    expect(s.sheet, isNull);
    // Notify: the same sheet in its Notify form; Send needs a note.
    await _tap(tester, find.byKey(ValueKey('resNotify-${onApp.bed}')));
    expect((s.sheet, s.waMode, s.noteTo?.name), ('wa', 'notify', onApp.name));
    expect(find.text('Notify ${onApp.name}'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifyForm')), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('noteSend')));
    expect((s.sheet, s.toast), ('wa', 'Type the note first.'));
    await tester.pump(const Duration(seconds: 3));
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('noteField')), matching: find.byType(TextField)), 'Water tank cleaning tomorrow 10 am');
    await tester.pump();
    expect(s.noteDraft, 'Water tank cleaning tomorrow 10 am');
    await _tap(tester, find.byKey(const ValueKey('noteSend')));
    expect((s.sheet, s.toast, s.noteDraft, s.noteTo), (null, 'Sent to Rahul.', '', null));
    await tester.pump(const Duration(seconds: 3));
    // A later WhatsApp is the plain sheet again.
    await _tap(tester, find.byKey(ValueKey('resWa-${onApp.bed}')));
    expect((s.sheet, s.waMode), ('wa', 'wa'));
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifyForm')), findsNothing);
    s.dispose();
  });

  test('F29 Part 1: on the server: the stay’s account says who is on the app, the paid month, Notify sends the note or says it is not available yet', () async {
    final server = _Server();
    final s = AppState(start: 'oMore', role: 'owner', moreTab: 'residents');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Padmavathi', email: 'p@gmail.com'));
    await s.startLive();
    final kiran = s.residents.firstWhere((r) => r.name == 'Kiran Rao');
    final ravi = s.residents.firstWhere((r) => r.name == 'Ravi Teja');
    expect((kiran.onApp, kiran.uid, ravi.onApp, ravi.uid), (false, null, true, 'fb-ravi'));
    expect((kiran.paidOn, ravi.paidOn), (null, DateTime.parse('2026-08-04T10:00:00Z').toLocal()));
    expect(rentThanks(s, ravi), startsWith('Hi Ravi, thanks, August rent received. – '));
    s.openNotify(kiran);
    expect(s.sheet, isNull);
    s.openNotify(ravi);
    expect((s.sheet, s.waMode, s.noteTo?.key), ('wa', 'notify', 'stay-2'));
    s.update(() => s.noteDraft = ' Gas bill today ');
    await s.sendNote();
    expect(server.calls, ['stay-2|Gas bill today']);
    expect((s.sheet, s.toast, s.noteDraft), (null, 'Sent to Ravi.', ''));
    // Until the server has `notify_resident`: honest, nothing sent, the sheet stays.
    server.ready = false;
    s.openNotify(ravi);
    s.update(() => s.noteDraft = 'Gate closes at 10');
    await s.sendNote();
    expect((s.sheet, s.toast, server.calls.length), ('wa', 'Not available yet. Use WhatsApp.', 1));
    s.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('F29 Part 1: Rent and Residents fit 360 px at 2× text (${dark ? 'dark' : 'light'})', (tester) async {
      for (final (start, tab) in const [('oRent', 'home'), ('oMore', 'residents')]) {
        final s = AppState(start: start, role: 'owner', moreTab: tab);
        s.update(() => s.theme = dark ? 'dark' : 'light');
        await _pump(tester, s, scale: 2, width: 360);
        expect(tester.takeException(), isNull, reason: start);
        s.dispose();
      }
    });
  }
}
