import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Item du panneau flottant Murmur : icône Lucide + label Gotham Medium.
class MurmurMenuItem {
  const MurmurMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Valeurs par défaut centralisées du panneau.
class MurmurMenuDefaults {
  const MurmurMenuDefaults._();

  static const double width = 248;
  static const double itemHeight = 52;
  static const double borderRadius = 16;
  static const double fontSize = 15;
  static const double iconSize = 20;
  static const double gapBelowAnchor = 4;
  static const double screenMargin = 8;
}

/// Affiche un panneau flottant custom ancré sous [anchorContext].
///
/// Remplace le `PopupMenuButton` Material : fond surface du thème
/// (blanc en clair, encre en sombre) + ombre portée, rayon 16,
/// fermeture au tap extérieur. Le dernier item (ex. « Supprimer ») est
/// simplement séparé par un diviseur, sans couleur de signalisation.
Future<void> showMurmurMenu({
  required BuildContext anchorContext,
  required List<MurmurMenuItem> items,
}) {
  assert(items.isNotEmpty, 'Le panneau doit contenir au moins un item.');
  final overlay = Overlay.of(anchorContext);
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
    return Future.value();
  }
  final anchorTopLeft = anchorBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final anchorBottomRight = anchorBox.localToGlobal(
    anchorBox.size.bottomRight(Offset.zero),
    ancestor: overlayBox,
  );
  final position = RelativeRect.fromRect(
    Rect.fromPoints(anchorTopLeft, anchorBottomRight),
    Offset.zero & overlayBox.size,
  );
  return Navigator.of(
    anchorContext,
  ).push(_MurmurMenuRoute(position: position, items: items));
}

class _MurmurMenuRoute extends PopupRoute<void> {
  _MurmurMenuRoute({required this.position, required this.items});

  final RelativeRect position;
  final List<MurmurMenuItem> items;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.25);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fermer';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _MurmurMenuLayoutDelegate(position),
      child: _MurmurMenuPanel(items: items),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
        alignment: Alignment.topRight,
        child: child,
      ),
    );
  }
}

/// Positionne le panneau sous l'ancre, aligné à droite, sans déborder.
class _MurmurMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _MurmurMenuLayoutDelegate(this.position);

  final RelativeRect position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        MurmurMenuDefaults.width,
        constraints.maxHeight - MurmurMenuDefaults.screenMargin * 2,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = Rect.fromLTRB(
      position.left,
      position.top,
      size.width - position.right,
      size.height - position.bottom,
    );
    var x = anchor.right - childSize.width;
    x = x.clamp(
      MurmurMenuDefaults.screenMargin,
      (size.width - childSize.width - MurmurMenuDefaults.screenMargin).clamp(
        MurmurMenuDefaults.screenMargin,
        size.width,
      ),
    );
    var y = anchor.bottom + MurmurMenuDefaults.gapBelowAnchor;
    if (y + childSize.height > size.height - MurmurMenuDefaults.screenMargin) {
      y = (anchor.top - childSize.height - MurmurMenuDefaults.gapBelowAnchor)
          .clamp(MurmurMenuDefaults.screenMargin, size.height);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MurmurMenuLayoutDelegate oldDelegate) {
    return position != oldDelegate.position;
  }
}

class _MurmurMenuPanel extends StatelessWidget {
  const _MurmurMenuPanel({required this.items});

  final List<MurmurMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;
    final foreground = scheme.onSurface;
    final radius = BorderRadius.circular(MurmurMenuDefaults.borderRadius);
    return Material(
      color: surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MurmurMenuDefaults.width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: foreground.withValues(alpha: 0.12),
                ),
              _MurmurMenuRow(item: items[i], foreground: foreground),
            ],
          ],
        ),
      ),
    );
  }
}

class _MurmurMenuRow extends StatelessWidget {
  const _MurmurMenuRow({required this.item, required this.foreground});

  final MurmurMenuItem item;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MurmurMenuDefaults.borderRadius),
      onTap: () {
        Navigator.of(context).pop();
        item.onTap();
      },
      child: Container(
        height: MurmurMenuDefaults.itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              item.icon,
              size: MurmurMenuDefaults.iconSize,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: MurmurTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                  fontSize: MurmurMenuDefaults.fontSize,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
