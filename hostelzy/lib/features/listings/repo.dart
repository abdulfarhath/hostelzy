// F13: where the app's data comes from. `SampleRepo` keeps the built-in
// sample hostels (offline, tests); `SupabaseRepo` reads live hostels from the
// database. Row Level Security decides what each user may read or write.

import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' show Offset;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../photos/photo.dart';
import 'live.dart';

/// Live hostels with their rooms, beds and rate cards.
/// Published room layouts come too, for signed-in users (RLS: women's PGs rule).
typedef Listings = ({List<Hostel> hostels, Map<String, List<Room>> rooms, Map<String, Map<String, int>> rates, Map<String, (double, double)> pos, Map<String, ({String id, String name})> upi, Map<String, Map<int, RoomLayout>> layouts, Map<String, Deals> deals, Map<String, List<Rule>> rules, Map<String, List<Review>> reviews, Map<String, int> strikes});

/// Remote switches (F15): the oldest supported build and maintenance mode.
typedef RemoteSettings = ({int minBuild, String maintenanceUntil});

abstract class HostelRepo {
  /// True when this talks to a real server (Supabase); false on sample data.
  bool get remote;

  /// Live hostels, or null to keep the built-in sample data.
  Future<Listings?> listings();
  Future<RemoteSettings?> settings();

  /// The signed-in user's profile. The phone is typed, never marked verified.
  Future<void> saveProfile({required String name, required String email, required String phone, required String role});

  /// This phone's push token (FCM).
  Future<void> savePushToken(String token);

  /// C: the hostel's invite code from the server ([renew]: a new one, the old
  /// link stops working). Null on sample data.
  Future<String?> inviteCode(String hid, {bool renew = false});

  /// C: asks to join the hostel with [code]; returns the hostel's name.
  /// Throws [UnsupportedError] on sample data, or with the server's reason.
  Future<String> joinWithInvite(String code, {required String name, required String phone, String bed = ''});

  /// C: the owner approves or rejects an invite sign-up.
  Future<void> decideSignup(String id, bool approve);

  /// Removes this phone's token (sign-out, account deleted).
  Future<void> removePushToken(String token);

  /// C: deletes the signed-in user's data on the server (keeps others'
  /// records without their identity). Throws with the server's reason.
  Future<void> deleteMyAccount();

  /// B7: a hostel's photos, cover first. Empty on sample data.
  Future<List<HostelPhoto>> photos(String hid);

  /// B7: uploads a compressed JPEG to the hostel's folder and records it.
  /// Throws [UnsupportedError] on sample data (nothing is uploaded).
  Future<HostelPhoto> addPhoto(String hid, Uint8List jpg, {required String label, required int ord, required bool cover});

  Future<void> removePhoto(HostelPhoto p);

  /// Saves the order (list order) and which photo is the cover.
  Future<void> savePhotoOrder(List<HostelPhoto> ordered, String coverId);
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

  /// S1: a tenant's hold on bed [bedKey] (`free`, or `book` with the
  /// [advance] payment started). The server checks the bed is free and issues
  /// the HZ code. Throws [UnsupportedError] on sample data.
  Future<({String id, String ref, String? payId})> placeHold({required String hid, required String bedKey, required String opt, int advance = 0});

  /// S1: releases a hold. The tenant's own release also cancels its
  /// unconfirmed advance ([cancelPay]); staff only release the bed.
  Future<void> releaseHold(String id, {bool cancelPay = true});

  /// S2: the owner confirms a tenant's free hold (`held`).
  Future<void> setHoldStatus(String id, String status);

  /// S2: the owner adds a resident on bed [bedKey]. The server matches the
  /// phone to Hostelzy (60 days), opens a Fair Play case when added late, and
  /// books the bed. Returns how it matched.
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn});

  /// S3: owner edits. The rate card (keys from [rateKey]) and each room's
  /// type and rent, by room number.
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms);
  Future<void> saveDeals(String hid, Deals d);
  Future<void> saveRules(String hid, List<Rule> rules);
  Future<void> saveUpi(String hid, String id, String name);

  /// S7: the owner's UTR for a plan invoice (→ checking); the team then marks
  /// it paid or not received (`paid` | `missing`).
  Future<void> sendInvoiceUtr(String key, String utr);
  Future<void> checkInvoice(String key, String status);

  /// S4: a resident's review of the hostel they stay at (the server checks
  /// the confirmed stay), and the owner's reply.
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again});
  Future<void> replyReview(String id, String reply);

  /// S5: Fair Play. A tenant's private report; the owner's reply (sending a
  /// case the team returned back to them); the owner's 48-hour fix; the
  /// team's decision (`close` | `more` | `strike`, with the result text).
  Future<void> sendReport(String hid, String why, String note);
  Future<void> replyCase(String key, String reply, {bool reopen = false});
  Future<void> fixCase(String key);
  Future<void> decideCase(String key, String hid, String how, String? decision);

  /// S8: the owner's one-time manager code, and joining with it (returns the
  /// hostel's name). Throws with the server's reason; [UnsupportedError] on
  /// sample data.
  Future<String> managerInvite(String hid, String name, String phone);
  Future<String> joinAsManager(String code);

  /// S6: the user's referral code (made once on the server), and using a
  /// friend's code before a first stay (returns the friend's first name).
  Future<String> referralCode();
  Future<String> useReferralCode(String code);
}

class SampleRepo implements HostelRepo {
  const SampleRepo();
  @override
  bool get remote => false;
  @override
  Future<Listings?> listings() async => null;
  @override
  Future<RemoteSettings?> settings() async => null;
  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) async {}
  @override
  Future<void> savePushToken(String token) async {}
  @override
  Future<String?> inviteCode(String hid, {bool renew = false}) async => null;
  @override
  Future<String> joinWithInvite(String code, {required String name, required String phone, String bed = ''}) => throw UnsupportedError('sample data');
  @override
  Future<void> decideSignup(String id, bool approve) async {}
  @override
  Future<void> removePushToken(String token) async {}
  @override
  Future<void> deleteMyAccount() async {}
  @override
  Future<List<HostelPhoto>> photos(String hid) async => const [];
  @override
  Future<HostelPhoto> addPhoto(String hid, Uint8List jpg, {required String label, required int ord, required bool cover}) => throw UnsupportedError('sample data');
  @override
  Future<void> removePhoto(HostelPhoto p) async {}
  @override
  Future<void> savePhotoOrder(List<HostelPhoto> ordered, String coverId) async {}
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
  @override
  Future<({String id, String ref, String? payId})> placeHold({required String hid, required String bedKey, required String opt, int advance = 0}) => throw UnsupportedError('sample data');
  @override
  Future<void> releaseHold(String id, {bool cancelPay = true}) async {}
  @override
  Future<void> setHoldStatus(String id, String status) async {}
  @override
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn}) => throw UnsupportedError('sample data');
  @override
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms) async {}
  @override
  Future<void> saveDeals(String hid, Deals d) async {}
  @override
  Future<void> saveRules(String hid, List<Rule> rules) async {}
  @override
  Future<void> saveUpi(String hid, String id, String name) async {}
  @override
  Future<void> sendInvoiceUtr(String key, String utr) async {}
  @override
  Future<void> checkInvoice(String key, String status) async {}
  @override
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) async {}
  @override
  Future<void> replyReview(String id, String reply) async {}
  @override
  Future<void> sendReport(String hid, String why, String note) async {}
  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) async {}
  @override
  Future<void> fixCase(String key) async {}
  @override
  Future<void> decideCase(String key, String hid, String how, String? decision) async {}
  @override
  Future<String> managerInvite(String hid, String name, String phone) => throw UnsupportedError('sample data');
  @override
  Future<String> joinAsManager(String code) => throw UnsupportedError('sample data');
  @override
  Future<String> referralCode() => throw UnsupportedError('sample data');
  @override
  Future<String> useReferralCode(String code) => throw UnsupportedError('sample data');
}

class SupabaseRepo implements HostelRepo {
  SupabaseRepo(this.db);
  final SupabaseClient db;
  @override
  bool get remote => true;

  /// Connects with the public anon key from `app_config.dart`. Signed-in
  /// users send their Firebase ID token ([idToken]); Supabase checks it
  /// (Third-party Auth) and the database rules use its uid.
  static Future<SupabaseRepo> connect({Future<String?> Function()? idToken}) async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey, accessToken: idToken);
    return SupabaseRepo(Supabase.instance.client);
  }

  @override
  Future<String?> inviteCode(String hid, {bool renew = false}) async => await db.rpc(renew ? 'new_hostel_invite' : 'hostel_invite', params: {'h': hid}) as String?;

  @override
  Future<String> joinWithInvite(String code, {required String name, required String phone, String bed = ''}) async =>
      await db.rpc('join_with_invite', params: {'p_code': code, 'p_name': name, 'p_phone': phone, 'p_bed': bed}) as String;

  @override
  Future<void> decideSignup(String id, bool approve) => db.rpc('decide_signup', params: {'p_id': id, 'p_approve': approve});

  @override
  Future<void> deleteMyAccount() => db.rpc('delete_my_account');

  @override
  Future<List<HostelPhoto>> photos(String hid) async =>
      sortPhotos([for (final r in await db.from('hostel_photos').select().eq('hostel_id', hid)) photoFromRow(supabaseUrl, r)]);

  @override
  Future<HostelPhoto> addPhoto(String hid, Uint8List jpg, {required String label, required int ord, required bool cover}) async {
    final path = '$hid/${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${jpg.length.toRadixString(36)}.jpg';
    await db.storage.from('hostel-photos').uploadBinary(path, jpg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    if (cover) await db.from('hostel_photos').update({'cover': false}).eq('hostel_id', hid).eq('cover', true);
    final row = await db.from('hostel_photos').insert({'hostel_id': hid, 'path': path, 'label': label, 'ord': ord, 'cover': cover}).select().single();
    return photoFromRow(supabaseUrl, row);
  }

  @override
  Future<void> removePhoto(HostelPhoto p) async {
    await db.from('hostel_photos').delete().eq('id', p.id);
    await db.storage.from('hostel-photos').remove([p.path]);
  }

  @override
  Future<void> savePhotoOrder(List<HostelPhoto> ordered, String coverId) async {
    if (ordered.isEmpty) return;
    // One cover at a time: clear it first, then set order and the new cover.
    await db.from('hostel_photos').update({'cover': false}).inFilter('id', [for (final p in ordered) p.id]);
    for (final (i, p) in ordered.indexed) {
      await db.from('hostel_photos').update({'ord': i, 'cover': p.id == coverId}).eq('id', p.id);
    }
  }

  @override
  Future<LiveRows?> live({String? me}) async {
    final r = await Future.wait([
      db.from('holds').select('*, beds(letter, rooms(number, label))').order('started_at', ascending: false),
      db.from('enquiries').select().order('created_at', ascending: false),
      db.from('payments').select('*, holds(beds(letter, rooms(number, label)))').order('created_at', ascending: false),
      db.from('complaints').select().order('created_at', ascending: false),
      me == null ? Future.value(<Map<String, dynamic>>[]) : db.from('stays').select('*, beds(letter, rooms(number, label))').isFilter('left_on', null).order('joined_on', ascending: false),
      db.from('invite_signups').select().eq('status', 'pending').order('created_at', ascending: false),
      db.from('invoices').select(),
      db.from('owner_plans').select('hostel_id, trial_ends'),
      db.from('fair_cases').select(),
      db.from('hostel_staff').select('hostel_id, user_id, role'),
      db.from('manager_invites').select().order('created_at'),
      me == null ? Future.value(<Map<String, dynamic>>[]) : db.from('profiles').select('member, member_since, ref_code, referred_by').eq('id', me),
      db.from('reward_ledger').select().order('created_at'),
    ]);
    return liveFromRows(holds: r[0], enquiries: r[1], payments: r[2], complaints: r[3], stays: r[4], signups: r[5], invoices: r[6], plans: r[7], cases: r[8], staff: r[9], managers: r[10], profile: me == null ? null : r[11], ledger: r[12], me: me);
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
  Future<({String id, String ref, String? payId})> placeHold({required String hid, required String bedKey, required String opt, int advance = 0}) async {
    final h = await db.from('holds').insert({'hostel_id': hid, 'bed_id': bedKey, 'opt': opt == 'book' ? 'advance' : 'free'}).select('id, ref').single();
    String? payId;
    if (opt == 'book') {
      final p = await db.from('payments').insert({'hostel_id': hid, 'hold_id': h['id'], 'kind': 'advance', 'amount': advance, 'note': h['ref']}).select('id').single();
      payId = p['id'] as String;
    }
    return (id: h['id'] as String, ref: h['ref'] as String, payId: payId);
  }

  @override
  Future<void> releaseHold(String id, {bool cancelPay = true}) async {
    await db.from('holds').update({'status': 'released'}).eq('id', id);
    if (cancelPay) await db.from('payments').update({'status': 'cancelled'}).eq('hold_id', id).inFilter('status', ['pending', 'waiting', 'missing']);
  }

  @override
  Future<void> setHoldStatus(String id, String status) => db.from('holds').update({'status': status}).eq('id', id);

  @override
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn}) async {
    final r = await db
        .from('stays')
        .insert({'hostel_id': hid, 'bed_id': bedKey, 'name': name, 'phone': phone, 'rent': rent, 'advance': advance, 'joined_on': '${joinedOn.year}-${'${joinedOn.month}'.padLeft(2, '0')}-${'${joinedOn.day}'.padLeft(2, '0')}'})
        .select('via, late_days')
        .single();
    return (via: r['via'] as String, lateDays: r['late_days'] as int);
  }

  @override
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms) async {
    await db.from('rate_cards').upsert([
      for (final e in rates.entries) {'hostel_id': hid, 'ac': e.key.startsWith('ac'), 'share': int.parse(e.key.replaceFirst(RegExp('^(ac|non)'), '')), 'rent': e.value},
    ], onConflict: 'hostel_id,ac,share');
    for (final e in rooms.entries) {
      await db.from('rooms').update({'ac': e.value.ac, 'rent': e.value.rent}).eq('hostel_id', hid).eq('number', e.key);
    }
  }

  @override
  Future<void> saveDeals(String hid, Deals d) => db.from('deals').upsert({'hostel_id': hid, 'deals_on': d.on.toList(), 'target': d.target, 'confirmed_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'hostel_id');

  @override
  Future<void> saveRules(String hid, List<Rule> rules) => db.from('hostels').update({'rules': [for (final r in rules) {'k': r.k, 'v': r.v}]}).eq('id', hid);

  @override
  Future<void> saveUpi(String hid, String id, String name) => db.from('hostels').update({'upi_id': id, 'upi_name': name}).eq('id', hid);

  @override
  Future<void> sendInvoiceUtr(String key, String utr) => db.from('invoices').update({'utr': utr, 'status': 'checking'}).eq('id', key);

  @override
  Future<void> checkInvoice(String key, String status) => db.from('invoices').update({'status': status, if (status == 'paid') 'late': 0}).eq('id', key);

  @override
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) =>
      db.from('reviews').insert({'hostel_id': hid, 'author_name': name, 'kind': kind, 'stars': stars, 'body': body, 'cats': cats, 'layout': layout, 'advance': advance, 'again': again});

  @override
  Future<void> replyReview(String id, String reply) => db.from('reviews').update({'reply': reply}).eq('id', id);

  @override
  Future<void> sendReport(String hid, String why, String note) => db.from('fair_reports').insert({'hostel_id': hid, 'why': why, 'note': note});

  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) => db.from('fair_cases').update({'owner_reply': reply, if (reopen) 'status': 'new'}).eq('id', key);

  @override
  Future<void> fixCase(String key) => db.rpc('fix_case', params: {'p_case': key});

  @override
  Future<void> decideCase(String key, String hid, String how, String? decision) async {
    if (how == 'strike') await db.from('strikes').insert({'hostel_id': hid, 'case_id': key});
    await db.from('fair_cases').update({'status': how == 'more' ? 'waiting' : 'closed', 'decision': decision}).eq('id', key);
  }

  @override
  Future<String> managerInvite(String hid, String name, String phone) async => await db.rpc('new_manager_invite', params: {'h': hid, 'p_name': name, 'p_phone': phone}) as String;

  @override
  Future<String> joinAsManager(String code) async => await db.rpc('join_as_manager', params: {'p_code': code}) as String;

  @override
  Future<String> referralCode() async => await db.rpc('my_referral_code') as String;

  @override
  Future<String> useReferralCode(String code) async => await db.rpc('use_referral_code', params: {'p_code': code}) as String;

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
    final rows = await db.from('hostels').select('*, rooms(*, beds(*)), rate_cards(*), layouts(*), deals(*), reviews(*)');
    // S5: strike counts are public (they hide deals and listings).
    final st = await db.rpc('strike_counts') as List;
    return listingsFromRows(rows, strikes: {for (final r in st.cast<Map>()) r['hostel_id'] as String: r['n'] as int});
  }

  @override
  Future<RemoteSettings?> settings() async => settingsFromRows(await db.from('app_settings').select());

  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) =>
      db.from('profiles').upsert({'name': name, 'email': email, 'phone': phone, 'role': role}, onConflict: 'id');

  @override
  Future<void> savePushToken(String token) => db.from('push_tokens').upsert({'token': token, 'platform': 'android', 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'token');

  @override
  Future<void> removePushToken(String token) => db.from('push_tokens').delete().eq('token', token);
}

/// Rows from `hostels` (with nested rooms → beds and rate_cards) → app models.
Listings listingsFromRows(List<Map<String, dynamic>> rows, {Map<String, int> strikes = const {}}) {
  final hs = <Hostel>[], rooms = <String, List<Room>>{}, rates = <String, Map<String, int>>{}, pos = <String, (double, double)>{};
  final upi = <String, ({String id, String name})>{};
  final lays = <String, Map<int, RoomLayout>>{};
  final deals = <String, Deals>{}, rules = <String, List<Rule>>{};
  final reviews = <String, List<Review>>{};
  for (final h in rows) {
    // S4: verified residents' reviews, newest first; the rating comes from them.
    final revRows = (h['reviews'] as List? ?? const []).cast<Map<String, dynamic>>().toList()..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
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
  return (hostels: hs, rooms: rooms, rates: rates, pos: pos, upi: upi, layouts: lays, deals: deals, rules: rules, reviews: reviews, strikes: strikes);
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
