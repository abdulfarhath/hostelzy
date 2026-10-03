// F18 map: "Use my location". Asks Android only after the app's explainer;
// never invents a position. Tests, web and desktop use [NoLocator].

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why there is no position: off (location switched off), denied, never
/// (denied forever: Settings), unavailable (no GPS here), failed.
enum LocateFail { off, denied, never, unavailable, failed }

abstract class Locator {
  /// [exact]: the team dropping a hostel's pin at its gate (F24 Wave 4c)
  /// wants GPS accuracy; finding nearby hostels doesn't.
  Future<((double, double)?, LocateFail?)> locate({bool exact = false});
}

class NoLocator implements Locator {
  const NoLocator();
  @override
  Future<((double, double)?, LocateFail?)> locate({bool exact = false}) async => (null, LocateFail.unavailable);
}

class GeoLocator implements Locator {
  const GeoLocator();
  @override
  Future<((double, double)?, LocateFail?)> locate({bool exact = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return (null, LocateFail.off);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return (null, LocateFail.never);
      if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) return (null, LocateFail.denied);
      // Coarse is enough to show nearby hostels (and kinder to privacy).
      final p = await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: exact ? LocationAccuracy.best : LocationAccuracy.low, timeLimit: const Duration(seconds: 15)));
      return ((p.latitude, p.longitude), null);
    } catch (e) {
      debugPrint('Location: $e');
      return (null, LocateFail.failed);
    }
  }
}

/// The real locator on Android, nothing elsewhere.
Locator platformLocator() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? const GeoLocator() : const NoLocator();
