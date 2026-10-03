// F13: where the app's data comes from. `SampleRepo` keeps the built-in
// sample hostels (offline, tests); `SupabaseRepo` reads live hostels from the
// database. Row Level Security decides what each user may read or write.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../photos/photo.dart';
import 'cache.dart';
import 'live.dart';

/// Live hostels with their rooms, beds and rate cards.
/// Published room layouts come too, for signed-in users (RLS: women's PGs rule).
typedef Listings = ({List<Hostel> hostels, Map<String, List<Room>> rooms, Map<String, Map<String, int>> rates, Map<String, (double, double)> pos, Map<String, ({String id, String name})> upi, Map<String, Map<int, RoomLayout>> layouts, Map<String, Deals> deals, Map<String, List<Rule>> rules, Map<String, List<Review>> reviews, Map<String, int> strikes, Map<String, Map<int, (int, String)>> checks, Map<String, List<Amenity>> amenities});

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

  /// F21: starts this month's rent payment for the resident's own stay
  /// (then UPI → UTR → the owner confirms, as for advances).
  Future<void> startRent({required String hid, required String stayKey, required int amount, required String note});

  /// F20: the user's reminder settings, backed up on their profile so a new
  /// phone gets them back. Null on sample data or when nothing is saved.
  Future<void> saveReminders(String uid, Map<String, dynamic> settings);

  /// F24 item 23: the user's own name on their profile.
  Future<void> saveName(String uid, String name);
  Future<Map<String, dynamic>?> loadReminders(String uid);

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
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body, String? photo});

  /// F21 W3: a complaint's photo (private bucket `complaint-photos`).
  Future<String> uploadComplaintPhoto(String hid, String uid, Uint8List jpg);
  Future<String?> complaintPhotoUrl(String path);
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
  /// F19: layout fixes. A resident sends or withdraws one; the owner (the
  /// team after 7 days) decides; owners publish their own edits and can undo.
  Future<String> sendLayoutFix(String hid, int room, Map<String, dynamic> layout, String note, {String? photo});

  /// F19 extras: a quick fix on one item, the owner's repair answer, muting
  /// a resident's suggestions, and the fix photo (private: the uploader, the
  /// hostel's staff and the team).
  Future<String> sendQuickFix(String hid, int room, {required String item, required String issue, String note = '', String? photo});
  Future<void> setRepair(String id, String state);
  Future<void> muteFixAuthor(String fixId);
  Future<void> unmuteFixAuthor(String hid, String userId);
  Future<String> uploadFixPhoto(String hid, String uid, Uint8List jpg);
  Future<String?> fixPhotoUrl(String path);
  Future<void> withdrawLayoutFix(String id);
  Future<void> decideLayoutFix(String id, bool approve, {String reason = ''});
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout);
  Future<void> undoLayoutPublish(String hid, int room);

  /// F24 item 11: "Ask Hostelzy to draw it" (staff) and the hostel's
  /// requests, with the team's drawing once sent. Photos go up with
  /// [uploadFixPhoto]. Publishing the room closes its sent request. The team
  /// sends a drawing from the app's team mode (or the console).
  Future<List<ShapeRequest>> shapeRequests(String hid);
  Future<String> requestShape(String hid, int room, {required String shape, String note = '', double w = 0, double h = 0, List<String> photos = const []});
  Future<void> sendShapeDrawing(String id, Map<String, dynamic> drawing);

  /// F23: add or change a floor / room amenity (staff or a resident of the
  /// hostel); returns the row id. Residents: at most 20 changes a day.
  Future<String> saveAmenity(Amenity a);
  Future<void> removeAmenity(String key);

  /// A hostel's food menu, Monday first (null when it has none); anyone can
  /// read a live hostel's. Staff save the whole week at once.
  Future<List<DayMenu>?> menu(String hid);
  Future<void> saveMenu(String hid, List<DayMenu> week);

  /// A resident's Good / Okay / Poor for today's [meal] ('b', 'l' or 'n');
  /// staff get this week's counts per meal, never who.
  Future<void> rateMeal(String hid, String meal, String rating);
  Future<Map<String, Map<String, int>>> mealVotes(String hid);

  /// F24: owners' numbers, only for hostels where this user holds, enquired,
  /// stays or works (DECISIONS F07: the number shows after a hold).
  Future<Map<String, String>> ownerContacts(List<String> hids);

  /// F24: the team onboards a hostel: [saveHostel] creates (null [id]) or
  /// updates the draft (basics, rate card, owner's number, rooms); the owner
  /// joins with a one-time code; [goLive] starts the 30-day trial.
  Future<String> saveHostel(String? id, Map<String, dynamic> p);
  Future<void> saveRooms(String hid, List<Map<String, dynamic>> rooms);
  Future<String> ownerInvite(String hid, String name, String phone);
  Future<String> joinAsOwner(String code);
  Future<bool> ownerLinked(String hid);
  Future<void> goLive(String hid);

  /// F24 item 5: notice, moves, moving out and the refund.
  Future<void> giveNotice(DateTime lastDay, String reason);
  Future<void> askMove(String toBedKey);
  Future<void> withdrawMove(String id);
  Future<void> answerMove(String id, bool accept);
  Future<void> markLeaving(String stayKey, DateTime day);
  Future<void> movedOut(String stayKey);
  Future<void> sendRefund(String stayKey, String utr);
  Future<void> confirmRefund(String stayKey, bool got);

  /// F24 item 6: counts per live hostel (reply speed, complaints, residents,
  /// photos, rooms, layouts) for the hostel page and the ranking.
  Future<Map<String, HostelSignals>> signals();

  /// F24 item 7: a fan, the AC or a window Working / Not working, saved for
  /// tenants; not working raises a complaint. The complaint's date (null when working).
  Future<DateTime?> setItemWorking(String hid, int room, String item, bool working);

  /// F24 item 8: the owner keeps a bed for a walk-in (1 hour); when it ends.
  Future<DateTime> holdWalkIn(String bedKey);
  Future<void> releaseWalkIn(String bedKey);

  /// F24 item 22: the Settings switches and the areas the tenant searched,
  /// kept on the profile (null before that SQL runs).
  Future<({Map<String, bool> notify, List<String> areas})?> loadNotify(String uid);
  Future<void> saveNotify(String uid, Map<String, bool> notify);
  Future<void> saveSearchedAreas(String uid, List<String> areas);

  /// F24 item 29: team mode from the server (team accounts only).
  Future<void> teamHello();
  Future<List<TeamMember>> teamMembers();
  Future<void> inviteTeamMember(String name, String phone, String role);
  Future<List<Lead>> teamTracker();
  Future<void> setLeadStage(String hid, int stage);
}

/// F24 item 29: one person on the Hostelzy team.
typedef TeamMember = ({String name, String phone, String role, bool joined});

/// The tracker's first four stages as `hostel_leads.stage` has them.
const leadStages = ['lead', 'visited', 'signed_up', 'data_complete'];

/// F24: real counts behind "Usually replies in ~N min" and the ranking.
typedef HostelSignals = ({int replyMin, int replyN, int complaints30, int residents, int photos, int rooms, int layouts});

String _ymd(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

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
  Future<void> startRent({required String hid, required String stayKey, required int amount, required String note}) => throw UnsupportedError('sample data');
  @override
  Future<void> saveReminders(String uid, Map<String, dynamic> settings) async {}

  @override
  Future<void> saveName(String uid, String name) async {}
  @override
  Future<Map<String, dynamic>?> loadReminders(String uid) async => null;
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
  Future<void> raiseComplaint({required String hid, required String bed, required String cat, required String body, String? photo}) async {}
  @override
  Future<String> uploadComplaintPhoto(String hid, String uid, Uint8List jpg) => throw UnsupportedError('sample data');
  @override
  Future<String?> complaintPhotoUrl(String path) async => null;
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

  @override
  Future<String> sendLayoutFix(String hid, int room, Map<String, dynamic> layout, String note, {String? photo}) => throw UnsupportedError('sample data');
  @override
  Future<String> sendQuickFix(String hid, int room, {required String item, required String issue, String note = '', String? photo}) => throw UnsupportedError('sample data');
  @override
  Future<void> setRepair(String id, String state) async {}
  @override
  Future<void> muteFixAuthor(String fixId) async {}
  @override
  Future<void> unmuteFixAuthor(String hid, String userId) async {}
  @override
  Future<String> uploadFixPhoto(String hid, String uid, Uint8List jpg) => throw UnsupportedError('sample data');
  @override
  Future<String?> fixPhotoUrl(String path) async => null;
  @override
  Future<void> withdrawLayoutFix(String id) async {}
  @override
  Future<void> decideLayoutFix(String id, bool approve, {String reason = ''}) async {}
  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) async {}

  @override
  Future<List<ShapeRequest>> shapeRequests(String hid) async => const [];

  @override
  Future<String> requestShape(String hid, int room, {required String shape, String note = '', double w = 0, double h = 0, List<String> photos = const []}) => throw UnsupportedError('sample data');

  @override
  Future<void> sendShapeDrawing(String id, Map<String, dynamic> drawing) async {}
  @override
  Future<void> undoLayoutPublish(String hid, int room) async {}

  @override
  Future<String> saveAmenity(Amenity a) async => a.key ?? a.id;

  @override
  Future<void> removeAmenity(String key) async {}

  @override
  Future<List<DayMenu>?> menu(String hid) async => null;
  @override
  Future<void> saveMenu(String hid, List<DayMenu> week) async {}
  @override
  Future<void> rateMeal(String hid, String meal, String rating) async {}
  @override
  Future<Map<String, Map<String, int>>> mealVotes(String hid) async => {};
  @override
  Future<Map<String, String>> ownerContacts(List<String> hids) async => {};
  @override
  Future<String> saveHostel(String? id, Map<String, dynamic> p) => throw UnsupportedError('sample data');
  @override
  Future<void> saveRooms(String hid, List<Map<String, dynamic>> rooms) async {}
  @override
  Future<String> ownerInvite(String hid, String name, String phone) => throw UnsupportedError('sample data');
  @override
  Future<String> joinAsOwner(String code) => throw UnsupportedError('sample data');
  @override
  Future<bool> ownerLinked(String hid) async => false;
  @override
  Future<void> goLive(String hid) => throw UnsupportedError('sample data');
  @override
  Future<void> giveNotice(DateTime lastDay, String reason) async {}
  @override
  Future<void> askMove(String toBedKey) async {}
  @override
  Future<void> withdrawMove(String id) async {}
  @override
  Future<void> answerMove(String id, bool accept) async {}
  @override
  Future<void> markLeaving(String stayKey, DateTime day) async {}
  @override
  Future<void> movedOut(String stayKey) async {}
  @override
  Future<void> sendRefund(String stayKey, String utr) async {}
  @override
  Future<void> confirmRefund(String stayKey, bool got) async {}
  @override
  Future<Map<String, HostelSignals>> signals() async => {};
  @override
  Future<DateTime?> setItemWorking(String hid, int room, String item, bool working) async => working ? null : DateTime.now();
  @override
  Future<DateTime> holdWalkIn(String bedKey) async => DateTime.now().add(const Duration(hours: 1));
  @override
  Future<void> releaseWalkIn(String bedKey) async {}
  @override
  Future<({Map<String, bool> notify, List<String> areas})?> loadNotify(String uid) async => null;
  @override
  Future<void> saveNotify(String uid, Map<String, bool> notify) async {}
  @override
  Future<void> saveSearchedAreas(String uid, List<String> areas) async {}
  @override
  Future<void> teamHello() async {}
  @override
  Future<List<TeamMember>> teamMembers() async => const [];
  @override
  Future<void> inviteTeamMember(String name, String phone, String role) async {}
  @override
  Future<List<Lead>> teamTracker() async => const [];
  @override
  Future<void> setLeadStage(String hid, int stage) async {}
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
  Future<String?> complaintPhotoUrl(String path) async => db.storage.from('complaint-photos').createSignedUrl(path, 3600);

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
  Future<String?> fixPhotoUrl(String path) async => db.storage.from('fix-photos').createSignedUrl(path, 3600);

  @override
  Future<void> withdrawLayoutFix(String id) => db.rpc('withdraw_layout_fix', params: {'p_id': id});

  @override
  Future<void> decideLayoutFix(String id, bool approve, {String reason = ''}) => db.rpc('decide_layout_fix', params: {'p_id': id, 'p_approve': approve, 'p_reason': reason});

  @override
  Future<void> publishLayout(String hid, int room, Map<String, dynamic> layout) => db.rpc('publish_layout', params: {'p_hostel': hid, 'p_room': room, 'p_layout': layout});

  @override
  Future<void> undoLayoutPublish(String hid, int room) => db.rpc('undo_layout_publish', params: {'p_hostel': hid, 'p_room': room});

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
    List<Map<String, dynamic>> rows;
    try {
      rows = await db.from('hostels').select('$base, amenities(*)');
    } on PostgrestException catch (e) {
      // F23: until the amenities migration has run (FOUNDER-TODO 4u), load
      // the hostels without them instead of failing.
      debugPrint('listings without amenities: ${e.message}');
      rows = await db.from('hostels').select(base);
    }
    // S5: strike counts are public (they hide deals and listings).
    final st = await db.rpc('strike_counts') as List;
    // F19: "Checked by N residents · date" per room.
    final ck = await db.rpc('layout_checks') as List;
    final checks = <String, Map<int, (int, String)>>{};
    for (final r in ck.cast<Map>()) {
      (checks[r['hostel_id'] as String] ??= {})[r['room'] as int] = (r['n'] as int, dayMon(DateTime.parse(r['last_at'] as String).toLocal()));
    }
    // F24 item 30: kept on the phone for the next time there's no network.
    unawaited(saveListingRows(rows));
    return listingsFromRows(rows, strikes: {for (final r in st.cast<Map>()) r['hostel_id'] as String: r['n'] as int}, checks: checks);
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
  Future<Map<String, String>> ownerContacts(List<String> hids) async => {
    for (final r in (await db.rpc('owner_contacts', params: {'p_hostels': hids}) as List).cast<Map<String, dynamic>>())
      if ((r['phone'] as String? ?? '').isNotEmpty) r['hostel_id'] as String: r['phone'] as String,
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
  Future<Map<String, HostelSignals>> signals() async => {
    for (final r in (await db.rpc('hostel_signals') as List).cast<Map<String, dynamic>>())
      r['hostel_id'] as String: (replyMin: r['reply_minutes'] as int? ?? 0, replyN: r['reply_n'] as int? ?? 0, complaints30: r['complaints_30d'] as int? ?? 0, residents: r['residents'] as int? ?? 0, photos: r['photos'] as int? ?? 0, rooms: r['rooms'] as int? ?? 0, layouts: r['layouts'] as int? ?? 0),
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
}

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
Listings listingsFromRows(List<Map<String, dynamic>> rows, {Map<String, int> strikes = const {}, Map<String, Map<int, (int, String)>> checks = const {}}) {
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
                )..walkInUntil = b['walk_in_until'] == null ? 0 : DateTime.parse(b['walk_in_until'] as String).millisecondsSinceEpoch,
            ],
          )..acSince = r['ac_repair_since'] == null ? '' : dayMon(DateTime.parse(r['ac_repair_since'] as String));
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
        live: (h['status'] as String? ?? 'live') == 'live',
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
  return (hostels: hs, rooms: rooms, rates: rates, pos: pos, upi: upi, layouts: lays, deals: deals, rules: rules, reviews: reviews, strikes: strikes, checks: checks, amenities: ams);
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
    ..outline = outlineFromJson(r['outline']);
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
