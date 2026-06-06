import 'package:flutter/material.dart';
import '../services/localization_service.dart';

/// Syntactic sugar: call `L10n.t('key')` for translations.
class L10n {
  static LocalizationService get _s => LocalizationService();
  static String t(String key, {Map<String, String>? params}) =>
      _s.t(key, params: params);
}

/// BuildContext extension for quick access: `context.t('key')`
extension L10nContext on BuildContext {
  String t(String key, {Map<String, String>? params}) =>
      L10n.t(key, params: params);
}
