import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';
import 'screens_tenant.dart' show filtered, searchSummary;

// F17 board 9: a real map (OpenStreetMap tiles, attribution shown) with square
// price pins, the searched landmark, and a card with distance, Directions and
// View hostel. Distances are straight-line from the landmark you searched;
// "my location" needs the location permission (F15).

/// Tiles load from the network; flow tests turn them off.
bool mapTiles = true;

LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final filt = filtered(s);
    final mh = hostelById(s.mapSel);
    final here = landmarkLatLng[s.lm]!;
    final pins = [for (final ho in hostels) ho]..sort((a, b) => (a.id == s.mapSel ? 1 : 0) - (b.id == s.mapSel ? 1 : 0));
    final free = s.freeOf(mh.id).f;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: ValueKey('map${s.lm}'),
            options: MapOptions(initialCenter: _ll(here), initialZoom: 13, minZoom: 10, maxZoom: 18, backgroundColor: p.sf),
            children: [
              if (mapTiles) TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'app.hostelzy.hostelzy'),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ll(here),
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
                  for (final ho in pins)
                    Marker(
                      point: _ll(posOf(ho)),
                      width: 64,
                      height: 30,
                      alignment: Alignment.topCenter,
                      child: () {
                        final sel = ho.id == s.mapSel, vis = filt.contains(ho);
                        return Tap(
                          onTap: () => s.update(() => s.mapSel = ho.id),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 7),
                              decoration: box(bg: sel ? p.tx : (vis ? p.ac : p.bg), w: 2, c: sel ? p.tx : (vis ? p.ac : p.tk)),
                              child: T('₹${(ho.from / 1000).toStringAsFixed(1)}k', w: 800, s: 13, c: sel ? p.bg : (vis ? p.ai : p.mu)),
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
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Tap(
            onTap: () => s.update(() => s.sheet = 'search'),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: box(bg: p.bg, w: 2, c: p.tx),
              child: Row(children: [const Ic('search', size: 18), const SizedBox(width: 10), Expanded(child: T(searchSummary(s), s: 14, w: 600, ell: true))]),
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
              Align(alignment: Alignment.centerRight, child: Container(color: p.bg.withValues(alpha: .85), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: T('© OpenStreetMap contributors', s: 10, c: p.mu))),
              const SizedBox(height: 6),
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
                              T('${kmLabel(kmTo(mh, s.lm))} from ${s.lm} · ${mh.reviews == 0 ? 'New' : 'rated ${jsNum(mh.rating)}'} · $free free', s: 12, c: p.mu),
                              const SizedBox(height: 4),
                              Rich([sp(context, fmt(mh.from)), sp(context, '/mo', s: 12, w: 400, c: p.mu)], s: 16, w: 800),
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
