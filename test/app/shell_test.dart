import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/appearance.dart';
import 'package:murmur/app/shell.dart';
import 'package:murmur/features/capture/data/recorder_backend.dart';
import 'package:murmur/features/capture/data/recording_service.dart';
import 'package:murmur/features/capture/presentation/capture_controller.dart';
import 'package:murmur/features/ideas/data/player_backend.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/ideas/presentation/ideas_page.dart';
import 'package:murmur/features/ideas/presentation/playback_controller.dart';
import 'package:murmur/features/rediscovery/presentation/rediscovery_session.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';
import 'package:murmur/features/settings/presentation/settings_page.dart';
import 'package:murmur/l10n/locale_controller.dart';
import 'package:murmur/shared/widgets/murmur_nav_bar.dart';

class FakeIdeaRepository implements IdeaRepository {
  FakeIdeaRepository({this.ideas = const <Idea>[]});

  final List<Idea> ideas;

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<Idea?> findById(String id) async => null;

  @override
  Future<void> insert(Idea idea) async {}

  @override
  Future<List<Idea>> listNewestFirst({int? limit}) async => ideas;

  @override
  Future<void> replaceAll(List<Idea> ideas) async {}

  @override
  Future<void> update(Idea idea) async {}
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

class FakePlayerBackend implements PlayerBackend {
  @override
  Future<void> dispose() async {}

  @override
  Future<Duration?> loadFile(String path) async => null;

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

class FakeReminderService implements ReminderService {
  @override
  Future<void> cancelReminder(String ideaId) async {}

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
  }) async {}
}

Idea _idea(String id) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 1),
    updatedAtUtc: DateTime.utc(2026, 10, 1),
    audioFileName: '$id.m4a',
    durationMs: 1000,
    status: IdeaStatus.toReview,
  );
}

Future<({MurmurShell shell, CaptureController capture})> _pumpShell(
  WidgetTester tester, {
  List<Idea> ideas = const <Idea>[],
  ValueNotifier<String?>? highlighted,
}) async {
  final audioDir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('murmur-shell-'),
  ))!;
  final service = RecordingService(
    repository: FakeIdeaRepository(),
    backend: FakeRecorderBackend(),
    audioDirectoryProvider: () async => audioDir,
  );
  final capture = CaptureController(service);
  // Le ticker de capture éventuel est annulé même si le test s'arrête
  // en plein enregistrement.
  addTearDown(capture.dispose);
  final shell = MurmurShell(
    controller: IdeasController(FakeIdeaRepository(ideas: ideas)),
    capture: capture,
    playback: PlaybackController(FakePlayerBackend()),
    reminders: FakeReminderService(),
    audioDir: audioDir,
    safetyDir: audioDir,
    appearance: AppearanceController(store: MemoryThemeModeStore()),
    locale: LocaleController(store: MemoryLocaleStore()),
    highlightedIdeaId: highlighted ?? ValueNotifier<String?>(null),
  );
  addTearDown(
    () => tester.runAsync(() async {
      if (await audioDir.exists()) await audioDir.delete(recursive: true);
    }),
  );
  await tester.pumpWidget(MaterialApp(home: shell));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return (shell: shell, capture: capture);
}

void main() {
  group('MurmurShell', () {
    testWidgets('barre persistante + onglet idées par défaut', (tester) async {
      await _pumpShell(tester, ideas: [_idea('a')]);

      expect(find.byType(MurmurNavBar), findsOneWidget);
      expect(find.byType(IdeasPage), findsOneWidget);
      expect(find.textContaining('Idée du'), findsOneWidget);
    });

    testWidgets('commutation découverte / paramètres, barre toujours là', (
      tester,
    ) async {
      await _pumpShell(tester, ideas: [_idea('a')]);

      await tester.tap(find.byIcon(LucideIcons.history));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RediscoverySessionPage), findsOneWidget);
      expect(find.byType(MurmurNavBar), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.settings));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(MurmurNavBar), findsOneWidget);
    });

    testWidgets('record ouvre la feuille de capture', (tester) async {
      final env = await _pumpShell(tester);

      await tester.tap(find.byIcon(LucideIcons.mic));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Enregistrement'), findsWidgets);

      // La feuille lance un enregistrement (ticker actif) : on l'annule
      // pour ne laisser aucun Timer actif en fin de test.
      await env.capture.discard();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('commutation : fondu puis ancien onglet masqué', (
      tester,
    ) async {
      await _pumpShell(tester, ideas: [_idea('a')]);

      await tester.tap(find.byIcon(LucideIcons.settings));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(IdeasPage), findsNothing);
    });

    testWidgets('badge : nombre d’idées à redécouvrir', (tester) async {
      await _pumpShell(tester, ideas: [_idea('a'), _idea('b')]);

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('deep-link : bascule sur l’onglet idées', (tester) async {
      final highlighted = ValueNotifier<String?>(null);
      addTearDown(highlighted.dispose);
      await _pumpShell(tester, ideas: [_idea('a')], highlighted: highlighted);

      await tester.tap(find.byIcon(LucideIcons.settings));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SettingsPage), findsOneWidget);

      highlighted.value = 'a';
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(IdeasPage), findsOneWidget);
      expect(find.textContaining('Idée du'), findsOneWidget);
    });
  });
}
