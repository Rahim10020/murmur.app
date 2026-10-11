/// Erreurs du domaine capture. Les messages par défaut restent français
/// (compatibilité historique) ; les contrôleurs affichent la version
/// localisée via `AppStrings` quand elle est disponible.
class MicPermissionDenied implements Exception {
  const MicPermissionDenied([
    this.message =
        'Le micro est nécessaire pour enregistrer. '
        'Autorisez l’accès dans les réglages, puis réessayez.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class RecordingAlreadyActive implements Exception {
  const RecordingAlreadyActive([
    this.message = 'Un enregistrement est déjà en cours.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class NoActiveRecording implements Exception {
  const NoActiveRecording([
    this.message = 'Aucun enregistrement en cours.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Échec de la sauvegarde des métadonnées après un arrêt réussi.
///
/// Le fichier audio est conservé tel quel ([keptAudioPath]) : il ne doit
/// jamais être supprimé silencieusement (brief §3).
class MetadataSaveFailure implements Exception {
  const MetadataSaveFailure(this.keptAudioPath, this.cause);

  final String keptAudioPath;
  final Object cause;

  String get message =>
      'Enregistrement conservé, mais fiche non sauvegardée : $cause';

  @override
  String toString() => message;
}

class RecordingFailure implements Exception {
  const RecordingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
