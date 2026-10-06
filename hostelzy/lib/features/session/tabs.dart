part of '../../state.dart';

// F26 #15–#17: the resident's "Find a bed" (the tenant app inside the resident
// app) and #16: the red dot on Holds when a hold result came in.
mixin _TabsData {
  /// F26 #17: a resident is browsing the tenant app (Explore · Map ·
  /// Saved & Holds · My stay · Me). Their stay doesn't change.
  bool inFindBed = false;

  /// F26 #17: the Saved & Holds tab's segment: saved | holds.
  String shSeg = 'saved';

  /// F26 #16: each hold's status the last time the user saw it (on Holds or
  /// the hold's own page). Kept on this phone only; no server change.
  final Map<String, String> holdSeen = {};
}

/// F26 #16: hold results the user is told about with a dot: kept or
/// declined. A declined hold is 'released' with the owner's `declined` mark
/// (F26 #9); the tenant's own release or an expiry gets no dot.
const _holdResults = {'confirmed', 'held', 'declined'};

/// What [holdSeen] keeps for a hold: its status, or 'declined'.
String _seenKey(Hold h) => h.declined ? 'declined' : h.status;

extension TabsActions on AppState {
  /// The tab a role starts on; inside Find a bed it is Explore.
  String get homeTab => role == 'resident' && inFindBed ? 'explore' : homeOf[role]!;

  /// F26 #17: Find a bed switches the resident to the tenant screens.
  void openFindBed() => update(() {
    inFindBed = true;
    screen = 'explore';
    hist = [];
    sheet = null;
  });

  /// F26 #17: My stay in the Find a bed bar goes back to the resident app.
  void leaveFindBed() => update(() {
    inFindBed = false;
    screen = 'rStay';
    hist = [];
    sheet = null;
  });

  /// F26 #16: a hold the user saw before changed to kept or declined since.
  bool get holdsDot => holds.any((h) {
    final seen = holdSeen[h.id];
    final k = _seenKey(h);
    return seen != null && seen != k && _holdResults.contains(k) && !releasing.contains(h.id);
  });

  /// Called while Holds or a hold's page is on screen. Notifies only when
  /// something changed, so it is safe after every frame.
  void markHoldResultsSeen() {
    final now = {for (final h in holds) h.id: _seenKey(h)};
    if (now.length == holdSeen.length && now.entries.every((e) => holdSeen[e.key] == e.value)) return;
    holdSeen
      ..clear()
      ..addAll(now);
    update(() {});
  }
}
