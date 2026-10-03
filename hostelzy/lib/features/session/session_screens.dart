import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Widget cell(String n, String t, bool first) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(border: first ? null : Border(left: bs(2, p.ai))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(n, s: 12, w: 600), const SizedBox(height: 2), T(t, w: 800, s: 15)]),
      ),
    );
    return Container(
      color: p.ac,
      child: Css(
        c: p.ai,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Row(mainAxisSize: MainAxisSize.min, children: [BrandMark(size: 17, mono: p.ai), const SizedBox(width: 6), const T('hostelzy', w: 800, s: 20, ls: -.02)]), const Flexible(child: T('Hyderabad', s: 12, w: 600, ls: .1, upper: true, align: TextAlign.right))]),
            ),
            // F21 W4: the language row, once a language has checked strings.
            if (s.langChoices.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  decoration: box(w: 2, c: p.ai),
                  child: Row(
                    children: [
                      for (final (code, label) in s.langChoices)
                        Expanded(
                          child: Tap(
                            key: ValueKey('wlang-$code'),
                            onTap: () => s.pickLang(code),
                            child: Container(color: s.lang == code ? p.ai : null, padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center, child: T(label, s: 14, w: 800, c: s.lang == code ? p.ac : p.ai)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                // F21 W4: the decorative headline shrinks to fit at large text sizes.
                child: Align(alignment: Alignment.bottomLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: MediaQuery.withNoTextScaling(child: const SizedBox(width: 350, child: T('See the bed before you see the building.', w: 800, s: 58, lh: .94, ls: -.04, balance: true))))),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: bs(2, p.ai), bottom: bs(2, p.ai)),
              ),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cell('01', 'Floor', true), cell('02', 'Room', false), cell('03', 'Your bed', false)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: VGap(
                gap: 12,
                children: [
                  // F21 W2: look around first; sign-in comes at the first hold.
                  Cta('Find a bed', key: const ValueKey('findBed'), onTap: s.browse, bg: p.ai, fg: p.ac, iconSize: 20),
                  const T('No sign-in needed to look around.', s: 14, w: 600),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      for (final (k, l) in const [('owner', 'I run a PG'), ('resident', 'I live in a PG'), (null, 'Sign in')])
                        Tap(onTap: () => s.startSignIn(k), child: T(l, s: 14, w: 800, underline: true)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHead extends StatelessWidget {
  const _StepHead({required this.step, required this.title, required this.sub});
  final String step, title, sub;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Kicker(step),
        const SizedBox(height: 6),
        T(title, w: 800, s: 34, lh: 1.02, ls: -.025),
        const SizedBox(height: 10),
        T(sub, s: 15, c: p.mu),
      ],
    );
  }
}

/// F13: Sign in with Google (DECISIONS 2026-10-02). Until Google sign-in is
/// switched on in Firebase, "Use on this phone only" keeps everything local.
/// F22 Area 4 (board `login`): the logo, why we ask, one Google button,
/// "Keep browsing as a guest", the Terms line.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final (title, sub) = switch (s.afterSignIn) {
      'owner' => ('Sign in to list your PG', 'So the Hostelzy team knows who to call. No passwords, no codes.'),
      'resident' => ('Sign in to join your PG', 'So your owner knows it’s you. No passwords, no codes.'),
      'enquiry' || 'book' || 'hold' => ('Sign in to hold a bed', 'So owners know who’s coming. No passwords, no codes.'),
      _ => ('Sign in', 'With your Google account. No passwords, no codes.'),
    };
    return FillScroll(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back)),
            const SizedBox(height: 40),
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 64)),
            const SizedBox(height: 14),
            T(title, w: 800, s: 34, lh: 1.02, ls: -.025),
            const SizedBox(height: 14),
            T(sub, s: 16, c: p.mu, lh: 1.5),
            const Spacer(),
            const SizedBox(height: 24),
            GoogleButton(s.signingIn ? 'Opening Google…' : 'Continue with Google', busy: s.signingIn, onTap: s.continueWithGoogle),
            const SizedBox(height: 6),
            Center(
              child: Tap(
                key: const ValueKey('keepGuest'),
                onTap: s.browse,
                child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: T('Keep browsing as a guest', w: 800, s: 15)),
              ),
            ),
            _Agree(s: s),
            const SizedBox(height: 10),
            // Without a Google account: everything stays on this phone.
            Center(child: Tap(onTap: s.continueOnPhone, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: T('Use on this phone only', s: 13, w: 600, c: p.mu)))),
          ],
        ),
      ),
    );
  }
}

class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return FillScroll(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackBtn(onTap: s.back),
            ),
            phoneOtpLogin
                ? const _StepHead(step: 'Step 1 of 2', title: 'Your mobile number', sub: 'We send a 6-digit code by SMS. No passwords.')
                // F13: typed, not verified: owners see "not verified" until SMS checks exist.
                // F22 Area 4 (board `about`): two fields, the "not verified" tag.
                : _StepHead(step: s.account?.email ?? 'About you', title: 'About you', sub: 'Owners use this to call or WhatsApp you.'),
            const SizedBox(height: 28),
            // F18: the user's own name (never a sample one).
            if (!phoneOtpLogin) ...[
              const T('Your name', w: 800, s: 13),
              const SizedBox(height: 6),
              // F24 item 23: never pre-filled; the Google name is only the hint.
              Field(key: const ValueKey('myName'), value: s.myName, placeholder: (s.account?.name ?? '').trim().isEmpty ? 'Full name' : s.account!.name, onChanged: (v) => s.update(() => s.myName = v)),
              if (s.account != null) ...[const SizedBox(height: 4), T('Type the name owners should see.', s: 12, c: p.mu)],
              const SizedBox(height: 16),
              Row(children: [const Expanded(child: T('Mobile number', w: 800, s: 13)), Container(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7), decoration: box(w: 1, c: p.dv), child: T('NOT VERIFIED', w: 800, s: 11, c: p.mu, ls: .05))]),
              const SizedBox(height: 6),
            ],
            Container(
              height: 60,
              decoration: box(w: 2, c: p.tx),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(right: bs(2, p.tx))),
                    child: const T('+91', w: 800, s: 20),
                  ),
                  Expanded(
                    child: Field(value: s.phone, onChanged: (v) => s.update(() => s.phone = _digits(v, 10)), placeholder: '10-digit number', numeric: true, border: false, height: null, fs: 22, w: 800, ls: .04, pad: const EdgeInsets.symmetric(horizontal: 14)),
                  ),
                ],
              ),
            ),
            if (!phoneOtpLogin) ...[const SizedBox(height: 6), T('We’ll check it by SMS later. Until then owners see “not verified”.', s: 13, c: p.mu, lh: 1.4)],
            const Spacer(),
            Cta(phoneOtpLogin ? 'Send code' : 'Continue', onTap: () => phoneOtpLogin ? (s.phone.length != 10 ? s.toastMsg('Enter all 10 digits.') : s.sendCode()) : s.savePhone(), iconSize: 20, bg: s.phone.length == 10 ? null : p.tk, fg: s.phone.length == 10 ? null : p.mu),
            const SizedBox(height: 12),
            _Agree(s: s),
            // F17: demo shortcut for development only, never in the Play Store build.
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Tap(
                onTap: () => s.update(() => s.phone = '9000000001'),
                child: T('Debug: fill a test number', s: 13, c: p.ad, w: 600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _digits(String v, int max) {
  final d = v.replaceAll(RegExp(r'\D'), '');
  return d.length > max ? d.substring(0, max) : d;
}

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final cells = <Widget>[];
    for (var i = 0; i < 6; i++) {
      if (i > 0) cells.add(const SizedBox(width: 8));
      cells.add(
        Expanded(
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: box(w: 2, c: i == s.otp.length ? p.ac : p.tx),
            child: T(i < s.otp.length ? s.otp[i] : '', w: 800, s: 28),
          ),
        ),
      );
    }
    return FillScroll(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackBtn(onTap: s.back),
            ),
            _StepHead(step: 'Step 2 of 2', title: 'Enter the code', sub: 'Sent by SMS to +91 ${phoneSpaced(s.phone)}. Android can fill it in for you.'),
            const SizedBox(height: 28),
            Stack(
              children: [
                Row(children: cells),
                Positioned.fill(
                  child: Field(value: s.otp, onChanged: (v) => s.update(() => s.otp = _digits(v, 6)), numeric: true, border: false, height: null, pad: EdgeInsets.zero, hiddenText: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                s.resendLeft > 0
                    ? T('Resend in ${cd(s.resendLeft.toDouble())}', s: 13, c: p.mu)
                    : Tap(onTap: s.sendCode, child: T('Resend code', s: 13, w: 800, c: p.ad)),
                if (kDebugMode)
                  Tap(
                    onTap: () => s.update(() => s.otp = '123456'),
                    child: T('Debug: fill', s: 13, c: p.ad, w: 600),
                  ),
                Tap(onTap: s.back, child: T('Change number', s: 13, w: 800, c: p.mu)),
              ],
            ),
            const Spacer(),
            Cta('Verify', onTap: () => s.otp.length == 6 ? (s..signedIn = true).go('role') : s.toastMsg('Enter the 6-digit code.'), iconSize: 20, bg: s.otp.length == 6 ? null : p.tk, fg: s.otp.length == 6 ? null : p.mu),
          ],
        ),
      ),
    );
  }
}

/// F22 Area 4 (board `role`): "What brings you here?" with three big rows.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const roles = [
      ('tenant', 'search', 'I need a bed', 'Find and hold a bed in a PG'),
      ('resident', 'home', 'I live in a PG', 'Rent, food and complaints'),
      ('owner', 'bed', 'I run a PG', 'Beds, residents and rent'),
    ];
    return FillScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            // F18 (C3): back to About you.
            child: Row(
              children: [
                if (s.hist.isNotEmpty) ...[BackBtn(onTap: s.back), const SizedBox(width: 12)],
                Expanded(child: PageHead(kicker: s.meFirst.isEmpty ? 'Welcome' : 'Welcome, ${s.meFirst}', title: 'What brings you here?', gap: 2)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in roles)
                  Tap(
                    key: ValueKey('role-${r.$1}'),
                    onTap: () => s.pickRole(r.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(
                        children: [
                          Container(width: 48, height: 48, color: p.sf, alignment: Alignment.center, child: Ic(r.$2, size: 24, color: p.tx)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(r.$3, w: 800, s: 19), const SizedBox(height: 2), T(r.$4, s: 14, c: p.mu)])),
                          Ic('chev', size: 18, color: p.tx),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.all(16), child: T('You can switch later in Me.', s: 13, c: p.mu)),
        ],
      ),
    );
  }
}

/// F18: roles that need someone else first (design "Real app v2":
/// ResidentGate, OwnerGate). Residents are added by their owner; owners are
/// set up in person by the Hostelzy team. Never sample data instead.
class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final owner = s.roleGate == 'owner';
    // F22 Area 4 (boards `gateRes`, `gateOwn`): one job each.
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: owner ? 'I run a PG' : 'I live in a PG', title: owner ? 'List your PG' : 'Join your PG', gap: 2))],
      ),
    );
    final List<Widget> body;
    final List<Widget> foot;
    if (owner) {
      body = [
        T('We visit, take photos and set it up with you. 30 days free, then from ₹499 a month. No commission.', s: 15, c: p.mu, lh: 1.5),
        VGap(gap: 6, children: [const T('PG name', w: 800, s: 13), Field(key: const ValueKey('gateHostel'), value: s.gateHostel, placeholder: 'e.g. Sri Sai Men’s PG', onChanged: (v) => s.update(() => s.gateHostel = v))]),
        VGap(
          gap: 6,
          children: [
            const T('Area', w: 800, s: 13),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final a in const ['Ameerpet', 'SR Nagar', 'Madhapur', 'Hitec City', 'Kondapur', 'Gachibowli', 'KPHB', 'Other']) ChipBtn(a, on: s.gateArea == a, onTap: () => s.update(() => s.gateArea = a))]),
          ],
        ),
      ];
      // F24: an owner who got a sign-in link from the Hostelzy team.
      if (s.pendingInvite?.startsWith('OWN-') ?? false) {
        body.insert(0, Container(
          key: const ValueKey('ownerJoin'),
          padding: const EdgeInsets.all(12),
          decoration: box(w: 2, c: p.tx),
          child: VGap(gap: 8, children: [
            const T('Your owner link from Hostelzy', w: 800, s: 15),
            T('Sign in once with it and your PG opens here, set up the way we did it on the visit.', s: 13, c: p.mu, lh: 1.4),
            Cta(s.joining ? 'Linking…' : 'Run my PG on Hostelzy', key: const ValueKey('ownerJoinGo'), height: 50, px: 14, fs: 15, onTap: s.joinInvite),
          ]),
        ));
      }
      // F24 (board `mgrJoin`): a manager joins with the owner's MGR- code.
      body.add(Tap(
        key: const ValueKey('mgrJoinOpen'),
        onTap: () => s.update(() {
          s.roleGate = 'resident';
          s.inviteDraft = 'MGR-';
        }),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: p.sf,
          child: Row(children: [Expanded(child: VGap(gap: 2, children: [const T('Manager at a PG?', w: 800, s: 14), T('Join it with the MGR- code your owner sent you.', s: 13, c: p.mu, lh: 1.4)])), const Ic('chev', size: 18)]),
        ),
      ));
      foot = [
        Cta('Request a visit', onTap: s.requestVisit, height: 54, px: 16, fs: 15),
        OutlineCta('WhatsApp Hostelzy', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, I run a PG and want to list it.')),
      ];
    } else {
      final num = s.phone.length == 10 ? '+91 ${phoneSpaced(s.phone)}' : null;
      final code = s.inviteDraft.isEmpty ? s.pendingInvite ?? '' : s.inviteDraft;
      final mgr = code.toUpperCase().startsWith('MGR');
      body = [
        T('Your owner gives you a code, or scan the Hostelzy poster at your PG.', s: 15, c: p.mu, lh: 1.5),
        // C: type the code (filled in when the invite link opened the app).
        Row(
          children: [
            Expanded(child: Field(key: const ValueKey('inviteCode'), value: s.inviteDraft.isEmpty ? s.pendingInvite ?? '' : s.inviteDraft, placeholder: 'e.g. ANJ-7Q2', height: 54, fs: 20, w: 800, ls: .06, onChanged: (v) => s.update(() => s.inviteDraft = v.toUpperCase()))),
            const SizedBox(width: 8),
            Cta(s.joining ? 'Sending…' : 'Join', key: const ValueKey('joinGo'), height: 54, px: 16, fs: 15, expand: false, onTap: s.joinInvite),
          ],
        ),
        if (mgr) T('Manager codes start with MGR. The owner sends it on WhatsApp; it works once, for 7 days.', key: const ValueKey('mgrHint'), s: 13, c: p.mu, lh: 1.45),
        if (!mgr) ...[
        // F14: the in-app scanner reads the poster's QR (the j/ invite link).
        OutlineCta('Scan the QR', key: const ValueKey('scanQr'), icon: 'qr', onTap: s.openScan),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          color: p.sf,
          child: VGap(
            gap: 6,
            children: [
              const T('No code?', w: 800, s: 14),
              T(num == null ? 'Ask your owner to add you with your mobile number. Add it in Settings first.' : 'Ask your owner to add you with $num.', s: 14, c: p.mu, lh: 1.4),
              Cta('Send my number on WhatsApp', icon: 'msg', height: 46, px: 16, fs: 14, bg: p.tx, fg: p.bg, onTap: () => s.whatsapp('', 'Hi, please add me as a resident on Hostelzy. My number is ${num ?? ''}${s.meName.isEmpty ? '' : ' (${s.meName})'}.')),
            ],
          ),
        ),
        ],
      ];
      foot = [Tap(onTap: () => s.pickRole('tenant'), child: T('Not in a PG yet? Find a bed ›', w: 800, s: 15, c: p.tx))];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: Scroll(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: VGap(gap: 12, children: body)))),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(gap: 8, children: foot),
        ),
      ],
    );
  }
}

/// F18 (C1): "By continuing you agree to the Terms and Privacy policy", both links real.
class _Agree extends StatelessWidget {
  const _Agree({required this.s});
  final AppState s;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        T('By continuing you agree to the ', s: 13, c: p.mu),
        Tap(onTap: () => s.openLink(Uri.parse(termsUrl), 'the browser'), child: T('Terms', s: 13, w: 800, c: p.tx)),
        T(' and ', s: 13, c: p.mu),
        Tap(onTap: () => s.openLink(Uri.parse(privacyUrl), 'the browser'), child: T('Privacy policy', s: 13, w: 800, c: p.tx)),
        T('.', s: 13, c: p.mu),
      ],
    );
  }
}

/// F14: the camera explainer before Android's own prompt (first scan only).
class CameraSheet extends StatelessWidget {
  const CameraSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('Only to read the QR on your PG’s Hostelzy poster. Nothing is recorded or saved, and nobody sees your camera.', s: 15, c: p.mu, lh: 1.5),
          Tap(
            key: const ValueKey('allowCamera'),
            onTap: s.allowCamera,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: p.ac,
              child: Row(
                children: [
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [T('Allow camera', w: 800, s: 15, c: p.ai), T('Your phone asks next', w: 600, s: 11, c: p.ai.withValues(alpha: .8))])),
                  Ic('arrow', size: 18, color: p.ai),
                ],
              ),
            ),
          ),
          OutlineCta('Type the code instead', icon: 'pencil', onTap: () => s.update(() => s.sheet = null)),
        ],
      ),
    );
  }
}

/// F14: scan the invite QR on the PG's poster; the code fills in and joins.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Widget error(bool denied) => Container(
      key: const ValueKey('scanError'),
      color: p.sf,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: VGap(
        gap: 8,
        children: [
          Ic('lock', size: 24, color: p.tx),
          T(denied ? 'The camera is off for Hostelzy' : 'The camera didn’t start', w: 800, s: 17, align: TextAlign.center),
          T(denied ? 'Allow it in your phone’s Settings → Apps → Hostelzy → Permissions, or type the code.' : 'Type the code from the poster instead.', s: 13, c: p.mu, lh: 1.45, align: TextAlign.center),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const Expanded(child: PageHead(kicker: 'Join your PG', title: 'Scan the QR', gap: 2))],
          ),
        ),
        Expanded(
          child: Scroll(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: VGap(
                gap: 12,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: box(w: 2, c: p.tx),
                      clipBehavior: Clip.hardEdge,
                      child: s.scanner.view(s.scannedQr, error),
                    ),
                  ),
                  T('Point it at the QR on the Hostelzy poster at your PG. The code fills in by itself and your owner gets the request.', s: 14, c: p.mu, lh: 1.5),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: OutlineCta('Type the code instead', key: const ValueKey('scanType'), icon: 'pencil', onTap: s.back),
        ),
      ],
    );
  }
}
