// F29 Part 3: the tenant's ID photo, masked on the phone, to the owner's
// Google Drive. Camera → the tenant drags a black bar over the first 8
// digits ("Cover the first 8 digits") → preview → upload through `id-upload`
// (the image is never kept on Hostelzy). With the owner's "Full copy needed
// (police file)" switch on, there is no bar. Used by S94 `joinForm` (wave 2).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../state.dart';
import '../../ui/common.dart';
import '../../ui/kit.dart';
import '../listings/repo.dart';
import '../photos/pick.dart';

/// The camera (not the gallery: the ID is photographed now, not stored on the phone by us).
class CameraPicker implements PhotoPicker {
  const CameraPicker();
  @override
  Future<Uint8List?> pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 90);
    return f?.readAsBytes();
  }
}

/// Where the bar starts: over the lower middle of an Aadhaar card, where the
/// number is printed. Fractions of the image (left, top, width, height).
const defaultMaskBar = Rect.fromLTWH(.06, .62, .5, .09);

/// Burns the black bar [bar] (fractions of the image) into [jpg]; a JPEG at
/// quality 85 comes back. Null when the bytes aren't an image.
Uint8List? maskImage(Uint8List jpg, Rect bar) {
  img.Image? im;
  try {
    im = img.decodeImage(jpg);
  } catch (_) {
    return null;
  }
  if (im == null) return null;
  im = img.bakeOrientation(im);
  final x1 = (bar.left * im.width).round().clamp(0, im.width - 1), y1 = (bar.top * im.height).round().clamp(0, im.height - 1);
  final x2 = (bar.right * im.width).round().clamp(x1 + 1, im.width), y2 = (bar.bottom * im.height).round().clamp(y1 + 1, im.height);
  img.fillRect(im, x1: x1, y1: y1, x2: x2 - 1, y2: y2 - 1, color: img.ColorRgb8(0, 0, 0));
  return Uint8List.fromList(img.encodeJpg(im, quality: 85));
}

class IdCapture extends StatefulWidget {
  const IdCapture({super.key, required this.token, required this.fullCopy, required this.onUploaded, this.camera = const CameraPicker(), this.ownerName = ''});

  /// The join token (S94); the server finds the hostel and the owner's Drive from it.
  final String token;

  /// The owner's "Full copy needed (police file)" setting: no masking bar.
  /// Null: asked from the server by the token ([HostelRepo.idTarget]).
  final bool? fullCopy;
  final void Function(String fileId) onUploaded;
  final PhotoPicker camera;
  final String ownerName;
  @override
  State<IdCapture> createState() => _IdCaptureState();
}

class _IdCaptureState extends State<IdCapture> {
  bool? _fullCopy;
  Uint8List? _photo;
  double _ratio = 1.6;
  Rect _bar = defaultMaskBar;
  bool _busy = false;
  String? _fileId, _error;

  bool get _full => widget.fullCopy ?? _fullCopy ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.fullCopy == null && _fullCopy == null) {
      AppScope.of(context).data.idTarget(widget.token).then((t) {
        if (mounted) setState(() => _fullCopy = t?.fullCopy ?? false);
      }, onError: (Object e) => debugPrint('id target: $e'));
    }
  }

  Future<void> _take() async {
    setState(() => _busy = true);
    try {
      final raw = await widget.camera.pick();
      if (raw == null) return;
      // Shrunk to 1600 px, as taken (no crop): the whole card stays in.
      final prepped = prepPhoto(raw, 'free');
      if (prepped == null) {
        setState(() => _error = 'That isn’t a photo. Try again.');
        return;
      }
      final im = img.decodeImage(prepped);
      setState(() {
        _photo = prepped;
        _ratio = im == null || im.height == 0 ? 1.6 : im.width / im.height;
        _bar = defaultMaskBar;
        _error = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(AppState s) async {
    final photo = _photo;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = _full ? photo : maskImage(photo, _bar);
      if (bytes == null) throw const DriveFail('bad_image', 'That isn’t a photo. Try again.');
      final id = await s.data.idUpload(widget.token, bytes);
      if (!mounted) return;
      setState(() => _fileId = id);
      widget.onUploaded(id);
    } on DriveFail catch (e) {
      if (mounted) setState(() => _error = e.code == 'not_ready' ? 'Not available yet. Send your ID on WhatsApp instead.' : e.message);
    } catch (e) {
      debugPrint('id upload: $e');
      if (mounted) setState(() => _error = 'Couldn’t upload. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = PalScope.of(context);
    final photo = _photo;
    final who = widget.ownerName.isEmpty ? 'the owner' : widget.ownerName;
    if (_fileId != null) {
      return Container(
        key: const ValueKey('idDone'),
        padding: const EdgeInsets.all(12),
        decoration: box(w: 2, c: p.tx),
        child: Row(
          children: [
            Ic('check', size: 18, color: p.tx),
            const SizedBox(width: 10),
            Expanded(child: T('Uploaded to $who’s Google Drive. Nothing is kept on Hostelzy.', s: 14, lh: 1.4)),
          ],
        ),
      );
    }
    return VGap(
      gap: 10,
      children: [
        if (photo == null) ...[
          T('It goes straight to $who’s own Google Drive; Hostelzy never stores it.', s: 13, c: p.mu, lh: 1.45),
          Cta(_busy ? 'Opening the camera…' : 'Take a photo of your ID', key: const ValueKey('idTake'), icon: 'camera', height: 54, px: 16, fs: 15, opacity: _busy ? .6 : 1, onTap: _busy ? null : _take),
        ] else ...[
          T(_full ? '$who needs the full copy (police file). Check the photo is sharp.' : 'Cover the first 8 digits', w: 800, s: 15, key: const ValueKey('idGuide')),
          if (!_full) T('Drag the black bar over the first 8 digits of the ID number. Only the last 4 stay visible.', s: 13, c: p.mu, lh: 1.45),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = w / _ratio;
              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(child: Container(decoration: box(w: 2, c: p.tx), child: Image.memory(photo, fit: BoxFit.fill, gaplessPlayback: true))),
                    if (!_full)
                      Positioned(
                        left: _bar.left * w,
                        top: _bar.top * h,
                        child: GestureDetector(
                          key: const ValueKey('maskBar'),
                          onPanUpdate: (d) => setState(() {
                            final l = (_bar.left + d.delta.dx / w).clamp(0.0, 1 - _bar.width), t = (_bar.top + d.delta.dy / h).clamp(0.0, 1 - _bar.height);
                            _bar = Rect.fromLTWH(l, t, _bar.width, _bar.height);
                          }),
                          child: Container(
                            width: _bar.width * w,
                            height: _bar.height * h,
                            color: const Color(0xFF000000),
                            alignment: Alignment.center,
                            child: const T('drag', s: 11, c: Color(0xFF8A8A8A)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_error != null) T(_error!, s: 13, w: 800, c: p.ad, key: const ValueKey('idError')),
          Row(
            children: [
              Expanded(child: OutlineCta('Retake', key: const ValueKey('idRetake'), icon: 'camera', onTap: _busy ? () {} : _take)),
              const SizedBox(width: 10),
              Expanded(child: Cta(_busy ? 'Uploading…' : 'Upload', key: const ValueKey('idUpload'), height: 52, px: 16, fs: 15, opacity: _busy ? .6 : 1, onTap: _busy ? null : () => _upload(s))),
            ],
          ),
        ],
      ],
    );
  }
}
