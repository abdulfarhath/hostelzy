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
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Row(children: [BrandMark(size: 17, mono: p.ai), const SizedBox(width: 6), const T('hostelzy', w: 800, s: 20, ls: -.02)]), const T('Hyderabad', s: 12, w: 600, ls: .1, upper: true)]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: const [T('See the bed before you see the building.', w: 800, s: 58, lh: .94, ls: -.04, balance: true)]),
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
                  Cta('Get started', onTap: () => s.go(phoneOtpLogin ? 'phone' : 'login'), bg: p.ai, fg: p.ac, iconSize: 20),
                  const T('For tenants, residents and hostel owners.', s: 14, w: 600),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: s.back)),
          const _StepHead(step: 'Step 1 of 2', title: 'Sign in', sub: 'With your Google account. No passwords, no codes.'),
          const Spacer(),
          Cta(s.signingIn ? 'Opening Google…' : 'Continue with Google', icon: 'user', onTap: s.continueWithGoogle, iconSize: 20, opacity: s.signingIn ? .6 : 1),
          const SizedBox(height: 10),
          OutlineCta('Use on this phone only', icon: 'chev', onTap: s.continueOnPhone),
          const SizedBox(height: 8),
          T('Nothing is saved to an account. You can sign in later.', s: 12, c: p.mu, align: TextAlign.center),
          const SizedBox(height: 12),
          Rich([sp(context, 'By continuing you agree to the '), sp(context, 'Terms', w: 800, c: p.tx), sp(context, ' and '), sp(context, 'Privacy policy', w: 800, c: p.tx), sp(context, '.')], s: 13, c: p.mu, align: TextAlign.center),
        ],
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
    return Padding(
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
              : _StepHead(step: 'Step 2 of 2', title: 'Your mobile number', sub: '${s.account != null ? 'Signed in as ${s.account!.email}. ' : ''}Owners use it to call or WhatsApp you. They see it as “not verified” until Hostelzy can check numbers by SMS.'),
          const SizedBox(height: 28),
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
          Cta(phoneOtpLogin ? 'Send code' : 'Continue', onTap: () => s.phone.length != 10 ? s.toastMsg('Enter all 10 digits.') : (phoneOtpLogin ? s.sendCode() : s.savePhone()), iconSize: 20, bg: s.phone.length == 10 ? null : p.tk, fg: s.phone.length == 10 ? null : p.mu),
          const SizedBox(height: 12),
          Rich([sp(context, 'By continuing you agree to the '), sp(context, 'Terms', w: 800, c: p.tx), sp(context, ' and '), sp(context, 'Privacy policy', w: 800, c: p.tx), sp(context, '.')], s: 13, c: p.mu, align: TextAlign.center),
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
    return Padding(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(border: Border(bottom: bs(2, p.tx))),
          child: const PageHead(kicker: 'Welcome', title: 'How will you use Hostelzy?', size: 34, gap: 6),
        ),
        for (final r in roles)
          Tap(
            onTap: () {
              s.update(() {
                s.role = r[0];
                // F07: a new owner accepts the Fair Play rules first.
                s.screen = r[0] == 'owner' && !s.fairAccepted ? 'oRules' : homeOf[r[0]]!;
                s.hist = [];
              });
              s.syncProfile();
            },
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
    );
  }
}
