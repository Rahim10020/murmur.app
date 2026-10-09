import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/backup/data/backup_service.dart';
import 'package:murmur/features/backup/domain/backup_manifest.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeReminderService implements ReminderService {
  final Map<String, DateTime> scheduled = <String, DateTime>{};

  @override
  Future<void> cancelReminder(String ideaId) async {
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
    scheduled[ideaId] = whenUtc;
  }
}

Idea _idea(String id, {DateTime? reminderAtUtc, String? status}) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 1),
    updatedAtUtc: DateTime.utc(2026, 10, 1),
    audioFileName: '$id.m4a',
    durationMs: 2000,
    status: status == 'done' ? IdeaStatus.done : IdeaStatus.toReview,
    reminderAtUtc: reminderAtUtc,
  );
}

Future<Directory> _seedAudio(Directory dir, List<String> names) async {
  if (!await dir.exists()) await dir.create(recursive: true);
  for (final name in names) {
    await File(p.join(dir.path, name)).writeAsBytes(<int>[1, 2, 3, 4]);
  }
  return dir;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const service = BackupService();

  group('BackupService round-trip', () {
    test(
      'export -> inspect -> restore : données et audios identiques',
      () async {
        final root = await Directory.systemTemp.createTemp('murmur-bak-');
        addTearDown(() => root.delete(recursive: true));
        final audioDir = await _seedAudio(
          Directory(p.join(root.path, 'audio')),
          ['a.m4a', 'b.m4a'],
        );
        final future = DateTime.now().toUtc().add(const Duration(days: 2));
        final ideas = [
          _idea('a', reminderAtUtc: future),
          _idea('b', status: 'done'),
        ];

        final bytes = await service.createArchive(
          ideas: ideas,
          audioDir: audioDir,
        );
        final preview = await service.inspectArchive(bytes);
        expect(preview.ideaCount, 2);
        expect(preview.totalAudioBytes, 8);

        final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
        final repo = SqfliteIdeaRepository(db);
        final controller = IdeasController(repo);
        final reminders = FakeReminderService();
        final staging = Directory(p.join(root.path, 'staging'));
        try {
          final report = await service.restoreArchive(
            bytes: bytes,
            replaceIdeas: controller.replaceAll,
            audioDir: audioDir,
            stagingDir: staging,
            reminders: reminders,
          );
          expect(report.restoredCount, 2);
          expect(report.rescheduledCount, 1);
          expect(report.skippedPastCount, 0);
          // SQLite persiste à la milliseconde.
          expect(
            reminders.scheduled['a']?.millisecondsSinceEpoch,
            future.millisecondsSinceEpoch,
          );

          await controller.refresh();
          expect(controller.ideas.map((e) => e.id).toSet(), {'a', 'b'});
          expect(await File(p.join(audioDir.path, 'a.m4a')).readAsBytes(), [
            1,
            2,
            3,
            4,
          ]);
        } finally {
          controller.dispose();
          await repo.close();
        }
      },
    );

    test('restore remplace : anciennes données et audios supprimés', () async {
      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final audioDir = await _seedAudio(Directory(p.join(root.path, 'audio')), [
        'old.m4a',
        'keep-part.part.m4a',
      ]);
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final controller = IdeasController(repo);
      try {
        await repo.insert(_idea('old'));

        final srcDir = Directory(p.join(root.path, 'src'))
          ..createSync(recursive: true);
        await File(p.join(srcDir.path, 'new.m4a')).writeAsBytes(<int>[9]);
        final bytes = await service.createArchive(
          ideas: [_idea('new')],
          audioDir: srcDir,
        );
        expect(bytes, isNotEmpty);

        final report = await service.restoreArchive(
          bytes: bytes,
          replaceIdeas: controller.replaceAll,
          audioDir: audioDir,
          stagingDir: Directory(p.join(root.path, 'staging')),
        );
        expect(report.restoredCount, 1);

        await controller.refresh();
        expect(controller.ideas.map((e) => e.id).toList(), ['new']);
        expect(File(p.join(audioDir.path, 'old.m4a')).existsSync(), isFalse);
        expect(
          File(p.join(audioDir.path, 'keep-part.part.m4a')).existsSync(),
          isTrue,
        );
        expect(await File(p.join(audioDir.path, 'new.m4a')).readAsBytes(), [9]);
      } finally {
        controller.dispose();
        await repo.close();
      }
    });

    test('rappels passés ignorés, jamais replanifiés', () async {
      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final srcDir = await _seedAudio(Directory(p.join(root.path, 'src')), [
        'a.m4a',
        'b.m4a',
      ]);
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      final bytes = await service.createArchive(
        ideas: [
          _idea('a', reminderAtUtc: past),
          _idea('b', reminderAtUtc: future),
        ],
        audioDir: srcDir,
      );

      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final controller = IdeasController(repo);
      final reminders = FakeReminderService();
      try {
        final report = await service.restoreArchive(
          bytes: bytes,
          replaceIdeas: controller.replaceAll,
          audioDir: Directory(p.join(root.path, 'audio')),
          stagingDir: Directory(p.join(root.path, 'staging')),
          reminders: reminders,
        );
        expect(report.skippedPastCount, 1);
        expect(report.rescheduledCount, 1);
        expect(reminders.scheduled.keys, ['b']);
      } finally {
        controller.dispose();
        await repo.close();
      }
    });
  });

  group('BackupService rejets', () {
    test('octets non-ZIP rejetés, données existantes intactes', () async {
      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final controller = IdeasController(repo);
      try {
        await repo.insert(_idea('keep'));
        await expectLater(
          service.restoreArchive(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            replaceIdeas: controller.replaceAll,
            audioDir: Directory(p.join(root.path, 'audio')),
            stagingDir: Directory(p.join(root.path, 'staging')),
          ),
          throwsA(isA<BackupValidationFailure>()),
        );
        await controller.refresh();
        expect(controller.ideas.map((e) => e.id).toList(), ['keep']);
      } finally {
        controller.dispose();
        await repo.close();
      }
    });

    test('archive hostile (traversal) rejetée avant toute mutation', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', 2, <int>[123, 125]))
        ..addFile(ArchiveFile('../evil.m4a', 3, <int>[1, 2, 3]));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
      final repo = SqfliteIdeaRepository(db);
      final controller = IdeasController(repo);
      try {
        await repo.insert(_idea('keep'));
        await expectLater(
          service.restoreArchive(
            bytes: bytes,
            replaceIdeas: controller.replaceAll,
            audioDir: Directory(p.join(root.path, 'audio')),
            stagingDir: Directory(p.join(root.path, 'staging')),
          ),
          throwsA(isA<BackupValidationFailure>()),
        );
        await controller.refresh();
        expect(controller.ideas.map((e) => e.id).toList(), ['keep']);
      } finally {
        controller.dispose();
        await repo.close();
      }
    });

    test('export avec audio manquant : échec explicite', () async {
      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final audioDir = Directory(p.join(root.path, 'audio'))..createSync();
      await expectLater(
        service.createArchive(ideas: [_idea('ghost')], audioDir: audioDir),
        throwsA(isA<BackupFailure>()),
      );
    });
  });

  group('Safety backup', () {
    test('créée et limitée aux 2 plus récentes', () async {
      final root = await Directory.systemTemp.createTemp('murmur-bak-');
      addTearDown(() => root.delete(recursive: true));
      final audioDir = await _seedAudio(Directory(p.join(root.path, 'audio')), [
        'a.m4a',
      ]);
      final safetyDir = Directory(p.join(root.path, 'safety'));
      final ideas = [_idea('a')];

      await service.createSafetyBackup(
        ideas: ideas,
        audioDir: audioDir,
        safetyDir: safetyDir,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.createSafetyBackup(
        ideas: ideas,
        audioDir: audioDir,
        safetyDir: safetyDir,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final third = await service.createSafetyBackup(
        ideas: ideas,
        audioDir: audioDir,
        safetyDir: safetyDir,
      );

      final files = safetyDir.listSync().whereType<File>().toList();
      expect(files.length, 2);
      expect(
        files.map((f) => p.basename(f.path)),
        contains(p.basename(third.path)),
      );
      // La sauvegarde de sécurité est elle-même une archive valide.
      final preview = await service.inspectArchive(await third.readAsBytes());
      expect(preview.ideaCount, 1);
    });
  });
}
