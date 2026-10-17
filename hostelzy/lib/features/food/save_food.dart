part of '../../state.dart';

// F27 Save food: before each meal a resident taps Eating or Skip (no answer =
// eating). The count closes the owner's 2 / 3 / 4 h before the meal; after
// that the answer is locked (the server says no too). The owner sees the
// headcount and who is skipping; everyone sees plates saved (1 skip whose
// count closed = 1 plate). Real numbers only; the demo build has samples.
mixin _SaveFoodData {
  /// Each hostel's meals board (the server's; the sample Anjani one in demo
  /// builds). Missing: not loaded, or the server has no Save food yet.
  Map<String, FoodBoard> foodBoards = AppState.samples ? {'anjani': sampleFoodBoard(DateTime(appToday.year, appToday.month, appToday.day))} : {};

  /// Plates saved per live hostel, for the hostel page chip.
  Map<String, int> hostelPlates = AppState.samples ? {'anjani': 412} : {};

  /// Tests: a fixed "now" for cut-offs.
  DateTime? foodClock;
}

/// What a tap on a meal ask notification means (`food|hostel|day|meal|action`).
typedef FoodTap = ({String hid, String day, String meal, String action});

FoodTap? parseFoodTap(String s) {
  final p = s.split('|');
  if (p.length != 5 || p.first != 'food' || !const ['b', 'l', 'n'].contains(p[3])) return null;
  return (hid: p[1], day: p[2], meal: p[3], action: p[4]);
}

/// "Breakfast", "Lunch", "Dinner".
String mealWord(String k) => const {'b': 'Breakfast', 'l': 'Lunch', 'n': 'Dinner'}[k]!;

extension SaveFoodActions on AppState {
  /// Now, India time: the real clock in the Play Store build; 2:30 pm on the
  /// sample day in debug builds and tests (so the samples line up).
  DateTime get foodNow {
    if (foodClock != null) return foodClock!;
    if (const bool.fromEnvironment('dart.vm.product')) {
      final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateTime(n.year, n.month, n.day, n.hour, n.minute);
    }
    return DateTime(appToday.year, appToday.month, appToday.day, 14, 30);
  }

  DateTime get foodToday => DateTime(foodNow.year, foodNow.month, foodNow.day);

  /// Today and the next 6 days.
  List<DateTime> get foodWeek => [for (var i = 0; i < 7; i++) DateTime(foodToday.year, foodToday.month, foodToday.day + i)];

  FoodBoard? foodOf(String hid) => foodBoards[hid];

  /// Does this hostel serve food (on its listing or with a menu)?
  bool servesFood(String hid) => hostelById(hid).food || menuOf(hid) != null;

  /// When a meal starts (the owner's meal time, else the usual one).
  DateTime mealAt(String hid, DateTime day, String k) => DateTime(day.year, day.month, day.day).add(Duration(minutes: (mealTimeOf(hid, k) ?? usualMealTimes[k]!).$1));

  /// When its count closes: [FoodBoard.cutoff] hours before.
  DateTime cutoffAt(String hid, DateTime day, String k) => mealAt(hid, day, k).subtract(Duration(hours: foodOf(hid)?.cutoff ?? 3));

  bool mealOpen(String hid, DateTime day, String k) => foodNow.isBefore(cutoffAt(hid, day, k));

  /// The resident's answer (no answer = eating).
  bool eatingAt(String hid, DateTime day, String k) => foodOf(hid)?.mine[mealKey(day, k)] ?? true;

  /// (residents, skipping) for a meal.
  (int, int) countAt(String hid, DateTime day, String k) => foodOf(hid)?.counts[mealKey(day, k)] ?? (0, 0);

  /// The resident's next meal they can still answer for.
  (DateTime, String)? nextOpenMeal(String hid) {
    for (final d in foodWeek) {
      for (final k in const ['b', 'l', 'n']) {
        if (mealOpen(hid, d, k)) return (d, k);
      }
    }
    return null;
  }

  /// The owner's next meal not yet served (its count may have closed).
  (DateTime, String) headcountMeal(String hid) {
    for (final d in foodWeek.take(2)) {
      for (final k in const ['b', 'l', 'n']) {
        if (mealAt(hid, d, k).isAfter(foodNow)) return (d, k);
      }
    }
    return (foodWeek[1], 'b');
  }

  /// "Dinner tonight", "Lunch today", "Breakfast tomorrow", "Lunch on Sat".
  String mealWhen(DateTime d, String k) {
    final days = d.difference(foodToday).inDays;
    final w = mealWord(k);
    if (days == 0) return k == 'n' ? '$w tonight' : '$w today';
    if (days == 1) return '$w tomorrow';
    return '$w on ${dayName(d).split(' ').first}';
  }

  /// "5:00 pm".
  String foodClockText(DateTime t) => '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';

  /// Plates the resident is skipping in the 7-day plan (planned, not yet saved).
  int get plannedSkips {
    final h = stayHostel.id;
    var n = 0;
    for (final d in foodWeek) {
      for (final k in const ['b', 'l', 'n']) {
        if (!eatingAt(h, d, k)) n++;
      }
    }
    return n;
  }

  /// Fetches the hostel's meals (every time a Save food screen opens).
  Future<void> loadFood(String hid) async {
    if (!data.remote) return;
    try {
      final b = await data.foodBoard(hid, foodToday, 7);
      update(() => b == null ? foodBoards.remove(hid) : foodBoards[hid] = b);
    } catch (e) {
      debugPrint('food: $e');
    }
  }

  /// Plates saved by a hostel, for its page.
  Future<void> loadPlates(String hid) async {
    if (!data.remote) return;
    try {
      final n = (await data.hostelPlates([hid]))[hid] ?? 0;
      if (n != (hostelPlates[hid] ?? 0)) update(() => hostelPlates[hid] = n);
    } catch (e) {
      debugPrint('plates: $e');
    }
  }

  /// Saves the resident's answers ([mealKey] → eating). Closed meals are
  /// left out; the screen changes at once and goes back if the server says no.
  Future<void> answerMeals(String hid, Map<String, bool> answers, {String? done}) async {
    final b = foodOf(hid);
    if (b == null) return;
    final open = {
      for (final e in answers.entries)
        if (mealOpen(hid, mealOfKey(e.key).$1, mealOfKey(e.key).$2)) e.key: e.value,
    };
    if (open.isEmpty) return toastMsg('The count for that meal has closed. Your answer counts from the next meal.');
    update(() => foodBoards[hid] = b.answer(open));
    if (data.remote) {
      try {
        await data.answerMeals(hid, open);
      } catch (e) {
        debugPrint('answer meals: $e');
        update(() => foodBoards[hid] = b);
        return toastMsg(
          '$e'.contains('has closed') ? 'The count for that meal has closed. Your answer counts from the next meal.' : 'Couldn’t save it. Check your internet and try again.',
        );
      }
      unawaited(loadFood(hid));
    }
    if (done != null) toastMsg(done);
  }

  /// Home card and the notification: Eating or Skip for one meal.
  Future<void> setEating(String hid, DateTime d, String k, bool eating) => answerMeals(
    hid,
    {mealKey(d, k): eating},
    done: eating ? 'You’re eating ${mealWord(k).toLowerCase()}.' : '${mealWord(k)} skipped. The kitchen cooks one plate less.',
  );

  /// Week plan: tap a meal to switch between eating and skip.
  Future<void> toggleMeal(String hid, DateTime d, String k) {
    if (!mealOpen(hid, d, k)) {
      toastMsg('The count for ${mealWord(k).toLowerCase()} on ${dayName(d).split(' ').first} has closed.');
      return Future.value();
    }
    return answerMeals(hid, {mealKey(d, k): !eatingAt(hid, d, k)});
  }

  /// The open weekend meals in the 7-day plan.
  List<String> weekendKeys(String hid) => [
    for (final d in foodWeek.where((d) => d.weekday >= 6))
      for (final k in const ['b', 'l', 'n'])
        if (mealOpen(hid, d, k)) mealKey(d, k),
  ];

  /// Is every open weekend meal already a skip?
  bool weekendSkipped(String hid) {
    final ks = weekendKeys(hid);
    return ks.isNotEmpty && ks.every((k) => foodOf(hid)?.mine[k] == false);
  }

  /// "Skip all weekend" (going home); again: eating all weekend.
  Future<void> skipWeekend(String hid) {
    final ks = weekendKeys(hid);
    if (ks.isEmpty) {
      toastMsg('This weekend’s counts have closed.');
      return Future.value();
    }
    final eat = weekendSkipped(hid);
    return answerMeals(hid, {for (final k in ks) k: eat}, done: eat ? 'Eating all weekend.' : 'Weekend skipped: ${ks.length} meals. The kitchen cooks for the rest.');
  }

  /// Resident: Plan the week (S90).
  void openWeekPlan() {
    go('rMeals');
    loadFood(stayHostel.id);
  }

  /// Owner: Meals (S91), from Manage or the Today card.
  void openMeals() {
    go('oMeals');
    loadFood(ownHid);
  }

  /// Owner: the count closes 2, 3 or 4 h before each meal.
  Future<void> setMealCutoff(int hours) async {
    final h = ownHid, b = foodOf(h);
    if (b == null || b.cutoff == hours) return;
    update(() => foodBoards[h] = b.copyWith(cutoff: hours));
    if (data.remote) {
      try {
        await data.setMealCutoff(h, hours);
      } catch (e) {
        debugPrint('cutoff: $e');
        update(() => foodBoards[h] = b);
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
      unawaited(loadFood(h));
    }
    toastMsg('The count now closes $hours h before each meal. Residents see the new time.');
  }

  /// A tap on "Dinner at 8 · Eating?" (or its Eating / Skip button).
  Future<void> openFoodTap(FoodTap t) async {
    if (!signedIn || role != 'resident') return;
    tab('rHome');
    if (t.action != 'eat' && t.action != 'skip') return;
    if (stayHostel.id != t.hid) return;
    if (foodOf(t.hid) == null) await loadFood(t.hid);
    final (d, k) = mealOfKey('${t.day}|${t.meal}');
    await setEating(t.hid, d, k, t.action == 'eat');
  }
}
