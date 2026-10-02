import 'package:flutter/material.dart' hide Tab;

import '../data.dart';
import '../features/photos/photo.dart';
import '../state.dart';
import 'common.dart';
import 'kit.dart';

/// A photo from the server, striped while it loads or when it can't.
class PhotoImg extends StatelessWidget {
  const PhotoImg(this.url, {super.key, this.fit = BoxFit.cover, this.dark = false});
  final String url;
  final BoxFit fit;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final p = PalScope.of(context);
    final stripes = CustomPaint(painter: dark ? Hatch(const Color(0xFF24221F), 10, 20, base: const Color(0xFF2E2B28)) : Hatch(p.sf, 6, 12, base: p.bg), child: const SizedBox.expand());
    return Image.network(url, fit: fit, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => stripes, loadingBuilder: (_, child, ev) => ev == null ? child : stripes);
  }
}

/// B7 design 14 "Owner: photos": albums, a 3-column grid (cover first),
/// uploads with progress, failed + retry, Add photos.
class OwnerPhotosScreen extends StatelessWidget {
  const OwnerPhotosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.photoHid);
    final albums = s.photoAlbums(h.id);
    final album = albums.contains(s.photoAlbum) ? s.photoAlbum : 'Hostel';
    final shown = s.photosIn(h.id, album);
    final ups = [for (final u in s.uploads) if (u.hid == h.id && u.album == album) u];
    final total = (s.photosOf[h.id] ?? const []).length;
    Widget badge(String t, {Color? bg, Color? fg}) => Container(color: bg ?? p.bg, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), child: T(t, s: 10, w: 800, c: fg));
    Widget tile(HostelPhoto ph, int i) {
      final cover = album == 'Hostel' && i == 0;
      final body = SizedBox(
        height: 104,
        child: Container(
          decoration: box(w: 1, c: p.hl),
          child: Stack(
            children: [
              PhotoImg(ph.url),
              if (cover) Positioned(left: 4, top: 4, child: badge('COVER', bg: p.ac, fg: p.ai)),
              Positioned(right: 4, top: 4, child: Container(width: 20, height: 20, color: p.bg, alignment: Alignment.center, child: T('${i + 1}', s: 11, w: 800))),
              if (ph.label.isNotEmpty) Positioned(left: 4, bottom: 4, child: badge(ph.label)),
            ],
          ),
        ),
      );
      return DragTarget<HostelPhoto>(
        onWillAcceptWithDetails: (d) => d.data.id != ph.id,
        onAcceptWithDetails: (d) => s.movePhoto(h.id, d.data, ph),
        builder: (_, cand, _) => LongPressDraggable<HostelPhoto>(
          key: ValueKey('photo${ph.id}'),
          data: ph,
          feedback: SizedBox(width: 110, child: Opacity(opacity: .85, child: body)),
          childWhenDragging: Opacity(opacity: .3, child: body),
          child: Container(foregroundDecoration: cand.isNotEmpty ? box(w: 2, c: p.ac) : null, child: Tap(onTap: () => s.update(() {
            s.photoSel = ph.id;
            s.sheet = 'photo';
          }), child: body)),
        ),
      );
    }

    Widget upTile(PhotoUpload u) => Tap(
      key: ValueKey(u.key),
      onTap: u.failed ? () => s.retryUpload(u) : null,
      child: Container(
        height: 104,
        decoration: box(w: 1, c: p.hl),
        child: u.failed
            ? Container(
                color: p.ab,
                alignment: Alignment.center,
                child: Css(c: p.ad, s: 11, w: 800, child: const Column(mainAxisSize: MainAxisSize.min, children: [Ic('warn', size: 18), SizedBox(height: 4), T('Failed · Retry')])),
              )
            : Stack(
                children: [
                  Positioned.fill(child: Image.memory(u.jpg, fit: BoxFit.cover)),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(color: p.bg, padding: const EdgeInsets.symmetric(horizontal: 3), child: T('Uploading ${u.percent}%', s: 10, w: 800)),
                        const SizedBox(height: 3),
                        Container(
                          height: 6,
                          decoration: box(bg: p.bg, w: 1, c: p.tx),
                          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: u.percent / 100, child: Container(color: p.tx)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    final add = Tap(
      key: const ValueKey('addPhoto'),
      onTap: s.addPhoto,
      child: Dashed(
        color: p.dv,
        child: SizedBox(
          height: 100,
          child: Center(child: Css(c: p.ad, s: 13, w: 800, child: const Column(mainAxisSize: MainAxisSize.min, children: [Ic('plus', size: 20), SizedBox(height: 4), T('Add photos')]))),
        ),
      ),
    );
    final tiles = [for (final (i, ph) in shown.indexed) tile(ph, i), for (final u in ups) upTile(u), add];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [BackBtn(onTap: s.back), const SizedBox(width: 12), Expanded(child: PageHead(kicker: '${h.name} · Manage', title: 'Photos'))]),
        ),
        Seg(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          center: true,
          opts: [for (final a in albums) (a, '$a ${s.photosIn(h.id, a).length}')],
          cur: album,
          onPick: (a) => s.update(() => s.photoAlbum = a),
        ),
        Expanded(
          child: Scroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: T(album == 'Hostel' ? 'Drag to reorder. The first is the cover.' : 'Drag to reorder.', s: 13, c: p.mu)),
                      const SizedBox(width: 8),
                      T('$total of ${HostelDraft.minPhotos} minimum', s: 13, w: 800, c: total >= HostelDraft.minPhotos ? p.tx : p.ad),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final w = (c.maxWidth - 12) / 3;
                      return Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Css(
                    c: p.mu,
                    s: 12,
                    lh: 1.45,
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Padding(padding: EdgeInsets.only(top: 1), child: Ic('camera', size: 16)), SizedBox(width: 8), Expanded(child: T('Daylight, from the door, whole room in view. Blurry or dark photos get retaken on the Hostelzy visit. No people’s faces.'))],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(border: Border(top: bs(2, p.tx))),
          child: Cta('Done', icon: 'check', height: 54, fs: 15, onTap: s.back),
        ),
      ],
    );
  }
}

/// B7 design 15 "Owner: crop + cover".
class CropScreen extends StatelessWidget {
  const CropScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final b = s.cropBytes;
    final hostelAlbum = s.photoAlbum == 'Hostel';
    final labels = hostelAlbum ? hostelPhotoLabels : s.photoAlbums(s.photoHid).where((a) => a != 'Hostel').toList();
    const light = Color(0xFFF3F2F2);
    final ratio = switch (s.cropAspect) { '4:3' => 4 / 3, '1:1' => 1.0, _ => null };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Tap(onTap: s.cancelCrop, child: const SizedBox(height: 44, child: Center(child: T('Cancel', s: 15, w: 800)))),
              const Expanded(child: T('Crop photo', s: 17, w: 800, align: TextAlign.center)),
              Tap(key: const ValueKey('useCrop'), onTap: s.useCrop, child: SizedBox(height: 44, child: Center(child: T('Use', s: 15, w: 800, c: p.ad)))),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF161514),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: b == null
                ? const SizedBox()
                : AspectRatio(
                    aspectRatio: ratio ?? 4 / 3,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: Image.memory(b, fit: ratio == null ? BoxFit.contain : BoxFit.cover)),
                        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Thirds(light)))),
                        for (final (x, y) in const [(-6.0, -6.0), (null, -6.0), (-6.0, null), (null, null)])
                          Positioned(left: x, top: y, right: x == null ? -6 : null, bottom: y == null ? -6 : null, child: Container(width: 16, height: 16, color: light)),
                      ],
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: VGap(
            gap: 10,
            children: [
              Seg(opts: const [('4:3', '4:3 listing'), ('1:1', 'Square'), ('free', 'Free')], cur: s.cropAspect, onPick: (a) => s.update(() => s.cropAspect = a), center: true, pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
              if (hostelAlbum)
                Tap(
                  onTap: () => s.update(() => s.cropCover = !s.cropCover),
                  child: Row(
                    children: [
                      const Expanded(child: T('Set as cover photo', s: 15, w: 600)),
                      Container(
                        width: 44,
                        height: 24,
                        padding: const EdgeInsets.all(2),
                        decoration: box(bg: s.cropCover ? p.tx : transparent, w: 2, c: p.tx),
                        alignment: s.cropCover ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(width: 16, height: 16, color: s.cropCover ? p.bg : p.tx),
                      ),
                    ],
                  ),
                ),
              Tap(
                onTap: () => s.update(() => s.cropLabel = labels[(labels.indexOf(s.cropLabel) + 1) % labels.length]),
                child: Row(children: [T(hostelAlbum ? 'What it shows' : 'Room type', s: 15, w: 600), const Spacer(), T('${s.cropLabel} ▾', s: 14, c: p.mu)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thirds extends CustomPainter {
  _Thirds(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size z) {
    final line = Paint()
      ..color = c.withValues(alpha: .4)
      ..strokeWidth = 1;
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(z.width * f, 0), Offset(z.width * f, z.height), line);
      canvas.drawLine(Offset(0, z.height * f), Offset(z.width, z.height * f), line);
    }
    canvas.drawRect(
      Offset.zero & z,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Thirds old) => old.c != c;
}

/// B7 design 16 "Tenant: photo gallery".
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final h = hostelById(s.hid);
    final all = s.photosOf[h.id] ?? const <HostelPhoto>[];
    final list = s.galleryList(h.id);
    final at = list.isEmpty ? 0 : s.galleryAt.clamp(0, list.length - 1);
    final cur = list.isEmpty ? null : list[at];
    const cats = ['All', 'Rooms', 'Washroom', 'Food', 'Common', 'Front'];
    int count(String c) => c == 'All' ? all.length : all.where((x) => s.galleryCatOf(x) == c).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFF161514),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Tap(
                onTap: s.back,
                child: Container(width: 44, height: 44, decoration: box(w: 1, c: const Color(0x55FFFFFF)), alignment: Alignment.center, child: const Ic('x', size: 18, color: Color(0xFFF0EEEE))),
              ),
              Expanded(child: T(cur == null ? 'No photos' : '${at + 1} / ${list.length} · ${cur.label}', s: 15, w: 800, c: const Color(0xFFF0EEEE), align: TextAlign.center)),
              const SizedBox(width: 44),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF161514),
            alignment: Alignment.center,
            child: cur == null
                ? const T('No photos here yet.', s: 14, c: Color(0xFFBAB6B6))
                : GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 50) return;
                      s.update(() => s.galleryAt = (at + (v < 0 ? 1 : -1)).clamp(0, list.length - 1));
                    },
                    child: AspectRatio(aspectRatio: 4 / 3, child: PhotoImg(cur.url, fit: BoxFit.contain, dark: true)),
                  ),
          ),
        ),
        Container(
          color: p.bg,
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
          child: VGap(
            gap: 10,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final c in cats)
                      if (c == 'All' || count(c) > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChipBtn('$c ${count(c)}', on: s.galleryCat == c, onTap: () => s.pickGalleryCat(c), pad: const EdgeInsets.symmetric(vertical: 9, horizontal: 12)),
                        ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (i, ph) in list.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tap(
                          onTap: () => s.update(() => s.galleryAt = i),
                          child: Container(width: 64, height: 48, decoration: box(w: i == at ? 2 : 1, c: i == at ? p.ac : p.hl), child: PhotoImg(ph.url)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: T('Photos by the owner', s: 12, c: p.mu)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Owner taps a photo: make it the cover, or remove it.
class PhotoSheet extends StatelessWidget {
  const PhotoSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ph = s.selPhoto;
    if (ph == null) return const SizedBox();
    final hostelAlbum = s.albumOf(ph) == 'Hostel';
    final isCover = hostelAlbum && s.photosIn(s.photoHid, 'Hostel').firstOrNull?.id == ph.id;
    return VGap(
      gap: 10,
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: PhotoImg(ph.url)),
        if (hostelAlbum && !isCover) Cta('Make it the cover', icon: 'check', height: 52, fs: 15, onTap: () => s.makeCover(ph)),
        OutlineCta('Remove photo', icon: 'trash', onTap: () => s.deletePhoto(s.photoHid, ph)),
      ],
    );
  }
}

/// Loads a hostel's photos once when shown (detail page).
class LoadPhotos extends StatefulWidget {
  const LoadPhotos(this.hid, {super.key, required this.child});
  final String hid;
  final Widget child;
  @override
  State<LoadPhotos> createState() => _LoadPhotosState();
}

class _LoadPhotosState extends State<LoadPhotos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadPhotos(widget.hid);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
