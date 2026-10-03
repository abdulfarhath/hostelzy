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
import 'l10n.dart';
import 'poster.dart';
import 'push.dart';
import 'reminders.dart';
import 'sign_in.dart';
import 'store.dart';
import 'locate.dart';
import 'features/listings/live.dart' show LiveRows, MeterRow, statsOf;
import 'features/listings/repo.dart' show HostelFlags, HostelRepo, HostelSignals, Listings, RemoteSettings, SampleRepo;
import 'features/photos/photo.dart';
import 'features/photos/pick.dart';
import 'features/links/scan.dart';

part 'features/fair_play/fair_play.dart';
part 'features/rewards/rewards.dart';
part 'features/plan/plan.dart';
part 'features/layouts/room_layouts.dart';
part 'features/team/team_mode.dart';
part 'features/layouts/owner_layouts.dart';
part 'features/onboarding/rooms_live.dart';
part 'features/team/team_members.dart';
part 'features/layouts/layout_editor.dart';
part 'features/layouts/layout_fixes.dart';
part 'features/onboarding/onboarding.dart';
part 'features/reviews/reviews.dart';
part 'features/reviews/review_rules.dart';
part 'features/session/on_phone.dart';
part 'features/map/map.dart';
part 'features/residents/residents.dart';
part 'features/holds/holds.dart';
part 'features/payments/payments.dart';
part 'features/session/play_store.dart';
part 'features/session/login.dart';
part 'features/listings/sync.dart';
part 'features/links/links.dart';
part 'features/photos/photos.dart';
part 'features/reminders/reminders.dart';
part 'features/residents/my_stay.dart';
part 'features/session/guest.dart';
part 'features/amenities/amenities.dart';
part 'features/food/food.dart';
part 'features/moves/moves.dart';
part 'features/meter/meter.dart';
part 'features/laundry/laundry.dart';

/// App state and actions. Mirrors the prototype's single component state so
/// the tenant, resident and owner roles share the same data.
///
/// B4: split by area. Each `lib/features/<area>/*.dart` part holds that
/// area's fields (a `_XData` mixin) and actions (an `XActions` extension).
/// This file keeps the shared core: navigation, `update`, statics, restore.
/// F21 W4: how long an Undo stays.
const undoSecs = Duration(seconds: 5);

class AppState extends ChangeNotifier with _FairPlayData, _RewardsData, _PlanData, _RoomLayoutsData, _TeamModeData, _OwnerLayoutsData, _RoomsLiveData, _TeamMembersData, _LayoutEditorData, _OnboardingData, _ReviewsData, _OnPhoneData, _MapAreaData, _HoldsData, _PaymentsData, _PlayStoreData, _LoginData, _SyncData, _LinksData, _PhotosData, _RemindersData, _MyStayData, _LayoutFixesData, _GuestData, _AmenityData, _FoodData, _MoveData, _MeterData, _LaundryData, _ReviewRulesData {
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
    this.moreTab = moreTab ?? 'home';
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

  static const screens = ['welcome', 'login', 'phone', 'roleGate', 'oCreate', 'oPublished', 'saved', 'otp', 'role', 'explore', 'map', 'holds', 'me', 'detail', 'picker', 'hold', 'rHome', 'rPay', 'food', 'help', 'move', 'rReview', 'rExit', 'reviews', 'oToday', 'oBeds', 'oRent', 'oMore', 'oInvite', 'oRank', 'oRules', 'oCase', 'oStrike', 'aCases', 'rewards', 'moveIn', 'oPlan', 'oInvoice', 'oPayStatus', 'aPay', 'compare', 'oLayout', 'aLayout', 'aAdd', 'aTrack', 'oTeam', 'settings', 'delAcc', 'delConfirm', 'delDone', 'perm', 'gate', 'aHome', 'oLayouts', 'oRooms', 'aTeam', 'oPhotos', 'oCrop', 'gallery', 'reminders', 'rRoom', 'rFix', 'oFix', 'oFixDone', 'where', 'rStay', 'rRefund', 'oMeter', 'scan'];
  static const tabScreens = ['explore', 'map', 'saved', 'holds', 'me', 'rHome', 'rPay', 'food', 'help', 'oToday', 'oBeds', 'oRent', 'oMore'];

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

  /// S3: house rules saved on the server, per hostel.
  final Map<String, List<Rule>> hostelRules = {};

  /// Owner's deal picker draft (Manage → Deals) and the tenant's deal-table room type.
  Set<String>? dealDraft;
  String dealTarget = 'all';
  bool? dealAc;

  /// Explore sort: rec (Recommended, F08) | near | price | deals (F03).
  String sortBy = 'rec';
  bool get bestDeals => sortBy == 'deals';

  // F07 Fair Play
  static final seedCaseCount = seedCases().length;

  // F10 owner plan
  late Invoice invoice = Invoice(ref: 'HZ-INV-1024', hid: ownHid, beds: planBeds, amt: planTiers[planTierOf(planBeds)].price, due: trialEnd.add(const Duration(days: 1)));
  late List<Invoice> invoices = [invoice, ...seedInvoices()];

  /// "I've paid": the UTR sheet, prefilled when fixing a UTR we couldn't find.
  void openUtr() => update(() {
    utrDraft = invoice.status == 'missing' ? invoice.utr ?? '' : '';
    sheet = 'utr';
  });

  // F12 room layouts

  /// Layouts drawn by the Hostelzy team, by hostel and room number.
  late final Map<String, Map<int, RoomLayout>> layouts = seedLayouts(rooms);

  /// Tapping a room in Plan opens it in Room.
  void openRoom(int n) => update(() {
    room = n;
    bed = null;
    mode = 'room';
  });

  /// A bed a tenant can hold: free, or freeing up soon.
  static bool _open(Bed b) => (b.state == 'free' || b.state == 'soon') && !b.mine;

  void openLayoutRequest() => openShapeRequest();

  // team mode

  void openLayout(int n, {bool editor = false, bool owner = false}) {
    _openLayout(n, editor: editor, owner: owner);
    // F12: one editor at a time (on the server).
    if (editor) unawaited(takeLayoutLock());
  }

  void _openLayout(int n, {bool editor = false, bool owner = false}) => update(() {
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
    // F24: the owner's "Ask Hostelzy" requests and the team's drawings.
    loadShapeRequests(ownHid);
  });

  // layout editor

  void edSelect(String id) => update(() => edSel = id);

  // F14 onboarding

  void switchHostel(String hid) => update(() {
    ownHid = hid;
    rules = hostelRules[hid] != null ? List.of(hostelRules[hid]!) : isSeedHostel(hid) ? rules : blankRules(hostelById(hid).terms);
    // Drafts belong to the hostel they were opened on.
    rateDraft = null;
    acDraft = null;
    dealDraft = null;
    sheet = null;
    screen = 'oToday';
    hist = [];
  });

  void openAddHostel() => update(() {
    draft = AppState.samples ? HostelDraft() : HostelDraft.blank();
    addStep = 1;
    hist = [...hist, screen];
    screen = 'aAdd';
    sheet = null;
  });

  // F08 reviews

  void openDeals() => update(() {
    final d = dealsOf(ownHid);
    dealDraft = Set.of(d.on);
    dealTarget = d.target;
    screen = 'oMore';
    hist = [];
    sheet = null;
    moreTab = 'deals';
  });

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    _tokenSub?.cancel();
    _edLockTimer?.cancel();
    stopLive();
    super.dispose();
  }

  void update(void Function() fn) {
    final key = '$screen|$mode|$moreTab';
    fn();
    if (key != '$screen|$mode|$moreTab') scrollEpoch++;
    notifyListeners();
    _persist();
  }

  // F18 on this phone

  /// Brings back what was saved; a signed-in user opens on their role's home.
  void restore(Map<String, dynamic> m, {Account? firebaseUser}) {
    opens = (m['opens'] as int? ?? 0) + 1;
    if (m.isEmpty) {
      _saved = jsonEncode(snapshot());
      return;
    }
    final a = m['account'] as Map<String, dynamic>?;
    myName = m['name'] as String? ?? '';
    phone = m['phone'] as String? ?? '';
    role = m['role'] as String? ?? 'tenant';
    theme = m['theme'] as String? ?? 'light';
    lang = m['lang'] as String? ?? 'en';
    fairAccepted = m['fairAccepted'] as bool? ?? false;
    pushAsked = m['pushAsked'] as bool? ?? false;
    camAsked = m['camAsked'] as bool? ?? false;
    for (final e in ((m['notif'] as Map?) ?? const {}).entries) {
      if (notif.containsKey(e.key) && e.value is bool) notif[e.key as String] = e.value as bool;
    }
    searchedAreas
      ..clear()
      ..addAll([for (final a in (m['areas'] as List? ?? const [])) if (a is String) a].take(5));
    restoreRem(m['rem'] as Map<String, dynamic>?);
    final ru = m['rules'] as List?;
    if (ru != null && ru.isNotEmpty) rules = [for (final r in ru.cast<List>()) Rule(r[0] as String, r[1] as String)];
    for (final e in ((m['fixDrafts'] as Map?) ?? const {}).entries) {
      fixDrafts[e.key as String] = snapFromJson((e.value as Map).cast<String, dynamic>());
    }
    // F18 kept the owner's menu on the phone; it now waits to be saved to the server.
    final me = m['menu'] as List?;
    if (me != null && me.length == 7) phoneMenu = [for (final d in me.cast<List>()) DayMenu(d[0] as String, d[1] as String, d[2] as String)];
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
    // F12: leaving the layout editor lets the room's edit lock go.
    if (screen == 'aLayout') unawaited(releaseLayoutLock());
    final h = List.of(hist);
    final prev = h.isNotEmpty ? h.removeLast() : homeOf[role]!;
    screen = prev;
    hist = h;
    sheet = null;
  });

  // F18 map

  void pickArea(String? a) => update(() {
    if (a != null) noteSearchedArea(a);
    mapArea = a;
    areaCenter = null;
    mapMoved = false;
    mapFocus++;
    sheet = null;
  });

  void searchThisArea() => update(() {
    if (mapNow == null) return;
    areaCenter = mapNow;
    mapArea = null;
    mapMoved = false;
  });

  /// F18: sample owner / resident data only in debug builds, tests and the
  /// demo APK (DATA=sample). The real APK (DATA=supabase) starts with none.
  static bool samples = kDebugMode || dataSource == 'sample';

  /// The demo APK says so on every screen (design "Demo").
  static bool demoBanner = !kDebugMode && dataSource == 'sample';

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

  /// F05 tenant → owner hand-off. Records the enquiry on Hostelzy first (the
  /// owner is told from here, not by the WhatsApp text), then opens the
  /// prefilled message ending with the HZ code and its link. One enquiry per
  /// tenant + hostel + bed: tapping again reuses the code.
  void enquire(String hid, String body, {String? bed, required String from}) {
    // F21 W2: guests sign in first; the enquiry needs their name and phone.
    if (!needSignIn('enquiry', () => enquire(hid, body, bed: bed, from: from))) return;
    // C: on Supabase the server records it and issues the HZ code.
    if (onServer) {
      enquireLive(hid, body, bed: bed, from: from);
      return;
    }
    update(() => _enquire(hid, body, bed: bed, from: from));
  }

  void markContacted(String ref) {
    update(() => enquiries = enquiries.map((e) => e.ref == ref ? e.withContacted() : e).toList());
    if (onServer) markContactedLive(ref);
  }

  /// Resident: raise a complaint (C: saved on the server when live).
  Future<void> raiseComplaint() async {
    if (cText.trim().isEmpty) return toastMsg('Tell us what is wrong first.');
    final text = cText.trim();
    final photo = cPhoto;
    if (onServer) {
      final h = myHostel;
      if (h == null) return toastMsg('Your owner hasn’t added you yet. Complaints open once you’re a resident here.');
      final uid = account?.uid;
      final ok = await _write(() async {
        // F21 W3: the photo goes up first, then the complaint points at it.
        final path = photo != null && uid != null ? await data.uploadComplaintPhoto(h, uid, photo) : null;
        await data.raiseComplaint(hid: h, bed: myBedLabel, cat: cCat, body: text, photo: path);
      });
      if (!ok) return;
      update(() {
        cText = '';
        cPhoto = null;
      });
      await refreshLive();
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch;
    update(() {
      complaints = [...complaints, Complaint(id: id, by: '$meShort · 204', cat: cCat, text: text, status: 'Open', date: dayMon(appToday), note: 'Saved on this phone · tell $stayOwner on WhatsApp too', mine: true, at: id)];
      if (photo != null) complaintPhotosLocal[id] = photo;
      cText = '';
      cPhoto = null;
    });
  }

  /// Help: one photo for the complaint (compressed like hostel photos).
  Future<void> pickComplaintPhoto() async {
    final raw = await picker.pick();
    if (raw == null) return;
    final jpg = prepPhoto(raw, 'free');
    if (jpg == null) return toastMsg('That photo didn’t open. Try another one.');
    update(() => cPhoto = jpg);
  }

  /// Owner: open a complaint's photo (a short-lived private link on the server).
  Future<void> openComplaintPhoto(Complaint c) async {
    final local = complaintPhotosLocal[c.id];
    if (local != null) {
      return update(() {
        cPhotoView = c.id;
        sheet = 'cPhoto';
      });
    }
    final path = c.photo;
    if (path == null) return;
    final url = await data.complaintPhotoUrl(path);
    if (url == null) return toastMsg('Couldn’t open the photo. Check your internet and try again.');
    openLink(Uri.parse(url), 'the photo');
  }

  /// Owner: Open → In progress → Resolved (C: saved on the server when live).
  Future<void> advanceComplaint(Complaint c) async {
    const nxs = {'Open': 'In progress', 'In progress': 'Resolved'};
    final next = nxs[c.status];
    if (next == null) return;
    final note = next == 'Resolved' ? 'Fixed by the owner' : 'Owner is on it';
    update(() => complaints = complaints.map((x) => x.id == c.id ? x.copyWith(status: next, note: note) : x).toList());
    if (onServer && c.key != null) await _write(() => data.updateComplaint(c.key!, status: next, note: note));
  }

  /// The resident's bed as shown on complaints (live: not known yet → '').
  // F21 W3: on the server, the resident's own bed (complaints and layout fixes said none).
  String get myBedLabel => onServer ? (myStay?.bed ?? '') : '204';

  // F06

  void openAddResident() => update(() {
    final free = unassignedBeds;
    rName = '';
    rPhone = '';
    rJoin = 'Today';
    rBed = free.isNotEmpty ? free.first : null;
    final r = rBed != null ? findBed(ownHid, rBed).r : null;
    rFee = r != null ? '${r.rent}' : '';
    rAdv = '${hostelById(ownHid).terms.advance}';
    sheet = 'addR';
  });

  void pickResidentBed(String id) => update(() {
    rBed = id;
    final r = findBed(ownHid, id).r;
    if (r != null) rFee = '${r.rent}';
  });

  void openEnquiry(String ref) => update(() {
    enqRef = ref;
    sheet = 'enq';
  });

  /// F16: does room [r] match room-type filter [f] (Any | AC | Non-AC)?
  static bool fits(Room r, String f) => f == 'Any' || (f == 'AC') == r.ac;

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

  /// "Not offered · + Add": starts from the other type's price (± ₹1,200).
  void addRate(bool ac, int share) => update(() {
    final other = rateDraft![rateKey(!ac, share)] ?? (rateDraft!.isEmpty ? hostelById(ownHid).from : rateDraft!.values.reduce((a, b) => a < b ? a : b));
    rateDraft![rateKey(ac, share)] = other + (ac ? 1200 : -1200);
  });

  void setHold(String id, String status) => update(() => holds = holds.map((h) => h.id == id ? h.withStatus(status) : h).toList());

  // F18 holds

  /// A tenant holds at most this many beds at a time (D12).
  static const maxHolds = 2;

  // F17 payments

  void openPayUtr(Payment p) => update(() {
    payId = p.id;
    payUtr = p.utr ?? '';
    sheet = 'payUtr';
  });

  // F13 login

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

  // F13 backend

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
      stats[h.id] = statsOf(l.reviews[h.id] ?? const []);
      // F24 item 9: the owner's last confirmations on the server; unknown
      // (never "today") until there is one.
      if (h.bedsCheckedAt != null) {
        confirmed[h.id] = daysSince(h.bedsCheckedAt!);
      } else {
        confirmed.remove(h.id);
      }
      if (h.layoutsCheckedAt != null) {
        layoutConfirmed[h.id] = daysSince(h.layoutsCheckedAt!);
      } else {
        layoutConfirmed.remove(h.id);
      }
      layouts[h.id] = l.layouts[h.id] ?? {};
      deals[h.id] = l.deals[h.id] ?? const Deals();
      strikes[h.id] = l.strikes[h.id] ?? 0;
      if (l.checks[h.id] != null) layoutChecks[h.id] = l.checks[h.id]!;
      if (l.rules[h.id] != null) hostelRules[h.id] = l.rules[h.id]!;
      // F24: "Visited by Hostelzy" is the team's go-live date on the server.
      if (h.visitedOn.isNotEmpty) visited[h.id] = h.visitedOn;
    }
    // S4: the live hostels' reviews replace any earlier copy of them.
    final ids = {for (final h in l.hostels) h.id};
    reviews = [...reviews.where((r) => !ids.contains(r.hid)), for (final h in l.hostels) ...?l.reviews[h.id]];
    // F23: their floor and room things too.
    amenities = [...amenities.where((a) => !ids.contains(a.hid)), for (final h in l.hostels) ...?l.amenities[h.id]];
    // S3: the owner edits their own hostel's rules.
    if (hostelRules[ownHid] != null) {
      rules = List.of(hostelRules[ownHid]!);
    } else if (!isSeedHostel(ownHid) && ids.contains(ownHid)) {
      rules = blankRules(hostelById(ownHid).terms);
    }
    // F24 item 8: the server's walk-in holds on the owner's beds.
    syncWalkIns();
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

  void openPerm() => update(() {
    hist = [...hist, screen];
    screen = 'perm';
  });

  void startDelete() => update(() {
    hist = [...hist, screen];
    screen = 'delConfirm';
  });

  // F17 links

  /// Sample people have obvious fake numbers (90000 000xx / 001xx).
  static bool isSampleNumber(String phone) => phone.startsWith('90000');
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
