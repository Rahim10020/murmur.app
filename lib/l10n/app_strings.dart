import '../features/ideas/domain/idea.dart';

/// Source de vérité des textes FR/EN.
///
/// Chaque écran lit ses labels ici (jamais de chaîne en dur côté UI).
/// Les contrôleurs/services exposent aussi leurs messages via ces clés
/// pour que le mode anglais ne laisse aucun résidu français.
abstract class AppStrings {
  const AppStrings();

  bool get isFrench;

  // --- Racine / navigation ---
  String get appTitle;
  String get navHome;
  String get navDiscover;
  String get navSettings;
  String get recordIdea;
  String bootstrapFailed(Object error);
  String get remindersUnavailable;

  // --- Onboarding ---
  String get onboardSkip;
  String get onboardBack;
  String get onboardContinue;
  String get onboardStart;
  String get onboardTitle1;
  String get onboardBody1;
  String get onboardTitle2;
  String get onboardBody2;
  String get onboardTitle3;
  String get onboardBody3;

  // --- Liste des idées ---
  String get ideasEmpty;
  String get retry;
  String get renameTitle;
  String get renameHint;
  String get cancel;
  String get save;
  String get deleteIdeaTitle;
  String get deleteIdeaBody;
  String get keep;
  String get delete;
  String get renameFailed;
  String get statusFailed;
  String get deleteFailed;
  String get ideaNotFound;
  String get ideasLoadFailed;
  String get ideaNotFoundSnack;

  // --- Tuile ---
  String get play;
  String get pause;
  String get addReminder;
  String get editReminder;
  String get actions;
  String get rename;
  String get markInProgress;
  String get markDone;
  String get archive;
  String get backToReview;
  String get playbackError;
  String reminderLabel(String formatted);

  // --- Statuts / dates ---
  String statusLabel(IdeaStatus status);
  String monthName(int month);
  String fallbackTitle(int day, String month);
  String formatReminder(int day, int month, int hour, int minute);
  String recordedOn(String date);

  // --- Lecture ---
  String get playbackFileMissing;
  String playbackFailed(Object error);
  String seekFailed(Object error);

  // --- Capture ---
  String get captureRecording;
  String get captureSaving;
  String get captureMicDenied;
  String get captureError;
  String get captureIdle;
  String get stopAndKeep;
  String get abandon;
  String get close;
  String get abandonRecordTitle;
  String get abandonRecordBody;
  String get micSettingsHint;
  String get micPermissionDenied;
  String get recordingAlreadyActive;
  String get noActiveRecording;
  String metadataSaveFailed(Object cause);
  String recordingStartFailed(Object error);
  String recordingStopFailed(Object error);
  String get recordingTempMissing;

  // --- Rappels ---
  String get remindMe;
  String get noReminder;
  String currentReminder(String formatted);
  String get notifDeniedBody;
  String get laterToday;
  String get tomorrow;
  String get nextWeek;
  String get pickDate;
  String get cancelReminder;
  String get reminderMustBeUtc;
  String get reminderMustBeFuture;
  String get reminderPastMessage;
  String get utcCompareMessage;
  String get notificationTitle;
  String get notificationBody;
  String get channelName;
  String get channelDescription;

  // --- Redécouverte ---
  String get rediscoveryTitle;
  String get rediscoveryEmpty;

  // --- Paramètres / backup ---
  String get settingsTitle;
  String get appearanceSection;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get languageSection;
  String get langSystem;
  String get langFrench;
  String get langEnglish;
  String get backupSection;
  String get backupDescription;
  String get exportBackup;
  String get restoreBackup;
  String get preparingArchive;
  String get nothingToExport;
  String get exportCancelled;
  String exportSaved(String size);
  String get exportFailedPrefix;
  String get chooseBackup;
  String get restoreCancelled;
  String get restoreCancelledUnchanged;
  String get safetyBackup;
  String get restoring;
  String restoreRefused(String message);
  String restoreFailed(Object error);
  String get replaceDataTitle;
  String replaceDataBody(String date, int count, String bytes);
  String get keepMyData;
  String get replace;
  String get restoreDoneTitle;
  String restoreReport(int restored, int rescheduled, int skipped);
  String get rescheduleImpossiblePrefix;
  String get ok;
  String get saveBackupDialogTitle;
  String get pickBackupDialogTitle;
  String formatBytes(int bytes);
  String countIdeas(int count);
  String countReminders(int count);
}

class FrStrings extends AppStrings {
  const FrStrings();

  @override
  bool get isFrench => true;

  @override
  String get appTitle => 'Murmur';
  @override
  String get navHome => 'Accueil';
  @override
  String get navDiscover => 'Redécouvrir des idées';
  @override
  String get navSettings => 'Paramètres et sauvegarde';
  @override
  String get recordIdea => 'Enregistrer une idée';
  @override
  String bootstrapFailed(Object error) => 'Impossible de démarrer Murmur : $error';
  @override
  String get remindersUnavailable =>
      'Les rappels sont indisponibles sur cet appareil pour le moment.';

  @override
  String get onboardSkip => 'Passer';
  @override
  String get onboardBack => 'Retour';
  @override
  String get onboardContinue => 'Continuer';
  @override
  String get onboardStart => 'Commencer';
  @override
  String get onboardTitle1 => 'Une idée ? Murmurez-la.';
  @override
  String get onboardBody1 =>
      'Capturez vos pensées à voix haute en un geste. Rien à écrire, rien à classer.';
  @override
  String get onboardTitle2 => 'Vos mots restent à vous.';
  @override
  String get onboardBody2 =>
      '100 % hors-ligne, sur votre téléphone. Rien n’est envoyé, rien n’est analysé.';
  @override
  String get onboardTitle3 => 'On vous la rappelle.';
  @override
  String get onboardBody3 =>
      'Programmez un rappel, ou laissez Murmur vous faire redécouvrir vos idées au bon moment.';

  @override
  String get ideasEmpty => 'Aucune idée pour le moment';
  @override
  String get retry => 'Réessayer';
  @override
  String get renameTitle => 'Renommer';
  @override
  String get renameHint => 'Titre (optionnel)';
  @override
  String get cancel => 'Annuler';
  @override
  String get save => 'Enregistrer';
  @override
  String get deleteIdeaTitle => 'Supprimer cette idée ?';
  @override
  String get deleteIdeaBody =>
      'L’audio et la fiche seront définitivement supprimés.';
  @override
  String get keep => 'Garder';
  @override
  String get delete => 'Supprimer';
  @override
  String get renameFailed => 'Renommage impossible';
  @override
  String get statusFailed => 'Changement de statut impossible';
  @override
  String get deleteFailed => 'Suppression impossible';
  @override
  String get ideaNotFound => 'Idée introuvable.';
  @override
  String get ideasLoadFailed => 'Impossible de charger les idées';
  @override
  String get ideaNotFoundSnack =>
      'Idée introuvable : elle a peut-être été supprimée.';

  @override
  String get play => 'Lire';
  @override
  String get pause => 'Pause';
  @override
  String get addReminder => 'Ajouter un rappel';
  @override
  String get editReminder => 'Modifier le rappel';
  @override
  String get actions => 'Actions';
  @override
  String get rename => 'Renommer';
  @override
  String get markInProgress => 'Commencer';
  @override
  String get markDone => 'Marquer terminée';
  @override
  String get archive => 'Archiver';
  @override
  String get backToReview => 'Remettre à revoir';
  @override
  String get playbackError => 'Erreur lecture';
  @override
  String reminderLabel(String formatted) => formatted;

  static const _statusFr = <IdeaStatus, String>{
    IdeaStatus.toReview: 'À revoir',
    IdeaStatus.inProgress: 'En cours',
    IdeaStatus.done: 'Terminée',
    IdeaStatus.archived: 'Archivée',
  };

  @override
  String statusLabel(IdeaStatus status) => _statusFr[status]!;

  static const _monthsFr = <String>[
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

  @override
  String monthName(int month) => _monthsFr[month - 1];
  @override
  String fallbackTitle(int day, String month) => 'Idée du $day $month';
  @override
  String formatReminder(int day, int month, int hour, int minute) =>
      'Rappel le ${_two(day)}/${_two(month)} à ${_two(hour)}:${_two(minute)}';
  @override
  String recordedOn(String date) => 'Enregistrée le $date';

  @override
  String get playbackFileMissing =>
      'Fichier audio introuvable pour cette idée.';
  @override
  String playbackFailed(Object error) => 'Lecture impossible : $error';
  @override
  String seekFailed(Object error) => 'Recherche impossible : $error';

  @override
  String get captureRecording => 'Enregistrement en cours…';
  @override
  String get captureSaving => 'Sauvegarde…';
  @override
  String get captureMicDenied => 'Micro non autorisé';
  @override
  String get captureError => 'Un problème est survenu';
  @override
  String get captureIdle => 'Prêt';
  @override
  String get stopAndKeep => 'Arrêter et garder';
  @override
  String get abandon => 'Abandonner';
  @override
  String get close => 'Fermer';
  @override
  String get abandonRecordTitle => 'Abandonner l’enregistrement ?';
  @override
  String get abandonRecordBody =>
      'L’audio en cours sera définitivement perdu.';
  @override
  String get micSettingsHint =>
      'Autorisez le micro dans les réglages Android, puis réessayez.';
  @override
  String get micPermissionDenied =>
      'Le micro est nécessaire pour enregistrer. Autorisez l’accès dans les réglages, puis réessayez.';
  @override
  String get recordingAlreadyActive => 'Un enregistrement est déjà en cours.';
  @override
  String get noActiveRecording => 'Aucun enregistrement en cours.';
  @override
  String metadataSaveFailed(Object cause) =>
      'Enregistrement conservé, mais fiche non sauvegardée : $cause';
  @override
  String recordingStartFailed(Object error) => 'Démarrage impossible : $error';
  @override
  String recordingStopFailed(Object error) => 'Arrêt impossible : $error';
  @override
  String get recordingTempMissing => 'Fichier temporaire introuvable.';

  @override
  String get remindMe => 'Me rappeler';
  @override
  String get noReminder => 'Aucun rappel pour cette idée.';
  @override
  String currentReminder(String formatted) => 'Rappel actuel : $formatted.';
  @override
  String get notifDeniedBody =>
      'Notifications non autorisées : les rappels ne pourront pas s’afficher tant que l’autorisation n’est pas accordée dans les réglages Android.';
  @override
  String get laterToday => 'Plus tard aujourd’hui (20h00)';
  @override
  String get tomorrow => 'Demain (9h00)';
  @override
  String get nextWeek => 'Semaine prochaine';
  @override
  String get pickDate => 'Choisir une date…';
  @override
  String get cancelReminder => 'Annuler le rappel';
  @override
  String get reminderMustBeUtc => 'Le rappel doit être exprimé en UTC.';
  @override
  String get reminderMustBeFuture => 'Le rappel doit être dans le futur.';
  @override
  String get reminderPastMessage => 'Choisissez une date dans le futur.';
  @override
  String get utcCompareMessage => 'Les comparaisons se font en UTC.';
  @override
  String get notificationTitle => 'Une idée à revoir';
  @override
  String get notificationBody =>
      'Prends un instant pour retrouver une idée enregistrée.';
  @override
  String get channelName => 'Rappels';
  @override
  String get channelDescription =>
      'Rappels pour revoir vos idées enregistrées.';

  @override
  String get rediscoveryTitle => 'Redécouverte';
  @override
  String get rediscoveryEmpty => 'Rien à redécouvrir pour le moment';

  @override
  String get settingsTitle => 'Paramètres';
  @override
  String get appearanceSection => 'Apparence';
  @override
  String get themeSystem => 'Système';
  @override
  String get themeLight => 'Clair';
  @override
  String get themeDark => 'Sombre';
  @override
  String get languageSection => 'Langue';
  @override
  String get langSystem => 'Système';
  @override
  String get langFrench => 'Français';
  @override
  String get langEnglish => 'Anglais';
  @override
  String get backupSection => 'Sauvegarde locale';
  @override
  String get backupDescription =>
      'Une archive ZIP contient toutes vos idées et leurs audios. Elle est enregistrée là où vous choisissez (Téléchargements, carte SD, clé USB…) : Murmur ne la téléverse nulle part.';
  @override
  String get exportBackup => 'Exporter une sauvegarde';
  @override
  String get restoreBackup => 'Restaurer une sauvegarde';
  @override
  String get preparingArchive => 'Préparation de l’archive…';
  @override
  String get nothingToExport => 'Rien à exporter : aucune idée enregistrée.';
  @override
  String get exportCancelled => 'Export annulé.';
  @override
  String exportSaved(String size) =>
      'Sauvegarde enregistrée ($size). Pensez à la copier ailleurs : Murmur ne la conserve pas en cas de désinstallation.';
  @override
  String get exportFailedPrefix => 'Export impossible';
  @override
  String get chooseBackup => 'Choisissez une sauvegarde…';
  @override
  String get restoreCancelled => 'Restauration annulée.';
  @override
  String get restoreCancelledUnchanged =>
      'Restauration annulée : vos données sont inchangées.';
  @override
  String get safetyBackup => 'Sauvegarde de sécurité…';
  @override
  String get restoring => 'Restauration en cours…';
  @override
  String restoreRefused(String message) =>
      'Restauration refusée : $message Vos données sont inchangées.';
  @override
  String restoreFailed(Object error) => 'Restauration impossible : $error';
  @override
  String get replaceDataTitle => 'Remplacer les données actuelles ?';
  @override
  String replaceDataBody(String date, int count, String bytes) =>
      'Sauvegarde du $date : ${countIdeas(count)}, $bytes.\n\nVos idées actuelles seront remplacées (une copie de sécurité automatique est conservée dans l’app avant remplacement). Les rappels passés ne seront pas replanifiés.';
  @override
  String get keepMyData => 'Garder mes données';
  @override
  String get replace => 'Remplacer';
  @override
  String get restoreDoneTitle => 'Restauration terminée';
  @override
  String restoreReport(int restored, int rescheduled, int skipped) =>
      '${countIdeasRestored(restored)}.\n${countRemindersRescheduled(rescheduled)}, ${countRemindersSkipped(skipped)}.';
  @override
  String get rescheduleImpossiblePrefix => 'Replanification impossible pour :';
  @override
  String get ok => 'OK';
  @override
  String get saveBackupDialogTitle => 'Enregistrer la sauvegarde Murmur';
  @override
  String get pickBackupDialogTitle => 'Choisir une sauvegarde Murmur';
  @override
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} Ko';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} Mo';
  }

  @override
  String countIdeas(int count) => '$count idée(s)';
  @override
  String countReminders(int count) => '$count rappel(s)';

  String countIdeasRestored(int count) => '$count idée(s) restaurée(s)';
  String countRemindersRescheduled(int count) =>
      '$count rappel(s) futur(s) replanifié(s)';
  String countRemindersSkipped(int count) => '$count passé(s) ignoré(s)';
}

class EnStrings extends AppStrings {
  const EnStrings();

  @override
  bool get isFrench => false;

  @override
  String get appTitle => 'Murmur';
  @override
  String get navHome => 'Home';
  @override
  String get navDiscover => 'Rediscover ideas';
  @override
  String get navSettings => 'Settings and backup';
  @override
  String get recordIdea => 'Record an idea';
  @override
  String bootstrapFailed(Object error) => 'Could not start Murmur: $error';
  @override
  String get remindersUnavailable =>
      'Reminders are unavailable on this device for now.';

  @override
  String get onboardSkip => 'Skip';
  @override
  String get onboardBack => 'Back';
  @override
  String get onboardContinue => 'Continue';
  @override
  String get onboardStart => 'Get started';
  @override
  String get onboardTitle1 => 'Got an idea? Hum it.';
  @override
  String get onboardBody1 =>
      'Capture your thoughts out loud in one gesture. Nothing to write, nothing to file.';
  @override
  String get onboardTitle2 => 'Your words stay yours.';
  @override
  String get onboardBody2 =>
      '100% offline, on your phone. Nothing is sent, nothing is analysed.';
  @override
  String get onboardTitle3 => 'We remind you.';
  @override
  String get onboardBody3 =>
      'Schedule a reminder, or let Murmur resurface your ideas at the right time.';

  @override
  String get ideasEmpty => 'No ideas yet';
  @override
  String get retry => 'Retry';
  @override
  String get renameTitle => 'Rename';
  @override
  String get renameHint => 'Title (optional)';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get deleteIdeaTitle => 'Delete this idea?';
  @override
  String get deleteIdeaBody =>
      'The audio and the card will be permanently deleted.';
  @override
  String get keep => 'Keep';
  @override
  String get delete => 'Delete';
  @override
  String get renameFailed => 'Could not rename';
  @override
  String get statusFailed => 'Could not change status';
  @override
  String get deleteFailed => 'Could not delete';
  @override
  String get ideaNotFound => 'Idea not found.';
  @override
  String get ideasLoadFailed => 'Could not load ideas';
  @override
  String get ideaNotFoundSnack =>
      'Idea not found: it may have been deleted.';

  @override
  String get play => 'Play';
  @override
  String get pause => 'Pause';
  @override
  String get addReminder => 'Add a reminder';
  @override
  String get editReminder => 'Edit reminder';
  @override
  String get actions => 'Actions';
  @override
  String get rename => 'Rename';
  @override
  String get markInProgress => 'Start';
  @override
  String get markDone => 'Mark as done';
  @override
  String get archive => 'Archive';
  @override
  String get backToReview => 'Move back to review';
  @override
  String get playbackError => 'Playback error';
  @override
  String reminderLabel(String formatted) => formatted;

  static const _statusEn = <IdeaStatus, String>{
    IdeaStatus.toReview: 'To review',
    IdeaStatus.inProgress: 'In progress',
    IdeaStatus.done: 'Done',
    IdeaStatus.archived: 'Archived',
  };

  @override
  String statusLabel(IdeaStatus status) => _statusEn[status]!;

  static const _monthsEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  String monthName(int month) => _monthsEn[month - 1];
  @override
  String fallbackTitle(int day, String month) => 'Idea of $day $month';
  @override
  String formatReminder(int day, int month, int hour, int minute) =>
      'Reminder on ${_two(month)}/${_two(day)} at ${_two(hour)}:${_two(minute)}';
  @override
  String recordedOn(String date) => 'Recorded on $date';

  @override
  String get playbackFileMissing => 'Audio file missing for this idea.';
  @override
  String playbackFailed(Object error) => 'Cannot play: $error';
  @override
  String seekFailed(Object error) => 'Cannot seek: $error';

  @override
  String get captureRecording => 'Recording…';
  @override
  String get captureSaving => 'Saving…';
  @override
  String get captureMicDenied => 'Microphone not allowed';
  @override
  String get captureError => 'Something went wrong';
  @override
  String get captureIdle => 'Ready';
  @override
  String get stopAndKeep => 'Stop and keep';
  @override
  String get abandon => 'Discard';
  @override
  String get close => 'Close';
  @override
  String get abandonRecordTitle => 'Discard this recording?';
  @override
  String get abandonRecordBody => 'The current audio will be lost for good.';
  @override
  String get micSettingsHint =>
      'Allow the microphone in the Android settings, then try again.';
  @override
  String get micPermissionDenied =>
      'The microphone is required to record. Allow access in settings, then try again.';
  @override
  String get recordingAlreadyActive => 'A recording is already in progress.';
  @override
  String get noActiveRecording => 'No recording in progress.';
  @override
  String metadataSaveFailed(Object cause) =>
      'Recording kept, but card not saved: $cause';
  @override
  String recordingStartFailed(Object error) => 'Could not start: $error';
  @override
  String recordingStopFailed(Object error) => 'Could not stop: $error';
  @override
  String get recordingTempMissing => 'Temporary file missing.';

  @override
  String get remindMe => 'Remind me';
  @override
  String get noReminder => 'No reminder for this idea.';
  @override
  String currentReminder(String formatted) => 'Current reminder: $formatted.';
  @override
  String get notifDeniedBody =>
      'Notifications are not allowed: reminders cannot show until you grant permission in the Android settings.';
  @override
  String get laterToday => 'Later today (8:00 PM)';
  @override
  String get tomorrow => 'Tomorrow (9:00 AM)';
  @override
  String get nextWeek => 'Next week';
  @override
  String get pickDate => 'Pick a date…';
  @override
  String get cancelReminder => 'Cancel reminder';
  @override
  String get reminderMustBeUtc => 'The reminder must be expressed in UTC.';
  @override
  String get reminderMustBeFuture => 'The reminder must be in the future.';
  @override
  String get reminderPastMessage => 'Pick a date in the future.';
  @override
  String get utcCompareMessage => 'Comparisons are done in UTC.';
  @override
  String get notificationTitle => 'An idea to review';
  @override
  String get notificationBody => 'Take a moment to revisit a saved idea.';
  @override
  String get channelName => 'Reminders';
  @override
  String get channelDescription => 'Reminders to review your saved ideas.';

  @override
  String get rediscoveryTitle => 'Rediscovery';
  @override
  String get rediscoveryEmpty => 'Nothing to rediscover for now';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearanceSection => 'Appearance';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get languageSection => 'Language';
  @override
  String get langSystem => 'System';
  @override
  String get langFrench => 'French';
  @override
  String get langEnglish => 'English';
  @override
  String get backupSection => 'Local backup';
  @override
  String get backupDescription =>
      'A ZIP archive holds all your ideas and their audio. It is saved where you choose (Downloads, SD card, USB drive…): Murmur never uploads it anywhere.';
  @override
  String get exportBackup => 'Export a backup';
  @override
  String get restoreBackup => 'Restore a backup';
  @override
  String get preparingArchive => 'Preparing the archive…';
  @override
  String get nothingToExport => 'Nothing to export: no ideas recorded.';
  @override
  String get exportCancelled => 'Export cancelled.';
  @override
  String exportSaved(String size) =>
      'Backup saved ($size). Copy it elsewhere: Murmur will not keep it if uninstalled.';
  @override
  String get exportFailedPrefix => 'Could not export';
  @override
  String get chooseBackup => 'Pick a backup…';
  @override
  String get restoreCancelled => 'Restore cancelled.';
  @override
  String get restoreCancelledUnchanged =>
      'Restore cancelled: your data is unchanged.';
  @override
  String get safetyBackup => 'Safety backup…';
  @override
  String get restoring => 'Restoring…';
  @override
  String restoreRefused(String message) =>
      'Restore refused: $message Your data is unchanged.';
  @override
  String restoreFailed(Object error) => 'Could not restore: $error';
  @override
  String get replaceDataTitle => 'Replace current data?';
  @override
  String replaceDataBody(String date, int count, String bytes) =>
      'Backup of $date: ${countIdeas(count)}, $bytes.\n\nYour current ideas will be replaced (an automatic safety copy is kept in the app first). Past reminders will not be rescheduled.';
  @override
  String get keepMyData => 'Keep my data';
  @override
  String get replace => 'Replace';
  @override
  String get restoreDoneTitle => 'Restore complete';
  @override
  String restoreReport(int restored, int rescheduled, int skipped) =>
      '${countIdeasRestored(restored)}.\n${countRemindersRescheduled(rescheduled)}, ${countRemindersSkipped(skipped)}.';
  @override
  String get rescheduleImpossiblePrefix => 'Could not reschedule for:';
  @override
  String get ok => 'OK';
  @override
  String get saveBackupDialogTitle => 'Save the Murmur backup';
  @override
  String get pickBackupDialogTitle => 'Pick a Murmur backup';
  @override
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  String countIdeas(int count) => count == 1 ? '1 idea' : '$count ideas';
  @override
  String countReminders(int count) =>
      count == 1 ? '1 reminder' : '$count reminders';

  String countIdeasRestored(int count) =>
      count == 1 ? '1 idea restored' : '$count ideas restored';
  String countRemindersRescheduled(int count) =>
      count == 1
          ? '1 future reminder rescheduled'
          : '$count future reminders rescheduled';
  String countRemindersSkipped(int count) =>
      count == 1 ? '1 past skipped' : '$count past skipped';
}

String _two(int value) => value.toString().padLeft(2, '0');
