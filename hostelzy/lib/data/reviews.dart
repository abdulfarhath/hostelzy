
// ------------------------------------------------------------ F08 reviews

const reviewCats = ['Food', 'Cleanliness', 'Safety', 'Water and power', 'Owner'];

/// A review from a resident with a confirmed stay (one per stay).
class Review {
  Review({required this.id, required this.hid, required this.name, required this.stars, required this.text, required this.stay, this.kind = '30-day', this.cats = const {}, this.layout, this.advance, this.again, this.reply, this.replyWhen, this.fresh = false, this.author, this.edited = false, this.reported = false});
  final String id, hid, name, stay, kind;

  /// F24 4a: the author can edit their review, so these change.
  String text;
  int stars;
  Map<String, int> cats;

  /// Who wrote it (the account id on the server, 'me' on sample data).
  final String? author;

  /// Changed by its author after posting.
  bool edited;

  /// Reported for abuse from this phone (the team decides).
  bool reported;

  /// "Is the room layout accurate?" Yes | Mostly | No (F12).
  String? layout;

  /// Exit review: did the advance come back? all | part | not.
  String? advance, again;
  String? reply, replyWhen;

  /// Not yet seen by the owner.
  bool fresh;
}

List<Review> seedReviews() => [
  Review(id: 'r1', hid: 'anjani', name: 'Karthik M.', stars: 5, text: 'Clean rooms, good food on weekdays. Got my ₹2,000 back the day I left.', stay: 'Stayed 8 months · left Aug 2026', kind: 'exit', advance: 'all', again: 'Yes'),
  Review(id: 'r2', hid: 'anjani', name: 'Naveen G.', stars: 3, text: 'Water pressure drops after 9 pm on the 2nd floor.', stay: 'Staying since Jun 2026', reply: 'Thanks Naveen. We’re fitting a booster pump on 10 Oct.', replyWhen: 'replied 3 days later'),
  Review(id: 'r3', hid: 'anjani', name: 'Teja N.', stars: 4, text: 'Room not swept for a few days in September, fixed after I complained.', stay: 'Staying since Sep 2026', fresh: true),
  Review(id: 'r4', hid: 'anjani', name: 'Arjun R.', stars: 5, text: 'Got my advance back the same day. Would stay again.', stay: 'Left Sep 2026', kind: 'exit', advance: 'all', again: 'Yes', fresh: true),
];

/// Per-hostel review aggregates from the sample data (category averages,
/// advance returned in full of those who left, layout accurate %).
class ReviewStats {
  const ReviewStats(this.cats, this.advFull, this.advLeft, this.layoutPct);
  final List<double> cats;
  final int advFull, advLeft, layoutPct;
}

const seedStats = <String, ReviewStats>{
  'anjani': ReviewStats([4.5, 3.9, 4.7, 4.1, 4.4], 35, 36, 92),
  'saisri': ReviewStats([4.6, 4.8, 4.9, 4.5, 4.7], 41, 41, 95),
  'nest42': ReviewStats([3.6, 4.5, 4.4, 4.6, 4.0], 9, 10, 88),
  'greenview': ReviewStats([4.2, 3.8, 4.3, 3.9, 4.2], 17, 19, 81),
  'orchid': ReviewStats([4.5, 4.4, 4.8, 4.2, 4.6], 24, 25, 90),
  'lakshmi': ReviewStats([4.1, 3.7, 4.2, 3.8, 4.0], 38, 44, 76),
};

/// F08 ranking factors and weights (DECISIONS 2026-10-02): verified reviews
/// 50%, reply speed 15%, beds kept up to date 15%, complaints resolved 10%,
/// listing complete 10%. Fair Play strikes lower the rank. The number itself
/// is never shown.
const rankWeights = <String, double>{'reviews': .5, 'reply': .15, 'fresh': .15, 'complaints': .1, 'listing': .1};

const rankLabel = {'reviews': 'Verified reviews', 'reply': 'Reply speed', 'fresh': 'Beds kept up to date', 'complaints': 'Complaints resolved', 'listing': 'Listing complete'};

/// Sample values (0–1) for the factors not derived from reviews or reply time.
const seedFactors = <String, Map<String, double>>{
  'anjani': {'fresh': .8, 'complaints': .7, 'listing': .8},
  'saisri': {'fresh': .6, 'complaints': .85, 'listing': .5},
  'nest42': {'fresh': .9, 'complaints': .75, 'listing': .9},
  'greenview': {'fresh': .75, 'complaints': .9, 'listing': .9},
  'orchid': {'fresh': .6, 'complaints': .7, 'listing': .7},
  'lakshmi': {'fresh': .5, 'complaints': .6, 'listing': .5},
};

/// Owner tips per factor.
const rankTips = {'fresh': 'Confirm free beds when we ask, every 3 days', 'complaints': 'Fix complaints within 3 days', 'listing': 'Add layouts for every room type'};

const rankReason = {'reviews': 'great reviews', 'reply': 'quick replies', 'fresh': 'beds kept up to date', 'complaints': 'complaints resolved fast', 'listing': 'full listing'};

/// F21 W1 (design `Agree`): the three rules a new owner agrees to.
const fairBasics = [
  'List only real beds, real prices and real photos.',
  'Add every tenant who came through Hostelzy within 3 days of moving in.',
  'Don’t ask Hostelzy tenants to skip the app or pay outside it.',
];

const fairRules = [
  ('Add every resident within 3 days', 'Name and phone. That is how a stay counts as came from the app or walked in.'),
  ('Never take a Hostelzy tenant off the app', 'Don’t ask them to cancel a hold or pay you outside the booking.'),
  ('Honour the deal and exit rules', 'The price, advance and maintenance shown at booking.'),
  ('Keep beds and prices up to date', 'Confirm free beds when we ask, every 3 days.'),
];

/// Strike ladder (DECISIONS 2026-10-02). No fines.
const strikeLadder = [('Strike 1', 'Warning', 'Nothing changes yet'), ('Strike 2', 'Deals hidden', 'For 30 days'), ('Strike 3', 'Removed', 'From Hostelzy')];

/// What strike [n] means, in a sentence (DECISIONS F07: 1 warning, 2 deals
/// hidden for 30 days, 3 removed). The server writes the same words.
String strikeWords(int n) => switch (n) { <= 1 => 'warning', 2 => 'deals hidden for 30 days', _ => 'removed from Hostelzy' };

/// "Strike 2 · deals hidden for 30 days".
String strikeDecision(int n) => 'Strike ${n.clamp(1, 3)} · ${strikeWords(n)}';

/// One dated fact from Hostelzy's own records.
class CaseEvent {
  const CaseEvent(this.date, this.title, this.sub, {this.flag = false});
  final String date, title, sub;
  final bool flag;
}

/// A Fair Play case: new → waiting (48 h for the owner) → decide → closed.
class FairCase {
  FairCase({required this.id, required this.hid, required this.title, required this.signal, required this.status, this.events = const [], this.resident, this.ownerReply, this.tenantNote, this.result, this.hoursLeft = 47.2, this.openedAt, this.key, this.tenantPhoto, this.ownerPhoto});
  final String id, hid, title, signal;

  /// S5: the case's id on the server (null on sample data).
  final String? key;
  String status;
  final List<CaseEvent> events;

  /// Resident the owner can switch to Via Hostelzy to fix the mistake.
  final String? resident;
  String? ownerReply, tenantNote, result;
  final double hoursLeft;

  /// F24 #18: the tenant's photo proof (attached by the Hostelzy team) and the
  /// owner's photo with their reply: private storage paths ('sample' in demos).
  String? tenantPhoto, ownerPhoto;

  /// F18 (F4): when the case opened (ms). The owner's 48 hours run from here;
  /// sample cases without it keep their sample time.
  final int? openedAt;
  double hoursLeftAt(int now) => openedAt == null ? hoursLeft : (48 - (now - openedAt!) / 3600000).clamp(0, 48).toDouble();
}

List<FairCase> seedCases() => [
  FairCase(
    id: 'FP-0142',
    hid: 'anjani',
    title: 'Teja Naidu was added as Direct',
    signal: 'Held, then added as Direct · tenant says yes',
    status: 'waiting',
    resident: 'Teja Naidu',
    events: const [
      CaseEvent('10 Sep', 'Enquired on Hostelzy', 'HZ-4766 · signed in with Google · phone 90000 00013'),
      CaseEvent('11 Sep', 'Held bed 102-B', 'Free 1-hour hold'),
      CaseEvent('11 Sep', 'Hold cancelled by tenant', '18 minutes later'),
      CaseEvent('18 Sep', 'Added by you as Direct', 'Bed 102-B · same phone number', flag: true),
      CaseEvent('1 Oct', 'Teja answered “Yes, I joined”', 'In the Hostelzy app', flag: true),
    ],
    tenantNote: 'I found it on Hostelzy, the owner said I could skip the hold.',
    tenantPhoto: 'sample',
  ),
  FairCase(id: 'FP-0141', hid: 'greenview', title: 'Bed 101-B taken after a cancelled hold', signal: 'Hold cancelled, same bed taken in 7 days', status: 'waiting'),
  FairCase(id: 'FP-0140', hid: 'lakshmi', title: 'Tenant report', signal: 'Tenant report: asked to pay without the app', status: 'waiting'),
  FairCase(id: 'FP-0139', hid: 'orchid', title: 'Direct resident on the deal price', signal: 'Direct resident paying the deal price', status: 'new'),
  FairCase(id: 'FP-0138', hid: 'nest42', title: 'Holds declined while beds fill', signal: 'Declining holds while occupancy rises', status: 'new'),
  FairCase(id: 'FP-0137', hid: 'saisri', title: 'Joined but never added', signal: 'Tenant said “Yes, I joined”, never added', status: 'new'),
];
