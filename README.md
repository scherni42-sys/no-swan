# No Swan

Die App merkt sich eine Home-Position und einen Radius (z. B. 500 m oder 1000 m).
Ist man innerhalb des Radius, gilt das Bild „Zuhause“, ist man außerhalb, das Bild „Unterwegs“.

## Was technisch geht (wichtig)

| | Android | iPhone (iOS) |
|---|---|---|
| Home-Position + Radius | ja | ja |
| Standort im Hintergrund prüfen | ja (natives Geofencing, zusätzlich WorkManager ca. alle 15 min) | ja (Geofencing) |
| **Systemhintergrund automatisch ändern** | **ja** (WallpaperManager) | **nein**, Apple erlaubt das keiner App |

**iPhone-Workaround:** In der Kurzbefehle-App eine persönliche Automation
„Ankommen“ bzw. „Verlassen“ am Home-Ort anlegen, Aktion „Hintergrundbild festlegen“
mit dem jeweiligen Bild. Das läuft ohne Nachfrage. Die No-Swan-App kann dabei
die Bilder verwalten und durch die Einrichtung führen, den Wechsel selbst macht iOS.

## Tech-Stack

**Flutter (Dart)**: eine Codebasis für Android und iOS, gute Plugins für
Standort (`geolocator`), Hintergrundjobs (`workmanager`) und Wallpaper (`async_wallpaper`).

## Projekt erzeugen

Das Projekt ist vollständig (Android- und iOS-Ordner, Berechtigungen eingetragen,
`flutter analyze` ohne Fehler). Starten mit Android-Handy per USB:

```bash
flutter pub get
flutter run
```

### Android: Berechtigungen (bereits in `android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.SET_WALLPAPER"/>
```

### iOS: (bereits in `ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>No Swan prüft, ob du in der Nähe deiner Home-Position bist.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>No Swan prüft auch im Hintergrund, ob du zuhause bist.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Zum Auswählen deiner Hintergrundbilder.</string>
```

## Aufbau

- `lib/main.dart` – Start, registriert auf Android die Hintergrundprüfung
- `lib/screens/home_screen.dart` – Oberfläche: Home setzen, Radius, zwei Bilder, „Jetzt prüfen“
- `lib/services/settings.dart` – Speichern der Einstellungen
- `lib/services/zone_checker.dart` – Distanz berechnen, bei Zonenwechsel Wallpaper setzen
- `lib/services/background.dart` – periodischer Hintergrundjob (Android, Reserve)
- `lib/services/geofence.dart` + `android/.../NoSwanGeofence.kt` – natives Geofencing: Android meldet Betreten/Verlassen, `GeofenceReceiver` setzt das Bild direkt, `BootReceiver` registriert nach Neustart neu

## Nächste Schritte

1. Auf einem Android-Gerät testen (`flutter run`).
2. Home-Position zusätzlich per Karte wählbar machen (z. B. `flutter_map`).
4. iOS: Einrichtungsassistent für die Kurzbefehle-Automation.
5. App-Icon, Name und Store-Veröffentlichung.
