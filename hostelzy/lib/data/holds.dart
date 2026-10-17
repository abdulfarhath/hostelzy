
/// F05: a tenant tapped "Ask on WhatsApp" / "WhatsApp owner". Hostelzy
/// records it (HZ code, OTP-verified phone, hostel, bed, time) before
/// WhatsApp opens, so the owner can trust it whatever the tenant types.
class Enquiry {
  Enquiry({required this.ref, required this.name, required this.phone, required this.hid, this.bed, required this.at, required this.from, required this.msg, this.contacted = false});
  final String ref, name, phone, hid, from, msg;

  /// Bed asked about; null = "Any bed".
  final String? bed;

  /// Time in ms since epoch.
  final int at;
  final bool contacted;
  Enquiry withContacted() => Enquiry(ref: ref, name: name, phone: phone, hid: hid, bed: bed, at: at, from: from, msg: msg, contacted: true);
}

List<Enquiry> seedEnquiries(int now) => [
  Enquiry(ref: 'HZ-4821', name: 'Ravi Teja', phone: '9000000029', hid: 'anjani', bed: '204-A', at: now - 6 * 60000, from: 'Hostel page · Ask on WhatsApp', msg: 'Can I come and see the rooms this evening?'),
  Enquiry(ref: 'HZ-4817', name: 'Sandeep Kumar', phone: '9000000032', hid: 'anjani', bed: '201-C', at: now - 18 * 60000, from: 'Hold · WhatsApp owner', msg: 'Can I come and see it today at 6 pm?'),
  Enquiry(ref: 'HZ-4809', name: 'Imran Shaikh', phone: '9000000033', hid: 'anjani', at: now - 2 * 3600000, from: 'Hostel page · Ask on WhatsApp', msg: 'Is there a bed free from 5 Oct?', contacted: true),
];

class HoldRequest {
  HoldRequest({required this.id, required this.name, required this.bed, required this.type, required this.secs, required this.note, required this.start, this.hold, this.trusted = false});
  final String id, name, bed, type, note;
  final int secs, start;
  final String? hold;

  /// F09: the tenant is a Trusted tenant (owners see the badge, not where they stayed).
  final bool trusted;
}

List<HoldRequest> seedRequests(int now) => [HoldRequest(id: 'k1', name: 'Karthik M', bed: '102-C', type: 'Free hold', secs: 2460, note: 'Can I visit at 6 pm today?', start: now, trusted: true), HoldRequest(id: 'v1', name: 'Vamsi Reddy', bed: '301-A', type: 'Free hold', secs: 3180, note: 'Joining Infosys on 12 Oct.', start: now)];

/// Free hold length; Members (F09) get 2 hours.
const freeHoldSecs = 3600, memberHoldSecs = 7200;

// ------------------------------------------------------------ F09 Stay Rewards

/// ₹100 off the next Hostelzy hostel's first month (given by the owner,
/// credited on the owner's next Hostelzy invoice) and ₹100 per referral.
const memberReward = 100, referralReward = 100;

/// Trusted tenant after this many months, rent on time, no owner complaints.
const trustedMonths = 6;

class Hold {
  Hold({required this.id, required this.hid, required this.bed, required this.room, required this.opt, required this.start, required this.status, this.ref, this.paid = 0, this.perks = const [], this.fixedFee = 0, this.trusted = false, this.ends, this.seen, this.declined = false});
  final String id, hid, bed, opt;

  /// F24 item 13: the monthly rent locked by a booking on the server (0 = not known).
  final int fixedFee;
  final int room, start;

  /// F24 #16: placed by a Trusted tenant (set by the server; owners see it).
  final bool trusted;

  /// When a free hold ends on the server (ms): 1 hour, or 2 for Members.
  final int? ends;

  /// F04 booking: HZ code, advance paid to the owner, and the locked deal.
  final String? ref;
  final int paid;
  final List<String> perks;

  /// F26 #9: when the owner (or a manager) first opened this hold (ms; null =
  /// not yet). Only then do the tenant's steps say "Owner reviewing".
  final int? seen;

  /// F26 #9: the owner released it (said no), not the tenant.
  final bool declined;

  /// waiting | confirmed | held | booked | released
  final String status;
  Hold withStatus(String s, {bool? declined}) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: s, ref: ref, paid: paid, perks: perks, fixedFee: fixedFee, trusted: trusted, ends: ends, seen: seen, declined: declined ?? this.declined);
  Hold withPerks(List<String> p) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: status, ref: ref, paid: paid, perks: p, fixedFee: fixedFee, trusted: trusted, ends: ends, seen: seen, declined: declined);
  Hold withSeen(int at) => Hold(id: id, hid: hid, bed: bed, room: room, opt: opt, start: start, status: status, ref: ref, paid: paid, perks: perks, fixedFee: fixedFee, trusted: trusted, ends: ends, seen: at, declined: declined);
}
