// B7: a hostel photo in Supabase Storage (bucket `hostel-photos`).

typedef HostelPhoto = ({String id, String path, String url, String label, int ord, bool cover});

/// Public URL of a file in the `hostel-photos` bucket.
String photoUrl(String base, String path) => '$base/storage/v1/object/public/hostel-photos/$path';

HostelPhoto photoFromRow(String base, Map<String, dynamic> r) => (
  id: r['id'] as String,
  path: r['path'] as String,
  url: photoUrl(base, r['path'] as String),
  label: r['label'] as String? ?? '',
  ord: r['ord'] as int? ?? 0,
  cover: r['cover'] as bool? ?? false,
);

/// Cover first, then by order.
List<HostelPhoto> sortPhotos(Iterable<HostelPhoto> ps) => [...ps]..sort((a, b) => a.cover != b.cover ? (a.cover ? -1 : 1) : a.ord.compareTo(b.ord));
