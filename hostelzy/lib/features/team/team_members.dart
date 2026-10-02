part of '../../state.dart';

// F14 team members
mixin _TeamMembersData {

  /// The Hostelzy team (team mode). Invites stay pending until real team
  /// accounts exist (F13).
  final List<({String name, String phone, String role, bool joined})> teamMembers = [(name: 'Founder', phone: '9000000100', role: 'Everything', joined: true)];
  String tmName = '', tmPhone = '', tmRole = 'Visits';
}

extension TeamMembersActions on AppState {

  void addTeamMember() {
    final ph = tmPhone.replaceAll(RegExp(r'\D'), '');
    if (tmName.trim().isEmpty || ph.length != 10) return toastMsg('Add a name and a 10-digit number.');
    update(() {
      teamMembers.add((name: tmName.trim(), phone: ph, role: tmRole, joined: false));
      tmName = '';
      tmPhone = '';
    });
    toastMsg('Invite pending. Team accounts come with the backend (F13).');
  }
}
