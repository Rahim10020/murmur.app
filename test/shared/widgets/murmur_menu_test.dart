import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:murmur/app/theme.dart';
import 'package:murmur/shared/widgets/murmur_menu.dart';

Future<void> _pumpTrigger(
  WidgetTester tester,
  void Function(BuildContext context) onTap,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MurmurTheme.light(),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => IconButton(
              icon: const Icon(LucideIcons.ellipsis),
              onPressed: () => onTap(context),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<MurmurMenuItem> _items({
  required void Function() onArchive,
  required void Function() onDelete,
}) {
  return [
    MurmurMenuItem(icon: LucideIcons.pencil, label: 'Renommer', onTap: () {}),
    MurmurMenuItem(
      icon: LucideIcons.hourglass,
      label: 'Commencer',
      onTap: () {},
    ),
    MurmurMenuItem(
      icon: LucideIcons.check,
      label: 'Marquer terminée',
      onTap: () {},
    ),
    MurmurMenuItem(
      icon: LucideIcons.archive,
      label: 'Archiver',
      onTap: onArchive,
    ),
    MurmurMenuItem(
      icon: LucideIcons.rotateCcw,
      label: 'Remettre à revoir',
      onTap: () {},
    ),
    MurmurMenuItem(
      icon: LucideIcons.trash,
      label: 'Supprimer',
      onTap: onDelete,
    ),
  ];
}

void main() {
  group('MurmurMenu', () {
    testWidgets('affiche les 6 actions avec icônes', (tester) async {
      await _pumpTrigger(
        tester,
        (context) => showMurmurMenu(
          anchorContext: context,
          items: _items(onArchive: () {}, onDelete: () {}),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();

      for (final label in [
        'Renommer',
        'Commencer',
        'Marquer terminée',
        'Archiver',
        'Remettre à revoir',
        'Supprimer',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tap action : callback + panneau fermé', (tester) async {
      var archived = 0;
      await _pumpTrigger(
        tester,
        (context) => showMurmurMenu(
          anchorContext: context,
          items: _items(onArchive: () => archived++, onDelete: () {}),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archiver'));
      await tester.pumpAndSettle();

      expect(archived, 1);
      expect(find.text('Archiver'), findsNothing);
    });

    testWidgets('tap hors panneau : fermé sans action', (tester) async {
      var deleted = 0;
      await _pumpTrigger(
        tester,
        (context) => showMurmurMenu(
          anchorContext: context,
          items: _items(onArchive: () {}, onDelete: () => deleted++),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(deleted, 0);
      expect(find.text('Supprimer'), findsNothing);
    });
  });
}
