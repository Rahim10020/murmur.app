import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../features/reminders/data/flutter_reminder_service.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../l10n/strings_scope.dart';
import 'appearance.dart';
import 'bootstrap.dart';
import 'onboarding.dart';
import 'shell.dart';
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
  late final OnboardingController _onboarding = OnboardingController();
  late final LocaleController _locale = LocaleController();
  String? _error;
  AppStrings _strings = const FrStrings();

  @override
  void initState() {
    super.initState();
    _appearance.load();
    _onboarding.load();
    _locale.load().then((_) => _applyStrings());
    _locale.addListener(_onLocaleChanged);
    _bootstrap();
  }

  /// Pousse les chaînes effectives vers les contrôleurs/services (messages
  /// d'erreur localisés) et replanifie les rappels futurs pour que les
  /// notifications adoptent la nouvelle langue.
  void _applyStrings() {
    final systemTag = PlatformDispatcher.instance.locale.toLanguageTag();
    _strings = _locale.stringsFor(systemTag);
    final scope = _scope;
    if (scope != null) {
      scope.ideas.setStrings(_strings);
      scope.playback.setStrings(_strings);
      scope.capture.setStrings(_strings);
      scope.recordingService.setStrings(_strings);
      final reminders = scope.reminders;
      if (reminders is FlutterReminderService) {
        reminders.setStrings(_strings);
      }
      _reconcileReminders();
    }
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() => _applyStrings();

  Future<void> _reconcileReminders() async {
    final scope = _scope;
    final reminders = scope?.reminders;
    if (scope == null || reminders == null) return;
    try {
      final nowUtc = DateTime.now().toUtc();
      final future = <String, DateTime>{};
      for (final idea in scope.ideas.ideas) {
        final reminder = idea.reminderAtUtc;
        if (reminder != null && reminder.isAfter(nowUtc)) {
          future[idea.id] = reminder;
        }
      }
      await reminders.reconcile(future);
    } catch (_) {
      // Best-effort : la langue reste appliquée même si la
      // replanification échoue.
    }
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
      _applyStrings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _strings.bootstrapFailed(e));
    }
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    _tapSubscription?.cancel();
    _scope?.dispose();
    _highlightedIdeaId.dispose();
    _appearance.dispose();
    _onboarding.dispose();
    _locale.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() => _onboarding.complete();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_appearance, _onboarding, _locale]),
      builder: (context, _) {
        final systemTag = PlatformDispatcher.instance.locale.toLanguageTag();
        final strings = _locale.stringsFor(systemTag);
        _strings = strings;
        return StringsScope(
          strings: strings,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: strings.appTitle,
            theme: MurmurTheme.light(),
            darkTheme: MurmurTheme.dark(),
            themeMode: _appearance.mode,
            home: _error != null
                ? Scaffold(
                    appBar: AppBar(title: Text(strings.appTitle)),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ),
                  )
                : _scope == null
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : _onboarding.done
                ? MurmurShell(
                    controller: _scope!.ideas,
                    capture: _scope!.capture,
                    playback: _scope!.playback,
                    reminders: _scope!.reminders ?? _DisabledReminderService(strings),
                    audioDir: _scope!.audioDir,
                    safetyDir: _scope!.safetyDir,
                    appearance: _appearance,
                    locale: _locale,
                    highlightedIdeaId: _highlightedIdeaId,
                  )
                : OnboardingPage(onDone: _finishOnboarding),
          ),
        );
      },
    );
  }
}

/// Secours si le plugin de rappels est indisponible : les opérations
/// rappels échouent avec un message clair au lieu de crasher.
class _DisabledReminderService implements ReminderService {
  _DisabledReminderService(this._strings);

  final AppStrings _strings;
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
    throw StateError(_strings.remindersUnavailable);
  }
}
