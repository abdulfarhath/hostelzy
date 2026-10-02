part of '../../state.dart';

// F08 reviews
mixin _ReviewsData {

  List<Review> reviews = seedReviews();
  final Map<String, ReviewStats> stats = Map.of(seedStats);

  /// Fair Play strikes per hostel (F07); each lowers the rank.
  final Map<String, int> strikes = {};

  /// Resident review forms (30-day and exit) and the owner's reply screen.
  int rvStars = 0, exStars = 0;
  Map<String, int> rvCats = {};
  String? rvLayout, exAdv, exAgain;
  String rvText = '', revF = 'new';
  String? replyFor;
  String replyText = '';

  /// F16: rate card per hostel, `rateKey(ac, share)` → monthly rent.
  final Map<String, Map<String, int>> rates = {};

  /// F16 room-type filters: Explore + search (`fR`), bed picker (`pR`).
  /// Any | AC | Non-AC
  String fR = 'Any', pR = 'Any';

  /// Owner rate card being edited (`oRates`): a copy until saved.
  Map<String, int>? rateDraft;
  Map<int, bool>? acDraft;
  int rcFloor = 2;
  String hid = 'anjani';
  int floor = 2;
  int? room;
  String? bed;
  String holdOpt = 'free';
  List<Hold> holds = [];
  String? holdId;
  late int now;
  String? toast;
  String lm = 'Hitec City', fG = 'Any', fS = 'Any', fB = 'Any';
  bool fFood = false;

  /// F21 W2: only hostels with a Hostelzy deal.
  bool fDeals = false;
  String mapSel = 'anjani';
  String payM = 'UPI';
  /// Food: today's weekday first (E1).
  /// F21: "This is correct" on Confirm stay.
  bool cAgree = false;
  int day = appToday.weekday - 1;
  String? rated;
  List<Complaint> complaints = seedComplaints();
  String cCat = 'Wi-Fi', cText = '';

  /// F21 W3: the photo for the next complaint, and photos of complaints
  /// raised on this phone (demo builds; on the server they're in storage).
  Uint8List? cPhoto;
  final Map<int, Uint8List> complaintPhotosLocal = {};
  int? cPhotoView;
  late String vDate = leaveDates(hostels[0].terms).first;
  String vReason = 'New job';
  bool notice = false;
  String? swapBed;
  bool swapSent = false;
  late List<HoldRequest> reqs;
  late List<Enquiry> enquiries;
  int _nextRef = 4822;

  /// HZ code of the enquiry behind the open WhatsApp sheet, if any.
  String? waRef, waHid;

  /// Enquiry open in the owner's enquiry sheet.
  String? enqRef;
  List<Resident> residents = seedResidents();

  // F06: residents list, add-resident sheet, invite sign-ups, confirm stay.
  String resF = 'All';
  List<Signup> signups = List.of(seedSignups);
  String rName = '', rPhone = '', rJoin = 'Today', rFee = '', rAdv = '';
  String? rBed;
  int rPickBack = 3;

  /// Bed of the resident on the confirm-your-stay screen.
  String? cBed;
  String rentF = 'All';
  List<DayMenu> menu = List.of(seedMenu);
  int mDay = 3;
  List<Rule> rules = seedRules(hostels[0].terms);
  String addName = '', addPhone = '', addDate = 'Today';
  String? addBed;
  String? obed;
  final Map<String, bool> saved = {};
  String? waTo, waMsg;

  /// Number the WhatsApp sheet sends to (10 digits).
  String waPhone = '';
  String obView = 'plan';
  int obFloor = 2;

  /// The owner's hostel (one per owner until F14).
  String ownHid = 'anjani';

  /// Bumped whenever a screen's scroll position should reset.
  int scrollEpoch = 0;
}

extension ReviewsActions on AppState {

  /// Ranking factors (0–1) for a hostel.
  Map<String, double> factors(String hid) {
    final h = hostelById(hid);
    final f = seedFactors[hid] ?? const {'fresh': .5, 'complaints': .5, 'listing': .5};
    return {
      'reviews': (h.rating / 5 - (h.reviews < 20 ? .1 : 0)).clamp(0, 1).toDouble(),
      'reply': (1 - h.reply / 120).clamp(0, 1).toDouble(),
      'fresh': f['fresh']!,
      'complaints': f['complaints']!,
      'listing': f['listing']!,
    };
  }

  double rankScore(String hid) {
    final f = factors(hid);
    // F14: beds not confirmed for 7 days rank lower.
    return rankWeights.entries.fold<double>(0, (a, e) => a + e.value * f[e.key]!) - (strikes[hid] ?? 0) * .1 - (stale(hid) ? .05 : 0);
  }

  /// All hostels, best rank first.
  List<String> get rankOrder => (browsable.map((h) => h.id).toList()..sort((a, b) => rankScore(b).compareTo(rankScore(a))));
  int rankOf(String hid) => rankOrder.indexOf(hid) + 1;

  /// What tenants see as the reason for the rank: the two strongest factors.
  String rankReasons(String hid) {
    final f = factors(hid);
    final keys = ['reply', 'fresh', 'complaints', 'listing']..sort((a, b) => f[b]!.compareTo(f[a]!));
    final parts = [if (hostelById(hid).reviews < 20) 'few reviews yet', ...keys.take(2).map((k) => rankReason[k]!)];
    final t = parts.join(', ');
    return t[0].toUpperCase() + t.substring(1);
  }

  /// S4: on Supabase a review needs a confirmed stay (the server checks it).
  Future<bool> _postReviewLive({required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) async {
    final hid = myHostel;
    if (hid == null) {
      toastMsg('Your owner hasn’t added you yet. Reviews open once you’re a resident here.');
      return false;
    }
    final ok = await _write(() => data.postReview(hid: hid, name: meShort, kind: kind, stars: stars, body: body, cats: cats, layout: layout, advance: advance, again: again));
    if (ok) await refreshListings();
    return ok;
  }

  /// S4: hostels (and their reviews) again from the server.
  Future<void> refreshListings() async {
    try {
      final l = await data.listings();
      if (l != null) applyListings(l);
    } catch (e) {
      debugPrint('listings: $e');
    }
  }

  void postReview() {
    if (rvStars == 0) return toastMsg('Tap the stars to rate your stay.');
    if (onServer) {
      _postReviewLive(kind: 'stay', stars: rvStars, body: rvText.trim(), cats: Map.of(rvCats), layout: rvLayout).then((ok) {
        if (!ok) return;
        update(() {
          rvStars = 0;
          rvCats = {};
          rvLayout = null;
          rvText = '';
        });
        back();
        toastMsg('Review posted as $meShort · verified resident.');
      });
      return;
    }
    update(() {
      reviews = [Review(id: 'r${reviews.length + 1}', hid: 'anjani', name: meShort, stars: rvStars, text: rvText.trim(), stay: 'Staying since Mar 2026', cats: Map.of(rvCats), layout: rvLayout, fresh: true), ...reviews];
      // F12: a resident who says the layout is wrong flags it for the team.
      if (rvLayout == 'No') layoutOf('anjani', 204)?.disputes++;
      rvStars = 0;
      rvCats = {};
      rvLayout = null;
      rvText = '';
    });
    back();
    toastMsg('Review posted as $meShort · verified resident.');
  }

  /// Exit review: the advance answer feeds the "advance returned" record.
  void postExitReview() {
    final adv = exAdv;
    if (adv == null) return toastMsg('Tell us if you got your advance back.');
    if (exStars == 0) return toastMsg('Tap the stars to rate your stay.');
    if (onServer) {
      _postReviewLive(kind: 'exit', stars: exStars, advance: adv, again: exAgain).then((ok) {
        if (!ok) return;
        update(() {
          exAdv = null;
          exStars = 0;
          exAgain = null;
        });
        back();
        toastMsg(adv == 'not' ? 'Thanks. Your review is posted, and the owner sees the advance wasn’t returned.' : 'Thanks. Your review is posted.');
      });
      return;
    }
    final st = stats['anjani']!;
    update(() {
      stats['anjani'] = ReviewStats(st.cats, st.advFull + (adv == 'all' ? 1 : 0), st.advLeft + 1, st.layoutPct);
      reviews = [Review(id: 'r${reviews.length + 1}', hid: 'anjani', name: meShort, stars: exStars, text: '', stay: 'Leaving $vDate', kind: 'exit', advance: adv, again: exAgain, fresh: true), ...reviews];
      exAdv = null;
      exStars = 0;
      exAgain = null;
    });
    back();
    toastMsg(adv == 'not' ? 'Thanks. We remind the owner and check in a week.' : 'Thanks. Your review is posted.');
  }

  void postReply(Review r) {
    if (replyText.trim().isEmpty) return toastMsg('Write a reply first.');
    if (onServer) {
      final text = replyText.trim();
      _write(() => data.replyReview(r.id, text)).then((ok) async {
        if (!ok) return;
        await refreshListings();
        update(() {
          replyFor = null;
          replyText = '';
        });
        toastMsg('Reply posted under ${r.name.split(' ')[0]}’s review.');
      });
      return;
    }
    update(() {
      r.reply = replyText.trim();
      r.replyWhen = 'replied today';
      r.fresh = false;
      replyFor = null;
      replyText = '';
    });
    toastMsg('Reply posted under ${r.name.split(' ')[0]}’s review.');
  }

  /// Strike 2+ hides the hostel's deals (F07).
  /// Deals are hidden at 2 Fair Play strikes (F07) and paused while the
  /// owner's plan is 15+ days late (F10).
  Deals dealsOf(String hid) => (strikes[hid] ?? 0) >= 2 || dealsPaused(hid) ? const Deals() : deals[hid] ?? const Deals();

  /// Walk-in vs Hostelzy quote for a room type ([ac], [share]) at [hid].
  DealQuote quote(String hid, bool ac, int share) {
    final h = hostelById(hid);
    final d = dealsOf(hid);
    final fee = rates[hid]![rateKey(ac, share)] ?? h.from;
    return DealQuote(h.terms, fee, d.covers(ac) ? d.on : const {});
  }

  /// Best 6-month saving at a hostel across its room types (Explore sort and ribbon).
  DealQuote? bestQuote(String hid, {String f = 'Any'}) {
    DealQuote? best;
    for (final r in rooms[hid]!) {
      if (!AppState.fits(r, f)) continue;
      final q = quote(hid, r.ac, r.share);
      if (!q.any) continue;
      if (best == null || q.save6 > best.save6 || (q.save6 == best.save6 && q.upfront > best.upfront)) best = q;
    }
    return best;
  }

  void toggleDeal(String id) {
    final cur = dealDraft ??= Set.of(dealsOf(ownHid).on);
    if (cur.contains(id)) {
      update(() => cur.remove(id));
    } else if (cur.length >= maxDeals) {
      toastMsg('Pick up to $maxDeals. Remove one first.');
    } else {
      update(() => cur.add(id));
    }
  }

  void publishDeals() {
    final on = Set.of(dealDraft ?? dealsOf(ownHid).on);
    final d = Deals(on: on, target: dealTarget, confirmed: dayMon(appToday)), hid = ownHid;
    final msg = on.isEmpty ? 'Deals removed. Tenants see walk-in prices.' : 'Deals published. Tenants who book through Hostelzy get them.';
    if (onServer) {
      _write(() => data.saveDeals(hid, d)).then((ok) {
        if (!ok) return;
        update(() => deals[hid] = d);
        toastMsg(msg);
      });
      return;
    }
    update(() => deals[hid] = d);
    toastMsg(msg);
  }

  /// S3: Manage → Rules. On Supabase they are saved for the hostel's page.
  void saveRules() {
    final hid = ownHid, list = List.of(rules);
    const msg = 'Rules saved. Residents and new tenants see them now.';
    if (onServer) {
      _write(() => data.saveRules(hid, list)).then((ok) {
        if (!ok) return;
        update(() => hostelRules[hid] = list);
        toastMsg(msg);
      });
      return;
    }
    toastMsg(msg);
  }
  /// This month's rent is paid once Srinivas confirms it (F17).
  bool get paid => myRentPay?.status == 'paid';
}
