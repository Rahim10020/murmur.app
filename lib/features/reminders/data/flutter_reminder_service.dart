import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_policy.dart';

/// Service de rappels derrière une abstraction (brief §4) :
/// la logique métier ne dépend que de cette interface.
abstract class ReminderService {
  /// Initialise le plugin + fuseau horaire. À appeler une fois au démarrage.
  Future<void> init();

  /// Demande la permission de notification. `true` si accordée.
  /// En cas de refus, l'app reste utilisable (rappels expliqués, pas bloqués).
  Future<bool> requestPermission();

  /// Planifie (ou remplace) le rappel d'une idée. [whenUtc] doit être futur.
  Future<void> scheduleReminder({
    required String ideaId,
    required DateTime whenUtc,
  });

  /// Annule le rappel d'une idée (sans effet s'il n'existe pas).
  Future<void> cancelReminder(String ideaId);

  /// IDs de notification actuellement planifiés côté OS.
  Future<Set<int>> pendingNotificationIds();

  /// Réconcilie la planification OS avec la vérité DB.
  ///
  /// [futureByIdea] associe chaque ID d'idée à son rappel futur (UTC).
  /// Annule les planifications orphelines/passées et (re)planifie les
  /// rappels futurs manquants. Les rappels passés ne sont jamais
  /// replanifiés : ils sont simplement annulés côté OS.
  Future<void> reconcile(Map<String, DateTime> futureByIdea);

  /// Payload (ID d'idée) si l'app a été lancée via une notification,
  /// `null` sinon. Gère le cold start.
  Future<String?> initialNotificationIdeaId();

  /// Taps sur notification pendant que l'app tourne (ou en fond).
  Stream<String?> get onNotificationTap;

  Future<void> dispose();
}

class FlutterReminderService implements ReminderService {
  FlutterReminderService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();
  bool _initialized = false;

  @override
  Stream<String?> get onNotificationTap => _tapController.stream;

  @override
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _tapController.add(response.payload);
      },
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    // `null` = plateforme sans permission d'exécution (accordée par défaut).
    return granted ?? true;
  }

  @override
  Future<void> scheduleReminder({
    required String ideaId,
    required DateTime whenUtc,
  }) async {
    if (!whenUtc.isUtc) {
      throw ArgumentError('Le rappel doit être exprimé en UTC.');
    }
    final nowUtc = DateTime.now().toUtc();
    if (!whenUtc.isAfter(nowUtc)) {
      throw ArgumentError.value(
        whenUtc,
        'whenUtc',
        'Le rappel doit être dans le futur.',
      );
    }
    const androidDetails = AndroidNotificationDetails(
      ReminderPolicy.channelId,
      ReminderPolicy.channelName,
      channelDescription: ReminderPolicy.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.zonedSchedule(
      id: ReminderPolicy.notificationIdFor(ideaId),
      scheduledDate: tz.TZDateTime.from(whenUtc, tz.local),
      notificationDetails: details,
      // Inexact par choix (brief §3) : pas d'alarme exacte, pas de
      // permission SCHEDULE_EXACT_ALARM. Livraison non garantie à la minute.
      androidScheduleMode: AndroidScheduleMode.inexact,
      title: ReminderPolicy.notificationTitle,
      body: ReminderPolicy.notificationBody,
      payload: ideaId,
    );
  }

  @override
  Future<void> cancelReminder(String ideaId) {
    return _plugin.cancel(id: ReminderPolicy.notificationIdFor(ideaId));
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((e) => e.id).toSet();
  }

  @override
  Future<void> reconcile(Map<String, DateTime> futureByIdea) async {
    final nowUtc = DateTime.now().toUtc();
    final wanted = <String, int>{};
    for (final entry in futureByIdea.entries) {
      final when = entry.value;
      if (!when.isUtc) continue;
      if (!when.isAfter(nowUtc)) continue;
      wanted[entry.key] = ReminderPolicy.notificationIdFor(entry.key);
    }
    final pending = await pendingNotificationIds();
    final plan = ReminderReconciliation.plan(
      pendingIds: pending,
      futureByIdea: wanted,
    );
    for (final id in plan.toCancel) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {
        // Best-effort : un reliquat OS ne bloque pas le démarrage.
      }
    }
    for (final entry in wanted.entries) {
      if (!plan.toSchedule.contains(entry.value)) continue;
      try {
        await scheduleReminder(
          ideaId: entry.key,
          whenUtc: futureByIdea[entry.key]!,
        );
      } catch (_) {
        // Best-effort : l'utilisateur pourra replanifier depuis la fiche.
      }
    }
  }

  @override
  Future<String?> initialNotificationIdeaId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<void> dispose() async {
    await _tapController.close();
  }
}
