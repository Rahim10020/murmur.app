import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../shared/widgets/murmur_menu.dart';
import '../domain/idea.dart';
import 'idea_display.dart';
import 'playback_controller.dart';

/// Tuile d'une idée : lecture, rappel, menu d'actions, surlignage deep-link.
class IdeaTile extends StatelessWidget {
  const IdeaTile({
    super.key,
    required this.idea,
    required this.highlighted,
    required this.playback,
    required this.audioDir,
    required this.onRename,
    required this.onStatus,
    required this.onDelete,
    required this.onRemind,
  });

  final Idea idea;
  final bool highlighted;
  final PlaybackController playback;
  final Directory audioDir;
  final Future<void> Function(Idea idea) onRename;
  final Future<void> Function(Idea idea, IdeaStatus status) onStatus;
  final Future<void> Function(Idea idea) onDelete;
  final Future<void> Function(Idea idea) onRemind;

  @override
  Widget build(BuildContext context) {
    final playing = playback.isPlaying(idea.id);
    final audioPath = '${audioDir.path}/${idea.audioFileName}';
    final hasReminder = idea.reminderAtUtc != null;
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            tooltip: playing ? 'Pause' : 'Lire',
            icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
            onPressed: () => playback.toggle(idea, audioPath),
          ),
          title: Text(fallbackTitle(idea)),
          subtitle: Text(_subtitle(hasReminder)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: hasReminder
                    ? 'Modifier le rappel'
                    : 'Ajouter un rappel',
                icon: Icon(
                  hasReminder ? LucideIcons.bellRing : LucideIcons.bell,
                ),
                onPressed: () => onRemind(idea),
              ),
              Builder(
                builder: (rowContext) => IconButton(
                  tooltip: 'Actions',
                  icon: const Icon(LucideIcons.ellipsis),
                  onPressed: () => showMurmurMenu(
                    anchorContext: rowContext,
                    items: [
                      MurmurMenuItem(
                        icon: LucideIcons.pencil,
                        label: 'Renommer',
                        onTap: () => onRename(idea),
                      ),
                      MurmurMenuItem(
                        icon: LucideIcons.hourglass,
                        label: 'Commencer',
                        onTap: () => onStatus(idea, IdeaStatus.inProgress),
                      ),
                      MurmurMenuItem(
                        icon: LucideIcons.check,
                        label: 'Marquer terminée',
                        onTap: () => onStatus(idea, IdeaStatus.done),
                      ),
                      MurmurMenuItem(
                        icon: LucideIcons.archive,
                        label: 'Archiver',
                        onTap: () => onStatus(idea, IdeaStatus.archived),
                      ),
                      MurmurMenuItem(
                        icon: LucideIcons.rotateCcw,
                        label: 'Remettre à revoir',
                        onTap: () => onStatus(idea, IdeaStatus.toReview),
                      ),
                      MurmurMenuItem(
                        icon: LucideIcons.trash,
                        label: 'Supprimer',
                        onTap: () => onDelete(idea),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (playback.isActiveFor(idea.id))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ProgressBar(
              position: playback.position,
              total:
                  playback.totalDuration ??
                  Duration(milliseconds: idea.durationMs),
              onSeek: playback.seekTo,
            ),
          ),
      ],
    );
    if (!highlighted) return tile;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primary.withValues(alpha: 0.15),
      child: tile,
    );
  }

  String _subtitle(bool hasReminder) {
    final buffer = StringBuffer(
      '${formatDuration(Duration(milliseconds: idea.durationMs))}'
      ' \u2022 ${statusLabels[idea.status]}',
    );
    if (hasReminder) {
      buffer.write(' \u2022 ${formatReminder(idea.reminderAtUtc!)}');
    }
    if (playback.state == PlaybackState.error &&
        playback.currentIdeaId == idea.id) {
      buffer.write(' \u2022 Erreur lecture');
    }
    return buffer.toString();
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.total,
    required this.onSeek,
  });

  final Duration position;
  final Duration total;
  final Future<void> Function(Duration target) onSeek;

  @override
  Widget build(BuildContext context) {
    final maxMs = total.inMilliseconds;
    final valueMs = position.inMilliseconds.clamp(0, maxMs);
    return Row(
      children: [
        Text(formatDuration(position)),
        Expanded(
          child: Slider(
            value: maxMs == 0 ? 0 : valueMs.toDouble(),
            max: maxMs == 0 ? 1 : maxMs.toDouble(),
            // Seek au relâcher : évite une rafale de seeks pendant le drag.
            onChanged: (_) {},
            onChangeEnd: (value) =>
                onSeek(Duration(milliseconds: value.toInt())),
          ),
        ),
        Text(formatDuration(total)),
      ],
    );
  }
}
