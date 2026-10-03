part of '../../state.dart';

// F24 Wave 4a (F08): one review of each kind per stay, the 30-day review
// opens after 30 days, the author can edit it, the owner replies once, and
// anyone can report a review for abuse (the Hostelzy team decides). The
// server enforces all of it (migration 20261003060000, FOUNDER-TODO 4zr1).
mixin _ReviewRulesData {
  /// The review behind the "Report this review" sheet (`revReport`), and why.
  String? revReportFor, revReportWhy;

  /// Reviews reported from this phone (the server ignores a second report).
  final Set<String> reportedReviews = {};
}

/// Why a review breaks the rules (the team reads it in the console).
const reviewReportReasons = ['Abusive or rude words', 'Personal details like a phone number', 'Not written by a resident', 'Something else'];

extension ReviewRules on AppState {
  /// The account on this phone's reviews ('me' on sample data).
  String? get _reviewAuthor => onServer ? account?.uid : 'me';

  /// The resident's own review of their hostel; [kind] is '30-day' or 'exit'.
  Review? myReview(String kind) {
    final me = _reviewAuthor;
    if (me == null) return null;
    final hid = onServer ? myHostel : stayHostel.id;
    return reviews.where((r) => r.hid == hid && r.kind == kind && r.author == me).firstOrNull;
  }

  /// The day the 30-day review opens, or null once it is open. Sample data
  /// is always open (the sample resident moved in months ago).
  DateTime? get reviewOpensOn {
    if (!onServer) return null;
    final j = myStayRow?.joinAt;
    if (j == null) return null;
    final joined = DateTime.fromMillisecondsSinceEpoch(j);
    final opens = DateTime(joined.year, joined.month, joined.day + 30);
    final today = DateTime(appToday.year, appToday.month, appToday.day);
    return opens.isAfter(today) ? opens : null;
  }

  /// Opens the 30-day review; the resident's own review comes back to edit.
  void openReview() {
    final on = reviewOpensOn;
    if (on != null) return toastMsg('Reviews open after 30 days of your stay, on ${dayMon(on)}.');
    final r = myReview('30-day');
    update(() {
      if (r == null) return;
      rvStars = r.stars;
      rvCats = Map.of(r.cats);
      rvLayout = r.layout;
      rvText = r.text;
    });
    go('rReview');
  }

  /// Opens the exit review; the resident's own one comes back to edit.
  void openExitReview() {
    final r = myReview('exit');
    update(() {
      if (r == null) return;
      exAdv = r.advance;
      exStars = r.stars;
      exAgain = r.again;
      exText = r.text;
    });
    go('rExit');
  }

  /// A review write with the server's rules said in plain words.
  Future<bool> _reviewWrite(Future<void> Function() f) async {
    try {
      await f();
      await refreshLive();
      return true;
    } catch (e) {
      debugPrint('review: $e');
      final m = '$e';
      toastMsg(m.contains('already reviewed') || m.contains('reviews_one_per_stay')
          ? 'You already reviewed this stay. Open your review to change it.'
          : m.contains('reviews open after 30 days')
          ? 'Reviews open after 30 days of your stay.'
          : m.contains('confirmed stay')
          ? 'Only residents with a confirmed stay can review. Ask your owner to confirm your stay.'
          : m.contains('already replied')
          ? 'You already replied to this review. Each review gets one reply.'
          : m.contains('hidden by Hostelzy')
          ? 'Hostelzy hid this review, so it can’t be changed.'
          : m.contains('edit your own review')
          ? 'This is your review. Change it instead of reporting it.'
          : 'Couldn’t save it. Check your internet and try again.');
      return false;
    }
  }

  /// Sample data: a "layout is wrong" answer flags the resident's room
  /// (on the server the review does it, F13 S4).
  void _flagMyRoom(String hid, int by) {
    final l = layoutOf(hid, int.tryParse(stayRoom) ?? 204);
    if (l != null) l.disputes = math.max(0, l.disputes + by);
  }

  /// Saves the author's changes to their review [r].
  Future<void> _editReview(Review r, {required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again, required void Function() clear}) async {
    if (onServer) {
      final ok = await _reviewWrite(() => data.editReview(r.id, stars: stars, body: body, cats: cats, layout: layout, advance: advance, again: again));
      if (!ok) return;
      await refreshListings();
    } else {
      final was = r.layout == 'No';
      if (r.kind == '30-day' && was != (layout == 'No')) _flagMyRoom(r.hid, was ? -1 : 1);
    }
    update(() {
      r
        ..stars = stars
        ..text = body
        ..cats = cats
        ..layout = layout
        ..advance = advance
        ..again = again
        ..edited = true;
      clear();
    });
    back();
    toastMsg('Review updated. It shows as edited.');
  }

  /// Owner (board 6): "Report this review" opens the reasons.
  void openReviewReport(Review r) => update(() {
    revReportFor = r.id;
    revReportWhy = null;
    sheet = 'revReport';
  });

  Future<void> sendReviewReport() async {
    final id = revReportFor, why = revReportWhy;
    if (id == null) return;
    if (why == null) return toastMsg('Pick what is wrong with it.');
    if (onServer && !await _reviewWrite(() => data.reportReview(id, why))) return;
    update(() {
      reportedReviews.add(id);
      sheet = null;
      revReportFor = null;
      revReportWhy = null;
    });
    toastMsg('Sent to the Hostelzy team. They hide it if it breaks the rules.');
  }
}
