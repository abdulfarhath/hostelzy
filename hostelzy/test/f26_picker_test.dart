import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

// F26 #8 (pick a bed: every room's drawn layout, floor chips jump), #12
// ("Edit this layout" → try mode → Publish → only residents can send a fix)
// and "Layouts open to all" (no women's-PG lock).

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

void main() {
  mapTiles = false;

  testWidgets('F26 #12: Edit this layout on a picker room → try mode → Publish → residents only; Keep trying, then Pick a bed', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.hid = 'anjani';
    s.openPicker();
    await _pump(tester, s);
    final r = s.rooms['anjani']!.firstWhere((r) => s.liveLayout('anjani', r.n) != null);
    await _tap(tester, find.byKey(ValueKey('editLayout-${r.n}')));
    expect((s.screen, s.fixTry, s.fixRoom), ('rFix', true, r.n));
    expect(find.text('Try mode · only on this phone'), findsOneWidget);
    expect(find.text('Move things to see how the room works for you'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('tryPublish')));
    expect(s.sheet, 'fixLock');
    expect(find.text('Only residents can send a fix'), findsOneWidget);
    expect(find.text('Book a bed to join. Your tries stay on this phone.'), findsOneWidget);
    // Keep trying: back in the editor, still trying.
    await _tap(tester, find.text('Keep trying'));
    expect((s.sheet, s.screen, s.fixTry), (null, 'rFix', true));
    // Pick a bed: leaves the try and goes back to every room.
    await _tap(tester, find.byKey(const ValueKey('tryPublish')));
    await _tap(tester, find.byKey(const ValueKey('fixLockPick')));
    expect((s.sheet, s.screen, s.mode, s.fixTry), (null, 'picker', 'plan', false));
    s.dispose();
  });

  testWidgets('F26 #12: the room on its own has the red Edit this layout button', (tester) async {
    final s = AppState(start: 'picker', role: 'tenant', mode: 'room');
    await _pump(tester, s);
    final btn = find.byKey(const ValueKey('editLayout'));
    expect(btn, findsOneWidget);
    expect(find.text('Edit room'), findsNothing);
    await _tap(tester, btn);
    expect((s.screen, s.fixTry), ('rFix', true));
    s.dispose();
  });

  testWidgets('F26 #8: a room without a layout shows its beds as boxes; a free one picks', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.hid = 'greenview';
    s.openPicker();
    await _pump(tester, s);
    final r = s.rooms['greenview']!.firstWhere((r) => s.liveLayout('greenview', r.n) == null && r.beds.any((b) => b.state == 'free' && !b.mine));
    expect(find.byKey(ValueKey('editLayout-${r.n}')), findsNothing);
    final b = r.beds.firstWhere((b) => b.state == 'free' && !b.mine);
    await _tap(tester, find.byKey(ValueKey('bed-${b.id}')));
    expect(s.bed, b.id);
    s.dispose();
  });

  testWidgets('F26: a women\'s PG\'s layouts open without a hold', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    s.hid = 'saisri';
    s.openPicker();
    await _pump(tester, s);
    expect(s.heldAt('saisri'), isFalse);
    expect(find.textContaining('after you hold'), findsNothing);
    expect(find.byKey(const ValueKey('editLayout')), findsNothing);
    final drawn = s.rooms['saisri']!.where((r) => s.liveLayout('saisri', r.n) != null);
    for (final r in drawn) {
      expect(find.byKey(ValueKey('editLayout-${r.n}')), findsOneWidget);
    }
    s.dispose();
  });

  testWidgets('F26 #8: the picker fits at 2× text on a 360-px phone, light and dark, both views', (tester) async {
    for (final dark in [false, true]) {
      for (final mode in ['plan', 'room']) {
        final t = AppState(start: 'explore', role: 'tenant');
        t.hid = 'anjani';
        t.openPicker();
        t.theme = dark ? 'dark' : 'light';
        t.mode = mode;
        await _pump(tester, t, scale: 2, width: 360);
        expect(tester.takeException(), isNull);
        t.dispose();
      }
    }
  });
}
