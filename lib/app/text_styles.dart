import 'package:flutter/material.dart';

import 'theme.dart';

/// Styles de texte explicites (famille + graisse visibles dans le code).
///
/// Correspondance avec les polices embarquées (voir `pubspec.yaml`) :
/// - w400 → Gotham Regular (paragraphes) ;
/// - w500 → Gotham Medium (titres, labels) ;
/// - w700 → Gotham Bold.
class MurmurTextStyles {
  const MurmurTextStyles._();

  /// Paragraphes et messages courants : Gotham Regular explicite.
  static const TextStyle paragraph = TextStyle(
    fontFamily: MurmurTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.5,
  );

  /// Petits textes secondaires : Gotham Regular explicite.
  static const TextStyle caption = TextStyle(
    fontFamily: MurmurTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
  );

  /// Titres de section : Gotham Medium explicite.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: MurmurTheme.fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 18,
  );

  /// Labels de bouton : Gotham Medium explicite.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: MurmurTheme.fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );
}
