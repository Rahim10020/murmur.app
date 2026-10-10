import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';
import 'package:murmur/features/rediscovery/presentation/rediscovery_session.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';

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

class FakeReminderService implements ReminderService {
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancelReminder(String ideaId) async {
    cancelled.add(ideaId);
  }

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
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleReminder({
    required String ideaId,
    required DateTime whenUtc,
  }) async {}
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

Future<void> _pumpTab(
  WidgetTester tester,
  IdeasController controller,
  Directory audioDir,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RediscoverySessionPage(
        controller: controller,
        playback: PlaybackController(FakePlayerBackend()),
        reminders: FakeReminderService(),
        audioDir: audioDir,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Onglet Découverte', () {
    testWidgets('vide : message simple, sans bouton', (tester) async {
      final controller = await _controllerWith([]);
      addTearDown(controller.dispose);
      final audioDir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('murmur-redis-'),
      ))!;
      addTearDown(
        () => tester.runAsync(() => audioDir.delete(recursive: true)),
      );

      await _pumpTab(tester, controller, audioDir);

      expect(find.text('Rien à redécouvrir pour le moment'), findsOneWidget);
      // Aucun bouton retour : on circule via la bottom nav bar.
      expect(find.text('Fermer'), findsNothing);
    });

    testWidgets('action -> carte suivante -> résumé sans bouton', (
      tester,
    ) async {
      final controller = await _controllerWith([
        _idea('old', DateTime.utc(2026, 9, 1)),
        _idea('new', DateTime.utc(2026, 10, 1)),
      ]);
      addTearDown(controller.dispose);
      final audioDir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('murmur-redis-'),
      ))!;
      addTearDown(
        () => tester.runAsync(() => audioDir.delete(recursive: true)),
      );

      await _pumpTab(tester, controller, audioDir);

      // La plus ancienne d'abord.
      expect(find.textContaining('01/09/'), findsOneWidget);

      await tester.tap(find.text('Garder pour plus tard'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('01/10/'), findsOneWidget);

      await tester.tap(find.text('Marquer comme terminée'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Session terminée. Vos idées sont à jour.'),
        findsOneWidget,
      );
      expect(find.text('Fermer'), findsNothing);
    });
  });
}
