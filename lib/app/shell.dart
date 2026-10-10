import 'dart:io';

import 'package:flutter/material.dart';

import '../features/capture/presentation/capture_controller.dart';
import '../features/capture/presentation/capture_sheet.dart';
import '../features/ideas/presentation/ideas_controller.dart';
import '../features/ideas/presentation/ideas_page.dart';
import '../features/ideas/presentation/playback_controller.dart';
import '../features/rediscovery/domain/rediscovery_policy.dart';
import '../features/rediscovery/presentation/rediscovery_session.dart';
import '../features/reminders/data/flutter_reminder_service.dart';
import '../features/settings/presentation/settings_page.dart';
import '../shared/widgets/murmur_nav_bar.dart';
import 'appearance.dart';

/// Coquille de navigation Murmur : bottom nav bar toujours visible.
///
/// Onglets : 0 = idées, 1 = découverte, 2 = paramètres ([IndexedStack],
/// états conservés). Le bouton central ouvre la feuille de capture en
/// modal par-dessus. Aucun bouton retour dans les pages : on circule
/// uniquement via la barre ; le retour système revient aux idées.
class MurmurShell extends StatefulWidget {
  const MurmurShell({
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
  final ValueNotifier<String?> highlightedIdeaId;

  @override
  State<MurmurShell> createState() => _MurmurShellState();
}

class _MurmurShellState extends State<MurmurShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.highlightedIdeaId.addListener(_onHighlight);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.highlightedIdeaId.removeListener(_onHighlight);
    super.dispose();
  }

  // Le badge suit la DB : rebuild différé au prochain frame car les
  // notifications peuvent arriver pendant le build (refresh en initState).
  void _onChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onHighlight() {
    final id = widget.highlightedIdeaId.value;
    if (id != null && _tab != 0 && mounted) {
      setState(() => _tab = 0);
    }
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

  @override
  Widget build(BuildContext context) {
    final discoveryCount = RediscoveryPolicy.selectSession(
      widget.controller.ideas,
      DateTime.now().toUtc(),
    ).length;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0 && mounted) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            IdeasPage(
              controller: widget.controller,
              playback: widget.playback,
              reminders: widget.reminders,
              audioDir: widget.audioDir,
              highlightedIdeaId: widget.highlightedIdeaId,
            ),
            RediscoverySessionPage(
              controller: widget.controller,
              playback: widget.playback,
              reminders: widget.reminders,
              audioDir: widget.audioDir,
            ),
            SettingsPage(
              controller: widget.controller,
              reminders: widget.reminders,
              audioDir: widget.audioDir,
              safetyDir: widget.safetyDir,
              appearance: widget.appearance,
              onRestored: () => widget.controller.refresh(),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MurmurNavBarDefaults.horizontalMargin,
              0,
              MurmurNavBarDefaults.horizontalMargin,
              MurmurNavBarDefaults.bottomMargin,
            ),
            child: MurmurNavBar(
              onDiscover: () => setState(() => _tab = 1),
              onRecord: _openCaptureSheet,
              onSettings: () => setState(() => _tab = 2),
              discoveryCount: discoveryCount,
            ),
          ),
        ),
      ),
    );
  }
}
