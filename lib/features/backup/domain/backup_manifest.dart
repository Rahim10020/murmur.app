import 'dart:convert';

import '../../ideas/domain/idea.dart';

/// Format de sauvegarde Murmur (brief §9) :
///
/// ```text
/// murmur-backup-YYYY-MM-DD.zip
///   manifest.json
///   audio/<idea-id>.m4a
/// ```
///
/// Le manifeste est versionné ; les futurs schémas non supportés sont
/// rejetés avec une erreur explicite. Les chemins d'archive sont une
/// entrée hostile : validation défensive systématique.
class BackupFormat {
  const BackupFormat._();

  static const String appId = 'Murmur';
  static const int schemaVersion = 1;
  static const String manifestName = 'manifest.json';
  static const String audioPrefix = 'audio/';

  /// Garde-fous contre les archives déraisonnables.
  static const int maxIdeas = 10000;
  static const int maxManifestBytes = 10 * 1024 * 1024;
  static const int maxSingleAudioBytes = 200 * 1024 * 1024;
  static const int maxTotalAudioBytes = 1024 * 1024 * 1024;

  static bool isSafeEntryName(String name) {
    if (name.isEmpty) return false;
    if (name.startsWith('/') ||
        name.startsWith('\\') ||
        name.contains('..') ||
        name.contains('\\')) {
      return false;
    }
    if (name == manifestName) return true;
    if (!name.startsWith(audioPrefix)) return false;
    final base = name.substring(audioPrefix.length);
    if (base.isEmpty || base.contains('/')) return false;
    return IdeaFileNames.isSafe(base);
  }
}

/// Noms de fichiers audio sûrs partagés (évite la duplication).
class IdeaFileNames {
  const IdeaFileNames._();

  static bool isSafe(String value) {
    if (value.isEmpty) return false;
    if (value.contains('/') ||
        value.contains('\\') ||
        value.contains('..') ||
        value.startsWith('.')) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);
  }
}

/// Échec de validation d'une sauvegarde (archive ou manifeste).
class BackupValidationFailure implements Exception {
  const BackupValidationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Manifeste validé : métadonnées d'export + fiches idées.
class BackupManifest {
  const BackupManifest({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.ideas,
  });

  final int schemaVersion;
  final DateTime exportedAtUtc;
  final List<Idea> ideas;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'app': BackupFormat.appId,
      'backupSchemaVersion': schemaVersion,
      'exportedAtUtc': exportedAtUtc.toIso8601String(),
      'ideas': ideas.map((idea) {
        final map = Map<String, Object?>.from(idea.toMap());
        map['audio'] = '${BackupFormat.audioPrefix}${idea.audioFileName}';
        return map;
      }).toList(),
    };
  }

  /// Valide et parse un JSON décodé. Rejette tout ce qui est inattendu.
  static BackupManifest parse(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const BackupValidationFailure(
        'Manifeste invalide : objet JSON attendu.',
      );
    }
    if (json['app'] != BackupFormat.appId) {
      throw const BackupValidationFailure(
        'Archive non reconnue : ce n’est pas une sauvegarde Murmur.',
      );
    }
    final version = json['backupSchemaVersion'];
    if (version is! int) {
      throw const BackupValidationFailure(
        'Manifeste invalide : version de schéma manquante.',
      );
    }
    if (version > BackupFormat.schemaVersion) {
      throw BackupValidationFailure(
        'Sauvegarde trop récente (schéma v$version) : '
        'mettez Murmur à jour pour la restaurer.',
      );
    }
    if (version < 1) {
      throw const BackupValidationFailure(
        'Manifeste invalide : version de schéma inconnue.',
      );
    }
    final exportedRaw = json['exportedAtUtc'];
    final exportedAtUtc = exportedRaw is String
        ? DateTime.tryParse(exportedRaw)
        : null;
    if (exportedAtUtc == null || !exportedAtUtc.isUtc) {
      throw const BackupValidationFailure(
        'Manifeste invalide : date d’export UTC manquante.',
      );
    }
    final ideasRaw = json['ideas'];
    if (ideasRaw is! List) {
      throw const BackupValidationFailure(
        'Manifeste invalide : liste d’idées manquante.',
      );
    }
    if (ideasRaw.length > BackupFormat.maxIdeas) {
      throw const BackupValidationFailure(
        'Sauvegarde déraisonnable : trop d’idées.',
      );
    }
    final ideas = <Idea>[];
    final seenIds = <String>{};
    for (final entry in ideasRaw) {
      if (entry is! Map<String, Object?>) {
        throw const BackupValidationFailure(
          'Manifeste invalide : fiche idée malformée.',
        );
      }
      final audioRef = entry['audio'];
      Idea idea;
      try {
        idea = Idea.fromMap(entry);
      } catch (e) {
        throw BackupValidationFailure(
          'Manifeste invalide : fiche idée rejetée ($e).',
        );
      }
      if (!seenIds.add(idea.id)) {
        throw BackupValidationFailure(
          'Manifeste invalide : ID dupliqué (${idea.id}).',
        );
      }
      if (audioRef != '${BackupFormat.audioPrefix}${idea.audioFileName}') {
        throw BackupValidationFailure(
          'Manifeste invalide : référence audio incohérente '
          'pour ${idea.id}.',
        );
      }
      ideas.add(idea);
    }
    return BackupManifest(
      schemaVersion: version,
      exportedAtUtc: exportedAtUtc,
      ideas: ideas,
    );
  }

  /// Valide la disposition des entrées d'archive contre le manifeste.
  ///
  /// [entrySizes] associe chaque nom d'entrée à sa taille décompressée.
  static void validateLayout({
    required List<String> entryNames,
    required Map<String, int> entrySizes,
    required BackupManifest manifest,
  }) {
    for (final name in entryNames) {
      if (!BackupFormat.isSafeEntryName(name)) {
        throw BackupValidationFailure(
          'Archive rejetée : entrée interdite ($name).',
        );
      }
    }
    final expected = <String>{
      BackupFormat.manifestName,
      for (final idea in manifest.ideas)
        '${BackupFormat.audioPrefix}${idea.audioFileName}',
    };
    final actual = entryNames.toSet();
    final missing = expected.difference(actual);
    if (missing.isNotEmpty) {
      throw BackupValidationFailure(
        'Archive incomplète : fichiers manquants (${missing.take(3).join(', ')}).',
      );
    }
    final unexpected = actual.difference(expected);
    if (unexpected.isNotEmpty) {
      throw BackupValidationFailure(
        'Archive rejetée : fichiers inattendus '
        '(${unexpected.take(3).join(', ')}).',
      );
    }
    var total = 0;
    for (final idea in manifest.ideas) {
      final name = '${BackupFormat.audioPrefix}${idea.audioFileName}';
      final size = entrySizes[name] ?? 0;
      if (size <= 0) {
        throw BackupValidationFailure(
          'Archive rejetée : audio vide (${idea.id}).',
        );
      }
      if (size > BackupFormat.maxSingleAudioBytes) {
        throw BackupValidationFailure(
          'Archive rejetée : audio déraisonnable (${idea.id}).',
        );
      }
      total += size;
      if (total > BackupFormat.maxTotalAudioBytes) {
        throw const BackupValidationFailure(
          'Archive rejetée : taille totale déraisonnable.',
        );
      }
    }
  }
}

/// Nom de fichier suggéré pour l'export (brief §9).
String suggestedBackupFileName(DateTime nowLocal) {
  final y = nowLocal.year.toString().padLeft(4, '0');
  final m = nowLocal.month.toString().padLeft(2, '0');
  final d = nowLocal.day.toString().padLeft(2, '0');
  return 'murmur-backup-$y-$m-$d.zip';
}

/// Encode un manifeste en JSON UTF-8.
List<int> encodeManifest(BackupManifest manifest) {
  return utf8.encode(jsonEncode(manifest.toJson()));
}
