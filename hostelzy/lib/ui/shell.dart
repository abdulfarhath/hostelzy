import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../state.dart';
import 'amenities.dart';
import 'refunds.dart';
import 'common.dart';
import 'fairplay.dart';
import 'guest.dart';
import '../l10n.dart';
import 'kit.dart';
import 'photos.dart';
import 'layout.dart';
import 'layout_fixes.dart';
import 'map.dart';
import 'onboarding.dart';
import 'payments.dart';
import 'reminders.dart';
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
import 'stay_tools.dart';

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
    'rRoom' => const ResidentRoomScreen(),
    'rFix' => const FixEditorScreen(),
    'oFix' => const OwnerFixScreen(),
    'oFixDone' => const FixDoneScreen(),
    'aAdd' => const AddHostelScreen(),
    'aTrack' => const TrackerScreen(),
    'oTeam' => const TeamScreen(),
    'settings' => const SettingsScreen(),
    'delAcc' => const DeleteAccountScreen(),
    'delConfirm' => const DeleteConfirmScreen(),
    'delDone' => const DeleteDoneScreen(),
    'perm' => const PermissionScreen(),
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
  s.update(() {
    s.sheet = 'add';
    s.addName = '';
    s.addPhone = '';
    s.addBed = null;
    s.addDate = 'Today';
  });
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
      'hold' => sb?.b != null ? 'Bed ${sb!.b!.id}' : 'Pick a bed',
      'signIn' => switch (s.afterSignIn) {
        'enquiry' => 'Sign in to message ${hostelById(s.hid).owner}',
        'book' => 'Sign in to book this bed',
        _ => 'Sign in to hold this bed',
      },
      'wa' => 'Ask ${s.waTo ?? 'the owner'}',
      'add' => 'Add tenant',
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
      'photo' => 'This photo',
      'fixLock' => 'Fix this room?',
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
      'wa' when s.waHid != null && s.waRef != null => hostelById(s.waHid!).name,
      'utr' => 'Invoice ${s.invoice.ref}',
      'layoutReq' => 'Room ${s.lRoom} · ${s.lReqShape == 'Custom' ? 'Custom shape' : s.lReqShape}',
      'switch' => 'Your hostels',
      'payAdv' => 'Book bed ${s.pay?.bed ?? ''} · deal ${s.pay?.note ?? ''}',
      'payUtr' => '${s.pay?.what ?? ''} · ${fmt(s.pay?.amt ?? 0)} to ${s.pay != null ? hostelById(s.pay!.hid).owner : ''}',
      'manager' => '${hostelById(s.ownHid).name} · team',
      'name' => 'Settings',
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
      'search' => const _SearchSheet(),
      'holdNotify' => const HoldNotifySheet(),
      'lang' => const LangSheet(),
      'cPhoto' => s.complaintPhotosLocal[s.cPhotoView] == null ? const SizedBox() : Padding(padding: const EdgeInsets.all(16), child: Image.memory(s.complaintPhotosLocal[s.cPhotoView]!, fit: BoxFit.contain)),
      'signIn' => const SignInSheet(),
      'loc' => const LocationSheet(),
      'hold' => const _HoldSheet(),
      'wa' => const _WaSheet(),
      'add' => const _AddSheet(),
      'bed' => const _BedSheet(),
      'enq' => const _EnquirySheet(),
      'addR' => const _AddResidentSheet(),
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

class _SearchSheet extends StatelessWidget {
  const _SearchSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final count = filtered(s).length;
    // F21 W2: Filters sheet. Sort lives here; same labels as the Explore chips.
    Widget group(String label, Widget child) => VGap(gap: 8, children: [T(label, w: 800, s: 15), child]);
    const segPad = EdgeInsets.symmetric(vertical: 11, horizontal: 6);
    const chipPad = EdgeInsets.symmetric(vertical: 10, horizontal: 12);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 18,
        children: [
          group('Sort by', Seg(opts: const [('rec', 'Recommended'), ('near', 'Nearest'), ('price', 'Lowest price')], cur: s.sortBy, onPick: (v) => s.update(() => s.sortBy = v), pad: segPad, center: true, byLabel: true)),
          group('For', Seg(opts: const [('Any', 'Anyone'), ('Men', 'Men'), ('Women', 'Women'), ('Co-living', 'Co-living')], cur: s.fG, onPick: (v) => s.update(() => s.fG = v), pad: segPad, center: true)),
          group(
            'Room',
            wrap(6, [
              for (final n in ['2', '3', '4']) ChipBtn('$n sharing', on: s.fS == n, pad: chipPad, onTap: () => s.update(() => s.fS = s.fS == n ? 'Any' : n)),
              for (final r in ['AC', 'Non-AC']) ChipBtn(r, on: s.fR == r, pad: chipPad, onTap: () => s.update(() => s.fR = s.fR == r ? 'Any' : r)),
            ]),
          ),
          group(
            'Budget',
            wrap(6, [
              for (final (k, l) in const [('Any', 'Any'), ('6k', 'Under ₹6,000'), ('8k', 'Under ₹8,000'), ('10k', 'Under ₹10,000')]) ChipBtn(l, on: s.fB == k, pad: chipPad, onTap: () => s.update(() => s.fB = k)),
            ]),
          ),
          group('Deals', wrap(6, [ChipBtn('Hostelzy deals only', on: s.fDeals, pad: chipPad, onTap: () => s.update(() => s.fDeals = !s.fDeals))])),
          // F23: things on the floor (working), and a geyser in the room's washroom.
          group('On the floor', wrap(6, [
            for (final k in const [('washer', 'Washing machine'), ('fridge', 'Fridge'), ('ro', 'RO water'), ('geyser', 'Geyser in my washroom')])
              ChipBtn(k.$2, key: ValueKey('fAm-${k.$1}'), on: s.fAm.contains(k.$1), pad: chipPad, onTap: () => s.update(() => s.fAm = s.fAm.contains(k.$1) ? (Set.of(s.fAm)..remove(k.$1)) : {...s.fAm, k.$1})),
          ])),
          Tap(
            key: const ValueKey('foodToggle'),
            onTap: () => s.update(() => s.fFood = !s.fFood),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const T('Food included', s: 15, w: 800),
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
          Row(
            children: [
              Tap(key: const ValueKey('clearAll'), onTap: s.clearFilters, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4), child: T('Clear all', w: 800, s: 15, underline: true))),
              const SizedBox(width: 16),
              Expanded(
                child: Cta(
                  'Show $count hostels',
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// F21 W2: two equal ways to take a bed: hold free for an hour (picked
/// first) or pay the advance to book. One button, one verb.
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
    final book = s.holdOpt == 'book';
    Widget card(String opt, String title, String sub, List<String> ticks) {
      final on = s.holdOpt == opt;
      return Expanded(
        child: Tap(
          key: ValueKey('opt-$opt'),
          onTap: () => s.update(() => s.holdOpt = opt),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: box(bg: on ? p.ab : null, w: 2, c: on ? p.ac : p.tx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: T(title, w: 800, s: 17, lh: 1.2)),
                    const SizedBox(width: 6),
                    Container(width: 18, height: 22, decoration: box(w: 2, c: p.tx), padding: const EdgeInsets.all(3), child: on ? Container(color: p.tx) : null),
                  ],
                ),
                const SizedBox(height: 6),
                T(sub, s: 13, c: p.mu),
                const SizedBox(height: 8),
                for (final t in ticks)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 2), child: Ic('check', size: 13)), const SizedBox(width: 6), Expanded(child: T(t, s: 13, lh: 1.35))]),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card('free', 'Hold free · ${s.isMember ? '2 hours' : '1 hour'}', 'Go and see it first', const ['₹0 now', 'Bed kept for you', 'Ends on its own']),
                const SizedBox(width: 10),
                card('book', 'Pay ${fmt(q.hzAdv)} to book', 'Sure already', ['Bed is yours once ${h.owner} confirms', 'Your price is fixed']),
              ],
            ),
          ),
          Container(
            color: p.sf,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Rich([
              sp(context, 'Bed ${b.id} · ${fmt(q.hzFee)}/mo', w: 800, c: p.tx),
              sp(context, ' · ${r.share} sharing${h.ac ? ' · ${r.type}' : ''} · Advance ${fmt(q.hzAdv)} · ${fmt(q.hzBack)} back when you leave'),
            ], s: 13, c: p.mu, lh: 1.45),
          ),
          if (book && q.any)
            Container(
              color: p.gb,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Rich([sp(context, 'Hostelzy deal: ', w: 800), sp(context, perks.join(' · ')), sp(context, ' · booking code ${s.peekRef}', w: 800)], s: 13, c: p.gn, lh: 1.45),
            ),
          Cta(book ? 'Pay ${fmt(q.hzAdv)} to book' : 'Hold bed ${b.id} free', key: const ValueKey('holdGo'), height: 56, px: 16, fs: 15, onTap: () => s.placeHold(s.holdOpt)),
          T(book ? 'You pay by UPI straight to ${h.owner}. Hostelzy never holds your money.' : 'If ${h.owner} doesn’t keep it within the hour, the bed is free again. You pay nothing.', s: 12, c: p.mu, lh: 1.4),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          // F22 Area 1: the message with the booking code; nothing is sent from here.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: box(w: 2, c: p.tx),
            child: T(s.waFull, s: 15, lh: 1.45),
          ),
          Cta(
            'Open WhatsApp',
            icon: 'msg',
            height: 54,
            px: 16,
            fs: 15,
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
          if (ref != null) T('The booking code keeps your Hostelzy price.', s: 12, c: p.mu, lh: 1.45),
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
        // F22 Area 3 (board `enquiry`): the booking code first, then two actions.
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Kicker(e.contacted ? 'Enquiry from the app · contacted' : 'Enquiry from the app')),
        KV('Booking code', e.ref, keyWidth: 110),
        KV('Phone', '+91 ${phoneSpaced(e.phone)} · not verified', keyWidth: 110),
        KV('Asked about', '${e.bed != null ? 'Bed ${e.bed}${r != null ? ' · ${r.share} sharing' : ''}' : 'Any bed'} · ${clockTime(e.at)}', keyWidth: 110),
        KV('Message', '“${e.msg}”', keyWidth: 110),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: T('If $first moves in, add them with this phone number so it counts.', s: 13, c: p.mu, lh: 1.4),
        ),
        if (!e.contacted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
      for (final r in s.rooms[s.ownHid] ?? const <Room>[])
        for (final b in r.beds)
          if (b.state == 'free' && !b.mine) b.id,
    ];
    final m = s.matchFor(s.rPhone, s.rJoinAt);
    final who = s.rName.trim().isEmpty ? 'They' : s.rName.trim().split(' ')[0];
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
          T(s.onServer ? '$who confirms by joining with your invite code. They count as a resident once they confirm.' : '$who confirms the details in the app. They count as a resident once they confirm.', s: 12, c: p.mu, lh: 1.4),
          Cta('Add resident', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.addResident),
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
    final a = s.rooms[s.ownHid] ?? const <Room>[];
    final freeA = <Bed>[];
    for (final r in a) {
      for (final b in r.beds) {
        if (b.state == 'free' || b.state == 'soon') freeA.add(b);
      }
    }
    final sel = s.addBed != null ? s.findBed(s.ownHid, s.addBed) : null;
    final terms = hostelById(s.ownHid).terms;
    Widget label(String t) => T(t, w: 800, s: 13);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 14,
        children: [
          VGap(
            gap: 6,
            children: [
              label('Name'),
              Field(key: const ValueKey('addName'), value: s.addName, onChanged: (v) => s.update(() => s.addName = v), placeholder: 'Full name'),
            ],
          ),
          VGap(
            gap: 6,
            children: [
              label('Phone'),
              Row(
                children: [
                  Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: box(w: 2, c: p.tx), child: const T('+91', w: 800, s: 15)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Field(
                      key: const ValueKey('addPhone'),
                      value: s.addPhone,
                      onChanged: (v) => s.update(() {
                        final d = v.replaceAll(RegExp(r'\D'), '');
                        s.addPhone = d.length > 10 ? d.substring(0, 10) : d;
                      }),
                      placeholder: 'WhatsApp number, 10 digits',
                      numeric: true,
                    ),
                  ),
                ],
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
              label('Moves in'),
              Seg(opts: same(['Today', 'Tomorrow', dayMon(appToday.add(const Duration(days: 4)))]), cur: s.addDate, onPick: (v) => s.update(() => s.addDate = v), pad: const EdgeInsets.all(10)),
            ],
          ),
          T(sel?.r != null ? 'Rent ${fmt(sel!.r!.rent)} a month · due at move-in ${fmt(terms.advance + sel.r!.rent)} (advance ${fmt(terms.advance)}, ${fmt(terms.maintenance)} kept on exit)' : 'Pick a bed to see the rent.', s: 13, c: p.mu, lh: 1.45),
          // F22: the board asks "How did they find you?" and a booking code; the
          // server already links a tenant who came from the app by phone number.
          Container(
            padding: const EdgeInsets.all(12),
            color: p.sf,
            child: T('Came from the Hostelzy app? Use the phone number they booked with, so it counts.', s: 13, lh: 1.45),
          ),
          Cta(
            'Add tenant',
            key: const ValueKey('addGo'),
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
              final name = s.addName.trim();
              if (s.onServer) {
                // S2: the booking is a stay on the server (moving in on the chosen day).
                final days = switch (s.addDate) { 'Today' => 0, 'Tomorrow' => 1, _ => 4 };
                s.addStayLive(name, s.addPhone, sel.b!.id, sel.r!.rent, terms.advance, appToday.add(Duration(days: days)), booking: true).then((ok) {
                  if (!ok) return;
                  s.update(() {
                    s.addName = '';
                    s.addPhone = '';
                    s.addBed = null;
                    s.addDate = 'Today';
                  });
                });
                return;
              }
              sel.b!.state = 'booked';
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
    final terms = hostelById(s.ownHid).terms;
    final leave = leaveDates(terms).first;
    final stl = {'free': 'Free', 'soon': 'Free from ${b.soon}', 'held': 'On hold', 'booked': 'Taken'}[b.state]!;
    void done(String m) {
      s.update(() => s.sheet = null);
      s.toastMsg(m);
    }

    final first = res?.name.split(' ').first ?? '';
    final actions = <(String, VoidCallback, bool, String)>[];
    if (b.state == 'booked') {
      actions.add(('Message ${first.isEmpty ? 'resident' : first}', () => s.openWA(res != null ? res.name : 'Resident', 'Hi, this is ${s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}.'), true, 'msg'));
      actions.add((
        'Mark as leaving $leave',
        () => res != null ? s.markLeaving(res, b, leaveDays(terms).first) : () {
          b.state = 'soon';
          b.soon = leave;
          done('Bed ${b.id} is listed as free from $leave.');
        }(),
        false,
        'logout',
      ));
    } else if (b.state == 'held') {
      actions.add((
        'Release hold',
        () {
          s.ownerReleaseBed(s.ownHid, b);
          done('Bed ${b.id} is ${b.state == 'soon' ? 'free soon' : 'free'} again.');
        },
        true,
        'x',
      ));
    } else if (b.state == 'soon' && res != null) {
      // F24: leaving: when they've gone, the bed frees and the refund is due.
      actions.add(('Message ${first.isEmpty ? 'resident' : first}', () => s.openWA(res.name, 'Hi, this is ${s.meName.isNotEmpty ? s.meName : hostelById(s.ownHid).owner} from ${hostelById(s.ownHid).name}.'), false, 'msg'));
      actions.add(('${first.isEmpty ? 'They' : first} moved out', () => s.movedOut(res, b), true, 'logout'));
    } else {
      actions.add((
        'Add tenant to this bed',
        () => s.update(() {
          s.sheet = 'add';
          s.addBed = b.id;
        }),
        true,
        'plus',
      ));
      actions.add((
        'Hold for a walk-in',
        () {
          s.holdWalkIn(s.ownHid, b);
          done('Bed ${b.id} held for 1 hour. It frees itself after that.');
        },
        false,
        'clock',
      ));
    }
    // F22 Area 3 (board `bedSheet`): who's in it, the room, the rent, since
    // when and how they came; then one main action.
    final via = res == null ? null : residentTag(p, res.tag).label.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Kicker(stl)),
        if (b.state == 'booked') KV('Resident', res != null ? '${res.name} · rent ${res.status == 'Overdue' ? 'late' : res.status.toLowerCase()}' : 'Not added yet', keyWidth: 110),
        KV('Room', '${r.label} · ${r.share} sharing · ${b.spot}', keyWidth: 110),
        KV('Rent', '${fmt(r.rent)} a month', keyWidth: 110),
        if (res != null) KV('Since', [res.since.replaceFirst('Joined ', '').replaceFirst('Added ', ''), ?via].join(' · '), keyWidth: 110),
        KV('Advance', '${fmt(terms.advance)} · ${fmt(terms.maintenance)} kept on exit', keyWidth: 110),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: VGap(
            gap: 8,
            children: [for (final a in actions) a.$3 ? Cta(a.$1, icon: a.$4, height: 54, px: 16, fs: 15, onTap: a.$2, bg: p.tx, fg: p.bg, border: p.tx) : OutlineCta(a.$1, icon: a.$4, onTap: a.$2)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              key: const ValueKey('bedLayout'),
              onTap: () {
                s.update(() => s.sheet = null);
                s.ownerLayout(r.n);
              },
              child: T('Room ${r.label} layout ›', s: 14, w: 800),
            ),
          ),
        ),
      ],
    );
  }
}
