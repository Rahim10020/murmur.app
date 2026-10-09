import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../ideas/domain/idea.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../domain/backup_manifest.dart';

/// Échec d'export/restauration (hors validation : IO, archive illisible…).
class BackupFailure implements Exception {
  const BackupFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Aperçu d'une archive avant restauration (confirmation explicite).
class BackupPreview {
  const BackupPreview({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.ideaCount,
    required this.totalAudioBytes,
  });

  final int schemaVersion;
  final DateTime exportedAtUtc;
  final int ideaCount;
  final int totalAudioBytes;
}

/// Compte-rendu de restauration.
class RestoreReport {
  const RestoreReport({
    required this.restoredCount,
    required this.rescheduledCount,
    required this.skippedPastCount,
    required this.schedulingErrors,
  });

  final int restoredCount;
  final int rescheduledCount;
  final int skippedPastCount;
  final List<String> schedulingErrors;
}

/// Export et restauration locale (brief §3 et §9).
///
/// Stratégie : valider intégralement avant toute mutation, mettre en scène
/// les fichiers d'abord, remplacer la DB en transaction, puis seulement
/// toucher aux anciens audios. Mode « remplacer » uniquement, après
/// confirmation explicite de l'UI et sauvegarde de sécurité.
class BackupService {
  const BackupService();

  /// Construit l'archive ZIP : manifeste + audios référencés uniquement.
  ///
  /// Ni caches, ni journaux, ni temporaires (`*.part.m4a` exclus par
  /// construction : seuls les fichiers des fiches sont embarqués).
  Future<Uint8List> createArchive({
    required List<Idea> ideas,
    required Directory audioDir,
  }) async {
    final manifest = BackupManifest(
      schemaVersion: BackupFormat.schemaVersion,
      exportedAtUtc: DateTime.now().toUtc(),
      ideas: List<Idea>.unmodifiable(ideas),
    );
    final archive = Archive();
    final manifestBytes = encodeManifest(manifest);
    archive.addFile(
      ArchiveFile(
        BackupFormat.manifestName,
        manifestBytes.length,
        manifestBytes,
      ),
    );
    for (final idea in ideas) {
      final file = File(p.join(audioDir.path, idea.audioFileName));
      late final Uint8List audioBytes;
      try {
        audioBytes = await file.readAsBytes();
      } catch (_) {
        throw BackupFailure(
          'Export impossible : audio manquant pour ${idea.id}.',
        );
      }
      if (audioBytes.isEmpty) {
        throw BackupFailure('Export impossible : audio vide (${idea.id}).');
      }
      archive.addFile(
        ArchiveFile(
          '${BackupFormat.audioPrefix}${idea.audioFileName}',
          audioBytes.length,
          audioBytes,
        ),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Contrôle une archive sans rien modifier. Lève [BackupValidationFailure].
  Future<BackupPreview> inspectArchive(Uint8List bytes) async {
    final decoded = _decodeAndValidate(bytes);
    var total = 0;
    for (final idea in decoded.manifest.ideas) {
      total += decoded.audioFor(idea.audioFileName).length;
    }
    return BackupPreview(
      schemaVersion: decoded.manifest.schemaVersion,
      exportedAtUtc: decoded.manifest.exportedAtUtc,
      ideaCount: decoded.manifest.ideas.length,
      totalAudioBytes: total,
    );
  }

  /// Restaure en mode « remplacer » après validation complète.
  ///
  /// L'appelant (UI) doit avoir obtenu la confirmation explicite et
  /// constitué la sauvegarde de sécurité via [createSafetyBackup].
  /// Les rappels futurs sont replanifiés, les passés sont ignorés
  /// et comptés (jamais re-déclenchés comme actifs).
  Future<RestoreReport> restoreArchive({
    required Uint8List bytes,
    required Future<void> Function(List<Idea> ideas) replaceIdeas,
    required Directory audioDir,
    required Directory stagingDir,
    ReminderService? reminders,
  }) async {
    final decoded = _decodeAndValidate(bytes);
    final manifest = decoded.manifest;

    // 1. Mise en scène : octets validés uniquement, noms sûrs uniquement.
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }
    final staged = <String, File>{};
    try {
      for (final idea in manifest.ideas) {
        final data = decoded.audioFor(idea.audioFileName);
        final stagedFile = File(p.join(stagingDir.path, idea.audioFileName));
        await stagedFile.writeAsBytes(data, flush: true);
        staged[idea.audioFileName] = stagedFile;
      }

      // 2. Remplacement DB en transaction (tout ou rien).
      await replaceIdeas(manifest.ideas);

      // 3. Installation des audios, puis seulement suppression des anciens
      //    fichiers devenus orphelins.
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final wanted = manifest.ideas.map((e) => e.audioFileName).toSet();
      for (final entry in staged.entries) {
        final target = File(p.join(audioDir.path, entry.key));
        await entry.value.copy(target.path);
      }
      await for (final entity in audioDir.list()) {
        if (entity is File && p.extension(entity.path) == '.m4a') {
          final base = p.basename(entity.path);
          // Les temporaires d'enregistrement en cours (*.part.m4a) sont
          // préservés : nettoyés au démarrage par le service de capture.
          if (!wanted.contains(base) && !_isInProgressTemp(base)) {
            try {
              await entity.delete();
            } catch (_) {
              // Orphelin tenace : signalé au prochain nettoyage, pas fatal.
            }
          }
        }
      }
    } finally {
      for (final file in staged.values) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }

    // 4. Rappels : futurs replanifiés, passés ignorés.
    var rescheduled = 0;
    var skippedPast = 0;
    final schedulingErrors = <String>[];
    if (reminders != null) {
      final nowUtc = DateTime.now().toUtc();
      for (final idea in manifest.ideas) {
        final reminder = idea.reminderAtUtc;
        if (reminder == null) continue;
        if (!reminder.isAfter(nowUtc)) {
          skippedPast++;
          continue;
        }
        try {
          await reminders.scheduleReminder(ideaId: idea.id, whenUtc: reminder);
          rescheduled++;
        } catch (e) {
          schedulingErrors.add('${idea.id} : $e');
        }
      }
    } else {
      skippedPast = manifest.ideas
          .where(
            (idea) =>
                idea.reminderAtUtc != null &&
                !idea.reminderAtUtc!.isAfter(DateTime.now().toUtc()),
          )
          .length;
    }
    return RestoreReport(
      restoredCount: manifest.ideas.length,
      rescheduledCount: rescheduled,
      skippedPastCount: skippedPast,
      schedulingErrors: schedulingErrors,
    );
  }

  /// Sauvegarde de sécurité des données actuelles avant remplacement.
  /// Ne conserve que les [keepMax] plus récentes.
  Future<File> createSafetyBackup({
    required List<Idea> ideas,
    required Directory audioDir,
    required Directory safetyDir,
    int keepMax = 2,
  }) async {
    if (!await safetyDir.exists()) {
      await safetyDir.create(recursive: true);
    }
    final bytes = await createArchive(ideas: ideas, audioDir: audioDir);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File(p.join(safetyDir.path, 'safety-$stamp.zip'));
    await file.writeAsBytes(bytes, flush: true);
    final existing =
        await safetyDir
              .list()
              .where(
                (e) => e is File && p.basename(e.path).startsWith('safety-'),
              )
              .cast<File>()
              .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    while (existing.length > keepMax) {
      final oldest = existing.removeAt(0);
      try {
        await oldest.delete();
      } catch (_) {}
    }
    return file;
  }

  _DecodedBackup _decodeAndValidate(Uint8List bytes) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BackupValidationFailure('Archive illisible : $e.');
    }
    ArchiveFile? manifestFile;
    final names = <String>[];
    final sizes = <String, int>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      names.add(file.name);
      sizes[file.name] = file.size;
      if (file.name == BackupFormat.manifestName) manifestFile = file;
    }
    if (manifestFile == null) {
      throw const BackupValidationFailure(
        'Archive rejetée : manifest.json introuvable.',
      );
    }
    if (manifestFile.size > BackupFormat.maxManifestBytes) {
      throw const BackupValidationFailure(
        'Archive rejetée : manifeste déraisonnable.',
      );
    }
    late final Object? json;
    try {
      json = jsonDecode(utf8.decode(manifestFile.content));
    } catch (_) {
      throw const BackupValidationFailure(
        'Archive rejetée : manifeste JSON invalide.',
      );
    }
    final manifest = BackupManifest.parse(json);
    BackupManifest.validateLayout(
      entryNames: names,
      entrySizes: sizes,
      manifest: manifest,
    );
    final audioByName = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith(BackupFormat.audioPrefix)) {
        audioByName[file.name] = file.content;
      }
    }
    return _DecodedBackup(manifest, audioByName);
  }
}

/// Archive décodée et validée : manifeste + audios indexés par nom sûr.
class _DecodedBackup {
  const _DecodedBackup(this.manifest, this.audioByName);

  final BackupManifest manifest;
  final Map<String, Uint8List> audioByName;

  Uint8List audioFor(String safeFileName) {
    final data = audioByName['${BackupFormat.audioPrefix}$safeFileName'];
    if (data == null) {
      throw BackupValidationFailure(
        'Archive incomplète : audio manquant ($safeFileName).',
      );
    }
    return data;
  }
}

/// Temporaire d'enregistrement en cours (voir RecordingService).
/// Dupliqué ici pour éviter une dépendance backup -> capture.
bool _isInProgressTemp(String baseFileName) {
  return baseFileName.endsWith('.part.m4a');
}
