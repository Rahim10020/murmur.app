import 'package:sqflite/sqflite.dart';

import '../domain/idea.dart';
import '../domain/idea_repository.dart';
import 'idea_database.dart';

/// Implémentation SQLite de [IdeaRepository].
///
/// Les écritures valident le modèle avant insertion afin de ne jamais
/// persister une ligne dangereuse (chemin absolu, horodatage non-UTC…).
class SqfliteIdeaRepository implements IdeaRepository {
  SqfliteIdeaRepository(this._db);

  final Database _db;

  @override
  Future<void> insert(Idea idea) async {
    idea.validate();
    await _db.insert(
      IdeaDatabase.tableName,
      idea.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(Idea idea) async {
    idea.validate();
    final count = await _db.update(
      IdeaDatabase.tableName,
      idea.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[idea.id],
    );
    if (count == 0) {
      throw StateError('Idée introuvable pour mise à jour : ${idea.id}');
    }
  }

  @override
  Future<void> deleteById(String id) async {
    await _db.delete(
      IdeaDatabase.tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<Idea?> findById(String id) async {
    final rows = await _db.query(
      IdeaDatabase.tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Idea.fromMap(rows.first);
  }

  @override
  Future<List<Idea>> listNewestFirst({int? limit}) async {
    final rows = await _db.query(
      IdeaDatabase.tableName,
      orderBy: 'createdAtUtc DESC',
      limit: limit,
    );
    return rows.map(Idea.fromMap).toList();
  }

  @override
  Future<void> replaceAll(List<Idea> ideas) async {
    for (final idea in ideas) {
      idea.validate();
    }
    final seen = <String>{};
    for (final idea in ideas) {
      if (!seen.add(idea.id)) {
        throw ArgumentError.value(
          idea.id,
          'ideas',
          'ID dupliqué dans le remplacement.',
        );
      }
    }
    await _db.transaction((txn) async {
      await txn.delete(IdeaDatabase.tableName);
      for (final idea in ideas) {
        await txn.insert(
          IdeaDatabase.tableName,
          idea.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  @override
  Future<void> close() => _db.close();
}
