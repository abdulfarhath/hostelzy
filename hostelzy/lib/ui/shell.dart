import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../features/amenities/amenities_screens.dart';
import '../features/explore/explore_screen.dart';
import '../features/explore/explore_sheets.dart';
import '../features/explore/hostel_screen.dart';
import '../features/fair_play/fair_play_screens.dart';
import '../features/food/food_screen.dart';
import '../features/holds/holds_screens.dart';
import '../features/holds/holds_sheets.dart';
import '../features/holds/picker_screen.dart';
import '../features/layouts/admin_layout_screen.dart';
import '../features/layouts/layout_fixes_screens.dart';
import '../features/layouts/layout_map.dart';
import '../features/layouts/owner_layout_screens.dart';
import '../features/map/map_screen.dart';
import '../features/meter/stay_tools_screens.dart';
import '../features/moves/move_screen.dart';
import '../features/moves/refunds_screens.dart';
import '../features/onboarding/add_hostel_screen.dart';
import '../features/onboarding/rooms_screens.dart';
import '../features/owner/owner_beds_screen.dart';
import '../features/owner/owner_invite_screen.dart';
import '../features/owner/owner_manage_screen.dart';
import '../features/owner/owner_rent_screen.dart';
import '../features/owner/owner_sheets.dart';
import '../features/owner/owner_today_screen.dart';
import '../features/payments/payments_sheets.dart';
import '../features/payments/rent_pay_screen.dart';
import '../features/photos/photos_screens.dart';
import '../features/plan/plan_screens.dart';
import '../features/reminders/reminders_screens.dart';
import '../features/residents/resident_screens.dart';
import '../features/residents/residents_sheets.dart';
import '../features/reviews/reviews_screens.dart';
import '../features/rewards/rewards_screens.dart';
import '../features/session/guest_screens.dart';
import '../features/session/me_screen.dart';
import '../features/session/session_screens.dart';
import '../features/session/settings_screens.dart';
import '../features/team/team_screens.dart';
import '../features/team/team_tracker_screens.dart';
import '../l10n.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

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
        child: LangScope(
          strings: s.langs[s.lang]?.strings ?? const {},
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
      ('Start', [('welcome', 'Welcome', 'tenant'), ('phone', 'Phone number', 'tenant'), ('login', 'Sign in', 'tenant'), ('role', 'Pick a role', 'tenant')]),
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
                // F24 item 17: plan, deals, rates and Fair Play are the owner's.
                Expanded(child: switch (s.ownerOnlyWhat(s.screen, s.moreTab)) {
                  final String what => OwnerOnlyScreen(what),
                  null => _screen(s.screen),
                }),
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
                  child: s.toastUndo == null
                      ? T(s.toast!, s: 14, w: 600, lh: 1.35, c: p.bg)
                      : Row(children: [Expanded(child: T(s.toast!, s: 14, w: 600, lh: 1.35, c: p.bg)), Tap(key: const ValueKey('undo'), onTap: s.undoToast, child: Padding(padding: const EdgeInsets.only(left: 12), child: T('Undo', s: 14, w: 800, c: p.bg, underline: true)))]),
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
    'where' => const WhereScreen(),
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
    'rStay' => const StayScreen(),
    'rReview' => const ResidentReviewScreen(),
    'rExit' => const ExitReviewScreen(),
    'reviews' => const ReviewsScreen(),
    'oRank' => const OwnerRankScreen(),
    'oRules' => const OwnerRulesScreen(),
    'oCase' => const OwnerCaseScreen(),
    'oStrike' => const StrikeScreen(),
    'rewards' => const RewardsScreen(),
    'moveIn' => const MoveInScreen(),
    'oPlan' => const PlanScreen(),
    'oInvoice' => const InvoiceScreen(),
    'oPayStatus' => const PayStatusScreen(),
    'compare' => const CompareScreen(),
    'oLayout' => const OwnerLayoutScreen(),
    'aLayout' => const AdminLayoutScreen(),
    'rRoom' => const ResidentRoomScreen(),
    'rFix' => const FixEditorScreen(),
    'oFix' => const OwnerFixScreen(),
    'oFixDone' => const FixDoneScreen(),
    'aAdd' => const AddHostelScreen(),
    'aPin' => const PinScreen(),
    'aTrack' => const TrackerScreen(),
    'oTeam' => const TeamScreen(),
    'settings' => const SettingsScreen(),
    'delAcc' => const DeleteAccountScreen(),
    'delConfirm' => const DeleteConfirmScreen(),
    'delDone' => const DeleteDoneScreen(),
    'perm' => const PermissionScreen(),
    'scan' => const ScanScreen(),
    'rRefund' => const ResidentRefundScreen(),
    'oMeter' => const OwnerMeterScreen(),
    'reminders' => const RemindersScreen(),
    'gate' => const GateScreen(),
    'aHome' => const TeamHomeScreen(),
    'oLayouts' => const OwnerLayoutsScreen(),
    'oRooms' => const OwnerRoomsScreen(),
    'aTeam' => const TeamMembersScreen(),
    'oToday' => const OwnerTodayScreen(),
    // F21 W4: the bed map is a floor drawing; its labels grow at most 1.3×.
    'oBeds' => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: const OwnerBedsScreen()),
    'oRent' => const OwnerRentScreen(),
    'oMore' => const OwnerManageScreen(),
    'oInvite' => const OwnerInviteScreen(),
    _ => const SizedBox(),
  };
}

const _tabs = {
  'tenant': [('explore', 'Explore', 'home'), ('map', 'Map', 'pin'), ('saved', 'Saved', 'heart'), ('holds', 'Holds', 'clock'), ('me', 'Me', 'user')],
  'resident': [('rHome', 'Home', 'home'), ('food', 'Food', 'utensils'), ('rPay', 'Pay rent', 'wallet'), ('help', 'Help', 'wrench'), ('me', 'Me', 'user')],
  'owner': [('oToday', 'Today', 'chart'), ('oBeds', 'Beds', 'bed'), ('*', 'Add tenant', 'userPlus'), ('oRent', 'Rent', 'wallet'), ('oMore', 'Manage', 'inbox')],
};

void _openTab(AppState s, String k) {
  // F21 W3: Manage opens on its list.
  if (k == 'oMore') s.moreTab = 'home';
  if (k != '*') return s.tab(k);
  // F25: the "+" tab opens the one "Add a resident" sheet.
  s.openAddResident();
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
              final center = t.$1 == '*', act = s.screen == t.$1;
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
              final center = t.$1 == '*', act = s.screen == t.$1;
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
      'amFloor' => 'On ${s.floorName(s.amFloor).toLowerCase()}',
      'foodWeek' => 'Food menu',
      'amAdd' => s.amDraft?.id == 'new' ? 'Add to ${s.floorName(s.amFloor).toLowerCase()}' : 'Change ${s.amDraft?.label ?? ''}',
      'cPhoto' => 'Photo',
      'lang' => 'Language',
      'search' => s.filterCount > 0 ? 'Filters · ${s.filterCount}' : 'Filters',
      'holdNotify' => 'Bed ${s.holds.where((h) => h.id == s.holdId).firstOrNull?.bed ?? ''} is held for you',
      'loc' => 'Use your location?',
      'scanCam' => 'Use your camera?',
      'hold' => sb?.b != null ? 'Bed ${sb!.b!.id}' : 'Pick a bed',
      'signIn' => switch (s.afterSignIn) {
        'enquiry' => 'Sign in to message ${hostelById(s.hid).owner}',
        'book' => 'Sign in to book this bed',
        _ => 'Sign in to hold this bed',
      },
      'wa' => 'Ask ${s.waTo ?? 'the owner'}',
      'addR' => 'Add a resident',
      'rank' => 'How the ranking works',
      'revReport' => 'Report this review',
      'report' => 'Tell us what happened',
      'trusted' => '${allRequests(s).where((r) => r.id == s.trustedReq && r.name != 'Hostelzy tenant').firstOrNull?.name ?? 'This tenant'} is a Trusted tenant',
      'bed' => 'Bed ${s.obed ?? ''}',
      'utr' => 'I’ve paid ${fmt(s.invoiceAmt)}',
      'layoutReq' => 'Ask Hostelzy to draw it',
      'switch' => 'Switch hostel',
      'team' => 'Hostelzy team',
      'addRoom' => 'Add a room',
      'payAdv' => 'Pay the advance',
      'payUtr' => 'Enter the UPI reference',
      'manager' => 'Add a manager',
      'name' => 'Change your name',
      'waNum' => 'Your WhatsApp number',
      'photo' => 'This photo',
      'fixLock' => s.fixTry ? 'Publish' : 'Fix this room?',
      'fixLimit' => 'Can’t send yet',
      'fixSend' => 'Send your fix',
      'fixReject' => 'Reject this fix?',
      'quickFix' => s.qfItem,
      'fixMute' => 'Mute ${s.openFixItem?.author ?? 'this resident'}?',
      'water' => 'Drink water',
      'addRem' => s.remEdit == null ? 'Add a reminder' : 'Edit reminder',
      'waterOffer' => 'Want water reminders?',
      'refund' => refundSheetTitle(s.refundOpen),
      'laundry' => 'Laundry day',
      'perks' => s.level == 'trusted' ? 'You’re a Trusted tenant' : 'What Trusted tenants get',
      _ => '',
    };
    final enq = s.sheet == 'enq' ? s.enquiries.where((e) => e.ref == s.enqRef).firstOrNull : null;
    final kicker = switch (s.sheet) {
      'loc' => 'Map',
      'scanCam' => 'Join your PG',
      'wa' when s.waHid != null && s.waRef != null => hostelById(s.waHid!).name,
      'utr' => 'Invoice ${s.invoice.ref}',
      'layoutReq' => 'Room ${s.lRoom} · ${s.lReqShape == 'Custom' ? 'Custom shape' : s.lReqShape}',
      'switch' => 'Your hostels',
      'payAdv' => 'Book bed ${s.pay?.bed ?? ''} · deal ${s.pay?.note ?? ''}',
      'payUtr' => '${s.pay?.what ?? ''} · ${fmt(s.pay?.amt ?? 0)} to ${s.pay != null ? hostelById(s.pay!.hid).owner : ''}',
      'manager' => '${hostelById(s.ownHid).name} · team',
      'name' => 'Settings',
      'waNum' => 'Settings',
      'quickFix' => 'Quick fix · Room ${s.fixRoom}',
      'fixMute' => 'Layout fixes',
      'report' => s.endedHold != null || AppState.samples ? '${hostelById(s.endedHold?.hid ?? 'anjani').name} · private' : 'Private',
      'water' => 'Reminders',
      'hold' => hostelById(s.hid).name,
      'signIn' => s.afterSignIn == 'enquiry' ? hostelById(s.hid).name : sb?.b != null ? 'Bed ${sb!.b!.id} · ${s.afterSignIn == 'book' ? 'pay the advance to book' : 'free ${s.isMember ? '2-hour' : '1-hour'} hold'}' : null,
      'holdNotify' => () {
        final h = s.holds.where((h) => h.id == s.holdId).firstOrNull;
        return h == null ? null : 'Held · ${cd(s.holdSecsOf(h) - (s.now - h.start) / 1000)} left';
      }(),
      'addRem' => 'My reminders',
      'revReport' => '${s.reviews.where((r) => r.id == s.revReportFor).firstOrNull?.name ?? 'A resident'}’s review',
      'waterOffer' => 'New in Hostelzy · stay on track',
      'trusted' => 'Hold request · bed ${allRequests(s).where((r) => r.id == s.trustedReq).firstOrNull?.bed ?? ''}',
      'fixLock' || 'fixLimit' || 'fixSend' => 'Room ${s.fixRoom}',
      'fixReject' => 'Room ${s.openFixItem?.room ?? ''} · ${s.openFixItem?.author ?? ''}',
      'amFloor' => hostelById(s.amHid).name,
      'foodWeek' => hostelById(s.foodFor ?? s.hid).name,
      'amAdd' => 'Shared things',
      'refund' => refundSheetKicker(s.refundOpen),
      'laundry' => 'House rules',
      'perks' => 'Stay Rewards',
      _ => null,
    };
    final body = switch (s.sheet) {
      'search' => const SearchSheet(),
      'holdNotify' => const HoldNotifySheet(),
      'lang' => const LangSheet(),
      'cPhoto' => s.complaintPhotosLocal[s.cPhotoView] == null ? const SizedBox() : Padding(padding: const EdgeInsets.all(16), child: Image.memory(s.complaintPhotosLocal[s.cPhotoView]!, fit: BoxFit.contain)),
      'signIn' => const SignInSheet(),
      'loc' => const LocationSheet(),
      'scanCam' => const CameraSheet(),
      'hold' => const HoldSheet(),
      'wa' => const WaSheet(),
      'bed' => const BedSheet(),
      'enq' => const EnquirySheet(),
      'addR' => const AddResidentSheet(),
      'rank' => const RankSheet(),
      'revReport' => const ReviewReportSheet(),
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
      'name' => const NameSheet(),
      'waNum' => const WaNumberSheet(),
      'photo' => const PhotoSheet(),
      'fixLock' => const FixLockSheet(),
      'fixLimit' => const FixLimitSheet(),
      'fixSend' => const FixSendSheet(),
      'fixReject' => const FixRejectSheet(),
      'quickFix' => const QuickFixSheet(),
      'fixMute' => const FixMuteSheet(),
      'water' => const WaterSheet(),
      'addRem' => const AddReminderSheet(),
      'waterOffer' => const WaterOfferSheet(),
      'amFloor' => const AmenityFloorSheet(),
      'foodWeek' => const FoodWeekSheet(),
      'amAdd' => const AmenityAddSheet(),
      'refund' => const RefundSheet(),
      'laundry' => const LaundrySheet(),
      'perks' => const PerksSheet(),
      _ => const SizedBox(),
    };
    void close() => s.update(() {
      // F21 W2: closing "Sign in to hold" drops the hold it was for.
      if (s.sheet == 'signIn') s.afterSignIn = null;
      s.sheet = null;
    });
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
                                  key: const ValueKey('sheetClose'),
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
