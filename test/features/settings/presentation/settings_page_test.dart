import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/reminders/data/flutter_reminder_service.dart';
import 'package:murmur/app/appearance.dart';
import 'package:murmur/features/settings/presentation/settings_page.dart';
import 'package:murmur/l10n/app_locale.dart';
import 'package:murmur/l10n/locale_controller.dart';

class FakeIdeaRepository implements IdeaRepository {
  @override
  Future<void> close() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<Idea?> findById(String id) async => null;

  @override
  Future<void> insert(Idea idea) async {}

  @override
  Future<List<Idea>> listNewestFirst({int? limit}) async => <Idea>[];

  @override
  Future<void> replaceAll(List<Idea> ideas) async {}

  @override
  Future<void> update(Idea idea) async {}
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

void main() {
  group('SettingsPage', () {
    testWidgets('affiche export + restauration + mention locale', (
      tester,
    ) async {
      final controller = IdeasController(FakeIdeaRepository());
      final appearance = AppearanceController(store: MemoryThemeModeStore());
      final locale = LocaleController(store: MemoryLocaleStore());
      addTearDown(() {
        controller.dispose();
        appearance.dispose();
        locale.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            controller: controller,
            reminders: FakeReminderService(),
            audioDir: Directory('/tmp/murmur-audio-test'),
            safetyDir: Directory('/tmp/murmur-safety-test'),
            appearance: appearance,
            locale: locale,
            onRestored: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sauvegarde locale'), findsOneWidget);
      expect(find.text('Exporter une sauvegarde'), findsOneWidget);
      expect(find.text('Restaurer une sauvegarde'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
      expect(find.byIcon(LucideIcons.upload), findsOneWidget);
      expect(find.textContaining('ne la téléverse nulle part'), findsOneWidget);
    });

    testWidgets('section apparence : trio Système/Clair/Sombre', (
      tester,
    ) async {
      final controller = IdeasController(FakeIdeaRepository());
      final appearance = AppearanceController(store: MemoryThemeModeStore());
      final locale = LocaleController(store: MemoryLocaleStore());
      addTearDown(() {
        controller.dispose();
        appearance.dispose();
        locale.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            controller: controller,
            reminders: FakeReminderService(),
            audioDir: Directory('/tmp/murmur-audio-test'),
            safetyDir: Directory('/tmp/murmur-safety-test'),
            appearance: appearance,
            locale: locale,
            onRestored: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Apparence'), findsOneWidget);
      // 'Système' apparaît deux fois : thème système + langue système.
      expect(find.text('Système'), findsNWidgets(2));
      expect(find.text('Clair'), findsOneWidget);
      expect(find.text('Sombre'), findsOneWidget);

      await tester.tap(find.text('Sombre'));
      await tester.pump();
      expect(appearance.mode, ThemeMode.dark);
    });

    testWidgets('section langue : Système/Français/Anglais', (
      tester,
    ) async {
      final controller = IdeasController(FakeIdeaRepository());
      final appearance = AppearanceController(store: MemoryThemeModeStore());
      final store = MemoryLocaleStore();
      final locale = LocaleController(store: store);
      addTearDown(() {
        controller.dispose();
        appearance.dispose();
        locale.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            controller: controller,
            reminders: FakeReminderService(),
            audioDir: Directory('/tmp/murmur-audio-test'),
            safetyDir: Directory('/tmp/murmur-safety-test'),
            appearance: appearance,
            locale: locale,
            onRestored: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('Anglais'), findsOneWidget);

      await tester.tap(find.text('Anglais'));
      await tester.pump();
      expect(locale.locale, AppLocale.english);

      await tester.tap(find.text('Français'));
      await tester.pump();
      expect(locale.locale, AppLocale.french);
    });
  });
}
