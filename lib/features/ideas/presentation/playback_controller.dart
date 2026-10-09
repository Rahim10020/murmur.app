import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/player_backend.dart';
import '../domain/idea.dart';

/// États visibles de la lecture d'une idée.
enum PlaybackState { idle, loading, playing, paused, completed, error }

/// Pilote la lecture d'un seul flux à la fois (un seul lecteur partagé).
///
/// Fichier manquant ou illisible → état erreur récupérable, jamais de crash.
class PlaybackController extends ChangeNotifier {
  PlaybackController(this._backend);

  final PlayerBackend _backend;

  PlaybackState state = PlaybackState.idle;
  String? currentIdeaId;
  Duration position = Duration.zero;
  Duration? totalDuration;
  String? errorMessage;
  Timer? _ticker;

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
    await _stopTicker();
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
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _poll(),
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
      await _stopTicker();
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
    await _stopTicker();
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
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _poll(),
      );
    } catch (e) {
      state = PlaybackState.error;
      errorMessage = 'Lecture impossible : $e';
      notifyListeners();
    }
  }

  Future<void> _poll() async {
    try {
      position = _backend.position;
    } catch (_) {
      return;
    }
    final total = totalDuration;
    if (total != null &&
        total > Duration.zero &&
        position >= total &&
        state == PlaybackState.playing) {
      await _stopTicker();
      state = PlaybackState.completed;
    }
    notifyListeners();
  }

  Future<void> _stopTicker() async {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _backend.dispose();
    super.dispose();
  }
}
