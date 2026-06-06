import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple localization service that loads ARB files and provides
/// translations via [t(key)].
class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._();
  factory LocalizationService() => _instance;
  LocalizationService._();

  Locale _locale = const Locale('zh');
  Map<String, dynamic> _strings = {};

  Locale get locale => _locale;

  /// Load translations for [locale] from the ARB file.
  Future<void> load(Locale locale) async {
    _locale = locale;
    final code = locale.languageCode;
    try {
      final jsonStr = await rootBundle.loadString('lib/l10n/app_$code.arb');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      // Filter out keys starting with '@' (metadata)
      final entries = data.entries
          .where((e) => !e.key.startsWith('@'))
          .map((e) => MapEntry<String, String>(e.key, e.value.toString()));
      _strings = Map<String, dynamic>.fromEntries(entries);
    } catch (_) {
      // Fallback to Chinese if file not found
      _strings = {};
    }
    notifyListeners();
  }

  /// Get translated string for [key], optionally replacing placeholders
  /// like {count} with values from [params].
  String t(String key, {Map<String, String>? params}) {
    final text = _strings[key] as String? ?? key;
    if (params != null) {
      var result = text;
      for (final entry in params.entries) {
        result = result.replaceAll('{${entry.key}}', entry.value);
      }
      return result;
    }
    return text;
  }
}
