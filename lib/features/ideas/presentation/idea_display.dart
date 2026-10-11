import '../../../../../l10n/app_strings.dart';
import '../domain/idea.dart';

/// Libellés de statuts localisés.
String statusLabelFor(IdeaStatus status, [AppStrings? strings]) =>
    (strings ?? const FrStrings()).statusLabel(status);

/// Compat historique : libellés français par défaut.
Map<IdeaStatus, String> get statusLabels =>
    <IdeaStatus, String>{
      IdeaStatus.toReview: const FrStrings().statusLabel(IdeaStatus.toReview),
      IdeaStatus.inProgress: const FrStrings().statusLabel(IdeaStatus.inProgress),
      IdeaStatus.done: const FrStrings().statusLabel(IdeaStatus.done),
      IdeaStatus.archived: const FrStrings().statusLabel(IdeaStatus.archived),
    };

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Titre lisible : titre saisi, sinon repli localisé (jamais une transcription).
String fallbackTitle(Idea idea, [AppStrings? strings]) {
  final s = strings ?? const FrStrings();
  final custom = idea.title?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final local = idea.createdAtUtc.toLocal();
  return s.fallbackTitle(local.day, s.monthName(local.month));
}

/// Mention de rappel affichée sous une idée (heure locale).
String formatReminder(DateTime reminderAtUtc, [AppStrings? strings]) {
  final s = strings ?? const FrStrings();
  final local = reminderAtUtc.toLocal();
  return s.formatReminder(local.day, local.month, local.hour, local.minute);
}
