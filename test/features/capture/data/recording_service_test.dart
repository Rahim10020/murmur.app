import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/capture/data/recorder_backend.dart';
import 'package:murmur/features/capture/data/recording_service.dart';
import 'package:murmur/features/capture/domain/capture_errors.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeRecorderBackend implements RecorderBackend {
  FakeRecorderBackend({this.permissionGranted = true});

  bool permissionGranted;
  bool failOnStart = false;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastPath;

  @override
  Future<void> cancel() async {
    cancelCount++;
    if (lastPath != null) {
      final file = File(lastPath!);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start({required String path}) async {
    startCount++;
    if (failOnStart) throw StateError('micro indisponible');
    lastPath = path;
    // Simule le fichier produit par le plugin natif.
    await File(path).writeAsBytes(<int>[1, 2, 3]);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class FailingRepository extends SqfliteIdeaRepository {
  FailingRepository(super.db);

  @override
  Future<void> insert(Idea idea) async {
    throw StateError('db pleine');
  }
}

Future<Directory> _tempAudioDir() {
  return Directory.systemTemp.createTemp('murmur-audio-test-');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RecordingService', () {
    test(
      'start -> stopAndSave écrit .m4a + fiche, double start refusé',
      () async {
        final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
        final repo = SqfliteIdeaRepository(db);
        final backend = FakeRecorderBackend();
        final audioDir = await _tempAudioDir();
        final service = RecordingService(
          repository: repo,
          backend: backend,
          audioDirectoryProvider: () async => audioDir,
          idGenerator: () => 'idea-1',
        );
        try {
          await service.start();
          expect(service.isRecording, isTrue);
          await expectLater(
            service.start(),
            throwsA(isA<RecordingAlreadyActive>()),
          );
          expect(backend.startCount, 1);

          final idea = await service.stopAndSave();
          expect(idea.id, 'idea-1');
          expect(idea.audioFileName, 'idea-1.m4a');
          expect(idea.status, IdeaStatus.toReview);
          expect(File('${audioDir.path}/idea-1.m4a').existsSync(), isTrue);
          expect(
            File('${audioDir.path}/idea-1.part.m4a').existsSync(),
            isFalse,
          );
          expect((await repo.findById('idea-1'))?.id, 'idea-1');
        } finally {
          await repo.close();
          await audioDir.delete(recursive: true);
        }
      },
    );

    test('permission refusée : aucun fichier, aucun état actif', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final backend = FakeRecorderBackend(permissionGranted: false);
      final audioDir = await _tempAudioDir();
      final service = RecordingService(
        repository: repo,
        backend: backend,
        audioDirectoryProvider: () async => audioDir,
      );
      try {
        await expectLater(service.start(), throwsA(isA<MicPermissionDenied>()));
        expect(service.isRecording, isFalse);
        expect(backend.startCount, 0);
      } finally {
        await repo.close();
        await audioDir.delete(recursive: true);
      }
    });

    test(
      'échec métadonnées : fichier conservé + MetadataSaveFailure',
      () async {
        final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
        final repo = FailingRepository(db);
        final backend = FakeRecorderBackend();
        final audioDir = await _tempAudioDir();
        final service = RecordingService(
          repository: repo,
          backend: backend,
          audioDirectoryProvider: () async => audioDir,
          idGenerator: () => 'idea-9',
        );
        try {
          await service.start();
          await expectLater(
            service.stopAndSave(),
            throwsA(isA<MetadataSaveFailure>()),
          );
          // Récupération possible : l'audio est toujours là.
          expect(File('${audioDir.path}/idea-9.m4a').existsSync(), isTrue);
        } finally {
          await repo.close();
          await audioDir.delete(recursive: true);
        }
      },
    );

    test('discard annule et supprime le temporaire', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final backend = FakeRecorderBackend();
      final audioDir = await _tempAudioDir();
      final service = RecordingService(
        repository: repo,
        backend: backend,
        audioDirectoryProvider: () async => audioDir,
        idGenerator: () => 'idea-2',
      );
      try {
        await service.start();
        await service.discard();
        expect(service.isRecording, isFalse);
        expect(backend.cancelCount, 1);
        expect(File('${audioDir.path}/idea-2.part.m4a').existsSync(), isFalse);
        expect(await repo.findById('idea-2'), isNull);
      } finally {
        await repo.close();
        await audioDir.delete(recursive: true);
      }
    });

    test('cleanupStaleTempFiles supprime les .part, garde les .m4a', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final backend = FakeRecorderBackend();
      final audioDir = await _tempAudioDir();
      final service = RecordingService(
        repository: repo,
        backend: backend,
        audioDirectoryProvider: () async => audioDir,
      );
      try {
        await File('${audioDir.path}/a.part.m4a').writeAsString('x');
        await File('${audioDir.path}/b.part.m4a').writeAsString('x');
        await File('${audioDir.path}/c.m4a').writeAsString('x');
        final removed = await service.cleanupStaleTempFiles();
        expect(removed, 2);
        expect(File('${audioDir.path}/c.m4a').existsSync(), isTrue);
      } finally {
        await repo.close();
        await audioDir.delete(recursive: true);
      }
    });

    test('stop sans enregistrement refusé', () async {
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final service = RecordingService(
        repository: repo,
        backend: FakeRecorderBackend(),
        audioDirectoryProvider: _tempAudioDir,
      );
      try {
        await expectLater(
          service.stopAndSave(),
          throwsA(isA<NoActiveRecording>()),
        );
      } finally {
        await repo.close();
      }
    });
  });
}
