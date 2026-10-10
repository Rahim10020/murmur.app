import 'dart:io';

import '../features/capture/data/recorder_backend.dart';
import '../features/capture/data/recording_service.dart';
import '../features/capture/presentation/capture_controller.dart';
import '../features/ideas/data/idea_database.dart';
import '../features/ideas/data/player_backend.dart';
import '../features/ideas/data/sqflite_idea_repository.dart';
import '../features/ideas/domain/idea_repository.dart';
import '../features/ideas/presentation/ideas_controller.dart';
import '../features/ideas/presentation/playback_controller.dart';
import '../features/reminders/data/flutter_reminder_service.dart';
import '../features/reminders/domain/reminder_policy.dart';
import '../shared/services/app_directories.dart';

/// Dépendances assemblées au démarrage : base, dossiers, services,
/// contrôleurs. Le widget ne fait qu'assembler et disposer.
class AppScope {
  AppScope({
    required this.repository,
    required this.audioDir,
    required this.safetyDir,
    required this.recordingService,
    required this.reminders,
    required this.ideas,
    required this.capture,
    required this.playback,
    required this.initialIdeaId,
  });

  final IdeaRepository repository;
  final Directory audioDir;
  final Directory safetyDir;
  final RecordingService recordingService;
  final ReminderService? reminders;
  final IdeasController ideas;
  final CaptureController capture;
  final PlaybackController playback;

  /// ID d'idée du cold start via notification, `null` sinon.
  final String? initialIdeaId;

  Future<void> dispose() async {
    capture.dispose();
    playback.dispose();
    ideas.dispose();
    await recordingService.dispose();
    try {
      await reminders?.dispose();
    } catch (_) {}
    await repository.close();
  }
}

/// Ouvre la base locale, prépare les dossiers, nettoie les temporaires
/// abandonnés, initialise les rappels et réconcilie la planification OS
/// avec la DB (source de vérité).
///
/// En cas d'échec, les ressources déjà ouvertes sont refermées avant
/// de relancer l'erreur. Les rappels indisponibles n'empêchent pas le
/// démarrage : [AppScope.reminders] est alors `null`.
Future<AppScope> bootstrapApp() async {
  IdeaRepository? repository;
  RecordingService? recordingService;
  ReminderService? reminderService;
  IdeasController? ideas;
  var disposeIdeas = false;
  try {
    final db = await IdeaDatabase.open();
    repository = SqfliteIdeaRepository(db);
    final audioDir = await AppDirectories.audioDirectory();
    final safetyDir = await AppDirectories.safetyBackupDirectory();
    recordingService = RecordingService(
      repository: repository,
      backend: RecordRecorderBackend(),
      audioDirectoryProvider: () async => audioDir,
    );
    // Fichiers temporaires abandonnés (crash pendant une capture).
    await recordingService.cleanupStaleTempFiles();

    // Rappels : init plugin + fuseau, puis réconciliation DB -> OS.
    final candidate = FlutterReminderService();
    try {
      await candidate.init();
      reminderService = candidate;
    } catch (_) {
      // Les rappels sont indisponibles mais l'app reste utilisable.
      try {
        await candidate.dispose();
      } catch (_) {}
      reminderService = null;
    }
    ideas = IdeasController(repository);
    disposeIdeas = true;
    await ideas.refresh();
    if (reminderService != null) {
      final nowUtc = DateTime.now().toUtc();
      final future = <String, DateTime>{};
      for (final idea in ideas.ideas) {
        final reminder = idea.reminderAtUtc;
        if (ReminderPolicy.isActiveReminder(reminder, nowUtc)) {
          future[idea.id] = reminder!;
        }
      }
      await reminderService.reconcile(future);
    }
    String? coldStartId;
    try {
      coldStartId = await reminderService?.initialNotificationIdeaId();
    } catch (_) {
      coldStartId = null;
    }
    final scope = AppScope(
      repository: repository,
      audioDir: audioDir,
      safetyDir: safetyDir,
      recordingService: recordingService,
      reminders: reminderService,
      ideas: ideas,
      capture: CaptureController(
        recordingService,
        onSaved: () => ideas?.refresh() ?? Future.value(),
      ),
      playback: PlaybackController(JustAudioPlayerBackend()),
      initialIdeaId: coldStartId,
    );
    return scope;
  } catch (_) {
    if (disposeIdeas) {
      ideas?.dispose();
    }
    if (recordingService != null) {
      try {
        await recordingService.dispose();
      } catch (_) {}
    }
    if (reminderService != null) {
      try {
        await reminderService.dispose();
      } catch (_) {}
    }
    if (repository != null) {
      try {
        await repository.close();
      } catch (_) {}
    }
    rethrow;
  }
}
