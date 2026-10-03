import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/locate.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F24 Wave 4c: the owner's WhatsApp number, the resident's number on the bed
// sheet, the wizard's real pin / house rules / amenities, and meal times on
// the menu that residents' reminders use.

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

Future<void> _settle(WidgetTester tester) async {
  for (var k = 0; k < 6; k++) {
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

class _Locator implements Locator {
  _Locator(this.pos);
  final (double, double)? pos;
  bool exactAsked = false;
  @override
  Future<((double, double)?, LocateFail?)> locate({bool exact = false}) async {
    exactAsked = exact;
    return (pos, pos == null ? LocateFail.denied : null);
  }
}

class _Server extends SampleRepo {
  final calls = <String>[];
  Map<String, (int, int)> times = {};
  bool timesMissing = false;
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<LiveRows?> live({String? me}) async => liveFromRows(holds: [], enquiries: [], complaints: [], me: me, payments: [], stays: [
    {'id': 'stay-1', 'hostel_id': 'saisri', 'user_id': 'fb-kiran', 'name': 'Kiran Rao', 'phone': '9876500001', 'rent': 9000, 'advance': 5000, 'confirmed': true, 'left_on': null, 'joined_on': '2026-09-05', 'beds': {'letter': 'A', 'rooms': {'number': 101, 'label': null}}},
  ]);
  @override
  Future<Map<String, ({String phone, String wa})>> ownerContacts(List<String> hids) async => {
    for (final h in hids) if (h == 'saisri') h: (phone: '9876543210', wa: '9123412345'),
  };
  @override
  Future<List<DayMenu>?> menu(String hid) async => null;
  @override
  Future<void> saveMenu(String hid, List<DayMenu> week) async => calls.add('menu $hid');
  @override
  Future<Map<String, (int, int)>> mealTimes(String hid) async => times;
  @override
  Future<void> saveMealTimes(String hid, Map<String, String> t) async {
    if (timesMissing) throw Exception('column "breakfast_time" does not exist');
    calls.add('times $hid ${t['b']} ${t['l']} ${t['n']}');
  }
}

void main() {
  mapTiles = false;
  final saved = Map.of(ownerPhones);
  setUp(() {
    ownerPhones.clear();
    ownerWhatsApps.clear();
  });
  tearDown(() {
    ownerPhones
      ..clear()
      ..addAll(saved);
    ownerWhatsApps.clear();
  });

  testWidgets('residents message the owner on their WhatsApp number; calls keep the phone', (tester) async {
    final server = _Server();
    final s = AppState(start: 'rHome', role: 'resident');
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
      s.myName = 'Kiran Rao';
    });
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    expect((ownerPhones['saisri'], ownerWhatsApps['saisri']), ('9876543210', '9123412345'));
    expect(ownerWa('saisri'), '9123412345');
    await tester.tap(find.text('Message owner'));
    await tester.pump();
    expect((s.sheet, s.waPhone), ('wa', '9123412345'));
    // No WhatsApp number: the phone.
    ownerWhatsApps.clear();
    expect(ownerWa('saisri'), '9876543210');
    s.dispose();
  });

  testWidgets('the owner’s bed sheet messages the resident on their own number', (tester) async {
    final s = AppState(start: 'oBeds', role: 'owner');
    await _pump(tester, s);
    final res = s.residents.firstWhere((r) => r.phone.isNotEmpty && s.findBed(s.ownHid, r.bed).b?.state == 'booked');
    s.update(() {
      s.obed = res.bed;
      s.sheet = 'bed';
    });
    await tester.pump();
    await _tap(tester, find.text('Message ${res.name.split(' ').first}'));
    expect((s.sheet, s.waTo, s.waPhone), ('wa', res.name, res.phone));
    s.dispose();
  });

  testWidgets('Settings › WhatsApp: an owner sets a different number, or goes back to the phone', (tester) async {
    final s = AppState(start: 'settings', role: 'owner');
    s.update(() => s.phone = '9000000100');
    await _pump(tester, s);
    expect(find.text('Same as phone'), findsOneWidget);
    await _tap(tester, find.text('WhatsApp'));
    expect(s.sheet, 'waNum');
    await tester.enterText(find.byKey(const ValueKey('waEdit')).last, '91234');
    await _tap(tester, find.text('Save WhatsApp number'));
    expect(s.toast, 'Enter all 10 digits.');
    await tester.pump(const Duration(seconds: 4));
    await tester.enterText(find.byKey(const ValueKey('waEdit')).last, '91234 12345');
    await _tap(tester, find.text('Save WhatsApp number'));
    expect((s.myWa, s.sheet), ('9123412345', null));
    expect(s.snapshot()['wa'], '9123412345');
    expect(find.text('+91 91234 12345'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, find.text('WhatsApp'));
    await _tap(tester, find.text('Use my phone number'));
    expect((s.myWa, s.toast), ('', 'WhatsApp uses your phone number.'));
    s.dispose();
  });

  testWidgets('tenants don’t see the WhatsApp row', (tester) async {
    final s = AppState(start: 'settings', role: 'tenant');
    await _pump(tester, s);
    expect(find.text('WhatsApp'), findsNothing);
    s.dispose();
  });

  testWidgets('the wizard drops a real pin at the gate and saves rules, amenities and the owner’s WhatsApp', (tester) async {
    final loc = _Locator((17.46221, 78.35683));
    final s = AppState(start: 'aTrack', role: 'owner');
    s.locator = loc;
    await _pump(tester, s);
    s.openAddHostel();
    await tester.pump();
    final d = s.draft;
    // No pin yet: nothing sent, and go-live waits for it.
    expect(s.draftPayload().containsKey('lat'), isFalse);
    expect(s.goLiveLeft, contains('Map pin dropped at the gate'));

    await _tap(tester, find.byKey(const ValueKey('aAddPin')));
    expect(s.screen, 'aPin');
    expect(find.byKey(const ValueKey('pinMark')), findsOneWidget);
    // The area's centre is never saved by itself.
    await _tap(tester, find.byKey(const ValueKey('pinSave')));
    expect((s.screen, d.pin, s.toast), ('aPin', null, 'Move the map so the pin sits on the gate, or use your location.'));
    await tester.pump(const Duration(seconds: 4));
    await _tap(tester, find.byKey(const ValueKey('pinLocate')));
    expect(loc.exactAsked, isTrue);
    expect(find.text('Pin at 17.46221, 78.35683'), findsOneWidget);
    // The team nudges it onto the gate.
    s.pinPanned((17.46230, 78.35690));
    await _tap(tester, find.byKey(const ValueKey('pinSave')));
    expect((s.screen, d.pin, d.pinChecked), ('aAdd', (17.46230, 78.35690), true));
    expect(find.text('Map pin · dropped at the gate'), findsOneWidget);
    expect(s.goLiveLeft, isNot(contains('Map pin dropped at the gate')));

    // Gate time and visitors are house rules; every amenity is kept.
    s.update(() {
      d.gate = '11 pm';
      d.visitors = 'Till 7 pm';
      d.ownerWa = '9123412345';
    });
    final p = s.draftPayload();
    expect((p['lat'], p['lng']), (17.46230, 78.35690));
    expect((p['rules'] as List).first, {'k': 'Gate closes', 'v': '11 pm'});
    expect((p['rules'] as List)[1], {'k': 'Visitors', 'v': 'Till 7 pm'});
    expect((p['rules'] as List).length, 8);
    expect(p['amenities'], d.amenities.toList());
    expect((p['tags'] as List).length, d.amenities.length + 1);
    expect(p['owner_whatsapp'], '9123412345');
    expect(d.ownerChat, '9123412345');
    s.dispose();
  });

  testWidgets('a real draft starts with no gate time or visitors', (tester) async {
    final d = HostelDraft.blank();
    expect((d.gate, d.visitors, d.pin), ('', '', null));
  });

  testWidgets('no location: the pin screen says to move the map', (tester) async {
    final s = AppState(start: 'aTrack', role: 'owner');
    s.locator = _Locator(null);
    await _pump(tester, s);
    s.openAddHostel();
    s.openPin();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('pinLocate')));
    expect(s.toast, 'Couldn’t find your location. Move the map instead.');
    expect(s.pinTouched, isFalse);
    s.dispose();
  });

  testWidgets('the owner sets meal times on the Food menu; they save with the menu', (tester) async {
    final server = _Server();
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _tap(tester, find.text('Food menu'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('mealTimes')), findsOneWidget);
    expect(find.textContaining('Not set. Residents’ meal reminders use the usual times'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('mealTimesSet')));
    expect(s.timesDraft['b'], (450, 570));
    await _tap(tester, find.byKey(const ValueKey('mt-b-s-')));
    await _tap(tester, find.byKey(const ValueKey('mt-b-s-')));
    await _tap(tester, find.byKey(const ValueKey('mt-n-e+')));
    expect((s.timesDraft['b'], s.timesDraft['n']), ((420, 570), (1200, 1335)));
    expect(find.text('Breakfast · 7:00 – 9:30'), findsOneWidget);
    expect(s.menuDirty, isTrue);
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    await _settle(tester);
    expect(server.calls, ['menu ${s.ownHid}', 'times ${s.ownHid} 07:00-09:30 12:30-14:00 20:00-22:15']);
    expect(s.mealTimes[s.ownHid]!['b'], (420, 570));
    expect(s.toast, 'Meal times saved. Residents’ meal reminders ring at them.');
    s.dispose();
  });

  testWidgets('before the server has meal times, the menu still saves and says so', (tester) async {
    final server = _Server()..timesMissing = true;
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = server;
    s.update(() => s.account = (uid: 'fb-owner', name: 'Srinivas', email: 's@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    await _tap(tester, find.text('Food menu'));
    await _settle(tester);
    s.startMealTimes();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('menuSave')));
    await _settle(tester);
    expect(server.calls, ['menu ${s.ownHid}']);
    expect(s.toast, 'Menu saved. Meal times save once Hostelzy updates the server; residents keep the usual times till then.');
    expect(s.mealTimes[s.ownHid], isNull);
    s.dispose();
  });

  testWidgets('residents’ meal reminders ring at the menu’s times, or the usual ones and say so', (tester) async {
    final server = _Server()..times = {'b': (8 * 60, 10 * 60), 'n': (21 * 60, 22 * 60 + 30)};
    final s = AppState(start: 'rHome', role: 'resident');
    s.data = server;
    s.update(() {
      s.account = (uid: 'fb-kiran', name: 'Kiran Rao', email: 'k@gmail.com');
      s.myName = 'Kiran Rao';
    });
    await s.startLive();
    await _pump(tester, s);
    await _settle(tester);
    await s.loadMenu('saisri');
    expect(s.remHostel, 'saisri');
    final rings = {for (final r in s.mealRings) r.$2: (r.$3, r.$4)};
    expect(rings['Breakfast'], (480, '10 am'));
    expect(rings['Lunch'], (750, '2 pm'));
    expect(rings['Dinner'], (1260, '10:30 pm'));
    expect(s.mealLine, startsWith('From the food menu · breakfast 8:00'));
    expect(s.mealTimeText('saisri', 'b'), '8:00 – 10:00');
    expect(s.mealTimeText('saisri', 'l'), '12:30 – 2:00');

    // The owner cleared them: the usual times, and the line says so.
    server.times = {};
    await s.loadMealTimes('saisri');
    expect(s.menuHasTimes, isFalse);
    expect(s.mealLine, startsWith('Usual times, the menu has none yet · lunch 12:30'));
    s.dispose();
  });

  test('meal time values round-trip', () {
    expect(parseMealTime('07:30-09:30'), (450, 570));
    expect(parseMealTime(''), isNull);
    expect(mealTimeValue((1200, 1335)), '20:00-22:15');
    expect(mealTimeValue(null), '');
    expect(mealSpan((750, 840)), '12:30 – 2:00');
  });
}
