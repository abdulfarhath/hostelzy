import 'dart:ui' show Offset;

import '../../data.dart';
import 'live.dart';
import 'repo.dart';

/// F24 item 29: a `team_tracker()` row → the tracker's [Lead]. With no next
/// step noted, the stage says what comes next.
Lead leadFromRow(Map<String, dynamic> r) {
  final stage = (r['stage'] as num?)?.toInt() ?? 0;
  final trial = r['trial_ends'] == null ? null : DateTime.parse(r['trial_ends'] as String);
  final note = (r['next_step'] as String? ?? '').trim();
  final next = stage == 5 && trial != null
      ? 'Trial ends ${dayMon(trial)}'
      : note.isNotEmpty
      ? note
      : const ['Visit the hostel', 'Sign up the owner', 'Add rooms, rates and photos', 'Go live', 'Start the trial', 'Trial running', 'Paying'][stage.clamp(0, 6)];
  return Lead(r['name'] as String? ?? '', r['area'] as String? ?? '', next, stage, hid: r['hostel_id'] as String?);
}

/// Rows from `hostels` (with nested rooms → beds and rate_cards) → app models.
Listings listingsFromRows(List<Map<String, dynamic>> rows, {Map<String, int> strikes = const {}, Map<String, Map<int, (int, String)>> checks = const {}, Map<String, int> checkers = const {}, Map<String, Standing> standing = const {}}) {
  final hs = <Hostel>[], rooms = <String, List<Room>>{}, rates = <String, Map<String, int>>{}, pos = <String, (double, double)>{};
  final upi = <String, ({String id, String name})>{};
  final lays = <String, Map<int, RoomLayout>>{};
  final deals = <String, Deals>{}, rules = <String, List<Rule>>{};
  final reviews = <String, List<Review>>{};
  for (final h in rows) {
    // S4: verified residents' reviews, newest first; the rating comes from them.
    // F24 4a: reviews the team hid (abuse, duplicates) never count.
    final revRows = (h['reviews'] as List? ?? const []).cast<Map<String, dynamic>>().where((r) => r['hidden'] != true).toList()..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    final revs = reviews[h['id'] as String] = [for (final r in revRows) reviewFromRow(r)];
    final id = h['id'] as String;
    final rs = <Room>[
      for (final r in (h['rooms'] as List? ?? const []).cast<Map<String, dynamic>>())
        () {
          final n = r['number'] as int, floor = r['floor'] as int, label = r['label'] as String?;
          final beds = (r['beds'] as List? ?? const []).cast<Map<String, dynamic>>().toList()..sort((a, b) => (a['letter'] as String).compareTo(b['letter'] as String));
          return Room(
            n: n,
            floor: floor,
            share: r['share'] as int,
            rent: r['rent'] as int,
            ac: r['ac'] as bool? ?? false,
            acRepair: r['ac_repair'] as bool? ?? false,
            bath: r['bath'] as String? ?? 'Shared',
            name: label,
            beds: [
              for (final b in beds)
                Bed(
                  id: '${label ?? n}-${b['letter']}',
                  letter: b['letter'] as String,
                  room: n,
                  floor: floor,
                  spot: b['spot'] as String? ?? '',
                  state: b['state'] as String? ?? 'free',
                  soon: b['free_from'] == null ? '' : dayMon(DateTime.parse(b['free_from'] as String)),
                  key: b['id'] as String?,
                )
                  ..freedAt = b['freed_at'] == null ? null : DateTime.parse(b['freed_at'] as String).toLocal()
                  ..walkInUntil = b['walk_in_until'] == null ? 0 : DateTime.parse(b['walk_in_until'] as String).millisecondsSinceEpoch,
            ],
          )..acSince = r['ac_repair_since'] == null ? '' : dayMon(DateTime.parse(r['ac_repair_since'] as String));
        }(),
    ]..sort((a, b) => a.n.compareTo(b.n));
    final cards = (h['rate_cards'] as List? ?? const []).cast<Map<String, dynamic>>();
    final rate = <String, int>{for (final c in cards) rateKey(c['ac'] as bool, c['share'] as int): c['rent'] as int};
    // F24 Wave 4d: the oldest card's confirmation (a card never confirmed: none).
    final ratesTracked = cards.isNotEmpty && cards.every((c) => c.containsKey('confirmed_at'));
    final ratesAt = ratesTracked && cards.every((c) => c['confirmed_at'] != null) ? _latest([for (final c in cards) c['confirmed_at']], oldest: true) : null;
    final prices = [...rate.values, ...rs.map((r) => r.rent)];
    final t = (h['terms'] as Map?)?.cast<String, dynamic>() ?? const {};
    final area = h['area'] as String;
    final spot = areaSpot[area] ?? areaSpot['Madhapur']!;
    hs.add(
      Hostel(
        id: id,
        name: h['name'] as String,
        gender: h['gender'] as String,
        area: area,
        from: prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b),
        // Ratings come from verified reviews (F08).
        rating: revs.isEmpty ? 0 : double.parse((revs.fold<int>(0, (a, r) => a + r.stars) / revs.length).toStringAsFixed(1)),
        reviews: revs.length,
        food: h['food'] as bool? ?? false,
        ac: h['ac'] as bool? ?? false,
        onlyAc: h['only_ac'] as bool? ?? false,
        instant: h['instant'] as bool? ?? false,
        owner: h['owner_name'] as String? ?? '',
        reply: 0,
        mins: spot.mins,
        x: spot.x,
        y: spot.y,
        tags: (h['tags'] as List? ?? const []).cast<String>(),
        terms: Terms(
          advance: t['advance'] as int? ?? 3000,
          maintenance: t['maintenance'] as int? ?? 1000,
          noticeDays: t['noticeDays'] as int? ?? 30,
          dueOnJoining: t['dueOnJoining'] as bool? ?? true,
          electricityExtra: t['electricityExtra'] as bool? ?? true,
        ),
        live: (h['status'] as String? ?? 'live') == 'live',
        // F24 item 9: the owner's confirmations, from the server.
        bedsCheckedAt: _latest([for (final r in (h['rooms'] as List? ?? const []).cast<Map>()) for (final b in (r['beds'] as List? ?? const []).cast<Map>()) b['confirmed_at']]),
        layoutsCheckedAt: _latest([for (final l in (h['layouts'] as List? ?? const []).cast<Map>()) if (l['stage'] == 'published') l['confirmed_at'] ?? l['updated_at']], oldest: true),
        ratesCheckedAt: ratesAt,
        ratesTracked: ratesTracked,
        visitedOn: h['visited_on'] == null ? '' : () {
          final v = DateTime.parse(h['visited_on'] as String);
          return '${dayMon(v)} ${v.year}';
        }(),
      ),
    );
    rooms[id] = rs;
    rates[id] = rate;
    if (h['lat'] != null && h['lng'] != null) pos[id] = ((h['lat'] as num).toDouble(), (h['lng'] as num).toDouble());
    upi[id] = (id: h['upi_id'] as String? ?? '', name: h['upi_name'] as String? ?? '');
    // S3: the owner's deals and house rules. One-to-one joins may come back as a map or a list.
    final d = switch (h['deals']) { final Map m => m.cast<String, dynamic>(), final List l when l.isNotEmpty => (l.first as Map).cast<String, dynamic>(), _ => null };
    deals[id] = d == null
        ? const Deals()
        : Deals(on: {...(d['deals_on'] as List? ?? const []).cast<String>()}, target: d['target'] as String? ?? 'all', confirmed: d['confirmed_at'] == null ? '' : dayMon(DateTime.parse(d['confirmed_at'] as String).toLocal()));
    final ru = [for (final r in (h['rules'] as List? ?? const []).cast<Map>()) Rule('${r['k'] ?? ''}', '${r['v'] ?? ''}')];
    if (ru.isNotEmpty) rules[id] = ru;
    lays[id] = {
      for (final l in (h['layouts'] as List? ?? const []).cast<Map<String, dynamic>>().where((l) => l['stage'] == 'published')) l['room'] as int: layoutFromRow(id, l),
    };
  }
  // F23: floor and room amenities, oldest first.
  final ams = <String, List<Amenity>>{
    for (final h in rows) h['id'] as String: [for (final r in ((h['amenities'] as List? ?? const []).cast<Map<String, dynamic>>().toList()..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String)))) amenityFromRow(r)],
  };
  return (hostels: hs, rooms: rooms, rates: rates, pos: pos, upi: upi, layouts: lays, deals: deals, rules: rules, reviews: reviews, strikes: strikes, checks: checks, checkers: checkers, amenities: ams, standing: standing);
}

/// The newest (or [oldest]) of some timestamps; null when there are none.
DateTime? _latest(List<Object?> ts, {bool oldest = false}) {
  DateTime? out;
  for (final t in ts) {
    final d = t is String ? DateTime.tryParse(t) : null;
    if (d != null && (out == null || (oldest ? d.isBefore(out) : d.isAfter(out)))) out = d;
  }
  return out;
}

/// A `layouts` row → the app's room layout. Beds are `{"A": [x, y]}` in
/// feet; items `[{id, kind, x, y, w, h, facing, working}]`; bunks `{upper: lower}`.
RoomLayout layoutFromRow(String hid, Map<String, dynamic> r) {
  num n(Object? v) => v as num? ?? 0;
  final beds = <String, Offset>{for (final e in (r['beds'] as Map? ?? const {}).entries) e.key as String: Offset(n((e.value as List)[0]).toDouble(), n(e.value[1]).toDouble())};
  final items = [
    for (final i in (r['items'] as List? ?? const []).cast<Map>()) LItem(i['id'] as String, i['kind'] as String, n(i['x']).toDouble(), n(i['y']).toDouble(), n(i['w']).toDouble(), n(i['h']).toDouble(), facing: i['facing'] as String?, working: i['working'] as bool? ?? true),
  ];
  final at = DateTime.tryParse(r['updated_at'] as String? ?? '');
  return RoomLayout(hid: hid, room: r['room'] as int, w: n(r['w']).toDouble(), h: n(r['h']).toDouble(), beds: beds, items: items, version: r['version'] as int? ?? 1, drawn: at == null ? '' : dayMon(at), verified: at == null ? '' : dayMon(at))
    ..bunks.addAll({for (final e in (r['bunks'] as Map? ?? const {}).entries) e.key as String: e.value as String})
    // F24: rows from before shapes have none: a rectangle.
    ..shape = r['shape'] as String? ?? 'Rectangle'
    ..outline = outlineFromJson(r['outline'])
    // F24 4a: residents' "layout is wrong" answers since it was last published.
    ..disputes = r['disputes'] as int? ?? 0;
}

/// F24: a `shape_requests` row → [ShapeRequest].
ShapeRequest shapeRequestFromRow(Map<String, dynamic> r) => ShapeRequest(
  id: r['id'] as String,
  hid: r['hostel_id'] as String,
  room: r['room'] as int,
  shape: r['shape'] as String? ?? 'Custom',
  note: r['note'] as String? ?? '',
  w: (r['w'] as num? ?? 0).toDouble(),
  h: (r['h'] as num? ?? 0).toDouble(),
  photos: [for (final x in (r['photos'] as List? ?? const [])) x as String],
  status: r['status'] as String? ?? 'requested',
  at: DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
  drawing: (r['drawing'] as Map?)?.cast<String, dynamic>(),
  sentAt: r['sent_at'] == null ? null : DateTime.parse(r['sent_at'] as String).millisecondsSinceEpoch,
);

RemoteSettings settingsFromRows(List<Map<String, dynamic>> rows) {
  final m = {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  return (minBuild: int.tryParse(m['min_supported_build'] ?? '') ?? 0, maintenanceUntil: m['maintenance_until'] ?? '');
}

/// F23: an `amenities` row → [Amenity].
Amenity amenityFromRow(Map<String, dynamic> r) => Amenity(
  id: r['id'] as String,
  key: r['id'] as String,
  hid: r['hostel_id'] as String,
  floor: r['floor'] as int,
  kind: r['kind'] as String,
  name: r['name'] as String? ?? '',
  qty: r['qty'] as int? ?? 1,
  working: r['working'] as bool? ?? true,
  place: r['place'] as String? ?? 'floor',
  rooms: [for (final x in (r['rooms'] as List? ?? const [])) x as int],
  byResident: r['by_role'] == 'resident',
  at: DateTime.parse(r['updated_at'] as String? ?? r['created_at'] as String).millisecondsSinceEpoch,
  // F25: absent until FOUNDER-TODO 4zk2 has run; then null = not placed yet.
  posX: (r['pos_x'] as num?)?.toInt(),
  posY: (r['pos_y'] as num?)?.toInt(),
);

/// `menus` rows → the week, Monday first; null when there are none.
List<DayMenu>? menuFromRows(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return null;
  final w = List<DayMenu>.filled(7, const DayMenu('', '', ''));
  for (final r in rows) {
    final d = (r['day'] as num).toInt();
    if (d >= 0 && d < 7) w[d] = DayMenu(r['breakfast'] as String? ?? '', r['lunch'] as String? ?? '', r['dinner'] as String? ?? '');
  }
  return w;
}

Map<String, Standing> standingFromRows(Iterable<Map> rows) => {
  for (final r in rows)
    r['hostel_id'] as String: (
      until: r['hidden_until'] == null ? null : DateTime.parse(r['hidden_until'] as String).toLocal(),
      dealsHidden: r['deals_hidden'] as bool? ?? false,
      removed: r['removed'] as bool? ?? false,
      why: r['last_reason'] as String?,
    ),
};
