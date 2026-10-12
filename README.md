# Murmur

Murmur est une application Flutter de capture vocale d'idées, personnelle et
hors ligne. Elle permet d'enregistrer une pensée en quelques secondes, de la
retrouver plus tard et de la conserver dans le stockage privé de l'appareil.

> Une idée vient. Murmur la garde, puis vous aide à vous en souvenir au bon
> moment.

## Fonctionnalités

- capture audio rapide avec affichage de l'état et de la durée ;
- enregistrement local au format `.m4a`, avec noms de fichiers générés et
  stockage dans le répertoire privé de l'application ;
- liste des idées, lecture/pause, renommage et suppression ;
- statuts `À revoir`, `En cours`, `Terminée` et `Archivée` ;
- rappels locaux avec ouverture de l'idée concernée depuis la notification ;
- réconciliation des rappels enregistrés avec les notifications du système au
  démarrage ;
- session de redécouverte déterministe, limitée à trois idées ;
- export et restauration d'une sauvegarde ZIP contenant le manifeste et les
  fichiers audio ;
- validation complète des sauvegardes avant restauration, confirmation
  explicite et sauvegarde de sécurité automatique ;
- interface en français ou en anglais ;
- thèmes système, clair et sombre.

Murmur ne nécessite ni compte, ni serveur, ni connexion réseau. Les titres
sont saisis par l'utilisateur : l'application ne fait ni transcription, ni
classement, ni résumé par IA.

## État du projet

Murmur est un projet terminé. La cible principale est Android, avec une
installation directe de l'APK. Le code contient également les projets Flutter
générés pour iOS, macOS, Linux, Windows et le web ; leur niveau de support peut
varier selon les plugins utilisés (microphone, lecture audio, notifications et
sélection de fichiers).

## Prérequis

- Flutter avec un SDK Dart compatible avec `pubspec.yaml` (`^3.12.2`) ;
- Android Studio ou un appareil/émulateur Android pour la cible principale ;
- un microphone pour tester la capture audio ;
- les permissions microphone et notifications, lorsque le système les demande.

## Installation et lancement

Depuis la racine du projet :

```bash
flutter pub get
flutter run
```

Pour choisir une cible disponible :

```bash
flutter devices
flutter run -d <device-id>
```

Au premier lancement, autorisez l'accès au microphone pour enregistrer une
idée. Les rappels restent optionnels : l'application demeure utilisable même
si la permission de notifications est refusée.

## Vérifications

Les tests unitaires et widget sont regroupés dans `test/`. Les commandes
principales sont :

```bash
flutter analyze
flutter test
```

Pour produire un APK Android de release :

```bash
flutter build apk --release
```

Le fichier généré se trouve généralement dans
`build/app/outputs/flutter-apk/app-release.apk`.

## Utilisation

1. Appuyez sur l'action principale pour démarrer une capture.
2. Arrêtez puis conservez l'enregistrement. L'audio est sauvegardé avant que
   l'idée soit affichée dans la liste.
3. Depuis une idée, écoutez l'audio, renommez-la, changez son statut, planifiez
   un rappel ou supprimez-la.
4. Utilisez la session de redécouverte pour revoir jusqu'à trois idées
   anciennes qui n'ont pas de rappel futur actif.
5. Dans les paramètres, exportez une sauvegarde ou restaurez une archive
   existante. La restauration remplace les idées présentes après validation et
   confirmation.

Les données sont conservées localement. L'export est réalisé via le sélecteur
de fichiers du système : Murmur ne demande pas de permission de stockage
générale et n'envoie aucune donnée vers un serveur.

## Organisation du code

```text
lib/
├── app/             # bootstrap, navigation, thème et apparence
├── features/
│   ├── capture/     # enregistrement et gestion des erreurs
│   ├── ideas/       # modèle, base SQLite, liste et lecture audio
│   ├── reminders/   # rappels locaux et politique de planification
│   ├── rediscovery/ # sélection des idées à revoir
│   ├── backup/      # export, validation et restauration ZIP
│   ├── onboarding/  # premier lancement
│   └── settings/    # langue, thème et sauvegardes
├── l10n/            # chaînes françaises et anglaises
└── shared/          # services et composants réutilisables
```

La base SQLite est la source de vérité des métadonnées. Les horodatages sont
persistés en UTC puis affichés en heure locale. Les audios sont référencés par
un nom de fichier sûr et relatif, jamais par un chemin absolu.

## Dépendances principales

- [`record`](https://pub.dev/packages/record) : capture microphone ;
- [`just_audio`](https://pub.dev/packages/just_audio) : lecture audio ;
- [`sqflite`](https://pub.dev/packages/sqflite) : persistance locale ;
- [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
  et [`timezone`](https://pub.dev/packages/timezone) : rappels locaux ;
- [`path_provider`](https://pub.dev/packages/path_provider) : répertoires
  privés de l'application ;
- [`file_picker`](https://pub.dev/packages/file_picker) et
  [`archive`](https://pub.dev/packages/archive) : export/restauration ;
- [`uuid`](https://pub.dev/packages/uuid) : identifiants stables.

Les versions résolues sont suivies dans [`pubspec.lock`](pubspec.lock).
