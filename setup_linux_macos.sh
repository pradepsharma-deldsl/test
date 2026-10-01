#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter is not installed or is not in PATH." >&2
  exit 1
fi
BOOT="$(mktemp -d)/secure_docs_flutter_bootstrap"
flutter create --platforms=android --org com.deldsl --project-name secure_doc_mobile "$BOOT"
cp "$BOOT/android/gradlew" android/gradlew
cp "$BOOT/android/gradlew.bat" android/gradlew.bat
cp "$BOOT/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
chmod +x android/gradlew
rm -rf "$(dirname "$BOOT")"
flutter pub get
echo "Setup completed. Run: flutter run"
