import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/appearance.dart';
import 'package:murmur/features/capture/data/recorder_backend.dart';
import 'package:murmur/features/capture/data/recording_service.dart';
import 'package:murmur/features/capture/presentation/capture_controller.dart';
import 'package:murmur/features/ideas/data/idea_database.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/data/sqflite_idea_repository.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/ideas/presentation/ideas_page.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeIdeaRepository implements IdeaRepository {
  FakeIdeaRepository({this.ideas = const <Idea>[], this.shouldFail = false});

  final List<Idea> ideas;
  final bool shouldFail;

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<Idea?> findById(String id) async => null;

  @override
  Future<void> insert(Idea idea) async {}

  @override
  Future<List<Idea>> listNewestFirst({int? limit}) async {
    if (shouldFail) throw StateError('boom');
    return ideas;
  }

  @override
  Future<void> update(Idea idea) async {}

  @override
  Future<void> replaceAll(List<Idea> ideas) async {}
}

class FakeRecorderBackend implements RecorderBackend {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start({required String path}) async {
    await File(path).writeAsBytes(<int>[0]);
  }

  @override
  Future<void> stop() async {}
}

class FakeReminderService implements ReminderService {
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
    scheduled[ideaId] = whenUtc;
  }
}

class FakePlayerBackend implements PlayerBackend {
  @override
  Future<void> dispose() async {}

  @override
  Future<Duration?> loadFile(String path) async => const Duration(seconds: 30);

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

Idea _idea(String id) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 9, 12),
    updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
    audioFileName: '$id.m4a',
    durationMs: 30000,
    status: IdeaStatus.toReview,
  );
}

class _Fixtures {
  _Fixtures({
    required this.db,
    required this.audioDir,
    required this.ideas,
    required this.capture,
    required this.playback,
    required this.reminders,
    required this.appearance,
    required this.highlightedIdeaId,
    required this.service,
  });

  final Database db;
  final Directory audioDir;
  final IdeasController ideas;
  final CaptureController capture;
  final PlaybackController playback;
  final ReminderService reminders;
  final AppearanceController appearance;
  final ValueNotifier<String?> highlightedIdeaId;
  final RecordingService service;

  Future<void> dispose() async {
    highlightedIdeaId.dispose();
    ideas.dispose();
    capture.dispose();
    playback.dispose();
    appearance.dispose();
    await service.dispose();
    await db.close();
    if (await audioDir.exists()) {
      await audioDir.delete(recursive: true);
    }
  }
}

/// Les IO réelles (SQLite, fichiers) tournent dans [WidgetTester.runAsync]
/// car le corps des widget tests vit en zone FakeAsync.
Future<_Fixtures> _setUpFixtures(
  WidgetTester tester, {
  List<Idea> ideas = const <Idea>[],
  bool shouldFail = false,
}) async {
  final fixtures = await tester.runAsync(() async {
    final db = await IdeaDatabase.open(path: inMemoryDatabasePath);
    final audioDir = await Directory.systemTemp.createTemp('murmur-page-');
    final service = RecordingService(
      repository: SqfliteIdeaRepository(db),
      backend: FakeRecorderBackend(),
      audioDirectoryProvider: () async => audioDir,
    );
    return _Fixtures(
      db: db,
      audioDir: audioDir,
      ideas: IdeasController(
        FakeIdeaRepository(ideas: ideas, shouldFail: shouldFail),
      ),
      capture: CaptureController(service),
      playback: PlaybackController(FakePlayerBackend()),
      reminders: FakeReminderService(),
      appearance: AppearanceController(store: MemoryThemeModeStore()),
      highlightedIdeaId: ValueNotifier<String?>(null),
      service: service,
    );
  });
  return fixtures!;
}

Future<void> _pumpPage(WidgetTester tester, _Fixtures f) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IdeasPage(
        controller: f.ideas,
        capture: f.capture,
        playback: f.playback,
        reminders: f.reminders,
        audioDir: f.audioDir,
        safetyDir: f.audioDir,
        appearance: f.appearance,
        highlightedIdeaId: f.highlightedIdeaId,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('IdeasPage', () {
    testWidgets('état vide + bouton micro (Lucide)', (tester) async {
      final f = await _setUpFixtures(tester);
      addTearDown(() => tester.runAsync(f.dispose));
      await _pumpPage(tester, f);

      expect(find.textContaining('Aucune idée'), findsOneWidget);
      expect(find.byIcon(LucideIcons.audioLines), findsOneWidget);
      expect(find.textContaining('Appuyez sur le micro'), findsNothing);
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      expect(find.byIcon(LucideIcons.history), findsOneWidget);
    });

    testWidgets('liste les idées avec lecture et menu', (tester) async {
      final f = await _setUpFixtures(tester, ideas: [_idea('a'), _idea('b')]);
      addTearDown(() => tester.runAsync(f.dispose));
      await _pumpPage(tester, f);

      expect(find.textContaining('Idée du'), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.play), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.ellipsis), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.bell), findsNWidgets(2));
    });

    testWidgets('deep-link : idée mise en avant après tap notification', (
      tester,
    ) async {
      final f = await _setUpFixtures(tester, ideas: [_idea('a'), _idea('b')]);
      addTearDown(() => tester.runAsync(f.dispose));
      await _pumpPage(tester, f);

      f.highlightedIdeaId.value = 'b';
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // L'idée ciblée reste visible (défilement + surlignage, pas de crash).
      expect(find.textContaining('Idée du'), findsNWidgets(2));
    });

    testWidgets('erreur de chargement affichée sans crash', (tester) async {
      final f = await _setUpFixtures(tester, shouldFail: true);
      addTearDown(() => tester.runAsync(f.dispose));
      await _pumpPage(tester, f);

      expect(find.textContaining('Impossible de charger'), findsOneWidget);
    });
  });
}
