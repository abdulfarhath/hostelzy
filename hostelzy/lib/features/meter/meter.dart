part of '../../state.dart';

// F24 #25: electricity by meter. The owner types each room's meter once a
// month (Rent › Electricity, board `oMeter`); the units since last month are
// split between the residents in the room, and each resident sees their share
// on their rent (board `rentMeter`). The ₹ per unit is the owner's own number.
mixin _MeterData {
  /// Owner: the hostel's readings for this month and last (by hostel).
  final Map<String, List<MeterRow>> meterRows = {};

  /// Owner's page: ₹ per unit and the "Now" readings typed (room → text).
  String meterRate = '';
  Map<int, String> meterNow = {};
  bool meterSaving = false;

  /// The server doesn't have meter readings yet (its update hasn't run).
  bool meterOff = false;

  /// Resident: this month's reading for their room (null: not added yet).
  MeterRow? myMeterRow;
  bool _myMeterAsked = false;
}

/// "1,870" (Indian grouping, no ₹).
String grouped(int n) => fmt(n).substring(1);

/// The month readings belong to (the 1st).
DateTime get meterMonth => DateTime(appToday.year, appToday.month);

/// "₹8", "₹7.50".
String perUnit(double r) => r == r.roundToDouble() ? '₹${r.round()}' : '₹${r.toStringAsFixed(2)}';

/// Demo builds: last month's readings for the sample hostel.
List<MeterRow> sampleMeters(List<Room> rooms) {
  final last = DateTime(meterMonth.year, meterMonth.month - 1);
  return [for (final r in rooms) (room: r.n, month: last, reading: r.n == 204 ? 1870 : 600 + (r.n * 37) % 1700, rate: 8.0, units: null, people: null, each: null)];
}

extension MeterActions on AppState {
  /// Residents in room [n] of the owner's hostel (who share its meter).
  int peopleIn(int n) {
    final r = rooms[ownHid]?.where((x) => x.n == n).firstOrNull;
    if (r == null) return 0;
    return residents.where((x) => x.bed.startsWith('${r.label}-')).length;
  }

  MeterRow? meterOf(int room, {bool last = false}) {
    final want = last ? DateTime(meterMonth.year, meterMonth.month - 1) : meterMonth;
    return (meterRows[ownHid] ?? const []).where((m) => m.room == room && m.month.year == want.year && m.month.month == want.month).lastOrNull;
  }

  /// Units since last month for a typed reading (null: no last reading or not typed).
  int? meterUnits(int room) {
    final now = int.tryParse((meterNow[room] ?? '').replaceAll(RegExp(r'\D'), ''));
    final last = meterOf(room, last: true)?.reading;
    if (now == null || last == null || now < last) return null;
    return now - last;
  }

  double? get meterRateValue {
    final r = double.tryParse(meterRate.trim().replaceAll('₹', ''));
    return r == null || r <= 0 || r > 100 ? null : r;
  }

  /// ₹ each for room [room] (rounded up), or null.
  int? meterEach(int room) {
    final u = meterUnits(room), rate = meterRateValue, n = peopleIn(room);
    if (u == null || rate == null || n == 0) return null;
    return (u * rate / n).ceil();
  }

  /// Rent › Electricity.
  void openMeter() {
    go('oMeter');
    loadMeters();
  }

  Future<void> loadMeters() async {
    final hid = ownHid;
    List<MeterRow> got;
    if (onServer) {
      try {
        got = await data.meters(hid, meterMonth);
        if (meterOff) update(() => meterOff = false);
      } catch (e) {
        debugPrint('meters: $e');
        update(() => meterOff = true);
        return;
      }
    } else {
      got = meterRows[hid] ?? (AppState.samples && isSeedHostel(hid) ? sampleMeters(rooms[hid] ?? const []) : const []);
    }
    update(() {
      meterRows[hid] = got;
      final cur = [for (final m in got) if (m.month.month == meterMonth.month && m.month.year == meterMonth.year) m];
      meterNow = {for (final m in cur) m.room: '${m.reading}'};
      final rate = (cur.isNotEmpty ? cur : got).lastOrNull?.rate;
      meterRate = rate == null ? '' : (rate == rate.roundToDouble() ? '${rate.round()}' : '$rate');
    });
  }

  /// "Add to October rent · 4 of 5 rooms".
  Future<void> saveMeters() async {
    final rate = meterRateValue;
    if (rate == null) return toastMsg('Type the ₹ per unit first.');
    final rows = <({int room, int reading})>[
      for (final r in rooms[ownHid] ?? const <Room>[])
        if (int.tryParse((meterNow[r.n] ?? '').replaceAll(RegExp(r'\D'), '')) case final v?) (room: r.n, reading: v),
    ];
    if (rows.isEmpty) return toastMsg('Type at least one room’s meter.');
    for (final x in rows) {
      final last = meterOf(x.room, last: true)?.reading;
      if (last != null && x.reading < last) return toastMsg('Room ${x.room}: the reading is lower than last month’s (${grouped(last)}).');
    }
    final month = monthYear(appToday).split(' ').first;
    if (onServer) {
      if (meterSaving) return;
      update(() => meterSaving = true);
      try {
        await data.saveMeter(ownHid, meterMonth, rate, rows);
      } catch (e) {
        debugPrint('save meter: $e');
        update(() => meterSaving = false);
        final m = '$e';
        if (m.contains('lower than last month')) return toastMsg(m.substring(m.indexOf('room')).split(RegExp(r'[,}\n]')).first.replaceFirst('room', 'Room'));
        return toastMsg(meterOff || m.contains('save_meter') || m.contains('meter_readings') ? 'Electricity by meter starts after Hostelzy’s next server update.' : 'Couldn’t save it. Check your internet and try again.');
      }
      update(() => meterSaving = false);
      await loadMeters();
    } else {
      update(() {
        final hid = ownHid;
        meterRows[hid] = [
          for (final m in meterRows[hid] ?? const <MeterRow>[]) if (!(m.month == meterMonth && rows.any((x) => x.room == m.room))) m,
          for (final x in rows) (room: x.room, month: meterMonth, reading: x.reading, rate: rate, units: meterUnits(x.room), people: peopleIn(x.room), each: meterEach(x.room)),
        ];
      });
    }
    back();
    toastMsg('Added to $month rent for ${rows.length} room${rows.length == 1 ? '' : 's'}. Residents see their share on their rent.');
  }

  /// Rooms with a reading typed, and all rooms.
  (int, int) get meterCount {
    final rs = rooms[ownHid] ?? const <Room>[];
    return (rs.where((r) => (meterNow[r.n] ?? '').trim().isNotEmpty).length, rs.length);
  }

  /// Resident: this month's electricity for their room.
  MeterRow? get myMeter {
    if (!onServer) return AppState.samples ? (room: 204, month: meterMonth, reading: 2080, rate: 8.0, units: 210, people: 4, each: 420) : null;
    final m = myMeterRow;
    return m != null && m.month.year == meterMonth.year && m.month.month == meterMonth.month && m.each != null ? m : null;
  }

  /// Loads the resident's reading once per app start (quietly: nothing shows
  /// until the owner adds it, or before the server has meter readings).
  Future<void> loadMyMeter({bool force = false}) async {
    final st = myStay;
    if (!onServer || st == null || (_myMeterAsked && !force)) return;
    _myMeterAsked = true;
    try {
      final rows = await data.meters(st.hid, meterMonth);
      final room = int.tryParse(stayRoom);
      final mine = [for (final r in rows) if (room == null || r.room == room) r];
      update(() => myMeterRow = mine.lastOrNull);
    } catch (e) {
      debugPrint('my meter: $e');
    }
  }
}
