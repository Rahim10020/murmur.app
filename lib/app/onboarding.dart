import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage du flag onboarding, isolé pour être testable sans plugin.
abstract class OnboardingStore {
  Future<bool?> readDone();
  Future<void> writeDone(bool value);
}

class SharedPreferencesOnboardingStore implements OnboardingStore {
  SharedPreferencesOnboardingStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool?> readDone() => _prefs.getBool(OnboardingController.storageKey);

  @override
  Future<void> writeDone(bool value) =>
      _prefs.setBool(OnboardingController.storageKey, value);
}

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore([this.value]);

  bool? value;

  @override
  Future<bool?> readDone() async => value;

  @override
  Future<void> writeDone(bool newValue) async {
    value = newValue;
  }
}

/// Onboarding première visite : affiché une seule fois, jamais bloquant.
///
/// Le brief interdit un onboarding obligatoire qui retarderait la première
/// capture : « Passer » reste toujours disponible et `complete()` ne fait
/// que persister le flag.
class OnboardingController extends ChangeNotifier {
  OnboardingController({OnboardingStore? store})
    : _store = store ?? SharedPreferencesOnboardingStore();

  static const String storageKey = 'murmur.onboardingDone';

  final OnboardingStore _store;
  bool _done = false;

  bool get done => _done;

  Future<void> load() async {
    try {
      _done = await _store.readDone() ?? false;
    } catch (_) {
      _done = false;
    }
    notifyListeners();
  }

  Future<void> complete() async {
    _done = true;
    notifyListeners();
    try {
      await _store.writeDone(true);
    } catch (_) {
      // Le flag reste actif pour la session même si la persistance échoue.
    }
  }
}
