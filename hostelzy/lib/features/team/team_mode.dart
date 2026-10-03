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
    // F24 item 29: this account shows as Active; the tracker and the team
    // come from the server.
    if (data.remote) {
      try {
        await data.teamHello();
      } catch (e) {
        debugPrint('team hello: $e');
      }
      await loadTeam();
    }
  }

  /// F24 item 29: the onboarding tracker (every hostel and its stage) and the
  /// team members, from the server. Before its SQL runs the lists stay as
  /// they are (empty in the real app).
  Future<void> loadTeam() async {
    if (!data.remote || account == null) return;
    try {
      final got = await Future.wait([data.teamTracker(), data.teamMembers()]);
      update(() {
        leads
          ..clear()
          ..addAll(got[0] as List<Lead>);
        teamMembers
          ..clear()
          ..addAll(got[1] as List<({String name, String phone, String role, bool joined})>);
      });
    } catch (e) {
      debugPrint('team: $e');
    }
  }

  /// Tracker: the button on a row moves the hostel to its next stage. On the
  /// server: Lead → Visited → Signed up → Data complete are saved; Live goes
  /// through go-live's checks; trial and paying follow the owner's plan.
  Future<void> advanceLead(Lead l) async {
    if (l.stage == 3 && l.hid == null) return openAddHostel();
    final hid = l.hid;
    if (!data.remote || hid == null || isSeedHostel(hid)) return update(() => l.stage++);
    if (l.stage >= 4) return toastMsg('Trial and paying follow ${l.name}’s plan.');
    try {
      if (l.stage == 3) {
        await data.goLive(hid);
        await refreshListings();
        toastMsg('${l.name} is live. The 30-day trial starts today.');
      } else {
        await data.setLeadStage(hid, l.stage + 1);
      }
    } catch (e) {
      debugPrint('lead: $e');
      return toastMsg(_onboardWords(e));
    }
    await loadTeam();
  }
}
