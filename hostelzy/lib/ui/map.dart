import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data.dart';
import '../map_config.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'photos.dart';
import 'screens_tenant.dart' show WhereBar, cardCost, filtered;

// F17 board 9 + F18 "Map v2" + F22 Area 1: a real map (OpenStreetMap tiles,
// attribution shown) with price pins for the hostels that match the filters,
// the "Where?" field and a location button on top, "Search this area" after a
// pan, and one photo card with the real cost and View.

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
        // F22 Area 1: the one "Where?" field on top, with a location button.
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Expanded(
                child: KeyedSubtree(key: const ValueKey('mapArea'), child: WhereBar(onTap: s.openWhere, height: 50)),
              ),
              const SizedBox(width: 8),
              // Explainer first; Android asks only after "Allow location".
              Tap(
                key: const ValueKey('mapLoc'),
                onTap: () => s.update(() => s.sheet = 'loc'),
                child: Semantics(
                  label: 'Use my location',
                  child: Container(width: 50, height: 50, alignment: Alignment.center, decoration: box(bg: p.bg, w: 2, c: p.tx), child: const Ic('pin', size: 20)),
                ),
              ),
            ],
          ),
        ),
        if (s.mapMoved)
          Positioned(
            top: 74,
            left: 0,
            right: 0,
            child: Center(
              child: Tap(
                onTap: s.searchThisArea,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  color: p.tx,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Ic('search', size: 16, color: p.bg), const SizedBox(width: 6), T('Search this area', s: 14, w: 800, c: p.bg)]),
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
              Align(alignment: Alignment.centerRight, child: Container(color: p.bg.withValues(alpha: .85), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T(mapAttribution, s: 10, c: p.mu))),
              const SizedBox(height: 6),
              if (mh == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: box(bg: p.bg, w: 2, c: p.tx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      T('No hostels ${s.mapArea != null ? 'in ${s.mapArea}' : 'here'} yet', w: 800, s: 16),
                      const SizedBox(height: 4),
                      T('We add hostels area by area, after we visit each one. Try a nearby area.', s: 13, c: p.mu),
                      const SizedBox(height: 10),
                      if (s.nearbyArea case final a?) Cta('Try $a', height: 46, px: 14, fs: 14, onTap: () => s.pickWhereArea(a)) else OutlineCta('Pick another area', icon: 'pin', height: 46, fs: 14, onTap: s.openWhere),
                    ],
                  ),
                )
              else
                MapCard(mh),
            ],
          ),
        ),
      ],
    );
  }
}

/// F22 Area 1: the map's one card: photo, name, one facts line, the real
/// cost and View.
class MapCard extends StatelessWidget {
  const MapCard(this.h, {super.key});
  final Hostel h;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final photos = s.photosOf[h.id] ?? const [];
    final cost = cardCost(s, h);
    return Container(
      decoration: box(bg: p.bg, w: 2, c: p.tx),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 112,
              child: CustomPaint(
                painter: Hatch(p.sf, 8, 16, base: p.bg),
                child: Stack(children: [
                  Positioned.fill(child: LoadPhotos(h.id, child: photos.isEmpty ? const SizedBox() : PhotoImg(photos.first.url))),
                  if (photos.isEmpty) Positioned(left: 6, bottom: 4, child: T('No photos yet', s: 11, c: p.mu)),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    T(h.name, w: 800, s: 16, lh: 1.15),
                    const SizedBox(height: 3),
                    T('${h.gender} · ${kmLabel(s.kmFor(h))} · ${h.reviews == 0 ? 'New' : jsNum(h.rating)} · ${s.freeOf(h.id).f} free', s: 13, c: p.mu),
                    if (cost != null) ...[
                      const SizedBox(height: 3),
                      Rich([sp(context, '${fmt(cost.fee)}/mo', w: 800), sp(context, ' · ${fmt(cost.move)} to move in')], s: 14),
                    ],
                    const SizedBox(height: 8),
                    Cta('View', key: const ValueKey('mapView'), height: 40, px: 14, fs: 14, onTap: () => s.update(() {
                      s.hist = [...s.hist, s.screen];
                      s.screen = 'detail';
                      s.sheet = null;
                      s.hid = h.id;
                      s.dealAc = null;
                      s.rulesOpen = false;
                    })),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          T('Only to show hostels near you and how far they are. Owners never see where you are.', s: 15, c: p.mu, lh: 1.5),
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
          OutlineCta('Type an area instead', icon: 'search', onTap: s.openWhere),
        ],
      ),
    );
  }
}


/// F24 Wave 4c (board `aPin`): the team drops the hostel's pin at its gate.
/// The pin stays in the middle; the map moves under it, or "Use my location"
/// puts it where the phone is. Saved only after one of those, so a hostel is
/// never pinned on its area's centre.
class PinScreen extends StatelessWidget {
  const PinScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final c = s.pinNow ?? landmarkLatLng['Hitec City']!;
    final d = s.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              BackBtn(onTap: s.back),
              const SizedBox(width: 12),
              Expanded(child: PageHead(kicker: '${d.name.trim().isEmpty ? 'New hostel' : d.name.trim()}${d.area.isEmpty ? '' : ' · ${d.area}'}', title: 'Map pin', gap: 2)),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  key: ValueKey('pin${s.pinFocus}'),
                  options: MapOptions(
                    initialCenter: _ll(c),
                    initialZoom: 17,
                    minZoom: 11,
                    maxZoom: 19,
                    backgroundColor: p.sf,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) s.pinPanned((camera.center.latitude, camera.center.longitude));
                    },
                  ),
                  children: [if (mapTiles) TileLayer(urlTemplate: mapTileUrl, userAgentPackageName: mapUserAgent)],
                ),
              ),
              // The pin: its tip sits on the map's centre.
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      key: const ValueKey('pinMark'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 26, height: 26, decoration: BoxDecoration(color: p.ac, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3))),
                        Container(width: 3, height: 10, color: p.ac),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(color: p.bg.withValues(alpha: .85), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T(mapAttribution, s: 10, c: p.mu)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(color: p.bg, border: Border(top: bs(2, p.tx))),
          child: VGap(
            gap: 10,
            children: [
              T(s.pinTouched ? 'Pin at ${c.$1.toStringAsFixed(5)}, ${c.$2.toStringAsFixed(5)}' : 'Stand at the gate and use your location, or move the map so the pin sits on the gate.', s: 13, c: s.pinTouched ? p.tx : p.mu, w: s.pinTouched ? 800 : 400, lh: 1.4),
              OutlineCta('Use my location', key: const ValueKey('pinLocate'), icon: 'pin', height: 48, fs: 14, onTap: s.locatePin),
              Cta('Save pin', key: const ValueKey('pinSave'), icon: 'check', height: 54, px: 16, fs: 15, bg: s.pinTouched ? null : p.tk, fg: s.pinTouched ? null : p.mu, onTap: s.savePin),
            ],
          ),
        ),
      ],
    );
  }
}
