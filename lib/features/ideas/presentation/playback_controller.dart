import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/player_backend.dart';
import '../domain/idea.dart';

/// États visibles de la lecture d'une idée.
enum PlaybackState { idle, loading, playing, paused, completed, error }

/// Pilote la lecture d'un seul flux à la fois (un seul lecteur partagé).
///
/// La progression suit [PlayerBackend.statusStream] (émissions régulières) :
/// aucun sondage par timer. Fichier manquant ou illisible → état erreur
/// récupérable, jamais de crash.
class PlaybackController extends ChangeNotifier {
  PlaybackController(this._backend);

  final PlayerBackend _backend;

  PlaybackState state = PlaybackState.idle;
  String? currentIdeaId;
  Duration position = Duration.zero;
  Duration? totalDuration;
  String? errorMessage;
  StreamSubscription<PlayerStatus>? _statusSubscription;

  bool isActiveFor(String ideaId) =>
      currentIdeaId == ideaId &&
      (state == PlaybackState.playing ||
          state == PlaybackState.paused ||
          state == PlaybackState.loading ||
          state == PlaybackState.completed);

  bool isPlaying(String ideaId) =>
      currentIdeaId == ideaId && state == PlaybackState.playing;

  Future<void> toggle(Idea idea, String audioPath) async {
    if (isPlaying(idea.id)) {
      await pause();
      return;
    }
    if (currentIdeaId == idea.id &&
        (state == PlaybackState.paused || state == PlaybackState.completed)) {
      await _resume();
      return;
    }
    await play(idea, audioPath);
  }

  Future<void> play(Idea idea, String audioPath) async {
    await _cancelStatusSubscription();
    try {
      await _backend.stop();
    } catch (_) {
      // Best-effort : un lecteur déjà arrêté ne bloque pas la lecture.
    }
    state = PlaybackState.loading;
    currentIdeaId = idea.id;
    position = Duration.zero;
    totalDuration = null;
    errorMessage = null;
    notifyListeners();

    if (!await File(audioPath).exists()) {
      state = PlaybackState.error;
      errorMessage = 'Fichier audio introuvable pour cette idée.';
      notifyListeners();
      return;
    }
    try {
      totalDuration = await _backend.loadFile(audioPath);
      await _backend.play();
      state = PlaybackState.playing;
      notifyListeners();
      _statusSubscription = _backend.statusStream().listen(
        _onStatus,
        onError: (_) {},
      );
    } catch (e) {
      state = PlaybackState.error;
      errorMessage = 'Lecture impossible : $e';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (state != PlaybackState.playing) return;
    try {
      await _backend.pause();
    } finally {
      state = PlaybackState.paused;
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration target) async {
    if (currentIdeaId == null) return;
    try {
      await _backend.seek(target);
      position = target;
      notifyListeners();
    } catch (e) {
      state = PlaybackState.error;
      errorMessage = 'Recherche impossible : $e';
      notifyListeners();
    }
  }

  /// Appelé quand l'idée courante est supprimée : coupe le son associé.
  Future<void> stopIfCurrent(String ideaId) async {
    if (currentIdeaId != ideaId) return;
    await stop();
  }

  Future<void> stop() async {
    await _cancelStatusSubscription();
    try {
      await _backend.stop();
    } catch (_) {
      // Best-effort.
    }
    state = PlaybackState.idle;
    currentIdeaId = null;
    position = Duration.zero;
    totalDuration = null;
    notifyListeners();
  }

  Future<void> _resume() async {
    state = PlaybackState.playing;
    notifyListeners();
    try {
      await _backend.play();
      await _cancelStatusSubscription();
      _statusSubscription = _backend.statusStream().listen(
        _onStatus,
        onError: (_) {},
      );
    } catch (e) {
      state = PlaybackState.error;
      errorMessage = 'Lecture impossible : $e';
      notifyListeners();
    }
  }

  void _onStatus(PlayerStatus status) {
    if (currentIdeaId == null || state == PlaybackState.error) return;
    position = status.position;
    if (status.duration != null) {
      totalDuration = status.duration;
    }
    if (status.completed) {
      if (state == PlaybackState.playing) {
        state = PlaybackState.completed;
      }
    } else if (!status.playing && state == PlaybackState.playing) {
      // Interruption externe (appel, autre app audio…).
      state = PlaybackState.paused;
    } else if (status.playing &&
        (state == PlaybackState.paused || state == PlaybackState.loading)) {
      state = PlaybackState.playing;
    }
    notifyListeners();
  }

  Future<void> _cancelStatusSubscription() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  void dispose() {
    _cancelStatusSubscription();
    _backend.dispose();
    super.dispose();
  }
}
