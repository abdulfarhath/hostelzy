import 'package:flutter/material.dart';

import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import 'resident_screens.dart' show complaintWord;

/// F26 #14: "Something wrong in your room?" (My stay › Help; Home › Raise
/// complaint). The old Help tab's form; once sent, the list opens.
class ComplaintSheet extends StatelessWidget {
  const ComplaintSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Future<void> send() async {
      final typed = s.cText.trim().isNotEmpty;
      await s.raiseComplaint();
      if (typed && s.cText.isEmpty && s.sheet == 'complaint') s.update(() => s.sheet = 'complaints');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: VGap(
        gap: 10,
        children: [
          wrap(6, [
            for (final c in const ['Wi-Fi', 'Water', 'Electricity', 'Cleaning', 'Food', 'Other']) ChipBtn(c, on: c == s.cCat, pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 12), onTap: () => s.update(() => s.cCat = c)),
          ]),
          Field(value: s.cText, onChanged: (v) => s.update(() => s.cText = v), placeholder: 'What’s wrong? Where, and since when.', maxLines: 3, height: null, pad: const EdgeInsets.all(12)),
          Row(
            children: [
              Tap(
                key: const ValueKey('cPhoto'),
                onTap: s.cPhoto == null ? s.pickComplaintPhoto : () => s.update(() => s.cPhoto = null),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: box(w: 2, c: p.tx),
                  alignment: Alignment.center,
                  child: s.cPhoto == null
                      ? const Ic('camera', size: 20)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(s.cPhoto!, fit: BoxFit.cover),
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(color: p.bg, child: const Ic('x', size: 14)),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Cta('Send to owner', height: 54, px: 16, fs: 15, onTap: send)),
            ],
          ),
          T('${s.stayOwner == 'your owner' ? 'Your owner' : s.stayOwner} sees it in Hostelzy. You’ll see here when it’s fixed.', s: 13, c: p.mu, lh: 1.4),
        ],
      ),
    );
  }
}

/// F26 #14: "Your complaints" (My stay › Help): what was sent and whether
/// it's being fixed.
class ComplaintsSheet extends StatelessWidget {
  const ComplaintsSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final owner = s.stayOwner;
    final mine = s.complaints.where((c) => c.mine).toList().reversed.toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (mine.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: VGap(
          gap: 10,
          children: [
            const T('No complaints', w: 800, s: 17),
            T('When something breaks, tell $owner here. You’ll see when it’s fixed.', s: 14, c: p.mu, lh: 1.4),
            OutlineCta('Something wrong in your room?', icon: 'wrench', height: 46, fs: 14, onTap: () => s.update(() => s.sheet = 'complaint')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in mine)
          () {
            final fresh = c.status == 'Open' && c.at != null && now - c.at! < 10 * 60 * 1000;
            final word = complaintWord(c.status);
            final when = fresh ? 'Just now' : c.date;
            final line = c.status == 'Open' && s.onServer ? '$owner sees it in the app' : (c.note.isEmpty ? 'Sent to $owner' : (c.status == 'Open' ? c.note : '“${c.note}”'));
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: fresh ? p.sf : null,
                border: Border(bottom: bs(1, p.hl)),
              ),
              child: VGap(
                gap: 4,
                children: [
                  Row(
                    children: [
                      Expanded(child: T(c.cat, w: 800, s: 15)),
                      if (c.photo != null || s.complaintPhotosLocal[c.id] != null) ...[Ic('camera', size: 14, color: p.mu), const SizedBox(width: 8)],
                      word == 'Fixed' ? Tag(word, bg: transparent, fg: p.mu) : Tag(word, bg: p.ab, fg: p.ad),
                    ],
                  ),
                  T(c.text, s: 14),
                  T('$when · $line', s: 12, c: p.mu),
                ],
              ),
            );
          }(),
      ],
    );
  }
}
