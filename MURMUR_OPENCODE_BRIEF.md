# Murmur — Product & Engineering Brief for OpenCode

> **Document purpose:** This file is the source of truth for product intent, MVP scope, architecture, implementation constraints, and acceptance criteria. Read it fully before editing code. Do not invent features or silently expand scope.

## 1. Product identity

**Name:** Murmur  
**Product type:** Personal, offline-first, voice-first idea-capture app.  
**Initial platform:** Android, installed directly as an APK.  
**Framework:** Flutter / Dart.  
**Primary user:** Initially the developer himself; keep the product simple and dependable rather than building a commercial SaaS.

### Product promise

> An idea comes to mind. Murmur keeps it, then helps you remember it when it matters.

Murmur is not a general-purpose recorder, task manager, note-taking suite, or AI assistant. Its purpose is to make it effortless to capture a thought as audio, keep that audio safe on the device, and bring the idea back later through reminders or a limited rediscovery session.

### Core loop

1. User opens Murmur and starts recording quickly.
2. User speaks naturally; no title, category, transcription, or form is required.
3. User stops recording; the audio and its metadata are saved reliably.
4. User optionally schedules a reminder, or leaves the idea without a reminder.
5. At the chosen time, a local notification reminds the user and opens the related idea.
6. A weekly rediscovery session can surface a small number of unreviewed ideas that have no active reminder.
7. User decides what to do: keep for later, start working on it, mark as done, or archive it.

**Most important product rule:** never require the user to organize an idea before it has been safely saved. Capture first; optional organization comes later.

## 2. Explicitly out of scope

Do not implement any of these in the MVP unless the product owner explicitly asks later:

- AI, LLMs, AI summaries, AI classification, or AI-generated titles.
- Speech-to-text or any transcription feature.
- Backend, server, cloud database, authentication, accounts, or subscriptions.
- Analytics, advertising, social features, collaboration, or sharing feeds.
- Complex project management, nested folders, or a large tagging system.
- A task manager that assumes every idea must become a task.
- Paid APIs or services.
- Mandatory onboarding that delays first capture.
- Background recording. The first version records while the app is in use; do not add a foreground service unless requirements change.

No internet permission should be added unless a future, explicitly approved feature needs it. The MVP should work offline after installation.

## 3. Product scope — MVP

### Capture and audio
- Start recording with one obvious primary action.
- Stop and save with one obvious action.
- Request microphone permission only when needed, with a clear explanation if denied.
- Store audio files in the app's private documents/support directory, not in a temporary/cache directory.
- Use a durable, widely supported audio format such as M4A/AAC if the selected recorder configuration supports it reliably on Android and iOS. Keep the file format explicit and consistent.
- Save metadata: stable ID, creation timestamp, duration, relative/managed file path, status, optional reminder timestamp, created/updated timestamps.
- Use a recoverable recording workflow: write to a temporary/in-progress file, then finalize/move it and insert metadata only after recording successfully stops. Clean up abandoned temporary files safely at startup.
- Do not silently discard an audio file if metadata saving fails. Surface a useful error and attempt recovery.
- Show recording state and elapsed duration. Prevent duplicate starts/stops and handle permission denial, interruptions, and errors.
- Do not delete the file until the database operation and any required cancellation of reminder have been handled consistently.

### Ideas list and playback
- List ideas newest first by default.
- Each item shows a readable fallback title (for example, “Idée du 9 octobre” or a localized date), creation date, duration, and status.
- Playback, pause, seek if straightforward, rename, archive, mark in progress, mark done, and delete.
- A title is optional user-entered metadata, not a transcript.
- Search, tags, advanced sorting, and folders are not required for the first version.
- If an audio file is missing or unreadable, show a recoverable error rather than crashing.

### Reminders
- User can create, edit, or cancel a reminder for an idea.
- Offer simple choices such as later today, tomorrow, next week, and a custom date/time; validate that the selected time is in the future.
- Use local scheduled notifications. No server or push-notification provider.
- Notification text must be private by default and should not expose the full idea content. Example: title “Une idée à revoir” and body “Prends un instant pour retrouver une idée enregistrée.”
- Tapping a notification should open Murmur and navigate to the relevant idea using a stable idea ID in the notification payload.
- Reschedule or cancel notifications when a reminder changes, an idea is deleted, or an idea is marked done/archived according to the agreed reminder policy.
- Use a deterministic notification ID derived safely from the idea ID; avoid collisions and avoid IDs that exceed supported integer ranges.
- Persist the reminder timestamp in the database as the source of truth. The OS schedule is a side effect and must be reconciled with persisted reminders on app startup.
- Handle notification permission denial gracefully and explain that reminders cannot be shown until permission is granted.
- Handle Android reboot and scheduled notification recovery according to the selected notification plugin's current official setup instructions.
- Prefer standard inexact scheduling for the MVP unless exact-to-the-minute delivery is proven necessary. Exact alarms may require additional Android permission and special handling; do not request them by default.
- Do not promise guaranteed delivery at an exact minute: Android battery optimization, OEM restrictions, Do Not Disturb, permission settings, and OS behavior can affect delivery.

### Weekly rediscovery
- Provide a simple weekly rediscovery entry point/session, not a complicated recommendation engine.
- Surface at most three eligible ideas per session.
- Eligible ideas: not done, not archived, no active future reminder, and not reviewed recently. Store a `lastReviewedAt` timestamp or equivalent.
- Selection should be deterministic and understandable (for example, oldest eligible ideas first), not “AI-powered.”
- Do not send repeated daily notifications for ignored reminders.
- For MVP, a weekly in-app session is sufficient; a recurring weekly notification is optional and should only be added if it can be implemented reliably without complicating reminder behavior.
- User can choose: “Start working on it,” “Remind me later,” “Keep for later,” “Mark as done,” or “Archive.” Use clear distinctions; do not imply every idea is a task.

### Local export and restore — required
Export and restore are part of the MVP because app-private files can be lost when the app is uninstalled or the device is lost.

- Provide “Export backup” and “Restore backup” in settings.
- Use Android's system document picker / Storage Access Framework via a maintained Flutter package or a platform-supported solution; do not ask for broad storage permissions just to export a user-selected file.
- Export one portable archive (for example ZIP) containing:
  - A versioned manifest in JSON.
  - All referenced audio files.
  - Metadata: IDs, timestamps, duration, titles, statuses, reminder timestamps, last-reviewed timestamps, and file names.
  - A backup schema version and export timestamp.
- Do not include caches, logs, temporary recording files, or unrelated app data.
- Restore must validate the archive and manifest before mutating current data.
- Reject malformed archives, path traversal entries (`../`, absolute paths), unexpected file paths, duplicate IDs, missing audio files, and unreasonable file sizes. Never extract arbitrary archive paths directly.
- Offer a clear choice between merging the backup and replacing current data. If only one mode is implemented in the first iteration, choose **replace only after explicit confirmation and a safety backup**; never silently overwrite existing data.
- Prefer merge semantics based on stable IDs if implemented. Define conflict handling deterministically and document it.
- Do not blindly restore old scheduled notifications as active if their times are in the past. Restore metadata, then reschedule only future reminders and report skipped past reminders.
- Restore audio files into the app-managed audio directory with generated safe filenames; do not trust paths from the archive.
- Use a transaction for database changes where possible. Stage files first, validate, then commit; if an operation fails, roll back or leave the previous state intact.
- Never delete existing audio files before the restore has been fully validated and the user has confirmed the action.
- Show progress and a useful success/failure summary, especially for large backups.
- Test backup round-trip: export -> delete app data in a test environment -> restore -> verify audio playback and metadata.
- Clearly tell the user that backups are stored wherever they choose (e.g. Downloads, SD card, USB, or a user-selected folder); Murmur itself does not upload them.

## 4. Platform strategy and future iOS

Build Android-first, but avoid Android-only business logic in core features.

- Use Flutter's shared UI and business logic.
- Keep platform-specific code isolated behind services/interfaces: recorder, notifications, backup file selection, file storage.
- Use app documents/support directories obtained through `path_provider`; never hard-code Android filesystem paths.
- Use a cross-platform audio format supported by the chosen packages on both Android and iOS.
- Keep notification scheduling behind a `ReminderService` abstraction. iOS uses different permission and scheduling behavior and requires Xcode/macOS for building/signing.
- Add microphone usage text to iOS `Info.plist` when iOS work begins.
- Android APK sideloading is free. Publishing to Google Play is not required for MVP.
- Future iOS support is feasible, not automatic: Flutter UI and most Dart logic can be reused, but notification behavior, microphone permissions, document picker behavior, background/reboot semantics, app signing, and testing must be completed and verified on iOS. Building/signing an iOS app generally requires macOS with Xcode. Do not promise identical platform behavior without tests.

## 5. Architecture and code quality

Use a small, maintainable layered architecture. Do not over-engineer with dozens of abstractions, but keep UI out of persistence and platform logic.

Suggested structure (adapt to an existing repository rather than replacing it blindly):

```text
lib/
  app/
    app.dart
    router.dart                 # only if routing is needed
    theme/
  core/
    errors/
    utils/
  features/
    capture/
      data/
      domain/
      presentation/
    ideas/
      data/
      domain/
      presentation/
    reminders/
      data/
      domain/
      presentation/
    backup/
      data/
      domain/
      presentation/
    settings/
      presentation/
  shared/
    widgets/
    services/
```

Use a simple state-management approach appropriate to project size. If the repository already uses a reasonable approach, keep it. Do not add Riverpod/BLoC/GetX merely by habit. If starting from scratch, prefer Flutter's built-in `ChangeNotifier`/`ValueNotifier` or one small established state-management package only if there is a concrete need.

Requirements:
- Null safety and sound typing.
- Small, focused classes and methods.
- Immutable domain models where practical.
- Repository/service interfaces where they isolate file system, database, or OS plugin behavior.
- No business logic embedded in large widgets.
- No duplicated reminder logic across screens.
- No empty placeholder files, dead code, fake implementations, or TODO-only features presented as complete.
- No giant single-file app.
- No speculative abstractions or premature clean-architecture ceremony.
- Handle exceptions and show useful user-facing errors; do not swallow errors silently.
- Keep dependencies minimal and justified.
- Use stable IDs (UUID is acceptable if a maintained package is selected; do not use list indexes as identity).
- Store timestamps consistently (UTC in persistence, local time for display and scheduling). Be explicit about conversions and daylight-saving/time-zone behavior.
- Never use the audio title as a file path.
- Use generated safe audio filenames, such as `<uuid>.m4a`.
- Avoid logging audio content, personal titles, or backup contents.

## 6. Dependencies and version policy

**Important:** Package versions move quickly. Before adding or upgrading dependencies, inspect the current stable release and its official changelog/documentation on pub.dev. Do not use prereleases, abandoned packages, or versions copied from old tutorials. Do not claim a version is compatible without checking its minimum Flutter/Dart SDK and platform requirements.

Candidate packages to evaluate:
- `record` — microphone recording.
- `just_audio` — local audio playback.
- `path_provider` — app-managed directories.
- `sqflite` — local SQLite database; alternatively `drift` only if justified.
- `flutter_local_notifications` — local notifications and scheduled reminders.
- `timezone` — time-zone aware scheduling if required by the notification plugin.
- `file_picker` or an equivalent maintained document-picker integration — user-selected backup destination/source.
- A maintained ZIP/archive package such as `archive` — backup archive creation/extraction, only after validating safe extraction behavior.
- `uuid` — stable IDs if needed.
- `intl` — date formatting/localization if needed.

Do not add every candidate automatically. Verify APIs against the exact resolved versions before implementation.

As of the research used to prepare this brief (2026-10-09), the package registry showed:
- `record` 7.1.1, which requires a recent Flutter/Dart toolchain; its changelog notes v7 raises requirements to Flutter 3.44 / Dart 3.13.
- `just_audio` 0.10.6, minimum Dart SDK 3.6.
- `flutter_local_notifications` 22.3.1, minimum Dart SDK 3.10; v10+ requires Android desugaring configuration, and current Android manifest/permission setup must be followed.
These are reference points, not permission to blindly pin these versions. Check the current stable versions and the Flutter SDK actually installed in the repository before choosing. If the installed SDK is too old, do not downgrade randomly or partially upgrade dependencies: report the mismatch and recommend a deliberate toolchain update or a compatible stable version.

Use `flutter pub add <package>` for selected packages where possible, then inspect `pubspec.yaml` and `pubspec.lock`. Commit the lockfile for this application. Avoid manually guessing transitive dependency versions. Never use `dependency_overrides` to hide incompatibilities without a documented, justified reason.

Official references:
- Flutter releases: https://docs.flutter.dev/release/whats-new
- `record`: https://pub.dev/packages/record
- `just_audio`: https://pub.dev/packages/just_audio
- `flutter_local_notifications`: https://pub.dev/packages/flutter_local_notifications
- `path_provider`: https://pub.dev/packages/path_provider
- `sqflite`: https://pub.dev/packages/sqflite
- `timezone`: https://pub.dev/packages/timezone
- `file_picker`: https://pub.dev/packages/file_picker
- `archive`: https://pub.dev/packages/archive

## 7. Android requirements

- Use the Android project template and Gradle/Kotlin configuration generated by the installed stable Flutter SDK unless a plugin's current official documentation requires a specific change.
- Inspect existing Gradle files before editing. Projects may use `build.gradle` or `build.gradle.kts`; do not paste Groovy syntax into Kotlin DSL files.
- Follow the notification plugin's exact current Android setup instructions, including core library desugaring if required by the selected version.
- Add only required permissions, including microphone permission and notification permission when applicable. Add boot receiver permission only if required for scheduled notification rescheduling.
- Do not request broad storage permissions for private app storage or system document-picker export/import.
- Keep the Android package/application ID stable once established.
- Test a release APK, not only debug mode.
- Do not enable exact alarms by default without a product requirement and verified permission flow.
- The app should remain usable if notifications are denied; explain the consequence instead of blocking recording.

## 8. Data model — starting proposal

`Idea`:
- `id`: stable string UUID, primary key.
- `createdAtUtc`: timestamp.
- `updatedAtUtc`: timestamp.
- `audioFileName`: generated safe file name, not an arbitrary absolute path.
- `durationMs`: integer.
- `title`: nullable user-entered title; no transcription-generated title.
- `status`: one of `toReview`, `inProgress`, `done`, `archived`.
- `reminderAtUtc`: nullable timestamp.
- `lastReviewedAtUtc`: nullable timestamp.
- `schemaVersion`: include at backup/manifest level; database migrations should be versioned separately.

Persist the relative managed filename and derive the absolute path from the app's audio directory. Do not rely on a temporary/cache directory.

Use database migrations when schema changes. Never destroy the database on version changes in production.

## 9. Backup format and data integrity

Proposed archive layout:

```text
murmur-backup-YYYY-MM-DD.zip
  manifest.json
  audio/
    <idea-id>.m4a
    <idea-id>.m4a
```

The manifest should include:
- `app`: `Murmur`
- `backupSchemaVersion`: integer
- `exportedAtUtc`: ISO-8601 UTC string
- `ideas`: list of idea metadata, with each audio file mapped to its safe archive-relative filename.

Use a documented versioned schema. Importers must reject unsupported future schema versions and provide a helpful error. Do not serialize absolute device paths into backups. Consider a checksum per audio file for detecting corruption; if implemented, verify checksums during restore.

Restore must be defensive: archive paths are untrusted input. Do not trust filenames, titles, IDs, sizes, timestamps, or JSON shapes from an imported archive.

## 10. Reminder consistency and lifecycle

- The database is the source of truth; the OS notification schedule is derived state.
- On app startup, compare stored future reminders with scheduled notifications and reconcile missing/stale entries using plugin APIs that are supported by the resolved version.
- When an idea is deleted, cancel its scheduled reminder and delete its audio file. Handle partial failure and report/recover rather than silently leaving orphan data.
- When an idea becomes `done` or `archived`, cancel its reminder unless the product owner explicitly changes this rule.
- If a reminder timestamp is in the past, do not reschedule it as a future notification.
- Notification payloads contain only the stable idea ID and minimal routing information.
- Handle cold start from a notification tap and warm app notification taps.
- If a notification points to a missing idea, route safely to the idea list and do not crash.
- Use stable, deterministic notification IDs, not random IDs regenerated on every app launch.

## 11. Accessibility, UX, and language

- Optimize for speed and clarity, not feature count.
- The primary recording action must be easy to find and use one-handed.
- Make recording state obvious; never make the user wonder whether audio is being captured.
- Provide clear states: idle, recording, saving, saved, permission denied, storage error, playback error.
- Prevent accidental loss: if the user tries to leave while recording, explain the choices.
- Use accessible labels, sufficient contrast, scalable text, and comfortable touch targets.
- Do not invent a visual design system unless one exists. First inspect the repository and existing product decisions.
- UI language should be French by default unless the repository/product owner specifies otherwise. Keep user-facing strings centralized enough to localize later.
- No visual redesign is authorized by this document; prioritize functional correctness and a coherent, calm, minimal interface.

## 12. Testing and acceptance criteria

Do not claim a feature is done until it has been exercised or tested.

### Capture
- Permission granted: record, stop, save, and play a voice note.
- Permission denied: app remains usable and explains how to enable it.
- Interrupt/stop/failure: no false “saved” success state.
- Relaunch app: saved ideas still appear and audio plays.
- Failed metadata save: do not silently lose the recording; recovery/error behavior is verified.

### Reminders
- Schedule a reminder a few minutes ahead and verify notification delivery on a physical Android device.
- Edit reminder: old schedule is cancelled and new one is scheduled.
- Delete idea: notification no longer opens a deleted item.
- Mark done/archive: reminder is cancelled.
- Tap notification while app is closed and while app is open; correct idea opens.
- Denied notification permission is handled.
- Reboot behavior is tested if the selected setup claims reboot rescheduling.
- Test on a physical device because emulator and OEM battery behavior can differ.

### Backup/restore
- Export backup to a user-selected location.
- Verify archive contents and manifest version.
- Restore into a clean app/test database and confirm metadata plus playback.
- Invalid ZIP, invalid JSON, missing audio, duplicate ID, path traversal, and unsupported schema are rejected safely.
- Restore cancellation or failure does not destroy existing user data.
- Past reminders are not unexpectedly re-fired after restore.

### Quality gates
Run and resolve relevant failures:
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release`

Add unit tests for repositories, reminder scheduling policy, rediscovery eligibility, backup validation, and restore conflict handling. Add widget tests for the key user flows where practical. Do not suppress analyzer warnings without a specific reason.

## 13. OpenCode working protocol — mandatory

Before changing code:
1. Inspect the repository, current Flutter/Dart versions, app structure, dependencies, and existing tests.
2. Read this document fully.
3. Summarize the current state and propose a small implementation plan.
4. Identify any dependency/API uncertainty and verify against current official docs.
5. Do not replace existing files or architecture wholesale without explaining why.

Implementation protocol:
- Work in small, coherent steps.
- Prefer completing one vertical slice (for example capture -> persistence -> list -> playback) before moving on.
- After each slice, run formatter, analyzer, and relevant tests.
- Inspect the final diff and remove dead code, accidental generated files, and unrelated changes.
- Keep `pubspec.lock` committed.
- Do not add dependencies unless they directly support approved MVP requirements.
- Do not change product scope, add AI/transcription, add cloud/backend, or introduce monetization.
- If a decision is ambiguous or could risk data loss, stop and ask the product owner rather than guessing.
- Never use destructive database migrations or delete existing user files during normal upgrades.
- Never claim tests passed unless the commands were actually run and their results checked.
- If the environment cannot build Android (missing SDK, Java, Flutter, or Gradle), report the exact blocker and still run available static checks.

Recommended implementation phases:
1. Repository/toolchain audit and dependency compatibility check.
2. Minimal app shell and local persistence schema.
3. Reliable recording, finalization, recovery, list, and playback.
4. Reminder service and notification deep-linking.
5. Idea status and weekly rediscovery.
6. Versioned export/restore with validation and safety guarantees.
7. Android permissions/configuration, physical-device QA, and release APK.
8. Document how to build/install/update the APK and back up/restore data.

## 14. Definition of done

Murmur MVP is done only when:
- A voice idea can be captured quickly without required text entry.
- Audio and metadata persist locally after app restart.
- Playback works reliably.
- A user can schedule, edit, and cancel reminders.
- Notifications open the correct idea and permission denial is handled.
- Ideas can be marked in progress, done, or archived.
- A limited weekly rediscovery flow exists.
- Export and restore work end-to-end and do not silently overwrite or destroy data.
- The app works offline without a backend or paid API.
- `flutter analyze`, tests, and a release APK build have been run; any remaining failures are explicitly documented.
- The owner receives concise build/install instructions and knows where exported backups are stored.

## 15. Final instruction

Treat reliability and data safety as more important than adding features. Murmur is a personal memory tool: a lost recording or a reminder that silently disappears undermines its purpose. When uncertain, prefer the smallest dependable implementation, verify official documentation, and ask before expanding scope.
