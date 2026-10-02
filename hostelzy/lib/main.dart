import 'package:flutter/material.dart';

import 'state.dart';
import 'ui/overview.dart';
import 'ui/shell.dart';

void main() => runApp(const HostelzyApp());

/// Root. On the web, query parameters pick a start state, the same props the
/// design exposes: `?start=picker&role=tenant&mode=list&theme=dark`, and
/// `?page=overview` opens the all-screens canvas.
class HostelzyApp extends StatefulWidget {
  const HostelzyApp({super.key});
  @override
  State<HostelzyApp> createState() => _HostelzyAppState();
}

class _HostelzyAppState extends State<HostelzyApp> {
  final q = Uri.base.queryParameters;
  late final AppState state = AppState(
    start: _pick(q['start'], AppState.screens),
    role: _pick(q['role'], const ['tenant', 'resident', 'owner']),
    theme: _pick(q['theme'], const ['light', 'dark']),
    mode: _pick(q['mode'], const ['plan', 'list', 'building']),
    sheet: _pick(q['sheet'], const ['search', 'hold', 'wa', 'add', 'bed', 'enq', 'addR', 'rank', 'joined', 'report', 'trusted', 'utr']),
    moveTab: _pick(q['moveTab'], const ['vacate', 'swap']),
    moreTab: _pick(q['moreTab'], const ['residents', 'complaints', 'deals', 'rates', 'menu', 'rules']),
    foodView: _pick(q['foodView'], const ['day', 'week']),
    mView: _pick(q['mView'], const ['day', 'week']),
    plan: _pick(q['plan'], const ['late5', 'late15', 'checking', 'paid', 'missing']),
  );
  late bool overview = q['page'] == 'overview';

  static String? _pick(String? v, List<String> ok) => v != null && ok.contains(v) ? v : null;

  @override
  void dispose() {
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
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
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
