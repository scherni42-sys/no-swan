# No Swan lokal unter Windows starten (optional)

Nur nötig, wenn du die App am eigenen Rechner bauen willst. Sonst baut GitHub sie automatisch.

1. **Android Studio** installieren: developer.android.com/studio, Standard-Installation durchklicken.
   Beim ersten Start den Assistenten (SDK, Emulator) komplett laufen lassen.
2. **Flutter** installieren: docs.flutter.dev/get-started/install/windows
   - Flutter-ZIP herunterladen und nach `C:\src\flutter` entpacken.
   - Windows-Suche: „Umgebungsvariablen“ > Benutzervariable `Path` > Neu > `C:\src\flutter\bin`.
3. In Android Studio: Plugins > „Flutter“ installieren (Dart kommt automatisch mit).
4. Eingabeaufforderung öffnen und prüfen:
   ```
   flutter doctor
   flutter doctor --android-licenses
   ```
   Alle Lizenzen mit `y` bestätigen.
5. Projekt holen: `git clone https://github.com/Scherni42-sys/no-swan.git`
   (oder ZIP von GitHub herunterladen und entpacken).
6. Handy per USB anschließen (USB-Debugging ist schon an), auf dem Handy „USB-Debugging zulassen“ bestätigen.
7. Im Projektordner:
   ```
   flutter pub get
   flutter run
   ```
