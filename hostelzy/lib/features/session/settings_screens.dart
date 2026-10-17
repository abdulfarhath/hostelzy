import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_config.dart';
import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';

// F15 Play Store: Settings (board 1), delete account (2–4), permission
// explainers (5) and the update / maintenance screen (7). The consent line on
// the phone screen (6) shipped with F17.

class _Head extends StatelessWidget {
  const _Head(this.kicker, this.title);
  final String kicker, title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: kicker, title: title, size: 28))]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, {this.value, this.red = false, required this.onTap});
  final String label;
  final String? value;
  final bool red;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final c = red ? p.ad : p.tx;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: Row(
          children: [
            Expanded(child: T(label, s: 15, w: 600, c: c)),
            if (value != null) ...[T(value!, s: 13, c: p.mu), const SizedBox(width: 8)],
            Ic('chev', size: 18, color: p.mu),
          ],
        ),
      ),
    );
  }
}

/// Square on/off switch, as in the designs.
class SquareSwitch extends StatelessWidget {
  const SquareSwitch({super.key, required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: box(bg: on ? p.tx : null, w: 2, c: p.tx),
      child: Container(width: 16, height: 16, color: on ? p.bg : p.tx),
    );
  }
}

/// Board 1: Settings, from Me.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final name = s.meName.isNotEmpty ? s.meName : (s.role == 'owner' ? hostelById(s.ownHid).owner : 'Add your name');
    final phone = s.myPhone.isEmpty ? 'Add your number' : '+91 ${phoneSpaced(s.myPhone)}';
    Widget toggle(String k, String t, String sub) => Tap(
      onTap: () => s.toggleNotif(k),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T(t, w: 800, s: 15), T(sub, s: 12, c: p.mu)])), SquareSwitch(on: s.notifOn(k))]),
      ),
    );
    Widget group(String label, List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Kicker(label)),
        Container(decoration: BoxDecoration(border: Border(top: bs(2, p.dv))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(s.myPhone.isEmpty ? name : '$name · $phone', 'Settings'),
        Expanded(
          child: Scroll(
            key: ValueKey('settings${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // F22 Area 1: You · Notifications · App, then Log out and Delete account.
                group('You', [
                  _Row('Name', value: name, onTap: s.editName),
                  _Row('Phone', value: phone, onTap: () => s.toastMsg('To change your number, log out and sign in with the new one.')),
                  // F24 Wave 4c: owners may chat on another number than they take calls on.
                  if (s.role == 'owner') _Row('WhatsApp', value: s.myWa.isEmpty ? 'Same as phone' : '+91 ${phoneSpaced(s.myWa)}', onTap: s.editWa),
                ]),
                group('Notifications', [
                  toggle('hold', 'Holds and bookings', 'When the owner confirms or replies'),
                  toggle('rent', 'Rent reminders', '3 days before'),
                  toggle('beds', 'New free beds', 'In areas you searched. “Tell me when verified” alerts always come'),
                  // F27: "Dinner at 8 · Eating?" for residents, the headcount for owners.
                  if (s.role == 'resident') toggle('food', 'Meals', '“Eating?” 1 hour before each meal’s count closes'),
                  if (s.role == 'owner') toggle('food', 'Meals', 'The headcount when each meal’s count closes'),
                ]),
                group('App', [
                  _Row('Language', value: s.langChoices.firstWhere((l) => l.$1 == s.lang, orElse: () => ('en', 'English')).$2, onTap: () => s.langChoices.length > 1 ? s.update(() => s.sheet = 'lang') : s.toastMsg('Telugu and Hindi come once a native speaker has checked the words.')),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                    child: Row(children: [const Expanded(child: T('Look', s: 15, w: 600)), Expanded(flex: 2, child: Seg(opts: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'Auto')], cur: s.theme, onPick: (v) => s.update(() => s.theme = v), center: true, pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 6)))]),
                  ),
                  _Row('Privacy policy', onTap: () => s.openLink(Uri.parse(privacyUrl), 'the browser')),
                  _Row('Terms', onTap: () => s.openLink(Uri.parse(termsUrl), 'the browser')),
                  if (s.role == 'owner') _Row('Fair Play rules', onTap: () => s.go('oRules')),
                  _Row('Hostelzy team', value: s.teamUnlocked ? 'Unlocked' : null, onTap: s.openTeam),
                ]),
                const SizedBox(height: 18),
                Container(decoration: BoxDecoration(border: Border(top: bs(2, p.dv))), child: _Row('Log out', onTap: s.logOut)),
                _Row('Delete account', red: true, onTap: () => s.go('delAcc')),
                Padding(padding: const EdgeInsets.all(16), child: T('Hostelzy $appVersion ($appBuild)${isStaging ? ' · STAGING' : ''} · Made in Hyderabad', s: 12, c: p.mu)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Board 2: what deleting does.
class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final block = s.deleteBlock;
    Widget item(String icon, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: 2), child: Ic(icon, size: 18, color: p.tx)), const SizedBox(width: 10), Expanded(child: T(t, s: 15, lh: 1.45))]),
    );
    if (block != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head('Delete account', block.title),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: box(bg: p.ab, w: 2, c: p.ad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Ic('lock', size: 20, color: p.ad), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [T('You can’t delete your account yet', w: 800, s: 14, c: p.ad), const SizedBox(height: 2), T(block.body, s: 13, lh: 1.4)]))],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: T('Once it’s settled, come back to Settings → Delete account.', s: 13, c: p.mu, lh: 1.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
            child: VGap(gap: 8, children: [Cta(block.cta, height: 54, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: block.go), OutlineCta('Back to settings', icon: 'back', onTap: s.back)]),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head('Settings', 'Delete your account?'),
        Expanded(
          child: Scroll(
            key: ValueKey('delAcc${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: T('This can’t be undone.', s: 15, c: p.mu, lh: 1.5)),
                // F22 Area 5 (board `delAcc`): two short lists, what goes and what stays.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const T('Deleted', w: 800, s: 15),
                      for (final x in const ['Your name, phone and Google sign-in', 'Saved hostels, holds and enquiries', 'Stay Rewards and your referral code']) item('trash', x),
                      const SizedBox(height: 14),
                      const T('Kept, without your name', w: 800, s: 15),
                      for (final x in const ['Stay records the hostel must keep (dates, rent receipts)', 'Your reviews, shown as “Former resident”', 'Fair Play case records']) item('lock', x),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Ic('shield', size: 16, color: p.mu), const SizedBox(width: 8), Expanded(child: T('We keep only what the law or the hostel needs, without your name or phone on it.', s: 12, c: p.mu, lh: 1.45))]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: VGap(gap: 6, children: [const T('Why are you leaving? (optional)', w: 800, s: 13), Field(value: s.delReason, placeholder: 'Helps us improve', onChanged: (v) => s.update(() => s.delReason = v))]),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: T('You can also ask for deletion on the web: $deleteAccountUrl', s: 12, c: p.mu)),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: VGap(gap: 8, children: [Cta('Continue', height: 54, px: 16, fs: 15, onTap: s.startDelete), OutlineCta('Keep my account', icon: 'back', onTap: s.back)]),
        ),
      ],
    );
  }
}

/// Delete account v2 (design 18): confirm it's you with Google.
class DeleteConfirmScreen extends StatelessWidget {
  const DeleteConfirmScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.account;
    final google = a != null && s.signIn.available;
    final name = a?.name.isNotEmpty == true ? a!.name : s.meName;
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head('Delete account', 'Confirm it’s you'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: VGap(
            gap: 14,
            children: [
              T(google ? 'Sign in with Google once more to delete your Hostelzy account. This can’t be undone.' : 'This phone isn’t signed in with Google, so your Hostelzy data is only on this phone. Deleting removes it from here. This can’t be undone.', s: 15, c: p.mu, lh: 1.5),
              if (a != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: box(w: 2, c: p.tx),
                  child: Row(
                    children: [
                      Container(width: 40, height: 40, color: p.ac, alignment: Alignment.center, child: T(initials.isEmpty ? '?' : initials, w: 800, c: p.ai)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [T(name, w: 800, s: 15), const SizedBox(height: 1), T(a.email, s: 12, c: p.mu)])),
                    ],
                  ),
                ),
              if (google)
                GoogleButton(s.deleting ? 'Deleting…' : 'Confirm with Google', busy: s.deleting, onTap: s.confirmDelete)
              else
                Cta('Delete from this phone', icon: 'trash', height: 54, px: 16, fs: 15, onTap: s.confirmDelete),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: OutlineCta('Keep my account', icon: 'back', height: 50, onTap: () => s.tab('me')),
        ),
      ],
    );
  }
}

/// Board 4: done.
class DeleteDoneScreen extends StatelessWidget {
  const DeleteDoneScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: Container(width: 56, height: 56, color: p.tx, alignment: Alignment.center, child: Ic('check', size: 28, color: p.bg))),
          const SizedBox(height: 14),
          const T('Your account is deleted', w: 800, s: 34, lh: 1.02, ls: -.025),
          const SizedBox(height: 14),
          T('We removed your name, phone, Google sign-in, holds, saved hostels and rewards. Reviews stay as “Former resident”.', s: 15, c: p.mu, lh: 1.5),
          const Spacer(),
          Cta('Close Hostelzy', icon: 'x', height: 54, px: 16, fs: 15, bg: p.tx, fg: p.bg, onTap: () {
            s.update(() {
              s.screen = 'welcome';
              s.hist = [];
            });
            SystemNavigator.pop();
          }),
        ],
      ),
    );
  }
}

/// Board 5: explainer before Android's own notifications prompt.
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // The one ask before Android's own prompt. Photos come from the phone's
    // picker (no camera permission) and location from the Near me sheet.
    const icon = 'bell', title = 'Turn on notifications?', sub = 'Only for things you’d want to know straight away.', yes = 'Turn on', no = 'Not now';
    const uses = ['When the owner confirms your hold', 'Rent reminders, 3 days before'];
    void allow() {
      s.back();
      s.enablePush();
    }

    return FillScroll(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: Container(width: 64, height: 64, color: p.sf, alignment: Alignment.center, child: Ic(icon, size: 30, color: p.tx))),
            const SizedBox(height: 14),
            const T(title, w: 800, s: 32, lh: 1.02, ls: -.025),
            const SizedBox(height: 14),
            T(sub, s: 15, c: p.mu, lh: 1.5),
            const SizedBox(height: 20),
            if (uses.isNotEmpty)
            Container(
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
              child: Column(
                children: [
                  for (final u in uses)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: 2), child: Ic('check', size: 16, color: p.tx)), const SizedBox(width: 10), Expanded(child: T(u, s: 14))]),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Cta(yes, height: 54, px: 16, fs: 15, onTap: allow),
            const SizedBox(height: 8),
            OutlineCta(no, icon: 'x', onTap: s.back),
            const SizedBox(height: 10),
            T('Your phone asks next. Change it any time in Settings.', s: 13, c: p.mu),
          ],
        ),
      ),
    );
  }
}

/// Board 7: update needed, or maintenance.
class GateScreen extends StatelessWidget {
  const GateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final update = s.gateKind == 'update';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: Container(width: 64, height: 64, color: p.sf, alignment: Alignment.center, child: Ic(update ? 'arrow' : 'wrench', size: 30, color: p.tx))),
          const SizedBox(height: 14),
          T(update ? 'Update Hostelzy to continue' : 'Back in a few minutes', w: 800, s: 32, lh: 1.02, ls: -.025),
          const SizedBox(height: 14),
          T(update ? 'This version is too old to work with Hostelzy any more. The update is free and takes a minute.' : 'We’re making Hostelzy better. Your holds, payments and data are safe.${s.maintUntil.isEmpty ? '' : ' Expected back by ${s.maintUntil}.'}', s: 15, c: p.mu, lh: 1.5),
          if (update) ...[const SizedBox(height: 10), T('Your version: $appVersion ($appBuild) · Needed: build $minSupportedBuild or newer', s: 13, c: p.mu)],
          const Spacer(),
          if (update)
            Cta('Update on Google Play', height: 54, px: 16, fs: 15, onTap: () => s.openLink(Uri.parse('https://play.google.com/store/apps/details?id=app.hostelzy.hostelzy'), 'Google Play'))
          else
            OutlineCta('WhatsApp Hostelzy', icon: 'msg', onTap: () => s.whatsapp(supportWhatsApp, 'Hi Hostelzy, is the app back?')),
        ],
      ),
    );
  }
}

/// F24 item 23: Settings › Name. The field starts empty; the current name is
/// only its hint.
class NameSheet extends StatelessWidget {
  const NameSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final now = s.meName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          const T('Your name', w: 800, s: 13),
          Field(key: const ValueKey('nameEdit'), value: s.nameDraft, placeholder: now.isEmpty ? 'Full name' : now, onChanged: (v) => s.update(() => s.nameDraft = v)),
          T('Owners see this name on your holds, enquiries and stay.', s: 12, c: p.mu, lh: 1.4),
          Cta('Save name', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.saveName),
        ],
      ),
    );
  }
}

/// F24 Wave 4c: Settings › WhatsApp (owners). Empty means the phone number.
class WaNumberSheet extends StatelessWidget {
  const WaNumberSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 10,
        children: [
          const T('WhatsApp number', w: 800, s: 13),
          Field(key: const ValueKey('waEdit'), value: s.waDraft, placeholder: s.myPhone.isEmpty ? '10-digit number' : phoneSpaced(s.myPhone), numeric: true, onChanged: (v) => s.update(() => s.waDraft = v)),
          T('Only if you chat on a different number than you take calls on. Tenants who held a bed and your residents message you here.', s: 12, c: p.mu, lh: 1.4),
          Cta('Save WhatsApp number', icon: 'check', height: 54, px: 16, fs: 15, onTap: s.saveWa),
          if (s.myWa.isNotEmpty) OutlineCta('Use my phone number', height: 50, onTap: () => s.saveWa(clear: true)),
        ],
      ),
    );
  }
}
