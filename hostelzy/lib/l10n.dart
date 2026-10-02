import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// F21 W4: Telugu first, then Hindi. Strings live in assets/l10n/app_<lang>.arb,
// keyed by the English text, and only hold what a person wrote or checked:
// no machine translation in the app. Anything missing shows in English.

/// One language's strings and whether a native speaker checked them.
class LangPack {
  const LangPack(this.code, this.name, this.strings, {this.reviewed = false});
  final String code, name;
  final Map<String, String> strings;
  final bool reviewed;

  /// The picker shows a language only once it has strings; "beta" until checked.
  String get label => reviewed ? name : '$name (beta)';

  static LangPack fromArb(String code, String name, String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return LangPack(
      code,
      name,
      {for (final e in m.entries) if (!e.key.startsWith('@') && e.value is String && (e.value as String).trim().isNotEmpty) e.key: e.value as String},
      reviewed: m['@@reviewed'] == true,
    );
  }
}

const langNames = {'te': 'తెలుగు', 'hi': 'हिन्दी'};

/// Reads the ARB files bundled with the app (missing or broken: none).
Future<Map<String, LangPack>> loadLangs() async {
  final out = <String, LangPack>{};
  for (final e in langNames.entries) {
    try {
      out[e.key] = LangPack.fromArb(e.key, e.value, await rootBundle.loadString('assets/l10n/app_${e.key}.arb'));
    } catch (_) {}
  }
  return out;
}

/// The strings for the language picked; `T` looks text up here.
class LangScope extends InheritedWidget {
  const LangScope({super.key, required this.strings, required super.child});
  final Map<String, String> strings;
  static String tr(BuildContext c, String text) {
    final m = c.dependOnInheritedWidgetOfExactType<LangScope>()?.strings;
    return m == null || m.isEmpty ? text : (m[text] ?? text);
  }

  @override
  bool updateShouldNotify(LangScope old) => !identical(old.strings, strings);
}
