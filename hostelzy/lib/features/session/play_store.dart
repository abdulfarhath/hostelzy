part of '../../state.dart';

// F15 Play Store
mixin _PlayStoreData {

  /// Notification choices (sent once notifications are live, F13).
  /// F24 item 22: kept on the profile too; the server's pushes honour them.
  final Map<String, bool> notif = {'hold': true, 'rent': true, 'beds': false};

  /// F24 item 22: the last areas picked in Where? (newest first, at most 5),
  /// for "New free beds" alerts.
  final List<String> searchedAreas = [];
}
