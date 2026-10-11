import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../l10n/app_strings.dart';
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
  PlaybackController(this._backend, {AppStrings? strings})
    : _strings = strings ?? const FrStrings();

  final PlayerBackend _backend;
  AppStrings _strings;

  /// Met à jour les chaînes (changement de langue).
  void setStrings(AppStrings strings) {
    _strings = strings;
    notifyListeners();
  }

  PlaybackState state = PlaybackState.idle;
  String? currentIdeaId;
  Duration position = Duration.zero;
  Duration? totalDuration;
  String? errorMessage;
  StreamSubscription<PlayerStatus>? _statusSubscription;

  /// Vrai dès qu'un événement `playing: true` a été reçu pour la lecture
  /// en cours. Tant que ce n'est pas confirmé, les événements
  /// `playing: false` initiaux (valeurs par défaut du wrapper, transition
  /// stop → load → buffering de just_audio) sont ignorés : ils ne doivent
  /// pas rabattre un `playing` optimiste vers `paused` au premier tap.
  bool _playingConfirmed = false;

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
    _playingConfirmed = false;
    notifyListeners();

    if (!await File(audioPath).exists()) {
      state = PlaybackState.error;
      errorMessage = _strings.playbackFileMissing;
      notifyListeners();
      return;
    }
    try {
      totalDuration = await _backend.loadFile(audioPath);
      // S'abonner AVANT play() : ne rater aucun événement natif et laisser
      // _onStatus confirmer le passage en lecture.
      await _cancelStatusSubscription();
      _statusSubscription = _backend.statusStream().listen(
        _onStatus,
        onError: (_) {},
      );
      await _backend.play();
      // Filet de sécurité : si le stream ne confirme pas (backend factice
      // en test, événement déjà consommé), on affiche quand même l'état
      // lecture. Les faux `playing: false` initiaux restent ignorés via
      // _playingConfirmed (voir _onStatus).
      if (state == PlaybackState.loading) {
        state = PlaybackState.playing;
        notifyListeners();
      }
    } catch (e) {
      await _cancelStatusSubscription();
      state = PlaybackState.error;
      errorMessage = _strings.playbackFailed(e);
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
      errorMessage = _strings.seekFailed(e);
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
    _playingConfirmed = false;
    state = PlaybackState.idle;
    currentIdeaId = null;
    position = Duration.zero;
    totalDuration = null;
    notifyListeners();
  }

  Future<void> _resume() async {
    final restartFromBeginning = state == PlaybackState.completed;
    // On exige une re-confirmation : les événements `playing: false`
    // émis pendant la reprise (re-buffering) ne doivent pas rebasculer
    // aussitôt en pause.
    _playingConfirmed = false;
    state = PlaybackState.playing;
    try {
      if (restartFromBeginning) {
        await _backend.seek(Duration.zero);
        position = Duration.zero;
      }
      notifyListeners();
      await _cancelStatusSubscription();
      _statusSubscription = _backend.statusStream().listen(
        _onStatus,
        onError: (_) {},
      );
      await _backend.play();
    } catch (e) {
      await _cancelStatusSubscription();
      state = PlaybackState.error;
      errorMessage = _strings.playbackFailed(e);
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
    } else if (status.playing || status.buffering) {
      _playingConfirmed = true;
      if (state == PlaybackState.paused ||
          state == PlaybackState.loading) {
        state = PlaybackState.playing;
      }
    } else if (!status.playing && state == PlaybackState.playing) {
      // Interruption externe (appel, autre app audio…) : buffering est
      // traité séparément ci-dessus ; seuls les vrais arrêts basculent
      // vers paused.
      if (_playingConfirmed) {
        state = PlaybackState.paused;
      }
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
