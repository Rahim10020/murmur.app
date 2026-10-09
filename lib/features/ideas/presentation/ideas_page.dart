import 'package:flutter/material.dart';

import '../domain/idea.dart';
import 'ideas_controller.dart';

/// Écran liste des idées (coquille phase 1, français par défaut).
///
/// La capture audio, la lecture et les rappels arrivent dans les phases
/// suivantes ; cet écran affiche déjà la persistance réelle.
class IdeasPage extends StatefulWidget {
  const IdeasPage({super.key, required this.controller});

  final IdeasController controller;

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Murmur')),
      body: switch (controller.state) {
        IdeasListState.initial || IdeasListState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        IdeasListState.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              controller.errorMessage ?? 'Erreur inconnue.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IdeasListState.loaded =>
          controller.ideas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucune idée pour le moment.\nLa capture audio arrive à la prochaine étape.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: controller.ideas.length,
                  itemBuilder: (context, index) {
                    final idea = controller.ideas[index];
                    return ListTile(
                      title: Text(_fallbackTitle(idea)),
                      subtitle: Text(_subtitle(idea)),
                    );
                  },
                ),
      },
    );
  }

  String _fallbackTitle(Idea idea) {
    final custom = idea.title?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final local = idea.createdAtUtc.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return 'Idée du $day/$month/$year';
  }

  String _subtitle(Idea idea) {
    final seconds = idea.durationMs ~/ 1000;
    return '${idea.status.name} • ${seconds}s';
  }
}
