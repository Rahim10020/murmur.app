import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/theme.dart';
import 'package:murmur/features/onboarding/presentation/onboarding_page.dart';

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required VoidCallback onDone,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MurmurTheme.light(),
      home: OnboardingPage(onDone: onDone),
    ),
  );
  await tester.pump();
}

void main() {
  group('OnboardingPage', () {
    testWidgets('3 écrans : titres, pastilles, navigation', (tester) async {
      var done = 0;
      await _pumpOnboarding(tester, onDone: () => done++);

      // Écran 1 : pas de Retour, Continuer + Passer présents.
      expect(find.text('Une idée ? Murmurez-la.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.micVocal), findsOneWidget);
      expect(find.text('Retour'), findsNothing);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Vos mots restent à vous.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.text('Retour'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('On vous la rappelle.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bellRing), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
      expect(done, 0);
    });

    testWidgets('Retour revient à l’écran précédent', (tester) async {
      await _pumpOnboarding(tester, onDone: () {});

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      expect(find.text('Une idée ? Murmurez-la.'), findsOneWidget);
    });

    testWidgets('Passer termine sans bloquer', (tester) async {
      var done = 0;
      await _pumpOnboarding(tester, onDone: () => done++);

      await tester.tap(find.text('Passer'));
      await tester.pump();

      expect(done, 1);
    });

    testWidgets('Commencer termine le parcours', (tester) async {
      var done = 0;
      await _pumpOnboarding(tester, onDone: () => done++);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer'));
      await tester.pump();

      expect(done, 1);
    });
  });
}
