// F13: where the app's data comes from. `SampleRepo` keeps the built-in
// sample hostels (offline, tests); `SupabaseRepo` reads live hostels from the
// database. Row Level Security decides what each user may read or write.

import 'dart:async';
import 'dart:ui' show Offset;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';
import '../../data.dart';
import 'live.dart';

/// Live hostels with their rooms, beds and rate cards.
/// Published room layouts come too, for signed-in users (RLS: women's PGs rule).
typedef Listings = ({List<Hostel> hostels, Map<String, List<Room>> rooms, Map<String, Map<String, int>> rates, Map<String, (double, double)> pos, Map<String, ({String id, String name})> upi, Map<String, Map<int, RoomLayout>> layouts});

/// Remote switches (F15): the oldest supported build and maintenance mode.
typedef RemoteSettings = ({int minBuild, String maintenanceUntil});

abstract class HostelRepo {
  /// Live hostels, or null to keep the built-in sample data.
  Future<Listings?> listings();
  Future<RemoteSettings?> settings();

  /// The signed-in user's profile. The phone is typed, never marked verified.
  Future<void> saveProfile({required String name, required String email, required String phone, required String role});

  /// This phone's push token (FCM).
  Future<void> savePushToken(String token);

  /// B6: what this user may see of holds, enquiries, payments and complaints;
  /// null keeps the built-in sample data.
  Future<LiveRows?> live({String? me});

  /// B6: emits a table name whenever one of [liveTables] changes (Realtime).
  Stream<String> changes();

  /// C: live writes. Each throws with the server's reason; the app then
  /// refetches, and Realtime tells the other phone.
  /// A tenant's enquiry; returns the server's HZ code.
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg});
  Future<void> markContacted(String ref);
  Future<void> sendUtr(String paymentId, String utr);
  /// Received + a hold: the hold becomes a booking too.
  Future<void> confirmPayment(String paymentId, bool received, {String? holdId});
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body});
  Future<void> updateComplaint(String key, {required String status, required String note});
}

class SampleRepo implements HostelRepo {
  const SampleRepo();
  @override
  Future<Listings?> listings() async => null;
  @override
  Future<RemoteSettings?> settings() async => null;
  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) async {}
  @override
  Future<void> savePushToken(String token) async {}
  @override
  Future<LiveRows?> live({String? me}) async => null;
  @override
  Stream<String> changes() => const Stream.empty();
  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) => throw UnsupportedError('sample data');
  @override
  Future<void> markContacted(String ref) async {}
  @override
  Future<void> sendUtr(String paymentId, String utr) async {}
  @override
  Future<void> confirmPayment(String paymentId, bool received, {String? holdId}) async {}
  @override
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body}) async {}
  @override
  Future<void> updateComplaint(String key, {required String status, required String note}) async {}
}

class SupabaseRepo implements HostelRepo {
  SupabaseRepo(this.db);
  final SupabaseClient db;

  /// Connects with the public anon key from `app_config.dart`. Signed-in
  /// users send their Firebase ID token ([idToken]); Supabase checks it
  /// (Third-party Auth) and the database rules use its uid.
  static Future<SupabaseRepo> connect({Future<String?> Function()? idToken}) async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey, accessToken: idToken);
    return SupabaseRepo(Supabase.instance.client);
  }

  @override
  Future<LiveRows?> live({String? me}) async {
    final r = await Future.wait([
      db.from('holds').select('*, beds(letter, rooms(number, label))').order('started_at', ascending: false),
      db.from('enquiries').select().order('created_at', ascending: false),
      db.from('payments').select('*, holds(beds(letter, rooms(number, label)))').order('created_at', ascending: false),
      db.from('complaints').select().order('created_at', ascending: false),
      me == null ? Future.value(<Map<String, dynamic>>[]) : db.from('stays').select('hostel_id, user_id, confirmed, left_on').eq('user_id', me),
    ]);
    return liveFromRows(holds: r[0], enquiries: r[1], payments: r[2], complaints: r[3], stays: r[4], me: me);
  }

  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) async {
    // The server sets the HZ code (B5); 'new' is replaced.
    final row = await db.from('enquiries').insert({'hostel_id': hid, 'ref': 'new', 'name': name, 'phone': phone, 'bed': bed, 'source': source, 'msg': msg}).select('ref').single();
    return row['ref'] as String;
  }

  @override
  Future<void> markContacted(String ref) => db.from('enquiries').update({'contacted': true}).eq('ref', ref);

  @override
  Future<void> sendUtr(String paymentId, String utr) => db.from('payments').update({'utr': utr, 'status': 'waiting'}).eq('id', paymentId);

  @override
  Future<void> confirmPayment(String paymentId, bool received, {String? holdId}) async {
    await db.from('payments').update({'status': received ? 'paid' : 'missing'}).eq('id', paymentId);
    if (received && holdId != null) await db.from('holds').update({'status': 'booked'}).eq('id', holdId);
  }

  @override
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body}) =>
      db.from('complaints').insert({'hostel_id': hid, 'bed': bed, 'cat': cat, 'body': body});

  @override
  Future<void> updateComplaint(String key, {required String status, required String note}) =>
      db.from('complaints').update({'status': status == 'Resolved' ? 'Fixed' : status, 'note': note}).eq('id', key);

  @override
  Stream<String> changes() {
    final out = StreamController<String>();
    var ch = db.channel('hz-live');
    for (final t in liveTables) {
      ch = ch.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: t, callback: (_) => out.add(t));
    }
    ch.subscribe();
    out.onCancel = () => db.removeChannel(ch);
    return out.stream;
  }

  @override
  Future<Listings?> listings() async {
    // RLS returns only live hostels to the public.
    final rows = await db.from('hostels').select('*, rooms(*, beds(*)), rate_cards(*), layouts(*)');
    return listingsFromRows(rows);
  }

  @override
  Future<RemoteSettings?> settings() async => settingsFromRows(await db.from('app_settings').select());

  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) =>
      db.from('profiles').upsert({'name': name, 'email': email, 'phone': phone, 'role': role}, onConflict: 'id');

  @override
  Future<void> savePushToken(String token) => db.from('push_tokens').upsert({'token': token, 'platform': 'android', 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'token');
}

/// Rows from `hostels` (with nested rooms → beds and rate_cards) → app models.
Listings listingsFromRows(List<Map<String, dynamic>> rows) {
  final hs = <Hostel>[], rooms = <String, List<Room>>{}, rates = <String, Map<String, int>>{}, pos = <String, (double, double)>{};
  final upi = <String, ({String id, String name})>{};
  final lays = <String, Map<int, RoomLayout>>{};
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
    lays[id] = {
      for (final l in (h['layouts'] as List? ?? const []).cast<Map<String, dynamic>>().where((l) => l['stage'] == 'published')) l['room'] as int: layoutFromRow(id, l),
    };
  }
  return (hostels: hs, rooms: rooms, rates: rates, pos: pos, upi: upi, layouts: lays);
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
    ..bunks.addAll({for (final e in (r['bunks'] as Map? ?? const {}).entries) e.key as String: e.value as String});
}

RemoteSettings settingsFromRows(List<Map<String, dynamic>> rows) {
  final m = {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  return (minBuild: int.tryParse(m['min_supported_build'] ?? '') ?? 0, maintenanceUntil: m['maintenance_until'] ?? '');
}
