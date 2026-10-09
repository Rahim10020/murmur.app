import 'idea.dart';

/// Contrat de persistance des idées.
///
/// Toute implémentation doit garantir :
/// - identités stables ([Idea.id] comme clé primaire) ;
/// - horodatages UTC en persistance ;
/// - aucune suppression de fichier audio cachée ici : la suppression
///   physique est orchestrée par une couche applicative (phase capture).
abstract class IdeaRepository {
  Future<void> insert(Idea idea);

  Future<void> update(Idea idea);

  Future<void> deleteById(String id);

  Future<Idea?> findById(String id);

  /// Idées triées par création décroissante (plus récentes d'abord).
  Future<List<Idea>> listNewestFirst({int? limit});

  /// Remplace l'intégralité du contenu (restauration) en une transaction.
  Future<void> replaceAll(List<Idea> ideas);

  Future<void> close();
}
