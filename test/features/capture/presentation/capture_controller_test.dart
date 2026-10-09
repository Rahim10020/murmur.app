import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/capture/data/recorder_backend.dart';
import 'package:murmur/features/capture/data/recording_service.dart';
import 'package:murmur/features/capture/presentation/capture_controller.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeRecorderBackend implements RecorderBackend {
  FakeRecorderBackend({this.permissionGranted = true});

  bool permissionGranted;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start({required String path}) async {
    await File(path).writeAsBytes(<int>[0]);
  }

  @override
  Future<void> stop() async {}
}

Future<RecordingService> _service({bool permissionGranted = true}) async {
  final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
  final audioDir = await Directory.systemTemp.createTemp('murmur-cap-');
  final service = RecordingService(
    repository: SqfliteIdeaRepository(db),
    backend: FakeRecorderBackend(permissionGranted: permissionGranted),
    audioDirectoryProvider: () async => audioDir,
  );
  addTearDown(() async {
    await db.close();
    if (await audioDir.exists()) await audioDir.delete(recursive: true);
  });
  return service;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CaptureController', () {
    test(
      'start -> stopAndSave : recording puis idle, onSaved appelé',
      () async {
        final service = await _service();
        var savedCalls = 0;
        final controller = CaptureController(
          service,
          onSaved: () async {
            savedCalls++;
          },
        );
        addTearDown(controller.dispose);

        await controller.start();
        expect(controller.state, CaptureState.recording);

        await controller.stopAndSave();
        expect(controller.state, CaptureState.idle);
        expect(savedCalls, 1);
      },
    );

    test('permission refusée : état dédié + message', () async {
      final service = await _service(permissionGranted: false);
      final controller = CaptureController(service);
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.state, CaptureState.permissionDenied);
      expect(controller.errorMessage, isNotNull);
    });

    test('double start ignoré sans crash', () async {
      final service = await _service();
      final controller = CaptureController(service);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.start();
      expect(controller.state, CaptureState.recording);
      await controller.discard();
      expect(controller.state, CaptureState.idle);
    });

    test('stop sans recording : sans effet', () async {
      final service = await _service();
      final controller = CaptureController(service);
      addTearDown(controller.dispose);

      await controller.stopAndSave();
      expect(controller.state, CaptureState.idle);
    });
  });
}
