import 'package:flutter/material.dart';

import '../data.dart';
import 'kit.dart';

/// 40×40 back button with a 1px divider-coloured border.
class BackBtn extends StatelessWidget {
  const BackBtn({super.key, required this.onTap, this.bg});
  final VoidCallback onTap;
  final Color? bg;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: box(bg: bg, w: 1, c: p.dv),
        alignment: Alignment.center,
        child: const Ic('back', size: 20),
      ),
    );
  }
}

/// Full-width action bar: label on the left, icon on the right.
///
/// [parts]: the prototype renders every `{{ value }}` as its own flex item,
/// so a label like `Pay {{ total }} by {{ method }}` is spread out by
/// `justify-content: space-between`. Pass the pieces to reproduce that.
class Cta extends StatelessWidget {
  const Cta(this.label, {super.key, this.parts, required this.onTap, this.icon = 'arrow', this.height = 56, this.vpad = 0, this.px = 18, this.fs = 16, this.iconSize = 18, this.bg, this.fg, this.border, this.opacity = 1, this.expand = true, this.gap = 12});
  final String label, icon;
  final List<String>? parts;
  final VoidCallback? onTap;
  final double? height;
  final double vpad, px, fs, iconSize, opacity, gap;
  final Color? bg, fg, border;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final f = fg ?? p.ai;
    Widget w = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: px, vertical: vpad),
      decoration: box(
        bg: bg ?? p.ac,
        border: border != null ? Border.all(width: 2, color: border!) : null,
      ),
      child: Css(
        c: f,
        w: 800,
        s: fs,
        child: Row(
          mainAxisAlignment: expand ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (parts != null)
              for (final t in parts!) T(t)
            else
              T(label),
            if (!expand) SizedBox(width: gap),
            Ic(icon, size: iconSize, color: f),
          ],
        ),
      ),
    );
    if (opacity != 1) w = Opacity(opacity: opacity, child: w);
    return Tap(onTap: onTap, child: w);
  }
}

/// Outline action (`border:2px solid var(--tx)`), same layout as [Cta].
class OutlineCta extends StatelessWidget {
  const OutlineCta(this.label, {super.key, required this.onTap, this.icon = 'arrow', this.height = 52, this.px = 16, this.fs = 15, this.iconSize = 18});
  final String label, icon;
  final VoidCallback onTap;
  final double height, px, fs, iconSize;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Cta(label, onTap: onTap, icon: icon, height: height, px: px, fs: fs, iconSize: iconSize, bg: transparent, fg: p.tx, border: p.tx);
  }
}

typedef Opt = (String value, String label);

/// Segmented control: 2px frame, active segment inverted.
class Seg extends StatelessWidget {
  const Seg({super.key, required this.opts, required this.cur, required this.onPick, this.pad = const EdgeInsets.symmetric(vertical: 10, horizontal: 12), this.fs = 13, this.margin, this.dividers = false});
  final List<Opt> opts;
  final String? cur;
  final ValueChanged<String> onPick;
  final EdgeInsets pad;
  final double fs;
  final EdgeInsets? margin;
  final bool dividers;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      margin: margin,
      decoration: box(w: 2, c: p.tx),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < opts.length; i++)
              Expanded(
                child: Tap(
                  onTap: () => onPick(opts[i].$1),
                  child: Container(
                    padding: pad,
                    decoration: BoxDecoration(
                      color: opts[i].$1 == cur ? p.tx : transparent,
                      border: dividers && i > 0 ? Border(left: bs(1, p.hl)) : null,
                    ),
                    child: T(opts[i].$2, s: fs, w: 600, c: opts[i].$1 == cur ? p.bg : p.tx),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<Opt> same(List<String> v) => [for (final x in v) (x, x)];

/// Filter chip: 1px border, inverted when on.
class ChipBtn extends StatelessWidget {
  const ChipBtn(this.label, {super.key, required this.on, required this.onTap, this.pad = const EdgeInsets.symmetric(vertical: 8, horizontal: 12), this.fs = 13});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final EdgeInsets pad;
  final double fs;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Tap(
      onTap: onTap,
      child: Container(
        padding: pad,
        decoration: box(bg: on ? p.tx : transparent, w: 1, c: on ? p.tx : p.dv),
        child: T(label, s: fs, w: 600, c: on ? p.bg : p.tx, nowrap: true),
      ),
    );
  }
}

/// Kicker + big title used at the top of tab screens.
class PageHead extends StatelessWidget {
  const PageHead({super.key, required this.kicker, required this.title, this.size = 30, this.gap = 4, this.kickerColor});
  final String kicker, title;
  final double size, gap;
  final Color? kickerColor;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Kicker(kicker, c: kickerColor),
      SizedBox(height: gap),
      T(title, s: size, w: 800, lh: 1.02, ls: -.025),
    ],
  );
}

/// Bed states, shared by every bed map.
class BedLook {
  const BedLook(this.bg, this.border, this.fg, this.tag, {this.hatch = false, this.dashed = false});
  final Color bg, border, fg;
  final String tag;
  final bool hatch, dashed;
  bool get transparentBg => bg == transparent;
}

BedLook bedState(Pal p, String k) => switch (k) {
  'free' => BedLook(p.bg, p.tx, p.tx, 'Free'),
  'soon' => BedLook(p.bg, p.tx, p.tx, 'Free soon', dashed: true),
  'held' => BedLook(transparent, p.tk, p.mu, 'On hold', hatch: true),
  'booked' => BedLook(p.tk, p.tk, p.tx, 'Taken'),
  'sel' => BedLook(p.ac, p.ac, p.ai, 'Selected'),
  _ => BedLook(p.ab, p.ac, p.ad, 'Your hold'),
};

/// `look(b, sel)` from the prototype.
({BedLook look, String tag, bool can}) lookOf(Pal p, Bed b, String? sel) {
  final k = b.id == sel
      ? 'sel'
      : b.mine
      ? 'mine'
      : b.state;
  final l = bedState(p, k);
  return (look: l, tag: k == 'soon' ? 'From ${b.soon}' : l.tag, can: (b.state == 'free' || b.state == 'soon') && !b.mine);
}

/// A box painted in a bed state (2px border, solid / dashed / hatched).
class BedBox extends StatelessWidget {
  const BedBox({super.key, required this.look, this.width, this.height, this.minHeight, this.padding, this.child, this.borderWidth = 2});
  final BedLook look;
  final double? width, height, minHeight;
  final EdgeInsets? padding;
  final Widget? child;
  final double borderWidth;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    Widget inner = Css(c: look.fg, child: child ?? const SizedBox.shrink());
    Widget w;
    if (look.dashed) {
      w = Dashed(color: look.border, width: borderWidth, bg: look.bg, padding: padding, child: inner);
    } else if (look.hatch) {
      w = CustomPaint(
        painter: Hatch(p.tk, 3, 7),
        child: Container(
          decoration: box(w: borderWidth, c: look.border),
          padding: padding,
          child: inner,
        ),
      );
    } else {
      w = Container(
        decoration: box(bg: look.bg, w: borderWidth, c: look.border),
        padding: padding,
        child: inner,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: SizedBox(width: width, height: height, child: w),
    );
  }
}

/// Legend swatch + label.
class Legend extends StatelessWidget {
  const Legend({super.key, required this.items});
  final List<(String label, String state)> items;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BedBox(look: bedState(p, it.$2), width: 12, height: 12),
              const SizedBox(width: 6),
              T(it.$1, s: 12, c: p.mu),
            ],
          ),
      ],
    );
  }
}

/// Key/value row: fixed-width muted key, bold value.
class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, required this.keyWidth, this.pad = const EdgeInsets.symmetric(vertical: 11, horizontal: 16)});
  final String k, v;
  final double keyWidth;
  final EdgeInsets pad;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: pad,
      decoration: BoxDecoration(border: Border(bottom: bs(1, p.hl))),
      child: Css(
        s: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: keyWidth,
              child: T(k, c: p.mu),
            ),
            const SizedBox(width: 12),
            Expanded(child: T(v, w: 600)),
          ],
        ),
      ),
    );
  }
}

/// Spread row: muted key left, value right.
class LineRow extends StatelessWidget {
  const LineRow(this.k, this.v, {super.key, this.vw = 600, this.pad = const EdgeInsets.symmetric(vertical: 12, horizontal: 16), this.border});
  final String k, v;
  final int vw;
  final EdgeInsets pad;
  final Border? border;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      padding: pad,
      decoration: BoxDecoration(border: border ?? Border(bottom: bs(1, p.hl))),
      child: Css(
        s: 14,
        child: CssRow(
          children: [
            T(k, c: p.mu),
            T(v, w: vw),
          ],
        ),
      ),
    );
  }
}

/// Timeline step: 14px square + title + detail.
class TimelineStep extends StatelessWidget {
  const TimelineStep({super.key, required this.t, required this.d, required this.bg, required this.bd});
  final String t, d;
  final Color bg, bd;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 3),
                width: 14,
                height: 14,
                decoration: box(bg: bg, w: 2, c: bd),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                T(t, w: 800, s: 15),
                const SizedBox(height: 1),
                T(d, s: 13, c: p.mu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status tag colours (`tagOf`).
({Color bg, Color fg}) tagOf(Pal p, String st) => st == 'Paid' || st == 'Resolved'
    ? (bg: p.gb, fg: p.gn)
    : st == 'Overdue' || st == 'Open'
    ? (bg: p.ac, fg: p.ai)
    : (bg: p.ab, fg: p.ad);

/// Single-line text input with a 2px frame (`height:46px;padding:0 12px`).
class Field extends StatefulWidget {
  const Field({super.key, required this.value, required this.onChanged, this.placeholder, this.numeric = false, this.height = 46, this.fs = 15, this.w = 400, this.ls = 0, this.border = true, this.maxLines = 1, this.pad = const EdgeInsets.symmetric(horizontal: 12), this.hiddenText = false});
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool numeric, border, hiddenText;
  final double? height;
  final double fs, ls;
  final int w;
  final int maxLines;
  final EdgeInsets pad;
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final TextEditingController ctl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(Field old) {
    super.didUpdateWidget(old);
    if (ctl.text != widget.value) {
      ctl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final base = DefaultTextStyle.of(context).style;
    // `font: inherit` → line-height 1.4; pin each line box to exactly that so
    // the text sits where the browser puts it on every platform.
    final style = cssStyle(base, s: widget.fs, w: widget.w, ls: widget.ls, c: widget.hiddenText ? transparent : p.tx, lh: 1.4);
    final strut = StrutStyle(fontFamily: 'Archivo', fontSize: widget.fs, height: 1.4, leadingDistribution: TextLeadingDistribution.even, forceStrutHeight: true);
    final field = TextField(
      strutStyle: strut,
      controller: ctl,
      onChanged: (v) {
        widget.onChanged(v);
        // Controlled input: snap back to the filtered state value.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ctl.text != widget.value) {
            ctl.value = TextEditingValue(
              text: widget.value,
              selection: TextSelection.collapsed(offset: widget.value.length),
            );
          }
        });
      },
      keyboardType: widget.numeric ? TextInputType.number : (widget.maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: widget.maxLines,
      minLines: widget.maxLines,
      style: style,
      cursorColor: widget.hiddenText ? transparent : p.tx,
      showCursor: !widget.hiddenText,
      cursorWidth: 1,
      enableInteractiveSelection: !widget.hiddenText,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        isCollapsed: true,
        isDense: true,
        border: InputBorder.none,
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: const Color(0xFF757575)),
        hintMaxLines: widget.maxLines,
        contentPadding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
    return Container(
      height: widget.height,
      padding: widget.pad,
      alignment: widget.maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
      decoration: widget.border ? box(bg: p.bg, w: 2, c: p.tx) : null,
      child: SizedBox(height: widget.fs * 1.4 * widget.maxLines, child: field),
    );
  }
}
