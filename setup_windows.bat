@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter is not installed or is not in PATH.
  exit /b 1
)

set "BOOT=%TEMP%\secure_docs_flutter_bootstrap"
if exist "%BOOT%" rmdir /s /q "%BOOT%"

echo Creating Flutter Android wrapper files...
flutter create --platforms=android --org com.deldsl --project-name secure_doc_mobile "%BOOT%"
if errorlevel 1 exit /b 1

copy /y "%BOOT%\android\gradlew" "android\gradlew" >nul
copy /y "%BOOT%\android\gradlew.bat" "android\gradlew.bat" >nul
copy /y "%BOOT%\android\gradle\wrapper\gradle-wrapper.jar" "android\gradle\wrapper\gradle-wrapper.jar" >nul

rmdir /s /q "%BOOT%"

echo Getting Flutter packages...
flutter pub get
if errorlevel 1 exit /b 1

echo.
echo Setup completed successfully.
echo Run: flutter run
endlocal
