// F24 item 30: the last hostels list from the server, kept on this phone so
// Explore still shows something (marked as offline) when there's no network.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'hostelzy.listings.v1';

/// Keeps the server's hostel rows (with rooms, beds, rates…) and when.
Future<void> saveListingRows(List<Map<String, dynamic>> rows) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'rows': rows}));
  } catch (_) {}
}

/// The last rows kept, or null.
Future<({List<Map<String, dynamic>> rows, DateTime at})?> loadListingRows() async {
  try {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return null;
    final m = jsonDecode(s) as Map<String, dynamic>;
    return (rows: (m['rows'] as List).cast<Map<String, dynamic>>(), at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int));
  } catch (_) {
    return null;
  }
}
