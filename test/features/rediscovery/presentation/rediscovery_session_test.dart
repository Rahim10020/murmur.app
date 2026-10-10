import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';
import 'package:murmur/features/rediscovery/presentation/rediscovery_session.dart';

class FakeIdeaRepository implements IdeaRepository {
  FakeIdeaRepository(this._ideas);

  final Map<String, Idea> _ideas;

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteById(String id) async {
    _ideas.remove(id);
  }

  @override
  Future<Idea?> findById(String id) async => _ideas[id];

  @override
  Future<void> insert(Idea idea) async {
    _ideas[idea.id] = idea;
  }

  @override
  Future<List<Idea>> listNewestFirst({int? limit}) async {
    final list = _ideas.values.toList()
      ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return list;
  }

  @override
  Future<void> replaceAll(List<Idea> ideas) async {
    _ideas
      ..clear()
      ..addEntries(ideas.map((e) => MapEntry(e.id, e)));
  }

  @override
  Future<void> update(Idea idea) async {
    if (!_ideas.containsKey(idea.id)) throw StateError('introuvable');
    _ideas[idea.id] = idea;
  }
}

class FakePlayerBackend implements PlayerBackend {
  @override
  Future<void> dispose() async {}

  @override
  Future<Duration?> loadFile(String path) async => null;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<PlayerStatus> statusStream() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

Idea _idea(String id, DateTime createdAtUtc) {
  return Idea(
    id: id,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: createdAtUtc,
    audioFileName: '$id.m4a',
    durationMs: 1000,
    status: IdeaStatus.toReview,
  );
}

Future<IdeasController> _controllerWith(List<Idea> ideas) async {
  final controller = IdeasController(
    FakeIdeaRepository({for (final e in ideas) e.id: e}),
  );
  await controller.refresh();
  return controller;
}

Future<Directory> _tempDir(WidgetTester tester) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('murmur-redis-'),
  ))!;
  addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
  return dir;
}

Future<void> _pumpTab(
  WidgetTester tester,
  IdeasController controller,
  Directory audioDir,
) async {
  final playback = PlaybackController(FakePlayerBackend());
  addTearDown(playback.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: RediscoverySessionPage(
        controller: controller,
        playback: playback,
        audioDir: audioDir,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Onglet Découverte', () {
    testWidgets('vide : message simple, sans actions', (tester) async {
      final controller = await _controllerWith([]);
      addTearDown(controller.dispose);
      final audioDir = await _tempDir(tester);

      await _pumpTab(tester, controller, audioDir);

      expect(find.text('Rien à redécouvrir pour le moment'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('liste simple : titres + lecture, sans boutons d’action', (
      tester,
    ) async {
      final controller = await _controllerWith([
        _idea('old', DateTime.utc(2026, 9, 1)),
        _idea('new', DateTime.utc(2026, 10, 1)),
      ]);
      addTearDown(controller.dispose);
      final audioDir = await _tempDir(tester);

      await _pumpTab(tester, controller, audioDir);

      // Les deux idées éligibles, plus ancienne d'abord.
      expect(find.textContaining('Idée du'), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.play), findsNWidgets(2));
      // Aucune action : ni statuts, ni rappel, ni boutons.
      expect(find.text('Garder pour plus tard'), findsNothing);
      expect(find.text('Marquer comme terminée'), findsNothing);
      expect(find.text('Me rappeler plus tard'), findsNothing);
      expect(find.text('Commencer à travailler dessus'), findsNothing);
      expect(find.text('Archiver'), findsNothing);
    });

    testWidgets('au plus 3 idées, les plus anciennes', (tester) async {
      final controller = await _controllerWith([
        for (var i = 1; i <= 5; i++) _idea('id-$i', DateTime.utc(2026, 9, i)),
      ]);
      addTearDown(controller.dispose);
      final audioDir = await _tempDir(tester);

      await _pumpTab(tester, controller, audioDir);

      expect(find.byType(ListTile), findsNWidgets(3));
    });
  });
}
