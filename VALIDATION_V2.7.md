# V2.7 targeted runtime repair

Root-cause fix:
- Removed all short-lived TextEditingController instances from showDialog flows.
- Document Type, Change PIN and Backup Password dialogs now use controller-free TextFormField state.
- Cross-tab refresh after type changes is deferred to the next frame.
- Entering Documents/Add explicitly refreshes data.

Why this matters:
`showDialog()` completes when Navigator.pop is called, while the dialog route may still be reversing/unmounting.
Disposing a controller immediately after await showDialog can leave a TextField dependent on an already-disposed object and can produce Flutter framework assertions such as `_dependents.isEmpty`.

New widget tests:
- custom document type dialog save lifecycle
- repeated dialog open/cancel lifecycle
- backup password inline validation
- module home and event shell

The GitHub workflow runs flutter analyze, flutter test, then flutter build apk --debug.
