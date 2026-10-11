import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';

class FakePlayerBackend implements PlayerBackend {
  FakePlayerBackend({this.failOnLoad = false});

  bool failOnLoad;
  int playCount = 0;
  final StreamController<PlayerStatus> statuses =
      StreamController<PlayerStatus>.broadcast();

  @override
  Future<void> dispose() async {
    await statuses.close();
  }

  @override
  Future<Duration?> loadFile(String path) async {
    if (failOnLoad) throw StateError('codec hs');
    return const Duration(seconds: 30);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<PlayerStatus> statusStream() => statuses.stream;

  @override
  Future<void> stop() async {}

  void emitStatus(PlayerStatus status) => statuses.add(status);
}

PlayerStatus _status({
  Duration position = Duration.zero,
  Duration? duration = const Duration(seconds: 30),
  bool playing = true,
  bool completed = false,
}) {
  return PlayerStatus(
    position: position,
    duration: duration,
    playing: playing,
    completed: completed,
  );
}

Future<void> _flushEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

Idea _idea(String id) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 9, 12),
    updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
    audioFileName: '$id.m4a',
    durationMs: 30000,
    status: IdeaStatus.toReview,
  );
}

void main() {
  group('PlaybackController', () {
    test('play puis toggle pause/reprise', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final backend = FakePlayerBackend();
      final controller = PlaybackController(backend);
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      expect(controller.state, PlaybackState.playing);
      expect(controller.currentIdeaId, 'a');

      await controller.toggle(_idea('a'), audioPath);
      expect(controller.state, PlaybackState.paused);

      await controller.toggle(_idea('a'), audioPath);
      expect(controller.state, PlaybackState.playing);
      expect(backend.playCount, 2);
    });

    test('la position émise traverse jusqu’au contrôleur', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final backend = FakePlayerBackend();
      final controller = PlaybackController(backend);
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      backend.emitStatus(_status(position: const Duration(seconds: 7)));
      await _flushEvents();

      expect(controller.position, const Duration(seconds: 7));
      expect(controller.state, PlaybackState.playing);
    });

    test('fin de lecture via stream : état completed', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final backend = FakePlayerBackend();
      final controller = PlaybackController(backend);
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      backend.emitStatus(
        _status(
          position: const Duration(seconds: 30),
          playing: false,
          completed: true,
        ),
      );
      await _flushEvents();

      expect(controller.state, PlaybackState.completed);
      expect(controller.position, const Duration(seconds: 30));
    });

    test('interruption externe : playing -> paused', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final backend = FakePlayerBackend();
      final controller = PlaybackController(backend);
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      // La lecture doit d'abord être confirmée par le natif ; ensuite une
      // interruption externe (playing:false) bascule bien en pause.
      backend.emitStatus(_status(playing: true));
      await _flushEvents();
      backend.emitStatus(_status(playing: false));
      await _flushEvents();

      expect(controller.state, PlaybackState.paused);
    });

    test('fichier manquant : erreur récupérable, pas de crash', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));

      final controller = PlaybackController(FakePlayerBackend());
      addTearDown(controller.dispose);

      await controller.play(_idea('ghost'), '${dir.path}/ghost.m4a');
      expect(controller.state, PlaybackState.error);
      expect(controller.errorMessage, contains('introuvable'));
    });

    test('échec chargement : erreur affichable', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final controller = PlaybackController(
        FakePlayerBackend(failOnLoad: true),
      );
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      expect(controller.state, PlaybackState.error);
    });

    test('stopIfCurrent coupe le son de l’idée supprimée', () async {
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final controller = PlaybackController(FakePlayerBackend());
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      await controller.stopIfCurrent('b');
      expect(controller.state, PlaybackState.playing);
      await controller.stopIfCurrent('a');
      expect(controller.state, PlaybackState.idle);
    });

    test('faux signal initial playing:false ne coupe pas le 1er tap', () async {
      // Repro du bug critique : just_audio émet des statuts initiaux avec
      // playing:false (valeurs par défaut du wrapper, buffering) juste après
      // play(). Ils ne doivent pas rabattre vers paused avant confirmation.
      final dir = await Directory.systemTemp.createTemp('murmur-play-');
      addTearDown(() => dir.delete(recursive: true));
      final audioPath = '${dir.path}/a.m4a';
      await File(audioPath).writeAsBytes(<int>[1]);

      final backend = FakePlayerBackend();
      final controller = PlaybackController(backend);
      addTearDown(controller.dispose);

      await controller.play(_idea('a'), audioPath);
      expect(controller.state, PlaybackState.playing);

      // Faux signal initial : reste en lecture.
      backend.emitStatus(_status(playing: false));
      await _flushEvents();
      expect(controller.state, PlaybackState.playing);
      expect(controller.isPlaying('a'), isTrue);

      // Confirmation native : toujours en lecture.
      backend.emitStatus(_status(playing: true));
      await _flushEvents();
      expect(controller.state, PlaybackState.playing);

      // Interruption GENUINE après confirmation : bascule en pause.
      backend.emitStatus(_status(playing: false));
      await _flushEvents();
      expect(controller.state, PlaybackState.paused);
    });
  });
}
