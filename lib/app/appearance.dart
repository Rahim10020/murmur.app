import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage du choix d'apparence, isolé pour être testable sans plugin.
abstract class ThemeModeStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesThemeModeStore implements ThemeModeStore {
  SharedPreferencesThemeModeStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(AppearanceController.storageKey);

  @override
  Future<void> write(String value) =>
      _prefs.setString(AppearanceController.storageKey, value);
}

class MemoryThemeModeStore implements ThemeModeStore {
  MemoryThemeModeStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String newValue) async {
    value = newValue;
  }
}

/// Choix d'apparence de l'utilisateur (Système/Clair/Sombre), persisté.
///
/// Défaut : [ThemeMode.system] (comportement actuel conservé).
class AppearanceController extends ChangeNotifier {
  AppearanceController({ThemeModeStore? store})
    : _store = store ?? SharedPreferencesThemeModeStore();

  static const String storageKey = 'murmur.themeMode';

  final ThemeModeStore _store;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      _mode = _parse(await _store.read());
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      await _store.write(mode.name);
    } catch (_) {
      // Le choix reste actif pour la session même si la persistance échoue.
    }
  }

  static ThemeMode _parse(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
