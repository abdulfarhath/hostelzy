import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/map.dart' show mapTiles;
import 'package:hostelzy/ui/shell.dart';

// F24 item 6: reply speed and ranking from real counts; no invented rules.

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

class _Server extends SampleRepo {
  @override
  Future<Map<String, HostelSignals>> signals() async => {
    'nest42': (replyMin: 45, replyN: 5, complaints30: 2, residents: 20, photos: 8, rooms: 10, layouts: 5),
    'saisri': (replyMin: 3, replyN: 1, complaints30: 0, residents: 0, photos: 2, rooms: 4, layouts: 0),
  };
}

void main() {
  mapTiles = false;

  testWidgets('reply time is real (and hidden until there are 3 replies); ranking uses real counts', (tester) async {
    final s = AppState(start: 'detail', role: 'tenant');
    s.data = _Server();
    s.hid = 'nest42';
    await s.refreshListings();
    await _pump(tester, s);
    expect((s.replyMins('nest42'), s.replyMins('saisri')), (45, 0));
    expect(find.text('Usually replies in ~45 min'), findsOneWidget);
    final f = s.factors('nest42');
    expect(f['complaints'], closeTo(.9, .001));
    expect(f['listing'], closeTo(.75, .001));
    expect(s.factors('saisri')['reply'], .5); // no replies yet: the middle, not the top
    s.update(() => s.hid = 'saisri');
    await tester.pump();
    expect(find.text('Replies through Hostelzy'), findsOneWidget);
    expect(replyWords(150), '3 h');
    s.dispose();
  });

  test('a real hostel with no rules leaves gate and visitors for the owner', () {
    final r = blankRules(const Terms());
    expect({for (final x in r) x.k: x.v}['Gate closes'], '');
    expect({for (final x in r) x.k: x.v}['Visitors'], '');
    expect(r.firstWhere((x) => x.k == 'Notice period').v, '30 days');
  });
}
