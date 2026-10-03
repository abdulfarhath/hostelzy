
// ------------------------------------------------------------ F10 owner plan

/// Flat plans by hostel size (DECISIONS 2026-10-02). No commission.
const planTiers = <({int upTo, String label, int price, String note})>[
  (upTo: 30, label: 'Up to 30 beds', price: 499, note: 'Everything below'),
  (upTo: 80, label: '31 to 80 beds', price: 999, note: 'Everything below'),
  (upTo: 1 << 30, label: '80+ beds', price: 1499, note: 'Plus a featured spot in your area'),
];

int planTierOf(int beds) => planTiers.indexWhere((t) => beds <= t.upTo);

/// F10: more than this many beds is the 80+ plan, with a featured spot in its area.
const featuredBeds = 80;

const planIncluded = 'Verified enquiries with booking codes · holds · residents app for rent and complaints · deals · Hostelzy score.';

/// Reminder after 5 days late; deals paused after 15.
const remindAfterDays = 5, pauseAfterDays = 15;

/// Anjani's 30-day trial started when the listing went live (1 Oct).
/// F18 (F12): the 30-day trial and first invoice run from the plan's start.
const trialDays = 30;

/// An owner's monthly Hostelzy invoice. [status]: upcoming | due | checking |
/// paid | missing (UTR not found in the bank record).
class Invoice {
  Invoice({required this.ref, required this.hid, required this.beds, required this.amt, required this.due, this.status = 'upcoming', this.utr, this.sent, this.late = 0, this.checked, this.key});
  final String ref, hid;

  /// S7: the invoice's id on the server (null on sample data).
  final String? key;
  final int beds;
  int amt;
  final DateTime due;
  String status;
  String? utr, sent, checked;

  /// Days past [due] while unpaid.
  int late;

  bool get pausesDeals => status != 'paid' && late >= pauseAfterDays;
}

/// Other owners' invoices on the founder's payments screen.
List<Invoice> seedInvoices() => [
  Invoice(ref: 'HZ-INV-1019', hid: 'greenview', beds: 24, amt: 499, due: DateTime(2026, 10), status: 'checking', utr: '402177100532', sent: '1 Oct, 9:02 am'),
  Invoice(ref: 'HZ-INV-1016', hid: 'lakshmi', beds: 96, amt: 1499, due: DateTime(2026, 9, 30), status: 'checking', utr: '402099214418', sent: '30 Sep, 8:40 pm'),
  Invoice(ref: 'HZ-INV-0998', hid: 'orchid', beds: 28, amt: 499, due: DateTime(2026, 9, 16), status: 'due', late: 15),
  Invoice(ref: 'HZ-INV-0990', hid: 'saisri', beds: 40, amt: 999, due: DateTime(2026, 9, 20), status: 'paid', utr: '401922107781', sent: '20 Sep', checked: '21 Sep'),
  Invoice(ref: 'HZ-INV-0987', hid: 'nest42', beds: 18, amt: 499, due: DateTime(2026, 9, 18), status: 'paid', utr: '401811902265', sent: '18 Sep', checked: '18 Sep'),
];

/// "4021 8834 1297".
String utrSpaced(String u) => [for (var i = 0; i < u.length; i += 4) u.substring(i, i + 4 > u.length ? u.length : i + 4)].join(' ');

// ------------------------------------------------------------ F17 payments

/// A payment from a tenant or resident straight to the owner's UPI ID.
/// Hostelzy never holds the money: the payer sends the UTR, the owner checks
/// their bank and confirms. [kind]: advance | rent. [status]: due | waiting |
/// paid | missing (owner says it didn't arrive).
class Payment {
  Payment({required this.id, required this.kind, required this.hid, required this.who, required this.what, required this.bed, required this.amt, required this.note, this.holdId, this.status = 'due', this.utr, this.sent, this.done, this.at = 0});
  final String id, kind, hid, who, what, bed, note;
  final int amt;

  /// When it was started (ms; 0 for samples).
  final int at;
  final String? holdId;
  String status;
  String? utr, sent, done;
}

/// Sample: one rent payment already waiting for the owner (F17 board 4).
List<Payment> seedPayments() => [
  Payment(id: 'rent204B', kind: 'rent', hid: 'anjani', who: 'Rahul V.', what: 'October rent', bed: '204-B', amt: 8020, note: 'Rent Oct · 204-B'),
  Payment(id: 'p1', kind: 'rent', hid: 'anjani', who: 'Arjun R.', what: 'October rent', bed: '204-A', amt: 7000, note: 'Rent Oct · 204-A', status: 'waiting', utr: '402199102245', sent: 'Thu 1 Oct, 9:20 am'),
];

/// F18 (F11): what a UPI ID looks like (handle@psp).
bool validUpiId(String id) => RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(id.trim());

/// `upi://pay` link with the payee, amount and note filled in.
Uri upiUri({required String id, required String name, required int amt, required String note}) => Uri(scheme: 'upi', host: 'pay', queryParameters: {'pa': id, 'pn': name, 'am': '$amt', 'tn': note, 'cu': 'INR'});
