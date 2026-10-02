import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'state.dart';

/// ARCHITECTURE step 1: go_router owns how the app is entered. Screens and
/// the back stack stay in [AppState] (one source of truth; Android back is
/// the shell's PopScope → [AppState.handleBack]); the router adds deep links:
///   hostelzy://app/r?c=HZ-5001   an enquiry (web page app/r/)
///   hostelzy://app/j?c=ANJ-7Q2   a resident invite (web page app/j/)
/// The same paths under /hostelzy/app/ work for https links later.
GoRouter appRouter(AppState s, WidgetBuilder shell) {
  String open(void Function() f) {
    // Once the router has finished parsing the link.
    scheduleMicrotask(f);
    return '/';
  }

  String? code(GoRouterState st) => st.uri.queryParameters['c'];
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, _) => shell(c)),
      for (final base in ['', '/hostelzy/app']) ...[
        GoRoute(path: '$base/r', redirect: (_, st) => open(() => s.openEnquiryLink(code(st) ?? ''))),
        GoRoute(path: '$base/j', redirect: (_, st) => open(() => s.openInviteLink(code(st) ?? ''))),
      ],
    ],
    // Any other link just opens the app where it was.
    errorBuilder: (c, _) => shell(c),
  );
}
