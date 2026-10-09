import '../domain/idea.dart';

/// Libellés français des statuts.
const Map<IdeaStatus, String> statusLabels = <IdeaStatus, String>{
  IdeaStatus.toReview: 'À revoir',
  IdeaStatus.inProgress: 'En cours',
  IdeaStatus.done: 'Terminée',
  IdeaStatus.archived: 'Archivée',
};

const List<String> _months = <String>[
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Titre lisible : titre saisi, sinon repli localisé (jamais une transcription).
String fallbackTitle(Idea idea) {
  final custom = idea.title?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final local = idea.createdAtUtc.toLocal();
  return 'Idée du ${local.day} ${_months[local.month - 1]}';
}

/// Mention de rappel affichée sous une idée (heure locale).
String formatReminder(DateTime reminderAtUtc) {
  final local = reminderAtUtc.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Rappel le $day/$month à $hour:$minute';
}
