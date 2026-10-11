import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'app_strings.dart';

/// Stockage du choix de langue, isolé pour être testable sans plugin.
abstract class LocaleStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesLocaleStore implements LocaleStore {
  SharedPreferencesLocaleStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(LocaleController.storageKey);

  @override
  Future<void> write(String value) =>
      _prefs.setString(LocaleController.storageKey, value);
}

class MemoryLocaleStore implements LocaleStore {
  MemoryLocaleStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String newValue) async {
    value = newValue;
  }
}

/// Choix de langue (Système/Français/Anglais), persisté.
///
/// Défaut : [AppLocale.system] avec fallback français (comportement
/// historique conservé). Même pattern que `AppearanceController`.
class LocaleController extends ChangeNotifier {
  LocaleController({LocaleStore? store}) : _store = store ?? SharedPreferencesLocaleStore();

  static const String storageKey = 'murmur.locale';

  final LocaleStore _store;
  AppLocale _locale = AppLocale.system;

  AppLocale get locale => _locale;

  Future<void> load() async {
    try {
      _locale = _parse(await _store.read());
    } catch (_) {
      _locale = AppLocale.system;
    }
    notifyListeners();
  }

  Future<void> setLocale(AppLocale locale) async {
    _locale = locale;
    notifyListeners();
    try {
      await _store.write(locale.name);
    } catch (_) {
      // Le choix reste actif pour la session même si la persistance échoue.
    }
  }

  /// Chaînes effectives pour un tag système (`PlatformDispatcher.locale`).
  AppStrings stringsFor(String systemTag) =>
      resolveIsFrench(_locale, systemTag) ? const FrStrings() : const EnStrings();

  static AppLocale _parse(String? raw) {
    return switch (raw) {
      'french' => AppLocale.french,
      'english' => AppLocale.english,
      _ => AppLocale.system,
    };
  }
}
