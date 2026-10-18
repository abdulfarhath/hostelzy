// F29 Part 3: a tenant's ID from the owner's Google Drive, for H49
// `joinReview` (wave 2). Loads a short-lived link through `id-view` (owner
// and managers only); tap opens the file in Drive.

import 'package:flutter/material.dart';

import '../../state.dart';
import '../../ui/kit.dart';
import '../listings/repo.dart';

class IdThumb extends StatefulWidget {
  const IdThumb({super.key, required this.hid, required this.fileId, this.height = 170});
  final String hid, fileId;
  final double height;
  @override
  State<IdThumb> createState() => _IdThumbState();
}

class _IdThumbState extends State<IdThumb> {
  Future<({String url, String open})>? _link;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link ??= AppScope.of(context).data.idView(widget.hid, widget.fileId);
  }

  @override
  void didUpdateWidget(IdThumb old) {
    super.didUpdateWidget(old);
    if (old.fileId != widget.fileId || old.hid != widget.hid) _link = AppScope.of(context).data.idView(widget.hid, widget.fileId);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    Widget frame(Widget child, {String? open}) => Tap(
      key: const ValueKey('idThumb'),
      onTap: open == null || open.isEmpty ? null : () => s.openLink(Uri.parse(open), 'Google Drive'),
      child: Container(height: widget.height, decoration: box(w: 2, c: p.tx, bg: p.sf), clipBehavior: Clip.hardEdge, alignment: Alignment.center, child: child),
    );
    return FutureBuilder(
      future: _link,
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          final why = e is DriveFail ? (e.code == 'not_ready' ? 'Not available yet.' : e.message) : 'Couldn’t load the ID. Check your internet and try again.';
          return frame(Padding(padding: const EdgeInsets.all(12), child: T(why, s: 13, c: p.mu, lh: 1.4, key: const ValueKey('idThumbError'))));
        }
        final link = snap.data;
        if (link == null) return frame(T('Loading the ID…', s: 13, c: p.mu, key: const ValueKey('idThumbLoading')));
        // Demo data: no real Drive, a drawn stand-in (never a real document).
        if (link.url.isEmpty) {
          return frame(
            CustomPaint(
              key: const ValueKey('idThumbSample'),
              painter: Hatch(p.hl, 8, 16, base: p.sf),
              child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: p.bg, child: T('Sample ID (drawn)', s: 13, w: 800, c: p.mu))),
            ),
          );
        }
        return frame(
          Image.network(
            link.url,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, _, _) => Padding(padding: const EdgeInsets.all(12), child: T('Couldn’t load the ID here. Tap to open it in Drive.', s: 13, c: p.mu, lh: 1.4, key: const ValueKey('idThumbError'))),
          ),
          open: link.open,
        );
      },
    );
  }
}
