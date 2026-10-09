import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeReminderService implements ReminderService {
  FakeReminderService({this.failOnSchedule = false});

  bool failOnSchedule;
  final Map<String, DateTime> scheduled = <String, DateTime>{};
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancelReminder(String ideaId) async {
    cancelled.add(ideaId);
    scheduled.remove(ideaId);
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
  }) async {
    if (failOnSchedule) throw StateError('planification OS impossible');
    scheduled[ideaId] = whenUtc;
  }
}

Idea _idea(String id) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 9, 12),
    updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
    audioFileName: '$id.m4a',
    durationMs: 1000,
    status: IdeaStatus.toReview,
  );
}

Future<IdeasController> _controller() async {
  final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
  final repo = SqfliteIdeaRepository(db);
  await repo.insert(_idea('a'));
  final controller = IdeasController(repo);
  addTearDown(() async {
    controller.dispose();
    await repo.close();
  });
  return controller;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('IdeasController rappels', () {
    test('setReminder persiste DB + planifie OS', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));

      await controller.setReminder('a', when, reminders);

      // SQLite persiste à la milliseconde : comparaison à la ms près.
      expect(
        controller.ideas.single.reminderAtUtc?.millisecondsSinceEpoch,
        when.millisecondsSinceEpoch,
      );
      expect(reminders.scheduled['a'], when);
    });

    test('setReminder passé refusé, DB inchangée', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));

      await expectLater(
        controller.setReminder('a', past, reminders),
        throwsArgumentError,
      );
      await controller.refresh();
      expect(controller.ideas.single.reminderAtUtc, isNull);
      expect(reminders.scheduled, isEmpty);
    });

    test('échec OS : DB restaurée, pas de rappel fantôme', () async {
      final controller = await _controller();
      final reminders = FakeReminderService(failOnSchedule: true);
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));

      await expectLater(
        controller.setReminder('a', when, reminders),
        throwsStateError,
      );
      await controller.refresh();
      expect(controller.ideas.single.reminderAtUtc, isNull);
    });

    test('clearReminder supprime DB + annule OS', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      await controller.setReminder('a', when, reminders);

      await controller.clearReminder('a', reminders);

      expect(controller.ideas.single.reminderAtUtc, isNull);
      expect(reminders.cancelled, contains('a'));
    });

    test('setStatus done annule le rappel actif', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      await controller.setReminder('a', when, reminders);

      await controller.setStatus('a', IdeaStatus.done, reminders: reminders);

      final idea = controller.ideas.single;
      expect(idea.status, IdeaStatus.done);
      expect(idea.reminderAtUtc, isNull);
      expect(reminders.cancelled, contains('a'));
    });

    test('setStatus inProgress conserve le rappel', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      await controller.setReminder('a', when, reminders);

      await controller.setStatus(
        'a',
        IdeaStatus.inProgress,
        reminders: reminders,
      );

      expect(
        controller.ideas.single.reminderAtUtc?.millisecondsSinceEpoch,
        when.millisecondsSinceEpoch,
      );
      expect(reminders.cancelled, isEmpty);
    });

    test('deleteIdea annule le rappel', () async {
      final controller = await _controller();
      final reminders = FakeReminderService();
      final audioDir = await Directory.systemTemp.createTemp('murmur-del-');
      addTearDown(() async {
        if (await audioDir.exists()) await audioDir.delete(recursive: true);
      });
      final when = DateTime.now().toUtc().add(const Duration(hours: 2));
      await controller.setReminder('a', when, reminders);

      await controller.deleteIdea(
        controller.ideas.single,
        audioDir,
        reminders: reminders,
      );

      expect(controller.ideas, isEmpty);
      expect(reminders.cancelled, contains('a'));
    });
  });
}
