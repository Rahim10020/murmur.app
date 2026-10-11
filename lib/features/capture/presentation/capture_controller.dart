import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../l10n/app_strings.dart';
import '../data/recording_service.dart';
import '../domain/capture_errors.dart';

/// États visibles de la capture (brief §11).
enum CaptureState { idle, recording, saving, permissionDenied, error }

/// Pilote la capture côté UI avec un [ChangeNotifier] intégré.
///
/// [onSaved] est appelé après chaque sauvegarde réussie pour
/// rafraîchir la liste (pas de logique métier dupliquée).
class CaptureController extends ChangeNotifier {
  CaptureController(this._service, {this._onSaved, AppStrings? strings})
    : _strings = strings ?? const FrStrings();

  final RecordingService _service;
  final Future<void> Function()? _onSaved;
  AppStrings _strings;

  /// Met à jour les chaînes (changement de langue).
  void setStrings(AppStrings strings) {
    _strings = strings;
    notifyListeners();
  }

  CaptureState state = CaptureState.idle;
  String? errorMessage;
  Timer? _ticker;

  /// Instant local du tap "enregistrer", positionné AVANT l'init async du
  /// backend (permission système, init recorder). Évite un compteur figé
  /// à 0:00 pendant cette fenêtre.
  DateTime? _recordingStartedAt;

  bool get isRecording => state == CaptureState.recording;

  Duration get elapsed {
    final localStart = _recordingStartedAt;
    if (localStart != null) return DateTime.now().difference(localStart);
    final startedAt = _service.startedAt;
    if (startedAt == null) return Duration.zero;
    return DateTime.now().difference(startedAt);
  }

  Future<void> start() async {
    if (state == CaptureState.recording || state == CaptureState.saving) {
      return;
    }
    state = CaptureState.recording;
    errorMessage = null;
    _recordingStartedAt = DateTime.now();
    _ticker?.cancel();
    // Ticker immédiat : le compteur bouge même pendant la demande de
    // permission / l'init du recorder.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => notifyListeners(),
    );
    notifyListeners();
    try {
      await _service.start();
    } on MicPermissionDenied {
      _ticker?.cancel();
      _recordingStartedAt = null;
      state = CaptureState.permissionDenied;
      errorMessage = _strings.micPermissionDenied;
      notifyListeners();
    } catch (e) {
      _ticker?.cancel();
      _recordingStartedAt = null;
      state = CaptureState.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopAndSave() async {
    if (state != CaptureState.recording) return;
    _ticker?.cancel();
    _recordingStartedAt = null;
    state = CaptureState.saving;
    notifyListeners();
    try {
      await _service.stopAndSave();
      state = CaptureState.idle;
      errorMessage = null;
      notifyListeners();
      await _onSaved?.call();
    } on MetadataSaveFailure catch (e) {
      // L'audio est conservé sur disque : on l'explique, sans faux succès.
      state = CaptureState.error;
      errorMessage = _strings.metadataSaveFailed(e.cause);
      notifyListeners();
      await _onSaved?.call();
    } catch (e) {
      state = CaptureState.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> discard() async {
    _ticker?.cancel();
    _recordingStartedAt = null;
    try {
      await _service.discard();
    } finally {
      state = CaptureState.idle;
      errorMessage = null;
      notifyListeners();
    }
  }

  void reset() {
    if (state == CaptureState.recording) return;
    state = CaptureState.idle;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
