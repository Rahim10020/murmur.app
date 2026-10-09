import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/reminders/domain/reminder_policy.dart';

void main() {
  group('ReminderPolicy', () {
    test('notificationIdFor est déterministe, positif, 31 bits', () {
      final a1 = ReminderPolicy.notificationIdFor('idea-1');
      final a2 = ReminderPolicy.notificationIdFor('idea-1');
      final b = ReminderPolicy.notificationIdFor('idea-2');

      expect(a1, equals(a2));
      expect(a1, isNot(equals(b)));
      expect(a1 >= 0 && a1 <= 0x7fffffff, isTrue);
      expect(b >= 0 && b <= 0x7fffffff, isTrue);
    });

    test('cancelsOnStatus : done et archived seulement', () {
      expect(ReminderPolicy.cancelsOnStatus(IdeaStatus.done), isTrue);
      expect(ReminderPolicy.cancelsOnStatus(IdeaStatus.archived), isTrue);
      expect(ReminderPolicy.cancelsOnStatus(IdeaStatus.toReview), isFalse);
      expect(ReminderPolicy.cancelsOnStatus(IdeaStatus.inProgress), isFalse);
    });

    test('isActiveReminder : strictement futur, UTC exigé', () {
      final now = DateTime.utc(2026, 10, 9, 12);
      expect(
        ReminderPolicy.isActiveReminder(DateTime.utc(2026, 10, 9, 13), now),
        isTrue,
      );
      expect(
        ReminderPolicy.isActiveReminder(DateTime.utc(2026, 10, 9, 12), now),
        isFalse,
      );
      expect(
        ReminderPolicy.isActiveReminder(DateTime.utc(2026, 10, 9, 11), now),
        isFalse,
      );
      expect(ReminderPolicy.isActiveReminder(null, now), isFalse);
      expect(
        () => ReminderPolicy.isActiveReminder(DateTime(2026, 10, 10), now),
        throwsArgumentError,
      );
    });

    test('laterToday : 20h si futur, sinon null', () {
      expect(
        ReminderPolicy.laterToday(DateTime(2026, 10, 9, 18)),
        DateTime(2026, 10, 9, 20),
      );
      expect(ReminderPolicy.laterToday(DateTime(2026, 10, 9, 21)), isNull);
    });

    test('tomorrow : lendemain 9h', () {
      expect(
        ReminderPolicy.tomorrow(DateTime(2026, 10, 9, 22)),
        DateTime(2026, 10, 10, 9),
      );
    });

    test('nextWeek : +7 jours, même heure', () {
      expect(
        ReminderPolicy.nextWeek(DateTime(2026, 10, 9, 15, 30)),
        DateTime(2026, 10, 16, 15),
      );
    });

    test('validateFuture refuse passé et présent', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(
        () => ReminderPolicy.validateFuture(DateTime(2026, 10, 9, 11), now),
        throwsArgumentError,
      );
      expect(
        () => ReminderPolicy.validateFuture(now, now),
        throwsArgumentError,
      );
      ReminderPolicy.validateFuture(DateTime(2026, 10, 9, 12, 2), now);
    });

    test('texte de notification discret (aucun contenu idée)', () {
      expect(ReminderPolicy.notificationTitle, 'Une idée à revoir');
      expect(ReminderPolicy.notificationBody, contains('idée enregistrée'));
    });
  });

  group('ReminderReconciliation', () {
    test('annule orphelins, planifie manquants, garde communs', () {
      final plan = ReminderReconciliation.plan(
        pendingIds: {1, 2, 3},
        futureByIdea: {'a': 2, 'b': 4},
      );
      expect(plan.toCancel, {1, 3});
      expect(plan.toSchedule, {4});
    });

    test('aucun voulu : tout est annulé', () {
      final plan = ReminderReconciliation.plan(
        pendingIds: {1},
        futureByIdea: {},
      );
      expect(plan.toCancel, {1});
      expect(plan.toSchedule, isEmpty);
    });

    test('aucun planifié : tout est planifié', () {
      final plan = ReminderReconciliation.plan(
        pendingIds: {},
        futureByIdea: {'a': 9},
      );
      expect(plan.toCancel, isEmpty);
      expect(plan.toSchedule, {9});
    });
  });
}
