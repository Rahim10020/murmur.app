import 'package:record/record.dart';

/// Backend d'enregistrement brut, isolé pour être testable sans plugin.
///
/// L'implémentation réelle utilise `record` avec un conteneur AAC/M4A,
/// supporté sur Android et iOS (brief §3-4).
abstract class RecorderBackend {
  Future<bool> hasPermission();

  Future<void> start({required String path});

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class RecordRecorderBackend implements RecorderBackend {
  RecordRecorderBackend([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const RecordConfig config = RecordConfig(encoder: AudioEncoder.aacLc);

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start({required String path}) {
    return _recorder.start(config, path: path);
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}
