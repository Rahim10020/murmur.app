import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../ideas/domain/idea.dart';
import '../../ideas/presentation/idea_display.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../../ideas/presentation/playback_controller.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/presentation/reminder_sheet.dart';
import '../domain/rediscovery_policy.dart';

/// Session de redécouverte hebdo : au plus 3 idées, une carte à la fois.
///
/// Chaque carte propose les 5 choix du brief : commencer, rappeler plus
/// tard, garder pour plus tard, terminer, archiver. Sélection déterministe
/// (plus anciennes éligibles d'abord), aucune recommandation.
class RediscoverySessionPage extends StatefulWidget {
  const RediscoverySessionPage({
    super.key,
    required this.ideas,
    required this.controller,
    required this.playback,
    required this.reminders,
    required this.audioDir,
  });

  /// Snapshot figé à l'ouverture (IDs traités dans l'ordre).
  final List<Idea> ideas;
  final IdeasController controller;
  final PlaybackController playback;
  final ReminderService reminders;
  final Directory audioDir;

  @override
  State<RediscoverySessionPage> createState() => _RediscoverySessionPageState();
}

class _RediscoverySessionPageState extends State<RediscoverySessionPage> {
  int _index = 0;
  bool _busy = false;
  String? _error;

  bool get _done => _index >= widget.ideas.length;

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_onPlayback);
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onPlayback);
    super.dispose();
  }

  void _onPlayback() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _done
              ? 'Redécouverte'
              : 'Redécouverte ${_index + 1}/${widget.ideas.length}',
        ),
      ),
      body: _done ? _summary() : _card(widget.ideas[_index]),
    );
  }

  Widget _summary() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleCheck, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Session terminée. Vos idées sont à jour.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Idea idea) {
    final audioPath = '${widget.audioDir.path}/${idea.audioFileName}';
    final playing = widget.playback.isPlaying(idea.id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: playing ? 'Pause' : 'Lire',
                  icon: Icon(
                    playing ? LucideIcons.pause : LucideIcons.play,
                    size: 32,
                  ),
                  onPressed: () => widget.playback.toggle(idea, audioPath),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fallbackTitle(idea),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enregistrée le ${_formatDate(idea.createdAtUtc)} • '
              '${formatDuration(Duration(milliseconds: idea.durationMs))}',
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!)],
            const Spacer(),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.inProgress,
                    reminders: widget.reminders,
                  ),
                ),
                icon: const Icon(LucideIcons.hourglass),
                label: const Text('Commencer à travailler dessus'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _remindLater(idea),
                icon: const Icon(LucideIcons.bellRing),
                label: const Text('Me rappeler plus tard'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _act(idea, () => widget.controller.markReviewed(idea.id)),
                icon: const Icon(LucideIcons.eye),
                label: const Text('Garder pour plus tard'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.done,
                    reminders: widget.reminders,
                  ),
                ),
                icon: const Icon(LucideIcons.check),
                label: const Text('Marquer comme terminée'),
              ),
              TextButton.icon(
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.archived,
                    reminders: widget.reminders,
                  ),
                ),
                icon: const Icon(LucideIcons.archive),
                label: const Text('Archiver'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _act(Idea idea, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.playback.stopIfCurrent(idea.id);
      await action();
      if (mounted) {
        setState(() {
          _busy = false;
          _index++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _remindLater(Idea idea) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ReminderSheet(
        idea: idea,
        controller: widget.controller,
        reminders: widget.reminders,
      ),
    );
    if (mounted) {
      setState(() => _index++);
    }
  }

  String _formatDate(DateTime utc) {
    final local = utc.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// Point d'entrée de la session : calcule la sélection et navigue.
///
/// Affiche un message explicite quand rien n'est éligible.
Future<void> openRediscoverySession({
  required BuildContext context,
  required IdeasController controller,
  required PlaybackController playback,
  required ReminderService reminders,
  required Directory audioDir,
}) async {
  final selection = RediscoveryPolicy.selectSession(
    controller.ideas,
    DateTime.now().toUtc(),
  );
  if (selection.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rien à redécouvrir pour le moment.')),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RediscoverySessionPage(
        ideas: selection,
        controller: controller,
        playback: playback,
        reminders: reminders,
        audioDir: audioDir,
      ),
    ),
  );
  await controller.refresh();
}
