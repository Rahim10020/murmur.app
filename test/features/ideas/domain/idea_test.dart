import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/domain/idea.dart';

Idea _sample({String id = 'id-1', String audioFileName = 'abc.m4a'}) {
  return Idea(
    id: id,
    createdAtUtc: DateTime.utc(2026, 10, 9, 12),
    updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
    audioFileName: audioFileName,
    durationMs: 42000,
    status: IdeaStatus.toReview,
  );
}

void main() {
  group('Idea', () {
    test('toMap/fromMap round-trip conserve tous les champs', () {
      final idea = Idea(
        id: '550e8400-e29b-41d4-a716-446655440000',
        createdAtUtc: DateTime.utc(2026, 10, 9, 8, 30),
        updatedAtUtc: DateTime.utc(2026, 10, 9, 9),
        audioFileName: '550e8400-e29b-41d4-a716-446655440000.m4a',
        durationMs: 61000,
        title: 'Titre libre',
        status: IdeaStatus.inProgress,
        reminderAtUtc: DateTime.utc(2026, 10, 10, 8),
        lastReviewedAtUtc: DateTime.utc(2026, 10, 9, 10),
      );

      final restored = Idea.fromMap(idea.toMap());

      expect(restored, equals(idea));
      expect(restored.createdAtUtc.isUtc, isTrue);
      expect(restored.reminderAtUtc?.isUtc, isTrue);
    });

    test('champs nullables absents restent null', () {
      final restored = Idea.fromMap(_sample().toMap());

      expect(restored.title, isNull);
      expect(restored.reminderAtUtc, isNull);
      expect(restored.lastReviewedAtUtc, isNull);
    });

    test('statuts inconnus rejetés', () {
      final map = _sample().toMap()..['status'] = 'unknown';

      expect(() => Idea.fromMap(map), throwsArgumentError);
    });

    test('horodatages non-UTC rejetés à la validation', () {
      final idea = Idea(
        id: 'id-1',
        createdAtUtc: DateTime(2026, 10, 9, 12),
        updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
        audioFileName: 'abc.m4a',
        durationMs: 1000,
        status: IdeaStatus.toReview,
      );

      expect(() => idea.validate(), throwsArgumentError);
    });

    test('noms de fichiers dangereux rejetés', () {
      for (final bad in <String>[
        '../evil.m4a',
        '/data/evil.m4a',
        r'..\evil.m4a',
        '.hidden.m4a',
        '',
        'a/b.m4a',
      ]) {
        expect(
          () => _sample(audioFileName: bad).validate(),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('durée négative rejetée', () {
      final idea = Idea(
        id: 'id-1',
        createdAtUtc: DateTime.utc(2026, 10, 9, 12),
        updatedAtUtc: DateTime.utc(2026, 10, 9, 12),
        audioFileName: 'abc.m4a',
        durationMs: -1,
        status: IdeaStatus.toReview,
      );

      expect(() => idea.validate(), throwsArgumentError);
    });

    test('ligne incomplète rejetée', () {
      expect(() => Idea.fromMap(<String, Object?>{}), throwsArgumentError);
    });
  });
}
