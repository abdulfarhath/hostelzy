import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data.dart';
import '../map_config.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'screens_tenant.dart' show WhereBar, filtered;

// F17 board 9 + F18 "Map v2": a real map (OpenStreetMap tiles, attribution
// shown) with price pins for the hostels that match the filters, an area
// picker, "Search this area" after a pan, "Use my location" (explainer, then
// Android asks), and a card with distance, Directions and View hostel.

/// Tiles load from the network; flow tests turn them off.
bool mapTiles = true;

LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    // F18: pins, card and list follow the filters and the area picked.
    final filt = filtered(s);
    final mh = filt.where((h) => h.id == s.mapSel).firstOrNull ?? filt.firstOrNull;
    final pins = [...filt]..sort((a, b) => (a.id == mh?.id ? 1 : 0) - (b.id == mh?.id ? 1 : 0));
    final showLm = s.myPos == null && s.mapArea == null && s.areaCenter == null;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: ValueKey('map${s.lm}${s.mapFocus}'),
            options: MapOptions(
              initialCenter: _ll(s.mapFocusPos),
              initialZoom: s.mapArea != null || s.myPos != null ? 14 : 13,
              minZoom: 10,
              maxZoom: 18,
              backgroundColor: p.sf,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) s.mapPanned((camera.center.latitude, camera.center.longitude));
              },
            ),
            children: [
              if (mapTiles) TileLayer(urlTemplate: mapTileUrl, userAgentPackageName: mapUserAgent),
              MarkerLayer(
                markers: [
                  // Landmarks as small labels.
                  for (final l in landmarks.where((l) => !showLm || l != s.lm))
                    Marker(
                      point: _ll(landmarkLatLng[l]!),
                      width: 110,
                      height: 18,
                      alignment: Alignment.centerRight,
                      child: Row(children: [Container(width: 7, height: 7, color: p.mu), const SizedBox(width: 4), Container(color: p.bg.withValues(alpha: .85), padding: const EdgeInsets.symmetric(horizontal: 3), child: T(l, s: 11, w: 600, c: p.mu))]),
                    ),
                  if (showLm)
                    Marker(
                      point: _ll(landmarkLatLng[s.lm]!),
                      width: 140,
                      height: 24,
                      alignment: Alignment.centerRight,
                      child: Row(
                        children: [
                          Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: p.tx.withValues(alpha: .18), shape: BoxShape.circle), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: p.tx, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 2)))),
                          const SizedBox(width: 4),
                          Container(color: p.bg, padding: const EdgeInsets.symmetric(horizontal: 3), child: T(s.lm, s: 11, w: 800)),
                        ],
                      ),
                    ),
                  // You are here (only after the user allowed location).
                  if (s.myPos != null)
                    Marker(
                      point: _ll(s.myPos!),
                      width: 44,
                      height: 44,
                      child: Container(
                        key: const ValueKey('youAreHere'),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.hl, shape: BoxShape.circle),
                        child: Container(width: 16, height: 16, decoration: BoxDecoration(color: p.tx, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3))),
                      ),
                    ),
                  for (final ho in pins)
                    Marker(
                      point: _ll(posOf(ho)),
                      width: 72,
                      height: 30,
                      alignment: Alignment.topCenter,
                      child: () {
                        final sel = ho.id == mh?.id;
                        return Tap(
                          onTap: () => s.update(() => s.mapSel = ho.id),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 7),
                              decoration: box(bg: sel ? p.tx : p.ac, w: 2, c: sel ? p.tx : p.ac),
                              child: T(fmt(s.fromOf(ho)), w: 800, s: 13, c: sel ? p.bg : p.ai),
                            ),
                          ),
                        );
                      }(),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Design "Map v2": area picker + List.
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Expanded(
                // F21 W2: the same "Where?" field as Explore.
                child: KeyedSubtree(key: const ValueKey('mapArea'), child: WhereBar(onTap: s.openWhere, height: 46)),
              ),
              const SizedBox(width: 8),
              Tap(
                onTap: () => s.tab('explore'),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: box(bg: p.bg, w: 2, c: p.tx),
                  child: const Row(children: [Ic('list', size: 16), SizedBox(width: 6), T('List', s: 14, w: 800)]),
                ),
              ),
            ],
          ),
        ),
        if (s.mapMoved)
          Positioned(
            top: 68,
            left: 0,
            right: 0,
            child: Center(
              child: Tap(
                onTap: s.searchThisArea,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  color: p.tx,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('search', size: 14, color: p.bg), const SizedBox(width: 6), T('Search this area', s: 13, w: 800, c: p.bg)]),
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(color: p.bg.withValues(alpha: .85), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T(mapAttribution, s: 10, c: p.mu)),
                  const Spacer(),
                  // Explainer first; Android asks only after "Allow location".
                  Tap(
                    onTap: () => s.update(() => s.sheet = 'loc'),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: box(bg: p.bg, w: 2, c: p.tx),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Ic('pin', size: 16), SizedBox(width: 8), T('Use my location', s: 14, w: 800)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (mh == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: box(bg: p.bg, w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('No hostels ${s.mapArea != null ? 'in ${s.mapArea}' : 'here'} yet', w: 800, s: 16),
                      const SizedBox(height: 4),
                      T('Hostelzy is adding hostels area by area. Try another area or clear the filters.', s: 13, c: p.mu),
                      const SizedBox(height: 10),
                      OutlineCta('Pick another area', icon: 'pin', height: 46, fs: 14, onTap: s.openWhere),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: box(bg: p.bg, w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stripes(step: 6, width: 64, height: 64, border: Border.all(width: 1, color: p.hl)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                T(mh.name, w: 800, s: 16, lh: 1.15),
                                const SizedBox(height: 3),
                                T('${kmLabel(s.kmFor(mh))} ${s.kmFrom} · ${mh.reviews == 0 ? 'New' : 'rated ${jsNum(mh.rating)}'} · ${s.freeOf(mh.id).f} free', s: 12, c: p.mu),
                                const SizedBox(height: 4),
                                Rich([sp(context, fmt(s.fromOf(mh))), sp(context, '/mo', s: 12, w: 400, c: p.mu)], s: 16, w: 800),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: Cta('Directions', icon: 'pin', height: 46, px: 12, fs: 14, bg: transparent, fg: p.tx, border: p.tx, onTap: () => s.directions(mh))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Cta('View hostel', height: 46, px: 12, fs: 14, onTap: () => s.update(() {
                              s.hist = [...s.hist, s.screen];
                              s.screen = 'detail';
                              s.sheet = null;
                              s.hid = mh.id;
                              s.dealAc = null;
                            })),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// F18 design "Location": the explainer before Android's location prompt.
class LocationSheet extends StatelessWidget {
  const LocationSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          const T('We use it only to show hostels near you and how far they are. Owners never see where you are.', s: 15, lh: 1.5),
          Tap(
            onTap: s.useMyLocation,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: p.ac,
              child: Row(
                children: [
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [T('Allow location', w: 800, s: 15, c: p.ai), T('Your phone asks next', w: 600, s: 11, c: p.ai.withValues(alpha: .8))])),
                  Ic('arrow', size: 18, color: p.ai),
                ],
              ),
            ),
          ),
          OutlineCta('Pick an area instead', icon: 'pin', onTap: () => s.update(() => s.sheet = 'areas')),
          T('You can change this in Settings.', s: 12, c: p.mu),
        ],
      ),
    );
  }
}

/// F18 design "Areas": pick an area to see every hostel there.
class AreasSheet extends StatelessWidget {
  const AreasSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final q = s.areaQ.trim().toLowerCase();
    final areas = mapAreas.where((a) => q.isEmpty || a.toLowerCase().contains(q)).toList();
    int count(String a) => browsable.where((h) => h.area == a && !s.removed(h.id)).length;
    Widget cell(String a) {
      final n = count(a), on = s.mapArea == a;
      return Opacity(
        opacity: n == 0 ? .5 : 1,
        child: Tap(
          onTap: n == 0 ? () => s.toastMsg('No hostels in $a yet. Coming soon.') : () => s.pickArea(a),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: box(bg: on ? p.sf : null, w: on ? 2 : 1, c: on ? p.tx : p.dv),
            child: Row(children: [Expanded(child: T(a, w: 800, s: 14)), T(n == 0 ? 'Soon' : '$n', s: 12, c: p.mu)]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          VGap(gap: 6, children: [const T('Search an area', w: 800, s: 13), Field(key: const ValueKey('areaQ'), value: s.areaQ, placeholder: 'e.g. Kondapur', onChanged: (v) => s.update(() => s.areaQ = v))]),
          Row(
            children: [
              Expanded(child: OutlineCta('Near me', icon: 'pin', height: 46, fs: 14, onTap: () => s.update(() => s.sheet = 'loc'))),
              if (s.mapArea != null || s.areaCenter != null) ...[const SizedBox(width: 8), Expanded(child: OutlineCta('All areas', icon: 'x', height: 46, fs: 14, onTap: () => s.pickArea(null)))],
            ],
          ),
          for (var i = 0; i < areas.length; i += 2)
            Row(children: [Expanded(child: cell(areas[i])), const SizedBox(width: 6), Expanded(child: i + 1 < areas.length ? cell(areas[i + 1]) : const SizedBox())]),
          if (areas.isEmpty) T('No area called “${s.areaQ.trim()}” yet.', s: 13, c: p.mu),
        ],
      ),
    );
  }
}
