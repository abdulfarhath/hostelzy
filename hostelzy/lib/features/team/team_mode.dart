part of '../../state.dart';

// team mode
mixin _TeamModeData {

  /// Hostelzy team tools are open on this phone. B7: only for Google
  /// accounts with the Firebase `team` claim (the passcode is gone).
  bool teamUnlocked = false;

  /// Checking the claim with Firebase.
  bool teamChecking = false;
}

extension TeamModeActions on AppState {

  void openTeam() {
    if (teamUnlocked) return go('aHome');
    update(() => sheet = 'team');
  }

  /// Asks Firebase whether this Google account is on the Hostelzy team.
  Future<void> checkTeam() async {
    if (account == null) return toastMsg('Sign in with your Hostelzy team Google account first.');
    if (teamChecking) return;
    update(() => teamChecking = true);
    final ok = await signIn.isTeam();
    update(() => teamChecking = false);
    if (!ok) return toastMsg('${account!.email} isn’t a Hostelzy team account.');
    update(() {
      teamUnlocked = true;
      sheet = null;
      hist = [...hist, screen];
      screen = 'aHome';
    });
  }
}
