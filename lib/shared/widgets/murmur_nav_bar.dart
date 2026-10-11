import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../l10n/strings_scope.dart';

/// Valeurs par défaut centralisées de la navigation.
class MurmurNavBarDefaults {
  const MurmurNavBarDefaults._();

  static const double height = 68;
  static const double borderRadius = 999;
  static const double maxWidth = 238;
  static const double horizontalMargin = 24;
  static const double bottomMargin = 16;
  static const double recordSize = 70;
  static const double recordRadius = 20;
  static const double recordGap = 12;
  static const double iconSize = 32;
  static const double itemGap = 16;
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
    final strings = StringsScope.of(context);
    // Hauteur stricte : en contraintes lâches, un expansible occuperait
    // tout l'espace restant et écraserait le body du Scaffold à 0.
    return SizedBox(
      height: MurmurNavBarDefaults.height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MurmurNavBarDefaults.maxWidth,
          ),
          child: SizedBox(
            height: MurmurNavBarDefaults.height,

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavIcon(
                  tooltip: strings.navHome,
                  icon: LucideIcons.audioLines,
                  selected: selectedIndex == 0,
                  onTap: onHome,
                ),
                const SizedBox(width: MurmurNavBarDefaults.itemGap),
                _NavIcon(
                  tooltip: strings.navDiscover,
                  icon: LucideIcons.history,
                  selected: selectedIndex == 1,
                  onTap: onDiscover,
                  badgeCount: discoveryCount,
                ),
                const SizedBox(width: MurmurNavBarDefaults.itemGap),
                _NavIcon(
                  tooltip: strings.navSettings,
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
    // Cercle plein derrière l'onglet actif, en fondu (pas d'apparition
    // sèche). La couleur d'icône commute sous le fondu.
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
        child: AnimatedContainer(
          duration: MurmurMotion.selection,
          curve: MurmurMotion.curve,
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? selectedBackground : Colors.transparent,
          ),
          child: shownIcon,
        ),
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
    final strings = StringsScope.of(context);
    final radius = BorderRadius.circular(MurmurNavBarDefaults.recordRadius);
    return _PressScale(
      child: Material(
        color: MurmurColors.primary,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: MurmurNavBarDefaults.recordSize,
            height: MurmurNavBarDefaults.recordSize,
            child: Tooltip(
              message: strings.recordIdea,
              child: const Icon(LucideIcons.mic, size: 32, color: MurmurColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écrasement à l'appui (120 ms, [MurmurMotion.press]).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? MurmurMotion.pressScale : 1,
        duration: MurmurMotion.press,
        curve: MurmurMotion.curve,
        child: widget.child,
      ),
    );
  }
}
