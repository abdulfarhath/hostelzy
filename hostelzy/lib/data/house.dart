import '../data.dart';

class DayMenu {
  const DayMenu(this.b, this.l, this.n);
  final String b, l, n;
  String of(String k) => k == 'b'
      ? b
      : k == 'l'
      ? l
      : n;
  DayMenu withMeal(String k, String v) => DayMenu(k == 'b' ? v : b, k == 'l' ? v : l, k == 'n' ? v : n);
}

const seedMenu = [
  DayMenu('Idli, sambar, coconut chutney', 'Rice, dal, bendakaya fry, curd', 'Chapati, paneer butter masala'),
  DayMenu('Upma, banana', 'Rice, sambar, cabbage poriyal', 'Egg curry, rice, rasam'),
  DayMenu('Poori, aloo curry', 'Veg biryani, raita', 'Chapati, dal tadka, salad'),
  DayMenu('Pesarattu, ginger chutney', 'Rice, tomato pappu, aloo fry, curd', 'Chicken curry or paneer, chapati'),
  DayMenu('Dosa, peanut chutney', 'Rice, rasam, beans fry', 'Veg fried rice, gobi manchurian'),
  DayMenu('Pongal, vada', 'Lemon rice, curd rice, papad', 'Chapati, chana masala'),
  DayMenu('Aloo paratha, curd', 'Chicken biryani or veg biryani', 'Khichdi, pickle'),
];

// F24 Wave 4c: meal times on the menu.
/// The usual meal times (when the owner hasn't set them): start, end.
const usualMealTimes = {'b': (7 * 60 + 30, 9 * 60 + 30), 'l': (12 * 60 + 30, 14 * 60), 'n': (20 * 60, 22 * 60)};

/// "7:30 – 9:30" like [meals].
String mealSpan((int, int) t) {
  String hm(int m) => '${m ~/ 60 % 12 == 0 ? 12 : m ~/ 60 % 12}:${(m % 60).toString().padLeft(2, '0')}';
  return '${hm(t.$1)} – ${hm(t.$2)}';
}

/// `menus` time columns: "07:30-09:30" ↔ (450, 570); '' is not set.
(int, int)? parseMealTime(String? v) {
  final m = RegExp(r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$').firstMatch(v ?? '');
  if (m == null) return null;
  return (int.parse(m[1]!) * 60 + int.parse(m[2]!), int.parse(m[3]!) * 60 + int.parse(m[4]!));
}

String mealTimeValue((int, int)? t) {
  if (t == null) return '';
  String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  return '${hm(t.$1)}-${hm(t.$2)}';
}

const meals = [
  ['b', 'Breakfast', '7:30 – 9:30'],
  ['l', 'Lunch', '12:30 – 2:00'],
  ['n', 'Dinner', '8:00 – 10:00'],
];

class Rule {
  const Rule(this.k, this.v);
  final String k, v;
}

/// F24: a real hostel with no rules yet: gate and visitors left for the
/// owner to fill; the rest comes from its terms.
List<Rule> blankRules(Terms t) => [for (final r in seedRules(t)) const {'Gate closes', 'Visitors'}.contains(r.k) ? Rule(r.k, '') : r];

List<Rule> seedRules(Terms t) => [
  const Rule('Gate closes', '10:30 pm'),
  const Rule('Visitors', 'Common area only, till 8 pm'),
  Rule('Notice period', '${t.noticeDays} days'),
  Rule('Advance', '${fmt(t.advance)} at move-in'),
  Rule('Exit maintenance', '${fmt(t.maintenance)} kept from the advance'),
  Rule('Fee due', t.dueOnJoining ? 'Every month on the joining date' : 'On the 1st of every month'),
  Rule('Electricity', t.electricityExtra ? 'Extra, split by room meter' : 'Included in the fee'),
  const Rule('Quiet hours', '11 pm – 6 am'),
];

/// Hostel page rule rows for [h].
List<List<String>> moneyRules(Hostel h) => [
  ['Notice period', '${h.terms.noticeDays} days'],
  ['Advance', '${fmt(h.terms.advance)} + first month at move-in'],
  ['Exit maintenance', '${fmt(h.terms.maintenance)} kept from the advance'],
  ['Fee due', h.terms.dueOnJoining ? 'Every month on your joining date' : 'On the 1st of every month'],
  ['Electricity', h.terms.electricityExtra ? 'Extra, split by room meter' : 'Included in the fee'],
];
