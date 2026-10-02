part of '../../state.dart';

// F20 Reminders: water, my own reminders and hostel reminders (meal times,
// rent due). They ring from this phone (lib/reminders.dart); settings are
// saved on the phone with the rest of the snapshot.
mixin _RemindersData {
  /// Local notifications ([NoReminders] in tests, web, desktop).
  Reminders rem = NoReminders();

  WaterPlan water = const WaterPlan();
  List<MyReminder> myRems = [];
  bool remMeals = true, remRent = true;

  /// The first-time offer ("Want water reminders?") was shown.
  bool remOffered = false;

  /// Glasses today (a "Done" on the notification counts too).
  int glasses = 0;

  /// Water sheet draft.
  WaterPlan? waterDraft;

  /// Add-a-reminder sheet: editing [remEdit] (null: a new one).
  String? remEdit;
  String remName = '', remRepeat = 'daily';
  int remAt = 21 * 60;
  Set<int> remDays = {};
}

/// Quick add: name and a sensible time.
const quickRems = [('Medicine', 'Take medicine', 21 * 60), ('Lunch', 'Lunch', 13 * 60), ('Walk', 'Go for a walk', 18 * 60 + 30), ('Sleep on time', 'Sleep on time', 22 * 60), ('Call home', 'Call home', 19 * 60)];

/// Water: how often (minutes).
const waterEvery = [20, 30, 45, 60, 90, 120];

/// A user can keep this many of their own reminders.
const maxMyRems = 20;

extension RemindersActions on AppState {
  Map<String, dynamic> remJson() => {
    'water': water.toJson(),
    'mine': [for (final r in myRems) r.toJson()],
    'meals': remMeals,
    'rent': remRent,
    'offered': remOffered,
  };

  void restoreRem(Map<String, dynamic>? m) {
    if (m == null) return;
    water = WaterPlan.fromJson(m['water'] as Map<String, dynamic>?);
    myRems = [for (final r in (m['mine'] as List? ?? const []).cast<Map<String, dynamic>>()) MyReminder.fromJson(r)];
    remMeals = m['meals'] as bool? ?? true;
    remRent = m['rent'] as bool? ?? true;
    remOffered = m['offered'] as bool? ?? false;
  }

  /// App start: plug in the phone's notifications, bring back today's
  /// glasses and schedule everything again (also after an app update).
  Future<void> startReminders(Reminders r) async {
    rem = r;
    r.onOpen(_openFromReminder);
    await refreshGlasses();
    // Not a change by the user: never overwrite the backup from here.
    await rem.apply(rings);
  }

  void _openFromReminder(String kind) {
    if (!signedIn) return;
    switch (kind) {
      case 'meal' when role == 'resident':
        tab('food');
      case 'rent' when role == 'resident':
        tab('rPay');
      default:
        if (screen != 'reminders') go('reminders');
    }
  }

  Future<void> refreshGlasses() async {
    final n = await rem.glasses();
    if (n != glasses) update(() => glasses = n);
  }

  /// The resident's hostel for hostel reminders (null: not a resident here).
  String? get remHostel => role != 'resident' ? null : (onServer ? myHostel : (AppState.samples ? 'anjani' : null));

  /// Inside the awake hours (the end included for my own reminders).
  bool awake(int minute, {bool end = false}) => minute >= water.from && (end ? minute <= water.to : minute < water.to);

  /// Rent due day for the resident ([appToday] or later).
  DateTime get rentDue {
    final d = hostelById(remHostel ?? 'anjani').terms.dueDay(residentJoinDay);
    final t = appToday;
    final x = DateTime(t.year, t.month, d);
    return x.isBefore(t) ? DateTime(t.year, t.month + 1, d) : x;
  }

  /// Everything that should ring, for [Reminders.apply].
  List<Ring> get rings {
    final out = <Ring>[];
    if (water.on) {
      final s = water.slots;
      for (var i = 0; i < s.length; i++) {
        out.add(Ring(id: 1000 + i, kind: 'water', minute: s[i], title: 'Time for a glass of water', body: 'Goal: ${water.goal} glasses a day. Tap Done when you’ve had it.'));
      }
    }
    for (var i = 0; i < myRems.length; i++) {
      final r = myRems[i];
      if (!r.on) continue;
      final id = 2000 + i * 8;
      const body = 'Tap Done when it’s done.';
      if (r.repeat == 'once') {
        if (r.onceAt != null) out.add(Ring(id: id, kind: 'mine', title: r.name, body: body, at: DateTime.fromMillisecondsSinceEpoch(r.onceAt!)));
      } else if (r.weekdays.isEmpty) {
        out.add(Ring(id: id, kind: 'mine', minute: r.at, title: r.name, body: body));
      } else {
        for (final d in r.weekdays) {
          out.add(Ring(id: id + d, kind: 'mine', minute: r.at, weekday: d, title: r.name, body: body));
        }
      }
    }
    final hid = remHostel;
    if (hid != null) {
      final h = hostelById(hid);
      if (remMeals && h.food) {
        for (final (k, name, at, end) in mealRings) {
          out.add(Ring(id: 3000 + k, kind: 'meal', minute: at, title: '$name is served till $end', body: 'See today’s menu in Hostelzy.'));
        }
      }
      if (remRent) {
        final due = rentDue;
        final at = math.max(9 * 60, water.from);
        final amt = AppState.samples && !onServer ? payments.where((x) => x.id == 'rent204B').firstOrNull?.amt : null;
        final body = '${amt != null ? '${fmt(amt)} to ${h.owner}' : 'Pay ${h.owner.isEmpty ? 'your owner' : h.owner}'} by ${dayMon(due)}';
        for (final (i, before) in [(0, 3), (1, 0)]) {
          final d = due.subtract(Duration(days: before));
          out.add(Ring(id: 4000 + i, kind: 'rent', title: before == 0 ? 'Rent due today' : 'Rent due in $before days', body: body, at: DateTime(d.year, d.month, d.day, at ~/ 60, at % 60)));
        }
      }
    }
    return out;
  }

  /// Meal reminders inside the awake hours: (index, meal, start, served till).
  List<(int, String, int, String)> get mealRings => [
    for (final (k, name, at, end) in const [(0, 'Breakfast', 7 * 60 + 30, '9:30 am'), (1, 'Lunch', 12 * 60 + 30, '2 pm'), (2, 'Dinner', 20 * 60, '10 pm')])
      if (awake(at, end: true)) (k, name, at, end),
  ];

  /// "From the food menu · lunch 12:30, dinner 8:00" (only what rings).
  String get mealLine {
    final m = mealRings;
    if (m.isEmpty) return 'From the food menu · none inside your awake hours';
    return 'From the food menu · ${m.map((x) => '${x.$2.toLowerCase()} ${clock(x.$3).replaceAll(RegExp(r' [ap]m'), '')}').join(', ')}';
  }

  Future<void> _reschedule() async {
    await rem.apply(rings);
    _backupRem();
  }

  /// Signed in on the server: the settings are backed up on the profile.
  Future<void> _backupRem() async {
    final a = account;
    if (!data.remote || a == null) return;
    try {
      await data.saveReminders(a.uid, remJson());
    } catch (e) {
      debugPrint('Reminders backup: $e');
    }
  }

  /// A new phone (nothing set here yet) gets the backed-up settings back.
  Future<void> restoreRemFromServer() async {
    final a = account;
    if (!data.remote || a == null || water.on || myRems.isNotEmpty) return;
    try {
      final m = await data.loadReminders(a.uid);
      if (m == null || water.on || myRems.isNotEmpty) return;
      update(() => restoreRem(m));
      await rem.apply(rings);
    } catch (e) {
      debugPrint('Reminders restore: $e');
    }
  }

  /// Next glass after [now] (minute of the day), null when off or done for today.
  int? nextGlass([DateTime? now]) {
    if (!water.on) return null;
    final n = now ?? DateTime.now();
    final m = n.hour * 60 + n.minute;
    return water.slots.where((t) => t > m).firstOrNull;
  }

  /// My next reminder later today: (name, minute).
  (String, int)? nextMine([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.hour * 60 + n.minute;
    final today = [
      for (final r in myRems)
        if (r.on && r.at > m && (r.repeat == 'once' ? r.onceAt != null && Glasses.today(DateTime.fromMillisecondsSinceEpoch(r.onceAt!)) == Glasses.today(n) : r.weekdays.isEmpty || r.weekdays.contains(n.weekday))) (r.name, r.at),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return today.firstOrNull;
  }

  /// The Today card shows while something is on.
  bool get showToday => water.on || nextMine() != null;

  /// Me row: "water every 30 min" / "2 on" / "off".
  String get remSummary {
    if (water.on) return 'water every ${everyLabel(water.every)}';
    final n = myRems.where((r) => r.on).length;
    return n == 0 ? 'off' : '$n on';
  }

  static String everyLabel(int m) => m >= 120 ? '${m ~/ 60} hours' : '$m min';

  /// "8 am – 10 pm"
  String get awakeLabel => '${clock(water.from, short: true)} – ${clock(water.to, short: true)}';

  void openReminders() {
    go('reminders');
    refreshGlasses();
  }

  /// Turning water on asks for notifications first if Android has them off.
  Future<void> toggleWater() async {
    if (water.on) {
      update(() => water = water.copyWith(on: false));
      await _reschedule();
      return toastMsg('Water reminders off.');
    }
    await _turnOnWater();
  }

  Future<void> _turnOnWater() async {
    if (osPushAllowed != true && rem.available) await enablePush();
    update(() => water = water.copyWith(on: true));
    await _reschedule();
    toastMsg(rem.available ? 'Water reminders on: every ${everyLabel(water.every)}, $awakeLabel.' : 'Saved. Reminders ring in the Android app.');
  }

  void openWater() => update(() {
    waterDraft = water;
    sheet = 'water';
  });

  void editWater(WaterPlan Function(WaterPlan w) f) => update(() => waterDraft = f(waterDraft ?? water));

  Future<void> saveWater() async {
    final d = waterDraft ?? water;
    if (d.to - d.from < 60) return toastMsg('Awake hours need at least an hour.');
    update(() {
      water = d.copyWith(on: true);
      waterDraft = null;
      sheet = null;
    });
    if (osPushAllowed != true && rem.available) await enablePush();
    await _reschedule();
    toastMsg('Saved: every ${everyLabel(water.every)}, $awakeLabel.');
  }

  Future<void> addGlass() async {
    update(() => glasses++);
    await rem.setGlasses(glasses);
  }

  void openAddRem([MyReminder? r]) => update(() {
    remEdit = r?.id;
    remName = r?.name ?? '';
    remAt = r?.at ?? 21 * 60;
    remRepeat = r?.repeat ?? 'daily';
    remDays = {...?r?.days};
    sheet = 'addRem';
  });

  void quickRem((String, String, int) q) => update(() {
    remName = q.$2;
    remAt = q.$3;
  });

  Future<void> saveRem() async {
    final name = remName.trim();
    if (name.isEmpty) return toastMsg('Give it a name.');
    if (remRepeat == 'days' && remDays.isEmpty) return toastMsg('Pick at least one day.');
    if (remEdit == null && myRems.length >= maxMyRems) return toastMsg('You can keep $maxMyRems reminders. Delete one first.');
    if (!awake(remAt, end: true)) return toastMsg('That’s outside your awake hours ($awakeLabel). Change them under Drink water first.');
    int? onceAt;
    if (remRepeat == 'once') {
      final n = DateTime.now();
      var t = DateTime(n.year, n.month, n.day, remAt ~/ 60, remAt % 60);
      if (!t.isAfter(n)) t = t.add(const Duration(days: 1));
      onceAt = t.millisecondsSinceEpoch;
    }
    final r = MyReminder(id: remEdit ?? 'r${DateTime.now().microsecondsSinceEpoch}', name: name, at: remAt, repeat: remRepeat, days: remRepeat == 'days' ? remDays : const {}, onceAt: onceAt);
    final editing = remEdit != null;
    update(() {
      myRems = editing ? [for (final x in myRems) x.id == r.id ? r : x] : [...myRems, r];
      sheet = null;
      remEdit = null;
    });
    if (osPushAllowed != true && rem.available) await enablePush();
    await _reschedule();
    toastMsg('${editing ? 'Saved' : 'Added'}: $name at ${clock(r.at)}, ${repeatLabel(r)}.');
  }

  Future<void> deleteRem(String id) async {
    update(() {
      myRems = myRems.where((r) => r.id != id).toList();
      sheet = null;
      remEdit = null;
    });
    await _reschedule();
    toastMsg('Reminder deleted.');
  }

  Future<void> toggleRem(String id) async {
    update(() => myRems = [for (final r in myRems) r.id == id ? r.copyWith(on: !r.on) : r]);
    await _reschedule();
  }

  Future<void> toggleHostelRem(String k) async {
    update(() => k == 'meals' ? remMeals = !remMeals : remRent = !remRent);
    await _reschedule();
  }

  /// "every day", "weekdays", "Sundays", "Mon, Wed", "once".
  static String repeatLabel(MyReminder r) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return switch (r.repeat) {
      'once' => 'once',
      'weekdays' => 'weekdays',
      'days' when r.days.length == 1 => const ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'][r.days.first - 1],
      'days' => ([...r.days]..sort()).map((d) => names[d - 1]).join(', '),
      _ => 'every day',
    };
  }

  /// First-time offer, once after sign-in, where reminders can ring.
  void maybeOfferReminders() {
    if (!rem.available || remOffered || !signedIn || sheet != null || screen != homeOf[role]) return;
    update(() {
      remOffered = true;
      sheet = 'waterOffer';
    });
  }

  Future<void> acceptOffer() async {
    update(() => sheet = null);
    await _turnOnWater();
  }
}
