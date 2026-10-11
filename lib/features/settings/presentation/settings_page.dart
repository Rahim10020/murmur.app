import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../app/appearance.dart';
import '../../../app/text_styles.dart';
import '../../../l10n/app_locale.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/locale_controller.dart';
import '../../../l10n/strings_scope.dart';
import '../../../shared/widgets/murmur_button.dart';
import '../../backup/data/backup_service.dart';
import '../../backup/domain/backup_manifest.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../../reminders/data/flutter_reminder_service.dart';

String formatBytes(int bytes, [AppStrings? strings]) =>
    (strings ?? const FrStrings()).formatBytes(bytes);

/// Paramètres : langue, apparence, sauvegarde locale export/restauration.
///
/// Les archives sont choisies par l'utilisateur via le sélecteur système
/// (aucune permission de stockage large). Murmur ne téléverse rien :
/// les sauvegardes restent là où l'utilisateur les enregistre.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.reminders,
    required this.audioDir,
    required this.safetyDir,
    required this.appearance,
    required this.locale,
    required this.onRestored,
  });

  final IdeasController controller;
  final ReminderService reminders;
  final Directory audioDir;
  final Directory safetyDir;
  final AppearanceController appearance;
  final LocaleController locale;
  final Future<void> Function() onRestored;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const BackupService _backups = BackupService();

  bool _busy = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final strings = StringsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(strings.languageSection, style: MurmurTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.locale,
            builder: (context, _) => SegmentedButton<AppLocale>(
              segments: [
                ButtonSegment<AppLocale>(
                  value: AppLocale.system,
                  icon: const Icon(LucideIcons.languages),
                  label: Text(strings.langSystem),
                ),
                ButtonSegment<AppLocale>(
                  value: AppLocale.french,
                  label: Text(strings.langFrench),
                ),
                ButtonSegment<AppLocale>(
                  value: AppLocale.english,
                  label: Text(strings.langEnglish),
                ),
              ],
              selected: {widget.locale.locale},
              onSelectionChanged: (selection) =>
                  widget.locale.setLocale(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(strings.appearanceSection, style: MurmurTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.appearance,
            builder: (context, _) => SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: const Icon(LucideIcons.monitorSmartphone),
                  label: Text(strings.themeSystem),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: const Icon(LucideIcons.sun),
                  label: Text(strings.themeLight),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: const Icon(LucideIcons.moon),
                  label: Text(strings.themeDark),
                ),
              ],
              selected: {widget.appearance.mode},
              onSelectionChanged: (selection) =>
                  widget.appearance.setMode(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(strings.backupSection, style: MurmurTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text(
            strings.backupDescription,
            style: MurmurTextStyles.paragraph,
          ),
          const SizedBox(height: 16),
          MurmurButton(
            onPressed: _busy ? null : _export,
            icon: LucideIcons.download,
            label: strings.exportBackup,
          ),
          const SizedBox(height: 8),
          MurmurButton(
            variant: MurmurButtonVariant.outline,
            onPressed: _busy ? null : _restore,
            icon: LucideIcons.upload,
            label: strings.restoreBackup,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status, style: MurmurTextStyles.paragraph),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    final strings = StringsScope.of(context);
    setState(() {
      _busy = true;
      _status = strings.preparingArchive;
    });
    try {
      final ideas = widget.controller.ideas;
      if (ideas.isEmpty) {
        setState(() {
          _busy = false;
          _status = strings.nothingToExport;
        });
        return;
      }
      final bytes = await _backups.createArchive(
        ideas: ideas,
        audioDir: widget.audioDir,
      );
      final uri = await FilePicker.saveFile(
        dialogTitle: strings.saveBackupDialogTitle,
        fileName: suggestedBackupFileName(DateTime.now()),
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = uri == null
            ? strings.exportCancelled
            : strings.exportSaved(formatBytes(bytes.length, strings));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '${StringsScope.of(context).exportFailedPrefix} : $e';
      });
    }
  }

  Future<void> _restore() async {
    final strings = StringsScope.of(context);
    setState(() {
      _busy = true;
      _status = strings.chooseBackup;
    });
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: strings.pickBackupDialogTitle,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = StringsScope.of(context).restoreCancelled;
        });
        return;
      }
      final Uint8List bytes = await picked.readAsBytes();
      final preview = await _backups.inspectArchive(bytes);
      if (!mounted) return;
      final confirmed = await _confirmReplace(preview);
      if (confirmed != true) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = StringsScope.of(context).restoreCancelledUnchanged;
        });
        return;
      }
      setState(() => _status = StringsScope.of(context).safetyBackup);
      await _backups.createSafetyBackup(
        ideas: widget.controller.ideas,
        audioDir: widget.audioDir,
        safetyDir: widget.safetyDir,
      );
      setState(() => _status = StringsScope.of(context).restoring);
      final staging = await Directory.systemTemp.createTemp('murmur-restore-');
      try {
        final report = await _backups.restoreArchive(
          bytes: bytes,
          replaceIdeas: widget.controller.replaceAll,
          audioDir: widget.audioDir,
          stagingDir: staging,
          reminders: widget.reminders,
        );
        await widget.onRestored();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = '';
        });
        await _showReport(report);
      } finally {
        try {
          if (await staging.exists()) {
            await staging.delete(recursive: true);
          }
        } catch (_) {}
      }
    } on BackupValidationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = StringsScope.of(context).restoreRefused(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = StringsScope.of(context).restoreFailed(e);
      });
    }
  }

  Future<bool?> _confirmReplace(BackupPreview preview) {
    final strings = StringsScope.of(context);
    final exported = preview.exportedAtUtc.toLocal();
    final date = strings.isFrench
        ? '${exported.day}/${exported.month}/${exported.year}'
        : '${exported.month}/${exported.day}/${exported.year}';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.replaceDataTitle),
        content: Text(
          strings.replaceDataBody(
            date,
            preview.ideaCount,
            formatBytes(preview.totalAudioBytes, strings),
          ),
          style: MurmurTextStyles.paragraph,
        ),
        actions: [
          MurmurButton(
            variant: MurmurButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
            label: strings.keepMyData,
          ),
          MurmurButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: strings.replace,
          ),
        ],
      ),
    );
  }

  Future<void> _showReport(RestoreReport report) {
    final strings = StringsScope.of(context);
    final buffer = StringBuffer(
      strings.restoreReport(
        report.restoredCount,
        report.rescheduledCount,
        report.skippedPastCount,
      ),
    );
    if (report.schedulingErrors.isNotEmpty) {
      buffer.write(
        '\n\n${strings.rescheduleImpossiblePrefix}\n'
        '${report.schedulingErrors.take(3).join('\n')}',
      );
    }
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.restoreDoneTitle),
        content: Text(buffer.toString(), style: MurmurTextStyles.paragraph),
        actions: [
          MurmurButton(
            onPressed: () => Navigator.of(context).pop(),
            label: strings.ok,
          ),
        ],
      ),
    );
  }
}
