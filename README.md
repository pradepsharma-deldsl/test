# Secure Manager / Document Vault V2.6

Android-first, offline encrypted Document Vault source. The main page contains Document Vault and the Event Management entry point. Event Management is intentionally still a shell for the next development module.

## V2.6 repairs

- Fixed fragile tab/category refresh lifecycle that could trigger Flutter framework assertion screens when saving under document types other than the default type.
- Custom/new document types are reloaded without destroying active tab state.
- Picture sharing now creates a real temporary image file before opening Android Share (WhatsApp/Gmail/etc.).
- Encrypted backup is copied to temporary/cache storage before Android Share so Gmail/Drive/File apps can consume it.
- Restore now uses the Android document picker without .sdbak-only filtering and can import provider streams from cloud/file providers.
- Minimum 1 picture, maximum 5 pictures when creating a document.
- Deleting the last remaining picture deletes the complete document record.

## GitHub build

Repository root must contain `pubspec.yaml`, `lib/`, `android/`, `test/`, and `.github/workflows/build-apk.yml`.

Run **Actions -> Build Android APK -> Run workflow**. The workflow executes:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build apk --debug`

On success download the `secure-docs-debug-apk` artifact.

See `VALIDATION_V2.6.md` for validation scope and runtime limitations.
