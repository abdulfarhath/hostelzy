// F13: where the app's data comes from. `SampleRepo` keeps the built-in
// sample hostels (offline, tests); `SupabaseRepo` reads live hostels from the
// database. Row Level Security decides what each user may read or write.

import 'dart:async';
import 'dart:typed_data';

import '../../data.dart';
import '../photos/photo.dart';
import 'live.dart';

export 'rows.dart';
export 'sample_repo.dart';
export 'supabase_repo.dart';

/// Live hostels with their rooms, beds and rate cards.
/// Published room layouts come too, for signed-in users (RLS: women's PGs rule).
typedef Listings = ({List<Hostel> hostels, Map<String, List<Room>> rooms, Map<String, Map<String, int>> rates, Map<String, (double, double)> pos, Map<String, ({String id, String name})> upi, Map<String, Map<int, RoomLayout>> layouts, Map<String, Deals> deals, Map<String, List<Rule>> rules, Map<String, List<Review>> reviews, Map<String, int> strikes, Map<String, Map<int, (int, String)>> checks, Map<String, int> checkers, Map<String, List<Amenity>> amenities, Map<String, Standing> standing});

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

  /// F24 Wave 4c: an owner's WhatsApp number when it isn't their phone
  /// ('' = same as the phone). Null when the server has no such field yet.
  Future<String?> myWhatsApp(String uid);
  Future<void> saveWhatsApp(String uid, String wa);
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

  /// Perf: several hostels' photos in one go (Explore's cards), by hostel id;
  /// every id asked for is in the map (empty when it has none).
  Future<Map<String, List<HostelPhoto>>> photosOfMany(List<String> hids);

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
  /// F24 #18: [before] marks someone who lived there before the hostel went
  /// live ("Joined before Hostelzy"); the server allows it only before
  /// go-live, and after it for the Hostelzy team.
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn, bool before = false});

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

  /// F24 4a: the author changes their own review; anyone reports one for
  /// abuse (the Hostelzy team decides).
  Future<void> editReview(String id, {required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again});
  Future<void> reportReview(String id, String why);

  /// S5: Fair Play. A tenant's private report; the owner's reply (sending a
  /// case the team returned back to them); the owner's 48-hour fix; the
  /// team's decision (`close` | `more` | `strike`, with the result text).
  Future<void> sendReport(String hid, String why, String note);
  Future<void> replyCase(String key, String reply, {bool reopen = false});
  Future<void> fixCase(String key);
  Future<void> decideCase(String key, String hid, String how, String? decision);

  /// F24 #18: the owner's "I agree" to the Fair Play rules, kept on the
  /// server once per account; and whether this account has agreed (null
  /// when the server can't say yet).
  Future<void> acceptFairPlay();
  Future<bool?> fairAccepted();

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

  /// F24 Wave 4b (F12): one room's published layout for the Room tab. A
  /// women's PG lists its layouts only to people with a hold there; others
  /// get room by room (a few a day; then it throws "hold a bed to see more").
  Future<RoomLayout?> roomLayout(String hid, int room);

  /// F12 one editor at a time: take (or refresh) the room's 10-minute edit
  /// lock; [mine] false names whoever holds it. Let it go when leaving.
  Future<({String name, bool mine})> lockLayout(String hid, int room);
  Future<void> unlockLayout(String hid, int room);

  /// F24 item 27: "Tell me when it's ready" on a room with no layout, and
  /// the rooms (`hid|room`) this tenant still waits for.
  Future<void> waitForLayout(String hid, int room);
  Future<Set<String>> layoutWaits();

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

  /// F25: put a shared thing on the floor map (0–100 each way), or take it
  /// off (null, null). Owner, manager or the team. False when the server
  /// doesn't have it yet (FOUNDER-TODO 4zk2 not run): nothing was saved.
  Future<bool> placeAmenity(String key, int? x, int? y);

  /// A hostel's food menu, Monday first (null when it has none); anyone can
  /// read a live hostel's. Staff save the whole week at once.
  Future<List<DayMenu>?> menu(String hid);
  Future<void> saveMenu(String hid, List<DayMenu> week);

  /// F24 Wave 4c: the menu's meal times, b | l | n → (start, end) minutes;
  /// only the ones set. Staff (and the team) save all three at once.
  Future<Map<String, (int, int)>> mealTimes(String hid);
  Future<void> saveMealTimes(String hid, Map<String, String> times);

  /// A resident's Good / Okay / Poor for today's [meal] ('b', 'l' or 'n');
  /// staff get this week's counts per meal, never who.
  Future<void> rateMeal(String hid, String meal, String rating);
  Future<Map<String, Map<String, int>>> mealVotes(String hid);

  /// F24: owners' numbers, only for hostels where this user holds, enquired,
  /// stays or works (DECISIONS F07: the number shows after a hold).
  /// F24 Wave 4c: with the owner's WhatsApp number ('' = same as the phone).
  Future<Map<String, ({String phone, String wa})>> ownerContacts(List<String> hids);

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

  /// F24 items 20 and 21: per live hostel, its bed count, whether it has the
  /// featured spot (80+ beds plan) and whether its deals are paused (plan 15+
  /// days late). Empty before that SQL runs.
  Future<Map<String, HostelFlags>> flags();

  /// F24 item 17: the hostels where this user is a manager, not the owner
  /// (plan, deals, rates and Fair Play are the owner's).
  Future<Set<String>> managedHostels(String uid);

  /// F24 item 9: the owner's "Yes, all free" (every bed of the hostel; the
  /// server stores its own time) and "All still correct" for the layouts.
  Future<void> confirmBeds(String hid);
  Future<void> confirmLayouts(String hid);

  /// F24 Wave 4d (F03): the owner's "Rates still right" (every rate card of
  /// the hostel; the server stores its own time). Owner only.
  Future<void> confirmRates(String hid);

  /// F24 item 14: the tenant's "Did you join?" for an ended hold (yes |
  /// not_yet | deciding), and the holds they already answered. Only the
  /// Hostelzy team reads the answers.
  Future<void> answerJoined(String holdId, String answer);
  Future<Set<String>> joinAnswers();
  /// F24 #25: meter readings for [month] and the month before (staff: their
  /// hostel's; a resident: their own room's), and saving a month's readings
  /// (rooms by number). Throws before the Wave 1 SQL has run.
  Future<List<MeterRow>> meters(String hid, DateTime month);
  Future<int> saveMeter(String hid, DateTime month, double rate, List<({int room, int reading})> rows);

  /// F24 #16: the signed-in tenant's level from the server.
  Future<Level?> myLevel();

  /// F24 #18: a photo with the owner's Fair Play reply (private bucket).
  Future<String> uploadCasePhoto(String hid, String uid, Uint8List jpg);
  Future<String?> casePhotoUrl(String path);
  Future<void> addCasePhoto(String caseKey, String path);

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

/// F24: the featured spot and paused deals, from `hostel_flags()`.
typedef HostelFlags = ({int beds, bool featured, bool dealsPaused});

/// F24 #18: a hostel's Fair Play standing from `fair_standing()`: when strike
/// 2's hidden deals come back ([until], null when not on strike 2) and why the
/// last strike came (`case` | `fixes`, "3 fixes in 6 months").
typedef Standing = ({DateTime? until, bool dealsHidden, bool removed, String? why});
