part of '../../state.dart';

// B7 photos: owners upload, order and pick a cover; tenants browse them.
mixin _PhotosData {
  /// Photos by hostel id, as loaded from the server (cover first).
  final Map<String, List<HostelPhoto>> photosOf = {};
  final Set<String> _photosLoading = {};

  /// Perf: hostels waiting for their photos, fetched together (see loadPhotos).
  final Map<String, Completer<void>> _photoQueue = {};

  /// Owner Photos screen: the album (Hostel or a room type).
  String photoAlbum = 'Hostel';

  /// Uploads in progress or failed, shown in the grid.
  List<PhotoUpload> uploads = [];

  /// Crop screen draft.
  Uint8List? cropBytes;
  String cropAspect = '4:3', cropLabel = 'Front';
  bool cropCover = false;

  /// Tenant gallery: category chip and the photo shown.
  String galleryCat = 'All';
  int galleryAt = 0;

  PhotoPicker picker = const NoPicker();

  /// The photo the owner tapped (sheet 'photo').
  String? photoSel;

  /// F24: the team adding photos to a draft hostel (null: the owner's own).
  String? photoFor;
}

/// A photo on its way up. [stage]: 1 prepared, 2 uploaded; [failed] → retry.
class PhotoUpload {
  PhotoUpload(this.key, this.hid, this.album, this.label, this.jpg, {this.cover = false});
  final String key, hid, album, label;
  final Uint8List jpg;
  final bool cover;
  int stage = 1;
  bool failed = false;
  int get percent => stage * 50;
}

/// Labels a photo can have in the Hostel album.
const hostelPhotoLabels = ['Front', 'Room', 'Washroom', 'Food', 'Common'];

extension PhotosActions on AppState {
  /// The hostel the Photos screen is for.
  String get photoHid => photoFor ?? ownHid;

  /// Room-type albums for [hid]: "3 sharing", "AC rooms"…
  List<String> photoAlbums(String hid) {
    final types = <String>{};
    var ac = false;
    for (final r in rooms[hid] ?? const <Room>[]) {
      if (r.ac) {
        ac = true;
      } else {
        types.add('${r.share} sharing');
      }
    }
    final sorted = types.toList()..sort();
    return ['Hostel', ...sorted.take(ac ? 1 : 2), if (ac) 'AC rooms'];
  }

  String albumOf(HostelPhoto p) => hostelPhotoLabels.contains(p.label) || p.label.isEmpty ? 'Hostel' : p.label;

  List<HostelPhoto> photosIn(String hid, String album) => [for (final p in photosOf[hid] ?? const <HostelPhoto>[]) if (albumOf(p) == album) p];

  /// Loads a hostel's photos once (detail page, owner Photos).
  /// Perf: the hostels asked for in the same frame (Explore's cards) are
  /// fetched together in one query instead of one query per card.
  Future<void> loadPhotos(String hid, {bool again = false}) {
    if ((!again && photosOf.containsKey(hid)) || _photosLoading.contains(hid)) return Future.value();
    _photosLoading.add(hid);
    if (_photoQueue.isEmpty) scheduleMicrotask(_fetchPhotoQueue);
    return (_photoQueue[hid] = Completer<void>()).future;
  }

  Future<void> _fetchPhotoQueue() async {
    final q = Map.of(_photoQueue);
    _photoQueue.clear();
    final hids = q.keys.toList();
    try {
      final got = hids.length == 1 ? {hids.first: await data.photos(hids.first)} : await data.photosOfMany(hids);
      update(() => photosOf.addAll(got));
    } catch (e) {
      debugPrint('photos: $e');
    } finally {
      _photosLoading.removeAll(hids);
      for (final c in q.values) {
        c.complete();
      }
    }
  }

  void openPhotos() {
    update(() {
      photoFor = null;
      photoAlbum = 'Hostel';
      hist = [...hist, screen];
      screen = 'oPhotos';
    });
    loadPhotos(ownHid);
  }

  /// Add photos: pick one, then crop it.
  Future<void> addPhoto() async {
    final b = await picker.pick();
    if (b == null) return;
    update(() {
      cropBytes = b;
      cropAspect = '4:3';
      cropLabel = photoAlbum == 'Hostel' ? 'Front' : photoAlbum;
      cropCover = photosIn(photoHid, 'Hostel').isEmpty && photoAlbum == 'Hostel';
      hist = [...hist, screen];
      screen = 'oCrop';
    });
  }

  void cancelCrop() => update(() {
    cropBytes = null;
    back();
  });

  /// Use: crop + compress, then upload in the background.
  Future<void> useCrop() async {
    final b = cropBytes;
    if (b == null) return;
    final jpg = prepPhoto(b, cropAspect);
    if (jpg == null) return toastMsg('That file isn’t a photo. Pick another.');
    final album = hostelPhotoLabels.contains(cropLabel) ? 'Hostel' : cropLabel;
    final u = PhotoUpload('u${DateTime.now().microsecondsSinceEpoch}', photoHid, album, cropLabel, jpg, cover: cropCover);
    update(() {
      cropBytes = null;
      photoAlbum = album;
      uploads = [...uploads, u];
      back();
    });
    await _upload(u);
  }

  Future<void> retryUpload(PhotoUpload u) async {
    update(() => u.failed = false);
    await _upload(u);
  }

  Future<void> _upload(PhotoUpload u) async {
    try {
      final ps = photosOf[u.hid] ?? const <HostelPhoto>[];
      final got = await data.addPhoto(u.hid, u.jpg, label: u.label, ord: ps.length, cover: u.cover);
      update(() {
        u.stage = 2;
        uploads = [for (final x in uploads) if (x != u) x];
        photosOf[u.hid] = sortPhotos([for (final p in ps) u.cover ? (id: p.id, path: p.path, url: p.url, label: p.label, ord: p.ord, cover: false) : p, got]);
      });
    } on UnsupportedError {
      update(() => uploads = [for (final x in uploads) if (x != u) x]);
      toastMsg('Photos upload in the real Hostelzy app. This is sample data.');
    } catch (e) {
      debugPrint('upload: $e');
      update(() => u.failed = true);
    }
  }

  /// Drag [from] onto [to] (same album). In the Hostel album the first photo
  /// is the cover.
  Future<void> movePhoto(String hid, HostelPhoto from, HostelPhoto to) async {
    final album = albumOf(from);
    final list = photosIn(hid, album);
    final i = list.indexWhere((p) => p.id == from.id), j = list.indexWhere((p) => p.id == to.id);
    if (i < 0 || j < 0 || i == j) return;
    list.insert(j, list.removeAt(i));
    final coverId = album == 'Hostel' ? list.first.id : (photosOf[hid] ?? const []).where((p) => p.cover).firstOrNull?.id ?? '';
    final others = [for (final p in photosOf[hid] ?? const <HostelPhoto>[]) if (albumOf(p) != album) p];
    final ordered = [
      for (final (k, p) in list.indexed) (id: p.id, path: p.path, url: p.url, label: p.label, ord: k, cover: p.id == coverId),
      for (final p in others) (id: p.id, path: p.path, url: p.url, label: p.label, ord: p.ord, cover: p.id == coverId),
    ];
    update(() => photosOf[hid] = sortPhotos(ordered));
    try {
      await data.savePhotoOrder(list, coverId);
    } catch (e) {
      toastMsg('Couldn’t save the new order. Check your internet.');
    }
  }

  HostelPhoto? get selPhoto => (photosOf[photoHid] ?? const <HostelPhoto>[]).where((p) => p.id == photoSel).firstOrNull;

  /// Hostel album: moves the photo to the front, so it becomes the cover.
  Future<void> makeCover(HostelPhoto p) async {
    update(() => sheet = null);
    final first = photosIn(photoHid, 'Hostel').firstOrNull;
    if (first == null || first.id == p.id) return;
    await movePhoto(photoHid, p, first);
  }

  Future<void> deletePhoto(String hid, HostelPhoto p) async {
    update(() => sheet = null);
    update(() => photosOf[hid] = [for (final x in photosOf[hid] ?? const <HostelPhoto>[]) if (x.id != p.id) x]);
    try {
      await data.removePhoto(p);
    } catch (e) {
      toastMsg('Couldn’t remove it. Check your internet.');
      unawaited(loadPhotos(hid, again: true));
    }
  }

  // ---------------------------------------------------------------- tenant gallery

  /// Gallery categories: Rooms (any room type), Washroom, Food, Common, Front.
  String galleryCatOf(HostelPhoto p) => switch (p.label) {
    'Washroom' || 'Food' || 'Common' || 'Front' => p.label,
    _ => 'Rooms',
  };

  List<HostelPhoto> galleryList(String hid) => [for (final p in photosOf[hid] ?? const <HostelPhoto>[]) if (galleryCat == 'All' || galleryCatOf(p) == galleryCat) p];

  void openGallery(String hid, [int at = 0]) => update(() {
    galleryCat = 'All';
    galleryAt = at;
    hist = [...hist, screen];
    screen = 'gallery';
  });

  void pickGalleryCat(String c) => update(() {
    galleryCat = c;
    galleryAt = 0;
  });
}
