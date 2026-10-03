part of '../../state.dart';

// F24 #26: laundry day. The owner picks a day and when the machine is free
// (House rules › Laundry day, board `oLaundry`). It is saved with the house
// rules (tenants see it on the hostel page) and residents who turn on the
// Laundry reminder get it at 8 pm the evening before (Me › Reminders).
mixin _LaundryData {
  /// The owner's sheet: day (1 = Monday … 7 = Sunday) and slot being picked.
  int laundryDayDraft = 7;
  String laundrySlotDraft = laundrySlots.first;

  /// Resident: the Laundry reminder is on (off until they turn it on).
  bool remLaundry = false;
}

const laundrySlots = ['7 am – 12 pm', 'All day', 'Evening'];
const laundryKey = 'Laundry day';
const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "Sunday · 7 am – 12 pm" → (7, '7 am – 12 pm'); null when not set.
({int day, String slot})? parseLaundry(String v) {
  final parts = v.split('·').map((x) => x.trim()).toList();
  final i = weekdayNames.indexWhere((d) => parts.first.toLowerCase().startsWith(d.substring(0, 3).toLowerCase()));
  if (i < 0) return null;
  return (day: i + 1, slot: parts.length > 1 ? parts[1] : 'All day');
}

extension LaundryActions on AppState {
  /// A hostel's laundry day, from its saved house rules (the owner's draft for their own).
  ({int day, String slot})? laundryOf(String hid) {
    final list = hid == ownHid && role == 'owner' ? rules : hostelRules[hid] ?? (isSeedHostel(hid) ? rules : const <Rule>[]);
    final r = list.where((x) => x.k == laundryKey).firstOrNull;
    return r == null || r.v.trim().isEmpty ? null : parseLaundry(r.v);
  }

  void openLaundry() => update(() {
    final cur = laundryOf(ownHid);
    laundryDayDraft = cur?.day ?? 7;
    laundrySlotDraft = cur?.slot ?? laundrySlots.first;
    sheet = 'laundry';
  });

  /// Saves the day with the house rules (on the server when signed in).
  void saveLaundry() {
    final v = '${weekdayNames[laundryDayDraft - 1]} · $laundrySlotDraft';
    final eve = weekdayNames[(laundryDayDraft + 5) % 7];
    update(() {
      rules = [...rules.where((r) => r.k != laundryKey), Rule(laundryKey, v)];
      sheet = null;
    });
    saveRules(msg: 'Laundry day saved: ${v.replaceFirst(' · ', ', ')}. Residents with the reminder on get it at 8 pm on $eve.');
  }

  Future<void> toggleLaundryRem() async {
    update(() => remLaundry = !remLaundry);
    await _reschedule();
  }

  /// The resident's laundry reminder: 8 pm the evening before, every week
  /// (the end of the awake hours when 8 pm is after them).
  Ring? get laundryRing {
    final hid = remHostel;
    if (hid == null || !remLaundry) return null;
    final l = laundryOf(hid);
    if (l == null) return null;
    final at = awake(20 * 60, end: true) ? 20 * 60 : water.to;
    final when = switch (l.slot) { 'All day' => 'all day', 'Evening' => 'in the evening', final x => x };
    return Ring(id: 4100, kind: 'laundry', minute: at, weekday: l.day == 1 ? 7 : l.day - 1, title: 'Laundry day tomorrow', body: '${hostelById(hid).name}: the machine is free $when.');
  }
}
