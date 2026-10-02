import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_config.dart';
import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F10 owner plan and UPI payment check: Manage → Your plan (board 1), the
// invoice with a UPI QR (2), "I've paid" with the UTR (3, a sheet), payment
// status (4), the overdue banners on owner Today (5) and the founder's
// payments screen (6).

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
  const _Head(this.kicker, this.title, {this.size = 30});
  final String kicker, title;
  final double size;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title, size: size))]),
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

/// Board 1: Manage → Your plan.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final inv = s.invoice;
    final tier = planTierOf(s.planBeds);
    final tag = invoiceTag(p, inv);
    final credits = s.ownerCredits.where((c) => c.hid == s.ownHid).toList();
    final (kick, big, sub) = switch (inv.status) {
      'upcoming' => ('Free trial', '${s.trialLeft} days left', 'Ends ${dayName(s.trialEnd)}. First invoice ${fmt(s.invoiceAmt)} on ${dayName(inv.due)}.'),
      'checking' => (planTiers[tier].label, 'Checking your payment', 'UPI reference ${utrSpaced(inv.utr ?? '')} · usually within a day.'),
      'paid' => (planTiers[tier].label, 'Paid for ${_monthNames[inv.due.month - 1]}', 'Next invoice on ${dayMon(DateTime(inv.due.year, inv.due.month + 1, inv.due.day))}.'),
      'missing' => (planTiers[tier].label, 'Payment not found', 'Check the UPI reference in your UPI app, or pay again with the QR.'),
      _ => (planTiers[tier].label, inv.late > 0 ? '${inv.late} days late' : '${fmt(s.invoiceAmt)} due', inv.pausesDeals ? 'Deals paused until you pay.' : 'Pay by ${dayName(inv.due.add(const Duration(days: pauseAfterDays)))} to keep your deals showing.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head('${h.name} · ${s.planBeds} beds', 'Your plan'),
        Expanded(
          child: Scroll(
            key: ValueKey('oPlan${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  color: p.tx,
                  child: Css(
                    c: p.bg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Opacity(opacity: .75, child: Kicker(kick, c: p.bg)),
                        const SizedBox(height: 4),
                        T(big, w: 800, s: 26),
                        const SizedBox(height: 4),
                        Opacity(opacity: .85, child: T(sub, s: 13, lh: 1.4)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Kicker('Plans by hostel size'), T('No commission', s: 12, w: 800)]),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < planTiers.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: i == tier ? p.sf : null,
                            border: Border(left: i == tier ? bs(4, p.ac) : BorderSide.none, bottom: bs(1, p.hl)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [T(planTiers[i].label, w: 800, s: 16), if (i == tier) ...[const SizedBox(width: 8), Tag('Your plan', bg: p.tx, fg: p.bg)]]),
                                    const SizedBox(height: 2),
                                    T(i == tier ? 'You have ${s.planBeds} beds' : planTiers[i].note, s: 12, c: p.mu),
                                  ],
                                ),
                              ),
                              Rich([sp(context, fmt(planTiers[i].price), w: 800, s: 20), sp(context, '/mo', s: 12, c: p.mu)]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Rich([sp(context, '$planIncluded '), sp(context, 'Hostelzy never touches your tenants’ money.', w: 800, c: p.tx)], s: 12, c: p.mu, lh: 1.45),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker('Invoices')),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tap(
                        onTap: s.openInvoice,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    T('${_monthNames[inv.due.month - 1].substring(0, 3)} ${inv.due.year} · ${fmt(inv.status == 'checking' || inv.status == 'paid' ? inv.amt : s.invoiceAmt)}', w: 800, s: 15),
                                    const SizedBox(height: 2),
                                    T('${inv.ref} · due ${dayMon(inv.due)}', s: 12, c: p.mu),
                                  ],
                                ),
                              ),
                              Tag(tag.label, bg: tag.bg, fg: tag.fg),
                              const SizedBox(width: 6),
                              const Ic('chev', size: 18),
                            ],
                          ),
                        ),
                      ),
                      for (final c in credits)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    T('Credit · ${fmt(c.amt)}', w: 800, s: 15),
                                    const SizedBox(height: 2),
                                    T('Member reward you gave a tenant at move-in · comes off your next invoice', s: 12, c: p.mu, lh: 1.35),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              T('− ${fmt(c.amt)}', w: 800, s: 16, c: p.gn),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: T('You pay by UPI QR, then type the UPI reference. We check it against our bank record.', s: 12, c: p.mu, lh: 1.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Board 2: the invoice with a UPI QR (amount and invoice code filled in).
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final inv = s.invoice;
    final tier = planTiers[planTierOf(s.planBeds)];
    final amt = fmt(s.invoiceAmt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head('Invoice ${inv.ref}', '$amt due ${dayMon(inv.due)}', size: 28),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('oInvoice${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: box(bg: const Color(0xFFFFFFFF), w: 2, c: p.tx),
                          child: QrImageView(data: upiUri(id: hostelzyUpiId, name: 'Hostelzy', amt: s.invoiceAmt, note: inv.ref).toString(), size: 175, padding: EdgeInsets.zero, backgroundColor: const Color(0xFFFFFFFF), eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF201E1D)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF201E1D))),
                        ),
                        const SizedBox(height: 12),
                        Rich([sp(context, 'Scan with any UPI app. Amount and the note '), sp(context, inv.ref, w: 800, c: p.tx), sp(context, ' are filled in.')], s: 13, c: p.mu, align: TextAlign.center),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The UPI ID is a placeholder until the founder sets it.
                        const KV('Pay to', 'Hostelzy · $hostelzyUpiId', keyWidth: 80),
                        KV('Plan', '${tier.label} · ${fmt(tier.price)}/mo', keyWidth: 80),
                        if (s.planCredit > 0) KV('Credit', '− ${fmt(s.planCredit)} · Member reward', keyWidth: 80),
                        KV('Period', _period(inv.due), keyWidth: 80),
                        KV('Hostel', hostelById(inv.hid).name, keyWidth: 80),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: VGap(
            gap: 8,
            children: [
              Cta('Open UPI app', height: 54, px: 16, fs: 15, onTap: () => s.openLink(upiUri(id: hostelzyUpiId, name: 'Hostelzy', amt: s.invoiceAmt, note: inv.ref), 'a UPI app')),
              OutlineCta('I’ve paid', icon: 'check', onTap: s.openUtr),
            ],
          ),
        ),
      ],
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

/// Board 4: Checking / Paid / Not received.
class PayStatusScreen extends StatelessWidget {
  const PayStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final inv = s.invoice;
    final utr = utrSpaced(inv.utr ?? '');
    final next = DateTime(inv.due.year, inv.due.month + 1, inv.due.day);
    final title = switch (inv.status) {
      'paid' => 'Paid. Thank you',
      'missing' => 'We couldn’t find this payment',
      'checking' => 'Checking your payment',
      _ => '${fmt(s.invoiceAmt)} due ${dayMon(inv.due)}',
    };
    final msg = switch (inv.status) {
      'paid' => [sp(context, 'Received on ${inv.checked ?? dayMon(appToday)}. Next invoice on ${dayMon(next)}.')],
      'missing' => [sp(context, 'No payment with UPI reference '), sp(context, utr, w: 800, c: p.tx), sp(context, ' reached us. Check the number in your UPI app, or pay again with the QR.')],
      _ => [sp(context, 'We’re matching UPI reference '), sp(context, utr, w: 800, c: p.tx), sp(context, ' with our bank record. Usually within a day. Your listing stays live meanwhile.')],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head('Invoice ${inv.ref} · ${fmt(inv.amt)}', title, size: 28),
        Expanded(
          child: Scroll(
            key: ValueKey('oPayStatus${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: PaySteps(inv.status)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: Rich(msg, s: 14, c: p.mu, lh: 1.5)),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KV('UPI ref.', utr, keyWidth: 70),
                      KV('Sent', inv.sent ?? '—', keyWidth: 70),
                      KV('Plan', planTiers[planTierOf(inv.beds)].label, keyWidth: 70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (inv.status == 'paid')
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), child: OutlineCta('Share receipt', icon: 'print', onTap: () => s.share('Hostelzy receipt · ${inv.ref} · ${hostelById(inv.hid).name} · ${fmt(inv.amt)} · UPI ref. ${utrSpaced(inv.utr ?? '')} · paid, checked ${inv.checked ?? ''}'))),
        if (inv.status == 'missing')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: VGap(
              gap: 8,
              children: [
                Cta('Fix the UPI reference', icon: 'arrow', height: 54, px: 16, fs: 15, onTap: s.openUtr),
                OutlineCta('WhatsApp Hostelzy', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, about invoice ${inv.ref}: UPI reference ${utrSpaced(inv.utr ?? '')}.')),
              ],
            ),
          ),
      ],
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
    if (inv.status == 'paid' || inv.status == 'upcoming' || inv.late < remindAfterDays) return const SizedBox();
    final amt = fmt(s.invoiceAmt);
    final checking = inv.status == 'checking';
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

/// Board 6: the founder's payments. The design is a 1440 px desk screen; in
/// the app it is one column (tiles, filter, then one card per invoice).
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final all = s.invoices;
    final check = all.where((i) => i.status == 'checking').toList();
    final late = all.where((i) => i.status != 'paid' && i.late > 0).toList();
    final paid = all.where((i) => i.status == 'paid').toList();
    final trial = all.where((i) => i.status == 'upcoming').toList();
    final list = switch (s.payTab) {
      'check' => check,
      'late' => late,
      'paid' => paid,
      'trial' => trial,
      _ => all,
    };
    Widget tile(String k, String v, String sub) => Expanded(
      child: Container(
        color: p.bg,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Kicker(k), const SizedBox(height: 2), T(v, w: 800, s: 24), T(sub, s: 12, c: p.mu)],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Rich([sp(context, 'Hostelzy '), sp(context, 'team', c: p.ac)], w: 800, s: 20)]),
              const SizedBox(height: 2),
              T('Owner payments · Match every UTR in the bank or merchant app. Never trust screenshots.', s: 12, c: p.mu),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('aPay${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: p.hl,
                  child: Column(
                    children: [
                      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile('To check', '${check.length}', 'UTRs waiting'), const SizedBox(width: 1), tile('Paying', '${paid.length}', 'hostels')])),
                      const SizedBox(height: 1),
                      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile('On trial', '${trial.length}', 'free for 30 days'), const SizedBox(width: 1), tile('Overdue', '${late.length}', '${late.where((i) => i.pausesDeals).length} with deals paused')])),
                      const SizedBox(height: 1),
                      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile('Paid so far', fmt(paid.fold(0, (a, i) => a + i.amt)), '${paid.length} invoices paid')])),
                    ],
                  ),
                ),
                Seg(
                  opts: [('check', 'Check ${check.length}'), ('late', 'Late ${late.length}'), ('paid', 'Paid'), ('trial', 'Trial'), ('all', 'All')],
                  cur: s.payTab,
                  onPick: (v) => s.update(() => s.payTab = v),
                  pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  center: true,
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                ),
                Container(
                  decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final i in list) _AdminInvoice(i),
                      if (list.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing here.', s: 14, c: p.mu)),
                    ],
                  ),
                ),
              ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: VGap(
        gap: 6,
        children: [
          Row(children: [Expanded(child: T('${hostelById(i.hid).name} · ${i.beds} beds', w: 800, s: 14)), Tag(tag.label, bg: tag.bg, fg: tag.fg)]),
          T('${i.ref} · ${fmt(amt)} · UTR ${i.utr != null ? utrSpaced(i.utr!) : '—'} · ${i.sent != null ? 'sent ${i.sent}' : 'not sent'}', s: 13, c: p.mu, lh: 1.4),
          if (i.status == 'checking')
            Row(
              children: [
                Expanded(child: Cta('Mark paid', icon: 'check', height: 44, px: 12, fs: 14, onTap: () => s.markPaid(i))),
                const SizedBox(width: 8),
                Expanded(child: Cta('Not received', icon: 'x', height: 44, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.notReceived(i))),
              ],
            ),
          if (i.status == 'due' || i.status == 'missing')
            if (i.late > 0 || i.status == 'missing') Cta('Send reminder', icon: 'msg', height: 44, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.sendReminder(i)),
          if (i.status == 'paid') T('Checked ${i.checked ?? ''}', s: 12, w: 800, c: p.gn),
        ],
      ),
    );
  }
}
