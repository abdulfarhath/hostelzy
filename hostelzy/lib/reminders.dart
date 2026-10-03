// F20 Reminders: water, my own reminders and hostel reminders ring from this
// phone (local scheduled notifications), so they work offline and cost no
// server push. Android only; tests, web and desktop use [NoReminders].

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Water: every [every] minutes from [from] to [to] (minutes of the day).
class WaterPlan {
  const WaterPlan({this.on = false, this.every = 30, this.from = 8 * 60, this.to = 22 * 60, this.goal = 8});
  final bool on;
  final int every, from, to, goal;
  WaterPlan copyWith({bool? on, int? every, int? from, int? to, int? goal}) => WaterPlan(on: on ?? this.on, every: every ?? this.every, from: from ?? this.from, to: to ?? this.to, goal: goal ?? this.goal);
  Map<String, dynamic> toJson() => {'on': on, 'every': every, 'from': from, 'to': to, 'goal': goal};
  static WaterPlan fromJson(Map<String, dynamic>? m) => m == null ? const WaterPlan() : WaterPlan(on: m['on'] as bool? ?? false, every: m['every'] as int? ?? 30, from: m['from'] as int? ?? 480, to: m['to'] as int? ?? 1320, goal: m['goal'] as int? ?? 8);

  /// Ring times (minutes of the day): from [from], every [every], before [to].
  List<int> get slots => [for (var t = from; t < to; t += every) t];
}

/// One of my reminders. [repeat]: once | daily | weekdays | days ([days]:
/// 1 = Monday … 7 = Sunday). A one-off rings at [onceAt] (ms).
class MyReminder {
  const MyReminder({required this.id, required this.name, required this.at, this.repeat = 'daily', this.days = const {}, this.on = true, this.onceAt});
  final String id, name, repeat;
  final int at;
  final Set<int> days;
  final bool on;
  final int? onceAt;
  MyReminder copyWith({bool? on}) => MyReminder(id: id, name: name, at: at, repeat: repeat, days: days, on: on ?? this.on, onceAt: onceAt);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'at': at, 'repeat': repeat, 'days': days.toList()..sort(), 'on': on, 'onceAt': onceAt};
  static MyReminder fromJson(Map<String, dynamic> m) => MyReminder(id: m['id'] as String, name: m['name'] as String, at: m['at'] as int, repeat: m['repeat'] as String? ?? 'daily', days: {...(m['days'] as List? ?? const []).cast<int>()}, on: m['on'] as bool? ?? true, onceAt: m['onceAt'] as int?);

  /// The weekdays it rings on (empty: every day or once).
  Set<int> get weekdays => switch (repeat) {
    'weekdays' => const {1, 2, 3, 4, 5},
    'days' => days,
    _ => const {},
  };
}

/// One notification to schedule. Repeats daily at [minute] unless [weekday]
/// (weekly) or [at] (once) is set.
class Ring {
  const Ring({required this.id, required this.title, required this.body, required this.kind, this.minute = 0, this.weekday, this.at});
  final int id;
  final String title, body;

  /// water | mine | meal | rent: picks the buttons and where a tap goes.
  final String kind;
  final int minute;
  final int? weekday;
  final DateTime? at;
}

/// Notification ids: water 1000+, mine 2000+, meals 3000+, rent 4000+,
/// laundry 4100, snoozed 5000+.
const snoozeId = 5000;

/// `4:30 pm`, `9 pm` when [short] and on the hour.
String clock(int minuteOfDay, {bool short = false}) {
  final h = minuteOfDay ~/ 60 % 24, m = minuteOfDay % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final ap = h < 12 ? 'am' : 'pm';
  if (short && m == 0) return '$h12 $ap';
  return '$h12:${m.toString().padLeft(2, '0')} $ap';
}

/// Reads and writes today's glasses. A "Done" on the notification counts a
/// glass from a background isolate, so the count lives in its own key.
class Glasses {
  static const _key = 'hostelzy.glasses';
  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static Future<int> read() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final v = (p.getString(_key) ?? '').split(':');
      return v.length == 2 && v[0] == today() ? int.tryParse(v[1]) ?? 0 : 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> write(int n) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, '${today()}:$n');
    } catch (_) {}
  }
}

abstract class Reminders {
  /// Whether reminders can ring here (the Android app).
  bool get available;

  /// Replaces every scheduled reminder with [rings].
  Future<void> apply(List<Ring> rings);

  /// Today's glasses, including ones counted from a notification.
  Future<int> glasses();
  Future<void> setGlasses(int n);

  /// Taps on a reminder that open the app: its kind (water | mine | meal | rent).
  void onOpen(void Function(String kind) f);
}

/// No local notifications here (tests, web, desktop). Keeps what would ring.
class NoReminders implements Reminders {
  NoReminders({this.available = false});
  @override
  final bool available;
  List<Ring> applied = [];
  int applies = 0;
  int _glasses = 0;
  @override
  Future<void> apply(List<Ring> rings) async {
    applied = rings;
    applies++;
  }

  @override
  Future<int> glasses() async => _glasses;
  @override
  Future<void> setGlasses(int n) async => _glasses = n;
  @override
  void onOpen(void Function(String kind) f) {}
}

const _channel = AndroidNotificationDetails('reminders', 'Reminders', channelDescription: 'Water, your own reminders and hostel reminders, set in Me → Reminders.', importance: Importance.high, priority: Priority.high, icon: 'ic_stat_hostelzy', color: Color(0xFFEC3013));

NotificationDetails _details(String kind) => NotificationDetails(
  android: AndroidNotificationDetails(
    _channel.channelId,
    _channel.channelName,
    channelDescription: _channel.channelDescription,
    importance: _channel.importance,
    priority: _channel.priority,
    icon: _channel.icon,
    color: _channel.color,
    actions: switch (kind) {
      'water' || 'mine' => const [AndroidNotificationAction('done', 'Done'), AndroidNotificationAction('snooze', 'Snooze 10 min')],
      'meal' => const [AndroidNotificationAction('open', 'Open menu', showsUserInterface: true)],
      'rent' => const [AndroidNotificationAction('open', 'Pay rent', showsUserInterface: true)],
      _ => const [],
    },
  ),
);

const _init = InitializationSettings(android: AndroidInitializationSettings('ic_stat_hostelzy'));

/// Payload: `kind|title|body`, so a snooze can ring the same reminder again.
String _payload(Ring r) => '${r.kind}|${r.title}|${r.body}';

/// "Done" and "Snooze 10 min" without opening the app (background isolate).
@pragma('vm:entry-point')
Future<void> reminderAction(NotificationResponse r) async {
  final parts = (r.payload ?? '').split('|');
  final kind = parts.first;
  if (r.actionId == 'done' && kind == 'water') {
    await Glasses.write(await Glasses.read() + 1);
  } else if (r.actionId == 'snooze' && parts.length == 3) {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    final n = FlutterLocalNotificationsPlugin();
    await n.initialize(settings: _init);
    await n.zonedSchedule(id: snoozeId + DateTime.now().minute, title: parts[1], body: parts[2], scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)), notificationDetails: _details(kind), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: r.payload);
  }
}

class LocalReminders implements Reminders {
  final _n = FlutterLocalNotificationsPlugin();
  void Function(String kind)? _open;
  String? _launched;

  /// Starts the plugin; null if it can't (then reminders don't ring).
  static Future<Reminders> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return NoReminders();
    try {
      tzdata.initializeTimeZones();
      // Hostelzy is a Hyderabad app: reminders follow India time.
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      final r = LocalReminders();
      await r._n.initialize(settings: _init, onDidReceiveNotificationResponse: r._tap, onDidReceiveBackgroundNotificationResponse: reminderAction);
      final l = await r._n.getNotificationAppLaunchDetails();
      if (l?.didNotificationLaunchApp == true) r._launched = (l!.notificationResponse?.payload ?? '').split('|').first;
      return r;
    } catch (e) {
      debugPrint('Reminders: $e');
      return NoReminders();
    }
  }

  void _tap(NotificationResponse r) {
    if (r.actionId == 'done' || r.actionId == 'snooze') {
      reminderAction(r);
      return;
    }
    _open?.call((r.payload ?? '').split('|').first);
  }

  @override
  bool get available => true;

  @override
  void onOpen(void Function(String kind) f) {
    _open = f;
    final l = _launched;
    _launched = null;
    if (l != null && l.isNotEmpty) f(l);
  }

  @override
  Future<void> apply(List<Ring> rings) async {
    try {
      await _n.cancelAllPendingNotifications();
      final now = tz.TZDateTime.now(tz.local);
      for (final r in rings) {
        final DateTimeComponents? repeat;
        tz.TZDateTime when;
        if (r.at != null) {
          when = tz.TZDateTime.from(r.at!, tz.local);
          if (!when.isAfter(now)) continue;
          repeat = null;
        } else {
          when = tz.TZDateTime(tz.local, now.year, now.month, now.day, r.minute ~/ 60, r.minute % 60);
          while (!when.isAfter(now) || (r.weekday != null && when.weekday != r.weekday)) {
            when = when.add(const Duration(days: 1));
          }
          repeat = r.weekday != null ? DateTimeComponents.dayOfWeekAndTime : DateTimeComponents.time;
        }
        await _n.zonedSchedule(id: r.id, title: r.title, body: r.body, scheduledDate: when, notificationDetails: _details(r.kind), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: repeat, payload: _payload(r));
      }
    } catch (e) {
      debugPrint('Reminders: $e');
    }
  }

  @override
  Future<int> glasses() => Glasses.read();
  @override
  Future<void> setGlasses(int n) => Glasses.write(n);
}
