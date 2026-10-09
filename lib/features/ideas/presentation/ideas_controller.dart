import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/domain/reminder_policy.dart';
import '../domain/idea.dart';
import '../domain/idea_repository.dart';

/// État de chargement de la liste des idées.
enum IdeasListState { initial, loading, loaded, error }

/// Contrôleur de la liste (built-in [ChangeNotifier], brief §5).
///
/// Expose la source de vérité (repository) à l'UI sans logique métier cachée.
/// La suppression d'une idée supprime aussi son fichier audio ; l'échec
/// d'une opération remonte un message affichable, jamais silencieux.
class IdeasController extends ChangeNotifier {
  IdeasController(this._repository);

  final IdeaRepository _repository;

  IdeasListState state = IdeasListState.initial;
  List<Idea> ideas = const <Idea>[];
  String? errorMessage;

  Future<void> refresh() async {
    state = IdeasListState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      ideas = await _repository.listNewestFirst();
      state = IdeasListState.loaded;
    } catch (e) {
      state = IdeasListState.error;
      errorMessage = 'Impossible de charger les idées : $e';
    }
    notifyListeners();
  }

  Future<void> rename(String id, String? title) async {
    final current = await _repository.findById(id);
    if (current == null) {
      throw StateError('Idée introuvable.');
    }
    final trimmed = title?.trim();
    await _repository.update(
      current.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        title: () => trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
    await refresh();
  }

  Future<void> setStatus(
    String id,
    IdeaStatus status, {
    ReminderService? reminders,
  }) async {
    final current = await _repository.findById(id);
    if (current == null) {
      throw StateError('Idée introuvable.');
    }
    final cancelsReminder =
        reminders != null &&
        ReminderPolicy.cancelsOnStatus(status) &&
        current.reminderAtUtc != null;
    await _repository.update(
      current.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        status: status,
        reminderAtUtc: cancelsReminder ? () => null : null,
      ),
    );
    if (cancelsReminder) {
      await reminders.cancelReminder(id);
    }
    await refresh();
  }

  /// Définit (ou déplace) le rappel d'une idée.
  ///
  /// La DB est écrite d'abord (source de vérité) puis l'OS est planifié ;
  /// si la planification échoue, la DB est restaurée et l'erreur remonte.
  Future<void> setReminder(
    String id,
    DateTime whenUtc,
    ReminderService reminders,
  ) async {
    if (!whenUtc.isUtc) {
      throw ArgumentError('Le rappel doit être exprimé en UTC.');
    }
    if (!whenUtc.isAfter(DateTime.now().toUtc())) {
      throw ArgumentError.value(
        whenUtc,
        'whenUtc',
        'Choisissez une date dans le futur.',
      );
    }
    final current = await _repository.findById(id);
    if (current == null) {
      throw StateError('Idée introuvable.');
    }
    final previous = current.reminderAtUtc;
    await _repository.update(
      current.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        reminderAtUtc: () => whenUtc,
      ),
    );
    try {
      await reminders.scheduleReminder(ideaId: id, whenUtc: whenUtc);
    } catch (e) {
      // Restaure la vérité DB : pas de rappel fantôme.
      final rollback = await _repository.findById(id);
      if (rollback != null) {
        await _repository.update(
          rollback.copyWith(reminderAtUtc: () => previous),
        );
      }
      await refresh();
      rethrow;
    }
    await refresh();
  }

  /// Supprime le rappel d'une idée (DB + OS).
  Future<void> clearReminder(String id, ReminderService reminders) async {
    final current = await _repository.findById(id);
    if (current == null) {
      throw StateError('Idée introuvable.');
    }
    await _repository.update(
      current.copyWith(
        updatedAtUtc: DateTime.now().toUtc(),
        reminderAtUtc: () => null,
      ),
    );
    await reminders.cancelReminder(id);
    await refresh();
  }

  /// Supprime la fiche puis le fichier audio.
  ///
  /// Si la suppression DB échoue, le fichier est conservé (pas de perte
  /// orpheline) et l'erreur remonte. Si seul le fichier manque, la fiche
  /// est quand même supprimée.
  Future<void> deleteIdea(
    Idea idea,
    Directory audioDir, {
    ReminderService? reminders,
  }) async {
    Object? cancelError;
    if (reminders != null) {
      try {
        await reminders.cancelReminder(idea.id);
      } catch (e) {
        cancelError = e;
      }
    }
    await _repository.deleteById(idea.id);
    final file = File('${audioDir.path}/${idea.audioFileName}');
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      throw StateError('Fiche supprimée, mais fichier audio conservé : $e');
    }
    await refresh();
    if (cancelError != null) {
      throw StateError(
        'Idée supprimée, mais le rappel n’a pas pu être annulé : '
        '$cancelError',
      );
    }
  }
}
