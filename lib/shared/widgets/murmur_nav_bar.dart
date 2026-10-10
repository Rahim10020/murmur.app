import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../app/theme.dart';

/// Valeurs par défaut centralisées de la navigation.
class MurmurNavBarDefaults {
  const MurmurNavBarDefaults._();

  static const double height = 82;
  static const double borderRadius = 999;
  static const double maxWidth = 240;
  static const double horizontalMargin = 24;
  static const double bottomMargin = 16;
  static const double recordSize = 70;
  static const double recordRadius = 20;
  static const double recordGap = 8;
  static const double iconSize = 32;
  static const double itemGap = 24;
  static const double badgeFontSize = 11;
}

/// Onglets de la barre : accueil, découverte, paramètres.
enum MurmurNavTab { home, discovery, settings }

/// Barre de navigation flottante Murmur (pilule compacte centrée).
///
/// 3 onglets : l'actif est marqué d'un cercle plein (encre en clair,
/// blanc en sombre). Le record est un bouton détaché séparé
/// ([MurmurRecordButton]). Fond surface + ombre, aucun dégradé.
class MurmurNavBar extends StatelessWidget {
  const MurmurNavBar({
    super.key,
    required this.selectedIndex,
    required this.onHome,
    required this.onDiscover,
    required this.onSettings,
    this.discoveryCount = 0,
  });

  /// Index de l'onglet actif (0 = accueil, 1 = découverte, 2 = paramètres).
  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onDiscover;
  final VoidCallback onSettings;

  /// Nombre d'idées éligibles à la redécouverte (badge, masqué si 0).
  final int discoveryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Hauteur stricte : en contraintes lâches, un expansible occuperait
    // tout l'espace restant et écraserait le body du Scaffold à 0.
    return SizedBox(
      height: MurmurNavBarDefaults.height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MurmurNavBarDefaults.maxWidth,
          ),
          child: Container(
            height: MurmurNavBarDefaults.height,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(
                MurmurNavBarDefaults.borderRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavIcon(
                  tooltip: 'Accueil',
                  icon: LucideIcons.house,
                  selected: selectedIndex == 0,
                  onTap: onHome,
                ),
                const SizedBox(width: MurmurNavBarDefaults.itemGap),
                _NavIcon(
                  tooltip: 'Redécouvrir des idées',
                  icon: LucideIcons.history,
                  selected: selectedIndex == 1,
                  onTap: onDiscover,
                  badgeCount: discoveryCount,
                ),
                const SizedBox(width: MurmurNavBarDefaults.itemGap),
                _NavIcon(
                  tooltip: 'Paramètres et sauvegarde',
                  icon: LucideIcons.settings,
                  selected: selectedIndex == 2,
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    // Cercle plein derrière l'onglet actif (référence visuelle).
    final selectedBackground = dark ? MurmurColors.paper : MurmurColors.ink;
    final selectedForeground = dark ? MurmurColors.ink : MurmurColors.paper;
    final shownIcon = Icon(
      icon,
      size: MurmurNavBarDefaults.iconSize,
      color: selected ? selectedForeground : foreground,
    );
    final button = IconButton(
      tooltip: tooltip,
      iconSize: MurmurNavBarDefaults.iconSize,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: foreground,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text(
          badgeCount > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(
            fontFamily: MurmurTheme.fontFamily,
            fontSize: MurmurNavBarDefaults.badgeFontSize,
          ),
        ),
        backgroundColor: MurmurColors.ink,
        textColor: MurmurColors.paper,
        child: selected
            ? CircleAvatar(
                backgroundColor: selectedBackground,
                radius: 26,
                child: shownIcon,
              )
            : shownIcon,
      ),
    );
    return button;
  }
}

/// Bouton record détaché : carré arrondi jaune, micro encre.
///
/// Placé à droite de la pilule (comme la référence), mêmes hauteur et
/// ombre. Tailles réglables dans [MurmurNavBarDefaults].
class MurmurRecordButton extends StatelessWidget {
  const MurmurRecordButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MurmurNavBarDefaults.recordRadius);
    return Material(
      color: MurmurColors.primary,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: const SizedBox(
          width: MurmurNavBarDefaults.recordSize,
          height: MurmurNavBarDefaults.recordSize,
          child: Tooltip(
            message: 'Enregistrer une idée',
            child: Icon(LucideIcons.mic, size: 32, color: MurmurColors.ink),
          ),
        ),
      ),
    );
  }
}
