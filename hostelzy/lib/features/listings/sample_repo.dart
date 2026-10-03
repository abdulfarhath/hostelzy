import 'dart:async';
import 'dart:typed_data';

import '../../data.dart';
import '../photos/photo.dart';
import 'live.dart';
import 'repo.dart';

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
  Future<String?> myWhatsApp(String uid) async => null;
  @override
  Future<void> saveWhatsApp(String uid, String wa) async {}
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
  Future<({String via, int lateDays})> addStay({required String hid, String? bedKey, required String name, required String phone, required int rent, required int advance, required DateTime joinedOn, bool before = false}) => throw UnsupportedError('sample data');
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
  Future<void> editReview(String id, {required int stars, String body = '', Map<String, int> cats = const {}, String? layout, String? advance, String? again}) async {}
  @override
  Future<void> reportReview(String id, String why) async {}
  @override
  Future<List<MeterRow>> meters(String hid, DateTime month) async => const [];
  @override
  Future<int> saveMeter(String hid, DateTime month, double rate, List<({int room, int reading})> rows) => throw UnsupportedError('sample data');
  @override
  Future<Level?> myLevel() async => null;
  @override
  Future<String> uploadCasePhoto(String hid, String uid, Uint8List jpg) => throw UnsupportedError('sample data');
  @override
  Future<String?> casePhotoUrl(String path) async => null;
  @override
  Future<void> addCasePhoto(String caseKey, String path) async {}
  @override
  Future<void> sendReport(String hid, String why, String note) async {}
  @override
  Future<void> replyCase(String key, String reply, {bool reopen = false}) async {}
  @override
  Future<void> fixCase(String key) async {}
  @override
  Future<void> decideCase(String key, String hid, String how, String? decision) async {}
  @override
  Future<void> acceptFairPlay() async {}
  @override
  Future<bool?> fairAccepted() async => null;
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
  Future<RoomLayout?> roomLayout(String hid, int room) async => null;
  @override
  Future<({String name, bool mine})> lockLayout(String hid, int room) async => (name: '', mine: true);
  @override
  Future<void> unlockLayout(String hid, int room) async {}
  @override
  Future<void> waitForLayout(String hid, int room) => throw UnsupportedError('sample data');
  @override
  Future<Set<String>> layoutWaits() async => {};

  @override
  Future<String> saveAmenity(Amenity a) async => a.key ?? a.id;

  @override
  Future<void> removeAmenity(String key) async {}

  @override
  Future<List<DayMenu>?> menu(String hid) async => null;
  @override
  Future<void> saveMenu(String hid, List<DayMenu> week) async {}
  @override
  Future<Map<String, (int, int)>> mealTimes(String hid) async => {};
  @override
  Future<void> saveMealTimes(String hid, Map<String, String> times) async {}
  @override
  Future<void> rateMeal(String hid, String meal, String rating) async {}
  @override
  Future<Map<String, Map<String, int>>> mealVotes(String hid) async => {};
  @override
  Future<Map<String, ({String phone, String wa})>> ownerContacts(List<String> hids) async => {};
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
  Future<Map<String, HostelFlags>> flags() async => {};
  @override
  Future<Set<String>> managedHostels(String uid) async => {};
  @override
  Future<void> confirmBeds(String hid) async {}
  @override
  Future<void> confirmLayouts(String hid) async {}
  @override
  Future<void> confirmRates(String hid) async {}
  @override
  Future<void> answerJoined(String holdId, String answer) async {}
  @override
  Future<Set<String>> joinAnswers() async => {};
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
