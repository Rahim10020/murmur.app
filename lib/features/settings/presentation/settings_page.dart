import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../backup/data/backup_service.dart';
import '../../backup/domain/backup_manifest.dart';
import '../../ideas/presentation/ideas_controller.dart';
import '../../reminders/data/flutter_reminder_service.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} Ko';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} Mo';
}

/// Paramètres : sauvegarde locale export/restauration (brief §3).
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
    required this.onRestored,
  });

  final IdeasController controller;
  final ReminderService reminders;
  final Directory audioDir;
  final Directory safetyDir;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Sauvegarde locale',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Une archive ZIP contient toutes vos idées et leurs audios. '
            'Elle est enregistrée là où vous choisissez (Téléchargements, '
            'carte SD, clé USB…) : Murmur ne la téléverse nulle part.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(LucideIcons.download),
            label: const Text('Exporter une sauvegarde'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(LucideIcons.upload),
            label: const Text('Restaurer une sauvegarde'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = 'Préparation de l’archive…';
    });
    try {
      final ideas = widget.controller.ideas;
      if (ideas.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'Rien à exporter : aucune idée enregistrée.';
        });
        return;
      }
      final bytes = await _backups.createArchive(
        ideas: ideas,
        audioDir: widget.audioDir,
      );
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde Murmur',
        fileName: suggestedBackupFileName(DateTime.now()),
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = uri == null
            ? 'Export annulé.'
            : 'Sauvegarde enregistrée (${formatBytes(bytes.length)}). '
                  'Pensez à la copier ailleurs : Murmur ne la conserve pas '
                  'en cas de désinstallation.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Export impossible : $e';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _status = 'Choisissez une sauvegarde…';
    });
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choisir une sauvegarde Murmur',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = 'Restauration annulée.';
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
          _status = 'Restauration annulée : vos données sont inchangées.';
        });
        return;
      }
      setState(() => _status = 'Sauvegarde de sécurité…');
      await _backups.createSafetyBackup(
        ideas: widget.controller.ideas,
        audioDir: widget.audioDir,
        safetyDir: widget.safetyDir,
      );
      setState(() => _status = 'Restauration en cours…');
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
        _status =
            'Restauration refusée : ${e.message} Vos données sont inchangées.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Restauration impossible : $e';
      });
    }
  }

  Future<bool?> _confirmReplace(BackupPreview preview) {
    final exported = preview.exportedAtUtc.toLocal();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remplacer les données actuelles ?'),
        content: Text(
          'Sauvegarde du ${exported.day}/${exported.month}/${exported.year} : '
          '${preview.ideaCount} idée(s), ${formatBytes(preview.totalAudioBytes)}.\n\n'
          'Vos idées actuelles seront remplacées (une copie de sécurité '
          'automatique est conservée dans l’app avant remplacement). '
          'Les rappels passés ne seront pas replanifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder mes données'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReport(RestoreReport report) {
    final buffer = StringBuffer(
      '${report.restoredCount} idée(s) restaurée(s).\n'
      '${report.rescheduledCount} rappel(s) futur(s) replanifié(s), '
      '${report.skippedPastCount} passé(s) ignoré(s).',
    );
    if (report.schedulingErrors.isNotEmpty) {
      buffer.write(
        '\n\nReplanification impossible pour :\n'
        '${report.schedulingErrors.take(3).join('\n')}',
      );
    }
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restauration terminée'),
        content: Text(buffer.toString()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
