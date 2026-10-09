import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../features/capture/data/recorder_backend.dart';
import '../features/capture/data/recording_service.dart';
import '../features/capture/presentation/capture_controller.dart';
import '../features/ideas/data/idea_database.dart';
import '../features/ideas/data/player_backend.dart';
import '../features/ideas/data/sqflite_idea_repository.dart';
import '../features/ideas/domain/idea_repository.dart';
import '../features/ideas/presentation/ideas_controller.dart';
import '../features/ideas/presentation/ideas_page.dart';
import '../features/ideas/presentation/playback_controller.dart';
import '../features/reminders/data/flutter_reminder_service.dart';
import '../features/reminders/domain/reminder_policy.dart';
import '../shared/services/app_directories.dart';
import 'theme.dart';

/// Racine applicative Murmur.
///
/// Ouvre la base locale, prépare le dossier audio, nettoie les fichiers
/// temporaires abandonnés, initialise les rappels puis réconcilie la
/// planification OS avec la DB (source de vérité).
/// Les erreurs d'ouverture sont affichées plutôt que masquées (brief §5).
class MurmurApp extends StatefulWidget {
  const MurmurApp({super.key});

  @override
  State<MurmurApp> createState() => _MurmurAppState();
}

class _MurmurAppState extends State<MurmurApp> {
  IdeasController? _ideas;
  CaptureController? _capture;
  PlaybackController? _playback;
  RecordingService? _recordingService;
  ReminderService? _reminders;
  StreamSubscription<String?>? _tapSubscription;
  IdeaRepository? _repository;
  Directory? _audioDir;
  final ValueNotifier<String?> _highlightedIdeaId = ValueNotifier(null);
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    FlutterReminderService? reminderService;
    try {
      final db = await IdeaDatabase.open();
      final repository = SqfliteIdeaRepository(db);
      final audioDir = await AppDirectories.audioDirectory();
      final recordingService = RecordingService(
        repository: repository,
        backend: RecordRecorderBackend(),
        audioDirectoryProvider: () async => audioDir,
      );
      // Fichiers temporaires abandonnés (crash pendant une capture).
      await recordingService.cleanupStaleTempFiles();

      // Rappels : init plugin + fuseau, puis réconciliation DB -> OS.
      reminderService = FlutterReminderService();
      try {
        await reminderService.init();
      } catch (_) {
        // Les rappels sont indisponibles mais l'app reste utilisable.
        reminderService = null;
      }
      final ideas = IdeasController(repository);
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
      if (!mounted) {
        await recordingService.dispose();
        await reminderService?.dispose();
        await repository.close();
        ideas.dispose();
        return;
      }
      final tapSub = reminderService?.onNotificationTap.listen((ideaId) {
        if (ideaId != null) _highlightedIdeaId.value = ideaId;
      });
      String? coldStartId;
      try {
        coldStartId = await reminderService?.initialNotificationIdeaId();
      } catch (_) {
        coldStartId = null;
      }
      setState(() {
        _repository = repository;
        _audioDir = audioDir;
        _recordingService = recordingService;
        _reminders = reminderService;
        _tapSubscription = tapSub;
        _ideas = ideas;
        _capture = CaptureController(
          recordingService,
          onSaved: () => _ideas?.refresh() ?? Future.value(),
        );
        _playback = PlaybackController(JustAudioPlayerBackend());
        if (coldStartId != null) _highlightedIdeaId.value = coldStartId;
      });
    } catch (e) {
      if (reminderService != null) {
        try {
          await reminderService.dispose();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _error = 'Impossible de démarrer Murmur : $e');
    }
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    _capture?.dispose();
    _playback?.dispose();
    _ideas?.dispose();
    _recordingService?.dispose();
    _reminders?.dispose();
    _repository?.close();
    _highlightedIdeaId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Murmur',
      theme: MurmurTheme.light(),
      darkTheme: MurmurTheme.dark(),
      home: _error != null
          ? Scaffold(
              appBar: AppBar(title: const Text('Murmur')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          : _ideas == null ||
                _capture == null ||
                _playback == null ||
                _audioDir == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : IdeasPage(
              controller: _ideas!,
              capture: _capture!,
              playback: _playback!,
              reminders: _reminders ?? _DisabledReminderService(),
              audioDir: _audioDir!,
              highlightedIdeaId: _highlightedIdeaId,
            ),
    );
  }
}

/// Secours si le plugin de rappels est indisponible : les opérations
/// rappels échouent avec un message clair au lieu de crasher.
class _DisabledReminderService implements ReminderService {
  @override
  Future<void> cancelReminder(String ideaId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> init() async {}

  @override
  Future<String?> initialNotificationIdeaId() async => null;

  @override
  Stream<String?> get onNotificationTap => const Stream.empty();

  @override
  Future<Set<int>> pendingNotificationIds() async => <int>{};

  @override
  Future<void> reconcile(Map<String, DateTime> futureByIdea) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleReminder({
    required String ideaId,
    required DateTime whenUtc,
  }) async {
    throw StateError(
      'Les rappels sont indisponibles sur cet appareil pour le moment.',
    );
  }
}
