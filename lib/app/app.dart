import 'package:flutter/material.dart';

import '../features/ideas/data/idea_database.dart';
import '../features/ideas/data/sqflite_idea_repository.dart';
import '../features/ideas/presentation/ideas_controller.dart';
import '../features/ideas/presentation/ideas_page.dart';

/// Racine applicative Murmur.
///
/// Ouvre la base locale puis expose la liste des idées.
/// Les erreurs d'ouverture sont affichées plutôt que masquées (brief §5).
class MurmurApp extends StatefulWidget {
  const MurmurApp({super.key});

  @override
  State<MurmurApp> createState() => _MurmurAppState();
}

class _MurmurAppState extends State<MurmurApp> {
  IdeasController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final db = await IdeaDatabase.open();
      final repository = SqfliteIdeaRepository(db);
      final controller = IdeasController(repository);
      if (!mounted) {
        await repository.close();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’ouvrir la base locale : $e');
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Murmur',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
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
          : _controller == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : IdeasPage(controller: _controller!),
    );
  }
}
