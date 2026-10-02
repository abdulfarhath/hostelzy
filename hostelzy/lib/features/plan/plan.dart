part of '../../state.dart';

// F10 owner plan
mixin _PlanData {

  /// The signed-in owner's next invoice (Anjani), then everyone else's.
  /// When the owner's plan started (go-live day); the trial and invoices follow it.
  late DateTime planStart = appToday;

  /// UTR being typed on "I've paid".
  String utrDraft = '';

  /// Founder payments filter: check | late | paid | trial | all.
  String payTab = 'check';
}

extension PlanActions on AppState {
  DateTime get trialEnd => planStart.add(const Duration(days: trialDays));

  int get planBeds => rooms[ownHid]!.fold(0, (a, r) => a + r.beds.length);
  int get planPrice => planTiers[planTierOf(planBeds)].price;
  int get planCredit => ownerCredits.where((c) => c.hid == ownHid).fold(0, (a, c) => a + c.amt);

  /// What the owner pays on [invoice]: the plan less any Member-reward credits.
  int get invoiceAmt => (planPrice - planCredit).clamp(0, planPrice);
  int get trialLeft => invoice.status == 'upcoming' ? trialEnd.difference(appToday).inDays : 0;
  bool dealsPaused(String hid) => invoices.any((i) => i.hid == hid && i.pausesDeals);

  /// Demo states for the overview and `?plan=`: late5 | late15 | checking | paid | missing.
  void _planDemo(String? plan) {
    if (plan == null) return;
    if (plan.startsWith('late')) {
      invoice
        ..status = 'due'
        ..late = int.parse(plan.substring(4));
    } else {
      invoice
        ..status = plan
        ..utr = '402188341297'
        ..sent = '${dayName(appToday)}, 10:14 am';
      if (plan == 'paid') invoice.checked = dayMon(appToday);
    }
  }

  void openInvoice() {
    go(const ['checking', 'paid'].contains(invoice.status) ? 'oPayStatus' : 'oInvoice');
  }

  void sendUtr() {
    if (utrDraft.length != 12) return toastMsg('The UTR has 12 digits.');
    update(() {
      invoice
        ..amt = invoiceAmt
        ..utr = utrDraft
        ..sent = '${dayName(appToday)}, 10:14 am'
        ..status = 'checking';
      sheet = null;
      screen = 'oPayStatus';
    });
    toastMsg('UTR saved. Hostelzy checks it against the bank record.');
  }

  /// Founder admin: the UTR is in the bank record.
  void markPaid(Invoice i) {
    update(() {
      i
        ..status = 'paid'
        ..late = 0
        ..checked = dayMon(appToday);
    });
    toastMsg('${i.ref} marked paid.');
  }

  /// Founder admin: no payment with that UTR reached the bank.
  void notReceived(Invoice i) {
    update(() => i.status = 'missing');
    toastMsg('Marked not received. ${hostelById(i.hid).owner} sees it on their plan screen.');
  }

  void sendReminder(Invoice i) => whatsapp(ownerPhones[i.hid] ?? '', 'Hi ${hostelById(i.hid).owner}, a reminder from Hostelzy: invoice ${i.ref} (${fmt(i.amt)}) is ${i.late} days late. Pay by UPI from the app → Manage → Your plan.');
}
