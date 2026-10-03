part of '../../state.dart';

// F10 owner plan
mixin _PlanData {

  /// The signed-in owner's next invoice (Anjani), then everyone else's.
  /// When the owner's plan started (go-live day); the trial and invoices follow it.
  late DateTime planStart = appToday;

  /// UTR being typed on "I've paid".
  String utrDraft = '';

  /// Founder payments filter: check | late | paid | soon (trial or not due).
  String payTab = 'check';

  /// F24 items 20, 21: the server's featured spots and paused deals per live hostel.
  Map<String, HostelFlags> flags = {};

  /// F24 item 17: hostels this user runs as a manager (not the owner).
  Set<String> managerOf = {};
}

extension PlanActions on AppState {
  DateTime get trialEnd => planStart.add(const Duration(days: trialDays));

  int get planBeds => rooms[ownHid]!.fold(0, (a, r) => a + r.beds.length);
  int get planPrice => planTiers[planTierOf(planBeds)].price;
  int get planCredit => ownerCredits.where((c) => c.hid == ownHid).fold(0, (a, c) => a + c.amt);

  /// What the owner pays on [invoice]: the plan less any Member-reward credits.
  /// On Supabase it is the server's invoice amount.
  int get invoiceAmt => invoice.key != null ? invoice.amt : (planPrice - planCredit).clamp(0, planPrice);
  int get trialLeft => invoice.status == 'upcoming' ? trialEnd.difference(appToday).inDays : 0;
  /// Deals pause while the plan is 15+ days late (F10): the server says so
  /// for every hostel (`hostel_flags`); the owner also knows from their invoice.
  bool dealsPaused(String hid) => flags[hid]?.dealsPaused == true || invoices.any((i) => i.hid == hid && i.pausesDeals);

  /// F10: an 80+ bed hostel's plan includes a featured spot in its area. On
  /// the server it comes from `hostel_flags` (more than 80 beds, plan not 15+
  /// days late); sample hostels by their own bed count.
  bool featured(String hid) {
    final f = flags[hid];
    if (f != null) return f.featured;
    if (!isSeedHostel(hid) || !AppState.samples) return false;
    return (rooms[hid] ?? const []).fold<int>(0, (a, r) => a + r.beds.length) > featuredBeds && !dealsPaused(hid);
  }

  /// F14: plan, deals, rates and Fair Play are the owner's; a manager doesn't get them.
  bool get managerHere => managerOf.contains(ownHid);

  /// What a manager can't open, by screen (and Manage page): null if they can.
  String? ownerOnlyWhat(String screen, String moreTab) {
    if (!managerHere) return null;
    return switch (screen) {
      'oPlan' || 'oInvoice' || 'oPayStatus' => 'see the Hostelzy plan and its invoices',
      'oCase' || 'oStrike' => 'see and answer Fair Play checks',
      'oMore' when moreTab == 'deals' => 'change Hostelzy deals',
      'oMore' when moreTab == 'rates' => 'change rates, AC rooms and the UPI ID',
      _ => null,
    };
  }

  /// F24 item 17: which hostels this user only manages.
  Future<void> loadManagerOf() async {
    final uid = account?.uid;
    if (uid == null || !data.remote) return;
    try {
      final m = await data.managedHostels(uid);
      if (!setEquals(m, managerOf)) update(() => managerOf = m);
    } catch (e) {
      debugPrint('managers: $e');
    }
  }

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

  void sendUtr() {
    if (utrDraft.length != 12) return toastMsg('The UPI reference has 12 digits.');
    final key = invoice.key;
    if (onServer && key != null) {
      // S7: saved on the server; the team checks it against the bank.
      final utr = utrDraft;
      _write(() => data.sendInvoiceUtr(key, utr)).then((ok) {
        if (!ok) return;
        update(() {
          invoice.sent = '${dayName(appToday)}, ${clockTime(DateTime.now().millisecondsSinceEpoch)}';
          sheet = null;
          screen = 'oPayStatus';
        });
        toastMsg('UPI reference saved. Hostelzy checks it against the bank record.');
      });
      return;
    }
    if (onServer) return toastMsg('Your first invoice isn’t out yet. You pay once it arrives.');
    update(() {
      invoice
        ..amt = invoiceAmt
        ..utr = utrDraft
        ..sent = '${dayName(appToday)}, 10:14 am'
        ..status = 'checking';
      sheet = null;
      screen = 'oPayStatus';
    });
    toastMsg('UPI reference saved. Hostelzy checks it against the bank record.');
  }

  /// Founder admin: the UTR is in the bank record.
  void markPaid(Invoice i) {
    final key = i.key;
    if (onServer && key != null) {
      _write(() => data.checkInvoice(key, 'paid')).then((ok) {
        if (ok) toastMsg('${i.ref} marked paid.');
      });
      return;
    }
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
    final key = i.key;
    if (onServer && key != null) {
      _write(() => data.checkInvoice(key, 'missing')).then((ok) {
        if (ok) toastMsg('Marked not received. ${hostelById(i.hid).owner} sees it on their plan screen.');
      });
      return;
    }
    update(() => i.status = 'missing');
    toastMsg('Marked not received. ${hostelById(i.hid).owner} sees it on their plan screen.');
  }

  void sendReminder(Invoice i) => whatsapp(ownerWa(i.hid), 'Hi ${hostelById(i.hid).owner}, a reminder from Hostelzy: invoice ${i.ref} (${fmt(i.amt)}) is ${i.late} days late. Pay by UPI from the app → Manage → Your plan.');

  /// "I've paid": the UTR sheet, prefilled when fixing a UTR we couldn't find.
  void openUtr() => update(() {
    utrDraft = invoice.status == 'missing' ? invoice.utr ?? '' : '';
    sheet = 'utr';
  });
}
