/// Statuts d'une idée, conformes au brief produit (§8).
///
/// `toReview` est le statut initial après capture.
enum IdeaStatus {
  toReview,
  inProgress,
  done,
  archived;

  /// Nom persistant en base (stable, jamais renommé sans migration).
  String get storageName => name;

  static IdeaStatus fromStorage(String value) {
    for (final status in IdeaStatus.values) {
      if (status.storageName == value) return status;
    }
    throw ArgumentError.value(value, 'value', 'Statut d’idée inconnu');
  }
}

/// Modèle de domaine immuable pour une idée Murmur (brief §8).
///
/// Conventions :
/// - horodatages persistés en UTC (`millisSinceEpoch`), affichés en local ;
/// - [audioFileName] est un nom de fichier sûr (ex. `<uuid>.m4a`),
///   jamais un chemin absolu ni un titre utilisateur.
class Idea {
  const Idea({
    required this.id,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.audioFileName,
    required this.durationMs,
    required this.status,
    this.title,
    this.reminderAtUtc,
    this.lastReviewedAtUtc,
  });

  final String id;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String audioFileName;
  final int durationMs;
  final String? title;
  final IdeaStatus status;
  final DateTime? reminderAtUtc;
  final DateTime? lastReviewedAtUtc;

  /// Valide les invariants critiques pour la sécurité des données.
  void validate() {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'L’ID ne doit pas être vide');
    }
    if (!createdAtUtc.isUtc || !updatedAtUtc.isUtc) {
      throw ArgumentError('Les horodatages created/updated doivent être UTC');
    }
    if (reminderAtUtc != null && !reminderAtUtc!.isUtc) {
      throw ArgumentError('Le rappel doit être exprimé en UTC');
    }
    if (lastReviewedAtUtc != null && !lastReviewedAtUtc!.isUtc) {
      throw ArgumentError('lastReviewedAt doit être exprimé en UTC');
    }
    if (!_isSafeFileName(audioFileName)) {
      throw ArgumentError.value(
        audioFileName,
        'audioFileName',
        'Nom de fichier audio non sûr (chemin absolu ou traversal interdit)',
      );
    }
    if (durationMs < 0) {
      throw ArgumentError.value(
        durationMs,
        'durationMs',
        'La durée ne doit pas être négative',
      );
    }
  }

  static bool _isSafeFileName(String value) {
    if (value.isEmpty) return false;
    if (value.contains('/') ||
        value.contains('\\') ||
        value.contains('..') ||
        value.startsWith('.')) {
      return false;
    }
    // Noms générés attendus : <uuid>.m4a — on reste tolérant sur
    // l'extension pour la V1 tant que le nom est sûr.
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);
  }

  Idea copyWith({
    String? id,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    String? audioFileName,
    int? durationMs,
    String? Function()? title,
    IdeaStatus? status,
    DateTime? Function()? reminderAtUtc,
    DateTime? Function()? lastReviewedAtUtc,
  }) {
    return Idea(
      id: id ?? this.id,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      audioFileName: audioFileName ?? this.audioFileName,
      durationMs: durationMs ?? this.durationMs,
      title: title != null ? title() : this.title,
      status: status ?? this.status,
      reminderAtUtc: reminderAtUtc != null
          ? reminderAtUtc()
          : this.reminderAtUtc,
      lastReviewedAtUtc: lastReviewedAtUtc != null
          ? lastReviewedAtUtc()
          : this.lastReviewedAtUtc,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'audioFileName': audioFileName,
      'durationMs': durationMs,
      'title': title,
      'status': status.storageName,
      'reminderAtUtc': reminderAtUtc?.millisecondsSinceEpoch,
      'lastReviewedAtUtc': lastReviewedAtUtc?.millisecondsSinceEpoch,
    };
  }

  factory Idea.fromMap(Map<String, Object?> map) {
    DateTime readUtc(String key) {
      final value = map[key];
      if (value is! int) {
        throw ArgumentError.value(value, key, 'Horodatage UTC attendu (int)');
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    DateTime? readNullableUtc(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! int) {
        throw ArgumentError.value(value, key, 'Horodatage UTC attendu (int)');
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    final id = map['id'];
    final audioFileName = map['audioFileName'];
    final durationMs = map['durationMs'];
    final statusRaw = map['status'];
    if (id is! String ||
        audioFileName is! String ||
        durationMs is! int ||
        statusRaw is! String) {
      throw ArgumentError('Ligne idée invalide : champs manquants ou typés');
    }
    final title = map['title'];
    if (title != null && title is! String) {
      throw ArgumentError.value(title, 'title', 'Titre attendu (String?)');
    }
    final idea = Idea(
      id: id,
      createdAtUtc: readUtc('createdAtUtc'),
      updatedAtUtc: readUtc('updatedAtUtc'),
      audioFileName: audioFileName,
      durationMs: durationMs,
      title: title as String?,
      status: IdeaStatus.fromStorage(statusRaw),
      reminderAtUtc: readNullableUtc('reminderAtUtc'),
      lastReviewedAtUtc: readNullableUtc('lastReviewedAtUtc'),
    );
    idea.validate();
    return idea;
  }

  @override
  bool operator ==(Object other) {
    return other is Idea &&
        other.id == id &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.audioFileName == audioFileName &&
        other.durationMs == durationMs &&
        other.title == title &&
        other.status == status &&
        other.reminderAtUtc == reminderAtUtc &&
        other.lastReviewedAtUtc == lastReviewedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAtUtc,
    updatedAtUtc,
    audioFileName,
    durationMs,
    title,
    status,
    reminderAtUtc,
    lastReviewedAtUtc,
  );
}
