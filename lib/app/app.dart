import 'dart:async';

import 'package:flutter/material.dart';

import '../features/ideas/presentation/ideas_page.dart';
import '../features/reminders/data/flutter_reminder_service.dart';
import 'appearance.dart';
import 'bootstrap.dart';
import 'theme.dart';

/// Racine applicative Murmur : assemble le périmètre initialisé par
/// [bootstrapApp]. Les erreurs de démarrage sont affichées plutôt que
/// masquées (brief §5).
class MurmurApp extends StatefulWidget {
  const MurmurApp({super.key});

  @override
  State<MurmurApp> createState() => _MurmurAppState();
}

class _MurmurAppState extends State<MurmurApp> {
  AppScope? _scope;
  StreamSubscription<String?>? _tapSubscription;
  final ValueNotifier<String?> _highlightedIdeaId = ValueNotifier(null);
  late final AppearanceController _appearance = AppearanceController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _appearance.load();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final scope = await bootstrapApp();
      if (!mounted) {
        await scope.dispose();
        return;
      }
      final tapSub = scope.reminders?.onNotificationTap.listen((ideaId) {
        if (ideaId != null) _highlightedIdeaId.value = ideaId;
      });
      setState(() {
        _scope = scope;
        _tapSubscription = tapSub;
        if (scope.initialIdeaId != null) {
          _highlightedIdeaId.value = scope.initialIdeaId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de démarrer Murmur : $e');
    }
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    _scope?.dispose();
    _highlightedIdeaId.dispose();
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appearance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Murmur',
        theme: MurmurTheme.light(),
        darkTheme: MurmurTheme.dark(),
        themeMode: _appearance.mode,
        home: _error != null
            ? Scaffold(
                appBar: AppBar(title: const Text('Murmur')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                ),
              )
            : _scope == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : IdeasPage(
                controller: _scope!.ideas,
                capture: _scope!.capture,
                playback: _scope!.playback,
                reminders: _scope!.reminders ?? _DisabledReminderService(),
                audioDir: _scope!.audioDir,
                safetyDir: _scope!.safetyDir,
                appearance: _appearance,
                highlightedIdeaId: _highlightedIdeaId,
              ),
      ),
    );
  }
}

/// Secours si le plugin de rappels est indisponible : les opérations
/// rappels échouent avec un message clair au lieu de crasher.
class _DisabledReminderService implements ReminderService {
  @override
  Future<void> cancelReminder(String ideaId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> init() async {}

  @override
  Future<String?> initialNotificationIdeaId() async => null;

  @override
  Stream<String?> get onNotificationTap => const Stream.empty();

  @override
  Future<Set<int>> pendingNotificationIds() async => <int>{};

  @override
  Future<void> reconcile(Map<String, DateTime> futureByIdea) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleReminder({
    required String ideaId,
    required DateTime whenUtc,
  }) async {
    throw StateError(
      'Les rappels sont indisponibles sur cet appareil pour le moment.',
    );
  }
}
