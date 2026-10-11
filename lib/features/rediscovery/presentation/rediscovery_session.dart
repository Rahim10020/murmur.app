import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../l10n/strings_scope.dart';
import '../../ideas/presentation/idea_display.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../../ideas/presentation/playback_controller.dart';
import '../domain/rediscovery_policy.dart';

/// Onglet de redécouverte hebdo : liste simple des idées éligibles.
///
/// Sélection déterministe (plus anciennes éligibles d'abord, au plus 3),
/// aucune recommandation. Chaque ligne propose le titre et la lecture ;
/// volontairement sans actions (statuts, rappels) : on circule via la
/// bottom nav bar et on agit depuis la liste des idées.
class RediscoverySessionPage extends StatefulWidget {
  const RediscoverySessionPage({
    super.key,
    required this.controller,
    required this.playback,
    required this.audioDir,
  });

  final IdeasController controller;
  final PlaybackController playback;
  final Directory audioDir;

  @override
  State<RediscoverySessionPage> createState() => _RediscoverySessionPageState();
}

class _RediscoverySessionPageState extends State<RediscoverySessionPage> {
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

  // Rebuild différé : voir IdeasPage (transitions d'onglet).
  void _onChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPlayback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = StringsScope.of(context);
    final selection = RediscoveryPolicy.selectSession(
      widget.controller.ideas,
      DateTime.now().toUtc(),
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.rediscoveryTitle)),
      body: selection.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  strings.rediscoveryEmpty,
                  textAlign: TextAlign.center,
                  style: MurmurTextStyles.paragraph,
                ),
              ),
            )
          : ListView.builder(
              itemCount: selection.length,
              itemBuilder: (context, index) {
                final idea = selection[index];
                final audioPath =
                    '${widget.audioDir.path}/${idea.audioFileName}';
                final playing = widget.playback.isPlaying(idea.id);
                final loading =
                    widget.playback.state == PlaybackState.loading &&
                    widget.playback.currentIdeaId == idea.id;
                return ListTile(
                  leading: loading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: playing ? strings.pause : strings.play,
                          icon: Icon(
                            playing ? LucideIcons.pause : LucideIcons.play,
                          ),
                          onPressed: () =>
                              widget.playback.toggle(idea, audioPath),
                        ),
                  title: Text(fallbackTitle(idea, strings)),
                  subtitle: Text(
                    '${strings.recordedOn(_formatDate(idea.createdAtUtc, strings.isFrench))} • '
                    '${formatDuration(Duration(milliseconds: idea.durationMs))}',
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime utc, bool french) {
    final local = utc.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    if (french) return '$day/$month/${local.year}';
    return '$month/$day/${local.year}';
  }
}
