import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Répertoires gérés par l'application (brief §4-5).
///
/// Les audios vivent dans un sous-dossier des documents/support de l'app,
/// jamais dans un dossier temporaire/cache, et jamais à un chemin en dur.
class AppDirectories {
  const AppDirectories._();

  static const String audioSubdirName = 'audio';

  /// Répertoire des audios, créé si nécessaire.
  static Future<Directory> audioDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, audioSubdirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Construit un chemin absolu vers un nom de fichier déjà validé.
  static String audioPathFor(Directory audioDir, String safeFileName) {
    return p.join(audioDir.path, safeFileName);
  }
}
