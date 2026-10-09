import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/theme.dart';
import 'package:murmur/shared/widgets/murmur_button.dart';

Future<void> _pumpButton(
  WidgetTester tester,
  MurmurButton button, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MurmurTheme.light(),
      darkTheme: MurmurTheme.dark(),
      themeMode: mode,
      home: Scaffold(body: Center(child: button)),
    ),
  );
  await tester.pump();
}

void main() {
  group('MurmurButton', () {
    testWidgets('affiche label + icône et déclenche onPressed', (tester) async {
      var tapped = 0;
      await _pumpButton(
        tester,
        MurmurButton(
          label: 'Enregistrer',
          icon: LucideIcons.mic,
          onPressed: () => tapped++,
        ),
      );

      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      expect(tapped, 1);
    });

    testWidgets('désactivé : aucun appel, opacité réduite', (tester) async {
      await _pumpButton(
        tester,
        const MurmurButton(label: 'Inactif', onPressed: null),
      );

      await tester.tap(find.text('Inactif'));
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        MurmurButtonDefaults.disabledOpacity,
      );
    });

    testWidgets('variante primary : fond jaune, texte encre', (tester) async {
      await _pumpButton(tester, MurmurButton(label: 'Go', onPressed: () {}));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MurmurButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, MurmurColors.primary);
      final text = tester.widget<Text>(find.text('Go'));
      expect(text.style?.color, MurmurColors.ink);
      expect(text.style?.fontFamily, MurmurTheme.fontFamily);
    });

    testWidgets('variante secondary : fond encre en clair', (tester) async {
      await _pumpButton(
        tester,
        MurmurButton(
          label: 'Second',
          variant: MurmurButtonVariant.secondary,
          onPressed: () {},
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MurmurButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, MurmurColors.ink);
    });

    testWidgets('hauteur et rayon personnalisés appliqués', (tester) async {
      await _pumpButton(
        tester,
        MurmurButton(label: 'Petit', height: 40, onPressed: () {}),
      );

      final size = tester.getSize(find.byType(MurmurButton));
      expect(size.height, 40);
    });
  });
}
