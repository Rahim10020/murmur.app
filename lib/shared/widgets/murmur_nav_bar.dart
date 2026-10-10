import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../app/theme.dart';

/// Valeurs par défaut centralisées de la barre de navigation.
class MurmurNavBarDefaults {
  const MurmurNavBarDefaults._();

  static const double height = 72;
  static const double borderRadius = 999;
  static const double horizontalMargin = 48;
  static const double bottomMargin = 16;
  static const double recordSize = 56;
  static const double iconSize = 24;
  static const double badgeFontSize = 11;
}

/// Barre de navigation flottante Murmur (pilule centrée).
///
/// 3 actions : Découverte (avec badge du nombre d'idées à redécouvrir,
/// masqué si 0), Enregistrer (cercle jaune primary, action principale),
/// Paramètres. Fond surface + ombre, aucun dégradé.
class MurmurNavBar extends StatelessWidget {
  const MurmurNavBar({
    super.key,
    required this.onDiscover,
    required this.onRecord,
    required this.onSettings,
    this.discoveryCount = 0,
  });

  final VoidCallback onDiscover;
  final VoidCallback onRecord;
  final VoidCallback onSettings;

  /// Nombre d'idées éligibles à la redécouverte (badge, masqué si 0).
  final int discoveryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: MurmurNavBarDefaults.height,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(MurmurNavBarDefaults.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavIcon(
            tooltip: 'Redécouvrir des idées',
            icon: LucideIcons.history,
            onTap: onDiscover,
            badgeCount: discoveryCount,
          ),
          _RecordButton(onTap: onRecord),
          _NavIcon(
            tooltip: 'Paramètres et sauvegarde',
            icon: LucideIcons.settings,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      iconSize: MurmurNavBarDefaults.iconSize,
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
        child: Icon(icon),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MurmurColors.primary,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: MurmurNavBarDefaults.recordSize,
          height: MurmurNavBarDefaults.recordSize,
          child: Tooltip(
            message: 'Enregistrer une idée',
            child: Icon(LucideIcons.mic, size: 26, color: MurmurColors.ink),
          ),
        ),
      ),
    );
  }
}
