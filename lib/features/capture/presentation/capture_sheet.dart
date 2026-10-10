import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../ideas/presentation/idea_display.dart';
import 'capture_controller.dart';

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

  // Rebuild différé : voir IdeasPage._onChanged (transitions d'onglet).
  void _onChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

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
