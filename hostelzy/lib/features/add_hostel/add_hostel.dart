part of '../../state.dart';

// F28 Part 2 (wave 2): anyone signed in adds a hostel (S92 `addHostel`),
// then follows it in S93 `myAdd`: Added ✓ → Owner asked → Owner agreed →
// Verified → ₹200 paid. The hostel is UNVERIFIED (listed) until the owner
// claims it and the team verifies it. Partners add with a code and a range.
// Money: ₹200 to a resident when the hostel goes live, ₹20 to a partner after
// the team check, ₹2,000 a month for both together (DECISIONS 2026-10-18).

/// What S92 collects. The pin comes from the map (aPin in 'add' mode).
class AddDraft {
  String name = '', gender = 'Men', area = '';
  (double, double)? pin;
  int share = 2;
  bool food = true;

  /// A resident's own rent; partners enter [rent]–[rentMax].
  String rent = '', rentMax = '';
  String ownerName = '', ownerPhone = '';
  bool partner = false;
  String partnerCode = '';
  final List<Uint8List> photos = [];
}

/// The adder's latest hostel, from `my_added_hostel()` (or the demo seed).
class MyAdd {
  MyAdd({required this.id, required this.name, required this.gender, required this.area, required this.status, required this.source, this.partnerCode, required this.rentMin, required this.rentMax, required this.createdAt, this.ownerAskedAt, this.ownerAgreedAt, this.liveAt, this.removed = false, this.reward, this.payMonth, this.paidAt, this.upi = '', this.photos = 0, this.ownerName = '', this.ownerPhone = ''});
  final String id, name, gender, area, source, ownerName, ownerPhone;
  final String? partnerCode;
  String status, upi;
  final int rentMin, rentMax, photos;
  final DateTime createdAt;
  DateTime? ownerAskedAt, ownerAgreedAt, liveAt, paidAt;
  final bool removed;
  final int? reward;
  final DateTime? payMonth;

  static DateTime? _t(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

  factory MyAdd.fromJson(Map<String, dynamic> j) => MyAdd(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    gender: j['gender'] as String? ?? 'Men',
    area: j['area'] as String? ?? '',
    status: j['status'] as String? ?? 'listed',
    source: j['source'] as String? ?? 'resident',
    partnerCode: j['partner_code'] as String?,
    rentMin: (j['rent_min'] as num?)?.toInt() ?? 0,
    rentMax: (j['rent_max'] as num?)?.toInt() ?? 0,
    createdAt: _t(j['created_at']) ?? DateTime.now(),
    ownerAskedAt: _t(j['owner_asked_at']),
    ownerAgreedAt: _t(j['owner_agreed_at']),
    liveAt: _t(j['live_at']),
    removed: j['removed'] == true,
    reward: (j['reward'] as num?)?.toInt(),
    payMonth: _t(j['pay_month']),
    paidAt: _t(j['paid_at']),
    upi: j['upi'] as String? ?? '',
    photos: (j['photos'] as num?)?.toInt() ?? 0,
    ownerName: j['owner_name'] as String? ?? '',
    ownerPhone: j['owner_phone'] as String? ?? '',
  );

  bool get partner => source == 'partner';
  bool get verified => status == 'live';

  /// 1 Added · 2 Owner asked · 3 Owner agreed · 4 Verified · 5 Paid.
  int get step => paidAt != null ? 5 : verified ? 4 : ownerAgreedAt != null ? 3 : ownerAskedAt != null ? 2 : 1;

  /// The reward the adder is in line for: ₹200 (resident) or ₹20 (partner).
  int get rewardDue => reward ?? (partner ? partnerReward : addReward);

  /// "Ask again" after 3 days; "Still waiting" at 60 days without the owner.
  bool get canAskAgain => ownerAskedAt != null && DateTime.now().difference(ownerAskedAt!).inDays >= 3;
  bool get stillWaiting => step < 3 && DateTime.now().difference(createdAt).inDays >= 60;

  /// Beyond this month's ₹2,000 cap: the reward is queued for [payMonth].
  bool get queued => payMonth != null && paidAt == null && (payMonth!.year > DateTime.now().year || (payMonth!.year == DateTime.now().year && payMonth!.month > DateTime.now().month));

  /// A listed card as tenants see it (S93 shows the same card).
  Hostel get asHostel => Hostel(id: id, name: name, gender: gender, area: area, from: rentMin, rating: 0, reviews: 0, food: false, ac: false, instant: false, owner: ownerName, reply: 0, mins: const {}, x: 50, y: 50, tags: const [], listed: !verified, rentMin: rentMin, rentMax: rentMax);
}

/// ₹ (DECISIONS 2026-10-18, hub; the founder can change them).
const addReward = 200, partnerReward = 20, addRewardCap = 2000;

/// The demo partner code (sample data only).
const demoPartnerCode = 'HZ-PART-1';

mixin _AddHostelData {
  AddDraft addDraft = AddDraft();

  /// "Already on Hostelzy: `name`" after a duplicate add (id, name).
  (String, String)? addDup;
  bool addBusy = false;

  /// The partner code typed once in S92, remembered on this phone.
  String partnerCodeSaved = '';

  /// S93: the adder's latest hostel; null when none (or not loaded yet).
  /// Demo: seeded once with the sample listed hostel at "Owner asked".
  MyAdd? _myAdd;
  bool _myAddAsked = false, _myAddSeeded = false;

  /// What's typed in S93's UPI field.
  String adderUpiDraft = '';

  /// The map pin (aPin) is placing the hostel being added, not a team draft.
  String pinFor = '';
}

/// The claim link the adder sends the owner: the UNVERIFIED page with the claim sheet open.
String claimLink(String hid) => '$webBase/r/?h=${Uri.encodeQueryComponent(hid)}&claim=1';

/// The nearest known area to a pin (the area is read off the pin).
String areaOfPin((double, double) c) {
  var best = areaLatLng.keys.first;
  var d = double.infinity;
  for (final e in areaLatLng.entries) {
    final k = kmBetween(e.value, c);
    if (k < d) {
      d = k;
      best = e.key;
    }
  }
  return best;
}

extension AddHostelActions on AppState {

  MyAdd? get myAdd {
    if (!_myAddSeeded) {
      _myAddSeeded = true;
      // Demo (F28 build note): one hostel "added by you" at step "Owner asked".
      if (AppState.samples && !data.remote) {
        final h = hostelById('balaji');
        _myAdd = MyAdd(id: h.id, name: h.name, gender: h.gender, area: h.area, status: 'listed', source: 'resident', rentMin: h.rentMin, rentMax: h.rentMax, createdAt: DateTime.now().subtract(const Duration(days: 5)), ownerAskedAt: DateTime.now().subtract(const Duration(days: 1)), ownerName: 'Balaji', ownerPhone: '9000000107');
      }
    }
    return _myAdd;
  }

  set myAdd(MyAdd? v) {
    _myAddSeeded = true;
    _myAdd = v;
  }

  /// Explore "Add it", Me "Add a hostel", My stay "Add my hostel": S92.
  void openAddPg() {
    if (!needSignIn('add', openAddPg)) return;
    update(() {
      addDraft = AddDraft()
        ..partnerCode = partnerCodeSaved
        ..partner = false;
      addDup = null;
    });
    go('addHostel');
  }

  /// Gate photos, 1–3, from the camera or the gallery.
  Future<void> addPickPhoto({bool camera = false}) async {
    if (addDraft.photos.length >= 3) return toastMsg('Three photos are enough.');
    final raw = camera ? await cameraPick(picker) : await picker.pick();
    if (raw == null) return;
    final jpg = prepPhoto(raw, '4:3');
    if (jpg == null) return toastMsg('That photo didn’t open. Try another one.');
    update(() => addDraft.photos.add(jpg));
  }

  void addRemovePhoto(int i) => update(() => addDraft.photos.removeAt(i));

  /// The pin: the same map as the team's (aPin), in 'add' mode.
  void openAddPin() => update(() {
    pinFor = 'add';
    pinNow = addDraft.pin ?? myPos ?? areaLatLng[mapArea] ?? areaLatLng['Madhapur']!;
    pinTouched = addDraft.pin != null;
    pinFocus++;
    hist = [...hist, screen];
    screen = 'aPin';
  });

  /// aPin "Save pin" in 'add' mode: the pin and the area read off it.
  void saveAddPin((double, double) c) {
    update(() {
      addDraft
        ..pin = c
        ..area = areaOfPin(c);
      pinFor = '';
    });
    back();
  }

  /// "Add": checks, dedupe, then the hostel is made as UNVERIFIED.
  Future<void> submitAdd() async {
    final d = addDraft;
    final name = d.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final phone = d.ownerPhone.replaceAll(RegExp(r'\D'), '');
    final rent = int.tryParse(d.rent) ?? 0, rentMax = d.partner ? (int.tryParse(d.rentMax) ?? 0) : rent;
    if (name.length < 2) return toastMsg('Add the hostel’s name.');
    if (d.photos.isEmpty) return toastMsg('Add a photo of the gate.');
    if (d.pin == null) return toastMsg('Drop the pin on the gate.');
    if (rent < 1000 || rent > 100000) return toastMsg(d.partner ? 'Add the rent range (₹1,000 or more).' : 'What do you pay a month? ₹1,000 or more.');
    if (d.partner && rentMax < rent) return toastMsg('The top of the range can’t be below the bottom.');
    if (d.ownerName.trim().length < 2) return toastMsg('Add the owner’s name.');
    if (!AppState.validPhone(phone)) return toastMsg('Add the owner’s 10-digit phone (6–9 first).');
    final code = d.partner ? d.partnerCode.trim().toUpperCase() : '';
    if (d.partner && code.isEmpty) return toastMsg('Enter your partner code.');
    if (addBusy) return;
    update(() {
      addBusy = true;
      addDup = null;
    });
    if (!data.remote) {
      _submitAddSample(name, phone, rent, rentMax, code);
      return;
    }
    try {
      final r = await data.addHostel({
        'name': name,
        'gender': d.gender,
        'lat': d.pin!.$1,
        'lng': d.pin!.$2,
        'area': d.area,
        if (d.partner) 'rent_min': rent else 'rent': rent,
        if (d.partner) 'rent_max': rentMax,
        'share': d.share,
        'food': d.food,
        'owner_name': d.ownerName.trim(),
        'owner_phone': phone,
        if (d.partner) 'partner_code': code,
      });
      if (r['duplicate'] == true) {
        update(() {
          addBusy = false;
          addDup = (r['hostel_id'] as String, r['name'] as String? ?? 'this hostel');
        });
        return;
      }
      final hid = r['hostel_id'] as String;
      // The gate photos, the first as the cover. One failing never loses the hostel.
      for (final (i, jpg) in d.photos.indexed) {
        try {
          await data.addPhoto(hid, jpg, label: 'Gate', ord: i, cover: i == 0);
        } catch (e) {
          debugPrint('add photo: $e');
        }
      }
      if (d.partner) update(() => partnerCodeSaved = code);
      await loadMyAdd(force: true);
      unawaited(refreshListings());
      update(() {
        addBusy = false;
        screen = 'myAdd';
        hist = [homeTab];
        sheet = null;
      });
      toastMsg('Added as unverified.');
    } catch (e) {
      debugPrint('add hostel: $e');
      update(() => addBusy = false);
      final m = '$e';
      toastMsg(m.contains('partner code')
          ? 'That partner code isn’t valid. Check it with the Hostelzy team.'
          : m.contains('in progress')
          ? 'One hostel at a time. See Me › Your hostel.'
          : m.contains('pin')
          ? 'The pin isn’t in Hyderabad. Move it to the gate.'
          : 'Couldn’t add it. Check your internet and try again.');
    }
  }

  /// Demo and tests: the dedupe and the new listed card on this phone.
  void _submitAddSample(String name, String phone, int rent, int rentMax, String code) {
    if (code.isNotEmpty && code != demoPartnerCode) {
      update(() => addBusy = false);
      return toastMsg('That partner code isn’t valid. Check it with the Hostelzy team.');
    }
    // The demo seed never blocks trying Add a hostel in the demo APK.
    if (code.isEmpty && myAdd != null && !myAdd!.verified && myAdd!.id != 'balaji') {
      update(() => addBusy = false);
      return toastMsg('One hostel at a time. See Me › Your hostel.');
    }
    String key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final dup = hostels.where((h) => (ownerPhones[h.id] == phone) || (key(h.name) == key(name) && kmBetween(posOf(h), addDraft.pin!) <= .15)).firstOrNull;
    if (dup != null) {
      update(() {
        addBusy = false;
        addDup = (dup.id, dup.name);
      });
      return;
    }
    final id = 'add${DateTime.now().millisecondsSinceEpoch}';
    final d = addDraft;
    hostels.add(Hostel(id: id, name: name, gender: d.gender, area: d.area, from: rent, rating: 0, reviews: 0, food: d.food, ac: false, instant: false, owner: d.ownerName.trim(), reply: 0, mins: const {}, x: 50, y: 50, tags: const [], listed: true, rentMin: rent, rentMax: rentMax));
    rooms[id] = [];
    rates[id] = {};
    livePos[id] = d.pin!;
    ownerPhones[id] = phone;
    if (code.isNotEmpty) partnerCodeSaved = code;
    myAdd = MyAdd(id: id, name: name, gender: d.gender, area: d.area, status: 'listed', source: code.isEmpty ? 'resident' : 'partner', partnerCode: code.isEmpty ? null : code, rentMin: rent, rentMax: rentMax, createdAt: DateTime.now(), photos: d.photos.length, ownerName: d.ownerName.trim(), ownerPhone: phone);
    update(() {
      addBusy = false;
      screen = 'myAdd';
      hist = [homeTab];
      sheet = null;
    });
    toastMsg('Added as unverified.');
  }

  /// The duplicate's claim link, for the adder to pass to their owner.
  void shareDup() {
    final d = addDup;
    if (d == null) return;
    share('${d.$2} is already on Hostelzy. Owner: agree to get it verified (free): ${claimLink(d.$1)}');
  }

  /// Me › Your hostel: S93.
  void openMyAdd() {
    go('myAdd');
    unawaited(loadMyAdd(force: true));
  }

  /// `my_added_hostel()` once per sign-in (or on demand).
  Future<void> loadMyAdd({bool force = false}) async {
    if (!data.remote || account == null || (_myAddAsked && !force)) return;
    _myAddAsked = true;
    try {
      final j = await data.myAddedHostel();
      update(() => myAdd = j == null ? null : MyAdd.fromJson(j));
    } catch (e) {
      debugPrint('my add: $e');
    }
  }

  /// S93 "Send to your owner" / "Ask again": WhatsApp from the adder's phone,
  /// with the claim link. The step "Owner asked" is stamped on the server.
  void sendToOwner() {
    final a = myAdd;
    if (a == null) return;
    whatsapp(a.ownerPhone, 'Your PG ${a.name} is on Hostelzy. Agree to get it verified (free): ${claimLink(a.id)}');
    update(() => a.ownerAskedAt = DateTime.now());
    if (data.remote && !isSeedHostel(a.id)) {
      data.askedOwner(a.id).then((_) {}, onError: (Object e) => debugPrint('asked owner: $e'));
    }
  }

  /// S93: the UPI id for the payout, asked once after the owner agrees.
  Future<void> saveAdderUpi() async {
    final a = myAdd;
    final u = adderUpiDraft.trim();
    if (a == null) return;
    if (!RegExp(r'^[A-Za-z0-9._-]{2,}@[A-Za-z][A-Za-z0-9]+$').hasMatch(u)) return toastMsg('Enter your UPI id, like name@upi.');
    if (data.remote) {
      try {
        await data.setAdderUpi(u);
      } catch (e) {
        debugPrint('adder upi: $e');
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
    }
    update(() {
      a.upi = u;
      adderUpiDraft = '';
    });
    toastMsg('UPI id saved.');
  }

  /// Deep link `app/r/?h=<id>&claim=1` (the adder's message to the owner): the
  /// UNVERIFIED page with "Claim this hostel" open.
  void openClaimLink(String id) {
    final h = hostels.where((x) => x.id == id).firstOrNull;
    if (h == null) return toastMsg(listState == 'loading' ? 'Loading hostels… open the link again in a moment.' : 'That hostel isn’t on Hostelzy any more.');
    update(() {
      role = role == 'owner' ? 'tenant' : role;
      inFindBed = false;
      hid = h.id;
      screen = 'detail';
      hist = [homeTab];
      sheet = null;
    });
    if (h.listed) openClaim(h);
  }
}
