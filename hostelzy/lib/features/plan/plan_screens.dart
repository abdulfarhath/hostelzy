import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../team/team_tracker_screens.dart' show TeamHead, StatusTag;

// F10 owner plan and UPI payment check. F22 Area 3: Your plan, the invoice
// (with its UPI QR) and the payment status are one screen; "I've paid" with
// the UTR is a sheet; then the overdue banners on owner Today and the
// founder's payments screen.

String _period(DateTime due) {
  final end = DateTime(due.year, due.month + 1, due.day - 1);
  return '${dayMon(due)} – ${dayMon(end)} ${end.year}';
}

const _monthNames = monthNames;

/// Status tag for an invoice.
({String label, Color bg, Color fg}) invoiceTag(Pal p, Invoice i) => switch (i.status) {
  'checking' => (label: 'Checking', bg: p.tx, fg: p.bg),
  'paid' => (label: 'Paid', bg: p.gb, fg: p.gn),
  'missing' => (label: 'Not received', bg: p.ab, fg: p.ad),
  'due' when i.late > 0 => (label: '${i.late} days late', bg: p.ab, fg: p.ad),
  'due' => (label: 'Due', bg: p.ab, fg: p.ad),
  _ => (label: 'Upcoming', bg: p.sf, fg: p.mu),
};

class _Head extends StatelessWidget {
  const _Head(this.kicker, this.title);
  final String kicker, title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title))]),
    );
  }
}

/// Due → Checking → Paid.
class PaySteps extends StatelessWidget {
  const PaySteps(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final cur = switch (status) {
      'checking' => 1,
      'paid' => 2,
      _ => 0,
    };
    const steps = ['Due', 'Checking', 'Paid'];
    return Container(
      decoration: box(w: 2, c: p.tx),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == cur ? p.ac : null, border: i > 0 ? Border(left: bs(1, p.hl)) : null),
                child: T(steps[i], s: 13, w: 800, c: i == cur ? p.ai : p.mu),
              ),
            ),
        ],
      ),
    );
  }
}

/// F22 Area 3: Your plan and its invoice are one screen. 'oPlan', 'oInvoice'
/// and 'oPayStatus' all show it; the state (Free trial / Due / Late /
/// Checking / Paid / Not found) comes from the invoice.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});
  @override
  Widget build(BuildContext context) => const OwnerPlanScreen();
}

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});
  @override
  Widget build(BuildContext context) => const OwnerPlanScreen();
}

class PayStatusScreen extends StatelessWidget {
  const PayStatusScreen({super.key});
  @override
  Widget build(BuildContext context) => const OwnerPlanScreen();
}

class OwnerPlanScreen extends StatefulWidget {
  const OwnerPlanScreen({super.key});
  @override
  State<OwnerPlanScreen> createState() => _OwnerPlanScreenState();
}

class _OwnerPlanScreenState extends State<OwnerPlanScreen> {
  /// Paying from another phone: the invoice's UPI QR.
  bool qr = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final inv = s.invoice;
    final month = _monthNames[inv.due.month - 1];
    final utr = utrSpaced(inv.utr ?? '');
    final upi = upiUri(id: hostelzyUpiId, name: 'Hostelzy', amt: s.invoiceAmt, note: inv.ref);
    final late = inv.status == 'due' && inv.late > 0;
    final unpaid = inv.status == 'due' || inv.status == 'missing';
    // The status card: kicker, big line, one sentence; colours by state.
    final (Color bg, Color fg, String kick, String big, String sub) = switch (inv.status) {
      'upcoming' => (p.sf, p.tx, 'Free trial', '${s.trialLeft} days left', 'Then ${fmt(s.planPrice)} a month for ${s.planBeds} beds. First invoice on ${dayMon(inv.due)}. No commission, ever.'),
      'checking' => (p.sf, p.tx, 'Checking your payment', fmt(inv.amt), 'UPI reference $utr · we match it with our bank record, usually within a day.'),
      'paid' => (p.tx, p.bg, 'Paid', fmt(inv.amt), '$month paid${inv.checked != null ? ' on ${inv.checked}' : ''}. Thank you.'),
      'missing' => (p.ab, p.ad, 'Payment not found', fmt(inv.amt), 'We couldn’t find a payment with UPI reference $utr. Check the number in your UPI app, or pay again.'),
      _ when late => (p.ab, p.ad, '${inv.late} days late', fmt(s.invoiceAmt), inv.pausesDeals ? 'Your deals are paused until it’s paid. Your listing, holds and residents keep working.' : 'Pay by ${dayMon(inv.due.add(const Duration(days: pauseAfterDays)))} to keep your deals showing.'),
      _ => (p.sf, p.tx, '$month invoice', fmt(s.invoiceAmt), 'Due ${dayMon(inv.due)} · pay to Hostelzy by UPI'),
    };
    Widget row(String k, String v, {Color? c, Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Css(s: 14, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: T(k, c: p.mu)), const SizedBox(width: 12), Expanded(child: T(v, w: 600, c: c))])),
    );
    final credits = s.ownerCredits.where((c) => c.hid == s.ownHid).toList();
    final actions = <Widget>[
      if (unpaid && inv.status == 'due') ...[
        Cta('Pay ${fmt(s.invoiceAmt)} by UPI', key: const ValueKey('planPay'), height: 54, px: 16, fs: 15, onTap: () => s.openLink(upi, 'a UPI app')),
        OutlineCta('I’ve paid · enter UPI reference', icon: 'check', onTap: s.openUtr),
      ],
      if (inv.status == 'missing') ...[
        Cta('Fix the UPI reference', height: 54, px: 16, fs: 15, onTap: s.openUtr),
        OutlineCta('WhatsApp Hostelzy', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, about invoice ${inv.ref}: UPI reference $utr.')),
      ],
      if (inv.status == 'checking') OutlineCta('WhatsApp Hostelzy', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, about invoice ${inv.ref}: UPI reference $utr.')),
      if (inv.status == 'paid') OutlineCta('Share receipt', icon: 'print', onTap: () => s.share('Hostelzy receipt · ${inv.ref} · ${hostelById(inv.hid).name} · ${fmt(inv.amt)} · UPI ref. $utr · paid, checked ${inv.checked ?? ''}')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head('${h.name} · Manage', 'Your plan'),
        Expanded(
          child: Scroll(
            key: ValueKey('oPlan${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('planCard'),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  color: bg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Kicker(kick, c: fg),
                      const SizedBox(height: 4),
                      T(big, w: 800, s: 44, lh: 1, c: fg),
                      const SizedBox(height: 4),
                      T(sub, s: 14, c: inv.status == 'missing' || late ? p.tx : fg, lh: 1.4),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row('Plan', '${s.planBeds} beds · ${fmt(s.planPrice)} a month'),
                      row('Pay to', hostelzyUpiId),
                      row('Invoice', '${inv.ref} · ${inv.status == 'upcoming' ? 'first one' : 'due'} ${dayMon(inv.due)}'),
                      if (inv.status != 'upcoming') row('Period', _period(inv.due)),
                      // F09: Member rewards given at move-in come off the invoice.
                      for (final c in credits) row('Member reward', '− ${fmt(c.amt)}', c: p.gn),
                      if (s.planCredit > 0 && unpaid) row('You pay', '${fmt(s.invoiceAmt)} after credits'),
                    ],
                  ),
                ),
                if (unpaid) ...[
                  Tap(
                    key: const ValueKey('planQr'),
                    onTap: () => setState(() => qr = !qr),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(alignment: Alignment.centerLeft, child: T(qr ? 'Hide the QR' : 'Paying from another phone? Show the QR ›', s: 14, w: 800)),
                    ),
                  ),
                  if (qr)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: box(bg: const Color(0xFFFFFFFF), w: 2, c: p.tx),
                            child: QrImageView(data: upi.toString(), size: 175, padding: EdgeInsets.zero, backgroundColor: const Color(0xFFFFFFFF), eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF201E1D)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF201E1D))),
                          ),
                          const SizedBox(height: 10),
                          Rich([sp(context, 'Scan with any UPI app. The amount and the note '), sp(context, inv.ref, w: 800, c: p.tx), sp(context, ' are filled in.')], s: 13, c: p.mu, align: TextAlign.center),
                        ],
                      ),
                    ),
                ],
                // F25 A8: this hostel's earlier invoices, newest first, then the trial.
                const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('Past invoices')),
                Container(
                  key: const ValueKey('pastInvoices'),
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final i in s.pastInvoices) _PastInvoice(i),
                      if (s.pastInvoices.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: T('No past invoices yet.', key: const ValueKey('noPastInvoices'), s: 14, c: p.mu),
                        ),
                      if (inv.status != 'upcoming') row('${dayMon(s.planStart)} – ${dayMon(s.trialEnd)}', 'Free trial'),
                    ],
                  ),
                ),
                // F25 A7: the three plans (DECISIONS F10), the owner's marked.
                const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 6), child: Kicker('All plans')),
                Container(
                  key: const ValueKey('allPlans'),
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final (n, t) in planTiers.indexed) _Tier(t, yours: n == planTierOf(s.planBeds), n: n)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Rich([sp(context, '$planIncluded '), sp(context, 'Hostelzy never touches your tenants’ money.', w: 800, c: p.tx)], s: 13, c: p.mu, lh: 1.45),
                ),
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: VGap(gap: 8, children: actions),
          ),
      ],
    );
  }
}

/// F25 A8: the words for a past invoice. Only what really happened: Paid once
/// the team matched the UTR, Checking while it's being matched, else Not paid.
({String label, Color bg, Color fg}) pastInvoiceTag(Pal p, Invoice i) => switch (i.status) {
  'paid' => (label: 'Paid', bg: p.gb, fg: p.gn),
  'checking' => (label: 'Checking', bg: p.tx, fg: p.bg),
  _ => (label: 'Not paid', bg: p.ab, fg: p.ad),
};

/// F25 A8: one earlier invoice: month, reference, amount and status.
class _PastInvoice extends StatelessWidget {
  const _PastInvoice(this.i);
  final Invoice i;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final tag = pastInvoiceTag(p, i);
    return Container(
      key: ValueKey('pastInvoice-${i.ref}'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [T(monthYear(i.due), w: 800, s: 15), T('${i.ref} · ${fmt(i.amt)}', s: 12, c: p.mu, lh: 1.35)],
            ),
          ),
          const SizedBox(width: 8),
          StatusTag(tag.label, bg: tag.bg, fg: tag.fg),
        ],
      ),
    );
  }
}

/// F25 A7: one plan tier from [planTiers]; the owner's own is marked "Yours".
class _Tier extends StatelessWidget {
  const _Tier(this.t, {required this.yours, required this.n});
  final ({int upTo, String label, int price, String note}) t;
  final bool yours;
  final int n;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      key: ValueKey('planTier-$n'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(color: yours ? p.sf : null, border: Border(bottom: bs(1, p.hl))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                T(t.label, w: 800, s: 15),
                T('${fmt(t.price)} a month', s: 13, c: p.mu, lh: 1.35),
                // Only the 80+ plan adds something; the others say "Everything below".
                if (t.upTo > featuredBeds) T(t.note, s: 12, c: p.mu, lh: 1.35),
              ],
            ),
          ),
          if (yours) ...[const SizedBox(width: 8), StatusTag('Yours', key: ValueKey('planYours-$n'), bg: p.tx, fg: p.bg)],
        ],
      ),
    );
  }
}

/// Board 3: "I've paid": type the 12-digit UTR. Shown as a sheet.
class UtrSheet extends StatelessWidget {
  const UtrSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ok = s.utrDraft.length == 12;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          const PaySteps('due'),
          VGap(
            gap: 6,
            children: [
              const T('UPI reference (UTR), 12 digits', w: 800, s: 13),
              Field(
                value: s.utrDraft,
                placeholder: '4021 8834 1297',
                numeric: true,
                onChanged: (v) => s.update(() {
                  final d = v.replaceAll(RegExp(r'\D'), '');
                  s.utrDraft = d.length > 12 ? d.substring(0, 12) : d;
                }),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: p.sf,
            child: Rich([sp(context, 'Where to find it:', w: 800), sp(context, ' in your UPI app, open this payment → details → '), sp(context, 'UTR', w: 800), sp(context, ' or '), sp(context, 'UPI Ref. No.', w: 800)], s: 13, lh: 1.45),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Ic('shield', size: 16, color: p.mu),
              const SizedBox(width: 8),
              Expanded(child: T('We match the UPI reference with our bank record, usually within a day. No screenshots needed.', s: 12, c: p.mu, lh: 1.45)),
            ],
          ),
          Cta('Send UPI reference', icon: 'check', height: 54, px: 16, fs: 15, opacity: ok ? 1 : .4, onTap: s.sendUtr),
        ],
      ),
    );
  }
}

/// Board 5: overdue banners at the top of owner Today.
class PlanBanner extends StatelessWidget {
  const PlanBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final inv = s.invoice;
    // F24 item 17: the plan is the owner's; managers don't see it.
    if (s.managerHere || inv.status == 'paid' || inv.status == 'upcoming' || inv.late < remindAfterDays) return const SizedBox();
    final amt = fmt(s.invoiceAmt);
    final checking = inv.status == 'checking';
    // F24 item 21: the server pauses the deals for tenants too (hostel_flags).
    final (icon, title, body) = inv.pausesDeals
        ? ('warn', 'Deals paused: plan ${inv.late} days late', checking ? 'We’re checking your UPI reference. Deals switch back on once it matches our bank record.' : 'Tenants see walk-in prices only. Your listing, holds and residents keep working. Pay $amt to switch deals back on.')
        : ('clock', 'Your Hostelzy plan is ${inv.late} days late', checking ? 'We’re checking your UPI reference. Usually within a day.' : '$amt for ${_monthNames[inv.due.month - 1]}. Pay by ${dayMon(inv.due.add(const Duration(days: pauseAfterDays)))} to keep your deals showing.');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: box(bg: p.ab, w: 2, c: p.ad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ic(icon, size: 20, color: p.ad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [T(title, w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(body, s: 13, lh: 1.4)],
                  ),
                ),
              ],
            ),
          ),
          if (!checking) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Cta('Pay $amt by UPI', height: 48, px: 16, fs: 14, onTap: () => s.go('oInvoice'))),
                const SizedBox(width: 8),
                Cta('I’ve paid', icon: 'check', height: 48, px: 16, fs: 14, expand: false, bg: transparent, fg: p.tx, border: p.tx, onTap: s.openUtr),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Board 6: the founder's payments. F22 Area 4 (aPay): match each UPI
/// reference in the bank app, then tap. One list by tab: To check, Late
/// (overdue or not received), Paid, and Upcoming (on trial or not due yet).
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final all = s.invoices;
    final check = all.where((i) => i.status == 'checking').toList();
    final late = all.where((i) => i.status != 'paid' && (i.late > 0 || i.status == 'missing')).toList();
    final paid = all.where((i) => i.status == 'paid').toList();
    final soon = all.where((i) => !check.contains(i) && !late.contains(i) && !paid.contains(i)).toList();
    final tab = const ['late', 'paid', 'soon'].contains(s.payTab) ? s.payTab : 'check';
    final list = switch (tab) {
      'late' => late,
      'paid' => paid,
      'soon' => soon,
      _ => check,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TeamHead(kicker: 'Hostelzy team', title: 'Owner payments'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: T('Match each UPI reference in the bank app. Never trust screenshots.', s: 14, c: p.mu, lh: 1.4),
        ),
        Seg(
          opts: [('check', 'To check ${check.length}'), ('late', 'Late ${late.length}'), ('paid', 'Paid'), ('soon', 'Upcoming')],
          cur: tab,
          onPick: (v) => s.update(() => s.payTab = v),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          center: true,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('aPay${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final i in list) _AdminInvoice(i),
                  if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing here.', s: 14, c: p.mu)),
                  if (tab == 'paid' && paid.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Paid so far: ${fmt(paid.fold(0, (a, i) => a + i.amt))} · ${paid.length} invoices', s: 13, c: p.mu)),
                  if (tab == 'soon' && soon.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: T('On the 30-day free trial or not due yet. Nothing to check.', s: 13, c: p.mu)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminInvoice extends StatelessWidget {
  const _AdminInvoice(this.i);
  final Invoice i;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final tag = invoiceTag(p, i);
    final amt = i == s.invoice && i.status != 'checking' && i.status != 'paid' ? s.invoiceAmt : i.amt;
    final sub = [
      i.ref,
      if (i.utr != null) 'UPI ref ${utrSpaced(i.utr!)}',
      if (i.sent != null) 'sent ${i.sent}' else if (i.status != 'upcoming') 'not sent',
      if (i.status == 'upcoming') 'due ${dayMon(i.due)}',
      if (i.pausesDeals) 'deals paused',
      if (i.status == 'paid' && i.checked != null) 'checked ${i.checked}',
    ].join(' · ');
    return Container(
      key: ValueKey('aPay-${i.ref}'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: VGap(
        gap: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: T('${hostelById(i.hid).name} · ${fmt(amt)}', w: 800, s: 16, lh: 1.25)),
              const SizedBox(width: 8),
              i.status == 'checking' ? const StatusTag('Check', hot: true) : StatusTag(tag.label, bg: tag.bg, fg: tag.fg),
            ],
          ),
          T(sub, s: 13, c: p.mu, lh: 1.4),
          if (i.status == 'checking')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Cta('Mark paid', icon: 'check', height: 42, px: 12, fs: 13, onTap: () => s.markPaid(i))),
                const SizedBox(width: 8),
                Expanded(child: Cta('Not received', icon: 'x', height: 42, px: 12, fs: 13, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.notReceived(i))),
              ],
            ),
          if ((i.status == 'due' && i.late > 0) || i.status == 'missing') Cta('Send reminder', icon: 'msg', height: 42, px: 12, fs: 13, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.sendReminder(i)),
        ],
      ),
    );
  }
}

/// F24 item 17 (DECISIONS F14): what a manager sees if they reach the plan,
/// deals, rates or a Fair Play check (a link, a push, an old screen).
class OwnerOnlyScreen extends StatelessWidget {
  const OwnerOnlyScreen(this.what, {super.key});
  final String what;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    void back() => s.update(() {
      s.hist = [];
      s.sheet = null;
      s.screen = 'oMore';
      s.moreTab = 'home';
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(key: const ValueKey('ownerOnlyBack'), onTap: back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Manager', title: 'Owner only'))]),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              T('Only the owner can $what.', key: const ValueKey('ownerOnly'), s: 18, w: 800, lh: 1.3),
              const SizedBox(height: 8),
              T('You manage ${h.name}: beds, residents, enquiries, complaints, food and room layouts. Ask ${h.owner.isEmpty ? 'the owner' : h.owner} about the Hostelzy plan, deals, rates or Fair Play.', s: 14, c: p.mu, lh: 1.45),
              const SizedBox(height: 16),
              OutlineCta('Back to Manage', onTap: back),
            ],
          ),
        ),
      ],
    );
  }
}
