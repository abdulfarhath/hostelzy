import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

// F21 W2: one "Where?" field, sign-in at the first hold, notifications after it.

/// One typed field for landmarks, areas and hostels (Explore and the Map).
class WhereScreen extends StatelessWidget {
  const WhereScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final q = s.whereQ.trim().toLowerCase();
    bool hit(String x) => q.isEmpty || x.toLowerCase().contains(q);
    final live = browsable.where((h) => !s.removed(h.id)).toList();
    final lms = landmarks.where(hit).toList();
    final areas = mapAreas.where(hit).toList();
    final hostels = q.isEmpty ? <Hostel>[] : live.where((h) => hit(h.name)).toList();
    Widget group(String label) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: Kicker(label));
    Widget row(String icon, String title, String sub, VoidCallback onTap, {bool dim = false, Key? key}) => Tap(
      key: key,
      onTap: onTap,
      child: Opacity(
        opacity: dim ? .5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
          child: Row(
            children: [
              Container(width: 36, height: 36, alignment: Alignment.center, color: p.sf, child: Ic(icon, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(title, w: 800, s: 16), T(sub, s: 13, c: p.mu)])),
            ],
          ),
        ),
      ),
    );
    String n(int c) => c == 1 ? '1 hostel' : '$c hostels';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [BackBtn(onTap: s.back), const SizedBox(width: 12), const T('Where?', w: 800, s: 22)]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: box(w: 2, c: p.ac),
            child: Row(
              children: [
                const Padding(padding: EdgeInsets.only(left: 14), child: Ic('search', size: 18)),
                Expanded(child: Field(key: const ValueKey('whereQ'), value: s.whereQ, placeholder: 'Area, landmark or hostel', border: false, height: 50, fs: 17, w: 800, onChanged: (v) => s.update(() => s.whereQ = v))),
                if (s.whereQ.isNotEmpty) Tap(onTap: () => s.update(() => s.whereQ = ''), child: const Padding(padding: EdgeInsets.all(14), child: Ic('x', size: 18))),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              key: const ValueKey('nearMe'),
              onTap: s.whereNearMe,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: box(w: 2, c: p.tx),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [T('Near me', w: 800, s: 14), SizedBox(width: 8), Ic('pin', size: 16)]),
              ),
            ),
          ),
        ),
        Expanded(
          child: Scroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lms.isNotEmpty) group('Landmarks'),
                for (final l in lms) row('pin', l, '${n(live.where((h) => kmTo(h, l) <= 5).length)} within 5 km', () => s.pickLandmark(l), key: ValueKey('lm-$l')),
                if (areas.isNotEmpty) group('Areas'),
                for (final a in areas)
                  () {
                    final c = live.where((h) => h.area == a).length;
                    return row('globe', a, c == 0 ? 'Coming soon' : n(c), c == 0 ? () => s.toastMsg('No hostels in $a yet. Coming soon.') : () => s.pickWhereArea(a), dim: c == 0, key: ValueKey('area-$a'));
                  }(),
                if (hostels.isNotEmpty) group('Hostels'),
                for (final h in hostels) row('home', h.name, '${h.gender} · ${h.area}', () => s.pickWhereHostel(h.id), key: ValueKey('hostel-${h.id}')),
                if (lms.isEmpty && areas.isEmpty && hostels.isEmpty) Padding(padding: const EdgeInsets.all(16), child: T('Nothing called “${s.whereQ.trim()}” on Hostelzy yet.', s: 14, c: p.mu)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), child: T('The same field is on Explore and on the Map.', s: 12, c: p.mu)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Sign in to hold this bed": asked once, at the first hold or enquiry.
class SignInSheet extends StatelessWidget {
  const SignInSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final owner = hostelById(s.hid).owner;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 14,
        children: [
          T(s.afterSignIn == 'enquiry' ? 'So $owner knows who’s asking. We ask only once.' : 'So $owner knows who’s coming. We ask only once.', s: 15, c: p.mu, lh: 1.45),
          GoogleButton(s.signingIn ? 'Opening Google…' : 'Continue with Google', busy: s.signingIn, onTap: s.continueWithGoogle),
          // Builds without Google sign-in (the demo APK) keep everything on the phone.
          if (!s.signIn.available) OutlineCta('Use on this phone only', icon: 'chev', onTap: s.continueOnPhone),
          T('Then your name and phone number. Owners see it as “not verified”.', s: 12, c: p.mu, align: TextAlign.center),
        ],
      ),
    );
  }
}

/// After the first hold: notifications, so the owner's reply reaches you.
class HoldNotifySheet extends StatelessWidget {
  const HoldNotifySheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = s.holds.where((x) => x.id == s.holdId).firstOrNull;
    final owner = h == null ? 'the owner' : hostelById(h.hid).owner;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('Turn on notifications so $owner’s reply reaches you.', s: 15, c: p.mu, lh: 1.45),
          Cta('Turn on notifications', icon: 'bell', onTap: () {
            s.update(() => s.sheet = null);
            s.enablePush();
          }),
          OutlineCta('Not now', icon: 'x', onTap: () => s.update(() => s.sheet = null)),
        ],
      ),
    );
  }
}
