import 'package:flutter/widgets.dart';

/// Mouvements Murmur : point de réglage unique (tons calmes, subtils).
///
/// - [tabSwitch] : fondu (+ léger scale) entre onglets ;
/// - [selection] : fondu du cercle d'onglet actif ;
/// - [press] : écrasement à l'appui (bouton record).
/// Le tout en [easeOut]. Tout passe à zéro si l'utilisateur a activé
/// « réduire les animations » ([disableAnimations]).
class MurmurMotion {
  const MurmurMotion._();

  static const Duration tabSwitch = Duration(milliseconds: 300);
  static const Duration selection = Duration(milliseconds: 180);
  static const Duration press = Duration(milliseconds: 120);

  static const Curve curve = Curves.easeOut;
  static const double tabStartScale = 0.98;
  static const double pressScale = 0.93;

  static Duration scaled(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
