import 'package:flutter/foundation.dart';

import '../domain/idea.dart';
import '../domain/idea_repository.dart';

/// État de chargement de la liste des idées.
enum IdeasListState { initial, loading, loaded, error }

/// Contrôleur minimal de la liste (built-in [ChangeNotifier], brief §5).
///
/// La capture/l'enregistrement arrivent en phase 2 ; ce contrôleur expose
/// déjà la source de vérité (repository) à l'UI sans logique métier cachée.
class IdeasController extends ChangeNotifier {
  IdeasController(this._repository);

  final IdeaRepository _repository;

  IdeasListState state = IdeasListState.initial;
  List<Idea> ideas = const <Idea>[];
  String? errorMessage;

  Future<void> refresh() async {
    state = IdeasListState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      ideas = await _repository.listNewestFirst();
      state = IdeasListState.loaded;
    } catch (e) {
      state = IdeasListState.error;
      errorMessage = 'Impossible de charger les idées : $e';
    }
    notifyListeners();
  }

  Future<void> close() => _repository.close();
}
