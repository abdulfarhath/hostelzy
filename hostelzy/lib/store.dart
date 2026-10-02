// F18: what the app remembers on this phone between launches (login, name,
// phone, role, theme, holds, saved hostels, HZ codes). Until the backend is
// live (F13 part 2) this is the only place the user's own data lives.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class Store {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> data);
  Future<void> clear();
}

/// Nothing is kept (tests, previews).
class NoStore implements Store {
  const NoStore();
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<void> save(Map<String, dynamic> data) async {}
  @override
  Future<void> clear() async {}
}

/// In memory, for tests that check what would be saved.
class MemoryStore implements Store {
  Map<String, dynamic> data = {};
  @override
  Future<Map<String, dynamic>> load() async => jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> d) async => data = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
  @override
  Future<void> clear() async => data = {};
}

/// The phone's own storage (SharedPreferences), one JSON value.
class PrefsStore implements Store {
  static const _key = 'hostelzy.state.v1';
  @override
  Future<Map<String, dynamic>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode(data));
  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}
