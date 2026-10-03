part of '../../state.dart';

// F07 Fair Play
mixin _FairPlayData {

  List<FairCase> cases = seedCases();

  /// F24 #18: the photo the owner adds to their reply (sent with it).
  Uint8List? fpPhoto;

  /// The owner accepted the Fair Play rules (by code) when signing up.
  bool fairAccepted = false;
  String fpReply = '';

  /// F21: the owner ticks "I agree" (no fake SMS code).
  bool fpAgree = false;

  /// The full rules opened from "Full rules ›" before agreeing.
  bool fpFull = false;

  /// Owner mistakes fixed within 48 hours; 3 in 6 months = 1 warning.
  int ownerFixes = 0;

  /// Tenant's answer to "Did you join?" and the report form.
  String? joinAnswer, reportWhy;

  /// F24 item 14: ended holds this tenant already answered on the server.
  final Set<String> joinAnswered = {};
  bool _joinLoaded = false;
  String reportNote = '';

  /// Founder admin: queue tab and the open case.
  String adminTab = 'waiting';
  String? adminCase;
}

extension FairPlayActions on AppState {

  FairCase? get ownerCase => cases.where((c) => c.hid == ownHid && c.status != 'closed').firstOrNull;

  /// Strike 3: the listing is hidden from tenants (on the server too).
  bool removed(String hid) => (strikes[hid] ?? 0) >= 3;

  /// The owner's one line for their strikes: "Warning", "Deals hidden until
  /// 2 Nov", "Deals back since 2 Nov", "Removed from Hostelzy".
  String strikeLine(String hid) {
    final n = strikes[hid] ?? 0;
    final back = dealsBackOn(hid);
    if (n == 2 && back != null) return DateTime.now().isBefore(back) ? 'Deals hidden until ${dayMon(back)}' : 'Deals back since ${dayMon(back)}';
    final w = strikeWords(n);
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }

  /// The last strike came from three fixes in 6 months (not from a case).
  bool strikeFromFixes(String hid) => standing[hid]?.why == 'fixes';

  /// The tenant has a live hold or booking here, so the owner's number shows.
  bool heldAt(String hid) => holds.any((h) => h.hid == hid && h.status != 'released');

  void acceptFairPlay() {
    if (!fpAgree) return toastMsg('Tick “I agree” first.');
    // F24 #18: kept on the server once per account (sent again on the next
    // sign-in if this one doesn't get through).
    if (onServer) data.acceptFairPlay().catchError((Object e) => debugPrint('accept fair play: $e'));
    update(() {
      fairAccepted = true;
      fpAgree = false;
      fpFull = false;
      screen = 'oToday';
      hist = [];
    });
    toastMsg('Fair Play rules accepted. Welcome to Hostelzy.');
  }

  /// F24 #18: the owner agreed on another phone (or before reinstalling):
  /// don't ask again. Agreed here but not on the server yet: send it.
  Future<void> loadFairAccepted() async {
    if (!onServer) return;
    final got = await data.fairAccepted();
    if (got == null) return;
    if (got && !fairAccepted) {
      update(() {
        fairAccepted = true;
        if (screen == 'oRules' && !fpFull) {
          screen = 'oToday';
          hist = [];
        }
      });
    } else if (!got && fairAccepted) {
      data.acceptFairPlay().catchError((Object e) => debugPrint('accept fair play: $e'));
    }
  }

  /// "Change Teja to Via Hostelzy": fixed within 48 h, case closed, no strike.
  void fixCase(FairCase c) {
    final key = c.key;
    if (onServer && key != null) {
      // S5: the server checks the 48 hours, switches the resident and closes it.
      // F24 #18: the third fix in 6 months is a warning (the server counts).
      final had = strikes[c.hid] ?? 0;
      data.fixCase(key).then((_) async {
        await refreshLive();
        await refreshListings();
        final now = strikes[c.hid] ?? 0;
        toastMsg(now > had
            ? '${c.resident} now shows as came from the app. Case closed. That’s 3 fixes in 6 months, which counts as one warning (strike $now of 3).'
            : '${c.resident} now shows as came from the app. Case closed, no strike.');
      }, onError: (Object e) {
        final m = '$e';
        toastMsg(m.contains('48 hours are over')
            ? 'The 48 hours are over. Reply instead and the Hostelzy team decides.'
            : m.contains('closed')
            ? 'This case is already closed.'
            : 'Couldn’t save it. Check your internet and try again.');
      });
      return;
    }
    update(() {
      residents = [for (final r in residents) r.name == c.resident ? Resident(name: r.name, bed: r.bed, amt: r.amt, status: r.status, note: r.note, phone: r.phone, via: 'hz', since: r.since, ref: r.ref, confirmed: r.confirmed, advance: r.advance, joinAt: r.joinAt) : r];
      c.status = 'closed';
      c.result = 'Fixed by the owner within 48 h · no strike';
      ownerFixes++;
      if (ownerFixes >= 3) {
        strikes[c.hid] = (strikes[c.hid] ?? 0) + 1;
        ownerFixes = 0;
      }
    });
    toastMsg('${c.resident} now shows as came from the app. Case closed, no strike.');
  }

  void replyCase(FairCase c) {
    if (fpReply.trim().isEmpty) return toastMsg('Write what happened, or fix the resident.');
    final key = c.key;
    final photo = fpPhoto;
    final saved = photo == null ? 'Reply saved. The Hostelzy team reads it before deciding.' : 'Reply and photo saved. The Hostelzy team reads them before deciding.';
    if (onServer && key != null) {
      final text = fpReply.trim();
      final uid = account?.uid;
      _write(() async {
        // F24 #18: the photo goes up first (private), then onto the case.
        if (photo != null && uid != null) await data.addCasePhoto(key, await data.uploadCasePhoto(c.hid, uid, photo));
        await data.replyCase(key, text, reopen: c.status == 'waiting');
      }).then((ok) {
        if (!ok) return;
        update(() {
          fpReply = '';
          fpPhoto = null;
        });
        toastMsg(saved);
      });
      return;
    }
    update(() {
      c.ownerReply = fpReply.trim();
      if (photo != null) c.ownerPhoto = 'local';
      c.status = 'decide';
      fpReply = '';
      fpPhoto = null;
    });
    toastMsg(saved);
  }

  /// F24 #18: "Add a photo to your reply" (compressed like complaint photos).
  Future<void> pickCasePhoto() async {
    final raw = await picker.pick();
    if (raw == null) return;
    final jpg = prepPhoto(raw, 'free');
    if (jpg == null) return toastMsg('That photo didn’t open. Try another one.');
    update(() => fpPhoto = jpg);
  }

  /// Opens a case photo (a short-lived private link on the server).
  Future<void> openCasePhoto(String? path) async {
    if (path == null) return;
    if (path == 'sample' || path == 'local') return toastMsg('Photos open from the server in the real app. This is sample data.');
    final url = await data.casePhotoUrl(path);
    if (url == null) return toastMsg('Couldn’t open the photo. Check your internet and try again.');
    openLink(Uri.parse(url), 'the photo');
  }

  /// Founder decision: close, ask for more, or a strike (1 warning, 2 deals
  /// hidden for 30 days, 3 removed). On the server `give_strike` adds it.
  void decideCase(FairCase c, String how) {
    final key = c.key;
    if (onServer && key != null) {
      final n = (strikes[c.hid] ?? 0) + 1;
      final decision = switch (how) { 'close' => 'Closed · no issue', 'more' => null, _ => strikeDecision(n) };
      _write(() => data.decideCase(key, c.hid, how, decision)).then((ok) {
        if (!ok) return;
        if (how == 'strike') update(() => strikes[c.hid] = n);
        toastMsg(how == 'close' ? '${c.id} closed. No strike.' : how == 'more' ? 'Asked the owner for more. 48 hours again.' : '${c.id}: $decision.');
      });
      return;
    }
    update(() {
      switch (how) {
        case 'close':
          c.status = 'closed';
          c.result = 'Closed · no issue';
        case 'more':
          c.status = 'waiting';
          c.result = null;
        default:
          final n = (strikes[c.hid] ?? 0) + 1;
          strikes[c.hid] = n;
          c.status = 'closed';
          c.result = strikeDecision(n);
      }
    });
    toastMsg(how == 'close' ? '${c.id} closed. No strike.' : how == 'more' ? 'Asked the owner for more. 48 hours again.' : '${c.id}: ${c.result}.');
  }

  /// "Did you join?": yes | not_yet | deciding (F07, F24 item 14). On the
  /// server it is a Fair Play signal only the Hostelzy team reads.
  void answerJoined(String a) {
    final h = endedHold;
    if (onServer && h != null) {
      data.answerJoined(h.id, a).then((_) {
        update(() {
          joinAnswered.add(h.id);
          joinAnswer = a;
          sheet = null;
        });
        toastMsg(a == 'yes' ? 'Thanks. Only the Hostelzy team sees your answer. Your ₹100 Member reward unlocks once the owner confirms your stay.' : 'Thanks. Only the Hostelzy team sees your answer.');
      }, onError: (Object e) {
        debugPrint('did you join: $e');
        toastMsg('Couldn’t save your answer. Check your internet and try again.');
      });
      return;
    }
    update(() {
      joinAnswer = a;
      sheet = null;
      // S6: on Supabase, Member comes from a confirmed stay (the server).
      if (a == 'yes' && !onServer) becomeMember('Anjani Residency');
    });
    toastMsg(a != 'yes'
        ? 'Thanks.'
        : onServer
        ? 'Thanks. Your ₹100 Member reward unlocks once your owner confirms your stay.'
        : 'Thanks. Your ₹100 Member reward is unlocked for your next stay.');
  }

  /// Should Holds ask "Did you join?" (a real ended hold not answered yet;
  /// the demo build may ask about a sample one).
  bool get askJoined {
    if (joinAnswer != null) return false;
    final h = endedHold;
    if (h == null) return AppState.samples;
    return !joinAnswered.contains(h.id);
  }

  /// F24 item 14: which ended holds were answered already (once per session).
  Future<void> loadJoinAnswers() async {
    if (_joinLoaded || !data.remote) return;
    _joinLoaded = true;
    try {
      final got = await data.joinAnswers();
      if (got.isNotEmpty) update(() => joinAnswered.addAll(got));
    } catch (e) {
      // Before its SQL runs (FOUNDER-TODO 4zy3) there's nothing to load.
      debugPrint('join answers: $e');
    }
  }

  void sendReport() {
    final why = reportWhy;
    if (why == null) return toastMsg('Pick what happened.');
    if (onServer) {
      // S5: a private report to the Hostelzy team about the hostel of the ended hold.
      final hid = endedHold?.hid;
      if (hid == null) return toastMsg('Reports are about a hostel you held a bed at. Hold one first.');
      final note = reportNote.trim();
      _write(() => data.sendReport(hid, why, note)).then((ok) {
        if (!ok) return;
        update(() {
          reportWhy = null;
          reportNote = '';
          sheet = null;
        });
        toastMsg('Report sent to the Hostelzy team. The owner never sees your name.');
      });
      return;
    }
    update(() {
      cases = [FairCase(openedAt: DateTime.now().millisecondsSinceEpoch, id: 'FP-0${143 + cases.length - 6}', hid: 'anjani', title: 'Tenant report', signal: 'Tenant report: ${why[0].toLowerCase()}${why.substring(1)}', status: 'new', tenantNote: reportNote.trim().isEmpty ? null : reportNote.trim()), ...cases];
      reportWhy = null;
      reportNote = '';
      sheet = null;
    });
    toastMsg('Report saved for the Hostelzy team. The owner never sees your name.');
  }
}
