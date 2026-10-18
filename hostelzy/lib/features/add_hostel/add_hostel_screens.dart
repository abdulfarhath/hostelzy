import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../explore/unverified_screen.dart' show UnverifiedBadge;
import '../photos/photos_screens.dart' show LoadPhotos, PhotoImg;

// F28 Part 2: S92 "Add a hostel", S93 "Your hostel on Hostelzy", and the
// Explore row "Can't find your PG? Add it".

/// Explore: the end-of-list row and the empty state's row.
class AddItRow extends StatelessWidget {
  const AddItRow({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Tap(
      key: const ValueKey('addItRow'),
      onTap: s.openAddPg,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        padding: const EdgeInsets.all(14),
        decoration: box(w: 2, c: p.tx),
        child: Row(
          children: [
            Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: const Ic('plus', size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Rich([sp(context, 'Can’t find your PG? '), sp(context, 'Add it ›', w: 800, c: p.ad)], s: 15, lh: 1.35)),
          ],
        ),
      ),
    );
  }
}

/// S92: name · gate photos · pin · For · rent · sharing · food · owner · who · Add.
class AddPgScreen extends StatelessWidget {
  const AddPgScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.addDraft;
    Widget label(String t) => T(t, w: 800, s: 13);
    String digits(String v, int n) {
      final x = v.replaceAll(RegExp(r'\D'), '');
      return x.length > n ? x.substring(0, n) : x;
    }
    final dup = s.addDup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: PageHead(kicker: 'Unverified until the owner agrees', title: 'Add a hostel', size: 26))]),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('addHostel${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VGap(
                gap: 14,
                children: [
                  VGap(gap: 6, children: [label('Hostel name'), Field(key: const ValueKey('addHName'), value: d.name, placeholder: 'As written on the gate', onChanged: (v) => s.update(() => d.name = v))]),
                  VGap(
                    gap: 6,
                    children: [
                      label('Gate photo · 1 to 3'),
                      Row(
                        children: [
                          for (final (i, ph) in d.photos.indexed) ...[
                            _Thumb(ph, onRemove: () => s.addRemovePhoto(i)),
                            const SizedBox(width: 8),
                          ],
                          if (d.photos.length < 3) ...[
                            _AddPhotoBtn('Camera', 'camera', key: const ValueKey('addCamera'), onTap: () => s.addPickPhoto(camera: true)),
                            const SizedBox(width: 8),
                            _AddPhotoBtn('Gallery', 'plus', key: const ValueKey('addGallery'), onTap: s.addPickPhoto),
                          ],
                        ],
                      ),
                    ],
                  ),
                  VGap(
                    gap: 6,
                    children: [
                      label('Where is the gate?'),
                      Tap(
                        key: const ValueKey('addPin'),
                        onTap: s.openAddPin,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: box(w: 2, c: p.tx),
                          child: Row(
                            children: [
                              Ic('pin', size: 18, color: d.pin == null ? p.mu : p.ad),
                              const SizedBox(width: 10),
                              Expanded(child: T(d.pin == null ? 'Drop the pin on the gate (GPS, drag to fix)' : 'Pin set · ${d.area}', s: 14, w: d.pin == null ? 400 : 800, c: d.pin == null ? p.mu : p.tx)),
                              const Ic('chev', size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  VGap(gap: 6, children: [label('For'), Seg(opts: same(const ['Men', 'Women', 'Co-living']), cur: d.gender, onPick: (v) => s.update(() => d.gender = v))]),
                  if (d.partner)
                    VGap(
                      gap: 6,
                      children: [
                        label('Rent a month · from and to'),
                        Row(
                          children: [
                            Expanded(child: Field(key: const ValueKey('addRent'), value: d.rent, numeric: true, placeholder: '₹ from', onChanged: (v) => s.update(() => d.rent = digits(v, 6)))),
                            const SizedBox(width: 10),
                            Expanded(child: Field(key: const ValueKey('addRentMax'), value: d.rentMax, numeric: true, placeholder: '₹ to', onChanged: (v) => s.update(() => d.rentMax = digits(v, 6)))),
                          ],
                        ),
                      ],
                    )
                  else
                    VGap(gap: 6, children: [label('What do you pay? ₹ a month'), Field(key: const ValueKey('addRent'), value: d.rent, numeric: true, placeholder: '₹', onChanged: (v) => s.update(() => d.rent = digits(v, 6)))]),
                  VGap(gap: 6, children: [label('Sharing'), Seg(opts: const [('1', '1'), ('2', '2'), ('3', '3'), ('4', '4+')], cur: '${d.share}', center: true, onPick: (v) => s.update(() => d.share = int.parse(v)))]),
                  VGap(gap: 6, children: [label('Food included'), Seg(opts: const [('yes', 'Yes'), ('no', 'No')], cur: d.food ? 'yes' : 'no', onPick: (v) => s.update(() => d.food = v == 'yes'))]),
                  VGap(gap: 6, children: [label('Owner’s name'), Field(key: const ValueKey('addOwnerName'), value: d.ownerName, placeholder: 'Who runs it', onChanged: (v) => s.update(() => d.ownerName = v))]),
                  VGap(
                    gap: 6,
                    children: [
                      label('Owner’s phone'),
                      Row(
                        children: [
                          Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('+91', w: 800, s: 15)),
                          const SizedBox(width: 6),
                          Expanded(child: Field(key: const ValueKey('addOwnerPhone'), value: d.ownerPhone, numeric: true, placeholder: '10 digits', onChanged: (v) => s.update(() => d.ownerPhone = digits(v, 10)))),
                        ],
                      ),
                      T('Only the Hostelzy team sees the number. We send nothing to the owner; you do, on WhatsApp.', s: 12, c: p.mu, lh: 1.4),
                    ],
                  ),
                  VGap(
                    gap: 6,
                    children: [
                      label('You are'),
                      Seg(key: const ValueKey('addWho'), opts: const [('live', 'I live here'), ('partner', 'I’m a Hostelzy partner')], cur: d.partner ? 'partner' : 'live', onPick: (v) => s.update(() => d.partner = v == 'partner')),
                      if (d.partner) Field(key: const ValueKey('addPartnerCode'), value: d.partnerCode, placeholder: 'Partner code, like HZ-PART-7', onChanged: (v) => s.update(() => d.partnerCode = v.toUpperCase())),
                    ],
                  ),
                  if (dup != null)
                    Container(
                      key: const ValueKey('addDup'),
                      padding: const EdgeInsets.all(12),
                      decoration: box(bg: p.ab, w: 2, c: p.ad),
                      child: VGap(
                        gap: 8,
                        children: [
                          T('Already on Hostelzy: ${dup.$2}. Ask your owner to verify it instead.', w: 800, s: 14, c: p.ad, lh: 1.4),
                          OutlineCta('Share the link with your owner', key: const ValueKey('addDupShare'), icon: 'msg', height: 46, fs: 14, onTap: s.shareDup),
                        ],
                      ),
                    ),
                  T(d.partner
                      ? 'Hostelzy pays ${fmt(partnerReward)} per listed hostel after the team checks it, by UPI. Monthly cap ${fmt(addRewardCap)} for all adders together.'
                      : 'Paid ${fmt(addReward)} only when the owner agrees and Hostelzy verifies the hostel. One hostel at a time.', s: 12, c: p.mu, lh: 1.45),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
          child: Cta(s.addBusy ? 'Adding…' : 'Add', key: const ValueKey('addGo'), icon: 'check', height: 54, px: 16, fs: 15, opacity: s.addBusy ? .5 : 1, onTap: s.addBusy ? null : s.submitAdd),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.bytes, {required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Stack(
      children: [
        Container(width: 72, height: 72, decoration: box(w: 1, c: p.hl), child: Image.memory(bytes, fit: BoxFit.cover)),
        Positioned(
          right: 0,
          top: 0,
          child: Tap(onTap: onRemove, child: Container(width: 24, height: 24, alignment: Alignment.center, color: p.tx, child: Ic('x', size: 12, color: p.bg))),
        ),
      ],
    );
  }
}

class _AddPhotoBtn extends StatelessWidget {
  const _AddPhotoBtn(this.label, this.icon, {super.key, required this.onTap});
  final String label, icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: box(w: 2, c: p.tx),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Ic(icon, size: 20), const SizedBox(height: 4), T(label, s: 11, w: 600)]),
      ),
    );
  }
}

/// S93: the card as tenants see it, the 5 steps, Send to your owner, the UPI
/// id once the owner agrees, and the honest line.
class MyAddScreen extends StatelessWidget {
  const MyAddScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.myAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: a == null ? 'Me' : a.area, title: 'Your hostel on Hostelzy', size: 26))]),
        ),
        if (a == null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: VGap(
                gap: 10,
                children: [
                  const T('You haven’t added a hostel yet.', w: 800, s: 18),
                  T('Add your PG so tenants can find it. Paid ${fmt(addReward)} when the owner agrees and Hostelzy verifies it.', s: 14, c: p.mu, lh: 1.45),
                  Cta('Add a hostel', key: const ValueKey('myAddEmptyAdd'), icon: 'plus', height: 52, px: 16, fs: 15, onTap: s.openAddPg),
                ],
              ),
            ),
          )
        else ...[
          Expanded(
            child: Scroll(
              key: ValueKey('myAdd${s.scrollEpoch}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: VGap(
                  gap: 14,
                  children: [
                    _ListedCard(a),
                    const Kicker('Where it stands'),
                    _Steps(a),
                    if (a.removed)
                      T('The Hostelzy team removed this hostel, so there is no payout.', s: 13, c: p.ad, w: 800, lh: 1.4)
                    else if (a.stillWaiting)
                      T('Still waiting. The owner hasn’t answered in 60 days. You can ask again.', key: const ValueKey('stillWaiting'), s: 13, c: p.mu, lh: 1.4)
                    else if (a.queued && a.payMonth != null)
                      T('${fmt(a.rewardDue)} is yours, queued for ${monthYear(a.payMonth!)}: this month’s rewards reached the ${fmt(addRewardCap)} cap.', key: const ValueKey('queued'), s: 13, c: p.mu, lh: 1.4),
                    if (a.step >= 3 && a.paidAt == null && !a.removed)
                      Container(
                        key: const ValueKey('upiBox'),
                        padding: const EdgeInsets.all(12),
                        decoration: box(w: 2, c: p.tx),
                        child: VGap(
                          gap: 8,
                          children: [
                            T(a.upi.isEmpty ? 'Where should Hostelzy pay the ${fmt(a.rewardDue)}?' : 'Paid by UPI to ${a.upi}', w: 800, s: 14),
                            if (a.upi.isEmpty)
                              Row(
                                children: [
                                  Expanded(child: Field(key: const ValueKey('adderUpi'), value: s.adderUpiDraft, placeholder: 'Your UPI id, like name@upi', onChanged: (v) => s.update(() => s.adderUpiDraft = v))),
                                  const SizedBox(width: 8),
                                  Cta('Save', key: const ValueKey('adderUpiSave'), height: 46, px: 14, fs: 14, expand: false, gap: 8, icon: 'check', onTap: s.saveAdderUpi),
                                ],
                              )
                            else
                              Tap(onTap: () => s.update(() => a.upi = ''), child: T('Change', s: 13, w: 700, c: p.ad, underline: true)),
                          ],
                        ),
                      ),
                    T(a.partner
                        ? 'Paid ${fmt(partnerReward)} after the Hostelzy team checks the listing. Nothing for duplicates or for a hostel the team removes.'
                        : 'Paid only when the owner agrees and Hostelzy verifies the hostel.', key: const ValueKey('honestLine'), s: 13, c: p.mu, lh: 1.45),
                  ],
                ),
              ),
            ),
          ),
          if (!a.verified && !a.removed)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
              child: a.ownerAskedAt == null
                  ? Cta('Send to your owner', key: const ValueKey('sendToOwner'), icon: 'msg', height: 54, px: 16, fs: 15, onTap: s.sendToOwner)
                  : a.canAskAgain
                  ? Cta('Ask again', key: const ValueKey('askAgain'), icon: 'msg', height: 54, px: 16, fs: 15, onTap: s.sendToOwner)
                  : VGap(
                      gap: 6,
                      children: [
                        OutlineCta('Sent on WhatsApp · ask again in ${3 - DateTime.now().difference(a.ownerAskedAt!).inDays} days', key: const ValueKey('askedWait'), icon: 'check', fs: 14, onTap: s.sendToOwner),
                        T('Sent ${dayMon(a.ownerAskedAt!)}. The owner opens the link and taps Claim this hostel.', s: 12, c: p.mu, lh: 1.4),
                      ],
                    ),
            ),
        ],
      ],
    );
  }
}

/// The adder's hostel as tenants see it: photo, name + UNVERIFIED, where, rent.
class _ListedCard extends StatelessWidget {
  const _ListedCard(this.a);
  final MyAdd a;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = a.asHostel;
    final photos = s.photosOf[a.id] ?? const [];
    return Container(
      key: const ValueKey('myAddCard'),
      decoration: box(w: 2, c: p.tx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: Hatch(p.sf, 8, 16, base: p.bg),
              child: Stack(
                children: [
                  Positioned.fill(child: LoadPhotos(a.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url))),
                  Positioned(left: 8, bottom: 8, child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: T(photos.isEmpty ? '${a.photos} photo${a.photos == 1 ? '' : 's'} · added by you' : '1 / ${photos.length} · added by you', s: 12, c: p.mu))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: VGap(
              gap: 4,
              children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [T(a.name, w: 800, s: 18, lh: 1.2), if (a.verified) Container(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8), decoration: box(bg: p.vf, w: 2, c: p.vf), child: T('✓ Verified', s: 11, w: 800, ls: .08, upper: true, c: p.ai)) else const UnverifiedBadge(small: true)]),
                T('${a.gender} · ${a.area}', s: 14, c: p.mu),
                Rich([sp(context, '${rentRange(h)}/mo', w: 800, c: p.tx), sp(context, a.verified ? '' : ' · expected, not confirmed')], s: 14, c: p.mu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Added ✓ → Owner asked → Owner agreed → Verified → ₹200 paid.
class _Steps extends StatelessWidget {
  const _Steps(this.a);
  final MyAdd a;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final amt = fmt(a.rewardDue);
    final steps = <(String, String)>[
      ('Added', 'On Hostelzy as unverified since ${dayMon(a.createdAt)}'),
      ('Owner asked', a.ownerAskedAt == null ? 'Send the link to ${a.ownerName.isEmpty ? 'your owner' : a.ownerName.split(' ').first} on WhatsApp' : 'Sent ${dayMon(a.ownerAskedAt!)}'),
      ('Owner agreed', a.ownerAgreedAt == null ? 'The owner taps Claim this hostel' : 'Claimed ${dayMon(a.ownerAgreedAt!)}'),
      ('Verified', a.liveAt == null ? 'The Hostelzy team visits and checks it' : 'Verified ${dayMon(a.liveAt!)}'),
      ('$amt paid', a.paidAt != null ? 'Paid ${dayMon(a.paidAt!)} by UPI' : a.queued && a.payMonth != null ? 'Queued for ${monthYear(a.payMonth!)} (monthly cap)' : a.verified ? 'By UPI on the 5th${a.upi.isEmpty ? ' · add your UPI id below' : ''}' : 'By UPI, after verification'),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            Container(
              key: ValueKey('addStep-${i + 1}'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: box(bg: i < a.step ? p.tx : transparent, w: 2, c: i < a.step ? p.tx : (i == a.step ? p.ac : p.dv)),
                    child: i < a.step ? Ic('check', size: 14, color: p.bg) : T('${i + 1}', w: 800, s: 13, c: i == a.step ? p.ad : p.mu),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(steps[i].$1, w: 800, s: 15, c: i <= a.step ? p.tx : p.mu), T(steps[i].$2, s: 13, c: p.mu, lh: 1.35)])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
