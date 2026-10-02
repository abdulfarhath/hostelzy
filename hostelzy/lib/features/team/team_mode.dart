part of '../../state.dart';

// team mode
mixin _TeamModeData {

  /// Hostelzy team tools are unlocked on this phone (temporary passcode
  /// until F13 adds real admin accounts).
  bool teamUnlocked = false;
  String teamCode = '';

  /// G1 stopgap until real admin accounts: 5 wrong tries lock it for 15 min.
  int _teamFails = 0, _teamLockedUntil = 0;
}

extension TeamModeActions on AppState {

  void openTeam() {
    if (teamUnlocked) return go('aHome');
    update(() {
      teamCode = '';
      sheet = 'team';
    });
  }

  void unlockTeam() {
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t < _teamLockedUntil) return toastMsg('Too many wrong tries. Try again in ${((_teamLockedUntil - t) / 60000).ceil()} min.');
    if (teamCode != teamPasscode) {
      _teamFails++;
      if (_teamFails >= 5) {
        _teamFails = 0;
        _teamLockedUntil = t + 15 * 60000;
        return toastMsg('Too many wrong tries. Team mode is locked for 15 minutes.');
      }
      return toastMsg('Wrong passcode. ${5 - _teamFails} tries left.');
    }
    _teamFails = 0;
    update(() {
      teamUnlocked = true;
      sheet = null;
      hist = [...hist, screen];
      screen = 'aHome';
    });
  }
}
