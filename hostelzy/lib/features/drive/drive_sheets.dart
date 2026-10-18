// F29 Part 3: sheet H50 `drive`, "Tenant IDs in your Drive" (Manage › Tenant IDs).
// F31 Rule A: a status line, the button, the switch; no helper sentences.

import 'package:flutter/material.dart';

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
    final st = s.driveStatus;
    final why = s.driveUnavailable;
    final line = st == null
        ? 'Checking…'
        : why != null
        ? 'Not available yet'
        : st.connected
        ? 'Connected · ${st.files} file${st.files == 1 ? '' : 's'}'
        : 'Not connected';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: VGap(
        gap: 12,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(top: bs(2, p.tx), bottom: bs(1, p.hl))),
            child: Row(
              children: [
                if (st?.connected ?? false) ...[Ic('check', size: 16, color: p.tx), const SizedBox(width: 8)],
                Expanded(child: T(line, w: 800, s: 15, key: ValueKey(why != null ? 'driveNotYet' : st == null ? 'driveLoading' : 'driveStatus'))),
              ],
            ),
          ),
          if (st != null && why == null) ...[
            if (st.connected)
              Tap(
                key: const ValueKey('fullCopy'),
                onTap: s.toggleFullCopy,
                // A painted box, so a tap anywhere on the row flips the switch.
                child: Container(
                  color: transparent,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(child: T('Full copy needed (police file)', w: 800, s: 15)),
                      const SizedBox(width: 12),
                      SquareSwitch(on: st.fullCopy),
                    ],
                  ),
                ),
              ),
            // Connect / Disconnect: the owner's Google account, so the owner only.
            if (!s.managerHere)
              st.connected
                  ? OutlineCta(s.driveBusy ? 'Disconnecting…' : 'Disconnect', key: const ValueKey('driveDisconnect'), icon: 'x', onTap: s.driveBusy ? () {} : s.disconnectDrive)
                  : Cta(s.driveBusy ? 'Connecting…' : 'Connect Google Drive', key: const ValueKey('driveConnect'), height: 54, px: 16, fs: 15, icon: 'globe', opacity: s.driveBusy ? .6 : 1, onTap: s.driveBusy ? null : s.connectDrive),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
