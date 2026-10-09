import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/theme.dart';
import '../../capture/presentation/capture_controller.dart';
import '../domain/idea.dart';
import 'ideas_controller.dart';
import 'playback_controller.dart';

const Map<IdeaStatus, String> statusLabels = <IdeaStatus, String>{
  IdeaStatus.toReview: 'À revoir',
  IdeaStatus.inProgress: 'En cours',
  IdeaStatus.done: 'Terminée',
  IdeaStatus.archived: 'Archivée',
};

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String fallbackTitle(Idea idea) {
  final custom = idea.title?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final local = idea.createdAtUtc.toLocal();
  const months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return 'Idée du ${local.day} ${months[local.month - 1]}';
}

/// Écran liste des idées : lecture, statuts, capture (français par défaut).
class IdeasPage extends StatefulWidget {
  const IdeasPage({
    super.key,
    required this.controller,
    required this.capture,
    required this.playback,
    required this.audioDir,
  });

  final IdeasController controller;
  final CaptureController capture;
  final PlaybackController playback;
  final Directory audioDir;

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.capture.addListener(_onChanged);
    widget.playback.addListener(_onChanged);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.capture.removeListener(_onChanged);
    widget.playback.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Murmur')),
      body: switch (controller.state) {
        IdeasListState.initial || IdeasListState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        IdeasListState.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.errorMessage ?? 'Erreur inconnue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.refresh,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        IdeasListState.loaded =>
          controller.ideas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucune idée pour le moment.\nAppuyez sur le micro pour capturer votre première idée.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: controller.ideas.length,
                  itemBuilder: (context, index) {
                    return _IdeaTile(
                      idea: controller.ideas[index],
                      playback: widget.playback,
                      audioDir: widget.audioDir,
                      onRename: _rename,
                      onStatus: _setStatus,
                      onDelete: _delete,
                    );
                  },
                ),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: _openCaptureSheet,
        tooltip: 'Enregistrer une idée',
        child: const Icon(LucideIcons.mic),
      ),
    );
  }

  Future<void> _openCaptureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: false,
      builder: (_) => CaptureSheet(
        capture: widget.capture,
        onSaved: () => widget.controller.refresh(),
      ),
    );
  }

  Future<void> _rename(Idea idea) async {
    final textController = TextEditingController(text: idea.title ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Titre (optionnel)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.controller.rename(idea.id, result);
    } catch (e) {
      _snack('Renommage impossible : $e');
    }
  }

  Future<void> _setStatus(Idea idea, IdeaStatus status) async {
    try {
      await widget.controller.setStatus(idea.id, status);
    } catch (e) {
      _snack('Changement de statut impossible : $e');
    }
  }

  Future<void> _delete(Idea idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette idée ?'),
        content: const Text(
          'L’audio et la fiche seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.playback.stopIfCurrent(idea.id);
      await widget.controller.deleteIdea(idea, widget.audioDir);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IdeaTile extends StatelessWidget {
  const _IdeaTile({
    required this.idea,
    required this.playback,
    required this.audioDir,
    required this.onRename,
    required this.onStatus,
    required this.onDelete,
  });

  final Idea idea;
  final PlaybackController playback;
  final Directory audioDir;
  final Future<void> Function(Idea idea) onRename;
  final Future<void> Function(Idea idea, IdeaStatus status) onStatus;
  final Future<void> Function(Idea idea) onDelete;

  @override
  Widget build(BuildContext context) {
    final active = playback.isActiveFor(idea.id);
    final playing = playback.isPlaying(idea.id);
    final audioPath = '${audioDir.path}/${idea.audioFileName}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            tooltip: playing ? 'Pause' : 'Lire',
            icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
            onPressed: () => playback.toggle(idea, audioPath),
          ),
          title: Text(fallbackTitle(idea)),
          subtitle: Text(
            '${formatDuration(Duration(milliseconds: idea.durationMs))}'
            ' • ${statusLabels[idea.status]}'
            '${playback.state == PlaybackState.error && playback.currentIdeaId == idea.id ? ' • Erreur lecture' : ''}',
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsis),
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  onRename(idea);
                case 'inProgress':
                  onStatus(idea, IdeaStatus.inProgress);
                case 'done':
                  onStatus(idea, IdeaStatus.done);
                case 'archive':
                  onStatus(idea, IdeaStatus.archived);
                case 'review':
                  onStatus(idea, IdeaStatus.toReview);
                case 'delete':
                  onDelete(idea);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(LucideIcons.pencil),
                    SizedBox(width: 12),
                    Text('Renommer'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'inProgress',
                child: Row(
                  children: [
                    Icon(LucideIcons.hourglass),
                    SizedBox(width: 12),
                    Text('Commencer'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'done',
                child: Row(
                  children: [
                    Icon(LucideIcons.check),
                    SizedBox(width: 12),
                    Text('Marquer terminée'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(LucideIcons.archive),
                    SizedBox(width: 12),
                    Text('Archiver'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'review',
                child: Row(
                  children: [
                    Icon(LucideIcons.rotateCcw),
                    SizedBox(width: 12),
                    Text('Remettre à revoir'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash),
                    SizedBox(width: 12),
                    Text('Supprimer'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (active)
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
            onChanged: (value) => onSeek(Duration(milliseconds: value.toInt())),
          ),
        ),
        Text(formatDuration(total)),
      ],
    );
  }
}

/// Panneau de capture : un seul geste pour démarrer, un seul pour garder.
class CaptureSheet extends StatefulWidget {
  const CaptureSheet({super.key, required this.capture, required this.onSaved});

  final CaptureController capture;
  final Future<void> Function() onSaved;

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  @override
  void initState() {
    super.initState();
    widget.capture.addListener(_onChanged);
    widget.capture.start();
  }

  @override
  void dispose() {
    widget.capture.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final capture = widget.capture;
    final brightness = Theme.of(context).brightness;
    return PopScope(
      canPop: capture.state != CaptureState.recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || capture.state != CaptureState.recording) return;
        final abandon = await _confirmAbandon();
        if (abandon == true && context.mounted) {
          await capture.discard();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatDuration(capture.elapsed),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(_headline(capture.state)),
              if (capture.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(capture.errorMessage!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              _actions(context, brightness, capture),
            ],
          ),
        ),
      ),
    );
  }

  String _headline(CaptureState state) {
    return switch (state) {
      CaptureState.recording => 'Enregistrement en cours…',
      CaptureState.saving => 'Sauvegarde…',
      CaptureState.permissionDenied => 'Micro non autorisé',
      CaptureState.error => 'Un problème est survenu',
      CaptureState.idle => 'Prêt',
    };
  }

  Widget _actions(
    BuildContext context,
    Brightness brightness,
    CaptureController capture,
  ) {
    switch (capture.state) {
      case CaptureState.recording:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await capture.stopAndSave();
                  await widget.onSaved();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.square),
                label: const Text('Arrêter et garder'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: MurmurTheme.secondaryButtonStyle(brightness),
                onPressed: () async {
                  final abandon = await _confirmAbandon();
                  if (abandon != true) return;
                  await capture.discard();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.x),
                label: const Text('Abandonner'),
              ),
            ),
          ],
        );
      case CaptureState.saving:
        return const CircularProgressIndicator();
      case CaptureState.permissionDenied:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Autorisez le micro dans les réglages Android, puis réessayez.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => capture.start(),
                    icon: const Icon(LucideIcons.mic),
                    label: const Text('Réessayer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: MurmurTheme.secondaryButtonStyle(brightness),
                    onPressed: () {
                      capture.reset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ],
        );
      case CaptureState.error:
      case CaptureState.idle:
        return FilledButton(
          onPressed: () {
            capture.reset();
            Navigator.of(context).pop();
          },
          child: const Text('Fermer'),
        );
    }
  }

  Future<bool?> _confirmAbandon() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner l’enregistrement ?'),
        content: const Text('L’audio en cours sera définitivement perdu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
  }
}
