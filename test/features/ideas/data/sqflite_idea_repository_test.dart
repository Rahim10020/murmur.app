import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqfliteIdeaRepository', () {
    test('insert + findById + listNewestFirst (plus récent d’abord)', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      try {
        await repo.insert(_idea('a', DateTime.utc(2026, 10, 7)));
        await repo.insert(_idea('b', DateTime.utc(2026, 10, 9)));
        await repo.insert(_idea('c', DateTime.utc(2026, 10, 8)));

        expect((await repo.findById('b'))?.id, 'b');
        expect(await repo.findById('missing'), isNull);

        final list = await repo.listNewestFirst();
        expect(list.map((e) => e.id).toList(), ['b', 'c', 'a']);
      } finally {
        await repo.close();
      }
    });

    test('update persiste, update sur inconnu échoue', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      try {
        await repo.insert(_idea('a', DateTime.utc(2026, 10, 9)));
        final updated = _idea(
          'a',
          DateTime.utc(2026, 10, 9),
        ).copyWith(status: IdeaStatus.done, title: () => 'Fait');
        await repo.update(updated);

        expect((await repo.findById('a'))?.status, IdeaStatus.done);

        await expectLater(
          repo.update(_idea('ghost', DateTime.utc(2026, 10, 9))),
          throwsStateError,
        );
      } finally {
        await repo.close();
      }
    });

    test('insert en double ID refusé (pas d’écrasement silencieux)', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      try {
        await repo.insert(_idea('a', DateTime.utc(2026, 10, 9)));
        await expectLater(
          repo.insert(_idea('a', DateTime.utc(2026, 10, 9))),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await repo.close();
      }
    });

    test('insert invalide refusé avant écriture', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      try {
        final evil = _idea('../evil', DateTime.utc(2026, 10, 9));
        await expectLater(repo.insert(evil), throwsArgumentError);
        expect(await repo.findById('../evil'), isNull);
      } finally {
        await repo.close();
      }
    });

    test('deleteById supprime sans erreur si absent', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      try {
        await repo.insert(_idea('a', DateTime.utc(2026, 10, 9)));
        await repo.deleteById('a');
        expect(await repo.findById('a'), isNull);
        await repo.deleteById('a');
      } finally {
        await repo.close();
      }
    });
  });
}
