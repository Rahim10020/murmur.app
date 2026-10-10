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
import 'motion.dart';

/// Coquille de navigation Murmur : bottom nav bar toujours visible.
///
/// Onglets ([MurmurNavTab], [IndexedStack], états conservés) : accueil,
/// découverte, paramètres. Le record est un bouton détaché à droite de la
/// pilule et ouvre la feuille de capture en modal par-dessus. Aucun bouton
/// retour dans les pages : on circule uniquement via la barre ; le retour
/// système revient à l'accueil.
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
  MurmurNavTab _tab = MurmurNavTab.home;

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
    if (id != null && _tab != MurmurNavTab.home && mounted) {
      setState(() => _tab = MurmurNavTab.home);
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
      canPop: _tab == MurmurNavTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != MurmurNavTab.home && mounted) {
          setState(() => _tab = MurmurNavTab.home);
        }
      },
      child: Scaffold(
        // Fondu entre onglets (états conservés via l'IndexedStack) ;
        // la clé force la transition à chaque changement d'onglet.
        body: AnimatedSwitcher(
          duration: MurmurMotion.scaled(context, MurmurMotion.tabSwitch),
          switchInCurve: MurmurMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: MurmurMotion.tabStartScale,
                end: 1,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: IndexedStack(
              index: _tab.index,
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
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MurmurNavBarDefaults.horizontalMargin,
              0,
              MurmurNavBarDefaults.horizontalMargin,
              MurmurNavBarDefaults.bottomMargin,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MurmurNavBar(
                  selectedIndex: _tab.index,
                  onHome: () => setState(() => _tab = MurmurNavTab.home),
                  onDiscover: () =>
                      setState(() => _tab = MurmurNavTab.discovery),
                  onSettings: () =>
                      setState(() => _tab = MurmurNavTab.settings),
                  discoveryCount: discoveryCount,
                ),
                const SizedBox(width: MurmurNavBarDefaults.recordGap),
                MurmurRecordButton(onTap: _openCaptureSheet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
