// F29 Part 3: sheet H50 `drive`, "Tenant IDs in your Drive" (Manage › Tenant IDs).

import 'package:flutter/material.dart';

import '../../data.dart';
import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../session/settings_screens.dart' show SquareSwitch;

class DriveSheet extends StatelessWidget {
  const DriveSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.ownHid);
    final st = s.driveStatus;
    final why = s.driveUnavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          T('Keep tenant IDs in your own Google Drive. Hostelzy never stores them.', s: 14, c: p.mu, lh: 1.45),
          if (st == null)
            T('Checking…', s: 14, c: p.mu, key: const ValueKey('driveLoading'))
          // "Not available yet": the server or Google's consent screen isn't ready (founder's one-time step).
          else if (why != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: box(w: 2, c: p.tx),
              child: VGap(
                gap: 4,
                children: [
                  const T('Not available yet', w: 800, s: 16, key: ValueKey('driveNotYet')),
                  T(
                    why == 'scope' ? 'Google hasn’t allowed Drive access for Hostelzy yet. Until then tenants send their ID to you on WhatsApp.' : 'Hostelzy’s server doesn’t have Google Drive yet. Until then tenants send their ID to you on WhatsApp.',
                    s: 13,
                    c: p.mu,
                    lh: 1.45,
                  ),
                ],
              ),
            ),
            OutlineCta('Try again', key: const ValueKey('driveRetry'), icon: 'swap', onTap: s.loadDrive),
          ] else if (!st.connected) ...[
            T('Google asks you once. Hostelzy can see only the files it makes, in Hostelzy / ${h.name} / Tenant IDs.', s: 13, c: p.mu, lh: 1.45),
            if (s.managerHere)
              T('Only the owner connects Google Drive.', s: 13, w: 800, c: p.mu, key: const ValueKey('driveOwnerOnly'))
            else
              Cta(s.driveBusy ? 'Connecting…' : 'Connect Google Drive', key: const ValueKey('driveConnect'), height: 54, px: 16, fs: 15, icon: 'globe', opacity: s.driveBusy ? .6 : 1, onTap: s.driveBusy ? null : s.connectDrive),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(top: bs(2, p.tx), bottom: bs(1, p.hl))),
              child: Row(
                children: [
                  Ic('check', size: 16, color: p.tx),
                  const SizedBox(width: 8),
                  Expanded(child: T('Connected · ${st.files} file${st.files == 1 ? '' : 's'}', w: 800, s: 15, key: const ValueKey('driveStatus'))),
                ],
              ),
            ),
            Tap(
              key: const ValueKey('fullCopy'),
              onTap: s.toggleFullCopy,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const T('Full copy needed (police file)', w: 800, s: 15),
                        T(st.fullCopy ? 'On: the tenant sends the whole ID.' : 'Off: the tenant covers the first 8 digits of the ID number.', s: 13, c: p.mu, lh: 1.4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SquareSwitch(on: st.fullCopy),
                ],
              ),
            ),
            T('Files stay in your Drive; Hostelzy keeps only a link to each one.', s: 13, c: p.mu, lh: 1.45),
            if (s.managerHere)
              T('Only the owner disconnects Google Drive.', s: 13, w: 800, c: p.mu, key: const ValueKey('driveOwnerOnly'))
            else
              OutlineCta(s.driveBusy ? 'Disconnecting…' : 'Disconnect', key: const ValueKey('driveDisconnect'), icon: 'x', onTap: s.driveBusy ? () {} : s.disconnectDrive),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
