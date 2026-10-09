import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/theme.dart';
import '../../capture/presentation/capture_controller.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/domain/reminder_policy.dart';
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

/// Écran liste des idées : lecture, rappels, statuts, capture.
class IdeasPage extends StatefulWidget {
  const IdeasPage({
    super.key,
    required this.controller,
    required this.capture,
    required this.playback,
    required this.reminders,
    required this.audioDir,
    required this.highlightedIdeaId,
  });

  final IdeasController controller;
  final CaptureController capture;
  final PlaybackController playback;
  final ReminderService reminders;
  final Directory audioDir;

  /// ID d'idée à mettre en avant (deep-link depuis une notification).
  final ValueNotifier<String?> highlightedIdeaId;

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.capture.addListener(_onChanged);
    widget.playback.addListener(_onChanged);
    widget.highlightedIdeaId.addListener(_onHighlight);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.capture.removeListener(_onChanged);
    widget.playback.removeListener(_onChanged);
    widget.highlightedIdeaId.removeListener(_onHighlight);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onHighlight() {
    _revealHighlight(0);
  }

  void _revealHighlight(int attempt) {
    final id = widget.highlightedIdeaId.value;
    if (id == null) {
      setState(() {});
      return;
    }
    setState(() {});
    // Laisse la liste se reconstruire avant le défilement.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final key = _tileKeys[id];
      if (key?.currentContext != null) {
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
        );
      } else if (attempt < 3 &&
          widget.controller.state != IdeasListState.loaded) {
        // La liste charge encore (cold start) : on réessaie.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _revealHighlight(attempt + 1);
      } else if (mounted) {
        _snack('Idée introuvable : elle a peut-être été supprimée.');
      }
    });
  }

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
                    final idea = controller.ideas[index];
                    final key = _tileKeys.putIfAbsent(
                      idea.id,
                      () => GlobalKey(),
                    );
                    return _IdeaTile(
                      key: key,
                      idea: idea,
                      highlighted: widget.highlightedIdeaId.value == idea.id,
                      playback: widget.playback,
                      audioDir: widget.audioDir,
                      onRename: _rename,
                      onStatus: _setStatus,
                      onDelete: _delete,
                      onRemind: _remind,
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
      await widget.controller.setStatus(
        idea.id,
        status,
        reminders: widget.reminders,
      );
    } catch (e) {
      _snack('Changement de statut impossible : $e');
    }
  }

  Future<void> _remind(Idea idea) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ReminderSheet(
        idea: idea,
        controller: widget.controller,
        reminders: widget.reminders,
      ),
    );
    if (mounted) setState(() {});
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
      await widget.controller.deleteIdea(
        idea,
        widget.audioDir,
        reminders: widget.reminders,
      );
      widget.highlightedIdeaId.value = null;
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
              PopupMenuButton<String>(
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
                itemBuilder: (context) => [
                  _menuItem(
                    value: 'rename',
                    icon: LucideIcons.pencil,
                    label: 'Renommer',
                  ),
                  _menuItem(
                    value: 'inProgress',
                    icon: LucideIcons.hourglass,
                    label: 'Commencer',
                  ),
                  _menuItem(
                    value: 'done',
                    icon: LucideIcons.check,
                    label: 'Marquer terminée',
                  ),
                  _menuItem(
                    value: 'archive',
                    icon: LucideIcons.archive,
                    label: 'Archiver',
                  ),
                  _menuItem(
                    value: 'review',
                    icon: LucideIcons.rotateCcw,
                    label: 'Remettre à revoir',
                  ),
                  _menuItem(
                    value: 'delete',
                    icon: LucideIcons.trash,
                    label: 'Supprimer',
                  ),
                ],
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
      buffer.write(' \u2022 ${_formatReminder(idea.reminderAtUtc!)}');
    }
    if (playback.state == PlaybackState.error &&
        playback.currentIdeaId == idea.id) {
      buffer.write(' \u2022 Erreur lecture');
    }
    return buffer.toString();
  }
}

String _formatReminder(DateTime reminderAtUtc) {
  final local = reminderAtUtc.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Rappel le $day/$month à $hour:$minute';
}

PopupMenuItem<String> _menuItem({
  required String value,
  required IconData icon,
  required String label,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]),
  );
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

/// Panneau de rappel : presets simples + date personnalisée (brief §3).
///
/// La date choisie est validée comme future ; la permission de notification
/// est demandée au moment du choix, avec explication en cas de refus.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({
    super.key,
    required this.idea,
    required this.controller,
    required this.reminders,
  });

  final Idea idea;
  final IdeasController controller;
  final ReminderService reminders;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  bool _saving = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final nowLocal = DateTime.now();
    final laterToday = ReminderPolicy.laterToday(nowLocal);
    final tomorrow = ReminderPolicy.tomorrow(nowLocal);
    final nextWeek = ReminderPolicy.nextWeek(nowLocal);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Me rappeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.idea.reminderAtUtc == null
                  ? 'Aucun rappel pour cette idée.'
                  : 'Rappel actuel : ${_formatReminder(widget.idea.reminderAtUtc!)}.',
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!)],
            if (_permissionDenied) ...[
              const SizedBox(height: 8),
              const Text(
                'Notifications non autorisées : les rappels ne pourront pas '
                's’afficher tant que l’autorisation n’est pas accordée dans '
                'les réglages Android.',
              ),
            ],
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(
                onPressed: laterToday == null
                    ? null
                    : () => _schedule(laterToday),
                icon: const Icon(LucideIcons.moon),
                label: const Text('Plus tard aujourd’hui (20h00)'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _schedule(tomorrow),
                icon: const Icon(LucideIcons.sunrise),
                label: const Text('Demain (9h00)'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _schedule(nextWeek),
                icon: const Icon(LucideIcons.calendarClock),
                label: const Text('Semaine prochaine'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickCustom,
                icon: const Icon(LucideIcons.calendarPlus),
                label: const Text('Choisir une date…'),
              ),
              if (widget.idea.reminderAtUtc != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(LucideIcons.bellOff),
                  label: const Text('Annuler le rappel'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _schedule(DateTime whenLocal) async {
    setState(() {
      _saving = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      ReminderPolicy.validateFuture(whenLocal, DateTime.now());
      final granted = await widget.reminders.requestPermission();
      if (!granted) {
        setState(() {
          _saving = false;
          _permissionDenied = true;
        });
        return;
      }
      await widget.controller.setReminder(
        widget.idea.id,
        whenLocal.toUtc(),
        widget.reminders,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    await _schedule(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _cancel() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.clearReminder(widget.idea.id, widget.reminders);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
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
