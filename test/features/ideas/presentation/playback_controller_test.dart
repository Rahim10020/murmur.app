import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';

class FakePlayerBackend implements PlayerBackend {
  FakePlayerBackend({this.failOnLoad = false});

  bool failOnLoad;
  Duration positionValue = Duration.zero;
  int playCount = 0;

  @override
  Future<void> dispose() async {}

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
  Duration get position => positionValue;

  @override
  Future<void> seek(Duration position) async {
    positionValue = position;
  }

  @override
  Future<void> stop() async {}
}

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
  });
}
