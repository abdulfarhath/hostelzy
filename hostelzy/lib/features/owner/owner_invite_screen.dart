import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_config.dart' show inviteLink, shortLink;
import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

/// F06 board 6: invite residents by QR, then approve who signs up.
class OwnerInviteScreen extends StatelessWidget {
  const OwnerInviteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // C: the code comes from the server (sample data: the sample code).
    final code = s.inviteCode;
    final link = code == null ? '' : inviteLink(code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: '${hostelById(s.ownHid).name} · Residents', title: 'Invite residents', size: 28)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Scroll(
              key: ValueKey('oInvite${s.scrollEpoch}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // F22 Area 3 (board `invite`): the QR next to the code, two actions.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: code == null
                        ? OnShow(s.loadInvite, child: SizedBox(height: 150, child: Center(child: T('Getting your invite code…', s: 14, c: p.mu))))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: const ValueKey('inviteQrCode'),
                                padding: const EdgeInsets.all(8),
                                decoration: box(bg: const Color(0xFFFFFFFF), w: 2, c: p.tx),
                                child: QrImageView(data: link, size: 120, padding: EdgeInsets.zero, backgroundColor: const Color(0xFFFFFFFF), eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF201E1D)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF201E1D))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: T(code, w: 800, s: 32, ls: .04)),
                                    const SizedBox(height: 4),
                                    T('Residents scan or type this code, sign in, and you approve them.', s: 14, c: p.mu, lh: 1.4),
                                    const SizedBox(height: 4),
                                    T(shortLink(link), s: 12, w: 800),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Cta('Share link', icon: 'msg', height: 50, px: 14, fs: 14, bg: p.tx, fg: p.bg, opacity: code == null ? .4 : 1, onTap: code == null ? null : () => s.share('Join ${hostelById(s.ownHid).name} on Hostelzy to pay rent, raise complaints and see the food menu: $link'))),
                        const SizedBox(width: 8),
                        Expanded(child: Cta('Print poster', icon: 'print', height: 50, px: 14, fs: 14, bg: transparent, fg: p.tx, border: p.tx, opacity: code == null ? .4 : 1, onTap: code == null ? null : () => s.sharePoster(link))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [Kicker('Waiting for you${s.signups.isEmpty ? '' : ' · ${s.signups.length}'}')],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final g in s.signups)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [T(g.name, w: 800, s: 15), const SizedBox(height: 1), T('Bed ${g.bed} · ${g.ago} · phone not verified', s: 13, c: p.mu)],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tap(
                                  onTap: () => s.approveSignup(g),
                                  child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, color: p.ac, child: T('Approve', w: 800, s: 14, c: p.ai)),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: 'Not my resident',
                                  button: true,
                                  child: Tap(
                                    onTap: () => s.rejectSignup(g),
                                    child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const Ic('x', size: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (s.signups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: T('No one waiting. New sign-ups show up here.', s: 14, c: p.mu),
                          ),
                      ],
                    ),
                  ),
                  if (code != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Tap(key: const ValueKey('newCode'), onTap: () => s.loadInvite(renew: true), child: T('Make a new code (the old one stops working)', s: 14, w: 800, c: p.ad)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
