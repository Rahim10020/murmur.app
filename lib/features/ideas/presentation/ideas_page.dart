import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/appearance.dart';
import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../../shared/widgets/murmur_menu.dart';
import '../../capture/presentation/capture_controller.dart';
import '../../rediscovery/presentation/rediscovery_session.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/presentation/reminder_sheet.dart';
import '../../settings/presentation/settings_page.dart';
import '../domain/idea.dart';
import 'idea_display.dart';
import 'ideas_controller.dart';
import 'playback_controller.dart';

/// Écran liste des idées : lecture, rappels, statuts, capture.
class IdeasPage extends StatefulWidget {
  const IdeasPage({
    super.key,
    required this.controller,
    required this.capture,
    required this.playback,
    required this.reminders,
    required this.audioDir,
    required this.safetyDir,
    required this.appearance,
    required this.highlightedIdeaId,
  });

  final IdeasController controller;
  final CaptureController capture;
  final PlaybackController playback;
  final ReminderService reminders;
  final Directory audioDir;
  final Directory safetyDir;
  final AppearanceController appearance;

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
      appBar: AppBar(
        title: const Text('Murmur'),
        actions: [
          IconButton(
            tooltip: 'Redécouvrir des idées',
            icon: const Icon(LucideIcons.history),
            onPressed: () => openRediscoverySession(
              context: context,
              controller: widget.controller,
              playback: widget.playback,
              reminders: widget.reminders,
              audioDir: widget.audioDir,
            ),
          ),
          IconButton(
            tooltip: 'Paramètres et sauvegarde',
            icon: const Icon(LucideIcons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(
                    controller: widget.controller,
                    reminders: widget.reminders,
                    audioDir: widget.audioDir,
                    safetyDir: widget.safetyDir,
                    appearance: widget.appearance,
                    onRestored: () => widget.controller.refresh(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                  style: MurmurTextStyles.paragraph,
                ),
                const SizedBox(height: 16),
                MurmurButton(onPressed: controller.refresh, label: 'Réessayer'),
              ],
            ),
          ),
        ),
        IdeasListState.loaded =>
          controller.ideas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(54),
                    child: Text(
                      'Aucune idée pour le moment.\nAppuyez sur le micro pour capturer votre première idée.',
                      textAlign: TextAlign.center,
                      style: MurmurTextStyles.paragraph,
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
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: _openCaptureSheet,
          tooltip: 'Enregistrer une idée',
          child: const Icon(
            LucideIcons.mic,
            size: 32,
          ), // à ajuster en proportion
        ),
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
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Annuler',
          ),
          MurmurButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            label: 'Enregistrer',
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
          style: MurmurTextStyles.paragraph,
        ),
        actions: [
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Garder',
          ),
          MurmurButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Supprimer',
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
              Text(_headline(capture.state), style: MurmurTextStyles.paragraph),
              if (capture.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  capture.errorMessage!,
                  textAlign: TextAlign.center,
                  style: MurmurTextStyles.paragraph,
                ),
              ],
              const SizedBox(height: 24),
              _actions(context, capture),
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

  Widget _actions(BuildContext context, CaptureController capture) {
    switch (capture.state) {
      case CaptureState.recording:
        return Row(
          children: [
            Expanded(
              child: MurmurButton(
                onPressed: () async {
                  await capture.stopAndSave();
                  await widget.onSaved();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: LucideIcons.square,
                label: 'Arrêter et garder',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MurmurButton(
                variant: MurmurButtonVariant.secondary,
                onPressed: () async {
                  final abandon = await _confirmAbandon();
                  if (abandon != true) return;
                  await capture.discard();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: LucideIcons.x,
                label: 'Abandonner',
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
              style: MurmurTextStyles.paragraph,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MurmurButton(
                    onPressed: () => capture.start(),
                    icon: LucideIcons.mic,
                    label: 'Réessayer',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MurmurButton(
                    variant: MurmurButtonVariant.secondary,
                    onPressed: () {
                      capture.reset();
                      Navigator.of(context).pop();
                    },
                    label: 'Fermer',
                  ),
                ),
              ],
            ),
          ],
        );
      case CaptureState.error:
      case CaptureState.idle:
        return MurmurButton(
          onPressed: () {
            capture.reset();
            Navigator.of(context).pop();
          },
          label: 'Fermer',
        );
    }
  }

  Future<bool?> _confirmAbandon() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner l’enregistrement ?'),
        content: const Text(
          'L’audio en cours sera définitivement perdu.',
          style: MurmurTextStyles.paragraph,
        ),
        actions: [
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Continuer',
          ),
          MurmurButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: 'Abandonner',
          ),
        ],
      ),
    );
  }
}
