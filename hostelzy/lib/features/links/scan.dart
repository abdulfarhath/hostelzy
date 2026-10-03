// F14: "Scan the QR" on Join your PG. The camera view is kept apart from the
// app state so tests use a fake scanner (no camera, no plugin).

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

abstract class QrScanner {
  /// Whether this phone can scan in the app (Android with a camera).
  bool get available;

  /// The live camera view; calls [onCode] with each QR's text. [onError]
  /// builds what shows when the camera can't start (not allowed, no camera).
  Widget view(void Function(String raw) onCode, Widget Function(bool denied) onError);
}

/// Tests, web and desktop: no in-app scanner.
class NoScanner implements QrScanner {
  const NoScanner();
  @override
  bool get available => false;
  @override
  Widget view(void Function(String raw) onCode, Widget Function(bool denied) onError) => onError(false);
}

/// The phone's camera (mobile_scanner). Android asks for the camera the
/// first time the view opens, after the app's own explainer.
class CameraScanner implements QrScanner {
  const CameraScanner();
  @override
  bool get available => true;
  @override
  Widget view(void Function(String raw) onCode, Widget Function(bool denied) onError) => MobileScanner(
    onDetect: (c) {
      for (final b in c.barcodes) {
        final v = b.rawValue;
        if (v != null && v.isNotEmpty) return onCode(v);
      }
    },
    errorBuilder: (context, e) => onError(e.errorCode == MobileScannerErrorCode.permissionDenied),
  );
}

final _code = RegExp(r'^[A-Z0-9]{2,6}-[A-Z0-9]{2,8}$');

/// The invite code in a scanned QR: the poster's j/ link
/// (`https://…/j/?c=ANJ-7Q2`, `hostelzy://app/j?c=…`) or a bare code. Null
/// for anything else (another app's QR, a booking link).
String? inviteCodeFromQr(String raw) {
  final t = raw.trim();
  if (_code.hasMatch(t.toUpperCase())) return t.toUpperCase();
  final u = Uri.tryParse(t);
  if (u == null) return null;
  final segs = u.pathSegments.where((x) => x.isNotEmpty).toList();
  final isJoin = (segs.isNotEmpty && segs.last == 'j') || (u.host == 'app' && segs.length == 1 && segs.first == 'j');
  if (!isJoin) return null;
  final c = u.queryParameters['c']?.trim().toUpperCase();
  return c != null && _code.hasMatch(c) ? c : null;
}
