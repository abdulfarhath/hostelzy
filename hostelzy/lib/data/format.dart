import '../data.dart';

/// "Today": the real date in India in the Play Store build (F17); the sample
/// data's day (1 Oct 2026) in debug builds and tests, so the samples line up.
/// F18: a getter, so the date moves on while the app stays open overnight.
DateTime get appToday => const bool.fromEnvironment('dart.vm.product') ? _todayIst() : DateTime(2026, 10);

DateTime _todayIst() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(n.year, n.month, n.day);
}

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "October 2026"
String monthYear(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "fan", but "AC unit" keeps its capitals.
String lowerName(String n) => n.length > 1 && n[1].toUpperCase() == n[1] && n[1].toLowerCase() != n[1] ? n : n.toLowerCase();

/// `1st`, `2nd`, `14th`
String ordinal(int n) => '$n${(n % 100 >= 11 && n % 100 <= 13) ? 'th' : const ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'][n % 10]}';

/// `31 Oct`
String dayMon(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Last-day choices when giving notice today: the earliest day the notice
/// period allows, then 15 and 30 days after it.
List<String> leaveDates(Terms t) => [for (final d in leaveDays(t)) dayMon(d)];

List<DateTime> leaveDays(Terms t) => [for (final x in [0, 15, 30]) appToday.add(Duration(days: t.noticeDays + x))];

/// "12 min", "2 h": how long an owner usually takes to reply.
String replyWords(int min) => min < 60 ? '$min min' : '${(min / 60).round()} h';

/// `Due 14 Oct` for a resident who joined on [joinDay].
String dueNote(Terms t, int joinDay) => 'Due ${t.dueDay(joinDay)} ${_months[appToday.month - 1]}';

/// `13 days left`, `due today`.
String dueLeft(Terms t, int joinDay) {
  final n = t.dueDay(joinDay) - appToday.day;
  return n <= 0 ? 'due today' : '$n day${n == 1 ? '' : 's'} left';
}

/// Number as JavaScript prints it (`4.0` → `4`).
String jsNum(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

/// `'₹' + Math.round(n).toLocaleString('en-IN')`
String fmt(num n) {
  final v = n.round();
  final neg = v < 0;
  final s = v.abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '₹${neg ? '-' : ''}$out';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `Sat 3 Oct`
String dayName(DateTime d) => '${_weekdays[d.weekday - 1]} ${dayMon(d)}';

/// "6 min ago", "2 h ago".
String ago(int ms) {
  final m = ms ~/ 60000;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  return h < 24 ? '$h h ago' : '${h ~/ 24} d ago';
}

/// "Today, 6:42 pm"
String clockTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return 'Today, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// F21: this week (Monday first) as [day, date, month], from [appToday].
List<List<String>> get weekDays {
  final mon = appToday.subtract(Duration(days: appToday.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      () {
        final d = mon.add(Duration(days: i));
        return [const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i], '${d.day}', _months[d.month - 1]];
      }(),
  ];
}

/// Monday = 0 … Sunday = 6.
int get todayIdx => appToday.weekday - 1;

const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Thursday"
String get todayName => _dayNames[todayIdx];

/// Countdown text, `cd()` in the prototype.
String cd(num t) {
  final v = t < 0 ? 0 : t.floor();
  final h = v ~/ 3600, m = (v % 3600) ~/ 60, x = v % 60;
  return '${h > 0 ? '$h:${m.toString().padLeft(2, '0')}' : '$m'}:${x.toString().padLeft(2, '0')}';
}

/// `s.replace(/(\d{5})(\d{0,5})/, '$1 $2')`
String phoneSpaced(String s) => s.replaceFirstMapped(RegExp(r'(\d{5})(\d{0,5})'), (m) => '${m[1]} ${m[2]}');

String initials(String n) {
  final s = n.split(' ').map((w) => w.isEmpty ? '' : w[0]).join();
  return s.length > 2 ? s.substring(0, 2) : s;
}

/// Whole days from [at] to today (never negative), for "confirmed X days ago".
int daysSince(DateTime at) {
  final l = at.toLocal(), t = appToday;
  return DateTime(t.year, t.month, t.day).difference(DateTime(l.year, l.month, l.day)).inDays.clamp(0, 1 << 20);
}
