import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'backend.dart';
import 'push.dart';
import 'sign_in.dart';
import 'store.dart';
import 'locate.dart';
import 'state.dart';
import 'ui/overview.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (p, a) = await startFirebase();
  push = p;
  signIn = a;
  // F18: stay logged in: what this phone kept from last time.
  saved = await store.load();
  runApp(const HostelzyApp());
}

/// F13: Firebase push and Google sign-in on Android; no-ops elsewhere.
Push push = const NoPush();
SignIn signIn = const NoSignIn();
final Store store = PrefsStore();
Map<String, dynamic> saved = const {};

/// Root. On the web, query parameters pick a start state, the same props the
/// design exposes: `?start=picker&role=tenant&mode=list&theme=dark`, and
/// `?page=overview` opens the all-screens canvas.
class HostelzyApp extends StatefulWidget {
  const HostelzyApp({super.key});
  @override
  State<HostelzyApp> createState() => _HostelzyAppState();
}

class _HostelzyAppState extends State<HostelzyApp> {
  // F17: start-state shortcuts and the all-screens canvas are for
  // development only; the Play Store build always starts at Welcome.
  final q = kDebugMode ? Uri.base.queryParameters : const <String, String>{};
  late final AppState state = AppState(
    start: _pick(q['start'], AppState.screens),
    role: _pick(q['role'], const ['tenant', 'resident', 'owner']),
    theme: _pick(q['theme'], const ['light', 'dark', 'system']),
    mode: _pick(q['mode'], const ['plan', 'room', 'list', 'building']),
    sheet: _pick(q['sheet'], const ['search', 'hold', 'wa', 'add', 'bed', 'enq', 'addR', 'rank', 'joined', 'report', 'trusted', 'utr', 'layoutReq', 'switch', 'manager', 'payAdv', 'payUtr', 'team', 'addRoom']),
    moveTab: _pick(q['moveTab'], const ['vacate', 'swap']),
    moreTab: _pick(q['moreTab'], const ['residents', 'complaints', 'deals', 'rates', 'menu', 'rules']),
    foodView: _pick(q['foodView'], const ['day', 'week']),
    mView: _pick(q['mView'], const ['day', 'week']),
    auth: q['auth'],
    plan: _pick(q['plan'], const ['late5', 'late15', 'checking', 'paid', 'missing']),
  );
  late bool overview = q['page'] == 'overview';
  late final StreamSubscription<(String, String)> _pushSub;

  @override
  void initState() {
    super.initState();
    state.push = push;
    state.signIn = signIn;
    state.locator = platformLocator();
    state.store = store;
    // Dev start states (debug ?start=…) skip the saved login.
    if (q['start'] == null) state.restore(saved, firebaseUser: signIn.current);
    _pushSub = push.foreground.listen((m) => state.toastMsg(m.$2.isEmpty ? m.$1 : '${m.$1}: ${m.$2}'));
    if (dataSource == 'supabase') _goLive();
  }

  /// F13: live hostels and remote switches from Supabase.
  Future<void> _goLive() async {
    try {
      final db = await SupabaseData.connect(idToken: signIn.available ? signIn.idToken : null);
      state.data = db;
      final s = await db.settings();
      if (s != null) state.applySettings(s);
      final l = await db.listings();
      if (l != null) state.applyListings(l);
    } catch (e) {
      // Say so instead of quietly showing sample hostels as if they were live.
      state.toastMsg('Couldn’t reach Hostelzy. Showing sample hostels. Check your internet.');
      debugPrint('Supabase: $e');
    }
  }

  static String? _pick(String? v, List<String> ok) => v != null && ok.contains(v) ? v : null;

  @override
  void dispose() {
    _pushSub.cancel();
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 1, maxScaleFactor: 1.3)),
        child: child!,
      ),
      home: overview
          ? OverviewPage(onOpenPrototype: () => setState(() => overview = false))
          : AppScope(
              state: state,
              child: HostelzyShell(bare: q['bare'] == 'true', onOpenOverview: () => setState(() => overview = true)),
            ),
    );
  }
}
