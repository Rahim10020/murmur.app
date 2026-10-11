import 'dart:io';

import 'package:murmur/features/capture/data/recorder_backend.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/l10n/app_strings.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../ideas/domain/idea.dart';
import '../domain/capture_errors.dart';

/// Orchestre un enregistrement récupérable (brief §3) :
///
/// 1. écrit dans un fichier temporaire `<uuid>.part.m4a` ;
/// 2. à l'arrêt, finalise en `<uuid>.m4a` puis insère les métadonnées ;
/// 3. si l'insertion échoue, le fichier est conservé et l'erreur remonte ;
/// 4. les fichiers temporaires abandonnés sont nettoyés au démarrage.
class RecordingService {
  RecordingService({
    required this.repository,
    required this.backend,
    required this.audioDirectoryProvider,
    String Function()? idGenerator,
    AppStrings? strings,
  }) : _idGenerator = idGenerator ?? const Uuid().v4,
       _strings = strings ?? const FrStrings();

  final IdeaRepository repository;
  final RecorderBackend backend;
  final Future<Directory> Function() audioDirectoryProvider;
  final String Function() _idGenerator;
  AppStrings _strings;

  /// Met à jour les chaînes (changement de langue).
  void setStrings(AppStrings strings) => _strings = strings;

  String? _activeId;
  DateTime? _startedAt;
  String? _tempPath;

  bool get isRecording => _activeId != null;
  String? get activeId => _activeId;
  DateTime? get startedAt => _startedAt;

  static String tempFileName(String id) => '$id.part.m4a';
  static String finalFileName(String id) => '$id.m4a';
  static bool isTempFileName(String name) => name.endsWith('.part.m4a');

  Future<void> start() async {
    if (isRecording) throw RecordingAlreadyActive(_strings.recordingAlreadyActive);
    final granted = await backend.hasPermission();
    if (!granted) throw const MicPermissionDenied();

    final dir = await audioDirectoryProvider();
    final id = _idGenerator();
    final tempPath = p.join(dir.path, tempFileName(id));
    try {
      await backend.start(path: tempPath);
    } catch (e) {
      throw RecordingFailure(_strings.recordingStartFailed(e));
    }
    _activeId = id;
    _startedAt = DateTime.now();
    _tempPath = tempPath;
  }

  /// Arrête, finalise le fichier et persiste la fiche idée.
  ///
  /// Retourne l'idée sauvegardée. En cas d'échec DB, le fichier reste
  /// sur disque et [MetadataSaveFailure] est levée.
  Future<Idea> stopAndSave({String? title}) async {
    final id = _activeId;
    final tempPath = _tempPath;
    final startedAt = _startedAt;
    if (id == null || tempPath == null || startedAt == null) {
      throw NoActiveRecording(_strings.noActiveRecording);
    }
    _activeId = null;
    _startedAt = null;
    _tempPath = null;

    try {
      await backend.stop();
    } catch (e) {
      throw RecordingFailure(_strings.recordingStopFailed(e));
    }

    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    final dir = await audioDirectoryProvider();
    final finalPath = p.join(dir.path, finalFileName(id));
    final tempFile = File(tempPath);
    if (!await tempFile.exists()) {
      throw RecordingFailure(_strings.recordingTempMissing);
    }
    await tempFile.rename(finalPath);

    final nowUtc = DateTime.now().toUtc();
    final idea = Idea(
      id: id,
      createdAtUtc: startedAt.toUtc(),
      updatedAtUtc: nowUtc,
      audioFileName: finalFileName(id),
      durationMs: durationMs,
      title: _cleanTitle(title),
      status: IdeaStatus.toReview,
    );
    try {
      await repository.insert(idea);
    } catch (e) {
      // Fichier conservé : l'utilisateur ne perd pas son audio.
      throw MetadataSaveFailure(finalPath, e);
    }
    return idea;
  }

  /// Annule l'enregistrement et supprime le fichier temporaire.
  Future<void> discard() async {
    final tempPath = _tempPath;
    _activeId = null;
    _startedAt = null;
    _tempPath = null;
    try {
      await backend.cancel();
    } catch (_) {
      // L'annulation best-effort ne doit pas masquer le nettoyage.
    }
    if (tempPath != null) {
      try {
        final file = File(tempPath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Nettoyage best-effort : repris au prochain démarrage.
      }
    }
  }

  /// Supprime les fichiers temporaires abandonnés. Retourne leur nombre.
  Future<int> cleanupStaleTempFiles() async {
    final dir = await audioDirectoryProvider();
    if (!await dir.exists()) return 0;
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is File && isTempFileName(p.basename(entity.path))) {
        try {
          await entity.delete();
          removed++;
        } catch (_) {
          // On continue avec les autres fichiers.
        }
      }
    }
    return removed;
  }

  Future<void> dispose() => backend.dispose();

  static String? _cleanTitle(String? title) {
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
