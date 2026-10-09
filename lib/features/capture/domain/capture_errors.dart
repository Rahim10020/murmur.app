/// Erreurs du domaine capture, avec messages destinés à l'UI (français).
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
  const RecordingAlreadyActive();

  @override
  String toString() => 'Un enregistrement est déjà en cours.';
}

class NoActiveRecording implements Exception {
  const NoActiveRecording();

  @override
  String toString() => 'Aucun enregistrement en cours.';
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
