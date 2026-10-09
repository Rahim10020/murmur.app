import '../../ideas/domain/idea.dart';

/// Politique de redécouverte hebdo (brief §3) — logique pure et déterministe.
///
/// Éligible : ni terminée ni archivée, sans rappel futur actif, et non
/// revue récemment. Sélection : plus anciennes éligibles d'abord, au plus
/// [sessionLimit] par session. Aucune recommandation, aucune IA.
class RediscoveryPolicy {
  const RediscoveryPolicy._();

  /// Nombre maximal d'idées par session.
  static const int sessionLimit = 3;

  /// Délai après lequel une idée revue redevient éligible.
  static const Duration reviewCooldown = Duration(days: 7);

  static bool isEligible(
    Idea idea,
    DateTime nowUtc, {
    Duration cooldown = reviewCooldown,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError('La comparaison se fait en UTC.');
    }
    if (idea.status == IdeaStatus.done || idea.status == IdeaStatus.archived) {
      return false;
    }
    final reminder = idea.reminderAtUtc;
    if (reminder != null && reminder.isAfter(nowUtc)) {
      return false;
    }
    final reviewed = idea.lastReviewedAtUtc;
    if (reviewed != null && nowUtc.difference(reviewed) < cooldown) {
      return false;
    }
    return true;
  }

  /// Sélectionne la session : éligibles triées par création croissante
  /// (plus anciennes d'abord), tronquées à [limit].
  static List<Idea> selectSession(
    List<Idea> ideas,
    DateTime nowUtc, {
    int limit = sessionLimit,
    Duration cooldown = reviewCooldown,
  }) {
    final eligible =
        ideas
            .where((idea) => isEligible(idea, nowUtc, cooldown: cooldown))
            .toList()
          ..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    if (eligible.length <= limit) return eligible;
    return eligible.sublist(0, limit);
  }
}
