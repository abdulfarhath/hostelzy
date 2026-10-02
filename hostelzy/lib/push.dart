// F13: push notifications (Firebase Cloud Messaging) and crash reports
// (Crashlytics). Android only; tests, web and desktop use [NoPush].

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'sign_in.dart';

/// Result of asking Android for notification permission.
enum PushAsk { allowed, denied, unavailable }

abstract class Push {
  /// Shows Android's own prompt (after the app's explainer).
  Future<PushAsk> ask();

  /// This phone's FCM token, for the server to send pushes to.
  Future<String?> token();

  /// Whether Android lets the app show notifications now, without asking.
  /// Null where push doesn't exist (tests, web, desktop).
  Future<bool?> allowed();

  /// New tokens (FCM rotates them).
  Stream<String> get tokenRefresh;

  /// Forgets this phone's token (sign-out, account deleted).
  Future<void> deleteToken();

  /// Notifications that arrive while the app is open: (title, body).
  Stream<(String, String)> get foreground;
}

/// No Firebase here (tests, web, desktop): nothing is switched on.
class NoPush implements Push {
  const NoPush();
  @override
  Future<PushAsk> ask() async => PushAsk.unavailable;
  @override
  Future<String?> token() async => null;
  @override
  Future<bool?> allowed() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<(String, String)> get foreground => const Stream.empty();
}

class FirebasePush implements Push {
  final _m = FirebaseMessaging.instance;
  @override
  Future<PushAsk> ask() async {
    final r = await _m.requestPermission();
    return r.authorizationStatus == AuthorizationStatus.authorized || r.authorizationStatus == AuthorizationStatus.provisional ? PushAsk.allowed : PushAsk.denied;
  }

  @override
  Future<String?> token() => _m.getToken();
  @override
  Future<bool?> allowed() async {
    final st = (await _m.getNotificationSettings()).authorizationStatus;
    return st == AuthorizationStatus.authorized || st == AuthorizationStatus.provisional;
  }

  @override
  Stream<String> get tokenRefresh => _m.onTokenRefresh;
  @override
  Future<void> deleteToken() => _m.deleteToken();
  @override
  Stream<(String, String)> get foreground => FirebaseMessaging.onMessage.where((m) => m.notification != null).map((m) => (m.notification!.title ?? 'Hostelzy', m.notification!.body ?? ''));
}

/// Starts Firebase on Android: crash reports in release builds, push and
/// Google sign-in. Returns [NoPush] / [NoSignIn] anywhere else or if Firebase
/// can't start.
Future<(Push, SignIn)> startFirebase() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return (const NoPush(), const NoSignIn());
  try {
    await Firebase.initializeApp();
    final c = FirebaseCrashlytics.instance;
    await c.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = c.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (e, st) {
      c.recordError(e, st, fatal: true);
      return true;
    };
    return (FirebasePush(), FirebaseSignIn());
  } catch (e) {
    debugPrint('Firebase: $e');
    return (const NoPush(), const NoSignIn());
  }
}
