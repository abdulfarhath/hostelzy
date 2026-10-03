part of '../../state.dart';

// F14 team members
mixin _TeamMembersData {

  /// The Hostelzy team (team mode). F24 item 29: from the server
  /// (`team_members`); the sample founder row only in the demo.
  final List<({String name, String phone, String role, bool joined})> teamMembers = [if (AppState.samples) (name: 'Founder', phone: '9000000100', role: 'Everything', joined: true)];
  String tmName = '', tmPhone = '', tmRole = 'Visits';
}

extension TeamMembersActions on AppState {

  Future<void> addTeamMember() async {
    final ph = tmPhone.replaceAll(RegExp(r'\D'), '');
    if (tmName.trim().isEmpty || ph.length != 10) return toastMsg('Add a name and a 10-digit number.');
    final name = tmName.trim();
    // F24 item 29: saved on the server; Active once they open team tools.
    if (data.remote && account != null) {
      try {
        await data.inviteTeamMember(name, ph, tmRole);
      } catch (e) {
        debugPrint('team invite: $e');
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
      update(() {
        tmName = '';
        tmPhone = '';
      });
      await loadTeam();
      return toastMsg('Saved. $name shows as Active after the founder adds their Google account and they open team tools.');
    }
    update(() {
      teamMembers.add((name: name, phone: ph, role: tmRole, joined: false));
      tmName = '';
      tmPhone = '';
    });
    toastMsg('Invite pending. This demo has no server, so nothing is sent.');
  }
}
