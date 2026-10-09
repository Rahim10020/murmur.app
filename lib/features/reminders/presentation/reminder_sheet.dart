import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/text_styles.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../ideas/domain/idea.dart';
import '../../ideas/presentation/idea_display.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../data/flutter_reminder_service.dart';
import '../domain/reminder_policy.dart';

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
            const Text('Me rappeler', style: MurmurTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(
              widget.idea.reminderAtUtc == null
                  ? 'Aucun rappel pour cette idée.'
                  : 'Rappel actuel : ${formatReminder(widget.idea.reminderAtUtc!)}.',
              style: MurmurTextStyles.paragraph,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: MurmurTextStyles.paragraph),
            ],
            if (_permissionDenied) ...[
              const SizedBox(height: 8),
              const Text(
                'Notifications non autorisées : les rappels ne pourront pas '
                's’afficher tant que l’autorisation n’est pas accordée dans '
                'les réglages Android.',
                style: MurmurTextStyles.paragraph,
              ),
            ],
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else ...[
              MurmurButton(
                onPressed: laterToday == null
                    ? null
                    : () => _schedule(laterToday),
                icon: LucideIcons.moon,
                label: 'Plus tard aujourd’hui (20h00)',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                onPressed: () => _schedule(tomorrow),
                icon: LucideIcons.sunrise,
                label: 'Demain (9h00)',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                onPressed: () => _schedule(nextWeek),
                icon: LucideIcons.calendarClock,
                label: 'Semaine prochaine',
              ),
              const SizedBox(height: 8),
              MurmurButton(
                variant: MurmurButtonVariant.outline,
                onPressed: _pickCustom,
                icon: LucideIcons.calendarPlus,
                label: 'Choisir une date…',
              ),
              if (widget.idea.reminderAtUtc != null) ...[
                const SizedBox(height: 8),
                MurmurButton(
                  variant: MurmurButtonVariant.text,
                  onPressed: _cancel,
                  icon: LucideIcons.bellOff,
                  label: 'Annuler le rappel',
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
