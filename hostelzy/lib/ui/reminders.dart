import 'package:flutter/material.dart';

import '../data.dart';
import '../reminders.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'settings.dart' show SquareSwitch;

// F20 Reminders (design "Hostelzy · F20 Reminders"): Me → Reminders (Main),
// the water sheet (Water), add a reminder (Add), the first-time offer (Offer)
// and the Today card on resident Home and Explore (Home, HomeTenant).

String _icon(String name) {
  final n = name.toLowerCase();
  if (n.contains('medicine') || n.contains('tablet')) return 'pill';
  if (n.contains('lunch') || n.contains('dinner') || n.contains('breakfast') || n.contains('eat')) return 'utensils';
  if (n.contains('call')) return 'phone';
  return 'clock';
}

/// Picks a time (minutes of the day) with the phone's clock dialog.
Future<int?> pickTime(BuildContext context, int minute) async {
  final p = PalScope.of(context);
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    builder: (c, child) => Theme(
      data: Theme.of(c).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: p.ac, primary: p.ac, onPrimary: p.ai, surface: p.bg, onSurface: p.tx, brightness: p.bg.computeLuminance() < .5 ? Brightness.dark : Brightness.light),
        timePickerTheme: const TimePickerThemeData(shape: RoundedRectangleBorder()),
      ),
      child: child!,
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// A form box showing a time; tap to change it.
class TimeBox extends StatelessWidget {
  const TimeBox({super.key, required this.label, required this.minute, required this.onPick});
  final String label;
  final int minute;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return VGap(
      gap: 6,
      children: [
        T(label, w: 800, s: 13),
        Tap(
          onTap: () async {
            final m = await pickTime(context, minute);
            if (m != null) onPick(m);
          },
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: box(bg: p.bg, w: 2, c: p.tx),
            child: T(clock(minute), s: 15),
          ),
        ),
      ],
    );
  }
}

/// Eight square glass cells, filled in ink.
class GlassCells extends StatelessWidget {
  const GlassCells({super.key, required this.done, required this.goal});
  final int done, goal;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < goal; i++)
          Container(
            width: 22,
            height: 26,
            decoration: box(bg: i < done ? p.tx : transparent, w: 2, c: p.tx),
          ),
      ],
    );
  }
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final w = s.water;
    final next = s.nextGlass();
    final hid = s.remHostel;
    final h = hid != null ? hostelById(hid) : null;
    Widget row({required String icon, required String title, required String sub, Widget? trail, VoidCallback? onTap, double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
        child: Row(
          children: [
            Container(width: 36, height: 36, color: p.sf, alignment: Alignment.center, child: Ic(icon, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Tap(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(title, w: 800, s: 15),
                    const SizedBox(height: 1),
                    T(sub, s: 12, c: p.mu),
                  ],
                ),
              ),
            ),
            if (trail != null) ...[const SizedBox(width: 12), trail],
          ],
        ),
      ),
    );
    Widget section(String k, {String? action, VoidCallback? onAction}) => Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      decoration: BoxDecoration(border: Border(bottom: bs(2, p.dv))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Kicker(k)),
          if (action != null)
            Tap(
              onTap: onAction,
              child: T(action, w: 800, s: 12, c: p.ad),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              const Expanded(
                child: PageHead(kicker: 'Me · on this phone', title: 'Reminders', size: 28),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scroll(
            key: ValueKey('reminders${s.scrollEpoch}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.osPushAllowed == false)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: box(bg: p.ab, w: 2, c: p.ad),
                    child: VGap(
                      gap: 8,
                      children: [
                        T('Notifications are off', w: 800, s: 15, c: p.ad),
                        const T('Reminders can’t ring until you turn them on for Hostelzy.', s: 13),
                        Cta('Turn on notifications', icon: 'bell', height: 44, fs: 14, onTap: s.enablePush),
                      ],
                    ),
                  ),
                if (!s.rem.available)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: T('Reminders ring in the Android app. You can set them up here.', s: 13, c: p.mu),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: box(w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              color: p.tx,
                              alignment: Alignment.center,
                              child: Ic('drop', size: 20, color: p.bg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Tap(
                                onTap: s.openWater,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const T('Drink water', w: 800, s: 17),
                                    const SizedBox(height: 1),
                                    T('Every ${RemindersActions.everyLabel(w.every)} · ${s.awakeLabel}', s: 12, c: p.mu),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tap(
                              key: const ValueKey('waterSwitch'),
                              onTap: s.toggleWater,
                              child: SquareSwitch(on: w.on),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: VGap(
                          gap: 8,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(child: T('${s.glasses} of ${w.goal} glasses today', w: 800, s: 15)),
                                Tap(
                                  onTap: s.openWater,
                                  child: T('Change', w: 800, s: 13, c: p.ad),
                                ),
                              ],
                            ),
                            GlassCells(done: s.glasses, goal: w.goal),
                            Row(
                              children: [
                                Expanded(
                                  child: Cta('I had a glass', icon: 'plus', height: 44, px: 16, fs: 14, bg: p.tx, fg: p.bg, onTap: s.addGlass),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Cta(next != null ? 'Next at ${clock(next)}' : (w.on ? 'Done for today' : 'Off'), icon: 'clock', height: 44, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: s.openWater),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                section('My reminders', action: '+ Add', onAction: s.openAddRem),
                if (s.myRems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: T('Add your own, like medicine at 9 pm or a call home on Sundays.', s: 13, c: p.mu),
                  ),
                for (final r in s.myRems)
                  row(
                    icon: _icon(r.name),
                    title: r.name,
                    sub: '${clock(r.at)} · ${RemindersActions.repeatLabel(r)}',
                    onTap: () => s.openAddRem(r),
                    opacity: r.on ? 1 : .55,
                    trail: Tap(
                      onTap: () => s.toggleRem(r.id),
                      child: SquareSwitch(on: r.on),
                    ),
                  ),
                if (h != null) ...[
                  section('From ${h.name}'),
                  if (h.food)
                    row(
                      icon: 'utensils',
                      title: 'Meal times',
                      sub: s.mealLine,
                      trail: Tap(
                        onTap: () => s.toggleHostelRem('meals'),
                        child: SquareSwitch(on: s.remMeals),
                      ),
                    ),
                  row(
                    icon: 'wallet',
                    title: 'Rent due',
                    sub: '3 days before and on the day · next ${dayMon(s.rentDue)}',
                    trail: Tap(
                      onTap: () => s.toggleHostelRem('rent'),
                      child: SquareSwitch(on: s.remRent),
                    ),
                  ),
                  row(icon: 'clock', title: 'Laundry day', sub: 'When ${h.owner.isEmpty ? 'your owner' : h.owner} sets one', opacity: .45),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: T('Reminders ring from this phone, even offline. Nothing rings outside your awake hours.', s: 12, c: p.mu),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WaterSheet extends StatelessWidget {
  const WaterSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final d = s.waterDraft ?? s.water;
    Widget every(int m) {
      final on = d.every == m;
      return Expanded(
        child: Tap(
          onTap: () => s.editWater((w) => w.copyWith(every: m)),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: box(bg: on ? p.tx : transparent, w: on ? 2 : 1, c: on ? p.tx : p.dv),
            child: T(RemindersActions.everyLabel(m), w: 800, s: 14, c: on ? p.bg : p.tx),
          ),
        ),
      );
    }

    Widget stepBtn(String icon, String label, VoidCallback onTap) => Semantics(
      label: label,
      button: true,
      child: Tap(
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: Ic(icon, size: 18))),
      ),
    );
    final n = d.slots.length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          const T('How often', w: 800, s: 13),
          Row(children: [every(20), const SizedBox(width: 6), every(30), const SizedBox(width: 6), every(45)]),
          Row(children: [every(60), const SizedBox(width: 6), every(90), const SizedBox(width: 6), every(120)]),
          const T('Awake hours', w: 800, s: 13),
          Row(
            children: [
              Expanded(
                child: TimeBox(
                  label: 'From',
                  minute: d.from,
                  onPick: (m) => s.editWater((w) => w.copyWith(from: m)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TimeBox(
                  label: 'To',
                  minute: d.to,
                  onPick: (m) => s.editWater((w) => w.copyWith(to: m)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const T('Daily goal', w: 800, s: 15),
                    T('Glasses a day', s: 12, c: p.mu),
                  ],
                ),
              ),
              Container(
                decoration: box(w: 2, c: p.tx),
                child: Row(
                  children: [
                    stepBtn('minus', 'One fewer', () => s.editWater((w) => w.copyWith(goal: (w.goal - 1).clamp(1, 16)))),
                    Container(
                      width: 52,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(left: bs(2, p.tx), right: bs(2, p.tx)),
                      ),
                      child: T('${d.goal}', w: 800, s: 18),
                    ),
                    stepBtn('plus', 'One more', () => s.editWater((w) => w.copyWith(goal: (w.goal + 1).clamp(1, 16)))),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: p.sf,
            child: d.to - d.from < 60
                ? T('Awake hours need at least an hour.', s: 13, c: p.ad)
                : Rich([
                    const TextSpan(text: 'That’s '),
                    TextSpan(
                      text: '$n reminder${n == 1 ? '' : 's'} a day',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ', ${clock(d.from)} to ${clock(d.to)}.'),
                  ], s: 13),
          ),
          Cta('Save', height: 54, fs: 15, onTap: s.saveWater),
        ],
      ),
    );
  }
}

class AddReminderSheet extends StatelessWidget {
  const AddReminderSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final pick = s.remRepeat == 'days';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          if (s.remEdit == null) ...[
            const T('Quick add', w: 800, s: 13),
            wrap(6, [for (final q in quickRems) ChipBtn(q.$1, on: s.remName == q.$2 && s.remAt == q.$3, onTap: () => s.quickRem(q), pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 12))]),
          ],
          VGap(
            gap: 6,
            children: [
              const T('Name', w: 800, s: 13),
              Field(value: s.remName, placeholder: 'Take medicine', onChanged: (v) => s.remName = v),
            ],
          ),
          TimeBox(label: 'Time', minute: s.remAt, onPick: (m) => s.update(() => s.remAt = m)),
          const T('Repeat', w: 800, s: 13),
          Seg(opts: const [('once', 'Once'), ('daily', 'Every day'), ('weekdays', 'Weekdays'), ('days', 'Pick days')], cur: s.remRepeat, onPick: (v) => s.update(() => s.remRepeat = v), pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), center: true),
          Opacity(
            opacity: pick ? 1 : .45,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Tap(
                      onTap: () => s.update(() {
                        s.remRepeat = 'days';
                        s.remDays = s.remDays.contains(i + 1) ? (Set.of(s.remDays)..remove(i + 1)) : {...s.remDays, i + 1};
                      }),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: box(bg: pick && s.remDays.contains(i + 1) ? p.tx : transparent, w: 1, c: pick && s.remDays.contains(i + 1) ? p.tx : p.dv),
                        child: T(days[i], w: 800, s: 13, c: pick && s.remDays.contains(i + 1) ? p.bg : p.tx),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Cta(s.remEdit == null ? 'Add reminder' : 'Save', height: 54, fs: 15, onTap: s.saveRem),
          if (s.remEdit != null)
            Center(
              child: Tap(
                onTap: () => s.deleteRem(s.remEdit!),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: T('Delete reminder', w: 800, s: 14, c: p.ad),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// First-time offer, once after sign-in.
class WaterOfferSheet extends StatelessWidget {
  const WaterOfferSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                color: p.tx,
                alignment: Alignment.center,
                child: Ic('drop', size: 24, color: p.bg),
              ),
              const SizedBox(width: 12),
              const Expanded(child: T('A friendly nudge every 30 minutes, 8 am to 10 pm. You can add your own reminders too, like medicine or lunch.', s: 15, lh: 1.4)),
            ],
          ),
          Cta('Turn on water reminders', height: 54, fs: 15, onTap: s.acceptOffer),
          OutlineCta('Not now', icon: 'x', onTap: () => s.update(() => s.sheet = null)),
          T('Change it any time in Me → Reminders. Runs on this phone.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// Home / Explore: glasses today and what rings next. Only while something is on.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16)});
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final mine = s.nextMine();
    final glass = s.nextGlass();
    if (!s.water.on && mine == null) return const SizedBox.shrink();
    final next = mine != null && s.role == 'resident' ? 'Next: ${mine.$1} at ${clock(mine.$2, short: true)}' : (glass != null ? 'Next glass at ${clock(glass)}' : (mine != null ? 'Next: ${mine.$1} at ${clock(mine.$2, short: true)}' : 'No more today'));
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: box(w: 2, c: p.tx),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            color: p.tx,
            alignment: Alignment.center,
            child: Ic('drop', size: 20, color: p.bg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tap(
              onTap: s.openReminders,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  T(s.water.on ? '${s.glasses} of ${s.water.goal} glasses' : 'Reminders', w: 800, s: 15),
                  T(next, s: 12, c: p.mu),
                ],
              ),
            ),
          ),
          if (s.water.on) ...[const SizedBox(width: 12), Cta('Glass', icon: 'plus', height: 40, px: 12, fs: 13, iconSize: 14, expand: false, gap: 8, bg: p.tx, fg: p.bg, onTap: s.addGlass)],
        ],
      ),
    );
  }
}
