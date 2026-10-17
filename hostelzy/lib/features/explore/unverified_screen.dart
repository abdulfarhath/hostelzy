import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../photos/photos_screens.dart';
import 'hostel_screen.dart' show DetailScreen;

// F26 #21: UNVERIFIED (team-listed) hostels: the badge, the Explore card, the
// hostel page (SCREENS T32) and the claim sheet (H44). No beds, holds,
// layouts or owner contact until the team verifies the hostel.

/// The grey-outline UNVERIFIED badge. It sits where the navy ✓ VERIFIED badge
/// sits on a verified hostel (its own widget, so the two never mix).
class UnverifiedBadge extends StatelessWidget {
  const UnverifiedBadge({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      key: const ValueKey('unverifiedBadge'),
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: box(w: 2, c: p.mu),
      child: T('Unverified', s: small ? 10 : 11, w: 800, ls: .08, lh: 1.3, upper: true, c: p.mu, nowrap: true),
    );
  }
}

void _open(AppState s, Hostel h) => s.update(() {
  s.hist = [...s.hist, s.screen];
  s.screen = 'detail';
  s.sheet = null;
  s.hid = h.id;
});

/// Explore card for a listed hostel: photo, name + UNVERIFIED, where, and the
/// expected rent range. No free beds, deals or rank.
class UnverifiedCard extends StatelessWidget {
  const UnverifiedCard(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final photos = s.photosOf[h.id] ?? const [];
    return Tap(
      key: ValueKey('listedCard-${h.id}'),
      onTap: () => _open(s, h),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: Hatch(p.sf, 8, 16, base: p.bg),
                child: Container(
                  decoration: box(w: 1, c: p.hl),
                  child: Stack(
                    children: [
                      Positioned.fill(child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url))),
                      Positioned(left: 8, bottom: 8, child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: T(photos.isEmpty ? 'No photos yet' : '1 / ${photos.length} · by the Hostelzy team', s: 12, c: p.mu))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [T(h.name, w: 800, s: 18, lh: 1.2), const UnverifiedBadge(small: true)],
            ),
            const SizedBox(height: 4),
            T('${h.gender} · ${h.area} · ${kmLabel(s.kmFor(h))} ${s.kmFrom}', s: 14, c: p.mu),
            const SizedBox(height: 4),
            Rich([sp(context, '${rentRange(h)}/mo', w: 800, c: p.tx), sp(context, ' · expected, not confirmed')], s: 14, c: p.mu),
          ],
        ),
      ),
    );
  }
}

/// T32: the hostel page of a listed hostel.
class UnverifiedScreen extends StatelessWidget {
  const UnverifiedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final photos = s.photosOf[h.id] ?? const [];
    final waiting = s.waitlist.contains(h.id);
    return Column(
      key: const ValueKey('unverifiedPage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scroll(
            key: ValueKey('unverified${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: Hatch(p.sf, 8, 16, base: p.bg),
                          child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url)),
                        ),
                      ),
                      Positioned(left: 16, top: 12, child: BackBtn(onTap: s.back, bg: p.bg)),
                      Positioned(left: 8, bottom: 8, child: Container(color: p.bg, padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: T(photos.isEmpty ? 'No photos yet' : '1 / ${photos.length} · by the Hostelzy team', s: 12, c: p.mu))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: VGap(
                    gap: 12,
                    children: [
                      VGap(
                        gap: 4,
                        children: [
                          Kicker('${h.gender} · ${h.area}, Hyderabad'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [T(h.name, w: 800, s: 30, lh: 1.05, ls: -.025), const UnverifiedBadge()],
                          ),
                          T('Listed by the Hostelzy team · not checked yet', s: 13, c: p.mu),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
                        child: VGap(
                          gap: 2,
                          children: [
                            const Kicker('Rent per month'),
                            T(rentRange(h), w: 800, s: 24, key: const ValueKey('rentRange')),
                            T('Expected, not confirmed. The owner hasn’t joined Hostelzy yet.', s: 13, c: p.mu, lh: 1.4),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: p.sf,
                        child: const T('No free beds, holds or owner contact yet. When our team checks this hostel, you’ll see its beds and can hold one.', s: 14, lh: 1.45),
                      ),
                      if (s.claimed.contains(h.id))
                        T('Claim sent. The Hostelzy team will call you.', s: 14, w: 800, c: p.mu)
                      else
                        Tap(
                          key: const ValueKey('claimLink'),
                          onTap: () => s.openClaim(h),
                          child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: T('Are you the owner? Claim this hostel ›', s: 14, w: 800, underline: true)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 8,
            children: [
              if (waiting)
                Cta('We’ll tell you when it’s verified', key: const ValueKey('tellMe'), icon: 'check', height: 52, px: 16, fs: 15, bg: p.sf, fg: p.tx, border: p.tx, onTap: () => s.tellWhenVerified(h))
              else
                Cta('Tell me when verified', key: const ValueKey('tellMe'), icon: 'bell', height: 52, px: 16, fs: 15, onTap: () => s.tellWhenVerified(h)),
              OutlineCta('Ask Hostelzy', icon: 'msg', onTap: () => s.askHostelzy(h)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hostel page: T32 for a listed (UNVERIFIED) hostel, else the full page.
class HostelPage extends StatelessWidget {
  const HostelPage({super.key});
  @override
  Widget build(BuildContext context) => hostelById(AppScope.of(context).hid).listed ? const UnverifiedScreen() : const DetailScreen();
}

/// H44: "Are you the owner? Claim this hostel": name and phone; the team
/// calls back and links the owner's account.
class ClaimSheet extends StatelessWidget {
  const ClaimSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          T('Tell us who you are. The Hostelzy team calls you to check, then helps you verify the hostel so tenants can hold beds.', s: 14, c: p.mu, lh: 1.45),
          const T('Your name', w: 800, s: 13),
          Field(key: const ValueKey('claimName'), value: s.claimName, placeholder: 'Your full name', onChanged: (v) => s.update(() => s.claimName = v)),
          const T('Your phone', w: 800, s: 13),
          Field(key: const ValueKey('claimPhone'), value: s.claimPhone, numeric: true, placeholder: '10 digits', onChanged: (v) => s.update(() => s.claimPhone = v.replaceAll(RegExp(r'\D'), ''))),
          const SizedBox(height: 4),
          Cta('Send to Hostelzy', key: const ValueKey('sendClaim'), height: 54, px: 16, fs: 15, onTap: s.sendClaim),
          T('Only the Hostelzy team sees this.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}
