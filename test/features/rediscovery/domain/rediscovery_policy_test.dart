import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/rediscovery/domain/rediscovery_policy.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Idea _idea(
  String id,
  DateTime createdAtUtc, {
  IdeaStatus status = IdeaStatus.toReview,
  DateTime? reminderAtUtc,
  DateTime? lastReviewedAtUtc,
}) {
  return Idea(
    id: id,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: createdAtUtc,
    audioFileName: '$id.m4a',
    durationMs: 1000,
    status: status,
    reminderAtUtc: reminderAtUtc,
    lastReviewedAtUtc: lastReviewedAtUtc,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime.utc(2026, 10, 9, 12);

  group('RediscoveryPolicy.isEligible', () {
    test('idée simple éligible', () {
      expect(
        RediscoveryPolicy.isEligible(
          _idea('a', DateTime.utc(2026, 10, 1)),
          now,
        ),
        isTrue,
      );
    });

    test('done et archived exclus', () {
      for (final status in [IdeaStatus.done, IdeaStatus.archived]) {
        expect(
          RediscoveryPolicy.isEligible(
            _idea('a', DateTime.utc(2026, 10, 1), status: status),
            now,
          ),
          isFalse,
        );
      }
    });

    test('inProgress reste éligible (ni done ni archived)', () {
      expect(
        RediscoveryPolicy.isEligible(
          _idea('a', DateTime.utc(2026, 10, 1), status: IdeaStatus.inProgress),
          now,
        ),
        isTrue,
      );
    });

    test('rappel futur bloque, rappel passé ne bloque pas', () {
      expect(
        RediscoveryPolicy.isEligible(
          _idea(
            'a',
            DateTime.utc(2026, 10, 1),
            reminderAtUtc: DateTime.utc(2026, 10, 10),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        RediscoveryPolicy.isEligible(
          _idea(
            'a',
            DateTime.utc(2026, 10, 1),
            reminderAtUtc: DateTime.utc(2026, 10, 8),
          ),
          now,
        ),
        isTrue,
      );
    });

    test('revue récemment exclue, après cooldown réintégrée', () {
      expect(
        RediscoveryPolicy.isEligible(
          _idea(
            'a',
            DateTime.utc(2026, 10, 1),
            lastReviewedAtUtc: DateTime.utc(2026, 10, 8),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        RediscoveryPolicy.isEligible(
          _idea(
            'a',
            DateTime.utc(2026, 10, 1),
            lastReviewedAtUtc: DateTime.utc(2026, 9, 20),
          ),
          now,
        ),
        isTrue,
      );
    });

    test('comparaison non-UTC refusée', () {
      expect(
        () => RediscoveryPolicy.isEligible(
          _idea('a', DateTime.utc(2026, 10, 1)),
          DateTime(2026, 10, 9, 12),
        ),
        throwsArgumentError,
      );
    });
  });

  group('RediscoveryPolicy.selectSession', () {
    test('plus anciennes d’abord, au plus 3, déterministe', () {
      final ideas = [
        _idea('new', DateTime.utc(2026, 10, 8)),
        _idea('old1', DateTime.utc(2026, 9, 1)),
        _idea('done', DateTime.utc(2026, 8, 1), status: IdeaStatus.done),
        _idea('old2', DateTime.utc(2026, 9, 10)),
        _idea(
          'reminded',
          DateTime.utc(2026, 8, 15),
          reminderAtUtc: DateTime.utc(2026, 10, 20),
        ),
        _idea('old3', DateTime.utc(2026, 9, 20)),
        _idea('old4', DateTime.utc(2026, 10, 1)),
      ];

      final first = RediscoveryPolicy.selectSession(ideas, now);
      final second = RediscoveryPolicy.selectSession(ideas, now);

      expect(first.map((e) => e.id).toList(), ['old1', 'old2', 'old3']);
      expect(second.map((e) => e.id).toList(), ['old1', 'old2', 'old3']);
    });

    test('moins de 3 éligibles : toutes retournées', () {
      final session = RediscoveryPolicy.selectSession([
        _idea('a', DateTime.utc(2026, 10, 1)),
      ], now);
      expect(session.map((e) => e.id).toList(), ['a']);
    });

    test('aucune éligible : session vide', () {
      expect(RediscoveryPolicy.selectSession([], now), isEmpty);
    });
  });

  group('markReviewed', () {
    test('pose lastReviewedAt et sort de la sélection', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      await repo.insert(_idea('a', DateTime.utc(2026, 10, 1)));
      final controller = IdeasController(repo);
      addTearDown(() async {
        controller.dispose();
        await repo.close();
      });

      await controller.markReviewed('a');

      final updated = controller.ideas.single;
      expect(updated.lastReviewedAtUtc, isNotNull);
      expect(updated.lastReviewedAtUtc!.isUtc, isTrue);
      final session = RediscoveryPolicy.selectSession(
        controller.ideas,
        DateTime.now().toUtc(),
      );
      expect(session, isEmpty);
    });

    test('idée inconnue : erreur explicite', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final controller = IdeasController(repo);
      addTearDown(() async {
        controller.dispose();
        await repo.close();
      });

      await expectLater(controller.markReviewed('ghost'), throwsStateError);
    });
  });
}
