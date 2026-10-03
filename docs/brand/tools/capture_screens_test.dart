// Play Store screenshots, taken from the real app screens with sample data (Brand chat).
// Not part of the app's tests. To run: copy into hostelzy/test/, then
//   flutter test test/capture_screens_test.dart
// It writes 1080x2338 PNGs into ../docs/brand/assets/play-store/raw/. Delete the copy after.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

const _out = '../docs/brand/assets/play-store/raw';
final _shots = <String, AppState Function()>{
  'explore': () => AppState(start: 'explore', role: 'tenant'),
  'map': () => AppState(start: 'map', role: 'tenant'),
  'detail': () => AppState(start: 'detail', role: 'tenant')..hid = 'anjani',
  'picker': () => AppState(start: 'picker', role: 'tenant')..hid = 'anjani',
  'compare': () => AppState(start: 'compare', role: 'tenant')..hid = 'anjani',
  'reviews': () => AppState(start: 'reviews', role: 'tenant')..hid = 'anjani',
  'holds': () => AppState(start: 'holds', role: 'tenant'),
  'rHome': () => AppState(start: 'rHome', role: 'resident'),
  'rRoom': () => AppState(start: 'rRoom', role: 'resident'),
  'food': () => AppState(start: 'food', role: 'resident'),
  'reminders': () => AppState(start: 'reminders', role: 'resident'),
  'rewards': () => AppState(start: 'rewards', role: 'resident'),
  'oToday': () => AppState(start: 'oToday', role: 'owner'),
  'oBeds': () => AppState(start: 'oBeds', role: 'owner'),
  'oRent': () => AppState(start: 'oRent', role: 'owner'),
  'oMore': () => AppState(start: 'oMore', role: 'owner'),
};

void main() {
  mapTiles = false;
  for (final e in _shots.entries) {
    testWidgets('capture ${e.key}', (tester) async {
      await tester.runAsync(() async {
        final l = FontLoader('Archivo');
        for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
          final b = File('assets/fonts/$f').readAsBytesSync();
          l.addFont(Future.value(ByteData.view(b.buffer)));
        }
        await l.load();
        final m = FontLoader('JetBrainsMono');
        final b = File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync();
        m.addFont(Future.value(ByteData.view(b.buffer)));
        await m.load();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = e.value();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, home: AppScope(state: s, child: const HostelzyShell(bare: true)))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        final rb = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await rb.toImage(pixelRatio: 1080 / 390);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      s.dispose();
    });
  }
}
