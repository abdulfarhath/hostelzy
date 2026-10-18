// F29 Part 3: Google's server auth code for the Drive scope, so the server
// (drive-connect) can get a refresh token for the owner's Drive. Only the
// `drive.file` scope is asked for: Google shows the owner that Hostelzy may
// see and change only files it makes itself.

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../sign_in.dart';

const driveScope = 'https://www.googleapis.com/auth/drive.file';

/// Why the code didn't come: the owner backed out, Google sign-in isn't set
/// up here, or Google refused (the consent screen lacks the scope).
enum DriveAuthFail { cancelled, notSetUp, failed }

abstract class DriveAuth {
  Future<(String? code, DriveAuthFail? fail)> serverCode();
}

/// No Google here (tests, web, desktop): the sample path connects without it.
class NoDriveAuth implements DriveAuth {
  const NoDriveAuth();
  @override
  Future<(String?, DriveAuthFail?)> serverCode() async => (null, DriveAuthFail.notSetUp);
}

class GoogleDriveAuth implements DriveAuth {
  const GoogleDriveAuth();
  @override
  Future<(String?, DriveAuthFail?)> serverCode() async {
    try {
      await ensureGoogleReady();
      final a = await GoogleSignIn.instance.authorizationClient.authorizeServer([driveScope]);
      final code = a?.serverAuthCode ?? '';
      return code.isEmpty ? (null, DriveAuthFail.cancelled) : (code, null);
    } on GoogleSignInException catch (e) {
      debugPrint('Drive auth: $e');
      return (null, switch (e.code) {
        GoogleSignInExceptionCode.canceled => DriveAuthFail.cancelled,
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError => DriveAuthFail.notSetUp,
        _ => DriveAuthFail.failed,
      });
    } catch (e) {
      debugPrint('Drive auth: $e');
      return (null, DriveAuthFail.failed);
    }
  }
}
