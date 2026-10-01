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
    this.moreTab = moreTab ?? 'complaints';
    this.foodView = foodView ?? 'day';
    this.mView = mView ?? 'day';
    reqs = seedRequests(n);
    _prep();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (const ['hold', 'holds', 'oToday'].contains(screen)) {
        now = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
    });
  }

  static const screens = ['welcome', 'phone', 'otp', 'role', 'explore', 'map', 'holds', 'me', 'detail', 'picker', 'hold', 'rHome', 'rPay', 'food', 'help', 'move', 'oToday', 'oBeds', 'oRent', 'oMore', 'oRates'];
  static const tabScreens = ['explore', 'map', 'holds', 'me', 'rHome', 'rPay', 'food', 'help', 'oToday', 'oBeds', 'oRent', 'oMore'];

  Timer? _ticker, _toastTimer;

  late String screen, role, theme, mode, moveTab, moreTab, foodView, mView;
  String? sheet;
  List<String> hist = [];
  String phone = '', otp = '';
  final Map<String, List<Room>> rooms = {};

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
  List<Resident> residents = seedResidents();
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
    if (screen == 'oRates' && rateDraft == null) {
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
    if (sheet == 'wa' && waTo == null) {
      waTo = 'Srinivas';
      waMsg = 'Hi Srinivas, I found Anjani Residency on Hostelzy. Can I come and see the rooms this evening?';
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
    go('oRates');
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

  void placeHold() {
    final b = findBed(hid, bed).b;
    if (b == null) return;
    final opt = holdOpt;
    b.state = opt == 'token' ? 'booked' : 'held';
    b.mine = true;
    final t = DateTime.now().millisecondsSinceEpoch;
    final id = 'h$t';
    final h = Hold(
      id: id,
      hid: hid,
      bed: b.id,
      room: b.room,
      opt: opt,
      start: t,
      status: opt == 'free'
          ? 'waiting'
          : opt == 'paid'
          ? 'held'
          : 'booked',
    );
    update(() {
      holds = [...holds, h];
      holdId = id;
      sheet = null;
      bed = null;
      hist = [...hist, screen];
      screen = 'hold';
    });
    toastMsg(
      opt == 'free'
          ? 'Hold placed. ${hostelById(hid).owner} has been told on WhatsApp.'
          : opt == 'paid'
          ? 'Paid ₹299. The bed is held for 48 hours.'
          : 'Paid ₹2,000. The bed is yours.',
    );
  }

  void setHold(String id, String status) => update(() => holds = holds.map((h) => h.id == id ? h.withStatus(status) : h).toList());

  void copyText(String s) => Clipboard.setData(ClipboardData(text: s));
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
