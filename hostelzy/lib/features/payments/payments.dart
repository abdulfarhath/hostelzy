part of '../../state.dart';

// F17 payments
mixin _PaymentsData {

  /// Where tenants pay each owner. Sample IDs are clearly fake until the
  /// owner types theirs in Manage → Rates.
  late final Map<String, ({String id, String name})> ownerUpi = {for (final h in hostels) h.id: (id: h.id == 'anjani' ? 'sample.owner@upi' : 'sample.${h.id}@upi', name: h.owner)};

  List<Payment> payments = seedPayments();

  /// The payment a pay / UTR sheet is about, and the UTR being typed.
  String? payId;
  String payUtr = '';
}

extension PaymentsActions on AppState {
  Payment? get pay => payments.where((x) => x.id == payId).firstOrNull;
  Payment? payOfHold(String holdId) => payments.where((x) => x.holdId == holdId).lastOrNull;

  /// This resident's rent for the month (Rahul, bed 204-B).
  Payment get myRent => payments.firstWhere((x) => x.id == 'rent204B');

  /// Opens the UPI app with the owner's ID, amount and note filled in.
  void payByUpi(Payment p) {
    final u = ownerUpi[p.hid]!;
    // F18: never pay a sample UPI ID in the Play Store build.
    if (!AppState.samples && u.id.startsWith('sample.')) return toastMsg('This is a sample listing, so it has no real UPI ID. Don’t pay it.');
    if (u.id.isNotEmpty && !validUpiId(u.id)) return toastMsg('${hostelById(p.hid).owner.isEmpty ? 'The owner' : hostelById(p.hid).owner}’s UPI ID isn’t valid. Ask them on WhatsApp.');
    if (u.id.isEmpty) return toastMsg('${hostelById(p.hid).owner.isEmpty ? 'The owner' : hostelById(p.hid).owner} hasn’t added a UPI ID yet. Ask them on WhatsApp.');
    openLink(upiUri(id: u.id, name: u.name, amt: p.amt, note: p.note), 'a UPI app');
    update(() {
      payId = p.id;
      payUtr = p.utr ?? '';
      sheet = 'payUtr';
    });
  }

  Future<void> sendPayUtr() async {
    final p = pay;
    if (p == null) return;
    if (payUtr.length != 12) return toastMsg('The UTR has 12 digits.');
    final h = hostelById(p.hid);
    // C: on Supabase the owner sees it only once the server has it.
    if (onServer && !await sendUtrLive(p, payUtr)) return;
    update(() {
      p
        ..utr = payUtr
        ..sent = '${dayName(appToday)}, ${clockTime(DateTime.now().millisecondsSinceEpoch)}'
        ..status = 'waiting';
      if (p.kind == 'rent') {
        for (final r in residents.where((r) => r.bed == p.bed)) {
          r.status = 'Waiting';
          r.note = 'UTR sent · ${h.owner} to confirm';
        }
      }
      sheet = null;
    });
    toastMsg('Saved. ${h.owner} confirms once they see the money.');
  }

  /// Owner: checked the bank. Only now is the bed Booked or the rent Paid.
  Future<void> confirmPayment(Payment p, bool received) async {
    final first = p.who.split(' ').first;
    if (onServer && !await confirmPaymentLive(p, received)) return;
    update(() {
      p.status = received ? 'paid' : 'missing';
      if (received) p.done = dayMon(appToday);
      if (p.kind == 'advance' && p.holdId != null) {
        final h = holds.where((x) => x.id == p.holdId).firstOrNull;
        if (h != null && received) {
          holds = holds.map((x) => x.id == h.id ? x.withStatus('booked') : x).toList();
          findBed(h.hid, h.bed).b?.state = 'booked';
        }
      }
      if (p.kind == 'rent') {
        for (final r in residents.where((r) => r.bed == p.bed)) {
          r.status = received ? 'Paid' : 'Due';
          r.note = received ? 'Confirmed ${dayMon(appToday)}' : 'UTR not found';
        }
      }
    });
    toastMsg(received ? 'Confirmed. It shows as ${p.kind == 'rent' ? 'paid' : 'booked'}.' : 'Marked not received. Tell $first on WhatsApp to check the UTR.');
  }

  /// Tenant gives up on a booking whose payment didn't arrive.
  void cancelBooking(Hold h) {
    releaseHold(h);
    update(() => hid = h.hid);
    openPicker();
  }
}
