import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostelzy/data.dart';
import 'package:hostelzy/features/drive/drive_auth.dart';
import 'package:hostelzy/features/drive/id_capture.dart';
import 'package:hostelzy/features/drive/id_thumb.dart';
import 'package:hostelzy/features/explore/explore_screen.dart';
import 'package:hostelzy/features/listings/repo.dart';
import 'package:hostelzy/features/map/map_screen.dart' show mapTiles;
import 'package:hostelzy/features/photos/pick.dart';
import 'package:hostelzy/state.dart';
import 'package:hostelzy/ui/common.dart' show Cta;
import 'package:hostelzy/ui/kit.dart';
import 'package:hostelzy/ui/shell.dart';
import 'package:image/image.dart' as img;

// Wave 4: F29 Part 3 (tenant IDs in the owner's Google Drive: H50, IdCapture,
// IdThumb) and F28 Part 4 (rent shown only within 60 days of a confirmation).

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final l = FontLoader('Archivo');
  for (final f in ['Archivo-Regular.ttf', 'Archivo-Medium.ttf', 'Archivo-SemiBold.ttf', 'Archivo-ExtraBold.ttf']) {
    final b = File('assets/fonts/$f').readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
});

/// The state's 1-second ticker must stop before the test ends (pending-timer check).
final _disposed = <AppState>{};
void _end(AppState s) {
  if (_disposed.add(s)) s.dispose();
}

Future<void> _pump(WidgetTester tester, AppState state) async {
  await _fonts(tester);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AppScope(state: state, child: const HostelzyShell(bare: true))));
  await tester.pump();
}

Future<void> _pumpWidget(WidgetTester tester, AppState state, Widget w, {bool dark = false}) async {
  await _fonts(tester);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AppScope(state: state, child: PalScope(pal: dark ? Pal.dark : Pal.light, child: Scaffold(backgroundColor: dark ? Pal.dark.bg : Pal.light.bg, body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: w)))))));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

/// The H50 status line says [t] (the Manage row behind the sheet may say the same).
Finder _status(String t) => find.descendant(of: find.byKey(const ValueKey('driveStatus')), matching: find.text(t));

/// A server with Drive: what the owner connected, what tenants uploaded.
class _Server extends SampleRepo {
  _Server({this.hasDrive = true, this.connectFail, this.viewFail});
  final bool hasDrive;
  final DriveFail? connectFail, viewFail;
  DriveStatus st = (connected: false, files: 0, fullCopy: false);
  final uploads = <Uint8List>[];
  final calls = <String>[];
  @override
  bool get remote => true;
  @override
  Future<DriveStatus?> driveStatus(String hid) async {
    calls.add('status $hid');
    return hasDrive ? st : null;
  }

  @override
  Future<DriveStatus> driveConnect(String hid, String code) async {
    calls.add('connect $hid $code');
    if (connectFail != null) throw connectFail!;
    return st = (connected: true, files: 0, fullCopy: false);
  }

  @override
  Future<DriveStatus> driveDisconnect(String hid) async {
    calls.add('disconnect $hid');
    return st = (connected: false, files: 0, fullCopy: false);
  }

  @override
  Future<void> setFullCopy(String hid, bool v) async {
    calls.add('fullCopy $hid $v');
    st = (connected: true, files: st.files, fullCopy: v);
  }

  @override
  Future<({String hid, bool fullCopy})?> idTarget(String token) async {
    calls.add('target $token');
    return st.connected ? (hid: 'anjani', fullCopy: st.fullCopy) : null;
  }

  @override
  Future<String> idUpload(String token, Uint8List bytes, {String mime = 'image/jpeg'}) async {
    calls.add('upload $token $mime');
    if (connectFail != null) throw connectFail!;
    uploads.add(bytes);
    return 'file-${uploads.length}';
  }

  @override
  Future<({String url, String open})> idView(String hid, String fileId) async {
    calls.add('view $hid $fileId');
    if (viewFail != null) throw viewFail!;
    return (url: 'https://x.supabase.co/functions/v1/id-view?t=abc', open: 'https://drive.google.com/file/d/$fileId/view');
  }
}

class _Code implements DriveAuth {
  _Code(this.code, [this.fail]);
  final String? code;
  final DriveAuthFail? fail;
  @override
  Future<(String?, DriveAuthFail?)> serverCode() async => (code, fail);
}

/// A white 400×250 "card" photo.
Uint8List _photo() => Uint8List.fromList(img.encodeJpg(img.fill(img.Image(width: 400, height: 250), color: img.ColorRgb8(255, 255, 255)), quality: 90));

class _Camera implements PhotoPicker {
  _Camera(this.bytes);
  final Uint8List? bytes;
  int taken = 0;
  @override
  Future<Uint8List?> pick() async {
    taken++;
    return bytes;
  }
}

bool _dark(img.Image im, double fx, double fy) {
  final p = im.getPixel((fx * im.width).round(), (fy * im.height).round());
  return p.r < 40 && p.g < 40 && p.b < 40;
}

Hostel _listed(String id, {DateTime? confirmed, int min = 5000, int max = 6000}) => Hostel(id: id, name: 'Listed $id', gender: 'Men', area: 'Madhapur', from: min, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: '', reply: 0, mins: const {'Hitec City': 7}, x: 30, y: 40, tags: const [], listed: true, rentMin: min, rentMax: max, rentConfirmedAt: confirmed);

void main() {
  mapTiles = false;
  setUp(SampleRepo.resetDrive);
  tearDown(resetSampleData);

  // ------------------------------------------------------------ F28 Part 4
  test('28-90: a listed hostel’s rent is fresh for 60 days after a person confirmed it; verified hostels always show theirs', () {
    final now = DateTime(2026, 10, 18);
    expect(rentFresh(_listed('a', confirmed: now.subtract(const Duration(days: 59))), now: now), isTrue);
    expect(rentFresh(_listed('b', confirmed: now.subtract(const Duration(days: 60))), now: now), isFalse);
    expect(rentFresh(_listed('c'), now: now), isFalse);
    expect(rentFresh(hostelById('anjani'), now: now), isTrue);
    expect(rentLine(_listed('a', confirmed: now, min: 7000, max: 9000), now: now), 'Around ₹7,000–9,000');
    expect(rentLine(_listed('b'), now: now), 'Rent on request');
    // Priced listed hostels before "Rent on request" ones.
    final fresh = _listed('a', confirmed: now), stale = _listed('b');
    expect(rentFreshCompare(stale, fresh, now: now), greaterThan(0));
    expect(rentFreshCompare(fresh, stale, now: now), lessThan(0));
    expect(rentFreshCompare(fresh, hostelById('anjani'), now: now), 0);
    // From the server row.
    final l = listingsFromRows([
      {'id': 'x1', 'name': 'Listed PG', 'gender': 'Men', 'area': 'Madhapur', 'status': 'listed', 'rent_min': 7000, 'rent_max': 9000, 'rent_confirmed_at': '2026-10-01T10:00:00+00:00'},
      {'id': 'x2', 'name': 'Old PG', 'gender': 'Men', 'area': 'Madhapur', 'status': 'listed', 'rent_min': 7000, 'rent_max': 9000},
    ]);
    expect(l.hostels[0].rentConfirmedAt, DateTime.parse('2026-10-01T10:00:00+00:00').toLocal());
    expect(l.hostels[1].rentConfirmedAt, isNull);
    expect(rentFresh(l.hostels[0], now: DateTime.parse('2026-11-29T10:00:00+00:00')), isTrue);
    expect(rentFresh(l.hostels[0], now: DateTime.parse('2026-12-01T10:00:00+00:00')), isFalse);
  });

  testWidgets('28-90: Explore says "Rent on request" after 60 days, sorts that card after priced ones; its page keeps the number back', (tester) async {
    final s = AppState(start: 'explore', role: 'tenant');
    // (after the state is made: it starts from the seed hostels)
    hostels.add(_listed('stale', confirmed: DateTime.now().subtract(const Duration(days: 75))));
    s.rooms['stale'] = [];
    await _pump(tester, s);
    final hs = filtered(s);
    expect(hs.last.id, 'stale', reason: 'the cheapest listed hostel goes last because its rent is stale');
    expect(hs.indexWhere((h) => h.id == 'balaji'), lessThan(hs.length - 1));
    await tester.ensureVisible(find.byKey(const ValueKey('listedCard-stale')));
    await tester.pump();
    expect(find.byKey(const ValueKey('rentOnRequest')), findsOneWidget);
    expect(find.text('Rent on request'), findsOneWidget); // the card: those words only (F31)
    expect(find.textContaining('₹5,000'), findsNothing);
    // The demo's own listed hostel is confirmed today: it shows its range.
    await tester.ensureVisible(find.byKey(const ValueKey('listedCard-balaji')));
    await tester.pump();
    expect(find.textContaining('Around ₹7,000–9,000/mo'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('listedCard-stale')));
    expect(s.screen, 'detail');
    expect(find.text('Rent on request'), findsOneWidget);
    // The page: the words and the button, no sentence (F31).
    expect(find.textContaining('confirmed'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('rentAsk')));
    expect(s.lastLink.toString(), contains('wa.me'));
    expect(find.textContaining('₹5,000'), findsNothing);
    _end(s);
  });

  // ------------------------------------------------------------ F29 Part 3: H50
  testWidgets('29-20: Manage › Tenant IDs → H50: connect, Full copy switch, disconnect (demo data), light and dark', (tester) async {
    for (final dark in [false, true]) {
      SampleRepo.resetDrive();
      final s = AppState(start: 'oMore', role: 'owner', theme: dark ? 'dark' : 'light');
      await _pump(tester, s);
      final row = find.byKey(const ValueKey('manage-Tenant IDs'));
      expect(row, findsOneWidget);
      await _tap(tester, row);
      expect(s.sheet, 'drive');
      await tester.pump();
      expect(find.text('Tenant IDs in your Drive'), findsOneWidget);
      // F31 Rule A: a status line, the button, the switch; nothing explained.
      expect(_status('Not connected'), findsOneWidget);
      expect(find.byKey(const ValueKey('driveNotYet')), findsNothing);
      expect(find.byKey(const ValueKey('fullCopy')), findsNothing);
      expect(find.textContaining('Hostelzy never stores'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('driveConnect')));
      await tester.pump();
      expect(s.driveStatus?.connected, isTrue);
      expect(find.text('Connected · 0 files'), findsOneWidget);
      expect(s.toast, 'Google Drive connected');
      expect(find.text('Full copy needed (police file)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // the toast sits over the sheet's bottom
      await _tap(tester, find.byKey(const ValueKey('fullCopy')));
      await tester.pump();
      expect(s.driveStatus?.fullCopy, isTrue);
      expect((await const SampleRepo().driveStatus('anjani'))?.fullCopy, isTrue);
      await _tap(tester, find.byKey(const ValueKey('driveDisconnect')));
      await tester.pump();
      expect(s.driveStatus?.connected, isFalse);
      expect(find.byKey(const ValueKey('driveConnect')), findsOneWidget);
      // The Manage row follows.
      s.update(() => s.sheet = null);
      await tester.pump();
      expect(find.text('Not connected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4)); // let the toast go
      _end(s);
    }
  });

  testWidgets('29-20: on a real server: status from the server, Google’s code goes to drive-connect, the switch saves', (tester) async {
    final srv = _Server();
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = srv;
    s.driveAuth = _Code('4/abc');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Tenant IDs')));
    await tester.pump();
    expect(srv.calls, ['status anjani']);
    await _tap(tester, find.byKey(const ValueKey('driveConnect')));
    await tester.pump();
    expect(srv.calls.last, 'connect anjani 4/abc');
    expect(find.text('Connected · 0 files'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // let the toast go
    await _tap(tester, find.byKey(const ValueKey('fullCopy')));
    await tester.pump();
    expect(srv.calls.last, 'fullCopy anjani true');
    srv.st = (connected: true, files: 12, fullCopy: true);
    await s.loadDrive();
    await tester.pump();
    expect(find.text('Connected · 12 files'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('driveDisconnect')));
    await tester.pump();
    expect(srv.calls.last, 'disconnect anjani');
    expect(s.toast, 'Disconnected');
    // The owner backs out of Google's consent: nothing happens, no "not available".
    s.driveAuth = _Code(null, DriveAuthFail.cancelled);
    await _tap(tester, find.byKey(const ValueKey('driveConnect')));
    await tester.pump();
    expect(s.driveUnavailable, isNull);
    expect(srv.calls.where((c) => c.startsWith('connect')).length, 1);
    await tester.pump(const Duration(seconds: 4)); // let the toast go
    _end(s);
  });

  testWidgets('29-20: honest "Not available yet": server without Drive, consent screen without the scope, no_scope from the server; Try again', (tester) async {
    // 1. The SQL / functions aren't there.
    final none = _Server(hasDrive: false);
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = none;
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Tenant IDs')));
    await tester.pump();
    // F31: one line, no button.
    expect(find.byKey(const ValueKey('driveNotYet')), findsOneWidget);
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('driveConnect')), findsNothing);
    expect(find.byType(Cta), findsNothing);
    expect(none.calls, ['status anjani']);
    // 2. Google refuses the Drive scope on this device (consent screen lacks it).
    final srv = _Server();
    s.data = srv;
    s.driveAuth = _Code(null, DriveAuthFail.failed);
    await s.loadDrive();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('driveConnect')));
    await tester.pump();
    expect(s.driveUnavailable, 'scope');
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('driveConnect')), findsNothing);
    expect(srv.calls.any((c) => c.startsWith('connect')), isFalse);
    // 3. The server says no_scope.
    final noScope = _Server(connectFail: const DriveFail('no_scope', 'Google didn’t allow Drive access'));
    s.data = noScope;
    s.driveAuth = _Code('4/abc');
    await s.loadDrive();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('driveConnect')));
    await tester.pump();
    expect(s.driveUnavailable, 'scope');
    expect(find.byKey(const ValueKey('driveNotYet')), findsOneWidget);
    // 4. Any other refusal is said in the server's words, and the sheet stays usable.
    final noRefresh = _Server(connectFail: const DriveFail('no_refresh', 'Google didn’t give Hostelzy a lasting permission.'));
    s.data = noRefresh;
    await s.loadDrive();
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('driveConnect')));
    await tester.pump();
    expect(s.toast, 'Google didn’t give Hostelzy a lasting permission.');
    expect(find.byKey(const ValueKey('driveConnect')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // let the toast go
    _end(s);
  });

  testWidgets('29-20: a manager sees the status and the switch but can’t connect or disconnect', (tester) async {
    final srv = _Server();
    final s = AppState(start: 'oMore', role: 'owner');
    s.data = srv;
    s.managerOf.add('anjani');
    await _pump(tester, s);
    await _tap(tester, find.byKey(const ValueKey('manage-Tenant IDs')));
    await tester.pump();
    expect(_status('Not connected'), findsOneWidget);
    expect(find.byKey(const ValueKey('driveConnect')), findsNothing);
    srv.st = (connected: true, files: 3, fullCopy: false);
    await s.loadDrive();
    await tester.pump();
    expect(find.text('Connected · 3 files'), findsOneWidget);
    expect(s.sheet, 'drive');
    expect(find.byKey(const ValueKey('driveDisconnect')), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('fullCopy')));
    await tester.pump();
    expect(srv.calls.last, 'fullCopy anjani true');
    await tester.pump(const Duration(seconds: 4)); // let any toast go
    _end(s);
  });

  // ------------------------------------------------------------ IdCapture
  test('29-21: maskImage burns a black bar where the tenant put it, and nowhere else', () {
    final out = maskImage(_photo(), defaultMaskBar)!;
    final im = img.decodeImage(out)!;
    expect(_dark(im, .3, .66), isTrue);
    expect(_dark(im, .07, .63), isTrue);
    expect(_dark(im, .9, .2), isFalse);
    expect(_dark(im, .3, .4), isFalse);
    expect(maskImage(Uint8List.fromList([1, 2, 3]), defaultMaskBar), isNull);
  });

  testWidgets('29-21: IdCapture: camera → "Cover the first 8 digits" with a draggable bar → upload sends the masked photo → done', (tester) async {
    for (final dark in [false, true]) {
      final srv = _Server();
      final s = AppState(start: 'explore', role: 'tenant', theme: dark ? 'dark' : 'light');
      s.data = srv;
      final cam = _Camera(_photo());
      String? got;
      await _pumpWidget(tester, s, IdCapture(key: ValueKey(dark), token: 'tok-1', fullCopy: false, ownerName: 'Srinivas', camera: cam, onUploaded: (id) => got = id), dark: dark);
      expect(find.text('Take a photo of your ID'), findsOneWidget);
      expect(find.byType(T), findsOneWidget, reason: 'F31: the button only, no sentence under it');
      await _tap(tester, find.byKey(const ValueKey('idTake')));
      await tester.pump();
      expect(cam.taken, 1);
      expect(find.text('Cover the first 8 digits'), findsOneWidget);
      final bar = find.byKey(const ValueKey('maskBar'));
      expect(bar, findsOneWidget);
      // Drag the bar up to the top-left; the upload is masked there, not at the start spot.
      final before = tester.getTopLeft(bar);
      await tester.drag(bar, const Offset(-300, -300));
      await tester.pump();
      expect(tester.getTopLeft(bar).dy, lessThan(before.dy));
      await _tap(tester, find.byKey(const ValueKey('idUpload')));
      await tester.pump();
      expect(srv.calls.last, 'upload tok-1 image/jpeg');
      expect(got, 'file-1');
      expect(find.byKey(const ValueKey('idDone')), findsOneWidget);
      expect(find.text('Uploaded to Srinivas’s Drive'), findsOneWidget);
      final im = img.decodeImage(srv.uploads.single)!;
      expect(_dark(im, .02, .02), isTrue);
      expect(_dark(im, .3, .66), isFalse);
      _end(s);
    }
  });

  testWidgets('29-21: IdCapture: Full copy needed → no bar, the photo goes as taken; refusals are plain; retake', (tester) async {
    final srv = _Server();
    final s = AppState(start: 'explore', role: 'tenant');
    s.data = srv;
    final cam = _Camera(_photo());
    await _pumpWidget(tester, s, IdCapture(token: 'tok-1', fullCopy: true, camera: cam, onUploaded: (_) {}));
    await _tap(tester, find.byKey(const ValueKey('idTake')));
    await tester.pump();
    expect(find.byKey(const ValueKey('maskBar')), findsNothing);
    expect(find.text('Full copy needed (police file)'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('idRetake')));
    await tester.pump();
    expect(cam.taken, 2);
    await _tap(tester, find.byKey(const ValueKey('idUpload')));
    await tester.pump();
    final im = img.decodeImage(srv.uploads.single)!;
    expect(_dark(im, .3, .66), isFalse);
    // Not available yet / the owner isn't connected: said on the spot, the tenant can try again.
    for (final (fail, words) in [(const DriveFail('not_ready', 'x'), 'Not available yet'), (const DriveFail('not_connected', 'The owner hasn’t connected Google Drive'), 'The owner hasn’t connected Google Drive')]) {
      final bad = _Server(connectFail: fail);
      s.data = bad;
      await _pumpWidget(tester, s, IdCapture(key: ValueKey(fail.code), token: 'tok-1', fullCopy: false, camera: _Camera(_photo()), onUploaded: (_) {}));
      await _tap(tester, find.byKey(const ValueKey('idTake')));
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('idUpload')));
      await tester.pump();
      expect(find.byKey(const ValueKey('idError')), findsOneWidget);
      expect(find.text(words), findsOneWidget);
      expect(find.byKey(const ValueKey('idUpload')), findsOneWidget);
    }
    // With no fullCopy given, the widget asks the server by the token (S94's path).
    final asks = _Server()..st = (connected: true, files: 0, fullCopy: true);
    s.data = asks;
    await _pumpWidget(tester, s, IdCapture(key: const ValueKey('asks'), token: 'tok-1', fullCopy: null, camera: _Camera(_photo()), onUploaded: (_) {}));
    await tester.pump();
    expect(asks.calls, ['target tok-1']);
    await _tap(tester, find.byKey(const ValueKey('idTake')));
    await tester.pump();
    expect(find.byKey(const ValueKey('maskBar')), findsNothing);
    expect(find.text('Full copy needed (police file)'), findsOneWidget);
    // The camera closed without a photo: back to the button.
    await _pumpWidget(tester, s, IdCapture(key: const ValueKey('none'), token: 'tok-1', fullCopy: false, camera: _Camera(null), onUploaded: (_) {}));
    await _tap(tester, find.byKey(const ValueKey('idTake')));
    await tester.pump();
    expect(find.byKey(const ValueKey('idTake')), findsOneWidget);
    _end(s);
  });

  // ------------------------------------------------------------ IdThumb
  testWidgets('29-20: IdThumb: asks id-view once, shows the image or why not, opens the file in Drive; demo draws a stand-in', (tester) async {
    final srv = _Server();
    final s = AppState(start: 'oToday', role: 'owner');
    s.data = srv;
    await _pumpWidget(tester, s, const IdThumb(hid: 'anjani', fileId: 'file-9'));
    await tester.pump();
    expect(srv.calls, ['view anjani file-9']);
    // Network images don't load in tests: the honest fallback shows and the tap still opens Drive.
    await tester.pump();
    expect(find.byKey(const ValueKey('idThumbError')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('idThumb')));
    expect(s.lastLink.toString(), 'https://drive.google.com/file/d/file-9/view');
    expect(srv.calls.length, 1);
    final off = _Server(viewFail: const DriveFail('not_ready', 'x'));
    s.data = off;
    await _pumpWidget(tester, s, const IdThumb(key: ValueKey('off'), hid: 'anjani', fileId: 'file-9'));
    await tester.pump();
    expect(find.text('Not available yet'), findsOneWidget);
    s.data = const SampleRepo();
    await _pumpWidget(tester, s, const IdThumb(key: ValueKey('sample'), hid: 'anjani', fileId: 'sample-id-1'));
    await tester.pump();
    expect(find.byKey(const ValueKey('idThumbSample')), findsOneWidget);
    expect(find.text('Sample ID (drawn)'), findsOneWidget);
    _end(s);
  });
}
