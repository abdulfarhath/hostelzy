// F13: where the app's data comes from. `SampleData` keeps the built-in
// sample hostels (offline, tests); `SupabaseData` reads live hostels from the
// database. Row Level Security decides what each user may read or write.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'data.dart';

/// Live hostels with their rooms, beds and rate cards.
typedef Listings = ({List<Hostel> hostels, Map<String, List<Room>> rooms, Map<String, Map<String, int>> rates, Map<String, (double, double)> pos, Map<String, ({String id, String name})> upi});

/// Remote switches (F15): the oldest supported build and maintenance mode.
typedef RemoteSettings = ({int minBuild, String maintenanceUntil});

abstract class HostelData {
  /// Live hostels, or null to keep the built-in sample data.
  Future<Listings?> listings();
  Future<RemoteSettings?> settings();
}

class SampleData implements HostelData {
  const SampleData();
  @override
  Future<Listings?> listings() async => null;
  @override
  Future<RemoteSettings?> settings() async => null;
}

class SupabaseData implements HostelData {
  SupabaseData(this.db);
  final SupabaseClient db;

  /// Connects with the public anon key from `app_config.dart`.
  static Future<SupabaseData> connect() async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
    return SupabaseData(Supabase.instance.client);
  }

  @override
  Future<Listings?> listings() async {
    // RLS returns only live hostels to the public.
    final rows = await db.from('hostels').select('*, rooms(*, beds(*)), rate_cards(*)');
    return listingsFromRows(rows);
  }

  @override
  Future<RemoteSettings?> settings() async => settingsFromRows(await db.from('app_settings').select());
}

/// Rows from `hostels` (with nested rooms → beds and rate_cards) → app models.
Listings listingsFromRows(List<Map<String, dynamic>> rows) {
  final hs = <Hostel>[], rooms = <String, List<Room>>{}, rates = <String, Map<String, int>>{}, pos = <String, (double, double)>{};
  final upi = <String, ({String id, String name})>{};
  for (final h in rows) {
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
                ),
            ],
          );
        }(),
    ]..sort((a, b) => a.n.compareTo(b.n));
    final rate = <String, int>{for (final c in (h['rate_cards'] as List? ?? const []).cast<Map<String, dynamic>>()) rateKey(c['ac'] as bool, c['share'] as int): c['rent'] as int};
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
        // Ratings come from verified reviews (F08); none read yet.
        rating: 0,
        reviews: 0,
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
      ),
    );
    rooms[id] = rs;
    rates[id] = rate;
    if (h['lat'] != null && h['lng'] != null) pos[id] = ((h['lat'] as num).toDouble(), (h['lng'] as num).toDouble());
    upi[id] = (id: h['upi_id'] as String? ?? '', name: h['upi_name'] as String? ?? '');
  }
  return (hostels: hs, rooms: rooms, rates: rates, pos: pos, upi: upi);
}

RemoteSettings settingsFromRows(List<Map<String, dynamic>> rows) {
  final m = {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  return (minBuild: int.tryParse(m['min_supported_build'] ?? '') ?? 0, maintenanceUntil: m['maintenance_until'] ?? '');
}
