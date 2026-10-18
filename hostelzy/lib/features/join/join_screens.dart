import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../drive/id_capture.dart';
import '../drive/id_thumb.dart';

// F29 Part 2: H48 "Ask to join" (owner), S94 "Join <hostel>" (tenant),
// H49 "<name> wants to join" (owner).

String _digits(String v, int n) {
  final d = v.replaceAll(RegExp(r'\D'), '');
  return d.length > n ? d.substring(0, n) : d;
}

/// H48: a free bed, the fee (from the room's rate), the advance (from the
/// terms), the move-in date, an optional first name, Send on WhatsApp.
class AskJoinSheet extends StatelessWidget {
  const AskJoinSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.joinDraft;
    final free = <String>[
      for (final r in s.rooms[s.ownHid] ?? const <Room>[])
        for (final b in r.beds)
          if ((b.state == 'free' || b.state == 'soon') && !b.mine) b.id,
    ];
    final shown = [...free.take(12), if (d.bed != null && !free.take(12).contains(d.bed)) d.bed!];
    Widget label(String t) => T(t, w: 800, s: 13);
    final fee = int.tryParse(d.fee) ?? 0, adv = int.tryParse(d.adv) ?? 0;
    const days = [(0, 'Today'), (1, 'Tomorrow'), (3, 'In 3 days'), (7, 'In a week'), (14, 'In 2 weeks')];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          VGap(
            gap: 6,
            children: [
              label('Free bed'),
              if (shown.isEmpty) T('No free beds right now.', s: 13, c: p.mu) else wrap(6, [for (final id in shown) ChipBtn(id, key: ValueKey('joinBed-$id'), on: id == d.bed, onTap: () => s.pickJoinBed(id), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: VGap(gap: 6, children: [label('Monthly fee'), Field(key: const ValueKey('joinFee'), value: d.fee.isEmpty ? '' : fmt(fee), numeric: true, placeholder: '₹', onChanged: (v) => s.update(() => d.fee = _digits(v, 6)))])),
              const SizedBox(width: 10),
              Expanded(child: VGap(gap: 6, children: [label('Advance'), Field(key: const ValueKey('joinAdv'), value: d.adv.isEmpty ? '' : fmt(adv), numeric: true, placeholder: '₹', onChanged: (v) => s.update(() => d.adv = _digits(v, 6)))])),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              Row(children: [label('Moves in'), const Spacer(), T(dayMon(appToday.add(Duration(days: d.days))), s: 13, c: p.mu)]),
              wrap(6, [for (final (n, l) in days) ChipBtn(l, key: ValueKey('joinDay-$n'), on: d.days == n, onTap: () => s.update(() => d.days = n), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          VGap(gap: 6, children: [label('Their first name (optional)'), Field(key: const ValueKey('joinName'), value: d.name, placeholder: 'For the message', onChanged: (v) => s.update(() => d.name = v))]),
          Cta(s.joinBusy ? 'Making the link…' : 'Send on WhatsApp', key: const ValueKey('askJoinSend'), icon: 'msg', height: 54, px: 16, fs: 15, opacity: s.joinBusy ? .5 : 1, onTap: s.joinBusy ? null : s.sendAskJoin),
        ],
      ),
    );
  }
}

/// S94: "Join `hostel` · bed 203 · ₹6,500/month": name, phone, date, ID,
/// Send to owner. Done state on the same screen.
class JoinFormScreen extends StatelessWidget {
  const JoinFormScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final i = s.joinInfo;
    if (i == null) return const SizedBox();
    Widget label(String t) => T(t, w: 800, s: 13);
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: 'Bed ${i.bed} · ${fmt(i.fee)}/month', title: 'Join ${i.hostel}', size: 26))]),
    );
    if (s.jSent) {
      return Column(
        key: const ValueKey('joinDone'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Dashed(
              color: p.dv,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: VGap(
                gap: 8,
                stretch: false,
                children: [
                  const Ic('check', size: 28),
                  const T('Sent', w: 800, s: 22),
                  T('${i.owner} will approve · we’ll notify you', s: 14, c: p.mu, lh: 1.45),
                  if (s.jId != 'whatsapp') OutlineCta('Send ID on WhatsApp', key: const ValueKey('sendIdWaDone'), icon: 'msg', height: 46, fs: 14, onTap: s.sendIdOnWhatsApp),
                ],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: OutlineCta('Back to Explore', icon: 'home', onTap: () => s.tab('explore'))),
        ],
      );
    }
    if (!i.open) {
      return Column(
        key: const ValueKey('joinClosed'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: box(bg: p.ab, w: 2, c: p.ad),
              child: T(i.taken ? 'This bed was just taken, ask your owner.' : i.status == 'approved' ? 'You’re already in. Pick “I live in a Hostelzy PG” to see your stay.' : 'This link isn’t valid any more. Ask ${i.owner} for a new one.', w: 800, s: 15, c: p.ad, lh: 1.4),
            ),
          ),
        ],
      );
    }
    final dates = <(DateTime, String)>[(i.movesIn, dayMon(i.movesIn)), if (!_sameDay(i.movesIn, appToday)) (appToday, 'Today'), if (!_sameDay(i.movesIn, appToday.add(const Duration(days: 1)))) (appToday.add(const Duration(days: 1)), 'Tomorrow'), (i.movesIn.add(const Duration(days: 7)), dayMon(i.movesIn.add(const Duration(days: 7))))];
    final date = s.jDate ?? i.movesIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(
          child: Scroll(
            key: ValueKey('joinForm${s.scrollEpoch}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VGap(
                gap: 14,
                children: [
                  KV('Advance', fmt(i.advance), keyWidth: 110),
                  VGap(gap: 6, children: [label('Your name'), Field(key: const ValueKey('jName'), value: s.jName, placeholder: i.nameHint.isEmpty ? 'Full name' : i.nameHint, onChanged: (v) => s.update(() => s.jName = v))]),
                  VGap(
                    gap: 6,
                    children: [
                      label('Your phone'),
                      Row(
                        children: [
                          Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('+91', w: 800, s: 15)),
                          const SizedBox(width: 6),
                          Expanded(child: Field(key: const ValueKey('jPhone'), value: s.jPhone, numeric: true, placeholder: '10 digits', onChanged: (v) => s.update(() => s.jPhone = _digits(v, 10)))),
                        ],
                      ),
                    ],
                  ),
                  VGap(
                    gap: 6,
                    children: [
                      Row(children: [label('Moving in'), const Spacer(), T(dayMon(date), s: 13, c: p.mu)]),
                      wrap(6, [for (final (dt, l) in dates) ChipBtn(l, key: ValueKey('jDate-${dt.day}-${dt.month}'), on: _sameDay(dt, date), onTap: () => s.update(() => s.jDate = dt), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
                    ],
                  ),
                  VGap(
                    gap: 8,
                    children: [
                      label('Your ID · Aadhaar or any government ID'),
                      // W4 (F29 Part 3): the owner takes IDs in Drive → IdCapture masks the first 8 digits on
                      // the phone and uploads there; Send ID on WhatsApp stays as the other way.
                      if (s.jId == 'whatsapp')
                        Container(
                          key: const ValueKey('idSentTick'),
                          padding: const EdgeInsets.all(12),
                          decoration: box(w: 2, c: p.tx),
                          child: Row(children: [Container(width: 24, height: 24, alignment: Alignment.center, color: p.tx, child: Ic('check', size: 16, color: p.bg)), const SizedBox(width: 10), Expanded(child: T('Sent on WhatsApp to ${i.owner}', w: 800, s: 14)), Tap(onTap: s.sendIdOnWhatsApp, child: T('Again', s: 13, w: 700, c: p.ad, underline: true))]),
                        )
                      else ...[
                        if (i.drive)
                          IdCapture(
                            key: const ValueKey('idCapture'),
                            token: i.token,
                            fullCopy: null,
                            ownerName: i.owner,
                            onUploaded: (id) => s.update(() {
                              s.jId = 'drive';
                              s.jIdFileId = id;
                            }),
                          ),
                        if (s.jId != 'drive') OutlineCta('Send ID on WhatsApp', key: const ValueKey('sendIdWa'), icon: 'msg', onTap: s.sendIdOnWhatsApp),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
          child: Cta(s.joinBusy ? 'Sending…' : 'Send to owner', key: const ValueKey('joinSend'), icon: 'check', height: 54, px: 16, fs: 15, opacity: s.joinBusy ? .5 : 1, onTap: s.joinBusy ? null : s.sendJoinForm),
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// H49: the tenant's details, the ID row, Approve / Ask again / Decline.
class JoinReviewSheet extends StatelessWidget {
  const JoinReviewSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final r = s.reviewReq;
    if (r == null) return const SizedBox();
    final r0 = s.findBed(s.ownHid, r.bed).r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KV('Name', r.name, keyWidth: 110),
        KV('Phone', '+91 ${phoneSpaced(r.phone)}', keyWidth: 110),
        KV('Moves in', dayMon(r.date), keyWidth: 110),
        KV('Bed', '${r.bed}${r0 == null ? '' : ' · ${r0.share} sharing'}', keyWidth: 110),
        KV('Fee', '${fmt(r.fee)} a month · advance ${fmt(r.advance)}', keyWidth: 110),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: switch (r.idReceived) {
            // W4 (F29 Part 3): the masked image from the owner's Drive (tap opens it in Drive), "Delete from my Drive".
            'drive' => Column(
                key: const ValueKey('idDrive'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.idFileId != null)
                    IdThumb(hid: s.ownHid, fileId: r.idFileId!)
                  else
                    Container(padding: const EdgeInsets.all(12), decoration: box(w: 2, c: p.tx), child: const Row(children: [Ic('doc', size: 18), SizedBox(width: 10), Expanded(child: T('ID in your Google Drive', w: 800, s: 14))])),
                  if (r.idFileId != null) Tap(key: const ValueKey('idDeleteDrive'), onTap: () => s.deleteJoinId(r), child: const Padding(padding: EdgeInsets.only(top: 10), child: T('Delete from my Drive', s: 13, w: 800, underline: true))),
                ],
              ),
            'whatsapp' => Tap(
                key: const ValueKey('idTick'),
                onTap: () => s.update(() => s.idTick = !s.idTick),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(
                    children: [
                      Container(width: 24, height: 24, alignment: Alignment.center, decoration: box(bg: s.idTick ? p.tx : transparent, w: 2, c: p.tx), child: s.idTick ? Ic('check', size: 16, color: p.bg) : null),
                      const SizedBox(width: 10),
                      const Expanded(child: T('ID received on WhatsApp', w: 800, s: 14)),
                    ],
                  ),
                ),
              ),
            _ => Container(key: const ValueKey('idNone'), padding: const EdgeInsets.all(12), color: p.sf, child: const T('No ID yet', w: 800, s: 14)),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: VGap(
            gap: 8,
            children: [
              Cta('Approve', key: const ValueKey('joinApprove'), icon: 'check', height: 54, px: 16, fs: 15, onTap: s.approveJoin),
              Row(
                children: [
                  Expanded(child: OutlineCta('Ask again', key: const ValueKey('joinAskAgain'), icon: 'msg', height: 48, fs: 14, onTap: s.askIdAgain)),
                  const SizedBox(width: 8),
                  Expanded(child: OutlineCta('Decline', key: const ValueKey('joinDecline'), icon: 'x', height: 48, fs: 14, onTap: s.declineJoin)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
