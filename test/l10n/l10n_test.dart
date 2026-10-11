import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/l10n/app_locale.dart';
import 'package:murmur/l10n/app_strings.dart';
import 'package:murmur/l10n/locale_controller.dart';

void main() {
  group('resolveIsFrench', () {
    test('choix explicite gagne sur le système', () {
      expect(resolveIsFrench(AppLocale.french, 'en_US'), isTrue);
      expect(resolveIsFrench(AppLocale.english, 'fr_FR'), isFalse);
    });

    test('système : fr/en détectés, fallback français', () {
      expect(resolveIsFrench(AppLocale.system, 'fr_FR'), isTrue);
      expect(resolveIsFrench(AppLocale.system, 'fr-CA'), isTrue);
      expect(resolveIsFrench(AppLocale.system, 'en_US'), isFalse);
      expect(resolveIsFrench(AppLocale.system, 'en-GB'), isFalse);
      expect(resolveIsFrench(AppLocale.system, 'es_ES'), isTrue);
      expect(resolveIsFrench(AppLocale.system, ''), isTrue);
    });
  });

  group('LocaleController', () {
    test('défaut système puis persistance', () async {
      final store = MemoryLocaleStore();
      final controller = LocaleController(store: store);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.locale, AppLocale.system);
      expect(controller.stringsFor('fr_FR'), isA<FrStrings>());
      expect(controller.stringsFor('en_US'), isA<EnStrings>());
      // Fallback français pour les autres langues système.
      expect(controller.stringsFor('es_ES'), isA<FrStrings>());

      await controller.setLocale(AppLocale.english);
      expect(controller.locale, AppLocale.english);
      expect(store.value, 'english');
      expect(controller.stringsFor('fr_FR'), isA<EnStrings>());
    });

    test('valeur stockée inconnue → système', () async {
      final controller = LocaleController(
        store: MemoryLocaleStore('klingon'),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.locale, AppLocale.system);
    });
  });

  group('AppStrings', () {
    test('aucune clé vide en FR ni EN', () {
      for (final s in const <AppStrings>[FrStrings(), EnStrings()]) {
        expect(s.appTitle, isNotEmpty);
        expect(s.navHome, isNotEmpty);
        expect(s.navDiscover, isNotEmpty);
        expect(s.navSettings, isNotEmpty);
        expect(s.recordIdea, isNotEmpty);
        expect(s.onboardSkip, isNotEmpty);
        expect(s.onboardBack, isNotEmpty);
        expect(s.onboardContinue, isNotEmpty);
        expect(s.onboardStart, isNotEmpty);
        expect(s.onboardTitle1, isNotEmpty);
        expect(s.onboardBody1, isNotEmpty);
        expect(s.onboardTitle2, isNotEmpty);
        expect(s.onboardBody2, isNotEmpty);
        expect(s.onboardTitle3, isNotEmpty);
        expect(s.onboardBody3, isNotEmpty);
        expect(s.ideasEmpty, isNotEmpty);
        expect(s.retry, isNotEmpty);
        expect(s.renameTitle, isNotEmpty);
        expect(s.renameHint, isNotEmpty);
        expect(s.cancel, isNotEmpty);
        expect(s.save, isNotEmpty);
        expect(s.deleteIdeaTitle, isNotEmpty);
        expect(s.deleteIdeaBody, isNotEmpty);
        expect(s.keep, isNotEmpty);
        expect(s.delete, isNotEmpty);
        expect(s.play, isNotEmpty);
        expect(s.pause, isNotEmpty);
        expect(s.addReminder, isNotEmpty);
        expect(s.editReminder, isNotEmpty);
        expect(s.actions, isNotEmpty);
        expect(s.captureRecording, isNotEmpty);
        expect(s.captureSaving, isNotEmpty);
        expect(s.captureMicDenied, isNotEmpty);
        expect(s.captureError, isNotEmpty);
        expect(s.captureIdle, isNotEmpty);
        expect(s.stopAndKeep, isNotEmpty);
        expect(s.abandon, isNotEmpty);
        expect(s.close, isNotEmpty);
        expect(s.abandonRecordTitle, isNotEmpty);
        expect(s.abandonRecordBody, isNotEmpty);
        expect(s.micSettingsHint, isNotEmpty);
        expect(s.remindMe, isNotEmpty);
        expect(s.noReminder, isNotEmpty);
        expect(s.notifDeniedBody, isNotEmpty);
        expect(s.laterToday, isNotEmpty);
        expect(s.tomorrow, isNotEmpty);
        expect(s.nextWeek, isNotEmpty);
        expect(s.pickDate, isNotEmpty);
        expect(s.cancelReminder, isNotEmpty);
        expect(s.notificationTitle, isNotEmpty);
        expect(s.notificationBody, isNotEmpty);
        expect(s.channelName, isNotEmpty);
        expect(s.channelDescription, isNotEmpty);
        expect(s.rediscoveryTitle, isNotEmpty);
        expect(s.rediscoveryEmpty, isNotEmpty);
        expect(s.settingsTitle, isNotEmpty);
        expect(s.appearanceSection, isNotEmpty);
        expect(s.languageSection, isNotEmpty);
        expect(s.langSystem, isNotEmpty);
        expect(s.langFrench, isNotEmpty);
        expect(s.langEnglish, isNotEmpty);
        expect(s.backupSection, isNotEmpty);
        expect(s.backupDescription, isNotEmpty);
        expect(s.exportBackup, isNotEmpty);
        expect(s.restoreBackup, isNotEmpty);
        for (final status in IdeaStatus.values) {
          expect(s.statusLabel(status), isNotEmpty);
        }
        for (var month = 1; month <= 12; month++) {
          expect(s.monthName(month), isNotEmpty);
        }
      }
    });

    test('les deux langues divergent sur les clés principales', () {
      const fr = FrStrings();
      const en = EnStrings();
      expect(fr.settingsTitle, isNot(en.settingsTitle));
      expect(fr.exportBackup, isNot(en.exportBackup));
      expect(fr.onboardStart, isNot(en.onboardStart));
      expect(fr.statusLabel(IdeaStatus.done), isNot(en.statusLabel(IdeaStatus.done)));
      expect(fr.monthName(1), isNot(en.monthName(1)));
      expect(fr.formatReminder(5, 6, 9, 7), isNot(en.formatReminder(5, 6, 9, 7)));
      expect(fr.formatBytes(2048), contains('Ko'));
      expect(en.formatBytes(2048), contains('KB'));
    });
  });
}
