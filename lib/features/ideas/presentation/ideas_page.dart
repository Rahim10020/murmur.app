import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../reminders/data/flutter_reminder_service.dart';
import '../../reminders/presentation/reminder_sheet.dart';
import '../domain/idea.dart';
import 'idea_tile.dart';
import 'ideas_controller.dart';
import 'playback_controller.dart';

/// Onglet liste des idées : lecture, rappels, statuts.
/// La navigation (bottom bar persistante) vit dans le shell.
class IdeasPage extends StatefulWidget {
  const IdeasPage({
    super.key,
    required this.controller,
    required this.playback,
    required this.reminders,
    required this.audioDir,
    required this.highlightedIdeaId,
  });

  final IdeasController controller;
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
    widget.playback.addListener(_onChanged);
    widget.highlightedIdeaId.addListener(_onHighlight);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.playback.removeListener(_onChanged);
    widget.highlightedIdeaId.removeListener(_onHighlight);
    super.dispose();
  }

  // Rebuild différé : plusieurs écrans peuvent écouter pendant une
  // transition d'onglet (AnimatedSwitcher), où un setState immédiat
  // pendant le build est interdit.
  void _onChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealHighlight(0);
    });
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.audioLines,
                          size: 88,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune idée pour le moment',
                          textAlign: TextAlign.center,
                          style: MurmurTextStyles.caption,
                        ),
                      ],
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
                    return IdeaTile(
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
