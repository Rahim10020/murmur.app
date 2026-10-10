import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../ideas/domain/idea.dart';
import '../../ideas/presentation/idea_display.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../../ideas/presentation/playback_controller.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/presentation/reminder_sheet.dart';
import '../domain/rediscovery_policy.dart';

/// Onglet de redécouverte hebdo : au plus 3 idées, une carte à la fois.
///
/// La sélection est recalculée en continu depuis le contrôleur (plus
/// anciennes éligibles d'abord) : chaque action fait apparaître la carte
/// suivante. Aucune navigation interne : on circule via la bottom nav bar.
/// Chaque carte propose les 5 choix du brief, sans recommandation.
class RediscoverySessionPage extends StatefulWidget {
  const RediscoverySessionPage({
    super.key,
    required this.controller,
    required this.playback,
    required this.reminders,
    required this.audioDir,
  });

  final IdeasController controller;
  final PlaybackController playback;
  final ReminderService reminders;
  final Directory audioDir;

  @override
  State<RediscoverySessionPage> createState() => _RediscoverySessionPageState();
}

class _RediscoverySessionPageState extends State<RediscoverySessionPage> {
  bool _busy = false;
  String? _error;
  bool _sawIdeas = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.playback.addListener(_onPlayback);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.playback.removeListener(_onPlayback);
    super.dispose();
  }

  void _onChanged() => setState(() {});
  void _onPlayback() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selection = RediscoveryPolicy.selectSession(
      widget.controller.ideas,
      DateTime.now().toUtc(),
    );
    if (selection.isNotEmpty) _sawIdeas = true;
    return Scaffold(
      appBar: AppBar(title: const Text('Redécouverte')),
      body: selection.isEmpty
          ? (_sawIdeas ? _summary() : _empty())
          : _card(selection.first),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Rien à redécouvrir pour le moment',
          textAlign: TextAlign.center,
          style: MurmurTextStyles.paragraph,
        ),
      ),
    );
  }

  Widget _summary() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleCheck, size: 48),
            SizedBox(height: 16),
            Text(
              'Session terminée. Vos idées sont à jour.',
              textAlign: TextAlign.center,
              style: MurmurTextStyles.paragraph,
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
              style: MurmurTextStyles.paragraph,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: MurmurTextStyles.paragraph),
            ],
            const Spacer(),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else ...[
              MurmurButton(
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.inProgress,
                    reminders: widget.reminders,
                  ),
                ),
                icon: LucideIcons.hourglass,
                label: 'Commencer à travailler dessus',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                onPressed: () => _remindLater(idea),
                icon: LucideIcons.bellRing,
                label: 'Me rappeler plus tard',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                variant: MurmurButtonVariant.outline,
                onPressed: () =>
                    _act(idea, () => widget.controller.markReviewed(idea.id)),
                icon: LucideIcons.eye,
                label: 'Garder pour plus tard',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                variant: MurmurButtonVariant.text,
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.done,
                    reminders: widget.reminders,
                  ),
                ),
                icon: LucideIcons.check,
                label: 'Marquer comme terminée',
              ),
              MurmurButton(
                variant: MurmurButtonVariant.text,
                onPressed: () => _act(
                  idea,
                  () => widget.controller.setStatus(
                    idea.id,
                    IdeaStatus.archived,
                    reminders: widget.reminders,
                  ),
                ),
                icon: LucideIcons.archive,
                label: 'Archiver',
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
        setState(() => _busy = false);
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
  }

  String _formatDate(DateTime utc) {
    final local = utc.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}
