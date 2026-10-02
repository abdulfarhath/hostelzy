// F13 login (DECISIONS "Payments contact + login SMS"): Sign in with Google
// through Firebase Auth, free on the Spark plan. Supabase trusts the Firebase
// ID token (Third-party Auth), so database rules key off the Firebase uid.
// SMS OTP comes back later, behind `phoneOtpLogin`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The signed-in Google account.
typedef Account = ({String uid, String name, String email});

/// Why Google sign-in didn't finish.
enum SignInFail { cancelled, notSetUp, failed }

abstract class SignIn {
  /// False where Google sign-in can't work (tests, web, desktop, no Firebase).
  bool get available;

  /// Signs in with Google; the account, or why not.
  Future<(Account?, SignInFail?)> google();

  /// Firebase ID token for Supabase (refreshed when needed).
  Future<String?> idToken();

  /// The account Firebase still has signed in from last time, if any.
  Account? get current;

  /// B7: the signed-in account has the `team: true` claim (set only by the
  /// founder's "Team member" GitHub action, never by the app).
  Future<bool> isTeam();

  Future<void> signOut();
}

/// No Google sign-in here: the app offers the local fallback.
class NoSignIn implements SignIn {
  const NoSignIn();
  @override
  bool get available => false;
  @override
  Future<(Account?, SignInFail?)> google() async => (null, SignInFail.notSetUp);
  @override
  Future<String?> idToken() async => null;
  @override
  Future<bool> isTeam() async => false;
  @override
  Account? get current => null;
  @override
  Future<void> signOut() async {}
}

/// Optional override for Google's web client id; normally it comes from
/// `google-services.json` once Google sign-in is switched on in Firebase.
const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

class FirebaseSignIn implements SignIn {
  final _auth = FirebaseAuth.instance;
  bool _ready = false;

  @override
  bool get available => true;

  @override
  Future<(Account?, SignInFail?)> google() async {
    try {
      final g = GoogleSignIn.instance;
      if (!_ready) {
        await g.initialize(serverClientId: _webClientId.isEmpty ? null : _webClientId);
        _ready = true;
      }
      final a = await g.authenticate();
      final cred = GoogleAuthProvider.credential(idToken: a.authentication.idToken);
      final u = (await _auth.signInWithCredential(cred)).user!;
      return ((uid: u.uid, name: u.displayName ?? a.displayName ?? '', email: u.email ?? a.email), null);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in: $e');
      return (null, e.code == GoogleSignInExceptionCode.canceled ? SignInFail.cancelled : (e.code == GoogleSignInExceptionCode.clientConfigurationError || e.code == GoogleSignInExceptionCode.providerConfigurationError ? SignInFail.notSetUp : SignInFail.failed));
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase sign-in: ${e.code}');
      return (null, e.code == 'operation-not-allowed' || e.code == 'app-not-authorized' ? SignInFail.notSetUp : SignInFail.failed);
    } catch (e) {
      debugPrint('Sign-in: $e');
      return (null, SignInFail.failed);
    }
  }

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  @override
  Future<bool> isTeam() async {
    try {
      // Forces a fresh token, so a claim added a minute ago counts.
      final r = await _auth.currentUser?.getIdTokenResult(true);
      return r?.claims?['team'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Account? get current {
    final u = _auth.currentUser;
    return u == null ? null : (uid: u.uid, name: u.displayName ?? '', email: u.email ?? '');
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_ready) await GoogleSignIn.instance.signOut();
  }
}
