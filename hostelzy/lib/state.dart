import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';
import 'data.dart';
import 'poster.dart';
import 'push.dart';
import 'sign_in.dart';
import 'store.dart';
import 'locate.dart';
import 'backend.dart' show HostelData, Listings, RemoteSettings, SampleData;

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
    // F18: the Play Store build starts with nobody else's data: no sample
    // residents, hold requests, enquiries, sign-ups, cases, complaints or
    // payments. Sample hostels for browsing stay until real ones are live (F13).
    if (!samples) {
      reqs = [];
      enquiries = [];
      residents = [];
      signups = [];
      cases = [];
      complaints = [];
      payments = [];
    }
    _planDemo(plan);
    // F15: old builds must update; maintenance from the backend (F13).
    if (appBuild < minSupportedBuild || maintenanceUntil.isNotEmpty) {
      gateKind = appBuild < minSupportedBuild ? 'update' : 'maintenance';
      screen = 'gate';
    }
    // F18: nobody is signed in on a fresh start; restore() brings a login back.
    signedIn = auth != 'out' && start != null && !const ['welcome', 'login', 'phone', 'otp', 'role'].contains(start);
    _prep();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // F17: a free hold really ends at 0:00.
      if (_expireHolds(DateTime.now().millisecondsSinceEpoch)) return;
      if (_expireWalkIns(DateTime.now().millisecondsSinceEpoch)) return;
      if (const ['hold', 'holds', 'oToday', 'otp'].contains(screen)) {
        now = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
    });
  }

  static const screens = ['welcome', 'login', 'phone', 'roleGate', 'oCreate', 'oPublished', 'saved', 'otp', 'role', 'explore', 'map', 'holds', 'me', 'detail', 'picker', 'hold', 'rHome', 'rPay', 'food', 'help', 'move', 'rConfirm', 'rReview', 'rExit', 'reviews', 'oToday', 'oBeds', 'oRent', 'oMore', 'oInvite', 'oReviews', 'oRank', 'oRules', 'oCase', 'oStrike', 'aCases', 'rewards', 'moveIn', 'oPlan', 'oInvoice', 'oPayStatus', 'aPay', 'compare', 'oLayout', 'aLayout', 'aAdd', 'aTrack', 'oTeam', 'settings', 'delAcc', 'delOtp', 'delDone', 'perm', 'gate', 'aHome', 'oLayouts', 'oRooms', 'aTeam'];
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
  static final seedCaseCount = seedCases().length;

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
    toastMsg('Reply saved. The Hostelzy team reads it before deciding.');
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
      cases = [FairCase(openedAt: DateTime.now().millisecondsSinceEpoch, id: 'FP-0${143 + cases.length - 6}', hid: 'anjani', title: 'Tenant report', signal: 'Tenant report: ${why[0].toLowerCase()}${why.substring(1)}', status: 'new', tenantNote: reportNote.trim().isEmpty ? null : reportNote.trim()), ...cases];
      reportWhy = null;
      reportNote = '';
      sheet = null;
    });
    toastMsg('Report saved for the Hostelzy team. The owner never sees your name.');
  }

  // ------------------------------------------------------------ F09 rewards

  /// Member after a first stay through Hostelzy.
  bool member = false;
  String memberSince = '';

  /// From the stay record (sample until the backend keeps it): months stayed
  /// in Hostelzy hostels, months the rent was late, owner complaints.
  int monthsOnTime = 0, lateRentMonths = 0, ownerComplaints = 0;

  /// none | member | trusted. Trusted tenant is earned, not given: 6 months in
  /// Hostelzy hostels, rent always on time, no complaints from the owner (F09).
  String get level => !member
      ? 'none'
      : monthsOnTime >= trustedMonths && lateRentMonths == 0 && ownerComplaints == 0
      ? 'trusted'
      : 'member';

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
    member = true;
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
  /// When the owner's plan started (go-live day); the trial and invoices follow it.
  late DateTime planStart = appToday;
  DateTime get trialEnd => planStart.add(const Duration(days: trialDays));
  late final Invoice invoice = Invoice(ref: 'HZ-INV-1024', hid: ownHid, beds: planBeds, amt: planTiers[planTierOf(planBeds)].price, due: trialEnd.add(const Duration(days: 1)));
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
    toastMsg('UTR saved. Hostelzy checks it against the bank record.');
  }

  /// Founder admin: the UTR is in the bank record.
  void markPaid(Invoice i) {
    update(() {
      i
        ..status = 'paid'
        ..late = 0
        ..checked = dayMon(appToday);
    });
    toastMsg('${i.ref} marked paid.');
  }

  /// Founder admin: no payment with that UTR reached the bank.
  void notReceived(Invoice i) {
    update(() => i.status = 'missing');
    toastMsg('Marked not received. ${hostelById(i.hid).owner} sees it on their plan screen.');
  }

  void sendReminder(Invoice i) => whatsapp(ownerPhones[i.hid] ?? '', 'Hi ${hostelById(i.hid).owner}, a reminder from Hostelzy: invoice ${i.ref} (${fmt(i.amt)}) is ${i.late} days late. Pay by UPI from the app → Manage → Your plan.');

  // ------------------------------------------------------------ F12 room layouts

  /// Layouts drawn by the Hostelzy team, by hostel and room number.
  late final Map<String, Map<int, RoomLayout>> layouts = seedLayouts(rooms);

  /// Room tab layer toggles: off by default (DECISIONS 2026-10-02).
  bool showFan = false, showAc = false;

  /// Layouts are only for people who signed in (Google, F13).
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
    return l != null && l.live ? l.forTenants : null;
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
      // Working / not working shows to tenants right away, also on the live copy.
      for (final x in l.published?.items ?? const <LItem>[]) {
        if (x.id == i.id) x.working = ok;
      }
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
        ..live = true
        ..published = null;
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
    final l = layoutOf(ownHid, lRoom);
    if (l == null) return toastMsg('This room has no layout yet.');
    if (lReqText.trim().isEmpty && lReqAdded.isEmpty) return toastMsg('Say what’s different, or add a photo.');
    update(() {
      l.request = (text: lReqText.trim(), added: Set.of(lReqAdded), size: lReqLen.isNotEmpty && lReqWid.isNotEmpty ? '$lReqLen × $lReqWid ft' : '', at: '${dayMon(appToday)}, 7:10 pm');
      sheet = null;
    });
    toastMsg('Request saved. It reaches the Hostelzy team once the app is online (F13).');
  }

  // ------------------------------------------------------------ team mode

  /// Hostelzy team tools are unlocked on this phone (temporary passcode
  /// until F13 adds real admin accounts).
  bool teamUnlocked = false;
  String teamCode = '';

  void openTeam() {
    if (teamUnlocked) return go('aHome');
    update(() {
      teamCode = '';
      sheet = 'team';
    });
  }

  /// G1 stopgap until real admin accounts: 5 wrong tries lock it for 15 min.
  int _teamFails = 0, _teamLockedUntil = 0;

  void unlockTeam() {
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t < _teamLockedUntil) return toastMsg('Too many wrong tries. Try again in ${((_teamLockedUntil - t) / 60000).ceil()} min.');
    if (teamCode != teamPasscode) {
      _teamFails++;
      if (_teamFails >= 5) {
        _teamFails = 0;
        _teamLockedUntil = t + 15 * 60000;
        return toastMsg('Too many wrong tries. Team mode is locked for 15 minutes.');
      }
      return toastMsg('Wrong passcode. ${5 - _teamFails} tries left.');
    }
    _teamFails = 0;
    update(() {
      teamUnlocked = true;
      sheet = null;
      hist = [...hist, screen];
      screen = 'aHome';
    });
  }

  void openLayout(int n, {bool editor = false, bool owner = false}) => update(() {
    // F18: a room without a layout gets a starting one to edit (no crash);
    // tenants don't see it until it is published.
    final r = rooms[ownHid]!.where((x) => x.n == n).firstOrNull;
    if (editor && r != null && layoutOf(ownHid, n) == null) {
      (layouts[ownHid] ??= {})[n] = mkLayout(ownHid, r, street: true)
        ..published = null
        ..live = false;
    }
    edOwner = editor && owner;
    lRoom = n;
    edSel = null;
    hist = [...hist, screen];
    screen = editor ? 'aLayout' : 'oLayout';
    sheet = null;
  });

  // ------------------------------------------------------------ F18 owner edits layouts

  /// DECISIONS 2026-10-02: owners edit and publish their own layouts; the
  /// Hostelzy team can still draw one for them. True while the owner edits.
  bool edOwner = false;

  /// Room layouts list filter: all | live | draft | none.
  String layoutsF = 'all';

  /// Create-a-layout draft (feet).
  String clLen = '', clWid = '';

  /// What tenants saw before the last publish, for "Undo publish".
  ({int room, LayoutSnap? snap, int version})? lastPublish;

  /// Owner taps a room: its layout, or "Create a layout" when it has none.
  void ownerLayout(int n) {
    if (layoutOf(ownHid, n) != null) return openLayout(n);
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    final l = mkLayout(ownHid, r, street: true);
    update(() {
      lRoom = n;
      clLen = '${l.w.round()}';
      clWid = '${l.h.round()}';
      hist = [...hist, screen];
      screen = 'oCreate';
      sheet = null;
    });
  }

  /// The nearest room of the same type that already has a layout to copy.
  Room? copySource(int n) {
    final r = rooms[ownHid]!.firstWhere((x) => x.n == n);
    return rooms[ownHid]!.where((x) => x.n != n && x.share == r.share && x.ac == r.ac && layoutOf(ownHid, x.n) != null).firstOrNull;
  }

  /// Start drawing: a rectangle of the given size, or a copy of [from].
  void createLayout({int? from}) {
    final r = rooms[ownHid]!.firstWhere((x) => x.n == lRoom);
    final len = double.tryParse(clLen) ?? 0, wid = double.tryParse(clWid) ?? 0;
    if (from == null && (len < 6 || wid < 6 || len > 60 || wid > 60)) return toastMsg('Enter the room size in feet (6 to 60).');
    final l = mkLayout(ownHid, r, street: true)
      ..published = null
      ..live = false
      ..drawn = dayMon(appToday);
    if (from != null) {
      l.restore(layoutOf(ownHid, from)!.snap());
    } else {
      l.mirrorTo(len, wid);
    }
    update(() {
      (layouts[ownHid] ??= {})[lRoom] = l;
      screen = 'oLayouts';
      hist = hist.where((x) => x != 'oCreate').toList();
    });
    openLayout(lRoom, editor: true, owner: true);
  }

  /// Owner publishes: tenants see this version now, no approval needed.
  void publishLayout(RoomLayout l) {
    final wasLive = l.live;
    update(() {
      lastPublish = (room: l.room, snap: wasLive ? (l.published ?? l.snap()) : null, version: l.version);
      if (wasLive) l.version += 1;
      l
        ..live = true
        ..pending = false
        ..published = null
        ..request = null
        ..drawn = dayMon(appToday);
      edOwner = false;
      screen = 'oPublished';
      sheet = null;
    });
  }

  /// "Undo publish · go back to vN" (or hide a first layout again).
  void undoPublish(RoomLayout l) {
    final u = lastPublish;
    if (u == null || u.room != l.room) return;
    update(() {
      if (u.snap == null) {
        l.live = false;
      } else {
        l
          ..restore(u.snap!)
          ..version = u.version;
      }
      lastPublish = null;
      screen = 'oLayout';
    });
    toastMsg(u.snap == null ? 'Unpublished. Tenants see “Layout coming soon” again.' : 'Back to v${u.version}. Tenants see it again.');
  }

  // ------------------------------------------------------------ F14 rooms after go-live

  /// Add-a-room sheet draft.
  int nrFloor = 1, nrShare = 3;
  bool nrAc = false;
  String nrLabel = '';

  /// Why a room can't be removed (a resident or a hold on it), or null.
  String? roomBlock(String hid, int n) {
    final r = rooms[hid]!.firstWhere((r) => r.n == n);
    final busy = r.beds.where((b) => b.state != 'free' || residents.any((x) => x.bed == b.id) || holds.any((h) => h.hid == hid && h.bed == b.id && h.status != 'released')).toList();
    if (busy.isEmpty) return null;
    return residents.any((x) => busy.any((b) => b.id == x.bed)) || busy.any((b) => b.state == 'booked') ? 'Has a resident' : 'Has a hold';
  }

  void openAddRoom(String hid, int floor) {
    final onFloor = rooms[hid]!.where((r) => r.floor == floor).map((r) => r.n).toList();
    var n = floor * 100 + 1;
    while (onFloor.contains(n) || rooms[hid]!.any((r) => r.label == '$n')) {
      n++;
    }
    update(() {
      nrFloor = floor;
      nrLabel = '$n';
      nrShare = 3;
      nrAc = false;
      sheet = 'addRoom';
    });
  }

  void addRoom(String hid) {
    final label = nrLabel.trim().toUpperCase();
    if (label.isEmpty) return toastMsg('Give the room a number.');
    if (rooms[hid]!.any((r) => r.label == label)) return toastMsg('Room $label already exists.');
    final rs = rooms[hid]!;
    var n = nrFloor * 100 + 1;
    while (rs.any((r) => r.n == n)) {
      n++;
    }
    final rent = rates[hid]?[rateKey(nrAc, nrShare)] ?? 0;
    if (rent == 0) return toastMsg('Add a price for $nrShare sharing ${nrAc ? 'AC' : 'Non-AC'} in Manage → Rates first.');
    update(() {
      rs.add(Room(
        n: n,
        floor: nrFloor,
        share: nrShare,
        ac: nrAc,
        rent: rent,
        bath: 'Attached',
        name: label == '$n' ? null : label,
        beds: [for (var k = 0; k < nrShare; k++) Bed(id: '$label-${'ABCD'[k]}', letter: 'ABCD'[k], room: n, floor: nrFloor, spot: spots[nrShare]![k], state: 'free', soon: '')],
      ));
      rs.sort((a, b) => a.floor != b.floor ? a.floor - b.floor : a.n - b.n);
      sheet = null;
    });
    toastMsg('Room $label added with $nrShare free beds. Hostelzy draws its layout on the next visit.');
  }

  void removeRoom(String hid, int n) {
    final why = roomBlock(hid, n);
    final r = rooms[hid]!.firstWhere((r) => r.n == n);
    if (why != null) return toastMsg('Room ${r.label} can’t be removed: ${why.toLowerCase()}.');
    update(() {
      rooms[hid]!.removeWhere((x) => x.n == n);
      layouts[hid]?.remove(n);
    });
    toastMsg('Room ${r.label} removed.');
  }

  /// A new floor above the top one, starting with one room.
  void addFloor(String hid) {
    final top = rooms[hid]!.fold<int>(0, (a, r) => r.floor > a ? r.floor : a);
    openAddRoom(hid, top + 1);
  }

  void removeFloor(String hid, int floor) {
    final rs = rooms[hid]!.where((r) => r.floor == floor).toList();
    final blocked = rs.where((r) => roomBlock(hid, r.n) != null).toList();
    if (blocked.isNotEmpty) return toastMsg('Floor $floor can’t be removed: room ${blocked.map((r) => r.label).join(', ')} ${blocked.length == 1 ? 'has' : 'have'} a resident or hold.');
    update(() {
      rooms[hid]!.removeWhere((r) => r.floor == floor);
      for (final r in rs) {
        layouts[hid]?.remove(r.n);
      }
    });
    toastMsg('Floor $floor removed.');
  }

  // ------------------------------------------------------------ F14 team members

  /// The Hostelzy team (team mode). Invites stay pending until real team
  /// accounts exist (F13).
  final List<({String name, String phone, String role, bool joined})> teamMembers = [(name: 'Founder', phone: '9000000100', role: 'Everything', joined: true)];
  String tmName = '', tmPhone = '', tmRole = 'Visits';

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

  // ------------------------------------------------------------ layout editor

  /// Selected thing in the editor: an item id, or `bed:A`.
  String? edSel;
  final List<LayoutSnap> _undo = [], _redo = [];
  Offset _dragStart = Offset.zero, _dragTotal = Offset.zero;
  String? _dragId;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _remember(RoomLayout l) {
    // The first edit of a live layout keeps a copy for tenants until the
    // owner approves the new version.
    if (!l.pending) l.published ??= l.snap();
    _undo.add(l.snap());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  Rect? _selRect(RoomLayout l) {
    final id = edSel;
    if (id == null) return null;
    if (id.startsWith('bed:')) return l.beds.containsKey(id.substring(4)) ? l.bedRect(id.substring(4)) : null;
    return l.items.where((i) => i.id == id).firstOrNull?.rect;
  }

  /// Move the selected thing so its top-left is [to] (feet), on the 1-ft
  /// grid and inside the room.
  void _place(RoomLayout l, Offset to) {
    final r = _selRect(l);
    if (r == null) return;
    final x = to.dx.roundToDouble().clamp(0, l.w - r.width).toDouble();
    final y = to.dy.roundToDouble().clamp(0, l.h - r.height).toDouble();
    final id = edSel!;
    if (id.startsWith('bed:')) {
      // A bunk bed moves as one: both beds share the spot.
      final b = l.bunks[id.substring(4)] ?? id.substring(4);
      l.beds[b] = Offset(x, y);
      final up = l.upperOn(b);
      if (up != null) l.beds[up] = Offset(x, y);
    } else {
      final i = l.items.firstWhere((i) => i.id == id);
      i
        ..x = x
        ..y = y;
    }
  }

  void edSelect(String id) => update(() => edSel = id);

  /// Drag from the editor map: [d] in feet since the last update.
  void edDrag(RoomLayout l, String id, Offset d) {
    if (_dragId != id) {
      _dragId = id;
      edSel = id;
      _remember(l);
      _dragStart = _selRect(l)!.topLeft;
      _dragTotal = Offset.zero;
    }
    _dragTotal += d;
    update(() => _place(l, _dragStart + _dragTotal));
  }

  /// Ends a drag (the next drag starts a new undo step).
  void edDragEnd() => _dragId = null;

  void edNudge(RoomLayout l, double dx, double dy) {
    final r = _selRect(l);
    if (r == null) return toastMsg('Tap a bed or an item first.');
    _remember(l);
    update(() => _place(l, r.topLeft + Offset(dx, dy)));
  }

  void edAdd(RoomLayout l, Room room, String kind) {
    if (kind == 'bed') {
      final missing = room.beds.map((b) => b.letter).where((x) => !l.beds.containsKey(x)).firstOrNull;
      if (missing == null) return toastMsg('All ${room.share} beds are placed. A new bed changes the sharing: the owner confirms the price first.');
      _remember(l);
      update(() {
        l.beds[missing] = Offset(((l.w - bedW) / 2).roundToDouble(), ((l.h - bedH) / 2).roundToDouble());
        edSel = 'bed:$missing';
      });
      return;
    }
    final n = l.items.where((i) => i.kind == kind).length + 1;
    var id = '$kind$n';
    while (l.items.any((i) => i.id == id)) {
      id = '${id}x';
    }
    final (w, h, x, y) = switch (kind) {
      'ac' => (.5, 1.8, l.w - .5, (l.h / 2).roundToDouble()),
      'window' => (4.0, .3, ((l.w - 4) / 2).roundToDouble(), 0.0),
      'door' => (3.0, .2, ((l.w - 3) / 2).roundToDouble(), l.h - .2),
      'wash' => (5.0, 4.0, 0.0, l.h - 4),
      'pillar' => (1.5, 1.5, ((l.w - 1.5) / 2).roundToDouble(), ((l.h - 1.5) / 2).roundToDouble()),
      _ => (1.0, 1.0, (l.w / 2).roundToDouble(), (l.h / 2).roundToDouble()),
    };
    _remember(l);
    update(() {
      l.items.add(LItem(id, kind, x, y, w, h, facing: kind == 'window' ? 'street' : null));
      edSel = id;
    });
  }

  void edDelete(RoomLayout l, Room room) {
    final id = edSel;
    if (id == null) return toastMsg('Tap a bed or an item first.');
    if (id.startsWith('bed:')) {
      final bedId = '${room.label}-${id.substring(4)}';
      if (residents.any((r) => r.bed == bedId) || findBed(l.hid, bedId).b?.state == 'booked') return toastMsg('Bed $bedId has a resident. It can’t be deleted.');
    }
    _remember(l);
    update(() {
      if (id.startsWith('bed:')) {
        final b = id.substring(4);
        l.beds.remove(b);
        l.bunks.remove(b);
        l.bunks.removeWhere((_, lower) => lower == b);
      } else {
        l.items.removeWhere((i) => i.id == id);
      }
      edSel = null;
    });
  }

  /// AC, window and door go to the next wall (top → right → bottom → left);
  /// a washroom zone or pillar turns 90°.
  void edRotate(RoomLayout l) {
    final id = edSel;
    final i = id == null ? null : l.items.where((x) => x.id == id).firstOrNull;
    if (i == null) return toastMsg('Tap an AC, window, door, washroom or pillar to turn it.');
    _remember(l);
    update(() {
      if (const ['ac', 'window', 'door'].contains(i.kind)) {
        const order = ['top', 'right', 'bottom', 'left'];
        final next = order[(order.indexOf(wallOf(i.rect, l.w, l.h) ?? 'left') + 1) % 4];
        final len = math.max(i.w, i.h), thick = math.min(i.w, i.h);
        switch (next) {
          case 'top' || 'bottom':
            i
              ..w = len
              ..h = thick
              ..x = ((l.w - len) / 2).roundToDouble()
              ..y = next == 'top' ? 0 : l.h - thick;
          default:
            i
              ..w = thick
              ..h = len
              ..y = ((l.h - len) / 2).roundToDouble()
              ..x = next == 'left' ? 0 : l.w - thick;
        }
      } else {
        final w0 = i.w;
        i
          ..w = i.h
          ..h = w0
          ..x = i.x.clamp(0, math.max(0, l.w - i.w)).toDouble()
          ..y = i.y.clamp(0, math.max(0, l.h - i.h)).toDouble();
      }
    });
  }

  /// Room size in feet (8 to 30), keeping everything inside the walls.
  void edResize(RoomLayout l, double dw, double dh) {
    final w = (l.w + dw).clamp(8, 30).toDouble(), h = (l.h + dh).clamp(8, 30).toDouble();
    if (w == l.w && h == l.h) return;
    _remember(l);
    update(() {
      final oldW = l.w, oldH = l.h;
      l
        ..w = w
        ..h = h;
      for (final i in l.items) {
        // Items on the right / bottom wall stay on it.
        if (i.x + i.w >= oldW - .5) i.x = w - i.w;
        if (i.y + i.h >= oldH - .5) i.y = h - i.h;
        i
          ..x = i.x.clamp(0, math.max(0, w - i.w)).toDouble()
          ..y = i.y.clamp(0, math.max(0, h - i.h)).toDouble();
      }
      for (final k in l.beds.keys.toList()) {
        final b = l.beds[k]!;
        l.beds[k] = Offset(b.dx.clamp(0, w - bedW).toDouble(), b.dy.clamp(0, h - bedH).toDouble());
      }
    });
  }

  void edUndo(RoomLayout l) {
    if (_undo.isEmpty) return;
    update(() {
      _redo.add(l.snap());
      l.restore(_undo.removeLast());
    });
  }

  void edRedo(RoomLayout l) {
    if (_redo.isEmpty) return;
    update(() {
      _undo.add(l.snap());
      l.restore(_redo.removeLast());
    });
  }

  /// Stack another bed on the selected one as a bunk (upper over lower), or
  /// take a bunk apart again.
  void edBunk(RoomLayout l, Room room) {
    final id = edSel;
    if (id == null || !id.startsWith('bed:')) return toastMsg('Tap a bed first.');
    final b = id.substring(4);
    final lower = l.bunks[b] ?? b;
    final upper = l.upperOn(lower);
    _remember(l);
    if (upper != null) {
      update(() {
        l.bunks.remove(upper);
        final p = l.beds[lower]!;
        l.beds[upper] = Offset(p.dx + bedW + 1 > l.w - bedW ? (p.dx - bedW - 1).clamp(0, l.w - bedW).toDouble() : p.dx + bedW + 1, p.dy);
      });
      return toastMsg('Bunk taken apart: two single beds.');
    }
    final p0 = l.bedRect(lower).center;
    final other = (l.beds.keys.where((k) => k != lower && !l.bunks.containsKey(k) && l.upperOn(k) == null).toList()..sort((a, c) => (l.bedRect(a).center - p0).distance.compareTo((l.bedRect(c).center - p0).distance))).firstOrNull;
    if (other == null) return toastMsg('No single bed left to stack.');
    update(() {
      l.bunks[other] = lower;
      l.beds[other] = l.beds[lower]!;
    });
    toastMsg('Bed ${room.label}-$other is now the upper bunk over ${room.label}-$lower.');
  }

  /// Copy this layout to the other rooms of the same type (same sharing, AC
  /// or not) as new versions for the owner to approve.
  void copyToSameRooms(RoomLayout l, Room room) {
    final same = rooms[l.hid]!.where((r) => r.n != room.n && r.share == room.share && r.ac == room.ac).toList();
    if (same.isEmpty) return toastMsg('No other ${room.share}-sharing ${room.type} rooms here.');
    update(() {
      for (final r in same) {
        final t = layouts[l.hid]?[r.n];
        if (t == null) continue;
        if (!t.pending) t.published ??= t.snap();
        t
          ..restore(l.snap())
          ..version += t.pending ? 0 : 1
          ..pending = true
          ..drawn = dayMon(appToday);
      }
    });
    toastMsg('Copied to rooms ${same.map((r) => r.label).join(', ')} as new versions for the owner to approve.');
  }

  /// Days since the owner confirmed the layouts still match the rooms.
  final Map<String, int> layoutConfirmed = Map.of(seedLayoutConfirmed);

  void confirmLayouts(String hid) {
    update(() => layoutConfirmed[hid] = 0);
    toastMsg('Thanks. Tenants see your layouts as confirmed today.');
  }

  void edMirror(RoomLayout l, {bool vertical = false}) {
    _remember(l);
    update(() => l.mirror(vertical: vertical));
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
    toastMsg('v${l.version} is waiting for ${hostelById(l.hid).owner}’s approval.');
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
    // Drafts belong to the hostel they were opened on.
    rateDraft = null;
    acDraft = null;
    dealDraft = null;
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
      if (d.floors.every((f) => f.noBeds || f.rooms.isEmpty)) 'At least one room with beds',
      if (!d.ownerVerified) 'Owner phone checked by a call',
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
      from: rs.isEmpty ? 0 : rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b),
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

  void postReview() {
    if (rvStars == 0) return toastMsg('Tap the stars to rate your stay.');
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
    final d = dealsOf(ownHid);
    dealDraft = Set.of(d.on);
    dealTarget = d.target;
    screen = 'oMore';
    hist = [];
    sheet = null;
    moreTab = 'deals';
  });

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
    update(() => deals[ownHid] = Deals(on: on, target: dealTarget, confirmed: dayMon(appToday)));
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
  /// Food: today's weekday first (E1).
  int day = appToday.weekday - 1;
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
    _persist();
  }

  // ------------------------------------------------------------ F18 on this phone

  /// Where the user's own data is kept between launches ([NoStore] in tests).
  Store store = const NoStore();
  String _saved = '';

  /// The user's own name: typed by them (prefilled from Google, editable).
  String myName = '';

  /// Display names from the user's own name; never a sample person.
  String get meName => myName.trim();
  String get meFirst => meName.isEmpty ? '' : meName.split(RegExp(r'\s+')).first;

  /// "Asha K." for reviews and payment lines.
  String get meShort {
    final w = meName.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return 'You';
    return w.length == 1 ? w.first : '${w.first} ${w.last[0]}.';
  }

  /// What is remembered on this phone. Sample data never goes in here.
  Map<String, dynamic> snapshot() => {
    'v': 1,
    'signedIn': signedIn,
    'role': role,
    'theme': theme,
    'name': myName,
    'phone': phone,
    if (account != null) 'account': {'uid': account!.uid, 'name': account!.name, 'email': account!.email},
    'saved': [for (final e in saved.entries) if (e.value) e.key],
    'holds': [
      for (final h in holds) {'id': h.id, 'hid': h.hid, 'bed': h.bed, 'room': h.room, 'opt': h.opt, 'start': h.start, 'status': h.status, 'ref': h.ref, 'paid': h.paid, 'perks': h.perks},
    ],
    'enquiries': [
      for (final e in enquiries.where((e) => phone.isNotEmpty && e.phone == phone)) {'ref': e.ref, 'name': e.name, 'phone': e.phone, 'hid': e.hid, 'bed': e.bed, 'at': e.at, 'from': e.from, 'msg': e.msg},
    ],
    'fairAccepted': fairAccepted,
    // F18 (F5): the owner's house rules and menu stay on the phone.
    'rules': [for (final r in rules) [r.k, r.v]],
    'menu': [for (final d in menu) [d.b, d.l, d.n]],
  };

  void _persist() {
    final j = jsonEncode(snapshot());
    if (j == _saved) return;
    _saved = j;
    store.save(jsonDecode(j) as Map<String, dynamic>);
  }

  /// Brings back what was saved; a signed-in user opens on their role's home.
  void restore(Map<String, dynamic> m, {Account? firebaseUser}) {
    if (m.isEmpty) {
      _saved = jsonEncode(snapshot());
      return;
    }
    final a = m['account'] as Map<String, dynamic>?;
    myName = m['name'] as String? ?? '';
    phone = m['phone'] as String? ?? '';
    role = m['role'] as String? ?? 'tenant';
    theme = m['theme'] as String? ?? 'light';
    fairAccepted = m['fairAccepted'] as bool? ?? false;
    final ru = m['rules'] as List?;
    if (ru != null && ru.isNotEmpty) rules = [for (final r in ru.cast<List>()) Rule(r[0] as String, r[1] as String)];
    final me = m['menu'] as List?;
    if (me != null && me.length == menu.length) menu = [for (final d in me.cast<List>()) DayMenu(d[0] as String, d[1] as String, d[2] as String)];
    // A Google account counts only while Firebase still has it signed in.
    account = firebaseUser ?? (a != null && !signIn.available ? (uid: a['uid'] as String, name: a['name'] as String, email: a['email'] as String) : null);
    signedIn = m['signedIn'] as bool? ?? false;
    if (a != null && signIn.available && firebaseUser == null) signedIn = false;
    for (final id in (m['saved'] as List? ?? const [])) {
      saved[id as String] = true;
    }
    holds = [
      for (final h in (m['holds'] as List? ?? const []).cast<Map<String, dynamic>>())
        Hold(id: h['id'] as String, hid: h['hid'] as String, bed: h['bed'] as String, room: h['room'] as int, opt: h['opt'] as String, start: h['start'] as int, status: h['status'] as String, ref: h['ref'] as String?, paid: h['paid'] as int? ?? 0, perks: (h['perks'] as List? ?? const []).cast<String>()),
    ];
    for (final h in holds.where((h) => h.status != 'released')) {
      if (!hostels.any((x) => x.id == h.hid)) continue;
      final b = findBed(h.hid, h.bed).b;
      if (b != null) {
        b.state = h.status == 'booked' ? 'booked' : 'held';
        b.mine = true;
      }
    }
    final mine = [
      for (final e in (m['enquiries'] as List? ?? const []).cast<Map<String, dynamic>>())
        Enquiry(ref: e['ref'] as String, name: e['name'] as String, phone: e['phone'] as String, hid: e['hid'] as String, bed: e['bed'] as String?, at: e['at'] as int, from: e['from'] as String, msg: e['msg'] as String),
    ];
    enquiries = [...mine, ...enquiries.where((e) => !mine.any((x) => x.ref == e.ref))];
    if (signedIn && screen == 'welcome') {
      screen = homeOf[role]!;
      hist = [];
    }
    _saved = jsonEncode(snapshot());
    notifyListeners();
  }

  void _prep() {
    if (screen == 'oMore' && moreTab == 'rates' && rateDraft == null) {
      rateDraft = Map.of(rates[ownHid]!);
      acDraft = {for (final r in rooms[ownHid]!) r.n: r.ac};
    }
    final cr = screen == 'compare' && cmpA.isEmpty ? rooms[hid]!.where((r) => layoutOf(hid, r.n) != null && r.beds.where(_open).length >= 2).firstOrNull : null;
    if (cr != null) {
      final r = cr;
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

  // ------------------------------------------------------------ F18 map

  /// "Use my location" ([NoLocator] in tests, web, desktop).
  Locator locator = const NoLocator();

  /// The user's own position, only after they allowed it. Never invented.
  (double, double)? myPos;

  /// Area picked on the map (null = all areas), or a panned-to centre from
  /// "Search this area".
  String? mapArea;
  (double, double)? areaCenter;

  /// Where the map is after the user panned it; shows "Search this area".
  (double, double)? mapNow;

  /// Area picker search text.
  String areaQ = '';
  bool mapMoved = false;

  /// Bumped to recentre the map (area picked, location found).
  int mapFocus = 0;
  (double, double) get mapFocusPos => mapArea != null ? (areaLatLng[mapArea] ?? landmarkLatLng[lm]!) : areaCenter ?? myPos ?? landmarkLatLng[lm]!;

  /// Distance to a hostel: from you once location is on, else from the
  /// landmark searched.
  double kmFor(Hostel h) => myPos != null ? kmBetween(posOf(h), myPos!) : kmTo(h, lm);
  String get kmFrom => myPos != null ? 'from you' : 'from $lm';

  /// The map area filter (Explore follows it too).
  bool inMapArea(Hostel h) => (mapArea == null || h.area == mapArea) && (areaCenter == null || kmBetween(posOf(h), areaCenter!) <= searchRadiusKm);
  String get mapAreaLabel => mapArea ?? (areaCenter != null ? 'This area' : (myPos != null ? 'Near me' : 'All areas'));

  void pickArea(String? a) => update(() {
    mapArea = a;
    areaCenter = null;
    mapMoved = false;
    mapFocus++;
    sheet = null;
  });

  void mapPanned((double, double) c) {
    mapNow = c;
    if (!mapMoved) update(() => mapMoved = true);
  }

  void searchThisArea() => update(() {
    if (mapNow == null) return;
    areaCenter = mapNow;
    mapArea = null;
    mapMoved = false;
  });

  /// After the location explainer: Android asks, then the map centres on you
  /// and hostels sort by distance from you.
  Future<void> useMyLocation() async {
    update(() => sheet = null);
    final (pos, fail) = await locator.locate();
    if (pos != null) {
      update(() {
        myPos = pos;
        mapArea = null;
        areaCenter = null;
        mapMoved = false;
        sortBy = 'near';
        mapFocus++;
      });
      return toastMsg('Showing hostels by distance from you.');
    }
    update(() => sheet = 'areas');
    toastMsg(switch (fail) {
      LocateFail.off => 'Location is switched off on this phone. Pick an area instead.',
      LocateFail.never => 'Location is blocked for Hostelzy. Allow it in Settings → Apps → Hostelzy, or pick an area.',
      LocateFail.denied => 'No problem. Pick an area instead.',
      LocateFail.unavailable => 'Location works in the Android app. Pick an area instead.',
      _ => 'Couldn’t find your location. Pick an area instead.',
    });
  }

  /// F18: sample owner / resident data only in debug builds and tests.
  static bool samples = kDebugMode;

  /// Owner screens: sample data in debug; in release only for the Hostelzy
  /// team (team mode) or hostels the team put live on a visit, until owner
  /// accounts come with the backend (F13 part 2).
  bool get canOwner => samples || teamUnlocked || ownerHostels.any((h) => !isSeedHostel(h));

  /// Resident screens need an owner to have added you (backend, F13 part 2).
  bool get canResident => samples;

  /// Which honest "not yet" screen the role picker showed: owner | resident.
  String roleGate = 'resident';

  /// Owner gate: "Request a visit" form.
  String gateHostel = '', gateArea = '';

  /// Sends the visit request to the Hostelzy team on WhatsApp (no backend yet).
  void requestVisit() {
    if (gateHostel.trim().length < 3) return toastMsg('Enter your hostel’s name.');
    if (gateArea.isEmpty) return toastMsg('Pick the area.');
    whatsapp(supportWhatsApp, 'Hi Hostelzy, please visit my hostel to list it.\nHostel: ${gateHostel.trim()}\nArea: $gateArea\nName: ${meName.isEmpty ? '-' : meName}\nPhone: ${phone.isEmpty ? '-' : '+91 ${phoneSpaced(phone)}'}');
  }

  /// Role picker: gated roles show how to get access instead of sample data.
  void pickRole(String r) {
    if ((r == 'owner' && !canOwner) || (r == 'resident' && !canResident)) {
      return update(() {
        roleGate = r;
        hist = [...hist, screen];
        screen = 'roleGate';
      });
    }
    update(() {
      role = r;
      // F07: a new owner accepts the Fair Play rules first.
      screen = r == 'owner' && !fairAccepted ? 'oRules' : homeOf[r]!;
      hist = [];
    });
    syncProfile();
  }

  /// F18: when Android back last showed "Press back again to exit" (ms).
  int _backAt = 0;

  /// Android back button: close a sheet → previous screen → the role's home
  /// tab → "Press back again to exit". Returns true when the app may close.
  bool handleBack() {
    if (sheet != null) {
      update(() => sheet = null);
      return false;
    }
    if (hist.isNotEmpty) {
      back();
      return false;
    }
    final home = signedIn ? homeOf[role]! : 'welcome';
    if (screen != home && screen != 'gate') {
      update(() {
        screen = home;
        hist = [];
      });
      return false;
    }
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t - _backAt < 2000) return true;
    _backAt = t;
    toastMsg('Press back again to exit');
    return false;
  }

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
  String get myPhone => phone.length == 10 ? phone : '';

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
      e = Enquiry(ref: 'HZ-${_nextRef++}', name: meName.isEmpty ? 'Hostelzy user' : meName, phone: me, hid: hid, bed: bed, at: DateTime.now().millisecondsSinceEpoch, from: from, msg: body.replaceFirst(RegExp(r'^Hi [^,]*, '), ''));
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
    // F06: residents who came through Hostelzy are added within 3 days of
    // moving in. Later counts as a Fair Play signal (F07).
    final late = m != null ? ((now - joinAt) / 86400000).floor() : 0;
    final lateDays = late > addWithinDays ? late : 0;
    if (lateDays > 0) {
      final id = 'FP-0${143 + cases.length - seedCaseCount}';
      cases = [
        FairCase(openedAt: DateTime.now().millisecondsSinceEpoch, id: id, hid: 'anjani', title: '$name added $lateDays days after moving in', signal: 'Hostelzy resident (${m!.ref}) added after the 3-day limit', status: 'new', resident: bed, events: [CaseEvent(dayMon(DateTime.fromMillisecondsSinceEpoch(m.at)), 'On Hostelzy', 'Tenant ${m.what}'), CaseEvent(joined, 'Moved in', 'Bed $bed'), CaseEvent(dayMon(appToday), 'Added by the owner', '$lateDays days later', flag: true)]),
        ...cases,
      ];
    }
    return Resident(name: name, bed: bed, amt: amt, status: 'Paid', note: 'Paid at move-in', phone: phone, via: m != null ? 'hz' : 'direct', since: confirmed ? 'Joined $joined' : 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: confirmed, advance: adv, joinAt: joinAt, lateDays: lateDays);
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
    toastMsg(res.lateDays > 0 ? 'Added, ${res.lateDays} days after moving in: that’s past the 3-day limit and goes to Fair Play.' : 'Added as Waiting OTP. ${name.split(' ')[0]} confirms with the code once the app is online.');
  }

  /// Invite QR sign-ups signed in with Google; approving counts them.
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
    rateDraft = Map.of(rates[ownHid]!);
    acDraft = {for (final r in rooms[ownHid]!) r.n: r.ac};
    final fs = floorsOf(rooms[ownHid]!);
    rcFloor = fs.isEmpty ? 1 : (fs.contains(2) ? 2 : fs.first);
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
    final other = rateDraft![rateKey(!ac, share)] ?? (rateDraft!.isEmpty ? hostelById(ownHid).from : rateDraft!.values.reduce((a, b) => a < b ? a : b));
    rateDraft![rateKey(ac, share)] = other + (ac ? 1200 : -1200);
  });

  void saveRates() {
    final rs = rooms[ownHid]!;
    // F18 (D8): no ₹0 or blank prices on a room type that has rooms.
    for (final r in rs) {
      final v = rateDraft![rateKey(acDraft![r.n]!, r.share)];
      if (v == null || v < 1000) return toastMsg('Set a price for ${r.share} sharing ${acDraft![r.n]! ? 'AC' : 'non-AC'} (₹1,000 or more).');
    }
    final newAc = rs.where((r) => acDraft![r.n]! && !r.ac).length;
    update(() {
      rates[ownHid] = Map.of(rateDraft!);
      for (final r in rs) {
        r.ac = acDraft![r.n]!;
      }
      applyRates(ownHid);
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
    if (activeHolds >= maxHolds) return toastMsg('You can hold $maxHolds beds at a time. Release one in Holds first.');
    final opt = how ?? holdOpt;
    final r = findBed(hid, bed).r!;
    final h0 = hostelById(hid);
    final q = quote(hid, r.ac, r.share);
    String? ref;
    if (opt == 'book') {
      ref = _record(hid, 'Booked bed ${b.id} with the advance.', bed: b.id, from: 'Book · Pay advance').ref;
    }
    // F17: a booking is "paying" until the owner confirms the advance arrived.
    _bedBefore['$hid|${b.id}'] = b.state;
    b.state = 'held';
    b.mine = true;
    final t = DateTime.now().millisecondsSinceEpoch;
    final id = 'h$t';
    final h = Hold(id: id, hid: hid, bed: b.id, room: b.room, opt: opt, start: t, status: opt == 'free' ? 'waiting' : 'paying', ref: ref, paid: opt == 'book' ? q.hzAdv : 0, perks: opt == 'book' && q.any ? lockedPerks(q, h0) : const []);
    final pay = opt == 'book' ? Payment(id: 'pay$t', kind: 'advance', hid: hid, who: meShort, what: 'Advance for bed ${b.id}', bed: b.id, amt: q.hzAdv, note: ref!, holdId: id) : null;
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

  // ------------------------------------------------------------ F18 holds

  /// What each bed was before a hold (free, or free soon), so releasing puts
  /// it back exactly (D10).
  final Map<String, String> _bedBefore = {};

  /// Walk-in holds the owner placed, and when they end (F8): ms.
  final Map<String, int> walkIns = {};

  /// "from ₹X": the cheapest rent on the rate card now (D8), not the
  /// number frozen when the hostel was listed.
  int fromOf(Hostel h) {
    final rs = rooms[h.id];
    if (rs == null || rs.isEmpty) return h.from;
    return rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
  }

  /// A tenant holds at most this many beds at a time (D12).
  static const maxHolds = 2;
  int get activeHolds => holds.where((h) => const ['waiting', 'confirmed', 'held', 'paying'].contains(h.status)).length;

  void _freeBed(String hid, String id) {
    final b = hostels.any((x) => x.id == hid) ? findBed(hid, id).b : null;
    if (b == null) return;
    b
      ..state = _bedBefore.remove('$hid|$id') ?? 'free'
      ..mine = false;
  }

  /// Release a hold: the bed goes back to how it was, the hold record says
  /// Released, and any unconfirmed advance for it is dropped (D10, F9).
  void releaseHold(Hold h, {String? msg}) {
    update(() {
      _freeBed(h.hid, h.bed);
      holds = holds.map((x) => x.id == h.id ? x.withStatus('released') : x).toList();
      payments = payments.where((x) => x.holdId != h.id || x.status == 'paid').toList();
    });
    if (msg != null) toastMsg(msg);
  }

  /// Owner releases a held bed: the tenant's hold record follows (F9).
  void ownerReleaseBed(String hid, Bed b) {
    final h = holds.where((x) => x.hid == hid && x.bed == b.id && x.status != 'released').firstOrNull;
    if (h != null) return releaseHold(h);
    walkIns.remove('$hid|${b.id}');
    update(() => _freeBed(hid, b.id));
  }

  /// Owner holds a bed for a walk-in for one hour; it frees itself after (F8).
  void holdWalkIn(String hid, Bed b) {
    _bedBefore['$hid|${b.id}'] = b.state;
    walkIns['$hid|${b.id}'] = DateTime.now().millisecondsSinceEpoch + 3600 * 1000;
    update(() => b.state = 'held');
  }

  bool _expireWalkIns(int n) {
    final out = walkIns.entries.where((e) => e.value <= n).map((e) => e.key).toList();
    if (out.isEmpty) return false;
    update(() {
      for (final k in out) {
        walkIns.remove(k);
        final i = k.indexOf('|');
        _freeBed(k.substring(0, i), k.substring(i + 1));
      }
    });
    return true;
  }

  void copyText(String s) => Clipboard.setData(ClipboardData(text: s));

  /// The last text handed to the phone's share sheet (tests read it).
  String? lastShare;

  /// Opens Android's share sheet (WhatsApp, SMS, Telegram…). Nothing is sent
  /// until the user picks an app and sends it.
  Future<void> share(String text) async {
    lastShare = text;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      copyText(text);
      toastMsg('Sharing isn’t available here. The text is copied.');
    }
  }

  /// F14: the resident QR poster as an A4 PDF, shared through the share sheet
  /// (print it, or send it to a print shop on WhatsApp).
  int? lastPosterBytes;
  Future<void> sharePoster(String link) async {
    final bytes = await residentPoster(hostel: hostelById(ownHid).name, link: link);
    lastPosterBytes = bytes.length;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'hostelzy-poster.pdf')], text: 'Hostelzy resident poster (A4)'));
    } catch (_) {
      toastMsg('Sharing isn’t available here.');
    }
  }

  /// "Find a PG on Hostelzy with my code …" (F09).
  String get referralText => 'I found my PG on Hostelzy: see the exact bed before you visit. Use my code $referralCode when you join a hostel through Hostelzy and we both get ${fmt(referralReward)} after your first month.'; 

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
    // F18: never pay a sample UPI ID in the Play Store build.
    if (!samples && u.id.startsWith('sample.')) return toastMsg('This is a sample listing, so it has no real UPI ID. Don’t pay it.');
    if (u.id.isNotEmpty && !validUpiId(u.id)) return toastMsg('${hostelById(p.hid).owner.isEmpty ? 'The owner' : hostelById(p.hid).owner}’s UPI ID isn’t valid. Ask them on WhatsApp.');
    if (u.id.isEmpty) return toastMsg('${hostelById(p.hid).owner.isEmpty ? 'The owner' : hostelById(p.hid).owner} hasn’t added a UPI ID yet. Ask them on WhatsApp.');
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
    toastMsg(received ? 'Confirmed. It shows as ${p.kind == 'rent' ? 'paid' : 'booked'}.' : 'Marked not received. Tell $first on WhatsApp to check the UTR.');
  }

  /// Tenant gives up on a booking whose payment didn't arrive.
  void cancelBooking(Hold h) {
    releaseHold(h);
    update(() => hid = h.hid);
    openPicker();
  }

  // ------------------------------------------------------------ F15 Play Store

  /// Notification choices (sent once notifications are live, F13).
  final Map<String, bool> notif = {'hold': true, 'rent': true, 'beds': false};

  // ------------------------------------------------------------ F13 login

  /// Google sign-in (Firebase on Android; [NoSignIn] in tests, web, desktop).
  SignIn signIn = const NoSignIn();

  /// Where data is saved: sample (on this phone) or Supabase.
  HostelData data = const SampleData();

  /// The signed-in Google account; null when using Hostelzy on this phone only.
  Account? account;
  bool signingIn = false;

  /// The typed phone number is never verified until SMS checks exist.
  bool get phoneVerified => false;

  Future<void> continueWithGoogle() async {
    if (signingIn) return;
    if (!signIn.available) return toastMsg('Google sign-in works in the Android app. Use Hostelzy on this phone for now.');
    update(() => signingIn = true);
    final (a, fail) = await signIn.google();
    update(() => signingIn = false);
    if (a != null) {
      update(() {
        account = a;
        // F18: the Google name is only a starting point; the user can change it.
        if (myName.trim().isEmpty) myName = a.name;
        hist = [...hist, screen];
        screen = 'phone';
        sheet = null;
      });
      return;
    }
    toastMsg(switch (fail) {
      SignInFail.cancelled => 'Sign-in cancelled.',
      SignInFail.notSetUp => 'Google sign-in isn’t switched on yet. Use Hostelzy on this phone for now.',
      _ => 'Couldn’t sign in. Check your internet and try again.',
    });
  }

  /// Honest fallback until Google sign-in is set up: nothing leaves the phone.
  void continueOnPhone() => update(() {
    account = null;
    hist = [...hist, screen];
    screen = 'phone';
    sheet = null;
  });

  /// After the phone number (typed, not verified): pick a role.
  /// Indian mobile numbers: 10 digits starting 6–9.
  static bool validPhone(String p) => RegExp(r'^[6-9]\d{9}$').hasMatch(p);

  void savePhone() {
    if (myName.trim().length < 2) return toastMsg('Enter your name.');
    if (phone.length != 10) return toastMsg('Enter all 10 digits.');
    if (!validPhone(phone)) return toastMsg('Mobile numbers start with 6, 7, 8 or 9.');
    myName = myName.trim();
    update(() {
      signedIn = true;
      hist = [...hist, screen];
      screen = 'role';
    });
  }

  /// Saves name, phone (not verified) and role once signed in with Google.
  Future<void> syncProfile() async {
    final a = account;
    if (a == null) return;
    try {
      await data.saveProfile(name: a.name, email: a.email, phone: phone, role: role);
    } catch (e) {
      debugPrint('Profile: $e');
    }
  }

  /// F13 push: Firebase on Android ([NoPush] in tests, web, desktop).
  Push push = const NoPush();

  /// This phone's FCM token once notifications are allowed. Saved to the
  /// backend (`push_tokens`) once phone login works.
  String? pushToken;

  /// After the explainer: Android's own prompt, then the token.
  Future<void> enablePush() async {
    final r = await push.ask();
    switch (r) {
      case PushAsk.allowed:
        pushToken = await push.token();
        final t = pushToken;
        if (t != null && account != null) {
          try {
            await data.savePushToken(t);
          } catch (e) {
            debugPrint('Push token: $e');
          }
        }
        update(() => notif.updateAll((k, v) => k == 'beds' ? v : true));
        toastMsg('Notifications allowed. Hostelzy starts sending them once your account is online.');
      case PushAsk.denied:
        toastMsg('Notifications are off. Turn them on in your phone’s settings → Apps → Hostelzy.');
      case PushAsk.unavailable:
        update(() => notif.updateAll((k, v) => k == 'beds' ? v : true));
        toastMsg('Saved. Notifications work in the Android app.');
    }
  }

  /// Permission explainer shown: notifications | location | camera.
  String permKind = 'notifications';

  /// Update / maintenance screen: update | maintenance.
  String gateKind = 'update';

  /// F15 maintenance message ("6:30 pm"), from the backend once online.
  String maintUntil = maintenanceUntil;

  // ------------------------------------------------------------ F13 backend

  /// Live hostels from the database replace the sample ones for tenants.
  void applyListings(Listings l) => update(() {
    liveListings = true;
    livePos.addAll(l.pos);
    for (final h in l.hostels) {
      hostels.removeWhere((x) => x.id == h.id);
      hostels.add(h);
      rooms[h.id] = l.rooms[h.id]!;
      rates[h.id] = l.rates[h.id]!;
      ownerUpi[h.id] = l.upi[h.id]!;
      stats[h.id] = const ReviewStats([0, 0, 0, 0, 0], 0, 0, 0);
      confirmed[h.id] = 0;
    }
  });

  /// Remote switches: too-old builds must update; maintenance mode.
  void applySettings(RemoteSettings r) => update(() {
    maintUntil = r.maintenanceUntil;
    if (appBuild < r.minBuild || r.maintenanceUntil.isNotEmpty) {
      gateKind = appBuild < r.minBuild ? 'update' : 'maintenance';
      screen = 'gate';
      hist = [];
      sheet = null;
    }
  });

  String delReason = '', delOtp = '';

  /// Why the account can't be deleted yet, or null.
  ({String title, String body, String cta, VoidCallback go})? get deleteBlock {
    final h = holds.where((x) => const ['waiting', 'confirmed', 'held', 'paying'].contains(x.status)).firstOrNull;
    if (h != null) {
      return (title: 'You have an open hold', body: 'Your hold on bed ${h.bed} at ${hostelById(h.hid).name} is still open. Cancel it or let it end first.', cta: 'Go to my hold', go: () => update(() {
        holdId = h.id;
        hist = [...hist, screen];
        screen = 'hold';
      }));
    }
    if (role == 'owner' && (invoice.status == 'due' || invoice.status == 'missing')) {
      return (title: 'Your Hostelzy plan is unpaid', body: 'Owners: invoice ${invoice.ref} (${fmt(invoiceAmt)}) is due. Pay it or contact us, then delete.', cta: 'Open invoice', go: () => go('oInvoice'));
    }
    return null;
  }

  bool isDark(Brightness phone) => theme == 'dark' || (theme == 'system' && phone == Brightness.dark);

  void openPerm(String kind) => update(() {
    permKind = kind;
    hist = [...hist, screen];
    screen = 'perm';
  });

  void startDelete() => update(() {
    delOtp = '';
    hist = [...hist, screen];
    screen = 'delOtp';
    codeSentAt = DateTime.now().millisecondsSinceEpoch;
    now = codeSentAt;
  });

  /// Deletes the account. With no backend yet, everything lives on this
  /// phone, so this clears it here; with F13 it also deletes it on the server.
  void deleteAccount() {
    if (delOtp.length != 6) return toastMsg('Enter the 6-digit code.');
    final me = myPhone;
    update(() {
      enquiries = enquiries.where((e) => e.phone != me).toList();
      holds = [];
      saved.clear();
      member = false;
      monthsOnTime = 0;
      rewardUsed = false;
      phone = '';
      otp = '';
      signedIn = false;
      account = null;
      delReason = '';
      screen = 'delDone';
      hist = [];
      sheet = null;
    });
  }

  /// F18: logging out forgets everything this phone kept about the user.
  void logOut() {
    signIn.signOut();
    final me = phone;
    update(() {
      for (final h in holds.where((h) => h.status != 'released')) {
        if (hostels.any((x) => x.id == h.hid) && findBed(h.hid, h.bed).b?.mine == true) _freeBed(h.hid, h.bed);
      }
      holds = [];
      saved.clear();
      if (me.isNotEmpty) enquiries = enquiries.where((e) => e.phone != me).toList();
      account = null;
      myName = '';
      role = 'tenant';
      screen = 'welcome';
      hist = [];
      phone = '';
      otp = '';
      signedIn = false;
      sheet = null;
    });
    store.clear();
    _saved = jsonEncode(snapshot());
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
  void whatsapp(String phone, String text) {
    if (_fakeContact(phone)) return;
    openLink(Uri.parse('https://wa.me/${phone.isEmpty ? '' : '91$phone'}?text=${Uri.encodeComponent(text)}'), 'WhatsApp');
  }

  void call(String phone) {
    if (phone.isEmpty) return toastMsg('No number to call yet.');
    if (_fakeContact(phone)) return;
    openLink(Uri.parse('tel:+91$phone'), 'the phone app');
  }

  /// Sample people have obvious fake numbers (90000 000xx / 001xx).
  static bool isSampleNumber(String phone) => phone.startsWith('90000');

  /// F18: the Play Store build never opens WhatsApp or the dialler for a
  /// sample number; it says so instead.
  bool _fakeContact(String phone) {
    if (samples || !isSampleNumber(phone)) return false;
    toastMsg('This is a sample listing, so there’s no real number yet.');
    return true;
  }
  void directions(Hostel h) => openLink(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${posOf(h).$1},${posOf(h).$2}'), 'Maps');

  /// The tenant's last ended hold: "Did you join?" asks about it (F07).
  Hold? get endedHold => holds.where((h) => h.status == 'released').lastOrNull;

  /// Holds that ran out (shown as "Hold expired").
  final Set<String> expiredHolds = {};

  bool _expireHolds(int n) {
    final out = holds.where((h) => const ['waiting', 'confirmed', 'held'].contains(h.status) && holdSecs - (n - h.start) / 1000 <= 0).toList();
    if (out.isEmpty) return false;
    now = n;
    update(() {
      for (final h in out) {
        if (findBed(h.hid, h.bed).b?.mine == true) _freeBed(h.hid, h.bed);
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
