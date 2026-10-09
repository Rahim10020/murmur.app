import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/ideas/domain/idea.dart';
import 'package:murmur/features/ideas/domain/idea_repository.dart';
import 'package:murmur/features/ideas/presentation/ideas_controller.dart';
import 'package:murmur/features/ideas/presentation/ideas_page.dart';

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

Future<void> _pumpPage(WidgetTester tester, IdeasController controller) async {
  await tester.pumpWidget(MaterialApp(home: IdeasPage(controller: controller)));
  await tester.pumpAndSettle();
}

void main() {
  group('IdeasPage', () {
    testWidgets('état vide explicite en français', (tester) async {
      final controller = IdeasController(FakeIdeaRepository());
      addTearDown(controller.dispose);

      await _pumpPage(tester, controller);

      expect(find.textContaining('Aucune idée'), findsOneWidget);
    });

    testWidgets('liste les idées avec titre de repli', (tester) async {
      final controller = IdeasController(
        FakeIdeaRepository(ideas: [_idea('a'), _idea('b')]),
      );
      addTearDown(controller.dispose);

      await _pumpPage(tester, controller);

      // Titres de repli localisés (jour/mois/année du 9/10/2026).
      expect(find.textContaining('Idée du'), findsNWidgets(2));
    });

    testWidgets('erreur de chargement affichée sans crash', (tester) async {
      final controller = IdeasController(FakeIdeaRepository(shouldFail: true));
      addTearDown(controller.dispose);

      await _pumpPage(tester, controller);

      expect(find.textContaining('Impossible de charger'), findsOneWidget);
    });
  });
}
