import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/theme.dart';
import 'package:murmur/shared/widgets/murmur_nav_bar.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required VoidCallback onDiscover,
  required VoidCallback onRecord,
  required VoidCallback onSettings,
  int discoveryCount = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MurmurTheme.light(),
      home: Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: MurmurNavBar(
          onDiscover: onDiscover,
          onRecord: onRecord,
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
    testWidgets('affiche les 3 actions avec icônes Lucide', (tester) async {
      await _pumpBar(
        tester,
        onDiscover: () {},
        onRecord: () {},
        onSettings: () {},
      );

      expect(find.byIcon(LucideIcons.history), findsOneWidget);
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      expect(find.byIcon(LucideIcons.settings), findsOneWidget);
    });

    testWidgets('chaque action déclenche son callback', (tester) async {
      var discovered = 0;
      var recorded = 0;
      var openedSettings = 0;
      await _pumpBar(
        tester,
        onDiscover: () => discovered++,
        onRecord: () => recorded++,
        onSettings: () => openedSettings++,
      );

      await tester.tap(find.byIcon(LucideIcons.history));
      await tester.tap(find.byIcon(LucideIcons.mic));
      await tester.tap(find.byIcon(LucideIcons.settings));
      await tester.pump();

      expect(discovered, 1);
      expect(recorded, 1);
      expect(openedSettings, 1);
    });

    testWidgets('badge masqué si 0, affiché sinon', (tester) async {
      await _pumpBar(
        tester,
        onDiscover: () {},
        onRecord: () {},
        onSettings: () {},
        discoveryCount: 0,
      );
      expect(find.text('0'), findsNothing);

      await _pumpBar(
        tester,
        onDiscover: () {},
        onRecord: () {},
        onSettings: () {},
        discoveryCount: 3,
      );
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('bouton record : cercle jaune, micro encre', (tester) async {
      await _pumpBar(
        tester,
        onDiscover: () {},
        onRecord: () {},
        onSettings: () {},
      );

      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(MurmurNavBar),
          matching: find.byType(Material),
        ),
      );
      expect(materials.any((m) => m.color == MurmurColors.primary), isTrue);
      final mic = tester.widget<Icon>(find.byIcon(LucideIcons.mic));
      expect(mic.color, MurmurColors.ink);
    });

    testWidgets('pilule compacte : largeur plafonnée', (tester) async {
      await _pumpBar(
        tester,
        onDiscover: () {},
        onRecord: () {},
        onSettings: () {},
      );

      final pill = find.descendant(
        of: find.byType(MurmurNavBar),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );
      expect(pill, findsOneWidget);
      expect(
        tester.getSize(pill).width,
        lessThanOrEqualTo(MurmurNavBarDefaults.maxWidth),
      );
    });
  });
}
