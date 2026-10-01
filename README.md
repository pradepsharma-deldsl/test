# Secure Docs / My Organizer V2.5

## Modules
- **Document Vault** — encrypted local document storage, 1–5 images per new document, searchable categories, picture sharing, encrypted backup/restore.
- **Event Management** — module entry point is present; scheduling functionality is intentionally reserved for the next development step.

## Updated behavior
- A new document still requires at least 1 picture and allows up to 5.
- If the last remaining picture of an existing document is deleted, the **entire document record is deleted** in the same database transaction.
- Stored pictures can be shared through Android Share (WhatsApp, Gmail, Messages, etc., depending on installed apps).
- Encrypted `.sdbak` backups open Android Share so they can be saved/sent to Gmail, Google Drive, OneDrive, Dropbox, Files, or other installed providers. No Google/Drive credentials are stored by this app.

# Secure Docs Mobile — repaired build

Android-focused offline secure document vault.

Key rules/features:
- 1 to 5 pictures per document
- Encrypted SQLCipher SQLite database
- Pictures stored as encrypted database BLOBs
- Add/edit/delete document types with search
- Document search/filter
- Camera/gallery import with handled errors
- PIN/password and biometric unlock
- Power saver
- Encrypted backup/restore

## GitHub build
Upload the CONTENTS of this project to the repository root so GitHub shows `android/`, `lib/`, `pubspec.yaml`, and `.github/` at top level.

Then run **Actions -> Build Android APK -> Run workflow**.

The workflow runs:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build apk --debug`

The APK artifact is named `secure-docs-debug-apk`.
