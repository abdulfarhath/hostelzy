import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'features/links/scan.dart' show CameraScanner;
import 'features/listings/cache.dart';
import 'features/listings/repo.dart';
import 'features/photos/pick.dart' show GalleryPicker;
import 'l10n.dart';
import 'locate.dart';
import 'push.dart';
import 'reminders.dart';
import 'router.dart';
import 'sign_in.dart';
import 'state.dart';
import 'store.dart';
import 'ui/overview.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (p, a) = await startFirebase();
  push = p;
  signIn = a;
  // F20: reminders ring from this phone (local notifications).
  reminders = await LocalReminders.start();
  // F18: stay logged in: what this phone kept from last time.
  saved = await store.load();
  runApp(const HostelzyApp());
}

/// F13: Firebase push and Google sign-in on Android; no-ops elsewhere.
Push push = const NoPush();
SignIn signIn = const NoSignIn();
Reminders reminders = NoReminders();
final Store store = PrefsStore();
Map<String, dynamic> saved = const {};

/// Root. On the web, query parameters pick a start state, the same props the
/// design exposes: `?start=picker&role=tenant&mode=room&theme=dark`, and
/// `?page=overview` opens the all-screens canvas.
class HostelzyApp extends StatefulWidget {
  const HostelzyApp({super.key});
  @override
  State<HostelzyApp> createState() => _HostelzyAppState();
}

class _HostelzyAppState extends State<HostelzyApp> with WidgetsBindingObserver {
  // F17: start-state shortcuts and the all-screens canvas are for
  // development only; the Play Store build always starts at Welcome.
  // PROTO=true (the web prototype only, see docs/PROTOTYPE.md) keeps these shortcuts in a release build.
  static const _proto = bool.fromEnvironment('PROTO');
  final q = kDebugMode || _proto ? Uri.base.queryParameters : const <String, String>{};
  late final AppState state = AppState(
    start: _pick(q['start'], AppState.screens),
    role: _pick(q['role'], const ['tenant', 'resident', 'owner']),
    theme: _pick(q['theme'], const ['light', 'dark', 'system']),
    mode: _pick(q['mode'], const ['plan', 'room']),
    sheet: _pick(q['sheet'], const ['search', 'hold', 'wa', 'bed', 'addR', 'rank', 'report', 'trusted', 'utr', 'layoutReq', 'switch', 'manager', 'payAdv', 'payUtr', 'team', 'addRoom', 'fixLock', 'fixLimit', 'fixSend', 'fixReject', 'laundry', 'perks']),
    moveTab: _pick(q['moveTab'], const ['vacate', 'swap']),
    moreTab: _pick(q['moreTab'], const ['home', 'residents', 'complaints', 'deals', 'rates', 'menu', 'rules']),
    foodView: _pick(q['foodView'], const ['day', 'week']),
    mView: _pick(q['mView'], const ['day', 'week']),
    auth: q['auth'],
    plan: _pick(q['plan'], const ['late5', 'late15', 'checking', 'paid', 'missing']),
  );
  late bool overview = q['page'] == 'overview';
  late final router = appRouter(state, (_) => HostelzyShell(bare: q['bare'] == 'true', onOpenOverview: () => setState(() => overview = true)));
  late final StreamSubscription<(String, String)> _pushSub;

  @override
  void initState() {
    super.initState();
    state.push = push;
    state.signIn = signIn;
    state.locator = platformLocator();
    state.picker = const GalleryPicker();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) state.scanner = const CameraScanner();
    state.store = store;
    // Dev start states (debug ?start=…) skip the saved login.
    if (q['start'] == null) state.restore(saved, firebaseUser: signIn.current);
    _pushSub = push.foreground.listen((m) => state.toastMsg(m.$2.isEmpty ? m.$1 : '${m.$1}: ${m.$2}'));
    state.watchPushToken();
    state.startReminders(reminders);
    // F21 W4: the checked Telugu / Hindi strings bundled with this build.
    loadLangs().then((l) => state.update(() => state.langs = l));
    WidgetsBinding.instance.addObserver(this);
    if (dataSource == 'supabase') {
      _goLive();
    } else {
      state.syncPushToken();
    }
  }

  /// F13: live hostels and remote switches from Supabase.
  Future<void> _goLive() async {
    // F21 W4: skeleton cards until the hostels arrive; "offline" if they can't.
    state.reconnect = _goLive;
    state.update(() => state.listState = 'loading');
    try {
      final db = await SupabaseRepo.connect(idToken: signIn.available ? signIn.idToken : null);
      state.data = db;
      // Perf: the switches and the hostels are fetched together; the
      // switches still apply first.
      final lf = db.listings()..ignore();
      final s = await db.settings();
      if (s != null) state.applySettings(s);
      final l = await lf;
      if (l != null) state.applyListings(l);
      state.update(() => state.listState = 'ready');
      // B6: the signed-in user's holds, enquiries, payments and complaints, live.
      await state.startLive();
      // F20: a new phone gets its reminders back.
      await state.restoreRemFromServer();
      // F24 item 22: the notification switches kept on the profile.
      await state.loadNotifyFromServer();
      // Push fix: every start, the server gets this phone's token if allowed.
      await state.syncPushToken();
    } catch (e) {
      // Never show sample hostels as if they were live: the last list from the
      // server if this phone has one (marked offline, F24), else an honest
      // empty list.
      if (state.listState == 'loading') {
        final c = await loadListingRows();
        if (c != null) {
          state.applyListings(listingsFromRows(c.rows));
          state.update(() {
            state.listState = 'cached';
            state.cachedAt = c.at;
          });
        } else {
          state.applyListings((hostels: const [], rooms: const {}, rates: const {}, pos: const {}, upi: const {}, layouts: const {}, deals: const {}, rules: const {}, reviews: const {}, strikes: const {}, checks: const {}, checkers: const {}, amenities: const {}, standing: const {}));
          state.update(() => state.listState = 'offline');
        }
      }
      debugPrint('Supabase: $e');
    }
  }

  static String? _pick(String? v, List<String> ok) => v != null && ok.contains(v) ? v : null;

  /// F20: a glass counted from a notification shows when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) state.refreshGlasses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSub.cancel();
    router.dispose();
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Hostelzy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Archivo',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(selectionColor: Color(0x55EC3013)),
      ),
      builder: (context, child) => MediaQuery(
        // F18: follow the phone's text size, capped so layouts still fit.
        data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1, maxScaleFactor: 2)),
        child: overview ? OverviewPage(onOpenPrototype: () => setState(() => overview = false)) : AppScope(state: state, child: child!),
      ),
    );
  }
}
