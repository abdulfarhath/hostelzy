import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'screens_owner.dart';
import 'screens_resident.dart';
import 'screens_start.dart';
import 'screens_tenant.dart';

/// Body text: Archivo 16px, line-height 1.4 (`[data-hz]`).
TextStyle rootTextStyle(Pal p) => TextStyle(fontFamily: 'Archivo', fontSize: 16, height: 1.4, letterSpacing: 0, color: p.tx, fontWeight: FontWeight.w400, leadingDistribution: TextLeadingDistribution.even, decoration: TextDecoration.none);

/// Wide screens: the prototype layout (screen list + 410×864 phone frame).
/// Narrow screens: the app full screen. `bare`: the phone frame alone.
class HostelzyShell extends StatelessWidget {
  const HostelzyShell({super.key, this.bare = false, this.onOpenOverview});
  final bool bare;
  final VoidCallback? onOpenOverview;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pal = s.theme == 'dark' ? Pal.dark : Pal.light;
    return PalScope(
      pal: pal,
      child: DefaultTextStyle(
        style: rootTextStyle(pal),
        child: LayoutBuilder(
          builder: (context, c) {
            if (bare) return const PhoneFrame();
            if (c.maxWidth >= 730) return _Desk(onOpenOverview: onOpenOverview);
            return const _FullScreen();
          },
        ),
      ),
    );
  }
}

class _Desk extends StatelessWidget {
  const _Desk({this.onOpenOverview});
  final VoidCallback? onOpenOverview;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      color: const Color(0xFFDCDAD9),
      child: Scroll(
        child: Container(
          color: p.page,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JumpPanel(onOpenOverview: onOpenOverview),
              const SizedBox(width: 40),
              const PhoneFrame(),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpPanel extends StatelessWidget {
  const _JumpPanel({this.onOpenOverview});
  final VoidCallback? onOpenOverview;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const groups = [
      ('Start', [('welcome', 'Welcome', 'tenant'), ('phone', 'Phone number', 'tenant'), ('otp', 'OTP', 'tenant'), ('role', 'Pick a role', 'tenant')]),
      ('Tenant', [('explore', 'Explore', 'tenant'), ('map', 'Map', 'tenant'), ('detail', 'Hostel detail', 'tenant'), ('picker', 'Bed picker', 'tenant'), ('hold', 'Hold status', 'tenant'), ('holds', 'Holds', 'tenant')]),
      ('Resident', [('rHome', 'Home', 'resident'), ('rPay', 'Pay rent', 'resident'), ('food', 'Food', 'resident'), ('help', 'Complaints', 'resident'), ('move', 'Vacate / swap', 'resident')]),
      ('Owner', [('oToday', 'Today', 'owner'), ('oBeds', 'Bed map', 'owner'), ('oRent', 'Rent', 'owner'), ('oMore', 'Manage', 'owner')]),
    ];
    final children = <Widget>[
      VGap(
        gap: 6,
        children: [
          const T('hostelzy', w: 800, s: 26, ls: -.02),
          T('Mobile prototype. Everything is clickable. Use the list below to jump straight to any screen.', s: 13, c: p.mu, lh: 1.45),
          _Link('Open all screens →', onTap: onOpenOverview),
        ],
      ),
      Seg(opts: const [('light', 'Light'), ('dark', 'Dark')], cur: s.theme, onPick: (v) => s.update(() => s.theme = v), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10)),
      for (final g in groups)
        Container(
          decoration: BoxDecoration(border: Border(top: bs(2, p.dv))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Kicker(g.$1)),
              for (final j in g.$2)
                () {
                  final on = s.screen == j.$1 && (s.role == j.$3 || const ['welcome', 'phone', 'otp', 'role'].contains(j.$1));
                  return Tap(
                    onTap: () => s.jump(j.$1, j.$3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: T(j.$2, s: 13, w: on ? 800 : 400, c: on ? p.ad : p.tx),
                    ),
                  );
                }(),
            ],
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(width: 240, child: VGap(gap: 20, children: children)),
    );
  }
}

class _Link extends StatefulWidget {
  const _Link(this.text, {this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: T(widget.text, s: 13, w: 600, underline: true, c: hover ? const Color(0xFFEC3013) : const Color(0xFFAE1800)),
      ),
    ),
  );
}

/// 410×864 device frame with a fake status bar and home indicator.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final onWelcome = s.screen == 'welcome';
    final sbBg = onWelcome ? p.ac : p.bg, sbFg = onWelcome ? p.ai : p.tx;
    return Container(
      width: 410,
      height: 864,
      decoration: BoxDecoration(
        color: p.bg,
        border: Border.all(width: 10, color: const Color(0xFF111111)),
        borderRadius: BorderRadius.circular(52),
        boxShadow: const [BoxShadow(offset: Offset(0, 12), blurRadius: 32, color: Color.fromRGBO(0, 0, 0, .22))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: _AppBody(
          top: Container(
            height: 44,
            color: sbBg,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Css(
              c: sbFg,
              w: 600,
              s: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const T('9:41'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const T('5G', s: 12),
                      const SizedBox(width: 6),
                      Container(
                        width: 22,
                        height: 11,
                        padding: const EdgeInsets.all(1.5),
                        decoration: box(w: 1.5, c: sbFg),
                        child: Container(color: sbFg),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottom: Container(
            height: 24,
            color: sbBg,
            alignment: Alignment.center,
            child: Opacity(
              opacity: .8,
              child: Container(
                width: 124,
                height: 4,
                decoration: BoxDecoration(color: sbFg, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          toastBottom: 100,
        ),
      ),
    );
  }
}

class _FullScreen extends StatelessWidget {
  const _FullScreen();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final mq = MediaQuery.of(context);
    final onWelcome = s.screen == 'welcome';
    final sbBg = onWelcome ? p.ac : p.bg;
    final dark = s.theme == 'dark';
    // Light status-bar icons on the red welcome screen and in dark theme.
    final lightIcons = onWelcome ? !dark : dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: transparent, systemNavigationBarColor: sbBg),
      child: Container(
        color: p.bg,
        child: _AppBody(
          top: Container(height: mq.padding.top, color: sbBg),
          bottom: Container(height: mq.padding.bottom, color: sbBg),
          toastBottom: 76 + mq.padding.bottom,
        ),
      ),
    );
  }
}

/// Screen + tabs + sheets + toast, between a top and bottom inset.
class _AppBody extends StatelessWidget {
  const _AppBody({required this.top, required this.bottom, required this.toastBottom});
  final Widget top, bottom;
  final double toastBottom;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final showTabs = AppState.tabScreens.contains(s.screen);
    // Material installs its own DefaultTextStyle; put the design's back.
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: rootTextStyle(p),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                Expanded(child: _screen(s.screen)),
                if (showTabs) const _TabBar(),
                bottom,
              ],
            ),
            if (s.sheet != null) const Positioned.fill(child: _Sheet()),
            if (s.toast != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: toastBottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.tx,
                    boxShadow: const [BoxShadow(offset: Offset(0, 12), blurRadius: 32, color: Color.fromRGBO(0, 0, 0, .25))],
                  ),
                  child: T(s.toast!, s: 14, w: 600, lh: 1.35, c: p.bg),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _screen(String k) => switch (k) {
    'welcome' => const WelcomeScreen(),
    'phone' => const PhoneScreen(),
    'otp' => const OtpScreen(),
    'role' => const RoleScreen(),
    'explore' => const ExploreScreen(),
    'map' => const MapScreen(),
    'holds' => const HoldsScreen(),
    'me' => const MeScreen(),
    'detail' => const DetailScreen(),
    'picker' => const PickerScreen(),
    'hold' => const HoldScreen(),
    'rHome' => const ResidentHomeScreen(),
    'rPay' => const RentPayScreen(),
    'food' => const FoodScreen(),
    'help' => const HelpScreen(),
    'move' => const MoveScreen(),
    'oToday' => const OwnerTodayScreen(),
    'oBeds' => const OwnerBedsScreen(),
    'oRent' => const OwnerRentScreen(),
    'oMore' => const OwnerManageScreen(),
    _ => const SizedBox(),
  };
}

class _TabBar extends StatelessWidget {
  const _TabBar();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const tabs = {
      'tenant': [('explore', 'Explore', 'home'), ('map', 'Map', 'pin'), ('*', 'Search', 'search'), ('holds', 'Holds', 'clock'), ('me', 'Me', 'user')],
      'resident': [('rHome', 'Home', 'home'), ('food', 'Food', 'utensils'), ('rPay', 'Pay rent', 'wallet'), ('help', 'Help', 'wrench'), ('me', 'Me', 'user')],
      'owner': [('oToday', 'Today', 'chart'), ('oBeds', 'Beds', 'bed'), ('*', 'Booking', 'plus'), ('oRent', 'Rent', 'wallet'), ('oMore', 'Manage', 'inbox')],
    };
    final list = tabs[s.role]!;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: bs(2, p.tx)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++)
            () {
              final t = list[i];
              final center = i == 2, act = s.screen == t.$1;
              return Expanded(
                child: Tap(
                  onTap: () {
                    if (t.$1 != '*') return s.tab(t.$1);
                    if (s.role == 'tenant') {
                      s.update(() => s.sheet = 'search');
                    } else {
                      s.update(() {
                        s.sheet = 'add';
                        s.addName = '';
                        s.addPhone = '';
                        s.addBed = null;
                        s.addDate = 'Today';
                      });
                    }
                  },
                  child: InsetBar(
                    edge: Edge.top,
                    size: !center && act ? 3 : 0,
                    color: p.ac,
                    bg: center ? p.ac : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Css(
                        c: center
                            ? p.ai
                            : act
                            ? p.tx
                            : p.mu,
                        s: 11,
                        w: 600,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Ic(t.$3, size: 20), const SizedBox(height: 5), T(t.$2, nowrap: true)]),
                      ),
                    ),
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ sheets

class _Sheet extends StatelessWidget {
  const _Sheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    final title = switch (s.sheet) {
      'search' => 'Search',
      'hold' => sb?.b != null ? 'Hold bed ${sb!.b!.id}' : 'Hold',
      'wa' => 'Continue on WhatsApp',
      'add' => 'Add a booking',
      'bed' => 'Bed ${s.obed ?? ''}',
      _ => '',
    };
    final enq = s.sheet == 'enq' ? s.enquiries.where((e) => e.ref == s.enqRef).firstOrNull : null;
    final body = switch (s.sheet) {
      'search' => const _SearchSheet(),
      'hold' => const _HoldSheet(),
      'wa' => const _WaSheet(),
      'add' => const _AddSheet(),
      'bed' => const _BedSheet(),
      'enq' => const _EnquirySheet(),
      _ => const SizedBox(),
    };
    void close() => s.update(() => s.sheet = null);
    return Container(
      color: const Color.fromRGBO(20, 18, 17, .55),
      child: LayoutBuilder(
        builder: (context, c) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: close),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * .88),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.bg,
                    border: Border(top: bs(2, p.tx)),
                  ),
                  child: Scroll(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(border: Border(bottom: bs(2, p.dv))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: enq != null
                                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Kicker('Enquiry from Hostelzy'), const SizedBox(height: 2), T('${enq.ref} · ${enq.name}', w: 800, s: 20)])
                                      : T(title, w: 800, s: 20),
                                ),
                                const SizedBox(width: 12),
                                Tap(
                                  onTap: close,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: box(w: 1, c: p.dv),
                                    child: const Ic('x', size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          body,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchSheet extends StatelessWidget {
  const _SearchSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final count = filtered(s).length;
    Widget group(String label, Widget child) => VGap(gap: 8, children: [Kicker(label), child]);
    const segPad = EdgeInsets.symmetric(vertical: 10, horizontal: 8);
    Widget lmChip(String l) => Expanded(
      child: ChipBtn(l, on: l == s.lm, onTap: () => s.update(() => s.lm = l), pad: const EdgeInsets.symmetric(vertical: 11, horizontal: 12), fs: 14),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 18,
        children: [
          group(
            'Near',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [lmChip(landmarks[0]), const SizedBox(width: 6), lmChip(landmarks[1])]),
                const SizedBox(height: 6),
                Row(children: [lmChip(landmarks[2]), const SizedBox(width: 6), lmChip(landmarks[3])]),
              ],
            ),
          ),
          group('Who is it for', Seg(opts: const [('Any', 'Any'), ('Women', 'Women'), ('Men', 'Men'), ('Co-living', 'Co-ed')], cur: s.fG, onPick: (v) => s.update(() => s.fG = v), pad: segPad)),
          group('Sharing', Seg(opts: same(['Any', '2', '3', '4']), cur: s.fS, onPick: (v) => s.update(() => s.fS = v), pad: segPad)),
          group('Monthly budget', Seg(opts: const [('Any', 'Any'), ('6k', '<6k'), ('8k', '<8k'), ('10k', '<10k')], cur: s.fB, onPick: (v) => s.update(() => s.fB = v), pad: segPad)),
          Tap(
            onTap: () => s.update(() => s.fFood = !s.fFood),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: bs(1, p.hl), bottom: bs(1, p.hl)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const T('Food included', s: 15, w: 600),
                  Container(
                    width: 44,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: box(bg: s.fFood ? p.ac : transparent, w: 2, c: p.tx),
                    alignment: s.fFood ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(width: 16, height: 16, color: s.fFood ? p.ai : p.tx),
                  ),
                ],
              ),
            ),
          ),
          Cta(
            'Show $count hostels',
            parts: ['Show', '$count', 'hostels'],
            height: 54,
            px: 16,
            fs: 15,
            onTap: () {
              if (s.screen != 'explore' && s.screen != 'map') {
                s.tab('explore');
              } else {
                s.update(() => s.sheet = null);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HoldSheet extends StatelessWidget {
  const _HoldSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    final o = holdOptions[s.holdOpt]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: T(sb?.b != null ? '${h.name} · Room ${sb!.r!.n} · ${fmt(sb.r!.rent)}/mo' : '', s: 13, c: p.mu),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: VGap(
            gap: 8,
            children: [
              for (final k in holdOptions.keys)
                () {
                  final on = k == s.holdOpt;
                  final opt = holdOptions[k]!;
                  return Tap(
                    onTap: () => s.update(() => s.holdOpt = k),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: box(bg: on ? p.ab : transparent, w: 2, c: on ? p.ac : p.hl),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: box(w: 2, c: p.tx),
                                child: Container(width: 8, height: 8, color: on ? p.ac : transparent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(opt.title, w: 800, s: 16),
                                const SizedBox(height: 3),
                                T(opt.sub, s: 13, c: p.mu, lh: 1.35),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          T(opt.amt, w: 800, s: 18),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: T(o.note, s: 12, c: p.mu, lh: 1.45),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Cta(o.cta, px: 16, onTap: s.placeHold),
        ),
      ],
    );
  }
}

/// F05 design question: the tenant note is green as the spec says, but the
/// design rules keep green for savings and deals. Founder approved the
/// default (green); false gives the neutral version from board 1.
const enquiryNoteGreen = true;

class _WaSheet extends StatelessWidget {
  const _WaSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ref = s.waRef;
    final noteFg = enquiryNoteGreen ? p.gn : p.tx;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          if (ref != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: box(bg: enquiryNoteGreen ? p.gb : p.sf, w: 2, c: enquiryNoteGreen ? p.gb : p.tx),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: Ic('shieldOk', size: 20, color: noteFg)),
                  const SizedBox(width: 10),
                  Expanded(child: Rich([sp(context, '${s.waTo} has been told on Hostelzy', w: 800, c: noteFg), sp(context, ', with your verified number and ref '), sp(context, ref, w: 800), sp(context, '.')], s: 14, lh: 1.4)),
                ],
              ),
            ),
          Rich([sp(context, 'To '), sp(context, ref != null ? '${s.waTo} · ${hostelById(s.waHid!).name}' : s.waTo ?? '', w: 800, c: p.tx), sp(context, ". We fill in the message so you don't have to.")], s: 13, c: p.mu),
          Container(
            padding: const EdgeInsets.all(14),
            color: p.sf,
            child: VGap(
              gap: 10,
              children: [
                T(s.waMsg ?? '', s: 15, lh: 1.45),
                if (ref != null) Rich([sp(context, 'Ref '), sp(context, ref, w: 800), sp(context, ' · hostelzy.in/r/$ref')], s: 14, lh: 1.45),
              ],
            ),
          ),
          Cta(
            'Open WhatsApp',
            icon: 'msg',
            height: 54,
            px: 16,
            fs: 15,
            bg: p.tx,
            fg: p.bg,
            onTap: () {
              final to = s.waTo ?? '';
              s.update(() => s.sheet = null);
              s.toastMsg('Opening WhatsApp with $to…');
            },
          ),
          OutlineCta(
            'Copy message',
            icon: 'check',
            height: 50,
            onTap: () {
              s.copyText(s.waFull);
              s.update(() => s.sheet = null);
              s.toastMsg('Message copied.');
            },
          ),
          if (ref != null) T("Change the message if you like. Your enquiry is already saved on Hostelzy, so you're covered either way.", s: 12, c: p.mu, lh: 1.45),
        ],
      ),
    );
  }
}

/// F05 board 3: one enquiry, opened from its HZ code on owner Today.
class _EnquirySheet extends StatelessWidget {
  const _EnquirySheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final e = s.enquiries.where((x) => x.ref == s.enqRef).firstOrNull;
    if (e == null) return const SizedBox();
    final first = e.name.split(' ')[0];
    final r = e.bed != null ? s.findBed(e.hid, e.bed).r : null;
    void contact(String how) {
      s.markContacted(e.ref);
      if (how == 'wa') {
        s.openWA(e.name, 'Hi $first, this is Srinivas from Anjani Residency. Got your Hostelzy enquiry (${e.ref}).');
      } else {
        s.update(() => s.sheet = null);
        s.toastMsg(how == 'call' ? 'Calling $first on +91 ${phoneSpaced(e.phone)}…' : 'Marked as contacted.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KV('Phone', '${phoneSpaced(e.phone)} · verified by OTP', keyWidth: 110),
        KV('Asked about', e.bed != null ? 'Bed ${e.bed}${r != null ? ' · ${r.share} sharing' : ''}' : 'Any bed', keyWidth: 110),
        KV('When', clockTime(e.at), keyWidth: 110),
        KV('From', e.from, keyWidth: 110),
        KV('Message', '“${e.msg}”', keyWidth: 110),
        KV('Status', e.contacted ? 'Contacted' : 'New · not replied yet', keyWidth: 110),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(12),
          color: p.sf,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Ic('userPlus', size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Rich([sp(context, 'If $first joins, add them in '), sp(context, 'Manage → Residents', w: 800), sp(context, " with this number. They'll show as "), sp(context, 'Joined via Hostelzy', w: 800), sp(context, '.')], s: 13, lh: 1.4)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(child: Cta('WhatsApp', icon: 'msg', height: 50, px: 14, fs: 15, onTap: () => contact('wa'))),
              const SizedBox(width: 8),
              Expanded(child: OutlineCta('Call', icon: 'phone', height: 50, px: 14, fs: 15, onTap: () => contact('call'))),
            ],
          ),
        ),
        if (!e.contacted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                onTap: () => contact('mark'),
                child: const SizedBox(
                  height: 44,
                  child: Center(child: T('Mark as contacted', w: 800, s: 14, underline: true)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms['anjani']!;
    final freeA = <Bed>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' || b.state == 'soon') freeA.add(b);
      }
    }
    final sel = s.addBed != null ? s.findBed('anjani', s.addBed) : null;
    final terms = hostelById('anjani').terms;
    Widget label(String t) => T(t, w: 800, s: 13);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 14,
        children: [
          VGap(
            gap: 6,
            children: [
              label('Tenant name'),
              Field(value: s.addName, onChanged: (v) => s.update(() => s.addName = v), placeholder: 'Full name'),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('WhatsApp number'),
              Field(
                value: s.addPhone,
                onChanged: (v) => s.update(() {
                  final d = v.replaceAll(RegExp(r'\D'), '');
                  s.addPhone = d.length > 10 ? d.substring(0, 10) : d;
                }),
                placeholder: '10 digits',
                numeric: true,
              ),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Bed'),
              wrap(6, [for (final b in freeA.take(12)) ChipBtn(b.id, on: b.id == s.addBed, onTap: () => s.update(() => s.addBed = b.id), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Moving in'),
              Seg(opts: same(['Today', 'Tomorrow', '5 Oct']), cur: s.addDate, onPick: (v) => s.update(() => s.addDate = v), pad: const EdgeInsets.all(10)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(top: bs(1, p.hl))),
            child: Css(
              s: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  T('Monthly rent', c: p.mu),
                  T(sel?.r != null ? fmt(sel!.r!.rent) : 'Pick a bed', w: 800),
                ],
              ),
            ),
          ),
          Css(
            s: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                T('Advance', c: p.mu),
                T('${fmt(terms.advance)} · ${fmt(terms.maintenance)} kept on exit', w: 800),
              ],
            ),
          ),
          Css(
            s: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                T('Due at move-in', c: p.mu),
                T(sel?.r != null ? fmt(terms.advance + sel!.r!.rent) : 'Pick a bed', w: 800),
              ],
            ),
          ),
          Cta(
            'Add booking',
            icon: 'check',
            height: 54,
            px: 16,
            fs: 15,
            onTap: () {
              if (s.addName.trim().isEmpty || sel == null || sel.b == null) return s.toastMsg('Add a name and pick a bed.');
              sel.b!.state = 'booked';
              final name = s.addName.trim();
              s.update(() {
                s.sheet = null;
                s.residents = [...s.residents, Resident(name: name, bed: sel.b!.id, amt: sel.r!.rent, status: 'Due', note: 'Moves in ${s.addDate}')];
                s.addName = '';
                s.addPhone = '';
                s.addBed = null;
                s.addDate = 'Today';
              });
              s.toastMsg('Booked bed ${sel.b!.id}. Welcome message sent on WhatsApp.');
            },
          ),
        ],
      ),
    );
  }
}

class _BedSheet extends StatelessWidget {
  const _BedSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final f = s.findBed('anjani', s.obed);
    if (f.b == null) return const SizedBox();
    final b = f.b!, r = f.r!;
    final res = s.residents.where((x) => x.bed == b.id).firstOrNull;
    final terms = hostelById('anjani').terms;
    final leave = leaveDates(terms).first;
    final stl = {'free': 'Free', 'soon': 'Free from ${b.soon}', 'held': 'On hold', 'booked': 'Taken'}[b.state]!;
    void done(String m) {
      s.update(() => s.sheet = null);
      s.toastMsg(m);
    }

    final actions = <(String, VoidCallback, bool)>[];
    if (b.state == 'booked') {
      actions.add((
        'Mark as leaving $leave',
        () {
          b.state = 'soon';
          b.soon = leave;
          done('Bed ${b.id} is listed as free from $leave.');
        },
        true,
      ));
      actions.add(('Message resident', () => s.openWA(res != null ? res.name : 'Resident', 'Hi, this is Srinivas from Anjani Residency.'), false));
    } else if (b.state == 'held') {
      actions.add((
        'Release hold',
        () {
          b.state = 'free';
          b.mine = false;
          done('Bed ${b.id} is free again.');
        },
        true,
      ));
    } else {
      actions.add((
        'Add booking for this bed',
        () => s.update(() {
          s.sheet = 'add';
          s.addBed = b.id;
        }),
        true,
      ));
      actions.add((
        'Hold for a walk-in',
        () {
          b.state = 'held';
          done('Bed ${b.id} held for 1 hour.');
        },
        false,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KV('Room', '${r.n} · Floor ${r.floor} · ${r.share} sharing', keyWidth: 110),
        KV('Position', b.spot, keyWidth: 110),
        KV('Rent', '${fmt(r.rent)} a month', keyWidth: 110),
        KV('Advance', '${fmt(terms.advance)} · ${fmt(terms.maintenance)} kept on exit', keyWidth: 110),
        KV('Status', stl, keyWidth: 110),
        KV(
          'Resident',
          res != null
              ? '${res.name} · rent ${res.status.toLowerCase()}'
              : b.state == 'booked'
              ? 'Offline tenant'
              : 'None',
          keyWidth: 110,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: VGap(
            gap: 8,
            children: [for (final a in actions) Cta(a.$1, height: 50, px: 16, fs: 15, onTap: a.$2, bg: a.$3 ? p.ac : transparent, fg: a.$3 ? p.ai : p.tx, border: a.$3 ? p.ac : p.tx)],
          ),
        ),
      ],
    );
  }
}
