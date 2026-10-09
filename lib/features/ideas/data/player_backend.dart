import 'package:just_audio/just_audio.dart';

/// Backend de lecture brut, isolé pour être testable sans plugin.
abstract class PlayerBackend {
  /// Charge le fichier et retourne sa durée si connue.
  Future<Duration?> loadFile(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Duration get position;

  Future<void> dispose();
}

class JustAudioPlayerBackend implements PlayerBackend {
  JustAudioPlayerBackend([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> loadFile(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Duration get position => _player.position;

  @override
  Future<void> dispose() => _player.dispose();
}
