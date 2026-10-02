import 'dart:math' as math;
import 'dart:ui' show FontFeature, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Colour tokens from the design (`[data-hz]` CSS variables).
class Pal {
  const Pal({required this.bg, required this.sf, required this.tx, required this.mu, required this.ac, required this.ai, required this.ab, required this.ad, required this.dv, required this.hl, required this.tk, required this.page, required this.gn, required this.gb});
  final Color bg, sf, tx, mu, ac, ai, ab, ad, dv, hl, tk, page, gn, gb;

  static const light = Pal(bg: Color(0xFFF3F2F2), sf: Color(0xFFEAE9E9), tx: Color(0xFF201E1D), mu: Color(0xFF605D5D), ac: Color(0xFFEC3013), ai: Color(0xFFF8F4F4), ab: Color(0xFFFFE0D9), ad: Color(0xFFAE1800), dv: Color.fromRGBO(32, 30, 29, .4), hl: Color.fromRGBO(32, 30, 29, .16), tk: Color(0xFFBAB6B6), page: Color(0xFFDCDAD9), gn: Color(0xFF1F7A3D), gb: Color(0xFFDCEFE0));
  static const dark = Pal(bg: Color(0xFF161514), sf: Color(0xFF24221F), tx: Color(0xFFF0EEEE), mu: Color(0xFFBAB6B6), ac: Color(0xFFFF563C), ai: Color(0xFF161514), ab: Color(0xFF4D170E), ad: Color(0xFFFF9783), dv: Color.fromRGBO(240, 238, 238, .36), hl: Color.fromRGBO(240, 238, 238, .14), tk: Color(0xFF4A4646), page: Color(0xFF0C0B0B), gn: Color(0xFF5FCF86), gb: Color(0xFF133A22));
}

class PalScope extends InheritedWidget {
  const PalScope({super.key, required this.pal, required super.child});
  final Pal pal;
  static Pal of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<PalScope>()!.pal;
  @override
  bool updateShouldNotify(PalScope old) => old.pal != pal;
}

const transparent = Color(0x00000000);

FontWeight fw(int w) => switch (w) {
  400 => FontWeight.w400,
  500 => FontWeight.w500,
  600 => FontWeight.w600,
  700 => FontWeight.w700,
  800 => FontWeight.w800,
  _ => FontWeight.w400,
};

/// Text with CSS-like props. `ls` is letter-spacing in em, `lh` the unitless line-height.
class T extends StatelessWidget {
  const T(this.text, {super.key, this.s, this.w, this.c, this.ls, this.lh, this.upper = false, this.tab = false, this.mono = false, this.ell = false, this.nowrap = false, this.align, this.balance = false, this.underline = false});
  final String text;
  final double? s, ls, lh;
  final int? w;
  final Color? c;
  final bool upper, tab, mono, ell, nowrap, balance, underline;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    // `font: 11px 'JetBrains Mono'` resets line-height to normal: rounded ascent + descent.
    final size = s ?? DefaultTextStyle.of(context).style.fontSize ?? 16;
    final lineH = lh ?? (mono ? ((1.02 * size).round() + (.3 * size).round()) / size : null);
    var style = cssStyle(DefaultTextStyle.of(context).style, s: s, w: w, c: c, ls: ls, lh: lineH, tab: tab, mono: mono);
    if (underline) style = style.copyWith(decoration: TextDecoration.underline, decorationColor: style.color);
    final t = upper ? text.toUpperCase() : text;
    final Widget out;
    if (ell) {
      out = Text(t, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, textAlign: align);
    } else if (nowrap) {
      out = Text(t, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: align);
    } else if (balance) {
      out = _Balanced(t, style: style);
    } else {
      out = Text(t, style: style, textAlign: align);
    }
    return CssLine(style: style, child: out);
  }
}

/// Gives a text block CSS line-box geometry: each line is exactly
/// `font-size × line-height` tall (Flutter rounds it to whole pixels) and the
/// first baseline sits where Blink puts it (rounded ascent plus floored
/// half-leading).
class CssLine extends SingleChildRenderObjectWidget {
  const CssLine({super.key, required this.style, required super.child});
  final TextStyle style;

  static (double, double) _metrics(TextStyle st) => st.fontFamily == 'JetBrainsMono' ? (1.02, .3) : (.878, .21);

  /// `line-height: normal` (no height set) is the rounded ascent + descent.
  static double _lh(TextStyle st) {
    if (st.height != null) return st.height!;
    final fs = st.fontSize ?? 16, m = _metrics(st);
    return ((m.$1 * fs).round() + (m.$2 * fs).round()) / fs;
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    final m = _metrics(style);
    return RenderCssLine(style.fontSize ?? 16, _lh(style), m.$1, m.$2, style.letterSpacing ?? 0);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCssLine renderObject) {
    final r = renderObject;
    final m = _metrics(style);
    r
      ..fontSize = style.fontSize ?? 16
      ..lh = _lh(style)
      ..asc = m.$1
      ..desc = m.$2
      ..ls = style.letterSpacing ?? 0;
    r.markNeedsLayout();
  }
}

class RenderCssLine extends RenderShiftedBox {
  RenderCssLine(this.fontSize, this.lh, this.asc, this.desc, this.ls) : super(null);
  double fontSize, lh, asc, desc, ls;

  double get _line => (fontSize * lh * 64).round() / 64;
  double get _baseline {
    final a = (asc * fontSize).roundToDouble(), d = (desc * fontSize).roundToDouble();
    // Blink floors the half-leading to whole pixels.
    return ((_line - (a + d)) / 2).floorToDouble() + a;
  }

  double _height(double childH) {
    final n = (childH / _line).round();
    return (n < 1 ? 1 : n) * _line;
  }

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) => _height(child?.getMinIntrinsicHeight(width) ?? 0);
  @override
  double computeMaxIntrinsicHeight(double width) => _height(child?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final s = c.getDryLayout(constraints.loosen().copyWith(minWidth: constraints.minWidth, maxHeight: double.infinity));
    return constraints.constrain(Size(s.width, _height(s.height)));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints.loosen().copyWith(minWidth: constraints.minWidth, maxHeight: double.infinity), parentUsesSize: true);
    final fb = c.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0;
    // Flutter splits letter-spacing around each glyph; CSS puts it all after.
    (c.parentData! as BoxParentData).offset = Offset(-ls / 2, _baseline - fb);
    size = constraints.constrain(Size(c.size.width, _height(c.size.height)));
  }
}

TextStyle cssStyle(TextStyle base, {double? s, int? w, Color? c, double? ls, double? lh, bool tab = false, bool mono = false}) {
  final size = s ?? base.fontSize ?? 16;
  return base.copyWith(fontSize: s, fontWeight: w != null ? fw(w) : null, color: c, letterSpacing: ls != null ? ls * size : null, height: lh, fontFeatures: tab ? const [FontFeature.tabularFigures()] : null, fontFamily: mono ? 'JetBrainsMono' : null);
}

/// TextSpan with CSS-like props, for inline runs.
TextSpan sp(BuildContext context, String text, {double? s, int? w, Color? c, double? ls, List<InlineSpan>? children}) {
  final base = DefaultTextStyle.of(context).style;
  return TextSpan(
    text: text,
    style: TextStyle(fontSize: s, fontWeight: w != null ? fw(w) : null, color: c, letterSpacing: ls != null ? ls * (s ?? base.fontSize ?? 16) : null),
    children: children,
  );
}

class Rich extends StatelessWidget {
  const Rich(this.spans, {super.key, this.s, this.w, this.c, this.lh, this.align});
  final List<InlineSpan> spans;
  final double? s, lh;
  final int? w;
  final Color? c;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) {
    final style = cssStyle(DefaultTextStyle.of(context).style, s: s, w: w, c: c, lh: lh);
    // The tallest inline box sets the CSS line height.
    var max = style.fontSize ?? 16;
    for (final sp in spans) {
      final fs = sp.style?.fontSize;
      if (fs != null && fs > max) max = fs;
    }
    return CssLine(
      style: style.copyWith(fontSize: max),
      child: Text.rich(
        TextSpan(style: style, children: spans),
        textAlign: align,
      ),
    );
  }
}

/// `text-wrap: balance`, ported from Blink's ScoreLineBreaker: break points
/// minimise the sum of squared slack over all lines (plus an orphan penalty on
/// the last break), keeping the greedy line count.
class _Balanced extends StatelessWidget {
  const _Balanced(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final avail = box.maxWidth;
        if (!avail.isFinite) return Text(text, style: style);
        // One box per line so lines sit exactly `font-size × line-height` apart.
        final lines = _balance(avail).split('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in lines)
              CssLine(
                style: style.copyWith(letterSpacing: 0),
                child: Text(l, style: style, softWrap: false),
              ),
          ],
        );
      },
    );
  }

  String _balance(double avail) {
    final words = text.split(' ');
    if (words.length < 4) return text;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: avail);
    final greedyLines = tp.computeLineMetrics().length;
    tp.layout();
    // Word extents on one unbroken line.
    final starts = <double>[], ends = <double>[];
    var off = 0;
    for (final w in words) {
      final bx = tp.getBoxesForSelection(TextSelection(baseOffset: off, extentOffset: off + w.length));
      starts.add(bx.isEmpty ? 0 : bx.first.left);
      ends.add(bx.isEmpty ? 0 : bx.last.right);
      off += w.length + 1;
    }
    tp.dispose();
    // Candidates: start sentinel (-1), a break after each word but the last, end sentinel.
    final n = words.length;
    final fontSize = style.fontSize ?? 16;
    final linePenalty = avail * fontSize * 4;
    double penalty(int c) => c == n - 2 ? 10000 : 0; // orphans: discourage a lone last word
    // pos_no_break of candidate c = start of word c+1; pos_if_break = end of word c.
    double posNoBreak(int c) => c < 0 ? 0 : starts[c + 1];
    double posIfBreak(int c) => ends[c];
    final cands = [-1, for (var i = 0; i < n - 1; i++) i, n - 1];
    final score = List<double>.filled(cands.length, double.infinity);
    final prev = List<int>.filled(cands.length, 0);
    final lines = List<int>.filled(cands.length, 0);
    score[0] = 0;
    for (var e = 1; e < cands.length; e++) {
      var best = double.infinity;
      var bestPrev = 0;
      for (var st = 0; st < e; st++) {
        if (!score[st].isFinite) continue;
        final delta = avail + 1 / 64 - (posIfBreak(cands[e]) - posNoBreak(cands[st]));
        final ws = delta < 0 ? 1e12 : delta * delta;
        final sc = score[st] + ws;
        if (sc <= best) {
          best = sc;
          bestPrev = st;
        }
      }
      score[e] = best + (e == cands.length - 1 ? 0 : penalty(cands[e])) + linePenalty;
      prev[e] = bestPrev;
      lines[e] = lines[bestPrev] + 1;
    }
    if (lines.last != greedyLines) return text;
    final breaks = <int>{};
    for (var i = cands.length - 1; i > 0; i = prev[i]) {
      if (i != cands.length - 1) breaks.add(cands[i]);
    }
    final sb = StringBuffer();
    for (var i = 0; i < n; i++) {
      sb.write(words[i]);
      if (i < n - 1) sb.write(breaks.contains(i) ? '\n' : ' ');
    }
    return sb.toString();
  }
}

/// CSS text inheritance (font-size, weight, color) for a subtree.
class Css extends StatelessWidget {
  const Css({super.key, this.s, this.w, this.c, this.lh, this.ls, required this.child});
  final double? s, lh, ls;
  final int? w;
  final Color? c;
  final Widget child;
  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: cssStyle(DefaultTextStyle.of(context).style, s: s, w: w, c: c, lh: lh, ls: ls),
    child: child,
  );
}

/// Uppercase label: 11px, 600, letter-spacing .1em, line-height 1.3.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.c, this.s = 11, this.ls = .1, this.ell = false, this.nowrap = false});
  final String text;
  final Color? c;
  final double s, ls;
  final bool ell, nowrap;
  @override
  Widget build(BuildContext context) => T(text, s: s, w: 600, ls: ls, lh: 1.3, upper: true, c: c ?? PalScope.of(context).mu, ell: ell, nowrap: nowrap);
}

/// Pill tag (`font-size:10px;font-weight:600;letter-spacing:.08em;uppercase;padding:3px 7px`).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.bg, this.fg});
  final String text;
  final Color bg;
  final Color? fg;
  @override
  Widget build(BuildContext context) => Container(
    color: bg,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    child: T(text, s: 10, w: 600, ls: .08, lh: 1.3, upper: true, c: fg),
  );
}

// ---------------------------------------------------------------- borders

BorderSide bs(double w, Color c) => BorderSide(width: w, color: c);

BoxDecoration box({Color? bg, double? w, Color? c, Border? border}) => BoxDecoration(
  color: bg,
  border: border ?? (w != null ? Border.all(width: w, color: c!) : null),
);

/// A box whose border is CSS `dashed`.
class Dashed extends StatelessWidget {
  const Dashed({super.key, required this.color, this.width = 2, this.bg, this.padding, required this.child});
  final Color color;
  final double width;
  final Color? bg;
  final EdgeInsets? padding;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashPainter(color, width, bg),
    child: Padding(padding: EdgeInsets.all(width) + (padding ?? EdgeInsets.zero), child: child),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.width, this.bg);
  final Color color;
  final double width;
  final Color? bg;

  @override
  void paint(Canvas canvas, Size size) {
    if (bg != null) canvas.drawRect(Offset.zero & size, Paint()..color = bg!);
    final p = Paint()..color = color;
    final w = width;
    // Chrome: dash = 3×width, gap = 3×width, both stretched so corners are solid.
    void edge(double len, void Function(double a, double b) draw) {
      final dash = 3 * w;
      if (len <= dash * 2) {
        draw(0, len);
        return;
      }
      final count = ((len + dash) / (2 * dash)).round().clamp(1, 1 << 20);
      final unit = len / (2 * count - 1);
      for (var i = 0; i < count; i++) {
        draw(i * 2 * unit, i * 2 * unit + unit);
      }
    }

    edge(size.width, (a, b) {
      canvas.drawRect(Rect.fromLTRB(a, 0, b, w), p);
      canvas.drawRect(Rect.fromLTRB(a, size.height - w, b, size.height), p);
    });
    edge(size.height, (a, b) {
      canvas.drawRect(Rect.fromLTRB(0, a, w, b), p);
      canvas.drawRect(Rect.fromLTRB(size.width - w, a, size.width, b), p);
    });
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color || o.width != width || o.bg != bg;
}

/// `repeating-linear-gradient(<angle>, c 0 a, transparent a b)`.
class Hatch extends CustomPainter {
  Hatch(this.color, this.a, this.b, {this.angle = 135, this.base});
  final Color color;
  final double a, b, angle;
  final Color? base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (base != null) canvas.drawColor(base!, BlendMode.src);
    final p = Paint()
      ..color = color
      ..isAntiAlias = true;
    final rad = angle * math.pi / 180;
    final dx = math.sin(rad), dy = -math.cos(rad);
    // CSS gradient line: centred, length |w sin| + |h cos|; t=0 at its start.
    final len = (size.width * dx).abs() + (size.height * dy).abs();
    final cx = size.width / 2, cy = size.height / 2;
    final sx = cx - dx * len / 2, sy = cy - dy * len / 2;
    final px = -dy, py = dx; // perpendicular
    final far = size.width + size.height;
    for (var t = 0.0; t < len; t += b) {
      final t1 = t, t2 = math.min(t + a, len);
      final ax = sx + dx * t1, ay = sy + dy * t1, bx = sx + dx * t2, by = sy + dy * t2;
      final path = Path()
        ..moveTo(ax - px * far, ay - py * far)
        ..lineTo(ax + px * far, ay + py * far)
        ..lineTo(bx + px * far, by + py * far)
        ..lineTo(bx - px * far, by - py * far)
        ..close();
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(Hatch o) => o.color != color || o.a != a || o.b != b || o.angle != angle || o.base != base;
}

/// Striped photo placeholder: `repeating-linear-gradient(135deg, sf 0 a, bg a 2a)`.
class Stripes extends StatelessWidget {
  const Stripes({super.key, required this.step, this.border, this.child, this.height, this.width});
  final double step;
  final Border? border;
  final Widget? child;
  final double? height, width;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    return Container(
      height: height,
      width: width,
      foregroundDecoration: border != null ? BoxDecoration(border: border) : null,
      child: CustomPaint(
        painter: Hatch(p.sf, step, step * 2, base: p.bg),
        child: border != null && child != null ? Padding(padding: border!.dimensions, child: child) : child,
      ),
    );
  }
}

/// CSS `box-shadow: inset …` used as a coloured bar on one edge.
enum Edge { top, bottom, left }

class InsetBar extends StatelessWidget {
  const InsetBar({super.key, required this.edge, required this.size, required this.color, this.bg, required this.child});
  final Edge edge;
  final double size;
  final Color color;
  final Color? bg;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BarPainter(edge, size, color, bg), child: child);
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.edge, this.size, this.color, this.bg);
  final Edge edge;
  final double size;
  final Color color;
  final Color? bg;
  @override
  void paint(Canvas canvas, Size s) {
    if (bg != null) canvas.drawRect(Offset.zero & s, Paint()..color = bg!);
    final r = switch (edge) {
      Edge.top => Rect.fromLTWH(0, 0, s.width, size),
      Edge.bottom => Rect.fromLTWH(0, s.height - size, s.width, size),
      Edge.left => Rect.fromLTWH(0, 0, size, s.height),
    };
    canvas.drawRect(r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.edge != edge || o.size != size || o.color != color || o.bg != bg;
}

// ---------------------------------------------------------------- interaction

/// A `<button>`: whole box is the hit target, pointer cursor.
class Tap extends StatelessWidget {
  const Tap({super.key, required this.onTap, required this.child, this.enabled = true});
  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
  );
}

/// Horizontal or vertical scroller without scrollbars or overscroll glow.
/// F18: a full-height screen that scrolls when it doesn't fit (small phones,
/// keyboard open) while a Spacer still pushes the buttons to the bottom.
class FillScroll extends StatelessWidget {
  const FillScroll({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Scroll(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}

class Scroll extends StatelessWidget {
  const Scroll({super.key, required this.child, this.horizontal = false, this.controller});
  final Widget child;
  final bool horizontal;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const _NoBars(),
    child: SingleChildScrollView(controller: controller, scrollDirection: horizontal ? Axis.horizontal : Axis.vertical, physics: const ClampingScrollPhysics(), child: child),
  );
}

class _NoBars extends ScrollBehavior {
  const _NoBars();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Vertical stack with a gap, children stretched (CSS grid with `gap`).
class VGap extends StatelessWidget {
  const VGap({super.key, required this.gap, required this.children, this.stretch = true, this.padding});
  final double gap;
  final List<Widget> children;
  final bool stretch;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && gap > 0) out.add(SizedBox(height: gap));
      out.add(children[i]);
    }
    final col = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: out);
    return padding != null ? Padding(padding: padding!, child: col) : col;
  }
}

/// Wrap spacing helper.
Widget wrap(double gap, List<Widget> children) => Wrap(spacing: gap, runSpacing: gap, children: children);

// ---------------------------------------------------------------- icons

const _svgIcons = <String, String>{
  'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  'pin': '<path d="M20 10c0 5-5.5 10.2-7.4 11.8a1 1 0 0 1-1.2 0C9.5 20.2 4 15 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>',
  'home': '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .7-1.5l7-6a2 2 0 0 1 2.6 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  'user': '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  'heart': '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>',
  'bed': '<path d="M2 4v16"/><path d="M2 8h18a2 2 0 0 1 2 2v10"/><path d="M2 17h20"/><path d="M6 8v9"/>',
  'wallet': '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
  'utensils': '<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"/><path d="M7 2v20"/><path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
  'wrench': '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.8-3.8a6 6 0 0 1-7.9 7.9l-6.9 6.9a2.1 2.1 0 0 1-3-3l6.9-6.9a6 6 0 0 1 7.9-7.9l-3.8 3.8z"/>',
  'plus': '<path d="M5 12h14"/><path d="M12 5v14"/>',
  'back': '<path d="m15 18-6-6 6-6"/>',
  'chev': '<path d="m9 18 6-6-6-6"/>',
  'arrow': '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
  'x': '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  'chevD': '<path d="m6 9 6 6 6-6"/>',
  'copy': '<path d="M8 8h12v12H8z"/><path d="M4 16V4h12"/>',
  'check': '<path d="M20 6 9 17l-5-5"/>',
  'msg': '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
  'clock': '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  'grid': '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/>',
  'list': '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>',
  'building': '<rect x="4" y="2" width="16" height="20"/><path d="M9 22v-4h6v4"/><path d="M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01"/>',
  'star': '<path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z" fill="currentColor" stroke="none"/>',
  'bell': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.9 1.9 0 0 0 3.4 0"/>',
  'logout': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
  'chart': '<path d="M3 3v18h18"/><path d="M18 17V9"/><path d="M13 17V5"/><path d="M8 17v-3"/>',
  'inbox': '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.5 5.1 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.5-6.9A2 2 0 0 0 16.8 4H7.2a2 2 0 0 0-1.7 1.1z"/>',
  'phone': '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
  'shield': '<path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/>',
  'shieldOk': '<path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
  'userPlus': '<path d="M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1"/><circle cx="9.5" cy="7" r="3.5"/><path d="M19 8v6M16 11h6"/>',
  'qr': '<path d="M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3z"/><path d="M14 14h3v3h-3zM21 14v1M14 21h1M18 18h3v3"/>',
  'warn': '<path d="M12 3 2 21h20z"/><path d="M12 10v5M12 18h.01"/>',
  'print': '<path d="M6 9V3h12v6M6 18H3v-8h18v8h-3M6 14h12v7H6z"/>',
  'fan': '<circle cx="12" cy="12" r="2"/><path d="M12 10V3M14 13l6 3.5M10 13l-6 3.5"/>',
  'pencil': '<path d="M3 21h4L20 8l-4-4L3 17z"/><path d="m14 6 4 4"/>',
  'room': '<path d="M3 3h18v18H3z"/><path d="M3 15h6v6M14 3v4"/>',
  'globe': '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20 15 15 0 0 1 0-20"/>',
  'doc': '<path d="M6 2h9l5 5v15H6z"/><path d="M14 2v6h6M9 13h8M9 17h8"/>',
  'trash': '<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14"/>',
  'camera': '<path d="M3 7h4l2-3h6l2 3h4v13H3z"/><circle cx="12" cy="13" r="4"/>',
  'lock': '<path d="M5 11h14v10H5z"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  'flag': '<path d="M5 21V4h12l-2 4 2 4H5"/>',
  'swap': '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
};

/// Lucide-style stroke icon, 1em square, `currentColor`.
class Ic extends StatelessWidget {
  const Ic(this.name, {super.key, required this.size, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter">${_svgIcons[name]}</svg>';
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        svg,
        width: size,
        height: size,
        theme: SvgTheme(currentColor: c),
      ),
    );
  }
}

/// A CSS flex row (`display:flex; justify-content:space-between`): items start
/// at their max-content width and, when they don't fit, shrink in proportion
/// to that width down to their min-content width, wrapping their text.
class CssRow extends MultiChildRenderObjectWidget {
  const CssRow({super.key, required super.children, this.gap = 0, this.baseline = false});
  final double gap;
  final bool baseline;
  @override
  RenderObject createRenderObject(BuildContext context) => RenderCssRow(gap, baseline);
  @override
  void updateRenderObject(BuildContext context, RenderCssRow renderObject) {
    final r = renderObject;
    r
      ..gap = gap
      ..baseline = baseline
      ..markNeedsLayout();
  }
}

class _CssRowData extends ContainerBoxParentData<RenderBox> {}

class RenderCssRow extends RenderBox with ContainerRenderObjectMixin<RenderBox, _CssRowData>, RenderBoxContainerDefaultsMixin<RenderBox, _CssRowData> {
  RenderCssRow(this.gap, this.baseline);
  double gap;
  bool baseline;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CssRowData) child.parentData = _CssRowData();
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  List<double> _widths(double avail) {
    final kids = _kids;
    final basis = [for (final k in kids) k.getMaxIntrinsicWidth(double.infinity)];
    final mins = [for (final k in kids) k.getMinIntrinsicWidth(double.infinity)];
    final gaps = gap * (kids.length - 1);
    final sizes = List.of(basis);
    if (!avail.isFinite || basis.fold<double>(0, (a, b) => a + b) + gaps <= avail) return sizes;
    final frozen = List<bool>.filled(kids.length, false);
    for (var pass = 0; pass < kids.length + 1; pass++) {
      var fixed = 0.0, scaled = 0.0, sumBasis = 0.0;
      for (var i = 0; i < kids.length; i++) {
        if (frozen[i]) {
          fixed += sizes[i];
        } else {
          scaled += basis[i];
          sumBasis += basis[i];
        }
      }
      final free = avail - gaps - fixed - sumBasis;
      if (free >= 0 || scaled == 0) break;
      var clamped = false;
      for (var i = 0; i < kids.length; i++) {
        if (frozen[i]) continue;
        final target = basis[i] + free * basis[i] / scaled;
        if (target < mins[i]) {
          sizes[i] = mins[i];
          frozen[i] = true;
          clamped = true;
        } else {
          sizes[i] = target;
        }
      }
      if (!clamped) break;
    }
    return sizes;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _kids.fold<double>(0, (a, k) => a + k.getMinIntrinsicWidth(height)) + gap * (childCount - 1);
  @override
  double computeMaxIntrinsicWidth(double height) => _kids.fold<double>(0, (a, k) => a + k.getMaxIntrinsicWidth(height)) + gap * (childCount - 1);
  @override
  double computeMinIntrinsicHeight(double width) {
    final kids = _kids, w = _widths(width);
    var h = 0.0;
    for (var i = 0; i < kids.length; i++) {
      final v = kids[i].getMinIntrinsicHeight(w[i]);
      if (v > h) h = v;
    }
    return h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    final kids = _kids;
    final avail = constraints.maxWidth;
    final w = _widths(avail);
    var h = 0.0, maxAbove = 0.0, maxBelow = 0.0;
    for (var i = 0; i < kids.length; i++) {
      kids[i].layout(BoxConstraints.tightFor(width: w[i]), parentUsesSize: true);
      final s = kids[i].size;
      if (s.height > h) h = s.height;
      if (baseline) {
        final bl = kids[i].getDistanceToBaseline(TextBaseline.alphabetic) ?? s.height;
        if (bl > maxAbove) maxAbove = bl;
        if (s.height - bl > maxBelow) maxBelow = s.height - bl;
      }
    }
    if (baseline) h = maxAbove + maxBelow;
    final used = w.fold<double>(0, (a, b) => a + b) + gap * (kids.length - 1);
    final width = avail.isFinite ? avail : used;
    final extra = kids.length > 1 && width > used ? (width - used) / (kids.length - 1) : 0.0;
    var x = 0.0;
    for (var i = 0; i < kids.length; i++) {
      final y = baseline ? maxAbove - (kids[i].getDistanceToBaseline(TextBaseline.alphabetic) ?? kids[i].size.height) : 0.0;
      (kids[i].parentData! as _CssRowData).offset = Offset(x, y);
      x += w[i] + gap + extra;
    }
    size = constraints.constrain(Size(width, h));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// The Hostelzy room mark (logo B3-a2). [mono] paints it in one colour, for
/// the red Welcome screen where the red bed would disappear.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, this.mono});
  final double size;
  final Color? mono;
  @override
  Widget build(BuildContext context) {
    final dark = PalScope.of(context).bg.computeLuminance() < .2;
    if (mono != null) {
      return SvgPicture.asset('assets/brand/mark-mono.svg', width: size, height: size, colorFilter: ColorFilter.mode(mono!, BlendMode.srcIn));
    }
    return SvgPicture.asset(dark ? 'assets/brand/mark-dark.svg' : 'assets/brand/mark-light.svg', width: size, height: size);
  }
}
