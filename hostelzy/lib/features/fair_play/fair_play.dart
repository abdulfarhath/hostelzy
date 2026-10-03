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
  String reportNote = '';

  /// Founder admin: queue tab and the open case.
  String adminTab = 'waiting';
  String? adminCase;
}

extension FairPlayActions on AppState {

  FairCase? get ownerCase => cases.where((c) => c.hid == ownHid && c.status != 'closed').firstOrNull;

  /// Strike 3: the listing is hidden from tenants.
  bool removed(String hid) => (strikes[hid] ?? 0) >= 3;

  /// The tenant has a live hold or booking here, so the owner's number shows.
  bool heldAt(String hid) => holds.any((h) => h.hid == hid && h.status != 'released');

  void acceptFairPlay() {
    if (!fpAgree) return toastMsg('Tick “I agree” first.');
    update(() {
      fairAccepted = true;
      fpAgree = false;
      fpFull = false;
      screen = 'oToday';
      hist = [];
    });
    toastMsg('Fair Play rules accepted. Welcome to Hostelzy.');
  }

  /// "Change Teja to Via Hostelzy": fixed within 48 h, case closed, no strike.
  void fixCase(FairCase c) {
    final key = c.key;
    if (onServer && key != null) {
      // S5: the server checks the 48 hours, switches the resident and closes it.
      data.fixCase(key).then((_) async {
        await refreshLive();
        toastMsg('${c.resident} now shows as came from the app. Case closed, no strike.');
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
  /// hidden 30 days, 3 removed).
  void decideCase(FairCase c, String how) {
    final key = c.key;
    if (onServer && key != null) {
      final n = (strikes[c.hid] ?? 0) + 1;
      final decision = switch (how) { 'close' => 'Closed · no issue', 'more' => null, _ => 'Strike $n · ${strikeLadder[(n - 1).clamp(0, 2)].$2.toLowerCase()}' };
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
          c.result = 'Strike $n · ${strikeLadder[(n - 1).clamp(0, 2)].$2.toLowerCase()}';
      }
    });
    toastMsg(how == 'close' ? '${c.id} closed. No strike.' : how == 'more' ? 'Asked the owner for more. 48 hours again.' : '${c.id}: ${c.result}.');
  }

  void answerJoined(String a) {
    update(() {
      joinAnswer = a;
      sheet = null;
      // S6: on Supabase, Member comes from a confirmed stay (the server).
      if (a == 'yes' && !onServer) becomeMember('Anjani Residency');
    });
    toastMsg(a != 'yes'
        ? 'Thanks. Only Hostelzy sees your answer.'
        : onServer
        ? 'Thanks. Your ₹100 Member reward unlocks once your owner confirms your stay.'
        : 'Thanks. Your ₹100 Member reward is unlocked for your next stay.');
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
