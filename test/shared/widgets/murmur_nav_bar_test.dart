import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/theme.dart';
import 'package:murmur/shared/widgets/murmur_nav_bar.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  int selectedIndex = 0,
  required VoidCallback onHome,
  required VoidCallback onDiscover,
  required VoidCallback onSettings,
  int discoveryCount = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MurmurTheme.light(),
      home: Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: MurmurNavBar(
          selectedIndex: selectedIndex,
          onHome: onHome,
          onDiscover: onDiscover,
          onSettings: onSettings,
          discoveryCount: discoveryCount,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('MurmurNavBar', () {
    testWidgets('pilule : accueil, découverte, paramètres (Lucide)', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        onHome: () {},
        onDiscover: () {},
        onSettings: () {},
      );

      expect(find.byIcon(LucideIcons.house), findsOneWidget);
      expect(find.byIcon(LucideIcons.history), findsOneWidget);
      expect(find.byIcon(LucideIcons.settings), findsOneWidget);
      // Le record est détaché, hors pilule.
      expect(find.byIcon(LucideIcons.mic), findsNothing);
    });

    testWidgets('chaque onglet déclenche son callback', (tester) async {
      var home = 0;
      var discovered = 0;
      var openedSettings = 0;
      await _pumpBar(
        tester,
        onHome: () => home++,
        onDiscover: () => discovered++,
        onSettings: () => openedSettings++,
      );

      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.tap(find.byIcon(LucideIcons.history));
      await tester.tap(find.byIcon(LucideIcons.settings));
      await tester.pump();

      expect(home, 1);
      expect(discovered, 1);
      expect(openedSettings, 1);
    });

    testWidgets('onglet actif : cercle en fondu (encre en clair)', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        selectedIndex: 1,
        onHome: () {},
        onDiscover: () {},
        onSettings: () {},
      );

      final circles = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(MurmurNavBar),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final filled = circles.where((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == MurmurColors.ink;
      });
      expect(filled, hasLength(1));
    });

    testWidgets('badge masqué si 0, affiché sinon', (tester) async {
      await _pumpBar(
        tester,
        onHome: () {},
        onDiscover: () {},
        onSettings: () {},
        discoveryCount: 0,
      );
      expect(find.text('0'), findsNothing);

      await _pumpBar(
        tester,
        onHome: () {},
        onDiscover: () {},
        onSettings: () {},
        discoveryCount: 3,
      );
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('pilule compacte : largeur plafonnée', (tester) async {
      await _pumpBar(
        tester,
        onHome: () {},
        onDiscover: () {},
        onSettings: () {},
      );

      final pill = find.descendant(
        of: find.byType(MurmurNavBar),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(MurmurNavBarDefaults.borderRadius),
        ),
      );
      expect(pill, findsOneWidget);
      expect(
        tester.getSize(pill).width,
        lessThanOrEqualTo(MurmurNavBarDefaults.maxWidth),
      );
    });
  });

  group('MurmurRecordButton', () {
    testWidgets('carré jaune, micro encre, callback', (tester) async {
      var recorded = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: MurmurTheme.light(),
          home: Scaffold(
            body: Center(child: MurmurRecordButton(onTap: () => recorded++)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      final mic = tester.widget<Icon>(find.byIcon(LucideIcons.mic));
      expect(mic.color, MurmurColors.ink);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MurmurRecordButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, MurmurColors.primary);
      final shape = material.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(MurmurNavBarDefaults.recordRadius),
      );

      await tester.tap(find.byIcon(LucideIcons.mic));
      expect(recorded, 1);
    });

    testWidgets('record : écrasement à l’appui', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MurmurTheme.light(),
          home: Scaffold(
            body: Center(child: MurmurRecordButton(onTap: () {})),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(MurmurRecordButton),
          matching: find.byType(AnimatedScale),
        ),
        findsOneWidget,
      );
    });
  });
}
