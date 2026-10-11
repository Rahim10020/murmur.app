import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Variantes visuelles du bouton Murmur (couleurs unies, aucun dégradé).
enum MurmurButtonVariant {
  /// Action principale : fond jaune, texte encre.
  primary,

  /// Action secondaire : fond encre (clair) ou gris adouci (sombre).
  secondary,

  /// Contour seul, fond transparent.
  outline,

  /// Texte seul, sans fond ni contour.
  text,
}

/// Valeurs par défaut centralisées : tout se règle ici ou par instance
/// ([height], [borderRadius], [fontSize], couleurs…).
class MurmurButtonDefaults {
  const MurmurButtonDefaults._();

  static const double height = 62;
  static const double borderRadius = 16;
  static const double fontSize = 16;
  static const double iconSize = 20;
  static const double outlineWidth = 1.5;
  static const double disabledOpacity = 0.45;
  static const FontWeight fontWeight = FontWeight.w500;
}

/// Bouton custom Murmur : une seule implémentation pour les 4 variantes.
///
/// - [label] texte affiché (Gotham Medium explicite) ;
/// - [icon] optionnelle (Lucide), placée avant le label ;
/// - [onPressed] à `null` = désactivé (opacité réduite, aucun effet) ;
/// - dimensionné par [height] (+ [padding] horizontal), shrink-wrap en
///   largeur sauf contrainte du parent (Expanded, stretch…) ;
/// - [backgroundColor]/[foregroundColor] permettent une exception locale,
///   en restant dans la palette (pas de gradient, jamais de jaune en texte).
class MurmurButton extends StatelessWidget {
  const MurmurButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MurmurButtonVariant.primary,
    this.icon,
    this.height = MurmurButtonDefaults.height,
    this.borderRadius = MurmurButtonDefaults.borderRadius,
    this.fontSize = MurmurButtonDefaults.fontSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final MurmurButtonVariant variant;
  final IconData? icon;
  final double height;
  final double borderRadius;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? foregroundColor;

  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    late final Color background;
    late final Color foreground;
    BorderSide border = BorderSide.none;
    switch (variant) {
      case MurmurButtonVariant.primary:
        background = backgroundColor ?? MurmurColors.primary;
        foreground = foregroundColor ?? MurmurColors.ink;
      case MurmurButtonVariant.secondary:
        final dark = Theme.of(context).brightness == Brightness.dark;
        background =
            backgroundColor ??
            (dark ? MurmurColors.secondaryDark : MurmurColors.ink);
        foreground = foregroundColor ?? MurmurColors.paper;
      case MurmurButtonVariant.outline:
        background = backgroundColor ?? Colors.transparent;
        foreground = foregroundColor ?? scheme.onSurface;
        border = BorderSide(
          color: foreground,
          width: MurmurButtonDefaults.outlineWidth,
        );
      case MurmurButtonVariant.text:
        background = backgroundColor ?? Colors.transparent;
        // Jaune interdit en texte : on utilise la couleur de texte du thème.
        foreground = foregroundColor ?? scheme.onSurface;
    }

    final content = Container(
      height: height,
      padding: padding,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MurmurButtonDefaults.iconSize, color: foreground),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MurmurTheme.fontFamily,
                fontWeight: MurmurButtonDefaults.fontWeight,
                fontSize: fontSize,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );

    final button = Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: radius, side: border),
      child: InkWell(borderRadius: radius, onTap: onPressed, child: content),
    );

    if (enabled) return button;
    return Opacity(
      opacity: MurmurButtonDefaults.disabledOpacity,
      child: button,
    );
  }
}
