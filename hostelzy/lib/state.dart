import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'data.dart';

/// App state and actions. Mirrors the prototype's single component state so
/// the tenant, resident and owner roles share the same data.
class AppState extends ChangeNotifier {
  AppState({String? start, String? role, String? theme, String? mode, this.sheet, String? moveTab, String? moreTab, String? foodView, String? mView}) {
    for (var i = 0; i < hostels.length; i++) {
      rooms[hostels[i].id] = mkRooms(hostels[i], i);
      rates[hostels[i].id] = seedRates(hostels[i]);
    }
    fixAnjani(rooms['anjani']!);
    final n = DateTime.now().millisecondsSinceEpoch;
    now = n;
    screen = start ?? 'welcome';
    this.role = role ?? 'tenant';
    this.theme = theme ?? 'light';
    this.mode = mode ?? 'plan';
    this.moveTab = moveTab ?? 'vacate';
    this.moreTab = moreTab ?? 'residents';
    this.foodView = foodView ?? 'day';
    this.mView = mView ?? 'day';
    reqs = seedRequests(n);
    enquiries = seedEnquiries(n);
    _prep();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (const ['hold', 'holds', 'oToday'].contains(screen)) {
        now = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
    });
  }

  static const screens = ['welcome', 'phone', 'otp', 'role', 'explore', 'map', 'holds', 'me', 'detail', 'picker', 'hold', 'rHome', 'rPay', 'food', 'help', 'move', 'rConfirm', 'rReview', 'rExit', 'reviews', 'oToday', 'oBeds', 'oRent', 'oMore', 'oInvite', 'oReviews', 'oRank', 'oRules', 'oCase', 'oStrike', 'aCases', 'rewards', 'moveIn'];
  static const tabScreens = ['explore', 'map', 'holds', 'me', 'rHome', 'rPay', 'food', 'help', 'oToday', 'oBeds', 'oRent', 'oMore'];

  Timer? _ticker, _toastTimer;

  late String screen, role, theme, mode, moveTab, moreTab, foodView, mView;
  String? sheet;
  List<String> hist = [];
  String phone = '', otp = '';
  final Map<String, List<Room>> rooms = {};

  /// F03: each hostel's published deals.
  final Map<String, Deals> deals = Map.of(seedDeals);

  /// Owner's deal picker draft (Manage → Deals) and the tenant's deal-table room type.
  Set<String>? dealDraft;
  String dealTarget = 'all';
  bool? dealAc;

  /// Explore sort: rec (Recommended, F08) | near | price | deals (F03).
  String sortBy = 'rec';
  bool get bestDeals => sortBy == 'deals';

  // ------------------------------------------------------------ F07 Fair Play

  List<FairCase> cases = seedCases();

  /// The owner accepted the Fair Play rules (by code) when signing up.
  bool fairAccepted = false;
  String fpOtp = '', fpReply = '';

  /// Owner mistakes fixed within 48 hours; 3 in 6 months = 1 warning.
  int ownerFixes = 0;

  /// Tenant's answer to "Did you join?" and the report form.
  String? joinAnswer, reportWhy;
  String reportNote = '';

  /// Founder admin: queue tab and the open case.
  String adminTab = 'waiting';
  String? adminCase;

  FairCase? get ownerCase => cases.where((c) => c.hid == ownHid && c.status != 'closed').firstOrNull;

  /// Strike 3: the listing is hidden from tenants.
  bool removed(String hid) => (strikes[hid] ?? 0) >= 3;

  /// The tenant has a live hold or booking here, so the owner's number shows.
  bool heldAt(String hid) => holds.any((h) => h.hid == hid && h.status != 'released');

  void acceptFairPlay() {
    if (fpOtp.length != 6) return toastMsg('Enter the 6-digit code.');
    update(() {
      fairAccepted = true;
      fpOtp = '';
      screen = 'oToday';
      hist = [];
    });
    toastMsg('Fair Play rules accepted. Welcome to Hostelzy.');
  }

  /// "Change Teja to Via Hostelzy": fixed within 48 h, case closed, no strike.
  void fixCase(FairCase c) {
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
    toastMsg('${c.resident} is now Via Hostelzy. Case closed, no strike.');
  }

  void replyCase(FairCase c) {
    if (fpReply.trim().isEmpty) return toastMsg('Write what happened, or fix the resident.');
    update(() {
      c.ownerReply = fpReply.trim();
      c.status = 'decide';
      fpReply = '';
    });
    toastMsg('Reply sent. The founder reads it before deciding.');
  }

  /// Founder decision: close, ask for more, or a strike (1 warning, 2 deals
  /// hidden 30 days, 3 removed).
  void decideCase(FairCase c, String how) {
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
      if (a == 'yes') becomeMember('Anjani Residency');
    });
    toastMsg(a == 'yes' ? 'Thanks. Your ₹100 Member reward is unlocked for your next stay.' : 'Thanks. Only Hostelzy sees your answer.');
  }

  void sendReport() {
    final why = reportWhy;
    if (why == null) return toastMsg('Pick what happened.');
    update(() {
      cases = [FairCase(id: 'FP-0${143 + cases.length - 6}', hid: 'anjani', title: 'Tenant report', signal: 'Tenant report: ${why[0].toLowerCase()}${why.substring(1)}', status: 'new', tenantNote: reportNote.trim().isEmpty ? null : reportNote.trim()), ...cases];
      reportWhy = null;
      reportNote = '';
      sheet = null;
    });
    toastMsg('Report sent. The owner never sees your name.');
  }

  // ------------------------------------------------------------ F09 rewards

  /// none | member | trusted. Member after a first stay through Hostelzy.
  String level = 'none';
  String memberSince = '';
  int monthsOnTime = 0;

  /// The ₹100 Member reward has been used at a move-in.
  bool rewardUsed = false;

  /// ₹100 credits for owners' next Hostelzy invoices (F10).
  final List<({String hid, String what, int amt})> ownerCredits = [];
  int friendsJoined = 1;

  /// Hold request whose Trusted tenant badge is open.
  String? trustedReq;

  bool get isMember => level != 'none';
  int get holdSecs => isMember ? memberHoldSecs : freeHoldSecs;
  String get referralCode => 'RAHUL-$referralReward';

  void becomeMember(String hostelName) {
    if (isMember) return;
    level = 'member';
    memberSince = 'Since ${dayMon(appToday.add(const Duration(days: 1)))} · first stay via Hostelzy at $hostelName';
  }

  /// Move-in for a booked or confirmed hold: the Member reward comes off the
  /// first month and is credited to the owner (no cash from Hostelzy).
  void moveIn(Hold hold) {
    final h = hostelById(hold.hid);
    final useReward = isMember && !rewardUsed;
    update(() {
      if (useReward) {
        rewardUsed = true;
        ownerCredits.add((hid: hold.hid, what: 'Member reward · ${hold.bed}', amt: memberReward));
      }
      becomeMember(h.name);
      role = 'resident';
      screen = 'rHome';
      hist = [];
    });
    toastMsg(useReward ? 'Welcome home. ${fmt(memberReward)} Member reward used.' : 'Welcome home. This is your stay now.');
  }

  // ------------------------------------------------------------ F08 reviews

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
    return rankWeights.entries.fold<double>(0, (a, e) => a + e.value * f[e.key]!) - (strikes[hid] ?? 0) * .1;
  }

  /// All hostels, best rank first.
  List<String> get rankOrder => (hostels.map((h) => h.id).toList()..sort((a, b) => rankScore(b).compareTo(rankScore(a))));
  int rankOf(String hid) => rankOrder.indexOf(hid) + 1;

  /// What tenants see as the reason for the rank: the two strongest factors.
  String rankReasons(String hid) {
    final f = factors(hid);
    final keys = ['reply', 'fresh', 'complaints', 'listing']..sort((a, b) => f[b]!.compareTo(f[a]!));
    final parts = [if (hostelById(hid).reviews < 20) 'few reviews yet', ...keys.take(2).map((k) => rankReason[k]!)];
    final t = parts.join(', ');
    return t[0].toUpperCase() + t.substring(1);
  }

  void postReview() {
    if (rvStars == 0) return toastMsg('Tap the stars to rate your stay.');
    update(() {
      reviews = [Review(id: 'r${reviews.length + 1}', hid: 'anjani', name: 'Rahul V.', stars: rvStars, text: rvText.trim(), stay: 'Staying since Mar 2026', cats: Map.of(rvCats), layout: rvLayout, fresh: true), ...reviews];
      rvStars = 0;
      rvCats = {};
      rvLayout = null;
      rvText = '';
    });
    back();
    toastMsg('Review posted as Rahul V. · verified resident.');
  }

  /// Exit review: the advance answer feeds the "advance returned" record.
  void postExitReview() {
    final adv = exAdv;
    if (adv == null) return toastMsg('Tell us if you got your advance back.');
    if (exStars == 0) return toastMsg('Tap the stars to rate your stay.');
    final st = stats['anjani']!;
    update(() {
      stats['anjani'] = ReviewStats(st.cats, st.advFull + (adv == 'all' ? 1 : 0), st.advLeft + 1, st.layoutPct);
      reviews = [Review(id: 'r${reviews.length + 1}', hid: 'anjani', name: 'Rahul V.', stars: exStars, text: '', stay: 'Leaving $vDate', kind: 'exit', advance: adv, again: exAgain, fresh: true), ...reviews];
      exAdv = null;
      exStars = 0;
      exAgain = null;
    });
    back();
    toastMsg(adv == 'not' ? 'Thanks. We remind the owner and check in a week.' : 'Thanks. Your review is posted.');
  }

  void postReply(Review r) {
    if (replyText.trim().isEmpty) return toastMsg('Write a reply first.');
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
  Deals dealsOf(String hid) => (strikes[hid] ?? 0) >= 2 ? const Deals() : deals[hid] ?? const Deals();

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
      if (!fits(r, f)) continue;
      final q = quote(hid, r.ac, r.share);
      if (!q.any) continue;
      if (best == null || q.save6 > best.save6 || (q.save6 == best.save6 && q.upfront > best.upfront)) best = q;
    }
    return best;
  }

  void openDeals() => update(() {
    final d = dealsOf('anjani');
    dealDraft = Set.of(d.on);
    dealTarget = d.target;
    screen = 'oMore';
    hist = [];
    sheet = null;
    moreTab = 'deals';
  });

  void toggleDeal(String id) {
    final cur = dealDraft ??= Set.of(dealsOf('anjani').on);
    if (cur.contains(id)) {
      update(() => cur.remove(id));
    } else if (cur.length >= maxDeals) {
      toastMsg('Pick up to $maxDeals. Remove one first.');
    } else {
      update(() => cur.add(id));
    }
  }

  void publishDeals() {
    final on = Set.of(dealDraft ?? dealsOf('anjani').on);
    update(() => deals['anjani'] = Deals(on: on, target: dealTarget, confirmed: dayMon(appToday)));
    toastMsg(on.isEmpty ? 'Deals removed. Tenants see walk-in prices.' : 'Deals published. Tenants who book through Hostelzy get them.');
  }

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
  String mapSel = 'anjani';
  bool paid = false;
  String payM = 'UPI';
  int day = 3;
  String? rated;
  List<Complaint> complaints = seedComplaints();
  String cCat = 'WiFi', cText = '';
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
  String cOtp = '';

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
  String obView = 'plan';
  int obFloor = 2;

  /// The owner's hostel (one per owner until F14).
  String ownHid = 'anjani';

  /// Bumped whenever a screen's scroll position should reset.
  int scrollEpoch = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void update(void Function() fn) {
    final key = '$screen|$mode|$moreTab';
    fn();
    if (key != '$screen|$mode|$moreTab') scrollEpoch++;
    notifyListeners();
  }

  void _prep() {
    if (screen == 'oMore' && moreTab == 'rates' && rateDraft == null) {
      rateDraft = Map.of(rates['anjani']!);
      acDraft = {for (final r in rooms['anjani']!) r.n: r.ac};
    }
    if (screen == 'picker' || sheet == 'hold') {
      final rs = rooms[hid]!;
      final r = rs.where((r) => r.floor == 2 && r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs[0];
      floor = r.floor;
      room = r.n;
      if (sheet == 'hold') bed = r.beds.where((b) => b.state == 'free').firstOrNull?.id;
    }
    if (screen == 'hold' && holds.isEmpty) {
      final b = rooms['anjani']!.firstWhere((r) => r.n == 202).beds[0];
      b.state = 'held';
      b.mine = true;
      holds = [Hold(id: 'h0', hid: 'anjani', bed: b.id, room: 202, opt: 'free', start: DateTime.now().millisecondsSinceEpoch - 17 * 60000, status: 'waiting')];
      holdId = 'h0';
    }
    if (sheet == 'bed' && obed == null) obed = '204-B';
    if (sheet == 'wa' && waTo == null) _enquire('anjani', 'Hi Srinivas, I found Anjani Residency on Hostelzy. Can I come and see the rooms this evening?', from: 'Hostel page · Ask on WhatsApp');
    if (sheet == 'enq' && enqRef == null) enqRef = 'HZ-4821';
    if (sheet == 'trusted' && trustedReq == null) trustedReq = 'k1';
    if (screen == 'rConfirm') {
      cBed = residents.where((r) => !r.confirmed).firstOrNull?.bed;
      cOtp = '';
    }
    if (sheet == 'addR' && rBed == null) {
      rBed = unassignedBeds.firstOrNull;
      final r = rBed != null ? findBed('anjani', rBed).r : null;
      rFee = r != null ? '${r.rent}' : '';
      rAdv = '${hostels[0].terms.advance}';
    }
  }

  void toastMsg(String m) {
    _toastTimer?.cancel();
    update(() => toast = m);
    _toastTimer = Timer(const Duration(milliseconds: 2600), () => update(() => toast = null));
  }

  void go(String s) => update(() {
    hist = [...hist, screen];
    screen = s;
    sheet = null;
  });

  void tab(String s) => update(() {
    screen = s;
    hist = [];
    sheet = null;
  });

  void back() => update(() {
    final h = List.of(hist);
    final prev = h.isNotEmpty ? h.removeLast() : homeOf[role]!;
    screen = prev;
    hist = h;
    sheet = null;
  });

  void jump(String s, String r) => update(() {
    screen = s;
    role = r;
    hist = [];
    sheet = null;
    toast = null;
    _prep();
  });

  void openWA(String to, String msg) => update(() {
    sheet = 'wa';
    waTo = to;
    waMsg = msg;
    waRef = null;
  });

  /// The tenant's verified number (the demo number until they log in).
  String get myPhone => phone.length == 10 ? phone : '9848012345';

  /// F05 tenant → owner hand-off. Records the enquiry on Hostelzy first (the
  /// owner is told from here, not by the WhatsApp text), then opens the
  /// prefilled message ending with the HZ code and its link. One enquiry per
  /// tenant + hostel + bed: tapping again reuses the code.
  void enquire(String hid, String body, {String? bed, required String from}) => update(() => _enquire(hid, body, bed: bed, from: from));

  /// Records (or reuses) the tenant's enquiry for this hostel + bed.
  Enquiry _record(String hid, String body, {String? bed, required String from}) {
    final me = myPhone;
    var e = enquiries.where((x) => x.hid == hid && x.bed == bed && x.phone == me).firstOrNull;
    if (e == null) {
      e = Enquiry(ref: 'HZ-${_nextRef++}', name: 'Rahul Varma', phone: me, hid: hid, bed: bed, at: DateTime.now().millisecondsSinceEpoch, from: from, msg: body.replaceFirst(RegExp(r'^Hi [^,]*, '), ''));
      enquiries = [e, ...enquiries];
    }
    return e;
  }

  void _enquire(String hid, String body, {String? bed, required String from}) {
    final e = _record(hid, body, bed: bed, from: from);
    sheet = 'wa';
    waTo = hostelById(hid).owner;
    waMsg = body;
    waRef = e.ref;
    waHid = hid;
  }

  /// Full message the tenant sends: their text plus the ref line.
  String get waFull => waRef == null ? (waMsg ?? '') : '${waMsg ?? ''}\nRef $waRef · hostelzy.in/r/$waRef';

  void markContacted(String ref) => update(() => enquiries = enquiries.map((e) => e.ref == ref ? e.withContacted() : e).toList());

  // ------------------------------------------------------------ F06

  /// Taken beds at Anjani with nobody added for them.
  List<String> get unassignedBeds => [
    for (final r in rooms['anjani']!)
      for (final b in r.beds)
        if (b.state == 'booked' && !residents.any((x) => x.bed == b.id)) b.id,
  ];

  /// Join time in ms for the add-resident sheet's "Joined on" choice.
  int get rJoinAt {
    final days = switch (rJoin) {
      'Today' => 0,
      'Yesterday' => 1,
      _ => rPickBack,
    };
    return now - days * 86400000;
  }

  String get rJoinLabel => dayName(appToday.subtract(Duration(days: switch (rJoin) {
    'Today' => 0,
    'Yesterday' => 1,
    _ => rPickBack,
  })));

  /// Joined via Hostelzy: this phone enquired about, held or booked a bed at
  /// Anjani on Hostelzy within [matchWindowDays] before joining.
  ({String ref, String what, int at})? matchFor(String phone, int joinAt) {
    if (phone.length != 10) return null;
    final from = joinAt - matchWindowDays * 86400000;
    bool inWin(int t) => t >= from && t <= joinAt + 86400000;
    final e = enquiries.where((e) => e.hid == 'anjani' && e.phone == phone && inWin(e.at)).firstOrNull;
    if (e != null) return (ref: e.ref, what: 'asked about your hostel', at: e.at);
    if (phone == myPhone) {
      final h = holds.where((h) => h.hid == 'anjani' && h.status != 'released' && inWin(h.start)).firstOrNull;
      if (h != null) return (ref: 'bed ${h.bed}', what: h.opt == 'book' ? 'booked a bed' : 'held a bed', at: h.start);
    }
    return null;
  }

  Resident _newResident(String name, String phone, String bed, int amt, int adv, int joinAt, {required bool confirmed}) {
    final m = matchFor(phone, joinAt);
    final b = findBed('anjani', bed).b;
    if (b != null) b.state = 'booked';
    final joined = dayMon(DateTime.fromMillisecondsSinceEpoch(joinAt));
    return Resident(name: name, bed: bed, amt: amt, status: 'Paid', note: 'Paid at move-in', phone: phone, via: m != null ? 'hz' : 'direct', since: confirmed ? 'Joined $joined' : 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: confirmed, advance: adv, joinAt: joinAt);
  }

  void openAddResident() => update(() {
    final free = unassignedBeds;
    rName = '';
    rPhone = '';
    rJoin = 'Today';
    rBed = free.isNotEmpty ? free.first : null;
    final r = rBed != null ? findBed('anjani', rBed).r : null;
    rFee = r != null ? '${r.rent}' : '';
    rAdv = '${hostels[0].terms.advance}';
    sheet = 'addR';
  });

  void pickResidentBed(String id) => update(() {
    rBed = id;
    final r = findBed('anjani', id).r;
    if (r != null) rFee = '${r.rent}';
  });

  /// "Add and send code": the resident is listed as Waiting OTP until they
  /// confirm with the WhatsApp code.
  void addResident() {
    final name = rName.trim();
    if (name.isEmpty || rPhone.length != 10 || rBed == null) return toastMsg('Add a name, a 10-digit number and a bed.');
    final res = _newResident(name, rPhone, rBed!, int.tryParse(rFee) ?? 0, int.tryParse(rAdv) ?? 0, rJoinAt, confirmed: false);
    update(() {
      residents = [res, ...residents];
      sheet = null;
      resF = 'All';
    });
    toastMsg('Code sent to ${name.split(' ')[0]} on WhatsApp.');
  }

  /// Invite QR sign-ups have verified their phone already; approving counts them.
  void approveSignup(Signup g) {
    final r = findBed('anjani', g.bed).r;
    final res = _newResident(g.name, g.phone, g.bed, r?.rent ?? 0, hostels[0].terms.advance, now, confirmed: true);
    update(() {
      signups = signups.where((x) => x.id != g.id).toList();
      residents = [res, ...residents];
    });
    toastMsg('${g.name.split(' ')[0]} is now a resident of bed ${g.bed}.');
  }

  void rejectSignup(Signup g) {
    update(() => signups = signups.where((x) => x.id != g.id).toList());
    toastMsg('Removed. ${g.name.split(' ')[0]} has been told.');
  }

  /// The resident the confirm screen is for (the newest one waiting).
  Resident? get toConfirm => residents.where((r) => r.bed == cBed).firstOrNull ?? residents.where((r) => !r.confirmed).firstOrNull;

  void confirmStay() {
    final r = toConfirm;
    if (r == null) return;
    if (cOtp.length != 6) return toastMsg('Enter the 6-digit code.');
    update(() {
      cBed = r.bed;
      r.confirmed = true;
      r.since = 'Joined ${dayMon(r.joinAt != null ? DateTime.fromMillisecondsSinceEpoch(r.joinAt!) : appToday)}';
      cOtp = '';
    });
  }

  void openEnquiry(String ref) => update(() {
    enqRef = ref;
    sheet = 'enq';
  });

  /// F16: does room [r] match room-type filter [f] (Any | AC | Non-AC)?
  static bool fits(Room r, String f) => f == 'Any' || (f == 'AC') == r.ac;

  /// F16: cheapest rent and free beds for one room type at a hostel, or
  /// null when the hostel has no rooms of that type.
  ({int from, int free})? typeSummary(String hid, bool ac) {
    final rs = rooms[hid]!.where((r) => r.ac == ac).toList();
    if (rs.isEmpty) return null;
    return (from: rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b), free: rs.fold(0, (a, r) => a + r.beds.where((b) => b.state == 'free' && !b.mine).length));
  }

  /// Bed picker room-type filter: keep the open room if it fits, else jump
  /// to the first fitting room (with a free bed) on this floor, then any floor.
  void pickRoomType(String f) => update(() {
    pR = f;
    final rs = rooms[hid]!;
    final cur = rs.where((r) => r.n == room).firstOrNull;
    if (cur != null && fits(cur, f)) return;
    final fit = rs.where((r) => fits(r, f));
    final r = fit.where((r) => r.floor == floor && r.beds.any((b) => b.state == 'free')).firstOrNull ?? fit.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? fit.firstOrNull;
    if (r != null) {
      room = r.n;
      floor = r.floor;
    }
    bed = null;
  });

  /// Owner opens "Rooms and rent" with a draft copy of the rate card.
  void openRates() {
    rateDraft = Map.of(rates['anjani']!);
    acDraft = {for (final r in rooms['anjani']!) r.n: r.ac};
    rcFloor = 2;
    // Manage → Rates (DECISIONS 2026-10-02).
    screen = 'oMore';
    hist = [];
    sheet = null;
    moreTab = 'rates';
    update(() {});
  }

  void setRoomAc(Room r, bool ac) {
    if (ac && rateDraft![rateKey(true, r.share)] == null) return toastMsg('Add a ${r.share} sharing AC price first.');
    if (!ac && rateDraft![rateKey(false, r.share)] == null) return toastMsg('Add a ${r.share} sharing non-AC price first.');
    update(() => acDraft![r.n] = ac);
  }

  /// "Not offered · + Add": starts from the other type's price (± ₹1,200).
  void addRate(bool ac, int share) => update(() {
    final other = rateDraft![rateKey(!ac, share)] ?? rateDraft!.values.reduce((a, b) => a < b ? a : b);
    rateDraft![rateKey(ac, share)] = other + (ac ? 1200 : -1200);
  });

  void saveRates() {
    final rs = rooms['anjani']!;
    final newAc = rs.where((r) => acDraft![r.n]! && !r.ac).length;
    update(() {
      rates['anjani'] = Map.of(rateDraft!);
      for (final r in rs) {
        r.ac = acDraft![r.n]!;
      }
      applyRates('anjani');
    });
    toastMsg(newAc > 0 ? 'Saved. The Hostelzy team adds the AC unit to the layout within 48 hours.' : 'Rate card saved. Tenants see the new prices now.');
  }

  /// Rewrites every room's rent from the hostel's rate card.
  void applyRates(String hid) {
    final rc = rates[hid]!;
    for (final r in rooms[hid]!) {
      final v = rc[rateKey(r.ac, r.share)];
      if (v != null) r.rent = v;
    }
  }

  ({int f, int t}) freeOf(String id) {
    var f = 0, t = 0;
    for (final r in rooms[id]!) {
      for (final b in r.beds) {
        t++;
        if (b.state == 'free' && !b.mine) f++;
      }
    }
    return (f: f, t: t);
  }

  ({Bed? b, Room? r}) findBed(String hid, String? id) {
    for (final r in rooms[hid]!) {
      for (final b in r.beds) {
        if (b.id == id) return (b: b, r: r);
      }
    }
    return (b: null, r: null);
  }

  void openPicker() {
    final h = hostelById(hid);
    // F16: carry the Explore room filter into the picker when it applies.
    final f = h.ac && h.hasNon ? fR : 'Any';
    final rs = rooms[hid]!.where((r) => fits(r, f)).toList();
    final r = rs.where((r) => r.floor == 2 && r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs.where((r) => r.beds.any((b) => b.state == 'free')).firstOrNull ?? rs[0];
    update(() {
      pR = f;
      hist = [...hist, screen];
      screen = 'picker';
      sheet = null;
      floor = r.floor;
      room = r.n;
      bed = null;
    });
  }

  void pickBed(Bed b) {
    if ((b.state != 'free' && b.state != 'soon') || b.mine) {
      toastMsg(b.state == 'held' ? 'Someone is holding this bed right now.' : 'This bed is taken.');
      return;
    }
    update(() {
      bed = bed == b.id ? null : b.id;
      room = b.room;
      floor = b.floor;
    });
  }

  /// F04: the HZ code a booking of the selected bed will get (the tenant's
  /// enquiry code for this hostel and bed, if they already have one).
  String get peekRef => enquiries.where((x) => x.hid == hid && x.bed == bed && x.phone == myPhone).firstOrNull?.ref ?? 'HZ-$_nextRef';

  /// Perks locked into a booking, as shown on the locked-deal card.
  List<String> lockedPerks(DealQuote q, Hostel h) => [
    if (q.hzFee < q.fee) '${fmt(q.hzFee)} monthly',
    if (q.hzExit < q.exit) '${fmt(q.hzExit)} exit only',
    if (q.firstOffNow > 0) '${fmt(firstOff)} off first month',
    if (q.hzAdv < q.adv) '${fmt(q.hzAdv)} advance',
    if (q.join > 0) 'No joining fee',
    if (q.laundry) 'Free laundry weekly',
    '${h.terms.noticeDays} days notice',
  ];

  /// [opt]: `free` (1-hour hold) or `book` (advance paid to the owner, deal
  /// locked, HZ code recorded like an enquiry so F05/F06 see it).
  void placeHold([String? how]) {
    final b = findBed(hid, bed).b;
    if (b == null) return;
    final opt = how ?? holdOpt;
    final r = findBed(hid, bed).r!;
    final h0 = hostelById(hid);
    final q = quote(hid, r.ac, r.share);
    String? ref;
    if (opt == 'book') {
      ref = _record(hid, 'Booked bed ${b.id} with the advance.', bed: b.id, from: 'Book · Pay advance').ref;
    }
    b.state = opt == 'book' ? 'booked' : 'held';
    b.mine = true;
    final t = DateTime.now().millisecondsSinceEpoch;
    final id = 'h$t';
    final h = Hold(id: id, hid: hid, bed: b.id, room: b.room, opt: opt, start: t, status: opt == 'free' ? 'waiting' : 'booked', ref: ref, paid: opt == 'book' ? q.hzAdv : 0, perks: opt == 'book' && q.any ? lockedPerks(q, h0) : const []);
    update(() {
      holds = [...holds, h];
      holdId = id;
      sheet = null;
      bed = null;
      hist = [...hist, screen];
      screen = 'hold';
    });
    toastMsg(opt == 'free' ? 'Hold placed. ${h0.owner} has been told on WhatsApp.' : 'Paid ${fmt(q.hzAdv)} to ${h0.owner}. Your deal is locked: $ref.');
  }

  void setHold(String id, String status) => update(() => holds = holds.map((h) => h.id == id ? h.withStatus(status) : h).toList());

  void copyText(String s) => Clipboard.setData(ClipboardData(text: s));
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
