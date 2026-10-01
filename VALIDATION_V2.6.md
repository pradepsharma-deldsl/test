# Secure Docs V2.6 validation

Repairs in this version:

1. Document type/category save crash
   - Removed ValueKey-based forced disposal of Document Vault tabs.
   - Tabs now keep their State objects while refreshToken requests data reloads through didUpdateWidget.
   - This avoids disposing Add/Types/Documents views while dialogs, image pickers, or save callbacks are still completing.
   - Document type picker no longer owns/disposes a TextEditingController during the modal route transition.
   - Database still validates the selected document_type_id inside the same transaction that creates/updates a document.

2. Picture sharing
   - Stored BLOB bytes are written to a real temporary file first.
   - Android Share receives an XFile backed by an actual filesystem path and MIME type.
   - This is substantially more compatible with WhatsApp/Gmail/Drive than the previous XFile.fromData path.

3. Backup / restore with Gmail, Drive and file providers
   - Encrypted .sdbak backup is copied to the app temporary/cache area before Android Share.
   - Restore uses FileType.any instead of extension-only filtering.
   - Restore accepts either a local file path or a provider stream (e.g. Android document providers / Drive) and materializes provider streams into a temporary file before decryption.

4. Existing rules retained
   - 1 to 5 pictures when creating a document.
   - If the last remaining stored picture is deleted, the whole parent document is deleted transactionally.
   - Custom document types are supported and protected from deletion while referenced.

Validation performed in this environment:
- Required Flutter/Android/GitHub workflow files present.
- YAML workflow parses.
- Dart source delimiter integrity checks passed.
- No remaining XFile.fromData picture sharing calls.
- No remaining ValueKey forced-tab-disposal pattern.
- SQLite schema simulation: custom non-Aadhaar category -> document -> 1 image succeeded.
- SQLite cascade simulation for last-image/document deletion succeeded.
- 23/23 automated source/database checks passed.

Runtime limitation:
This environment does not contain Flutter/Android SDK or a physical Android device. Therefore WhatsApp, Gmail/Drive chooser behavior, Android camera/gallery providers, SQLCipher native loading, biometric hardware, and the final APK must still be runtime-tested by the included GitHub Actions build and on an Android phone.
