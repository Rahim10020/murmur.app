import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Schéma SQLite local Murmur.
///
/// Version 1 : table `ideas` conforme au brief §8.
/// Les migrations futures s'ajoutent dans [_migrate] sans jamais
/// détruire la base en production.
class IdeaDatabase {
  static const int schemaVersion = 1;
  static const String tableName = 'ideas';
  static const String databaseFileName = 'murmur.db';

  const IdeaDatabase._();

  static Future<Database> open({String? path}) async {
    final dbPath = path ?? join(await getDatabasesPath(), databaseFileName);
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onCreate: (db, version) async {
        await _createV1(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrate(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
CREATE TABLE $tableName (
  id TEXT PRIMARY KEY,
  createdAtUtc INTEGER NOT NULL,
  updatedAtUtc INTEGER NOT NULL,
  audioFileName TEXT NOT NULL,
  durationMs INTEGER NOT NULL DEFAULT 0,
  title TEXT NULL,
  status TEXT NOT NULL,
  reminderAtUtc INTEGER NULL,
  lastReviewedAtUtc INTEGER NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_ideas_created ON $tableName(createdAtUtc DESC)',
    );
    await db.execute('CREATE INDEX idx_ideas_status ON $tableName(status)');
    await db.execute(
      'CREATE INDEX idx_ideas_reminder ON $tableName(reminderAtUtc)',
    );
  }

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // V1 : rien à migrer. Les futures versions ajoutent ici des
    // paliers `if (oldVersion < 2) { ... }` sans perte de données.
    if (oldVersion < 1 || newVersion < oldVersion) {
      throw StateError(
        'Migration de base non supportée : $oldVersion -> $newVersion',
      );
    }
  }
}
