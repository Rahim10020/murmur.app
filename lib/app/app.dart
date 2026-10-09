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
import '../shared/services/app_directories.dart';
import 'theme.dart';

/// Racine applicative Murmur.
///
/// Ouvre la base locale, prépare le dossier audio, nettoie les fichiers
/// temporaires abandonnés, puis expose liste + capture + lecture.
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
  IdeaRepository? _repository;
  Directory? _audioDir;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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
      if (!mounted) {
        await recordingService.dispose();
        await repository.close();
        return;
      }
      setState(() {
        _repository = repository;
        _audioDir = audioDir;
        _recordingService = recordingService;
        _ideas = IdeasController(repository);
        _capture = CaptureController(
          recordingService,
          onSaved: () => _ideas?.refresh() ?? Future.value(),
        );
        _playback = PlaybackController(JustAudioPlayerBackend());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de démarrer Murmur : $e');
    }
  }

  @override
  void dispose() {
    _capture?.dispose();
    _playback?.dispose();
    _ideas?.dispose();
    _recordingService?.dispose();
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              audioDir: _audioDir!,
            ),
    );
  }
}
