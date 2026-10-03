import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../data.dart';

// ------------------------------------------------------------ F12 room layouts

/// A bed on a layout is 2.7 × 5.4 ft ("3 × 6 ft" with its gap).
const bedW = 2.7, bedH = 5.4;

/// A fan covers about 4 ft around it ("Under a fan").
const fanReach = 4.0;

/// F24 item 11: room shapes the owner picks before drawing. Custom is drawn
/// by the Hostelzy team on request (48 h).
const layoutShapes = ['Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom'];

/// The outline of a preset [shape] in a [w] × [h] ft box, clockwise from the
/// top-left corner, on a half-foot grid. Null for a rectangle (and Custom,
/// which the team draws).
List<Offset>? shapeOutline(String shape, double w, double h) {
  double r(double v) => (v * 2).roundToDouble() / 2;
  final pts = switch (shape) {
    // The top-right corner is cut out.
    'L shape' => [Offset.zero, Offset(r(w * .55), 0), Offset(r(w * .55), r(h * .45)), Offset(w, r(h * .45)), Offset(w, h), Offset(0, h)],
    // A full-width top, a narrower part below.
    'T shape' => [Offset.zero, Offset(w, 0), Offset(w, r(h * .45)), Offset(r(w * .8), r(h * .45)), Offset(r(w * .8), h), Offset(r(w * .2), h), Offset(r(w * .2), r(h * .45)), Offset(0, r(h * .45))],
    // A notch in the middle of the top wall.
    'U shape' => [Offset.zero, Offset(r(w * .3), 0), Offset(r(w * .3), r(h * .4)), Offset(r(w * .7), r(h * .4)), Offset(r(w * .7), 0), Offset(w, 0), Offset(w, h), Offset(0, h)],
    'Angled corner' => [Offset.zero, Offset(r(w - math.min(w, h) * .35), 0), Offset(w, r(math.min(w, h) * .35)), Offset(w, h), Offset(0, h)],
    // The bottom wall is shorter than the top one.
    'Narrow end' => [Offset.zero, Offset(w, 0), Offset(r(w * .78), h), Offset(r(w * .22), h)],
    // A small recess in the bottom wall (a cupboard or a pillar bay).
    'Alcove' => [Offset.zero, Offset(w, 0), Offset(w, h), Offset(r(w * .62), h), Offset(r(w * .62), r(h - 2.5)), Offset(r(w * .38), r(h - 2.5)), Offset(r(w * .38), h), Offset(0, h)],
    _ => null,
  };
  return pts;
}

bool _inPoly(List<Offset> poly, Offset p) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
  }
  return inside;
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  final t = len2 == 0 ? 0.0 : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
}

/// Inside the outline, or within [tol] ft of its walls.
bool inOutline(List<Offset> poly, Offset p, {double tol = 0}) {
  if (_inPoly(poly, p)) return true;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    if (_segDist(p, poly[j], poly[i]) <= tol) return true;
  }
  return false;
}

/// Hostels whose rooms Hostelzy has drawn. The rest show "Layout coming soon".
const layoutHostels = ['anjani', 'saisri', 'nest42', 'orchid'];

/// One drawn item. [kind]: fan | ac | window | door | wash | pillar. Feet
/// from the room's top-left corner; the team moves them in the editor.
class LItem {
  LItem(this.id, this.kind, this.x, this.y, this.w, this.h, {this.facing, this.working = true});
  final String id, kind;
  double x, y, w, h;

  /// Window: street | courtyard | building.
  String? facing;
  bool working;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
  LItem copy() => LItem(id, kind, x, y, w, h, facing: facing, working: working);
}

/// Which wall an item sits on: top | bottom | left | right (null = inside).
String? wallOf(Rect r, double w, double h) {
  if (r.top < .5) return 'top';
  if (r.bottom > h - .5) return 'bottom';
  if (r.left < .5) return 'left';
  if (r.right > w - .5) return 'right';
  return null;
}

/// A saved state of a layout, for undo / redo in the editor.
/// F24: [shape] is the room's shape name and [outline] its walls (null = a
/// plain rectangle of w × h).
typedef LayoutSnap = ({double w, double h, Map<String, Offset> beds, List<LItem> items, Map<String, String> bunks, String shape, List<Offset>? outline});

/// An empty snapshot (a quick fix has no layout).
const LayoutSnap emptySnap = (w: 0, h: 0, beds: <String, Offset>{}, items: <LItem>[], bunks: <String, String>{}, shape: 'Rectangle', outline: null);

/// F19: a resident's suggested fix to a room layout. The owner (and the
/// team after 7 days) approves or rejects it; tenants never see who sent it.
class LayoutFix {
  LayoutFix({required this.id, required this.hid, required this.room, required this.snap, required this.at, this.note = '', this.status = 'pending', this.author = '', this.authorBed = '', this.since = '', this.reason, this.decidedAt, this.mine = false, this.baseVersion = 1, this.kind = 'layout', this.issue, this.item, this.photo, this.repair, this.authorId = ''});
  final String id, hid;
  final int room;
  final LayoutSnap snap;
  final String note, author, authorBed, since;

  /// F19 extras: layout | quick (one item: wrong_place | missing | broken |
  /// not_here); the photo (storage path, or a local key on sample data); a
  /// Broken quick fix's repair: working | not_broken.
  final String kind;
  final String? issue, item, photo;
  String? repair;

  /// Who sent it (for muting).
  final String authorId;

  bool get quick => kind == 'quick';
  bool get broken => quick && issue == 'broken';

  /// "AC unit is broken", "Fan is in the wrong place".
  String get quickLine => switch (issue) {
    'broken' => '$item is broken',
    'missing' => 'There’s no ${lowerName(item ?? '')} in this room',
    'not_here' => '$item isn’t in this room',
    _ => '$item is in the wrong place',
  };

  /// pending | approved | rejected | withdrawn
  String status;
  String? reason;

  /// When it was sent / decided (ms).
  final int at;
  int? decidedAt;

  /// Sent from this phone (the resident's own).
  final bool mine;

  /// The live version it was drawn on.
  final int baseVersion;
}

/// F19: a layout as JSON for the server ({w, h, beds: {A: [x, y]}, items, bunks}).
Map<String, dynamic> layoutJson(LayoutSnap l) => {
  'w': l.w,
  'h': l.h,
  'beds': {for (final e in l.beds.entries) e.key: [e.value.dx, e.value.dy]},
  'items': [for (final i in l.items) {'id': i.id, 'kind': i.kind, 'x': i.x, 'y': i.y, 'w': i.w, 'h': i.h, if (i.facing != null) 'facing': i.facing, 'working': i.working}],
  'bunks': l.bunks,
  if (l.shape != 'Rectangle') 'shape': l.shape,
  if (l.outline != null) 'outline': [for (final p in l.outline!) [p.dx, p.dy]],
};

/// F24: a saved outline (`[[x, y], …]`) back to points; null when missing.
List<Offset>? outlineFromJson(Object? o) {
  if (o is! List || o.length < 3) return null;
  return [for (final p in o.cast<List>()) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())];
}

/// F19: [layoutJson] back to a snapshot.
LayoutSnap snapFromJson(Map<String, dynamic> j) {
  num n(Object? v) => v as num? ?? 0;
  return (
    w: n(j['w']).toDouble(),
    h: n(j['h']).toDouble(),
    beds: {for (final e in (j['beds'] as Map? ?? const {}).entries) e.key as String: Offset(n((e.value as List)[0]).toDouble(), n(e.value[1]).toDouble())},
    items: [
      for (final i in (j['items'] as List? ?? const []).cast<Map>()) LItem(i['id'] as String, i['kind'] as String, n(i['x']).toDouble(), n(i['y']).toDouble(), n(i['w']).toDouble(), n(i['h']).toDouble(), facing: i['facing'] as String?, working: i['working'] as bool? ?? true),
    ],
    bunks: {for (final e in (j['bunks'] as Map? ?? const {}).entries) e.key as String: e.value as String},
    shape: j['shape'] as String? ?? 'Rectangle',
    outline: outlineFromJson(j['outline']),
  );
}

/// F19: what a fix changes, in words, and which things moved (for the red
/// outline): "Fan 1" · "moved", "AC unit" · "right → left wall".
({List<(String, String)> lines, Set<String> ids}) layoutDiff(LayoutSnap a, LayoutSnap b) {
  const names = {'fan': 'Fan', 'ac': 'AC unit', 'window': 'Window', 'door': 'Door', 'wash': 'Washroom', 'pillar': 'Pillar'};
  final lines = <(String, String)>[], ids = <String>{};
  String nm(LItem i) {
    final same = [...a.items, ...b.items].where((x) => x.kind == i.kind).map((x) => x.id).toSet();
    return same.length > 1 ? '${names[i.kind] ?? i.kind} ${i.id.replaceAll(RegExp(r'[^0-9]'), '')}' : names[i.kind] ?? i.kind;
  }
  for (final i in b.items) {
    final o = a.items.where((x) => x.id == i.id).firstOrNull;
    if (o == null) {
      lines.add((nm(i), 'added'));
      ids.add(i.id);
      continue;
    }
    final wo = wallOf(o.rect, a.w, a.h), wn = wallOf(i.rect, b.w, b.h);
    final changes = [
      if (wo != wn && (wo != null || wn != null)) '${wo ?? 'middle'} → ${wn ?? 'middle'}${wn == null ? '' : ' wall'}'
      else if (o.x != i.x || o.y != i.y) 'moved',
      if ((o.w != i.w || o.h != i.h) && wo == wn) 'turned',
      if (o.working != i.working) i.working ? 'working' : 'not working',
      if (o.facing != i.facing && i.facing != null) 'faces ${i.facing}',
    ];
    if (changes.isNotEmpty) {
      lines.add((nm(i), changes.join(' · ')));
      ids.add(i.id);
    }
  }
  for (final o in a.items) {
    if (!b.items.any((x) => x.id == o.id)) lines.add((nm(o), 'taken off'));
  }
  for (final k in b.beds.keys.toList()..sort()) {
    if (a.beds[k] != b.beds[k]) {
      lines.add(('Bed $k', a.beds.containsKey(k) ? 'moved' : 'added'));
      ids.add('bed:$k');
    }
  }
  if (a.shape != b.shape) lines.add(('Shape', '${a.shape} → ${b.shape}'));
  if (a.w != b.w || a.h != b.h) lines.add(('Size', '${a.w.round()} × ${a.h.round()} → ${b.w.round()} × ${b.h.round()} ft'));
  return (lines: lines, ids: ids);
}

/// A room's layout, drawn by the Hostelzy team. Layout beds are the bed-map
/// beds (same letters). [live]: a version tenants see. [pending]: a newer
/// version waiting for the owner's approval.
class RoomLayout {
  RoomLayout({required this.hid, required this.room, required this.w, required this.h, required this.beds, required this.items, this.version = 1, this.live = true, this.pending = false, this.drawn = '28 Sep', this.verified = '28 Sep'});
  final String hid;
  final int room;
  double w, h;
  final Map<String, Offset> beds;
  final List<LItem> items;
  int version;
  bool live, pending;
  String drawn, verified;

  /// F24 item 11: the room's shape and its walls (null = a rectangle).
  String shape = 'Rectangle';
  List<Offset>? outline;

  /// What tenants see while the team edits a new version (null = this).
  LayoutSnap? published;

  /// Bunk beds: upper bed letter → the lower bed it stands on (same spot).
  final Map<String, String> bunks = {};

  /// Residents who answered "No" to "Is the room layout accurate?".
  int disputes = 0;

  /// The upper bunk on [lower], if any.
  String? upperOn(String lower) => bunks.entries.where((e) => e.value == lower).firstOrNull?.key;

  /// The layout tenants see: the last approved version.
  RoomLayout get forTenants {
    final p = published;
    if (p == null) return this;
    return RoomLayout(hid: hid, room: room, w: p.w, h: p.h, beds: Map.of(p.beds), items: [for (final i in p.items) i.copy()], version: version - 1, drawn: drawn, verified: verified)
      ..bunks.addAll(p.bunks)
      ..shape = p.shape
      ..outline = p.outline;
  }

  Rect bedRect(String letter) => Rect.fromLTWH(beds[letter]!.dx, beds[letter]!.dy, bedW, bedH);
  Rect itemRect(LItem i) => i.rect;

  /// F18 Create a layout: resize the starting rectangle to [len] × [wid] ft,
  /// keeping beds and items inside the walls.
  void mirrorTo(double len, double wid) {
    final sx = len / w, sy = wid / h;
    for (final k in beds.keys.toList()) {
      beds[k] = Offset((beds[k]!.dx * sx).roundToDouble().clamp(0, len - 3), (beds[k]!.dy * sy).roundToDouble().clamp(0, wid - 6));
    }
    for (final i in items) {
      i
        ..x = (i.x * sx).clamp(0, len - i.w)
        ..y = (i.y * sy).clamp(0, wid - i.h);
    }
    final o = outline;
    if (o != null) outline = shapeOutline(shape, len, wid) ?? [for (final p in o) Offset((p.dx * sx * 2).roundToDouble() / 2, (p.dy * sy * 2).roundToDouble() / 2)];
    w = len;
    h = wid;
  }

  /// F24: true when [r] (feet) sits inside the room's walls. Beds and floor
  /// things must be wholly inside; a window, door or AC unit may sit on a wall.
  bool fits(Rect r, {bool onWall = false}) {
    const e = .02;
    if (r.left < -e || r.top < -e || r.right > w + e || r.bottom > h + e) return false;
    final o = outline;
    if (o == null) return true;
    final tol = onWall ? .35 : .05;
    final d = onWall ? r : r.deflate(math.min(.05, math.min(r.width, r.height) / 4));
    final pts = [d.topLeft, d.topRight, d.bottomLeft, d.bottomRight, d.center, d.topCenter, d.bottomCenter, d.centerLeft, d.centerRight];
    if (!pts.every((p) => inOutline(o, p, tol: tol))) return false;
    // A corner of the walls poking into the bed means it crosses a wall.
    final inner = r.deflate(tol);
    return !o.any((p) => inner.contains(p) && p.dx > inner.left && p.dy > inner.top);
  }

  static bool _onWall(String kind) => const ['window', 'door', 'ac'].contains(kind);

  /// Beds and things that are outside the walls, by editor id (`bed:A`, `fan1`).
  List<String> get outside => [
    for (final k in beds.keys)
      if (!bunks.containsKey(k) && !fits(bedRect(k))) 'bed:$k',
    for (final i in items)
      if (!fits(i.rect, onWall: _onWall(i.kind))) i.id,
  ];

  /// The nearest spot (half-foot grid) where a [size] thing at [at] fits,
  /// away from the other beds when [avoid] is given.
  Offset? nearestFit(Offset at, Size size, {bool onWall = false, List<Rect> avoid = const []}) {
    Offset? best;
    var bd = double.infinity;
    for (var y = 0.0; y <= h - size.height + .001; y += .5) {
      for (var x = 0.0; x <= w - size.width + .001; x += .5) {
        final d = (Offset(x, y) - at).distance;
        if (d >= bd) continue;
        final r = Offset(x, y) & size;
        if (!fits(r, onWall: onWall) || avoid.any((a) => a.overlaps(r))) continue;
        best = Offset(x, y);
        bd = d;
      }
    }
    return best;
  }

  /// Moves every bed and thing outside the walls to the nearest spot inside.
  /// Returns what still doesn't fit (the room is too small for it).
  List<String> fitInside() {
    for (final id in outside) {
      if (id.startsWith('bed:')) {
        final k = id.substring(4);
        final others = [for (final o in beds.keys) if (o != k && !bunks.containsKey(o) && bunks[k] != o) bedRect(o)];
        final to = nearestFit(beds[k]!, const Size(bedW, bedH), avoid: others);
        if (to == null) continue;
        beds[k] = to;
        final up = upperOn(k);
        if (up != null) beds[up] = to;
      } else {
        final i = items.firstWhere((x) => x.id == id);
        final to = nearestFit(Offset(i.x, i.y), Size(i.w, i.h), onWall: _onWall(i.kind));
        if (to == null) continue;
        i
          ..x = to.dx
          ..y = to.dy;
      }
    }
    return outside;
  }

  /// F24: give this layout [shape] (its preset outline at the current size).
  void setShape(String s, {List<Offset>? custom}) {
    shape = s;
    outline = custom ?? shapeOutline(s, w, h);
  }

  LayoutSnap snap() => (w: w, h: h, beds: Map.of(beds), items: [for (final i in items) i.copy()], bunks: Map.of(bunks), shape: shape, outline: outline == null ? null : List.of(outline!));
  void restore(LayoutSnap s) {
    w = s.w;
    h = s.h;
    shape = s.shape;
    outline = s.outline == null ? null : List.of(s.outline!);
    beds
      ..clear()
      ..addAll(s.beds);
    items
      ..clear()
      ..addAll([for (final i in s.items) i.copy()]);
    bunks
      ..clear()
      ..addAll(s.bunks);
  }

  /// Mirror left ↔ right (or flip top ↔ bottom) for a room drawn the other way.
  void mirror({bool vertical = false}) {
    for (final k in beds.keys.toList()) {
      final b = beds[k]!;
      beds[k] = vertical ? Offset(b.dx, h - b.dy - bedH) : Offset(w - b.dx - bedW, b.dy);
    }
    for (final i in items) {
      vertical ? i.y = h - i.y - i.h : i.x = w - i.x - i.w;
    }
    final o = outline;
    if (o != null) outline = [for (final p in o.reversed) vertical ? Offset(p.dx, h - p.dy) : Offset(w - p.dx, p.dy)];
  }
  Iterable<LItem> of(String kind) => items.where((i) => i.kind == kind);
  LItem? get ac => of('ac').firstOrNull;
  LItem? get window => of('window').firstOrNull;
  LItem? get door => of('door').firstOrNull;
  LItem? get wash => of('wash').firstOrNull;

  /// The AC blows about 8.5 ft into the room from its wall: this box, in feet.
  Rect? get airflow {
    final a = ac;
    if (a == null) return null;
    final r = a.rect, c = r.center;
    double cl(double v, double max) => v.clamp(0, max).toDouble();
    return switch (wallOf(r, w, h)) {
      'left' => Rect.fromLTRB(r.right, cl(c.dy - 3.25, h), cl(r.right + 8.5, w), cl(c.dy + 3.25, h)),
      'top' => Rect.fromLTRB(cl(c.dx - 3.25, w), r.bottom, cl(c.dx + 3.25, w), cl(r.bottom + 8.5, h)),
      'bottom' => Rect.fromLTRB(cl(c.dx - 3.25, w), cl(r.top - 8.5, h), cl(c.dx + 3.25, w), r.top),
      _ => Rect.fromLTRB(cl(r.left - 8.5, w), cl(c.dy - 3.25, h), r.left, cl(c.dy + 3.25, h)),
    };
  }
}

/// F24: the editors' "inside the walls" check: (ok, line).
(bool, String) wallsCheck(RoomLayout l, String roomLabel) {
  final out = l.outside;
  if (out.isEmpty) return (true, l.outline == null ? 'Everything inside the room' : 'Everything inside the ${l.shape} walls');
  final id = out.first;
  const names = {'fan': 'A fan', 'ac': 'The AC unit', 'window': 'A window', 'door': 'The door', 'wash': 'The washroom', 'pillar': 'A pillar'};
  final what = id.startsWith('bed:') ? 'Bed $roomLabel-${id.substring(4)}' : names[l.items.firstWhere((i) => i.id == id).kind] ?? 'Something';
  return (false, '$what is outside the walls');
}

/// F24 item 11: an owner's "Ask Hostelzy to draw it" request. Done within
/// 48 hours: requested → drawing → sent (the team's drawing comes back) →
/// published (the owner published it) | cancelled.
class ShapeRequest {
  ShapeRequest({required this.id, required this.hid, required this.room, required this.shape, this.note = '', this.w = 0, this.h = 0, this.photos = const [], this.status = 'requested', required this.at, this.drawing, this.sentAt});
  final String id, hid;
  final int room;
  final String shape, note;
  final double w, h;

  /// Private photo paths (or local keys on sample data).
  final List<String> photos;
  String status;

  /// Asked at (ms); due 48 hours later.
  final int at;
  int get due => at + const Duration(hours: 48).inMilliseconds;

  /// The team's drawing ({w, h, shape, outline, beds?, items?}) once sent.
  Map<String, dynamic>? drawing;
  int? sentAt;

  bool get open => status == 'requested' || status == 'drawing' || status == 'sent';
}

/// "22 h left", "Due now".
String hoursLeft(int due, int now) {
  final h = ((due - now) / 3600000).ceil();
  return h <= 0 ? 'Due now' : (h == 1 ? '1 h left' : '$h h left');
}

String _m(double ft) {
  final m = (ft * .3048 * 2).round() / 2;
  return m == m.roundToDouble() ? '${m.round()} m' : '$m m';
}

double _distTo(Offset p, Rect r) {
  final dx = p.dx < r.left ? r.left - p.dx : (p.dx > r.right ? p.dx - r.right : 0.0);
  final dy = p.dy < r.top ? r.top - p.dy : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
  return Offset(dx, dy).distance;
}

/// What a bed is like, for the facts and the compare table. Never priced by
/// position (DECISIONS 2026-10-02).
({String fan, String? ac, String win, String door, String wash, String wall, String bunk}) bedTraits(RoomLayout l, Room r, String letter) {
  final b = l.bedRect(letter);
  final c = b.center;
  final fans = l.of('fan').where((f) => (l.itemRect(f).center - c).distance <= fanReach).toList();
  final fan = fans.isEmpty ? 'No fan overhead' : (fans.any((f) => f.working) ? 'Under a fan' : 'Fan not working');
  final air = l.airflow;
  final ac = !r.ac ? null : (r.acRepair || l.ac?.working == false ? 'AC under repair' : (air != null && air.contains(c) ? 'In the airflow' : 'Out of the airflow'));
  final wi = l.window;
  final wr = wi != null ? l.itemRect(wi) : null;
  final side = wr == null
      ? false
      : switch (wallOf(wr, l.w, l.h)) {
          'top' => b.top < 2 && b.left < wr.right && b.right > wr.left,
          'bottom' => b.bottom > l.h - 2 && b.left < wr.right && b.right > wr.left,
          'left' => b.left < 2 && b.top < wr.bottom && b.bottom > wr.top,
          'right' => b.right > l.w - 2 && b.top < wr.bottom && b.bottom > wr.top,
          _ => false,
        };
  final win = side ? 'Window side · ${wi!.facing}' : 'No window';
  final dr = l.door != null ? _distTo(c, l.itemRect(l.door!)) : 99.0;
  final door = dr * .3048 < 2.2 ? 'Near the door' : _m(dr);
  final wash = l.wash == null ? 'Outside the room' : _m(_distTo(c, l.itemRect(l.wash!)));
  final walls = (b.left < 1.5 || b.right > l.w - 1.5 ? 1 : 0) + (b.top < 1.5 || b.bottom > l.h - 1.5 ? 1 : 0);
  final wall = switch (walls) {
    2 => 'Corner',
    1 => 'One wall',
    _ => 'No wall',
  };
  final bunk = l.bunks.containsKey(letter) ? 'Upper bunk' : (l.upperOn(letter) != null ? 'Lower bunk' : 'Single bed');
  return (fan: fan, ac: ac, win: win, door: door, wash: wash, wall: wall, bunk: bunk);
}

/// "Under a fan", "Window side · faces street", "In the AC airflow", "Door 4 m away".
List<String> bedFacts(RoomLayout l, Room r, String letter) {
  final t = bedTraits(l, r, letter);
  return [
    if (t.bunk != 'Single bed') t.bunk,
    if (t.wall == 'Corner') 'Corner bed · walls on two sides',
    t.fan,
    if (t.win != 'No window') t.win.replaceFirst('· ', '· faces '),
    if (t.ac != null) t.ac == 'AC under repair' ? t.ac! : t.ac!.replaceFirst('the airflow', 'the AC airflow'),
    t.door == 'Near the door' ? t.door : 'Door ${t.door} away',
    t.wash == 'Outside the room' ? 'Common washroom outside' : 'Washroom ${t.wash} away',
  ];
}

/// The sample layout the Hostelzy team drew for room [r]: beds along the
/// walls, window on the top wall, door bottom right, attached washroom bottom
/// left, fans, and an AC unit on the right wall of AC rooms.
RoomLayout mkLayout(String hid, Room r, {required bool street}) {
  final (w, h) = switch (r.share) {
    2 => (14.0, 12.0),
    3 => (18.0, 15.0),
    _ => (20.0, 15.0),
  };
  final slots = <Offset>[
    const Offset(.8, 1.4),
    if (r.share == 2) Offset(w - 3.5, 1.4) else Offset(w / 2, 1.4),
    if (r.share >= 3) Offset(w - 3.9, h - 7.2),
    if (r.share >= 4) Offset(w / 2 - 2.5, h - 7.2),
  ];
  final fans = r.share == 2 ? [const Offset(4, 4.5)] : [Offset(w * .575, 7), Offset(w * .83, 10.75)];
  return RoomLayout(
    hid: hid,
    room: r.n,
    w: w,
    h: h,
    beds: {for (var i = 0; i < r.beds.length && i < slots.length; i++) r.beds[i].letter: slots[i]},
    items: [
      LItem('win', 'window', w * .42, 0, w * .41, .3, facing: street ? 'street' : 'courtyard'),
      LItem('door', 'door', w - 4.5, h - .2, 3, .2),
      if (r.bath == 'Attached') LItem('wash', 'wash', 0, h - 4, 5, 4),
      for (var i = 0; i < fans.length; i++) LItem('fan${i + 1}', 'fan', fans[i].dx - .5, fans[i].dy - .5, 1, 1),
      if (r.ac) LItem('ac', 'ac', w - .5, 1.3, .5, 1.8),
    ],
  );
}

/// Layouts for every room of the hostels Hostelzy has drawn. Rooms on the
/// first half of each floor face the street. Anjani 204 has a v2 waiting for
/// the owner's approval.
Map<String, Map<int, RoomLayout>> seedLayouts(Map<String, List<Room>> rooms) {
  final out = <String, Map<int, RoomLayout>>{};
  for (final hid in layoutHostels) {
    final rs = rooms[hid]!;
    out[hid] = {
      for (final r in rs)
        r.n: () {
          final floor = rs.where((x) => x.floor == r.floor).toList();
          return mkLayout(hid, r, street: floor.indexOf(r) < (floor.length + 1) ~/ 2);
        }(),
    };
  }
  // Sample bunk bed: Nest 42 room 101, bed D is the upper bunk over C.
  final n101 = out['nest42']?[101];
  if (n101 != null && n101.beds.containsKey('C') && n101.beds.containsKey('D')) {
    n101.bunks['D'] = 'C';
    n101.beds['D'] = n101.beds['C']!;
  }
  out['anjani']![204]!
    ..version = 2
    ..pending = true
    ..drawn = '1 Oct';
  return out;
}
