import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:geolocator/geolocator.dart';

import 'settings.dart';

enum Zone { home, away }

/// Prüft die aktuelle Position gegen Home + Radius und setzt bei einem
/// Wechsel das passende Hintergrundbild (nur Android möglich).
class ZoneChecker {
  static Future<Zone?> checkAndApply({String source = 'app', bool force = false}) async {
    final s = await Settings.load();
    if (!s.hasHome) return null;

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (e) {
      // Ohne frischen Fix auf die letzte bekannte Position zurückfallen –
      // aber nur, wenn sie aktuell ist. Eine alte Position (z. B. von zuhause)
      // würde sonst den Zonenwechsel verschlucken.
      final last = await Geolocator.getLastKnownPosition();
      final fresh = last != null &&
          DateTime.now().difference(last.timestamp) < const Duration(minutes: 10);
      if (!fresh) {
        await Settings.saveCheck(source: source, error: 'Kein aktueller Standort: $e');
        rethrow;
      }
      pos = last;
    }
    final distance = Geolocator.distanceBetween(
      s.homeLat!, s.homeLng!, pos.latitude, pos.longitude,
    );
    final zone = distance <= s.radiusMeters ? Zone.home : Zone.away;

    // Nur bei Zonenwechsel das Bild setzen (spart Akku, kein Flackern).
    String? error;
    if (force || s.lastState != zone.name) {
      final path = zone == Zone.home ? s.imageHome : s.imageAway;
      if (path == null) {
        error = 'Kein Bild für „${zone == Zone.home ? 'Zuhause' : 'Unterwegs'}“ gewählt.';
      } else {
        error = await _applyWallpaper(path);
        if (error == null) await Settings.saveLastState(zone.name);
      }
    }
    await Settings.saveCheck(source: source, distance: distance, error: error);
    return zone;
  }

  /// Setzt das Bild und liefert null bei Erfolg, sonst eine Fehlermeldung.
  /// Start- und Sperrbildschirm getrennt, weil manche Hersteller (z. B.
  /// Samsung) bei „beide“ nur einen Bildschirm übernehmen.
  static Future<String?> _applyWallpaper(String path) async {
    if (!Platform.isAndroid) return 'Nur auf Android möglich.';
    for (final target in [WallpaperTarget.home, WallpaperTarget.lock]) {
      final result = await AsyncWallpaper.applyWallpaper(
        StaticWallpaperRequest(
          source: WallpaperSource.filePath(path),
          target: target,
          scaleMode: WallpaperScaleMode.centerCrop,
          strategy: WallpaperApplyStrategy.direct,
        ),
      );
      if (result.status != WallpaperOperationStatus.applied) {
        return 'Hintergrundbild (${target.name}) nicht gesetzt (${result.status.name}): '
            '${result.errorMessage ?? result.errorCode ?? 'unbekannt'}';
      }
    }
    return null;
  }
}
