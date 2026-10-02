import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'fairplay.dart';
import 'kit.dart';
import 'photos.dart';
import 'layout.dart';
import 'map.dart';
import 'onboarding.dart';
import 'payments.dart';
import 'settings.dart';
import 'team.dart';
import 'rooms.dart';
import 'plan.dart';
import 'reviews.dart';
import 'rewards.dart';
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

  /// The clickable prototype (phone frame, jump list, fake status bar) is
  /// for development only; the Play Store build uses [_Wide] (F17 board 11).
  static bool prototypeFrame = kDebugMode;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // F15: Phone setting follows the phone's light / dark mode.
    final pal = s.isDark(MediaQuery.platformBrightnessOf(context)) ? Pal.dark : Pal.light;
    // F18: Android back steps through the app instead of closing it.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s.handleBack()) SystemNavigator.pop();
      },
      child: PalScope(
        pal: pal,
        child: DefaultTextStyle(
          style: rootTextStyle(pal),
          child: LayoutBuilder(
            builder: (context, c) {
              if (bare) return const PhoneFrame();
              if (c.maxWidth >= 730) return prototypeFrame ? _Desk(onOpenOverview: onOpenOverview) : _Wide(width: c.maxWidth);
              return const _FullScreen();
            },
          ),
        ),
      ),
    );
  }
}

/// Tablets and desktop: the app in a column, the map beside it for tenants.
class _Wide extends StatelessWidget {
  const _Wide({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final map = s.role == 'tenant' && width >= 1000;
    final rail = AppState.tabScreens.contains(s.screen);
    return ColoredBox(
      color: p.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rail) const _Rail(),
          Container(width: 440, decoration: BoxDecoration(border: Border(right: bs(2, p.tx))), child: const _FullScreen(rail: true)),
          Expanded(
            child: map
                ? const MapScreen()
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [const BrandMark(size: 72), const SizedBox(height: 12), const T('hostelzy', w: 800, s: 32, ls: -.02), const SizedBox(height: 4), T('PGs and hostels in Hyderabad', s: 14, c: p.mu)],
                    ),
                  ),
          ),
        ],
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
          const Row(children: [BrandMark(size: 22), SizedBox(width: 7), T('hostelzy', w: 800, s: 26, ls: -.02)]),
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
  const _FullScreen({this.rail = false});

  /// On wide screens the tabs live in [_Rail] instead of the bottom bar.
  final bool rail;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final mq = MediaQuery.of(context);
    final onWelcome = s.screen == 'welcome';
    final sbBg = onWelcome ? p.ac : p.bg;
    final dark = s.isDark(MediaQuery.platformBrightnessOf(context));
    // Light status-bar icons on the red welcome screen and in dark theme.
    final lightIcons = onWelcome ? !dark : dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: transparent, systemNavigationBarColor: sbBg),
      child: Container(
        color: p.bg,
        child: _AppBody(
          top: Container(height: mq.padding.top, color: sbBg),
          // F18: the keyboard pushes the screen up instead of covering inputs.
          bottom: Container(height: mq.viewInsets.bottom > mq.padding.bottom ? mq.viewInsets.bottom : mq.padding.bottom, color: sbBg),
          toastBottom: (rail ? 12 : 76) + mq.padding.bottom,
          tabs: !rail,
        ),
      ),
    );
  }
}

/// Screen + tabs + sheets + toast, between a top and bottom inset.
class _AppBody extends StatelessWidget {
  const _AppBody({required this.top, required this.bottom, required this.toastBottom, this.tabs = true});
  final Widget top, bottom;
  final double toastBottom;
  final bool tabs;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final showTabs = tabs && AppState.tabScreens.contains(s.screen) && MediaQuery.viewInsetsOf(context).bottom == 0;
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
                // F18 design "Demo": the Play Store build says when it's on sample listings.
                if (AppState.demoBanner && !liveListings && !const ['welcome', 'login', 'phone', 'otp', 'role', 'roleGate', 'gate'].contains(s.screen))
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: p.tx,
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), color: p.ac, child: T('DEMO', w: 800, s: 12, c: p.ai)),
                        const SizedBox(width: 8),
                        Expanded(child: T('Sample data. Nothing you do here is real.', w: 800, s: 12, c: p.bg)),
                      ],
                    ),
                  ),
                Expanded(child: _screen(s.screen)),
                if (showTabs) const _TabBar(),
                bottom,
              ],
            ),
            // F18: sheets sit above the keyboard.
            if (s.sheet != null) Positioned(left: 0, top: 0, right: 0, bottom: MediaQuery.viewInsetsOf(context).bottom, child: const _Sheet()),
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
    'login' => const LoginScreen(),
    'saved' => const SavedScreen(),
    'roleGate' => const RoleGateScreen(),
    'oCreate' => const CreateLayoutScreen(),
    'oPublished' => const LayoutPublishedScreen(),
    'phone' => const PhoneScreen(),
    'otp' => const OtpScreen(),
    'role' => const RoleScreen(),
    'explore' => const ExploreScreen(),
    'map' => const MapScreen(),
    'holds' => const HoldsScreen(),
    'me' => const MeScreen(),
    'detail' => const DetailScreen(),
    'oPhotos' => const OwnerPhotosScreen(),
    'oCrop' => const CropScreen(),
    'gallery' => const GalleryScreen(),
    'picker' => const PickerScreen(),
    'hold' => const HoldScreen(),
    'rHome' => const ResidentHomeScreen(),
    'rPay' => const RentPayScreen(),
    'food' => const FoodScreen(),
    'help' => const HelpScreen(),
    'move' => const MoveScreen(),
    'rConfirm' => const ConfirmStayScreen(),
    'rReview' => const ResidentReviewScreen(),
    'rExit' => const ExitReviewScreen(),
    'reviews' => const ReviewsScreen(),
    'oReviews' => const OwnerReviewsScreen(),
    'oRank' => const OwnerRankScreen(),
    'oRules' => const OwnerRulesScreen(),
    'oCase' => const OwnerCaseScreen(),
    'oStrike' => const StrikeScreen(),
    'aCases' => const AdminCasesScreen(),
    'rewards' => const RewardsScreen(),
    'moveIn' => const MoveInScreen(),
    'oPlan' => const PlanScreen(),
    'oInvoice' => const InvoiceScreen(),
    'oPayStatus' => const PayStatusScreen(),
    'aPay' => const AdminPaymentsScreen(),
    'compare' => const CompareScreen(),
    'oLayout' => const OwnerLayoutScreen(),
    'aLayout' => const AdminLayoutScreen(),
    'aAdd' => const AddHostelScreen(),
    'aTrack' => const TrackerScreen(),
    'oTeam' => const TeamScreen(),
    'settings' => const SettingsScreen(),
    'delAcc' => const DeleteAccountScreen(),
    'delOtp' => const DeleteOtpScreen(),
    'delDone' => const DeleteDoneScreen(),
    'perm' => const PermissionScreen(),
    'gate' => const GateScreen(),
    'aHome' => const TeamHomeScreen(),
    'oLayouts' => const OwnerLayoutsScreen(),
    'oRooms' => const OwnerRoomsScreen(),
    'aTeam' => const TeamMembersScreen(),
    'oToday' => const OwnerTodayScreen(),
    'oBeds' => const OwnerBedsScreen(),
    'oRent' => const OwnerRentScreen(),
    'oMore' => const OwnerManageScreen(),
    'oInvite' => const OwnerInviteScreen(),
    _ => const SizedBox(),
  };
}

const _tabs = {
  'tenant': [('explore', 'Explore', 'home'), ('map', 'Map', 'pin'), ('*', 'Search', 'search'), ('holds', 'Holds', 'clock'), ('me', 'Me', 'user')],
  'resident': [('rHome', 'Home', 'home'), ('food', 'Food', 'utensils'), ('rPay', 'Pay rent', 'wallet'), ('help', 'Help', 'wrench'), ('me', 'Me', 'user')],
  'owner': [('oToday', 'Today', 'chart'), ('oBeds', 'Beds', 'bed'), ('*', 'Booking', 'plus'), ('oRent', 'Rent', 'wallet'), ('oMore', 'Manage', 'inbox')],
};

void _openTab(AppState s, String k) {
  if (k != '*') return s.tab(k);
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
}

/// F17 board 11: tablets and desktop get the tabs as a left rail.
class _Rail extends StatelessWidget {
  const _Rail();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = _tabs[s.role]!;
    return Container(
      width: 96,
      decoration: BoxDecoration(color: p.bg, border: Border(right: bs(2, p.tx))),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 40)),
          const SizedBox(height: 20),
          for (var i = 0; i < list.length; i++)
            () {
              final t = list[i];
              final center = i == 2, act = s.screen == t.$1;
              return Tap(
                key: ValueKey('rail-${t.$1 == '*' ? 'action' : t.$1}'),
                onTap: () => _openTab(s, t.$1),
                child: InsetBar(
                  edge: Edge.left,
                  size: !center && act ? 3 : 0,
                  color: p.ac,
                  bg: center ? p.ac : null,
                  child: SizedBox(
                    height: 72,
                    child: Css(
                      c: center ? p.ai : act ? p.tx : p.mu,
                      s: 11,
                      w: 600,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Ic(t.$3, size: 22), const SizedBox(height: 6), T(t.$2, nowrap: true)]),
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

class _TabBar extends StatelessWidget {
  const _TabBar();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final list = _tabs[s.role]!;
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
                  onTap: () => _openTab(s, t.$1),
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
      'loc' => 'Use your location?',
      'areas' => 'Pick an area',
      'hold' => sb?.b != null ? 'Book bed ${sb!.b!.id}' : 'Book',
      'wa' => s.waRef != null ? 'Ask ${s.waTo} on WhatsApp' : 'Continue on WhatsApp',
      'add' => 'Add a booking',
      'addR' => 'Add a resident',
      'rank' => 'How the ranking works',
      'joined' => 'Did you join Anjani Residency?',
      'report' => 'Tell us what happened',
      'trusted' => '${s.reqs.where((r) => r.id == s.trustedReq).firstOrNull?.name ?? 'This tenant'} is a Trusted tenant',
      'bed' => 'Bed ${s.obed ?? ''}',
      'utr' => 'I’ve paid ${fmt(s.invoiceAmt)}',
      'layoutReq' => 'Request a change',
      'switch' => 'Switch hostel',
      'team' => 'Hostelzy team',
      'addRoom' => 'Add a room',
      'payAdv' => 'Pay the advance',
      'payUtr' => 'Enter the UTR',
      'manager' => 'Add a manager',
      'photo' => 'This photo',
      _ => '',
    };
    final enq = s.sheet == 'enq' ? s.enquiries.where((e) => e.ref == s.enqRef).firstOrNull : null;
    final kicker = switch (s.sheet) {
      'loc' || 'areas' => 'Map',
      'joined' => 'One quick question',
      'wa' when s.waHid != null && s.waRef != null => hostelById(s.waHid!).name,
      'utr' => 'Invoice ${s.invoice.ref}',
      'layoutReq' => 'Room ${s.lRoom}',
      'switch' => 'Your hostels',
      'payAdv' => 'Book bed ${s.pay?.bed ?? ''} · deal ${s.pay?.note ?? ''}',
      'payUtr' => '${s.pay?.what ?? ''} · ${fmt(s.pay?.amt ?? 0)} to ${s.pay != null ? hostelById(s.pay!.hid).owner : ''}',
      'manager' => '${hostelById(s.ownHid).name} · team',
      'report' => 'Anjani Residency · private',
      'trusted' => 'Hold request · bed ${s.reqs.where((r) => r.id == s.trustedReq).firstOrNull?.bed ?? ''}',
      _ => null,
    };
    final body = switch (s.sheet) {
      'search' => const _SearchSheet(),
      'loc' => const LocationSheet(),
      'areas' => const AreasSheet(),
      'hold' => const _HoldSheet(),
      'wa' => const _WaSheet(),
      'add' => const _AddSheet(),
      'bed' => const _BedSheet(),
      'enq' => const _EnquirySheet(),
      'addR' => const _AddResidentSheet(),
      'rank' => const RankSheet(),
      'joined' => const JoinedSheet(),
      'report' => const ReportSheet(),
      'trusted' => const TrustedSheet(),
      'utr' => const UtrSheet(),
      'layoutReq' => const LayoutRequestSheet(),
      'switch' => const SwitchSheet(),
      'team' => const TeamSheet(),
      'addRoom' => const AddRoomSheet(),
      'payAdv' => const PayAdvSheet(),
      'payUtr' => const PayUtrSheet(),
      'manager' => const ManagerSheet(),
      'photo' => const PhotoSheet(),
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
                                      : kicker != null
                                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Kicker(kicker), const SizedBox(height: 2), T(title, w: 800, s: 20)])
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
          group('Room', Seg(opts: same(['Any', 'AC', 'Non-AC']), cur: s.fR, onPick: (v) => s.update(() => s.fR = v), pad: segPad)),
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

/// F04 board 3: book by paying the advance straight to the owner (deal
/// locked, HZ code), or hold free for an hour.
class _HoldSheet extends StatelessWidget {
  const _HoldSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final sb = s.bed != null ? s.findBed(s.hid, s.bed) : null;
    if (sb?.b == null) return const SizedBox();
    final b = sb!.b!, r = sb.r!;
    final q = s.quote(h.id, r.ac, r.share);
    final perks = s.lockedPerks(q, h);
    Widget line(String k, Widget v, {Color? bg, Color? fg}) => Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: null,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [T(k, s: 14, c: fg ?? p.mu), v]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: T('${h.name} · Room ${r.n} · ${r.share} sharing${h.ac ? ' · ${r.type}' : ''} · ${b.spot}', s: 13, c: p.mu),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: box(w: 2, c: p.tx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: const Kicker('Pay the owner to book'),
              ),
              Container(
                decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                child: line('Advance (refundable)', T(fmt(q.hzAdv), s: 14, w: 800)),
              ),
              Container(
                color: p.tx,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [T('Pay ${h.owner} today', w: 800, s: 15, c: p.bg), T(fmt(q.hzAdv), w: 800, s: 26, c: p.bg)],
                ),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(12, 10, 12, 4), child: Kicker('Pay at the hostel on move-in')),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    T('First month fee', s: 14, c: p.mu),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (q.hzFirst < q.fee) ...[
                          Text(fmt(q.fee), style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12, color: p.mu, decoration: TextDecoration.lineThrough, decorationColor: p.mu)),
                          const SizedBox(width: 4),
                        ],
                        T(fmt(q.hzFirst), s: 14, w: 800),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          color: q.any ? p.gb : p.sf,
          child: q.any
              ? VGap(
                  gap: 8,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [T('Your deal is locked', w: 800, s: 15, c: p.gn), T(s.peekRef, s: 12, w: 800, ls: .04, c: p.gn)],
                    ),
                    LayoutBuilder(
                      builder: (context, c) => Wrap(
                        runSpacing: 6,
                        children: [
                          for (final k in perks)
                            SizedBox(
                              width: c.maxWidth / 2,
                              child: Row(children: [Ic('check', size: 14, color: p.gn), const SizedBox(width: 6), Flexible(child: T(k, s: 13))]),
                            ),
                        ],
                      ),
                    ),
                    T('Show this code at the hostel. The owner sees the same deal in their app.', s: 12, c: p.mu, lh: 1.4),
                  ],
                )
              : T('No Hostelzy deal on this room type. Exit rules are still locked: ${fmt(q.hzExit)} maintenance, ${h.terms.noticeDays} days notice.', s: 13, c: p.mu, lh: 1.4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [T('Back when you leave', s: 13, c: p.mu), Rich([sp(context, fmt(q.hzBack), w: 800), sp(context, ' of your ${fmt(q.hzAdv)}', c: p.mu)], s: 13)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(child: Cta('Pay advance', height: 56, px: 14, fs: 15, onTap: () => s.placeHold('book'))),
              const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: () => s.placeHold('free'),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: box(w: 2, c: p.tx),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const T('Hold free', w: 800, s: 15), T(s.isMember ? '2 hours · Member perk' : '1 hour · 2 h for Members', s: 11, w: 600, c: p.mu)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: T('You pay ${fmt(q.hzAdv)} by UPI straight to ${h.owner}. Hostelzy never holds your money; we keep the record and your deal.', s: 12, c: p.mu, lh: 1.4),
        ),
      ],
    );
  }
}

class _WaSheet extends StatelessWidget {
  const _WaSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final ref = s.waRef;
    final to = s.waTo ?? '';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          // F17: honest. Nothing tells the owner except the tenant's own message.
          if (ref != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: p.sf,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: Ic('msg', size: 20, color: p.tx)),
                  const SizedBox(width: 10),
                  Expanded(child: Rich([sp(context, 'Send this on WhatsApp', w: 800, c: p.tx), sp(context, ' so $to knows you came from Hostelzy. Your enquiry code is '), sp(context, ref, w: 800, c: p.tx), sp(context, '.')], s: 14, lh: 1.45)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            color: p.sf,
            child: VGap(
              gap: 10,
              children: [
                T(s.waMsg ?? '', s: 15, lh: 1.45),
                if (ref != null) Rich([sp(context, 'Ref '), sp(context, ref, w: 800)], s: 14, lh: 1.45),
              ],
            ),
          ),
          Cta(
            'Send on WhatsApp',
            icon: 'msg',
            height: 54,
            px: 16,
            fs: 15,
            bg: p.tx,
            fg: p.bg,
            onTap: () {
              final text = s.waFull, phone = s.waPhone;
              s.update(() => s.sheet = null);
              s.whatsapp(phone, text);
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
          T('Nothing is sent until you press send in WhatsApp.', s: 12, c: p.mu, lh: 1.45),
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
        s.openWA(e.name, 'Hi $first, this is ${hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}. Got your Hostelzy enquiry (${e.ref}).', phone: e.phone);
      } else {
        s.update(() => s.sheet = null);
        how == 'call' ? s.call(e.phone) : s.toastMsg('Marked as contacted.');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KV('Phone', '${phoneSpaced(e.phone)} · not verified', keyWidth: 110),
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

/// F06 board 5: the owner adds a resident; the number is matched live
/// against Hostelzy enquiries, holds and bookings.
class _AddResidentSheet extends StatelessWidget {
  const _AddResidentSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final missing = s.unassignedBeds;
    final free = <String>[
      for (final r in s.rooms['anjani']!)
        for (final b in r.beds)
          if (b.state == 'free' && !b.mine) b.id,
    ];
    final m = s.matchFor(s.rPhone, s.rJoinAt);
    final who = s.rName.trim().isEmpty ? 'They get' : '${s.rName.trim().split(' ')[0]} gets';
    Widget label(String t) => T(t, w: 800, s: 13);
    Widget field(String l, String v, ValueChanged<String> on, {String? ph, bool numeric = false}) => VGap(
      gap: 6,
      children: [label(l), Field(value: v, onChanged: on, placeholder: ph, numeric: numeric)],
    );
    String digits(String v, int n) {
      final d = v.replaceAll(RegExp(r'\D'), '');
      return d.length > n ? d.substring(0, n) : d;
    }

    Widget bedChip(String id, bool flagged) {
      final on = id == s.rBed;
      return Tap(
        onTap: () => s.pickResidentBed(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: box(bg: on ? (flagged ? p.ab : p.tx) : transparent, w: 1, c: flagged ? p.ac : (on ? p.tx : p.dv)),
          child: T(flagged ? '$id · no resident' : id, s: 13, w: 600, c: flagged ? p.ad : (on ? p.bg : p.tx)),
        ),
      );
    }

    final past = [for (var i = 2; i <= 7; i++) i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          field('Name', s.rName, (v) => s.update(() => s.rName = v), ph: 'Full name'),
          field('WhatsApp number', s.rPhone, (v) => s.update(() => s.rPhone = digits(v, 10)), ph: '10 digits', numeric: true),
          if (s.rPhone.length == 10)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              color: p.sf,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Ic('shield', size: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Rich(
                      m != null
                          ? [sp(context, 'Joined via Hostelzy.', w: 800), sp(context, ' This number ${m.what} on Hostelzy ${s.now - m.at < 86400000 ? 'today' : 'on ${dayMon(DateTime.fromMillisecondsSinceEpoch(m.at))}'} (${m.ref}).')]
                          : [sp(context, 'Direct.', w: 800), sp(context, ' No Hostelzy enquiry, hold or booking from this number in the last $matchWindowDays days.')],
                      s: 13,
                      lh: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          VGap(
            gap: 6,
            children: [
              label('Bed'),
              wrap(6, [for (final id in missing) bedChip(id, true), for (final id in free.take(8)) bedChip(id, false)]),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Joined on'),
              Seg(opts: same(['Today', 'Yesterday', 'Pick date']), cur: s.rJoin, onPick: (v) => s.update(() => s.rJoin = v), pad: const EdgeInsets.all(10)),
              if (s.rJoin == 'Pick date') wrap(6, [for (final d in past) ChipBtn(dayMon(appToday.subtract(Duration(days: d))), on: s.rPickBack == d, onTap: () => s.update(() => s.rPickBack = d), pad: const EdgeInsets.symmetric(vertical: 8, horizontal: 10))]),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field('Monthly fee', s.rFee.isEmpty ? '' : fmt(int.parse(s.rFee)), (v) => s.update(() => s.rFee = digits(v, 6)), ph: '₹', numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: field('Advance paid', s.rAdv.isEmpty ? '' : fmt(int.parse(s.rAdv)), (v) => s.update(() => s.rAdv = digits(v, 6)), ph: '₹', numeric: true)),
            ],
          ),
          T('$who a WhatsApp code to confirm. They count as a resident once they confirm.', s: 12, c: p.mu, lh: 1.4),
          Cta('Add and send code', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.addResident),
        ],
      ),
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
              Seg(opts: same(['Today', 'Tomorrow', dayMon(appToday.add(const Duration(days: 4)))]), cur: s.addDate, onPick: (v) => s.update(() => s.addDate = v), pad: const EdgeInsets.all(10)),
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
              // F18 (F10): a real name, a real mobile number and a free bed.
              if (s.addName.trim().length < 2) return s.toastMsg('Add the tenant’s name.');
              if (s.addPhone.isNotEmpty && !AppState.validPhone(s.addPhone)) return s.toastMsg('That mobile number doesn’t look right (10 digits, 6–9 first).');
              if (sel == null || sel.b == null) return s.toastMsg('Pick a bed.');
              if (sel.b!.state == 'booked') return s.toastMsg('Bed ${sel.b!.id} is already taken.');
              sel.b!.state = 'booked';
              final name = s.addName.trim();
              s.update(() {
                s.sheet = null;
                final m = s.matchFor(s.addPhone, s.now);
                // F06: a new booking waits for the tenant's WhatsApp code like any added resident.
                s.residents = [...s.residents, Resident(name: name, bed: sel.b!.id, amt: sel.r!.rent, status: 'Due', note: 'Moves in ${s.addDate}', phone: s.addPhone, via: m != null ? 'hz' : 'direct', since: 'Added today', ref: m != null && m.ref.startsWith('HZ-') ? m.ref : null, confirmed: false)];
                s.addName = '';
                s.addPhone = '';
                s.addBed = null;
                s.addDate = 'Today';
              });
              s.toastMsg('Booked bed ${sel.b!.id}. Send them a welcome on WhatsApp.');
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
    final f = s.findBed(s.ownHid, s.obed);
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
      actions.add(('Message resident', () => s.openWA(res != null ? res.name : 'Resident', 'Hi, this is ${s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}.'), false));
    } else if (b.state == 'held') {
      actions.add((
        'Release hold',
        () {
          s.ownerReleaseBed(s.ownHid, b);
          done('Bed ${b.id} is ${b.state == 'soon' ? 'free soon' : 'free'} again.');
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
          s.holdWalkIn(s.ownHid, b);
          done('Bed ${b.id} held for 1 hour. It frees itself after that.');
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
