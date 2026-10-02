import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../app_config.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

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
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
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
            Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back)),
            const _StepHead(step: 'Step 1 of 2', title: 'Sign in', sub: 'With your Google account. No passwords, no codes.'),
            const Spacer(),
            GoogleButton(s.signingIn ? 'Opening Google…' : 'Continue with Google', busy: s.signingIn, onTap: s.continueWithGoogle),
            const SizedBox(height: 10),
            OutlineCta('Use on this phone only', icon: 'chev', onTap: s.continueOnPhone),
            const SizedBox(height: 8),
            T('Nothing is saved to an account. You can sign in later.', s: 12, c: p.mu, align: TextAlign.center),
            const SizedBox(height: 12),
            _Agree(s: s),
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
                : _StepHead(step: 'Step 2 of 2${s.account != null ? ' · ${s.account!.email}' : ''}', title: 'About you', sub: '${s.account != null ? 'Signed in as ${s.account!.email}. ' : ''}Owners use your number to call or WhatsApp you. They see it as “not verified” until Hostelzy can check numbers by SMS.'),
            const SizedBox(height: 28),
            // F18: the user's own name (never a sample one).
            if (!phoneOtpLogin) ...[
              const T('Your name', w: 800, s: 13),
              const SizedBox(height: 6),
              Field(key: const ValueKey('myName'), value: s.myName, placeholder: 'Full name', onChanged: (v) => s.update(() => s.myName = v)),
              if (s.account != null) ...[const SizedBox(height: 4), T('From your Google account. Change it if you like.', s: 12, c: p.mu)],
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

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const roles = [
      ['tenant', '01', 'I need a bed', 'Search PGs and hostels, pick the exact bed, hold it.'],
      ['resident', '02', 'I live in a Hostelzy PG', 'Pay rent, see the menu, raise complaints.'],
      ['owner', '03', 'I run a hostel', 'Bed map, hold requests, rent and complaints.'],
    ];
    return FillScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
            // F18 (C3): back to About you.
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (s.hist.isNotEmpty) ...[Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back)), const SizedBox(height: 8)], const PageHead(kicker: 'Welcome', title: 'How will you use Hostelzy?', size: 34, gap: 6)]),
          ),
          for (final r in roles)
            Tap(
              onTap: () => s.pickRole(r[0]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                decoration: BoxDecoration(border: Border(bottom: bs(2, p.dv))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: T(r[1], w: 800, s: 14, c: p.ad),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          T(r[2], w: 800, s: 22, ls: -.015),
                          const SizedBox(height: 4),
                          T(r[3], s: 14, c: p.mu, lh: 1.4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 24,
                      child: Padding(padding: EdgeInsets.only(top: 4), child: Ic('arrow', size: 22)),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: T('You can switch later from your profile.', s: 12, c: p.mu),
          ),
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
    final who = s.meName.isEmpty ? '' : '${s.meName} · ';
    Widget step(int n, String t, String sub) => Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 28, height: 28, color: p.tx, alignment: Alignment.center, child: T('$n', w: 800, s: 14, c: p.bg)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(t, w: 800, s: 14), T(sub, s: 12, c: p.mu)])),
        ],
      ),
    );
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '$who${owner ? 'I run a PG' : 'I live in a PG'}', title: owner ? 'List your hostel' : 'Ask your owner to add you', size: owner ? 30 : 28))],
      ),
    );
    final List<Widget> body;
    final List<Widget> foot;
    if (owner) {
      body = [
        T('The Hostelzy team sets up every hostel in person, so the listing is right from day one.', s: 15, c: p.mu, lh: 1.5),
        Column(children: [step(1, 'Request a visit', 'Tell us the hostel name and area'), step(2, 'We visit (about 45 min)', 'Photos, rooms, prices, residents'), step(3, 'You check and go live', '30 days free, then from ₹499 a month')]),
        VGap(gap: 6, children: [const T('Hostel name', w: 800, s: 13), Field(key: const ValueKey('gateHostel'), value: s.gateHostel, placeholder: 'e.g. Sri Sai Men’s PG', onChanged: (v) => s.update(() => s.gateHostel = v))]),
        VGap(
          gap: 6,
          children: [
            const T('Area', w: 800, s: 13),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final a in const ['Ameerpet', 'SR Nagar', 'Madhapur', 'Hitec City', 'Kondapur', 'Gachibowli', 'KPHB', 'Other']) ChipBtn(a, on: s.gateArea == a, onTap: () => s.update(() => s.gateArea = a))]),
          ],
        ),
      ];
      foot = [
        Cta('Request a visit', onTap: s.requestVisit, height: 54, px: 16, fs: 15),
        OutlineCta('WhatsApp Hostelzy · +91 ${phoneSpaced(supportWhatsApp)}', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, I run a PG and want to list it.')),
      ];
    } else {
      body = [
        T('Your rent, food menu and complaints open once your PG owner adds you with this number.', s: 15, c: p.mu, lh: 1.5),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: box(w: 2, c: p.tx),
          child: VGap(
            gap: 4,
            children: [
              const Kicker('Your number'),
              T(s.phone.length == 10 ? '+91 ${phoneSpaced(s.phone)}' : 'Add your number in Settings', w: 800, s: 24, ls: .02),
              const SizedBox(height: 6),
              Cta('Send it to your owner on WhatsApp', icon: 'msg', height: 48, px: 16, fs: 14, bg: p.tx, fg: p.bg, onTap: () => s.whatsapp('', 'Hi, please add me as a resident on Hostelzy. My number is +91 ${phoneSpaced(s.phone)}${s.meName.isEmpty ? '' : ' (${s.meName})'}.')),
            ],
          ),
        ),
        Row(
          children: [
            Container(width: 40, height: 40, color: p.sf, alignment: Alignment.center, child: Ic('qr', size: 20, color: p.tx)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const T('Is there a Hostelzy poster at your PG?', w: 800, s: 15), T('Scan its QR to ask to join. The owner approves you.', s: 12, c: p.mu)])),
          ],
        ),
        // Honest: the in-app scanner comes later; the phone camera opens the poster's link.
        Cta('Scan the invite QR', onTap: () => s.toastMsg('Open your phone camera and point it at the poster. It opens the invite link.'), height: 54, px: 16, fs: 15),
        // C: or type the code (filled in when the invite link opened the app).
        VGap(
          gap: 6,
          children: [
            const T('Have an invite code?', w: 800, s: 13),
            Row(
              children: [
                Expanded(child: Field(key: const ValueKey('inviteCode'), value: s.inviteDraft.isEmpty ? s.pendingInvite ?? '' : s.inviteDraft, placeholder: 'e.g. ANJ-7Q2', onChanged: (v) => s.update(() => s.inviteDraft = v.toUpperCase()))),
                const SizedBox(width: 8),
                Cta(s.joining ? 'Sending…' : 'Ask to join', icon: 'arrow', height: 48, px: 14, fs: 14, expand: false, bg: p.tx, fg: p.bg, onTap: s.joinInvite),
              ],
            ),
          ],
        ),
      ];
      foot = [Tap(onTap: () => s.pickRole('tenant'), child: T('Not in a PG yet? Find a bed', w: 800, s: 14, c: p.tx))];
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
