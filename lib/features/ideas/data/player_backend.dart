import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Instantané de lecture émis en continu, adapté à la barre de progression.
class PlayerStatus {
  const PlayerStatus({
    required this.position,
    required this.duration,
    required this.playing,
    required this.completed,
  });

  final Duration position;
  final Duration? duration;
  final bool playing;
  final bool completed;
}

/// Backend de lecture brut, isolé pour être testable sans plugin.
///
/// La progression passe par [statusStream] (émissions régulières de
/// just_audio, adaptées à une seek bar) et non par sondage du getter
/// `position`, dont la valeur dérive du dernier événement natif reçu.
abstract class PlayerBackend {
  /// Charge le fichier et retourne sa durée si connue.
  Future<Duration?> loadFile(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  /// Émissions continues pendant la lecture (silencieux en pause).
  Stream<PlayerStatus> statusStream();

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
  Stream<PlayerStatus> statusStream() {
    final out = StreamController<PlayerStatus>();
    Duration position = Duration.zero;
    Duration? duration;
    bool playing = false;
    bool completed = false;

    void emit() {
      if (!out.isClosed) {
        out.add(
          PlayerStatus(
            position: position,
            duration: duration,
            playing: playing,
            completed: completed,
          ),
        );
      }
    }

    final subscriptions = <StreamSubscription<void>>[
      _player.positionStream.listen((event) {
        position = event;
        emit();
      }),
      _player.durationStream.listen((event) {
        duration = event;
        emit();
      }),
      _player.playerStateStream.listen((event) {
        playing = event.playing;
        completed = event.processingState == ProcessingState.completed;
        emit();
      }),
    ];
    out.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    return out.stream;
  }

  @override
  Future<void> dispose() => _player.dispose();
}
