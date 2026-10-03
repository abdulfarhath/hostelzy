// Real app screenshots for Design (390x844 and @3x), with real fonts and sample data.
// Not part of the app's tests. To run: copy into hostelzy/test/, then
//   flutter test test/capture_design_test.dart
// It writes PNGs into ../docs/design/screens/. Delete the copy after. Add entries to _shots
// (any AppState start/role/theme/sheet) to capture other screens.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/shell.dart';

const _out = '../docs/design/screens';
final _shots = <String, AppState Function()>{
  'map-light': () => AppState(start: 'map', role: 'tenant', theme: 'light'),
  'map-dark': () => AppState(start: 'map', role: 'tenant', theme: 'dark'),
  'map-use-my-location-light': () => AppState(start: 'map', role: 'tenant', theme: 'light', sheet: 'loc'),
  'map-use-my-location-dark': () => AppState(start: 'map', role: 'tenant', theme: 'dark', sheet: 'loc'),
  'map-area-picker-light': () => AppState(start: 'where', role: 'tenant', theme: 'light'),
  'map-area-picker-dark': () => AppState(start: 'where', role: 'tenant', theme: 'dark'),
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
        for (final (scale, suffix) in const [(1.0, ''), (3.0, '@3x')]) {
          final img = await rb.toImage(pixelRatio: scale);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          Directory(_out).createSync(recursive: true);
          File('$_out/${e.key}$suffix.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      });
      s.dispose();
    });
  }
}
