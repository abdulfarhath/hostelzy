// B7: picking and preparing a photo. Kept apart from the UI so tests can use
// a fake picker and real (small) images.

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

abstract class PhotoPicker {
  /// A photo from the gallery, or null when the user backs out.
  Future<Uint8List?> pick();
}

class NoPicker implements PhotoPicker {
  const NoPicker();
  @override
  Future<Uint8List?> pick() async => null;
}

class GalleryPicker implements PhotoPicker {
  const GalleryPicker();
  @override
  Future<Uint8List?> pick() async {
    // The phone shrinks it first; [prepPhoto] then crops and compresses.
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 90);
    return f?.readAsBytes();
  }
}

/// Crop aspect: '4:3' (listing), '1:1' (square) or 'free' (as taken).
double? aspectOf(String a) => switch (a) { '4:3' => 4 / 3, '1:1' => 1.0, _ => null };

/// Centre-crops [bytes] to [aspect], fits it in 1600 px and saves a JPEG at
/// quality 80: a typical phone photo goes from 3–5 MB to about 200–400 KB.
/// Null when the file isn't an image.
Uint8List? prepPhoto(Uint8List bytes, String aspect) {
  img.Image? im;
  try {
    im = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (im == null) return null;
  im = img.bakeOrientation(im);
  final a = aspectOf(aspect);
  if (a != null) {
    var w = im.width, h = im.height;
    if (w / h > a) {
      w = (h * a).round();
    } else {
      h = (w / a).round();
    }
    im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
  }
  if (im.width > 1600 || im.height > 1600) {
    im = im.width >= im.height ? img.copyResize(im, width: 1600) : img.copyResize(im, height: 1600);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}
