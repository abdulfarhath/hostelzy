import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/live.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/l10n.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F21 Wave 4, everywhere: languages (checked strings only), accessibility
// (button semantics, 48×48 taps, no tiny text, 2× text), loading skeleton,
// "You're offline", inline errors with Retry, Undo, and one place for
// Log out and the theme.

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final l = FontLoader('Archivo');
  for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
    final b = File('assets/fonts/$f').readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
});

Future<void> _pump(WidgetTester tester, AppState state, {double scale = 1}) async {
  await _fonts(tester);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final shell = AppScope(state: state, child: const HostelzyShell(bare: true));
  await tester.pumpWidget(MaterialApp(home: scale == 1 ? shell : MediaQuery(data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)), child: shell)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// The server, whose live rows fail until [ok].
class _Flaky extends SampleRepo {
  bool ok = false;
  // ignore: close_sinks
  final ctrl = StreamController<String>.broadcast();
  @override
  bool get remote => true;
  @override
  Stream<String> changes() => ctrl.stream;
  @override
  Future<LiveRows?> live({String? me}) async {
    if (!ok) throw const SocketException('offline');
    return liveFromRows(holds: [], enquiries: [], payments: [], complaints: [], me: me);
  }
}

void main() {
  mapTiles = false;

  testWidgets('F21 W4: Release hold and Remove saved can be undone for 5 seconds', (tester) async {
    final s = AppState(start: 'hold', role: 'tenant');
    s.hist = ['holds'];
    await _pump(tester, s);
    final h = s.holds.single;
    await _tap(tester, find.text('Release this hold'));
    expect((s.screen, s.toast, s.releasing.contains(h.id)), ('holds', 'Hold on bed ${h.bed} released', true));
    await _tap(tester, find.byKey(const ValueKey('undo')));
    expect((s.toast, s.releasing.contains(h.id), s.holds.firstWhere((x) => x.id == h.id).status), (null, false, h.status));
    // Without Undo it really goes after 5 seconds.
    s.releaseWithUndo(h);
    await tester.pump(const Duration(seconds: 6));
    expect((s.holds.firstWhere((x) => x.id == h.id).status, s.releasing.isEmpty, s.toast), ('released', true, null));

    s.tab('explore');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('save-anjani')));
    expect((s.saved['anjani'], s.toast), (true, 'Saved on this phone.'));
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, find.byKey(const ValueKey('save-anjani')));
    expect((s.saved['anjani'], s.toast), (false, 'Removed Anjani Residency'));
    await _tap(tester, find.byKey(const ValueKey('undo')));
    expect(s.saved['anjani'], isTrue);
    s.dispose();
  });

  testWidgets('F21 W4: grey cards while loading, "You’re offline" (never "No hostels"), Retry', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.listState = 'loading';
    await _pump(tester, s);
    expect(find.bySemanticsLabel('Loading'), findsNWidgets(2));
    expect(find.text('Anjani Residency'), findsNothing);
    expect(find.text('HYDERABAD'), findsOneWidget);
    s.update(() => s.listState = 'offline');
    await tester.pump();
    expect(find.text('You’re offline'), findsOneWidget);
    expect(find.textContaining('No hostels'), findsNothing);
    var tried = 0;
    s.reconnect = () async {
      tried++;
      s.update(() => s.listState = 'ready');
    };
    await _tap(tester, find.byKey(const ValueKey('retry')));
    expect((tried, s.listState), (1, 'ready'));
    expect(find.text('Anjani Residency'), findsOneWidget);
    s.dispose();
  });

  testWidgets('F21 W4: holds that fail to load say so inline, with Retry', (tester) async {
    final s = AppState(start: 'holds', role: 'tenant');
    final server = _Flaky();
    s.data = server;
    s.update(() => s.account = (uid: 'fb-asha', name: 'Asha K', email: 'a@gmail.com'));
    await s.startLive();
    await _pump(tester, s);
    expect(s.liveFailed, isTrue);
    expect(find.text('Couldn’t load your holds'), findsOneWidget);
    server.ok = true;
    await _tap(tester, find.byKey(const ValueKey('inlineRetry')));
    await tester.pump();
    expect(find.text('Couldn’t load your holds'), findsNothing);
    s.stopLive();
    s.dispose();
  });

  testWidgets('F21 W4: buttons are buttons, small ones take a 48×48 tap, no tiny text', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    await _pump(tester, s);
    final sem = tester.ensureSemantics();
    expect(tester.getSemantics(find.descendant(of: find.byKey(const ValueKey('filtersBtn')), matching: find.byType(Semantics)).first), isSemantics(isButton: true, hasTapAction: true));
    // A 36×36 close button: a tap just outside it still closes the sheet.
    s.update(() => s.sheet = 'search');
    await tester.pump();
    final r = tester.getRect(find.byKey(const ValueKey('sheetClose')));
    expect(r.width, lessThan(48));
    await tester.tapAt(Offset(r.left - 4, r.center.dy));
    await tester.pump();
    expect(s.sheet, isNull);
    // No info text under 12px (small capital labels stay at 11).
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final size = t.style?.fontSize;
      if (size == null || t.style?.fontFamily == 'JetBrains Mono') continue;
      expect(size, greaterThanOrEqualTo(11), reason: t.data);
    }
    sem.dispose();
    s.dispose();
  });

  for (final c in const [('explore', 'tenant'), ('detail', 'tenant'), ('holds', 'tenant'), ('rHome', 'resident'), ('rStay', 'resident'), ('savedHolds', 'resident'), ('rPay', 'resident'), ('oToday', 'owner'), ('oMore', 'owner'), ('oRent', 'owner'), ('oBeds', 'owner'), ('welcome', 'tenant'), ('settings', 'tenant')]) {
    testWidgets('F21 W4: ${c.$1} fits at 2× text', (tester) async {
      final s = AppState(start: c.$1, role: c.$2);
      await _pump(tester, s, scale: 2);
      expect(tester.takeException(), isNull);
      s.dispose();
    });
  }

  testWidgets('F21 W4: languages: checked strings only, "beta" until reviewed, English for the rest', (tester) async {
    // The bundled files parse; strings that are empty never count.
    final te = LangPack.fromArb('te', 'తెలుగు', File('assets/l10n/app_te.arb').readAsStringSync());
    expect((te.code, te.label), ('te', te.reviewed ? 'తెలుగు' : 'తెలుగు (beta)'));
    expect(LangPack.fromArb('te', 'తెలుగు', '{"@@reviewed": false, "Help": "", "Pay rent": "x"}').strings, {'Pay rent': 'x'});
    // With no checked strings, there's no picker: Settings says so honestly.
    final s = AppState(start: 'settings', role: 'resident');
    await _pump(tester, s);
    expect(s.langChoices, [('en', 'English')]);
    await _tap(tester, find.text('Language'));
    expect((s.sheet, s.toast), (null, 'Telugu and Hindi come once a native speaker has checked the words.'));
    await tester.pump(const Duration(seconds: 3));
    // A pack with strings (a test stand-in, not real Telugu): the picker shows it as beta.
    s.update(() => s.langs = {'te': const LangPack('te', 'తెలుగు', {'Help': 'TE:Help'})});
    await _tap(tester, find.text('Language'));
    expect(s.sheet, 'lang');
    expect(find.text('తెలుగు (beta)'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('lang-te')));
    expect((s.lang, s.snapshot()['lang']), ('te', 'te'));
    // F26 #14: Help lives in My stay.
    s.tab('rStay');
    await tester.pump();
    expect(find.text('TE:Help'.toUpperCase()), findsOneWidget); // the Help kicker
    s.update(() => s.sheet = 'complaint');
    await tester.pump();
    expect(find.text('Send to owner'), findsOneWidget); // not translated yet: English
    s.dispose();
  });

  testWidgets('F21 W4 + F26 #11: Log out in red on Me (and in Settings); the theme in Settings only', (tester) async {
    final s = AppState(start: 'me', role: 'owner');
    await _pump(tester, s);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsNothing);
    await _tap(tester, find.text('Settings'));
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(hostelById(s.ownHid).name, isNotEmpty);
    s.dispose();
  });
}
