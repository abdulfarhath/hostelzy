// F27 Save food: "Are you eating?" per meal, the owner's headcount, plates
// saved. Pure models and helpers; the state is in features/food/save_food.dart.

/// "2026-10-01" (the server's `date`).
String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One meal on one day: "2026-10-01|n".
String mealKey(DateTime d, String meal) => '${ymd(d)}|$meal';

/// The day and meal of a [mealKey] (or of "2026-10-01" + meal).
(DateTime, String) mealOfKey(String k) {
  final p = k.split('|'), d = p.first.split('-');
  return (DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2])), p.last);
}

/// Plates saved (1 skip whose count has closed = 1 plate): the resident this
/// week and in all, the hostel this month and in all, and all of Hostelzy.
typedef PlatesSaved = ({int youWeek, int you, int hostelMonth, int hostel, int hostelzy});

const noPlates = (youWeek: 0, you: 0, hostelMonth: 0, hostel: 0, hostelzy: 0);

/// F27: one hostel's meals as the server keeps them. No answer = eating.
class FoodBoard {
  const FoodBoard({this.cutoff = 3, this.counts = const {}, this.mine = const {}, this.saved = noPlates, this.skippers = const []});

  /// How many hours before a meal its count closes (2, 3 or 4).
  final int cutoff;

  /// [mealKey] → (residents, skipping).
  final Map<String, (int, int)> counts;

  /// The resident's own answers: [mealKey] → eating.
  final Map<String, bool> mine;
  final PlatesSaved saved;

  /// Staff only: today's skippers (the hostel's own residents), name and bed.
  final List<({String key, String name, String bed})> skippers;

  FoodBoard copyWith({int? cutoff, Map<String, (int, int)>? counts, Map<String, bool>? mine}) =>
      FoodBoard(cutoff: cutoff ?? this.cutoff, counts: counts ?? this.counts, mine: mine ?? this.mine, saved: saved, skippers: skippers);

  /// The board after the resident's [answers]: each changed answer moves its
  /// meal's skipping count by one.
  FoodBoard answer(Map<String, bool> answers) {
    final m = Map.of(mine), c = Map.of(counts);
    for (final e in answers.entries) {
      final was = m[e.key] ?? true;
      m[e.key] = e.value;
      final n = c[e.key];
      if (n != null && was != e.value) c[e.key] = (n.$1, (n.$2 + (e.value ? -1 : 1)).clamp(0, n.$1));
    }
    return copyWith(mine: m, counts: c);
  }
}

/// The server's `food_board` reply.
FoodBoard foodBoardFromJson(Map<String, dynamic> j) {
  int n(Object? v) => (v as num?)?.toInt() ?? 0;
  final s = (j['saved'] as Map?)?.cast<String, dynamic>() ?? const {};
  return FoodBoard(
    cutoff: n(j['cutoff']) == 0 ? 3 : n(j['cutoff']),
    counts: {
      for (final c in (j['counts'] as List? ?? const []).cast<Map<String, dynamic>>()) '${c['day']}|${c['meal']}': (n(c['residents']), n(c['skipping'])),
    },
    mine: {for (final c in (j['mine'] as List? ?? const []).cast<Map<String, dynamic>>()) '${c['day']}|${c['meal']}': c['eating'] as bool? ?? true},
    saved: (youWeek: n(s['you_week']), you: n(s['you']), hostelMonth: n(s['hostel_month']), hostel: n(s['hostel']), hostelzy: n(s['hostelzy'])),
    skippers: [
      for (final c in (j['skippers'] as List? ?? const []).cast<Map<String, dynamic>>()) (key: '${c['day']}|${c['meal']}', name: c['name'] as String? ?? '', bed: c['bed'] as String? ?? ''),
    ],
  );
}

/// The demo build's Anjani meals (sample data only): 40 residents; the
/// resident skips the weekend, one lunch and one dinner.
FoodBoard sampleFoodBoard(DateTime today) {
  // Eating per weekday (Monday first): breakfast, lunch, dinner.
  const eating = [(38, 33, 35), (39, 30, 36), (37, 31, 34), (38, 28, 34), (38, 29, 34), (30, 24, 26), (27, 22, 25)];
  final counts = <String, (int, int)>{}, mine = <String, bool>{};
  for (var i = 0; i < 7; i++) {
    final d = today.add(Duration(days: i)), e = eating[d.weekday - 1];
    counts[mealKey(d, 'b')] = (40, 40 - e.$1);
    counts[mealKey(d, 'l')] = (40, 40 - e.$2);
    counts[mealKey(d, 'n')] = (40, 40 - e.$3);
    if (d.weekday >= 6) {
      for (final m in const ['b', 'l', 'n']) {
        mine[mealKey(d, m)] = false;
      }
    }
    if (i > 0 && d.weekday == 2) mine[mealKey(d, 'n')] = false;
    if (i > 0 && d.weekday == 3) mine[mealKey(d, 'l')] = false;
  }
  final k = mealKey(today, 'n');
  return FoodBoard(
    counts: counts,
    mine: mine,
    saved: (youWeek: 3, you: 23, hostelMonth: 412, hostel: 412, hostelzy: 9870),
    skippers: [
      for (final (n, b) in const [('Arjun R.', '204-A'), ('Sai K.', '204-C'), ('Pranav S.', '203-A'), ('Faiz M.', '101-A'), ('Teja N.', '102-B'), ('Vikram P.', '301-B')]) (key: k, name: n, bed: b),
    ],
  );
}
