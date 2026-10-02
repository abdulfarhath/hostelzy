import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';

/// App state and actions. Mirrors the prototype's single component state so
/// the tenant, resident and owner roles share the same data.
class AppState extends ChangeNotifier {
  AppState({String? start, String? role, String? theme, String? mode, this.sheet, String? moveTab, String? moreTab, String? foodView, String? mView, String? plan, String? auth}) {
    resetSampleData();
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
    _planDemo(plan);
    signedIn = auth != 'out';
    _prep();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // F17: a free hold really ends at 0:00.
      if (_expireHolds(DateTime.now().millisecondsSinceEpoch)) return;
      if (const ['hold', 'holds', 'oToday', 'otp'].contains(screen)) {
        now = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
    });
  }

  static const screens = ['welcome', 'phone', 'otp', 'role', 'explore', 'map', 'holds', 'me', 'detail', 'picker', 'hold', 'rHome', 'rPay', 'food', 'help', 'move', 'rConfirm', 'rReview', 'rExit', 'reviews', 'oToday', 'oBeds', 'oRent', 'oMore', 'oInvite', 'oReviews', 'oRank', 'oRules', 'oCase', 'oStrike', 'aCases', 'rewards', 'moveIn', 'oPlan', 'oInvoice', 'oPayStatus', 'aPay', 'compare', 'oLayout', 'aLayout', 'aAdd', 'aTrack', 'oTeam'];
  static const tabScreens = ['explore', 'map', 'holds', 'me', 'rHome', 'rPay', 'food', 'help', 'oToday', 'oBeds', 'oRent', 'oMore'];

  Timer? _ticker, _toastTimer;

  late String screen, role, theme, mode, moveTab, moreTab, foodView, mView;
  String? sheet;
  List<String> hist = [];
  String phone = '', otp = '';

  /// When the last code was sent (ms); "Resend in 0:30" counts down from it.
  int codeSentAt = 0;
  int get resendLeft => (30 - (now - codeSentAt) / 1000).ceil().clamp(0, 30);

  /// The SMS itself needs the backend (F13): MSG91 / Firebase.
  void sendCode() => update(() {
    now = DateTime.now().millisecondsSinceEpoch;
    codeSentAt = now;
    otp = '';
    if (screen != 'otp') {
      hist = [...hist, screen];
      screen = 'otp';
    }
  });
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

  // ------------------------------------------------------------ F10 owner plan

  /// The signed-in owner's next invoice (Anjani), then everyone else's.
  late final Invoice invoice = Invoice(ref: 'HZ-INV-1024', hid: ownHid, beds: planBeds, amt: planTiers[planTierOf(planBeds)].price, due: firstInvoiceDue);
  late final List<Invoice> invoices = [invoice, ...seedInvoices()];

  /// UTR being typed on "I've paid".
  String utrDraft = '';

  /// Founder payments filter: check | late | paid | trial | all.
  String payTab = 'check';

  int get planBeds => rooms[ownHid]!.fold(0, (a, r) => a + r.beds.length);
  int get planPrice => planTiers[planTierOf(planBeds)].price;
  int get planCredit => ownerCredits.where((c) => c.hid == ownHid).fold(0, (a, c) => a + c.amt);

  /// What the owner pays on [invoice]: the plan less any Member-reward credits.
  int get invoiceAmt => (planPrice - planCredit).clamp(0, planPrice);
  int get trialLeft => invoice.status == 'upcoming' ? trialEnd.difference(appToday).inDays : 0;
  bool dealsPaused(String hid) => invoices.any((i) => i.hid == hid && i.pausesDeals);

  /// Demo states for the overview and `?plan=`: late5 | late15 | checking | paid | missing.
  void _planDemo(String? plan) {
    if (plan == null) return;
    if (plan.startsWith('late')) {
      invoice
        ..status = 'due'
        ..late = int.parse(plan.substring(4));
    } else {
      invoice
        ..status = plan
        ..utr = '402188341297'
        ..sent = '${dayName(appToday)}, 10:14 am';
      if (plan == 'paid') invoice.checked = dayMon(appToday);
    }
  }

  void openInvoice() {
    go(const ['checking', 'paid'].contains(invoice.status) ? 'oPayStatus' : 'oInvoice');
  }

  /// "I've paid": the UTR sheet, prefilled when fixing a UTR we couldn't find.
  void openUtr() => update(() {
    utrDraft = invoice.status == 'missing' ? invoice.utr ?? '' : '';
    sheet = 'utr';
  });

  void sendUtr() {
    if (utrDraft.length != 12) return toastMsg('The UTR has 12 digits.');
    update(() {
      invoice
        ..amt = invoiceAmt
        ..utr = utrDraft
        ..sent = '${dayName(appToday)}, 10:14 am'
        ..status = 'checking';
      sheet = null;
      screen = 'oPayStatus';
    });
    toastMsg('UTR sent. We’ll check it against our bank record.');
  }

  /// Founder admin: the UTR is in the bank record.
  void markPaid(Invoice i) {
    update(() {
      i
        ..status = 'paid'
        ..late = 0
        ..checked = dayMon(appToday);
    });
    toastMsg('${i.ref} marked paid. ${hostelById(i.hid).owner} gets a receipt.');
  }

  /// Founder admin: no payment with that UTR reached the bank.
  void notReceived(Invoice i) {
    update(() => i.status = 'missing');
    toastMsg('${hostelById(i.hid).owner} is asked to check the UTR.');
  }

  void sendReminder(Invoice i) => whatsapp(ownerPhones[i.hid] ?? '', 'Hi ${hostelById(i.hid).owner}, a reminder from Hostelzy: invoice ${i.ref} (${fmt(i.amt)}) is ${i.late} days late. Pay by UPI from the app → Manage → Your plan.');

  // ------------------------------------------------------------ F12 room layouts

  /// Layouts drawn by the Hostelzy team, by hostel and room number.
  late final Map<String, Map<int, RoomLayout>> layouts = seedLayouts(rooms);

  /// Room tab layer toggles: off by default (DECISIONS 2026-10-02).
  bool showFan = false, showAc = false;

  /// Layouts are only for people who verified their phone by OTP.
  bool signedIn = true;

  /// The two beds on Compare beds (letters in [room]).
  String cmpA = '', cmpB = '';

  /// The bed whose facts show in the Room tab (a letter), when not picked.
  String? roomBed;

  /// Owner (Beds → room layout) and the Hostelzy admin editor: which room.
  int lRoom = 204;

  /// Request-a-change sheet draft.
  String lReqText = '', lReqLen = '', lReqWid = '';
  Set<String> lReqAdded = {};

  /// Admin editor: the selected AC unit's properties.
  final Map<String, String> acProps = {'Wall': 'Right', 'Blows': 'Left', 'Reach': '8 ft', 'Status': 'Working'};

  RoomLayout? layoutOf(String hid, int n) => layouts[hid]?[n];

  /// What tenants see: the last approved version.
  RoomLayout? liveLayout(String hid, int n) {
    final l = layoutOf(hid, n);
    return l != null && l.live ? l : null;
  }

  /// Women's PGs: whole-floor plans only after a hold here.
  bool floorLocked(String hid) => hostelById(hid).gender == 'Women' && !heldAt(hid);

  /// Tapping a room in Plan opens it in Room.
  void openRoom(int n) => update(() {
    room = n;
    bed = null;
    mode = 'room';
  });

  /// A bed a tenant can hold: free, or freeing up soon.
  static bool _open(Bed b) => (b.state == 'free' || b.state == 'soon') && !b.mine;

  void openCompare() {
    final r = rooms[hid]!.firstWhere((x) => x.n == room);
    final free = r.beds.where(_open).map((b) => b.letter).toList();
    if (free.length < 2) return toastMsg('Only one free bed in this room.');
    final sel = bed != null && free.contains(bed!.split('-').last) ? bed!.split('-').last : free.first;
    cmpA = sel;
    cmpB = free.firstWhere((x) => x != sel);
    go('compare');
  }

  /// Owner marks a fan, the AC or the window Working / Not working. Broken
  /// items show honestly to tenants and raise a complaint.
  void setWorking(RoomLayout l, LItem i, bool ok) {
    if (i.working == ok) return;
    final r = rooms[l.hid]!.firstWhere((x) => x.n == l.room);
    final name = switch (i.kind) {
      'fan' => 'Fan ${i.id.substring(3)}',
      'ac' => 'AC unit',
      _ => 'Window',
    };
    update(() {
      i.working = ok;
      if (i.kind == 'ac') r.acRepair = !ok;
      if (!ok) {
        final id = complaints.fold<int>(0, (a, c) => c.id > a ? c.id : a) + 1;
        complaints = [Complaint(id: id, by: 'Layout · ${l.room}', cat: i.kind == 'ac' ? 'AC' : i.kind == 'fan' ? 'Fan' : 'Window', text: '$name in room ${l.room} marked not working.', status: 'Open', date: dayMon(appToday), note: ''), ...complaints];
      }
    });
    toastMsg(ok ? '$name working again.' : '$name marked not working. A complaint is raised.');
  }

  void approveLayout(RoomLayout l) {
    update(() {
      l
        ..pending = false
        ..live = true;
    });
    toastMsg('Room ${l.room} layout approved. Tenants see it now.');
  }

  void openLayoutRequest() => update(() {
    lReqText = '';
    lReqLen = '';
    lReqWid = '';
    lReqAdded = {};
    sheet = 'layoutReq';
  });

  void sendLayoutRequest() {
    final l = layoutOf(ownHid, lRoom)!;
    if (lReqText.trim().isEmpty && lReqAdded.isEmpty) return toastMsg('Say what’s different, or add a photo.');
    update(() {
      l.request = (text: lReqText.trim(), added: Set.of(lReqAdded), size: lReqLen.isNotEmpty && lReqWid.isNotEmpty ? '$lReqLen × $lReqWid ft' : '', at: '${dayMon(appToday)}, 7:10 pm');
      sheet = null;
    });
    toastMsg('Request saved. It reaches the Hostelzy team once the app is online (F13).');
  }

  /// Admin: send the new version to the owner for approval.
  void sendLayoutToOwner(RoomLayout l) {
    update(() {
      l
        ..version += l.pending ? 0 : 1
        ..pending = true
        ..drawn = dayMon(appToday)
        ..request = null;
    });
    toastMsg('v${l.version} sent to ${hostelById(l.hid).owner} for approval.');
  }

  // ------------------------------------------------------------ F14 onboarding

  /// Days since each owner confirmed their free beds.
  final Map<String, int> confirmed = Map.of(seedConfirmed);

  /// "Visited by Hostelzy" dates.
  final Map<String, String> visited = Map.of(seedVisited);

  /// The signed-in owner's hostels (switcher), and floors without beds.
  final List<String> ownerHostels = ['anjani'];
  final Map<String, List<String>> emptyFloors = {};

  /// Managers: they run beds, residents, enquiries, complaints and food.
  final List<({String name, String phone, bool joined})> managers = [];
  String mgrName = '', mgrPhone = '';

  /// Add hostel wizard (Hostelzy admin mode on the visit).
  HostelDraft draft = HostelDraft();
  int addStep = 1;
  String resName = '', resPhone = '', resBed = '', resPaste = '', draftOtp = '';
  bool resPasteMode = false;

  /// Onboarding tracker.
  final List<Lead> leads = seedLeads();
  int trackCl = -1;

  bool stale(String hid) => (confirmed[hid] ?? staleAfterDays) >= staleAfterDays;
  bool needsConfirm(String hid) => (confirmed[hid] ?? 0) >= confirmEveryDays;

  void confirmBeds(String hid) {
    update(() => confirmed[hid] = 0);
    toastMsg('Thanks. Tenants see your free beds as confirmed today.');
  }

  void switchHostel(String hid) => update(() {
    ownHid = hid;
    sheet = null;
    screen = 'oToday';
    hist = [];
  });

  void openAddHostel() => update(() {
    draft = HostelDraft();
    addStep = 1;
    hist = [...hist, screen];
    screen = 'aAdd';
    sheet = null;
  });

  void addManager() {
    final ph = mgrPhone.replaceAll(RegExp(r'\D'), '');
    if (mgrName.trim().isEmpty || ph.length != 10) return toastMsg('Add a name and a 10-digit number.');
    update(() {
      managers.add((name: mgrName.trim(), phone: ph, joined: false));
      mgrName = '';
      mgrPhone = '';
      sheet = null;
    });
    // No backend yet: the invite is pending until the manager signs in.
    toastMsg('Invite pending. The manager joins by signing in with this number.');
  }

  /// Residents step: "Type one" or "Paste a list" (name, phone, bed per line).
  void addDraftResident() {
    final ph = resPhone.replaceAll(RegExp(r'\D'), '');
    if (resName.trim().isEmpty || ph.length != 10 || resBed.trim().isEmpty) return toastMsg('Name, 10-digit phone and bed.');
    update(() {
      draft.residents.add((name: resName.trim(), phone: ph, bed: resBed.trim().toUpperCase()));
      resName = '';
      resPhone = '';
      resBed = '';
    });
  }

  void pasteDraftResidents() {
    var n = 0;
    update(() {
      for (final line in resPaste.split('\n')) {
        final parts = line.split(',').map((x) => x.trim()).toList();
        if (parts.length < 3) continue;
        final ph = parts[1].replaceAll(RegExp(r'\D'), '');
        if (parts[0].isEmpty || ph.length != 10) continue;
        draft.residents.add((name: parts[0], phone: ph, bed: parts[2].toUpperCase()));
        n++;
      }
      resPaste = '';
    });
    toastMsg(n == 0 ? 'One per line: name, phone, bed.' : 'Added $n residents.');
  }

  /// Go live: the draft becomes a listing tenants can see (in this app
  /// session; stored for real with the backend, F13).
  List<String> get goLiveLeft {
    final d = draft;
    return [
      if (!d.ownerVerified) 'Owner phone verified by OTP',
      if (!d.fairPlay) 'Fair Play rules accepted',
      if (d.photoCount < HostelDraft.minPhotos) 'At least ${HostelDraft.minPhotos} photos',
      if (d.missingPrices.isNotEmpty) 'Every room type priced',
      if (!d.bedsChecked) 'Bed status checked on the visit',
      if (!d.pinChecked) 'Map pin checked',
    ];
  }

  void goLive() {
    if (goLiveLeft.isNotEmpty) return toastMsg('${goLiveLeft.length} things left.');
    final d = draft;
    var id = d.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    while (hostels.any((h) => h.id == id)) {
      id = '${id}x';
    }
    final spot = areaSpot[d.area] ?? areaSpot['Madhapur']!;
    final taken = {for (final r in d.residents) r.bed};
    final rs = <Room>[];
    for (var fi = 0; fi < d.floors.length; fi++) {
      final f = d.floors[fi];
      if (f.noBeds) continue;
      for (var i = 0; i < f.rooms.length; i++) {
        final dr = f.rooms[i];
        final n = fi * 100 + i + 1;
        rs.add(
          Room(
            n: n,
            floor: fi,
            share: dr.share,
            ac: dr.ac,
            rent: d.prices[rateKey(dr.ac, dr.share)]!,
            bath: 'Attached',
            name: dr.label == '$n' ? null : dr.label,
            beds: [
              for (var k = 0; k < dr.share; k++)
                Bed(id: '${dr.label}-${'ABCD'[k]}', letter: 'ABCD'[k], room: n, floor: fi, spot: spots[dr.share]![k], state: taken.contains('${dr.label}-${'ABCD'[k]}') ? 'booked' : 'free', soon: ''),
            ],
          ),
        );
      }
    }
    final h = Hostel(
      id: id,
      name: d.name,
      gender: d.gender,
      area: d.area,
      from: rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b),
      rating: 0,
      reviews: 0,
      food: d.food != 'No food',
      ac: rs.any((r) => r.ac),
      instant: false,
      owner: d.ownerName,
      reply: 0,
      mins: spot.mins,
      x: spot.x,
      y: spot.y,
      tags: [if (d.food != 'No food') '${d.food} a day', ...d.amenities.take(3)],
      terms: Terms(advance: d.advance, maintenance: d.kept, noticeDays: d.notice, dueOnJoining: d.dueOnJoining),
      onlyAc: rs.every((r) => r.ac),
    );
    update(() {
      hostels.add(h);
      ownerPhones[id] = d.ownerPhone;
      rooms[id] = rs;
      rates[id] = {...seedRates(h), ...d.prices};
      stats[id] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
      emptyFloors[id] = [for (final f in d.floors) if (f.noBeds) f.name];
      visited[id] = '${dayMon(appToday)} ${appToday.year}';
      confirmed[id] = 0;
      ownerHostels.add(id);
      leads.add(Lead(d.name, d.area, 'Trial ends ${dayMon(appToday.add(const Duration(days: 30)))}', 5, hid: id));
      screen = 'aTrack';
      hist = [];
    });
    toastMsg('${d.name} is live. The 30-day trial starts today.');
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
    // F14: beds not confirmed for 7 days rank lower.
    return rankWeights.entries.fold<double>(0, (a, e) => a + e.value * f[e.key]!) - (strikes[hid] ?? 0) * .1 - (stale(hid) ? .05 : 0);
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
  /// This month's rent is paid once Srinivas confirms it (F17).
  bool get paid => myRent.status == 'paid';
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

  /// Number the WhatsApp sheet sends to (10 digits).
  String waPhone = '';
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
    if (screen == 'compare' && cmpA.isEmpty) {
      final r = rooms[hid]!.firstWhere((r) => layoutOf(hid, r.n) != null && r.beds.where(_open).length >= 2);
      final free = r.beds.where(_open).toList();
      room = r.n;
      floor = r.floor;
      cmpA = free[0].letter;
      cmpB = free[1].letter;
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

  void openWA(String to, String msg, {String phone = ''}) => update(() {
    sheet = 'wa';
    waTo = to;
    waPhone = phone;
    waMsg = msg;
    waRef = null;
  });

  /// The tenant's verified number (the demo number until they log in).
  String get myPhone => phone.length == 10 ? phone : '9000000001';

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
    waPhone = ownerPhones[hid] ?? '';
    waMsg = body;
    waRef = e.ref;
    waHid = hid;
  }

  /// Full message the tenant sends: their text plus the ref line.
  String get waFull => waRef == null ? (waMsg ?? '') : '${waMsg ?? ''}\nRef $waRef';

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
    toastMsg('Removed.');
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
    // F17: a booking is "paying" until the owner confirms the advance arrived.
    b.state = 'held';
    b.mine = true;
    final t = DateTime.now().millisecondsSinceEpoch;
    final id = 'h$t';
    final h = Hold(id: id, hid: hid, bed: b.id, room: b.room, opt: opt, start: t, status: opt == 'free' ? 'waiting' : 'paying', ref: ref, paid: opt == 'book' ? q.hzAdv : 0, perks: opt == 'book' && q.any ? lockedPerks(q, h0) : const []);
    final pay = opt == 'book' ? Payment(id: 'pay$t', kind: 'advance', hid: hid, who: 'Rahul V.', what: 'Advance for bed ${b.id}', bed: b.id, amt: q.hzAdv, note: ref!, holdId: id) : null;
    update(() {
      holds = [...holds, h];
      if (pay != null) payments = [...payments, pay];
      holdId = id;
      bed = null;
      hist = [...hist, screen];
      screen = 'hold';
      sheet = pay != null ? 'payAdv' : null;
      payId = pay?.id;
    });
    if (pay == null) toastMsg('Hold placed on this phone. Tell ${h0.owner} on WhatsApp so they keep the bed.');
  }

  void setHold(String id, String status) => update(() => holds = holds.map((h) => h.id == id ? h.withStatus(status) : h).toList());

  void copyText(String s) => Clipboard.setData(ClipboardData(text: s));

  // ------------------------------------------------------------ F17 payments

  /// Where tenants pay each owner. Sample IDs are clearly fake until the
  /// owner types theirs in Manage → Rates.
  late final Map<String, ({String id, String name})> ownerUpi = {for (final h in hostels) h.id: (id: h.id == 'anjani' ? 'sample.owner@upi' : 'sample.${h.id}@upi', name: h.owner)};

  List<Payment> payments = seedPayments();

  /// The payment a pay / UTR sheet is about, and the UTR being typed.
  String? payId;
  String payUtr = '';
  Payment? get pay => payments.where((x) => x.id == payId).firstOrNull;
  Payment? payOfHold(String holdId) => payments.where((x) => x.holdId == holdId).lastOrNull;

  /// This resident's rent for the month (Rahul, bed 204-B).
  Payment get myRent => payments.firstWhere((x) => x.id == 'rent204B');

  /// Opens the UPI app with the owner's ID, amount and note filled in.
  void payByUpi(Payment p) {
    final u = ownerUpi[p.hid]!;
    openLink(upiUri(id: u.id, name: u.name, amt: p.amt, note: p.note), 'a UPI app');
    update(() {
      payId = p.id;
      payUtr = p.utr ?? '';
      sheet = 'payUtr';
    });
  }

  void openPayUtr(Payment p) => update(() {
    payId = p.id;
    payUtr = p.utr ?? '';
    sheet = 'payUtr';
  });

  void sendPayUtr() {
    final p = pay;
    if (p == null) return;
    if (payUtr.length != 12) return toastMsg('The UTR has 12 digits.');
    final h = hostelById(p.hid);
    update(() {
      p
        ..utr = payUtr
        ..sent = '${dayName(appToday)}, ${clockTime(DateTime.now().millisecondsSinceEpoch)}'
        ..status = 'waiting';
      if (p.kind == 'rent') {
        for (final r in residents.where((r) => r.bed == p.bed)) {
          r.status = 'Waiting';
          r.note = 'UTR sent · ${h.owner} to confirm';
        }
      }
      sheet = null;
    });
    toastMsg('Saved. ${h.owner} confirms once they see the money.');
  }

  /// Owner: checked the bank. Only now is the bed Booked or the rent Paid.
  void confirmPayment(Payment p, bool received) {
    final first = p.who.split(' ').first;
    update(() {
      p.status = received ? 'paid' : 'missing';
      if (received) p.done = dayMon(appToday);
      if (p.kind == 'advance' && p.holdId != null) {
        final h = holds.where((x) => x.id == p.holdId).firstOrNull;
        if (h != null && received) {
          holds = holds.map((x) => x.id == h.id ? x.withStatus('booked') : x).toList();
          findBed(h.hid, h.bed).b?.state = 'booked';
        }
      }
      if (p.kind == 'rent') {
        for (final r in residents.where((r) => r.bed == p.bed)) {
          r.status = received ? 'Paid' : 'Due';
          r.note = received ? 'Confirmed ${dayMon(appToday)}' : 'UTR not found';
        }
      }
    });
    toastMsg(received ? 'Confirmed. $first sees it as ${p.kind == 'rent' ? 'paid' : 'booked'}.' : 'Marked not received. $first is asked to check the UTR.');
  }

  /// Tenant gives up on a booking whose payment didn't arrive.
  void cancelBooking(Hold h) {
    update(() {
      final b = findBed(h.hid, h.bed).b;
      if (b != null) {
        b.state = 'free';
        b.mine = false;
      }
      holds = holds.map((x) => x.id == h.id ? x.withStatus('released') : x).toList();
      payments = payments.where((x) => x.holdId != h.id).toList();
    });
    update(() => hid = h.hid);
    openPicker();
  }

  // ------------------------------------------------------------ F17 links

  /// The last link the app tried to open (WhatsApp, phone, maps, UPI).
  Uri? lastLink;

  /// Opens another app. Nothing is sent from Hostelzy itself.
  Future<void> openLink(Uri u, String app) async {
    lastLink = u;
    try {
      if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    toastMsg('Couldn’t open $app on this device.');
  }

  /// WhatsApp with the message filled in; [phone] empty lets the user pick a chat.
  void whatsapp(String phone, String text) => openLink(Uri.parse('https://wa.me/${phone.isEmpty ? '' : '91$phone'}?text=${Uri.encodeComponent(text)}'), 'WhatsApp');
  void call(String phone) => openLink(Uri.parse('tel:+91$phone'), 'the phone app');
  void directions(Hostel h) => openLink(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${posOf(h).$1},${posOf(h).$2}'), 'Maps');

  /// Holds that ran out (shown as "Hold expired").
  final Set<String> expiredHolds = {};

  bool _expireHolds(int n) {
    final out = holds.where((h) => const ['waiting', 'confirmed', 'held'].contains(h.status) && holdSecs - (n - h.start) / 1000 <= 0).toList();
    if (out.isEmpty) return false;
    now = n;
    update(() {
      for (final h in out) {
        final b = findBed(h.hid, h.bed).b;
        if (b != null && b.mine) {
          b.state = 'free';
          b.mine = false;
        }
        expiredHolds.add(h.id);
      }
      holds = holds.map((h) => out.contains(h) ? h.withStatus('released') : h).toList();
    });
    return true;
  }

  /// Test hook: run the expiry check at time [n].
  @visibleForTesting
  bool expireHoldsAt(int n) => _expireHolds(n);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
