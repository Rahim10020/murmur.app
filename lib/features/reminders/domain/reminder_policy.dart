import '../../../l10n/app_strings.dart';
import '../../ideas/domain/idea.dart';

/// Politique de rappels Murmur (brief §3 et §10) — logique pure.
///
/// - la base de données est la source de vérité, la planification OS
///   n'est qu'un effet dérivé ;
/// - planification inexacte uniquement, jamais d'alarme exacte ;
/// - texte de notification discret par défaut (aucun contenu de l'idée).
class ReminderPolicy {
  const ReminderPolicy._();

  /// Titre discret affiché dans la notification (FR historique).
  static const String notificationTitle = 'Une idée à revoir';

  /// Corps discret affiché dans la notification (FR historique).
  static const String notificationBody =
      'Prends un instant pour retrouver une idée enregistrée.';

  static const String channelId = 'murmur_reminders';

  /// Nom de canal historique (FR). Voir `channelNameFor`.
  static const String channelName = 'Rappels';

  /// Description de canal historique (FR). Voir `channelDescriptionFor`.
  static const String channelDescription =
      'Rappels pour revoir vos idées enregistrées.';

  /// Versions localisées (notifications planifiées après le choix de langue).
  static String localizedTitle(AppStrings s) => s.notificationTitle;
  static String localizedBody(AppStrings s) => s.notificationBody;
  static String channelNameFor(AppStrings s) => s.channelName;
  static String channelDescriptionFor(AppStrings s) => s.channelDescription;

  /// ID de notification déterministe dérivé de l'ID stable de l'idée.
  ///
  /// N'utilise PAS [String.hashCode] (instable entre redémarrages) mais
  /// FNV-1a 32 bits, masqué sur 31 bits positifs (plage supportée par
  /// Android). Le risque de collision est documenté et négligeable à
  /// l'échelle d'un usage personnel ; la réconciliation reste correcte
  /// car la DB demeure la source de vérité.
  static int notificationIdFor(String ideaId) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < ideaId.length; i++) {
      hash ^= ideaId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// Les idées terminées ou archivées perdent leur rappel actif.
  static bool cancelsOnStatus(IdeaStatus status) {
    return status == IdeaStatus.done || status == IdeaStatus.archived;
  }

  /// Un rappel n'est actif que s'il est dans le futur (strict).
  static bool isActiveReminder(DateTime? reminderAtUtc, DateTime nowUtc, [AppStrings? strings]) {
    if (reminderAtUtc == null) return false;
    if (!reminderAtUtc.isUtc || !nowUtc.isUtc) {
      throw ArgumentError(
        (strings ?? const FrStrings()).utcCompareMessage,
      );
    }
    return reminderAtUtc.isAfter(nowUtc);
  }

  /// « Plus tard aujourd'hui » : 20h00 locales si encore futur, sinon null.
  static DateTime? laterToday(DateTime nowLocal) {
    final candidate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 20);
    return candidate.isAfter(nowLocal) ? candidate : null;
  }

  /// « Demain » : 9h00 locales le lendemain.
  static DateTime tomorrow(DateTime nowLocal) {
    final next = nowLocal.add(const Duration(days: 1));
    return DateTime(next.year, next.month, next.day, 9);
  }

  /// « Semaine prochaine » : même heure locale dans 7 jours, minutes à 0.
  static DateTime nextWeek(DateTime nowLocal) {
    final next = nowLocal.add(const Duration(days: 7));
    return DateTime(next.year, next.month, next.day, nowLocal.hour);
  }

  /// Refuse les dates passées ou trop proches (marge d'1 minute).
  static void validateFuture(DateTime whenLocal, DateTime nowLocal, [AppStrings? strings]) {
    if (!whenLocal.isAfter(nowLocal.add(const Duration(minutes: 1)))) {
      throw ArgumentError.value(
        whenLocal,
        'when',
        (strings ?? const FrStrings()).reminderPastMessage,
      );
    }
  }
}

/// Plan de réconciliation démarrage : DB (vérité) vs OS (dérivé).
class ReminderReconciliation {
  const ReminderReconciliation._();

  /// [pendingIds] : IDs déjà planifiés côté OS.
  /// [futureByIdea] : rappels futurs persistés, `ideaId -> notificationId`.
  static ({Set<int> toCancel, Set<int> toSchedule}) plan({
    required Set<int> pendingIds,
    required Map<String, int> futureByIdea,
  }) {
    final wanted = futureByIdea.values.toSet();
    final toCancel = pendingIds.difference(wanted);
    final scheduled = pendingIds.intersection(wanted);
    final toSchedule = wanted.difference(scheduled);
    return (toCancel: toCancel, toSchedule: toSchedule);
  }
}
