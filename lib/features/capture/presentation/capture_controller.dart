import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/recording_service.dart';
import '../domain/capture_errors.dart';

/// États visibles de la capture (brief §11).
enum CaptureState { idle, recording, saving, permissionDenied, error }

/// Pilote la capture côté UI avec un [ChangeNotifier] intégré.
///
/// [onSaved] est appelé après chaque sauvegarde réussie pour
/// rafraîchir la liste (pas de logique métier dupliquée).
class CaptureController extends ChangeNotifier {
  CaptureController(this._service, {this._onSaved});

  final RecordingService _service;
  final Future<void> Function()? _onSaved;

  CaptureState state = CaptureState.idle;
  String? errorMessage;
  Timer? _ticker;

  bool get isRecording => state == CaptureState.recording;

  Duration get elapsed {
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
    notifyListeners();
    try {
      await _service.start();
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => notifyListeners(),
      );
    } on MicPermissionDenied catch (e) {
      state = CaptureState.permissionDenied;
      errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      state = CaptureState.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopAndSave() async {
    if (state != CaptureState.recording) return;
    _ticker?.cancel();
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
      errorMessage = e.message;
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
