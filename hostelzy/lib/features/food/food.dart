part of '../../state.dart';

// The food menu on the server (`menus`, one row per weekday): the owner types
// the week and saves it; residents see it in Food and on Home; tenants see a
// peek on the hostel page. Breakfast ratings are counted without names.
mixin _FoodData {
  /// Each hostel's week, Monday first: the sample week for Anjani in demo
  /// builds, what the server has otherwise.
  Map<String, List<DayMenu>> menus = AppState.samples ? {'anjani': List.of(seedMenu)} : {};

  /// Owner's Food menu page: the week being typed, and whether it changed
  /// since it was opened or saved.
  List<DayMenu>? menuDraft;
  bool menuDirty = false;

  /// A week typed on this phone before menus were on the server (F18). The
  /// editor starts from it until it is saved.
  List<DayMenu>? phoneMenu;

  /// The hostel a tenant opened the Food menu sheet for, and its day.
  String? foodFor;
  int fwDay = 0;

  /// Owner: this week's breakfast / lunch / dinner ratings, counts only.
  Map<String, Map<String, int>> mealVotes = AppState.samples ? {'b': {'good': 9, 'okay': 3, 'poor': 1}} : {};
}

/// A week with nothing typed yet.
final blankWeek = List<DayMenu>.unmodifiable([for (var i = 0; i < 7; i++) const DayMenu('', '', '')]);

bool weekEmpty(List<DayMenu> m) => m.every((d) => '${d.b}${d.l}${d.n}'.trim().isEmpty);

extension FoodActions on AppState {
  /// A hostel's menu, or null when it has none.
  List<DayMenu>? menuOf(String hid) {
    final m = menus[hid];
    return m == null || weekEmpty(m) ? null : m;
  }

  /// The hostel Food shows: a resident's own, or the one a tenant opened.
  String get foodHid => role == 'resident' ? stayHostel.id : (foodFor ?? hid);

  /// The week Food and Home show (blank when there is none).
  List<DayMenu> get menu => menuOf(foodHid) ?? blankWeek;

  /// Fetches a hostel's menu from the server (every time a screen with it
  /// opens, so an owner's change shows straight away).
  Future<void> loadMenu(String hid) async {
    if (!data.remote) return;
    try {
      final m = await data.menu(hid);
      update(() => m == null ? menus.remove(hid) : menus[hid] = m);
    } catch (e) {
      debugPrint('menu: $e');
    }
  }

  /// Tenant: the whole week of a hostel's food, from its page (a sheet).
  void openFoodFor(String h) => update(() {
    foodFor = h;
    fwDay = todayIdx;
    sheet = 'foodWeek';
  });

  /// Owner: Manage › Food menu. Starts from the saved week (or one typed on
  /// this phone before), then from the server's once it arrives.
  void openMenu() {
    update(() {
      moreTab = 'menu';
      _fillMenuDraft();
    });
    final h = ownHid;
    loadMenu(h).then((_) {
      if (!menuDirty && ownHid == h) update(_fillMenuDraft);
    });
    loadMealVotes(h);
  }

  void _fillMenuDraft() {
    if (menuDirty && menuDraft != null) return;
    final saved = menuOf(ownHid);
    menuDraft = List.of(saved ?? phoneMenu ?? blankWeek);
    menuDirty = saved == null && phoneMenu != null && !weekEmpty(phoneMenu!);
  }

  void setMenuMeal(int d, String meal, String v) => update(() {
    final m = List.of(menuDraft ?? blankWeek);
    m[d] = m[d].withMeal(meal, v);
    menuDraft = m;
    menuDirty = true;
  });

  void copyMenuDay(int from, int to) => update(() {
    final m = List.of(menuDraft ?? blankWeek);
    m[to] = m[from];
    menuDraft = m;
    menuDirty = true;
  });

  /// Saves the week for the owner's hostel; residents see it the next time
  /// Food or Home opens.
  Future<void> saveMenu() async {
    final week = List.of(menuDraft ?? blankWeek), h = ownHid;
    void done() {
      update(() {
        menus[h] = week;
        menuDirty = false;
        phoneMenu = null;
        moreTab = 'home';
      });
      toastMsg(weekEmpty(week) ? 'Menu cleared. Residents see “no menu yet”.' : 'Menu saved. Residents see it in their Food tab now.');
    }

    if (onServer) {
      if (await _write(() => data.saveMenu(h, week))) done();
      return;
    }
    done();
  }

  /// Resident: how a meal went today, Good / Okay / Poor. The owner sees counts,
  /// never who.
  Future<void> rateMeal(String meal, String v) async {
    final before = rated;
    update(() => rated = v);
    if (onServer) {
      try {
        await data.rateMeal(stayHostel.id, meal, v.toLowerCase());
      } catch (e) {
        debugPrint('rate: $e');
        update(() => rated = before);
        return toastMsg('Couldn’t save it. Check your internet and try again.');
      }
    } else {
      update(() {
        final c = mealVotes.putIfAbsent(meal, () => {});
        if (before != null) c[before.toLowerCase()] = math.max(0, (c[before.toLowerCase()] ?? 0) - 1);
        c[v.toLowerCase()] = (c[v.toLowerCase()] ?? 0) + 1;
      });
    }
    toastMsg('Thanks. $stayOwner sees how many said $v, not who.');
  }

  /// Owner: this week's rating counts for their hostel.
  Future<void> loadMealVotes(String hid) async {
    if (!data.remote) return;
    try {
      final v = await data.mealVotes(hid);
      update(() => mealVotes = v);
    } catch (e) {
      debugPrint('votes: $e');
    }
  }
}
