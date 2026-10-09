import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/backup/domain/backup_manifest.dart';
import 'package:murmur/features/ideas/domain/idea.dart';

Map<String, Object?> _ideaJson(
  String id, {
  String? audioFileName,
  String status = 'toReview',
}) {
  return <String, Object?>{
    'id': id,
    'createdAtUtc': DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
    'updatedAtUtc': DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
    'audioFileName': audioFileName ?? '$id.m4a',
    'durationMs': 1000,
    'title': null,
    'status': status,
    'reminderAtUtc': null,
    'lastReviewedAtUtc': null,
    'audio': 'audio/${audioFileName ?? '$id.m4a'}',
  };
}

Map<String, Object?> _manifestJson(List<Map<String, Object?>> ideas) {
  return <String, Object?>{
    'app': 'Murmur',
    'backupSchemaVersion': 1,
    'exportedAtUtc': DateTime.utc(2026, 10, 9).toIso8601String(),
    'ideas': ideas,
  };
}

void main() {
  group('BackupManifest.parse', () {
    test('manifeste valide accepté', () {
      final manifest = BackupManifest.parse(
        _manifestJson([_ideaJson('a'), _ideaJson('b')]),
      );

      expect(manifest.schemaVersion, 1);
      expect(manifest.ideas.map((e) => e.id).toList(), ['a', 'b']);
      expect(manifest.exportedAtUtc.isUtc, isTrue);
    });

    test('rejette : non-Murmur, version future, JSON malformé', () {
      final wrongApp = _manifestJson([_ideaJson('a')])..['app'] = 'Autre';
      expect(
        () => BackupManifest.parse(wrongApp),
        throwsA(isA<BackupValidationFailure>()),
      );

      final future = _manifestJson([_ideaJson('a')])
        ..['backupSchemaVersion'] = 999;
      expect(
        () => BackupManifest.parse(future),
        throwsA(isA<BackupValidationFailure>()),
      );

      expect(
        () => BackupManifest.parse('chaîne'),
        throwsA(isA<BackupValidationFailure>()),
      );
      expect(
        () => BackupManifest.parse(null),
        throwsA(isA<BackupValidationFailure>()),
      );
    });

    test('rejette : IDs dupliqués, référence audio incohérente', () {
      expect(
        () => BackupManifest.parse(
          _manifestJson([_ideaJson('a'), _ideaJson('a')]),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );

      final incoherent = _ideaJson('a')..['audio'] = 'audio/autre.m4a';
      expect(
        () => BackupManifest.parse(_manifestJson([incoherent])),
        throwsA(isA<BackupValidationFailure>()),
      );
    });

    test('rejette : nom de fichier hostile, statut inconnu', () {
      expect(
        () => BackupManifest.parse(
          _manifestJson([_ideaJson('a', audioFileName: '../evil.m4a')]),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );
      expect(
        () => BackupManifest.parse(
          _manifestJson([_ideaJson('a', status: 'unknown')]),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );
    });

    test('aller-retour toJson/parse', () {
      final idea = Idea(
        id: 'x',
        createdAtUtc: DateTime.utc(2026, 10, 1),
        updatedAtUtc: DateTime.utc(2026, 10, 2),
        audioFileName: 'x.m4a',
        durationMs: 5000,
        title: 'Titre',
        status: IdeaStatus.inProgress,
        reminderAtUtc: DateTime.utc(2026, 10, 20),
        lastReviewedAtUtc: null,
      );
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAtUtc: DateTime.utc(2026, 10, 9),
        ideas: [idea],
      );
      final restored = BackupManifest.parse(
        jsonDecode(jsonEncode(manifest.toJson())),
      );
      expect(restored.ideas.single, equals(idea));
    });
  });

  group('BackupManifest.validateLayout', () {
    BackupManifest manifest() =>
        BackupManifest.parse(_manifestJson([_ideaJson('a'), _ideaJson('b')]));

    test('disposition valide acceptée', () {
      BackupManifest.validateLayout(
        entryNames: ['manifest.json', 'audio/a.m4a', 'audio/b.m4a'],
        entrySizes: {'manifest.json': 10, 'audio/a.m4a': 5, 'audio/b.m4a': 5},
        manifest: manifest(),
      );
    });

    test('rejette : traversal, absolu, inattendu, manquant', () {
      final base = {'manifest.json': 10, 'audio/a.m4a': 5, 'audio/b.m4a': 5};

      for (final evil in ['../x', '/abs', 'audio/../../x', 'other.txt']) {
        final names = [...base.keys, evil];
        expect(
          () => BackupManifest.validateLayout(
            entryNames: names,
            entrySizes: {...base, evil: 5},
            manifest: manifest(),
          ),
          throwsA(isA<BackupValidationFailure>()),
          reason: evil,
        );
      }

      expect(
        () => BackupManifest.validateLayout(
          entryNames: ['manifest.json', 'audio/a.m4a', 'audio/extra.m4a'],
          entrySizes: {
            'manifest.json': 10,
            'audio/a.m4a': 5,
            'audio/extra.m4a': 5,
          },
          manifest: manifest(),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );

      expect(
        () => BackupManifest.validateLayout(
          entryNames: ['manifest.json', 'audio/a.m4a'],
          entrySizes: {'manifest.json': 10, 'audio/a.m4a': 5},
          manifest: manifest(),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );
    });

    test('rejette : audio vide', () {
      expect(
        () => BackupManifest.validateLayout(
          entryNames: ['manifest.json', 'audio/a.m4a', 'audio/b.m4a'],
          entrySizes: {'manifest.json': 10, 'audio/a.m4a': 0, 'audio/b.m4a': 5},
          manifest: manifest(),
        ),
        throwsA(isA<BackupValidationFailure>()),
      );
    });

    test('nom de fichier suggéré', () {
      expect(
        suggestedBackupFileName(DateTime(2026, 10, 9, 15)),
        'murmur-backup-2026-10-09.zip',
      );
    });
  });
}
