/// Choix de langue de l'utilisateur : système, français ou anglais.
///
/// Défaut : [system]. Fallback : français (comportement historique de l'app).
enum AppLocale { system, french, english }

/// Résout la langue effective à partir du choix utilisateur et du tag
/// système (ex. `fr_FR`, `en-US`, `es_ES`).
///
/// - `french`/`english` explicites gagnent toujours.
/// - `system` : `fr*` → français, `en*` → anglais, sinon français (fallback).
bool resolveIsFrench(AppLocale choice, String systemTag) {
  switch (choice) {
    case AppLocale.french:
      return true;
    case AppLocale.english:
      return false;
    case AppLocale.system:
      final tag = systemTag.toLowerCase();
      if (tag.startsWith('en')) return false;
      return true;
  }
}
