import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../holds/building_view.dart';
import 'owner_today_screen.dart';

/// F26 #19 (board `[F26 #19] Owner Beds`): the Building view only (the
/// Rooms list and its Rooms · Building toggle are gone). A bed opens the bed
/// sheet; a room's number opens its layout (or "Create a layout"). The
/// Layouts page stays for creating and copying layouts.
class OwnerBedsScreen extends StatelessWidget {
  const OwnerBedsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final a = s.rooms[s.ownHid]!;
    void openBed(Bed b) => s.update(() {
      s.sheet = 'bed';
      s.obed = b.id;
    });
    return Scroll(
      key: ValueKey('oBeds${s.scrollEpoch}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(kicker: occCounts(s), title: 'Beds'),
            const SizedBox(height: 12),
            if (a.isEmpty)
              T('No rooms yet.', s: 14, c: p.mu, lh: 1.4)
            else
              BuildingView(hid: s.ownHid, rooms: a, tenant: false, selected: s.sheet == 'bed' ? s.obed : null, onBed: openBed, onRoom: (r) => s.ownerLayout(r.n)),
            const SizedBox(height: 10),
            T('Tap a bed for its bed sheet. Tap a room number for its layout.', s: 12, c: p.mu, lh: 1.45),
            const SizedBox(height: 12),
            Tap(
              key: const ValueKey('obLayouts'),
              onTap: () {
                s.go('oLayouts');
                s.loadShapeRequests(s.ownHid);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Rich([sp(context, 'Layouts ›', w: 800, c: p.tx), sp(context, ' to create or copy one.')], s: 13, c: p.mu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
