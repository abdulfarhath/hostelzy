import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/features/listings/cache.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/screens_tenant.dart' show HostelCard;
import 'package:hostelzy/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

// F24 items 30 and 31: the last hostels list kept for offline, and the
// staging label.

void main() {
  mapTiles = false;

  test('the hostels list is kept on the phone and read back', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadListingRows(), isNull);
    await saveListingRows([
      {'id': 'h1', 'name': 'Sri Sai PG'},
    ]);
    final c = await loadListingRows();
    expect(c!.rows.single['name'], 'Sri Sai PG');
    expect(DateTime.now().difference(c.at).inMinutes, 0);
  });

  testWidgets('offline with a kept list: Explore says so and offers to try again', (tester) async {
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
    var tries = 0;
    final s = AppState(start: 'explore', role: 'tenant');
    s.update(() {
      s.listState = 'cached';
      s.cachedAt = DateTime(2026, 10, 2, 21, 5);
      s.reconnect = () async => tries++;
    });
    await tester.pumpWidget(MaterialApp(home: AppScope(state: s, child: const HostelzyShell(bare: true))));
    await tester.pump();
    expect(find.text('Offline. Hostels as of 2 Oct, 9:05 pm. Tap to try again.'), findsOneWidget);
    // The saved hostels stay under the banner (Design w1-exploreCached).
    expect(find.byType(HostelCard), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('cachedBanner')));
    expect(tries, 1);
    s.dispose();
  });
}
