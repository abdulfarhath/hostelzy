import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../photos/photo.dart';
import 'cache.dart';
import 'live.dart';
import 'repo.dart';

String _ymd(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

class SupabaseRepo implements HostelRepo {
  SupabaseRepo(this.db);
  final SupabaseClient db;

  /// Perf: signed links to private photos, kept for most of their hour, so a
  /// screen that rebuilds asks the server once and the image cache keeps
  /// working (a new link each time would download the photo again).
  final _signed = <String, ({Future<String?> url, DateTime until})>{};

  Future<String?> _signedUrl(String bucket, String path) {
    final k = '$bucket/$path';
    final now = DateTime.now();
    final hit = _signed[k];
    if (hit != null && now.isBefore(hit.until)) return hit.url;
    final Future<String?> f = db.storage.from(bucket).createSignedUrl(path, 3600);
    _signed[k] = (url: f, until: now.add(const Duration(minutes: 50)));
    // A failed link is asked for again next time.
    unawaited(f.then((_) {}, onError: (Object _) {
      if (identical(_signed[k]?.url, f)) _signed.remove(k);
    }));
    return f;
  }

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

  /// Perf: Explore shows many hostel cards at once; their photos come in one
  /// query (`hostel_id in (...)`) instead of one query per card.
  @override
  Future<Map<String, List<HostelPhoto>>> photosOfMany(List<String> hids) async {
    final by = <String, List<HostelPhoto>>{for (final h in hids) h: []};
    for (final r in await db.from('hostel_photos').select().inFilter('hostel_id', hids)) {
      by[r['hostel_id'] as String]?.add(photoFromRow(supabaseUrl, r));
    }
    return {for (final e in by.entries) e.key: sortPhotos(e.value)};
  }

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
    // Perf: each row's order at once (one round trip, not one per photo).
    // Every update touches a different row and only one sets the cover.
    await Future.wait([
      for (final (i, p) in ordered.indexed) db.from('hostel_photos').update({'ord': i, 'cover': p.id == coverId}).eq('id', p.id),
    ]);
  }

  @override
  Future<LiveRows?> live({String? me}) async {
    final r = await Future.wait([
      db.from('holds').select('*, beds(letter, rooms(number, label))').order('started_at', ascending: false),
      db.from('enquiries').select().order('created_at', ascending: false),
      db.from('payments').select('*, holds(beds(letter, rooms(number, label)))').order('created_at', ascending: false),
      db.from('complaints').select().order('created_at', ascending: false),
      me == null ? Future.value(<Map<String, dynamic>>[]) : db.from('stays').select('*, beds(letter, rooms(number, label))').or('left_on.is.null,refund_status.in.(due,sent,not_received)').order('joined_on', ascending: false),
      db.from('invite_signups').select().eq('status', 'pending').order('created_at', ascending: false),
      db.from('invoices').select(),
      db.from('owner_plans').select('hostel_id, trial_ends'),
      db.from('fair_cases').select(),
      db.from('hostel_staff').select('hostel_id, user_id, role'),
      db.from('manager_invites').select().order('created_at'),
      me == null ? Future.value(<Map<String, dynamic>>[]) : db.from('profiles').select('member, member_since, ref_code, referred_by').eq('id', me),
      db.from('reward_ledger').select().order('created_at'),
      db.from('layout_fixes').select().neq('status', 'withdrawn').order('created_at'),
      db.from('layout_fix_mutes').select('hostel_id, user_id, name'),
      // F24: notices and moves; empty before its SQL runs.
      db.from('move_requests').select('*, stays(name, beds(letter, rooms(number, label)))').neq('status', 'withdrawn').order('created_at', ascending: false).limit(100).then((v) => v, onError: (_) => <Map<String, dynamic>>[]),
    ]);
    return liveFromRows(holds: r[0], enquiries: r[1], payments: r[2], complaints: r[3], stays: r[4], signups: r[5], invoices: r[6], plans: r[7], cases: r[8], staff: r[9], managers: r[10], profile: me == null ? null : r[11], ledger: r[12], fixes: r[13], mutes: r[14], moves: r[15], me: me);
  }

  @override
  Future<String> sendEnquiry({required String hid, required String name, required String phone, String? bed, required String source, required String msg}) async {
    // F24 4a: the server reuses the tenant's open enquiry for this bed, or
    // records a new one and sets its HZ code.
    try {
      return await db.rpc('send_enquiry', params: {'p_hostel': hid, 'p_name': name, 'p_phone': phone, 'p_bed': bed, 'p_source': source, 'p_msg': msg}) as String;
    } on PostgrestException catch (e) {
      // Until FOUNDER-TODO 4zr1 runs there is no send_enquiry: insert as before.
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }
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
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body, String? photo}) =>
      db.from('complaints').insert({'hostel_id': hid, 'bed': bed, 'cat': cat, 'body': body, 'photo': ?photo});

  @override
  Future<String> uploadComplaintPhoto(String hid, String uid, Uint8List jpg) async {
    final path = '$hid/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await db.storage.from('complaint-photos').uploadBinary(path, jpg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  @override
  Future<String?> complaintPhotoUrl(String path) => _signedUrl('complaint-photos', path);

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
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn, bool before = false}) async {
    final r = await db
        .from('stays')
        .insert({'hostel_id': hid, 'bed_id': bedKey, 'name': name, 'phone': phone, 'rent': rent, 'advance': advance, if (before) 'via': 'before', 'joined_on': '${joinedOn.year}-${'${joinedOn.month}'.padLeft(2, '0')}-${'${joinedOn.day}'.padLeft(2, '0')}'})
        .select('via, late_days')
        .single();
    return (via: r['via'] as String, lateDays: r['late_days'] as int);
  }

  @override
  Future<void> saveRates(String hid, Map<String, int> rates, Map<int, ({bool ac, int rent})> rooms) async {
    await db.from('rate_cards').upsert([
      for (final e in rates.entries) {'hostel_id': hid, 'ac': e.key.startsWith('ac'), 'share': int.parse(e.key.replaceFirst(RegExp('^(ac|non)'), '')), 'rent': e.value},
    ], onConflict: 'hostel_id,ac,share');
    // Perf: every room's update at once (one round trip, not one per room).
    await Future.wait([
      for (final e in rooms.entries) db.from('rooms').update({'ac': e.value.ac, 'rent': e.value.rent}).eq('hostel_id', hid).eq('number', e.key),
    ]);
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
  Future<void> postReview({required String hid, required String name, required String kind, required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) =>
      db.from('reviews').insert({'hostel_id': hid, 'author_name': name, 'kind': kind, 'stars': stars, 'body': body, 'cats': cats, 'layout': layout, 'advance': advance, 'again': again});

  @override
  Future<void> replyReview(String id, String reply) => db.from('reviews').update({'reply': reply}).eq('id', id);

  @override
  Future<void> editReview(String id, {required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) =>
      db.from('reviews').update({'stars': stars, 'body': body, 'cats': cats, 'layout': layout, 'advance': advance, 'again': again}).eq('id', id);

  @override
  Future<void> reportReview(String id, String why) => db.rpc('report_review', params: {'p_review': id, 'p_why': why});

  @override
  Future<void> sendReport(String hid, String why, String note) => db.from('fair_reports').insert({'hostel_id': hid, 'why': why, 'note': note});

  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) => db.from('fair_cases').update({'owner_reply': reply, if (reopen) 'status': 'new'}).eq('id', key);

  @override
  Future<void> fixCase(String key) => db.rpc('fix_case', params: {'p_case': key});

  @override
  Future<void> acceptFairPlay() => db.rpc('accept_fair_play');

  @override
  Future<bool?> fairAccepted() async {
    try {
      return (await db.from('fair_play_accepts').select('user_id').limit(1)).isNotEmpty;
    } on PostgrestException catch (e) {
      debugPrint('fair play accepted: ${e.message}');
      return null;
    }
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
  Future<String> sendLayoutFix(String hid, int room, Map<String, dynamic> layout, String note, {String? photo}) async =>
      await db.rpc('send_layout_fix', params: {'p_hostel': hid, 'p_room': room, 'p_layout': layout, 'p_note': note, 'p_photo': photo}) as String;

  @override
  Future<String> sendQuickFix(String hid, int room, {required String item, required String issue, String note = '', String? photo}) async =>
      await db.rpc('send_quick_fix', params: {'p_hostel': hid, 'p_room': room, 'p_item': item, 'p_issue': issue, 'p_note': note, 'p_photo': photo}) as String;

  @override
  Future<void> setRepair(String id, String state) => db.rpc('set_repair', params: {'p_id': id, 'p_state': state});

  @override
  Future<void> muteFixAuthor(String fixId) => db.rpc('mute_fix_author', params: {'p_fix': fixId});

  @override
  Future<void> unmuteFixAuthor(String hid, String userId) => db.rpc('unmute_fix_author', params: {'p_hostel': hid, 'p_user': userId});

  @override
  Future<String> uploadFixPhoto(String hid, String uid, Uint8List jpg) async {
    final path = '$hid/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await db.storage.from('fix-photos').uploadBinary(path, jpg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  @override
  Future<String?> fixPhotoUrl(String path) => _signedUrl('fix-photos', path);

  @override
  Future<void> withdrawLayoutFix(String id) => db.rpc('withdraw_layout_fix', params: {'p_id': id});

  @override
  Future<void> decideLayoutFix(String id, bool approve, {String reason = ''}) => db.rpc('decide_layout_fix', params: {'p_id': id, 'p_approve': approve, 'p_reason': reason});

  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) => db.rpc('publish_layout', params: {'p_hostel': hid, 'p_room': room, 'p_layout': layout});

  @override
  Future<void> undoLayoutPublish(String hid, int room) => db.rpc('undo_layout_publish', params: {'p_hostel': hid, 'p_room': room});

  @override
  Future<RoomLayout?> roomLayout(String hid, int room) async {
    final rows = (await db.rpc('room_layout', params: {'p_hostel': hid, 'p_room': room}) as List).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : layoutFromRow(hid, rows.first);
  }

  @override
  Future<({String name, bool mine})> lockLayout(String hid, int room) async {
    final rows = (await db.rpc('lock_layout', params: {'p_hostel': hid, 'p_room': room}) as List).cast<Map<String, dynamic>>();
    final r = rows.first;
    return (name: r['name'] as String? ?? '', mine: r['mine'] as bool? ?? false);
  }

  @override
  Future<void> unlockLayout(String hid, int room) => db.rpc('unlock_layout', params: {'p_hostel': hid, 'p_room': room});

  @override
  Future<void> waitForLayout(String hid, int room) => db.rpc('wait_for_layout', params: {'p_hostel': hid, 'p_room': room});

  @override
  Future<Set<String>> layoutWaits() async {
    final rows = (await db.from('layout_waits').select('hostel_id, room').isFilter('told_at', null) as List).cast<Map<String, dynamic>>();
    return {for (final r in rows) '${r['hostel_id']}|${r['room']}'};
  }

  @override
  Future<List<ShapeRequest>> shapeRequests(String hid) async {
    final rows = await db.from('shape_requests').select().eq('hostel_id', hid).order('created_at');
    return [for (final r in rows) shapeRequestFromRow(r)];
  }

  @override
  Future<String> requestShape(String hid, int room, {required String shape, String note = '', double w = 0, double h = 0, List<String> photos = const []}) async =>
      await db.rpc('request_shape', params: {'p_hostel': hid, 'p_room': room, 'p_shape': shape, 'p_note': note, 'p_w': w, 'p_h': h, 'p_photos': photos}) as String;

  @override
  Future<void> sendShapeDrawing(String id, Map<String, dynamic> drawing) => db.rpc('send_shape_drawing', params: {'p_id': id, 'p_drawing': drawing});

  @override
  Future<String> saveAmenity(Amenity a) async => await db.rpc('save_amenity', params: {
    'p_hostel': a.hid,
    'p_id': a.key,
    'p_floor': a.floor,
    'p_kind': a.kind,
    'p_name': a.name,
    'p_qty': a.qty,
    'p_working': a.working,
    'p_place': a.place,
    'p_rooms': a.rooms,
  }) as String;

  @override
  Future<void> removeAmenity(String key) => db.rpc('remove_amenity', params: {'p_id': key});

  @override
  Stream<String> changes() {
    // The listener cancelling removes the channel.
    // ignore: close_sinks
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
    const base = '*, rooms(*, beds(*)), rate_cards(*), layouts(*), deals(*), reviews(*)';
    Future<List<Map<String, dynamic>>> hostelRows() async {
      try {
        return await db.from('hostels').select('$base, amenities(*)');
      } on PostgrestException catch (e) {
        // F23: until the amenities migration has run (FOUNDER-TODO 4u), load
        // the hostels without them instead of failing.
        debugPrint('listings without amenities: ${e.message}');
        return await db.from('hostels').select(base);
      }
    }

    // S5: strike counts are public (they hide deals and listings). F24 #18:
    // fair_standing adds when strike 2's 30 days of hidden deals end; before
    // its SQL runs (FOUNDER-TODO 4zf1) the plain counts are used.
    Future<(List, Map<String, Standing>)> standingRows() async {
      try {
        final st = await db.rpc('fair_standing') as List;
        return (st, standingFromRows(st.cast<Map>()));
      } on PostgrestException catch (e) {
        if (!_missingFn(e)) rethrow;
        return (await db.rpc('strike_counts') as List, <String, Standing>{});
      }
    }

    Future<List<Object?>> checkRows() async => await db.rpc('layout_checks') as List<Object?>;

    // F24 #15: how many different residents checked the hostel's layouts.
    Future<Map<String, int>> checkerRows() async {
      try {
        return {for (final r in (await db.rpc('hostel_layout_checks') as List).cast<Map>()) r['hostel_id'] as String: r['n'] as int};
      } on PostgrestException catch (e) {
        if (!_missingFn(e)) rethrow;
        return {};
      }
    }

    // Perf: the four reads don't depend on each other, so they go together
    // (one round trip of waiting instead of four in a row).
    final got = await Future.wait<Object>([hostelRows(), standingRows(), checkRows(), checkerRows()]);
    final rows = got[0] as List<Map<String, dynamic>>;
    final (st, standing) = got[1] as (List, Map<String, Standing>);
    // F19: "Checked by N residents · date" per room.
    final ck = got[2] as List<Object?>;
    final checks = <String, Map<int, (int, String)>>{};
    for (final r in ck.cast<Map>()) {
      (checks[r['hostel_id'] as String] ??= {})[r['room'] as int] = (r['n'] as int, dayMon(DateTime.parse(r['last_at'] as String).toLocal()));
    }
    final checkers = got[3] as Map<String, int>;
    // F24 item 30: kept on the phone for the next time there's no network.
    unawaited(saveListingRows(rows));
    return listingsFromRows(rows, strikes: {for (final r in st.cast<Map>()) r['hostel_id'] as String: r['n'] as int}, checks: checks, checkers: checkers, standing: standing);
  }

  @override
  Future<RemoteSettings?> settings() async => settingsFromRows(await db.from('app_settings').select());

  @override
  Future<void> saveProfile({required String name, required String email, required String phone, required String role}) =>
      db.from('profiles').upsert({'name': name, 'email': email, 'phone': phone, 'role': role}, onConflict: 'id');

  @override
  Future<void> startRent({required String hid, required String stayKey, required int amount, required String note}) =>
      db.from('payments').insert({'hostel_id': hid, 'stay_id': stayKey, 'kind': 'rent', 'amount': amount, 'note': note});

  @override
  Future<void> saveReminders(String uid, Map<String, dynamic> settings) => db.from('profiles').update({'reminders': settings}).eq('id', uid);

  // "edit own profile" lets a user update their own row; guard_profile leaves the name alone.
  @override
  Future<void> saveName(String uid, String name) => db.from('profiles').update({'name': name}).eq('id', uid);
  @override
  Future<String?> myWhatsApp(String uid) async => (await db.from('profiles').select('whatsapp').eq('id', uid).maybeSingle())?['whatsapp'] as String?;
  @override
  Future<void> saveWhatsApp(String uid, String wa) => db.from('profiles').update({'whatsapp': wa}).eq('id', uid);

  @override
  Future<Map<String, dynamic>?> loadReminders(String uid) async {
    final r = await db.from('profiles').select('reminders').eq('id', uid).maybeSingle();
    return r?['reminders'] as Map<String, dynamic>?;
  }

  @override
  Future<void> savePushToken(String token) => db.from('push_tokens').upsert({'token': token, 'platform': 'android', 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'token');

  @override
  Future<void> removePushToken(String token) => db.from('push_tokens').delete().eq('token', token);

  @override
  Future<List<DayMenu>?> menu(String hid) async => menuFromRows(await db.from('menus').select('day, breakfast, lunch, dinner').eq('hostel_id', hid));

  @override
  Future<void> saveMenu(String hid, List<DayMenu> week) => db.from('menus').upsert([
    for (final (i, d) in week.indexed) {'hostel_id': hid, 'day': i, 'breakfast': d.b.trim(), 'lunch': d.l.trim(), 'dinner': d.n.trim()},
  ], onConflict: 'hostel_id,day');

  @override
  Future<Map<String, (int, int)>> mealTimes(String hid) async {
    final r = await db.from('menus').select('breakfast_time, lunch_time, dinner_time').eq('hostel_id', hid).limit(1).maybeSingle();
    if (r == null) return {};
    return {
      for (final (k, c) in const [('b', 'breakfast_time'), ('l', 'lunch_time'), ('n', 'dinner_time')])
        k: ?parseMealTime(r[c] as String?),
    };
  }

  @override
  Future<void> saveMealTimes(String hid, Map<String, String> times) => db.rpc('save_meal_times', params: {'p_hostel': hid, 'p': times});

  @override
  Future<void> rateMeal(String hid, String meal, String rating) => db.rpc('rate_meal', params: {'p_hostel': hid, 'p_meal': meal, 'p_rating': rating});

  @override
  Future<Map<String, Map<String, int>>> mealVotes(String hid) async {
    final out = <String, Map<String, int>>{};
    for (final r in (await db.rpc('meal_votes', params: {'p_hostel': hid}) as List).cast<Map<String, dynamic>>()) {
      out.putIfAbsent(r['meal'] as String, () => {})[r['rating'] as String] = (r['n'] as num).toInt();
    }
    return out;
  }

  @override
  Future<Map<String, ({String phone, String wa})>> ownerContacts(List<String> hids) async => {
    for (final r in (await db.rpc('owner_contacts', params: {'p_hostels': hids}) as List).cast<Map<String, dynamic>>())
      if ('${r['phone'] ?? ''}${r['whatsapp'] ?? ''}'.isNotEmpty) r['hostel_id'] as String: (phone: r['phone'] as String? ?? '', wa: r['whatsapp'] as String? ?? ''),
  };

  @override
  Future<String> saveHostel(String? id, Map<String, dynamic> p) async => await db.rpc('save_hostel', params: {'p_id': id, 'p': p}) as String;
  @override
  Future<void> saveRooms(String hid, List<Map<String, dynamic>> rooms) => db.rpc('save_rooms', params: {'p_hostel': hid, 'p_rooms': rooms});
  @override
  Future<String> ownerInvite(String hid, String name, String phone) async => await db.rpc('new_owner_invite', params: {'h': hid, 'p_name': name, 'p_phone': phone}) as String;
  @override
  Future<String> joinAsOwner(String code) async => await db.rpc('join_as_owner', params: {'p_code': code}) as String;
  @override
  Future<bool> ownerLinked(String hid) async => (await db.from('hostel_staff').select('user_id').eq('hostel_id', hid).eq('role', 'owner').limit(1)).isNotEmpty;
  @override
  Future<void> goLive(String hid) => db.rpc('go_live', params: {'h': hid});
  @override
  Future<void> giveNotice(DateTime lastDay, String reason) => db.rpc('give_notice', params: {'p_last_day': _ymd(lastDay), 'p_reason': reason});
  @override
  Future<void> askMove(String toBedKey) => db.rpc('ask_move', params: {'p_to_bed': toBedKey});
  @override
  Future<void> withdrawMove(String id) => db.rpc('withdraw_move', params: {'p_id': id});
  @override
  Future<void> answerMove(String id, bool accept) => db.rpc('answer_move', params: {'p_id': id, 'p_accept': accept});
  @override
  Future<void> markLeaving(String stayKey, DateTime day) => db.rpc('mark_leaving', params: {'p_stay': stayKey, 'p_day': _ymd(day)});
  @override
  Future<void> movedOut(String stayKey) => db.rpc('moved_out', params: {'p_stay': stayKey});
  @override
  Future<void> sendRefund(String stayKey, String utr) => db.rpc('send_refund', params: {'p_stay': stayKey, 'p_utr': utr});
  @override
  Future<void> confirmRefund(String stayKey, bool got) => db.rpc('confirm_refund', params: {'p_stay': stayKey, 'p_got': got});
  @override
  Future<List<MeterRow>> meters(String hid, DateTime month) async => [
    for (final r in await db.from('meter_readings').select('*, rooms(number)').eq('hostel_id', hid).gte('month', _ymd(DateTime(month.year, month.month - 1))).lte('month', _ymd(DateTime(month.year, month.month))).order('month')) meterFromRow(r),
  ];
  @override
  Future<int> saveMeter(String hid, DateTime month, double rate, List<({int room, int reading})> rows) async =>
      (await db.rpc('save_meter', params: {'p_hostel': hid, 'p_month': _ymd(DateTime(month.year, month.month)), 'p_rate': rate, 'p_rows': [for (final r in rows) {'room': r.room, 'reading': r.reading}]}) as num).toInt();
  @override
  Future<Level?> myLevel() async {
    final r = await db.rpc('my_level');
    return r is Map ? levelFrom(r.cast<String, dynamic>()) : null;
  }

  @override
  Future<String> uploadCasePhoto(String hid, String uid, Uint8List jpg) async {
    final path = '$hid/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await db.storage.from('case-photos').uploadBinary(path, jpg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  @override
  Future<String?> casePhotoUrl(String path) => _signedUrl('case-photos', path);
  @override
  Future<void> addCasePhoto(String caseKey, String path) => db.rpc('case_photo', params: {'p_case': caseKey, 'p_path': path});
  @override
  Future<Map<String, HostelSignals>> signals() async => {
    for (final r in (await db.rpc('hostel_signals') as List).cast<Map<String, dynamic>>())
      r['hostel_id'] as String: (replyMin: r['reply_minutes'] as int? ?? 0, replyN: r['reply_n'] as int? ?? 0, complaints30: r['complaints_30d'] as int? ?? 0, residents: r['residents'] as int? ?? 0, photos: r['photos'] as int? ?? 0, rooms: r['rooms'] as int? ?? 0, layouts: r['layouts'] as int? ?? 0),
  };
  // Staff may update their beds; the server stamps the time (F24 SQL 4zy1).
  @override
  Future<void> confirmBeds(String hid) => db.from('beds').update({'confirmed_at': DateTime.now().toUtc().toIso8601String()}).eq('hostel_id', hid);
  @override
  Future<void> confirmLayouts(String hid) => db.rpc('confirm_layouts', params: {'p_hostel': hid});
  @override
  Future<void> confirmRates(String hid) => db.rpc('confirm_rates', params: {'p_hostel': hid});
  @override
  Future<void> answerJoined(String holdId, String answer) => db.rpc('answer_joined', params: {'p_hold': holdId, 'p_answer': answer});
  @override
  Future<Set<String>> joinAnswers() async => {for (final r in await db.from('join_answers').select('hold_id')) r['hold_id'] as String};
  @override
  Future<Map<String, HostelFlags>> flags() async => {
    for (final r in (await db.rpc('hostel_flags') as List).cast<Map<String, dynamic>>())
      r['hostel_id'] as String: (beds: r['beds'] as int? ?? 0, featured: r['featured'] == true, dealsPaused: r['deals_paused'] == true),
  };
  @override
  Future<Set<String>> managedHostels(String uid) async => {
    for (final r in await db.from('hostel_staff').select('hostel_id').eq('user_id', uid).eq('role', 'manager')) r['hostel_id'] as String,
  };
  @override
  Future<DateTime?> setItemWorking(String hid, int room, String item, bool working) async {
    final at = await db.rpc('set_item_working', params: {'p_hostel': hid, 'p_room': room, 'p_item': item, 'p_working': working});
    return at == null ? null : DateTime.parse(at as String).toLocal();
  }

  @override
  Future<DateTime> holdWalkIn(String bedKey) async => DateTime.parse(await db.rpc('hold_walk_in', params: {'p_bed': bedKey}) as String).toLocal();
  @override
  Future<void> releaseWalkIn(String bedKey) => db.rpc('release_walk_in', params: {'p_bed': bedKey});
  @override
  Future<({Map<String, bool> notify, List<String> areas})?> loadNotify(String uid) async {
    final r = await db.from('profiles').select('notify, searched_areas').eq('id', uid).maybeSingle();
    if (r == null) return null;
    return (
      notify: {for (final e in ((r['notify'] as Map?) ?? const {}).entries) if (e.value is bool) e.key as String: e.value as bool},
      areas: [for (final a in (r['searched_areas'] as List? ?? const [])) a as String],
    );
  }

  @override
  Future<void> saveNotify(String uid, Map<String, bool> notify) => db.from('profiles').update({'notify': notify}).eq('id', uid);
  @override
  Future<void> saveSearchedAreas(String uid, List<String> areas) => db.from('profiles').update({'searched_areas': areas}).eq('id', uid);
  @override
  Future<void> teamHello() => db.rpc('team_hello');
  @override
  Future<List<TeamMember>> teamMembers() async => [
    for (final r in await db.from('team_members').select().order('created_at'))
      (name: r['name'] as String? ?? '', phone: r['phone'] as String? ?? '', role: r['role'] as String? ?? 'Everything', joined: r['joined_at'] != null),
  ];
  @override
  Future<void> inviteTeamMember(String name, String phone, String role) => db.from('team_members').insert({'name': name, 'phone': phone, 'role': role});
  @override
  Future<List<Lead>> teamTracker() async => [for (final r in (await db.rpc('team_tracker') as List).cast<Map<String, dynamic>>()) leadFromRow(r)];
  @override
  Future<void> setLeadStage(String hid, int stage) => db.from('hostel_leads').upsert({'hostel_id': hid, 'stage': leadStages[stage], 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'hostel_id');

  @override
  Future<void> holdSeen(List<String> holdIds) async {
    try {
      await db.rpc('hold_seen', params: {'p_holds': holdIds});
    } on PostgrestException catch (e) {
      // Before FOUNDER-TODO 4ze26 runs the tenant just doesn't see "Owner reviewing".
      if (!_missingFn(e)) rethrow;
    }
  }

  @override
  Future<void> joinWaitlist(String hid) => db.from('verify_waitlist').insert({'hostel_id': hid});

  @override
  Future<Set<String>> myWaitlist() async => {for (final r in await db.from('verify_waitlist').select('hostel_id')) r['hostel_id'] as String};

  @override
  Future<void> sendClaim(String hid, String name, String phone) => db.from('claim_requests').insert({'hostel_id': hid, 'name': name, 'phone': phone});

  @override
  Future<Map<String, ({int verified, int listed})>?> areaCounts() async {
    try {
      return {
        for (final r in (await db.rpc('area_counts') as List).cast<Map<String, dynamic>>())
          r['area'] as String: (verified: (r['verified'] as num).toInt(), listed: (r['listed'] as num).toInt()),
      };
    } on PostgrestException catch (e) {
      if (!_missingFn(e)) rethrow;
      return null;
    }
  }
}

/// A function the app calls isn't on the server yet (its SQL hasn't run).
bool _missingFn(PostgrestException e) => e.code == 'PGRST202' || e.code == '42883' || e.message.contains('Could not find the function');
