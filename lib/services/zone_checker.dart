import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:geolocator/geolocator.dart';

import 'settings.dart';

enum Zone { home, away }

/// Prüft die aktuelle Position gegen Home + Radius und setzt bei einem
/// Wechsel das passende Hintergrundbild (nur Android möglich).
class ZoneChecker {
  static Future<Zone?> checkAndApply() async {
    final s = await Settings.load();
    if (!s.hasHome) return null;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    final distance = Geolocator.distanceBetween(
      s.homeLat!, s.homeLng!, pos.latitude, pos.longitude,
    );
    final zone = distance <= s.radiusMeters ? Zone.home : Zone.away;

    // Nur bei Zonenwechsel das Bild setzen (spart Akku, kein Flackern).
    if (s.lastState != zone.name) {
      final applied = await _applyWallpaper(zone == Zone.home ? s.imageHome : s.imageAway);
      if (applied) await Settings.saveLastState(zone.name);
    }
    return zone;
  }

  static Future<bool> _applyWallpaper(String? path) async {
    if (path == null || !Platform.isAndroid) return false;
    final result = await AsyncWallpaper.applyWallpaper(
      StaticWallpaperRequest(
        source: WallpaperSource.filePath(path),
        target: WallpaperTarget.both,
        scaleMode: WallpaperScaleMode.centerCrop,
        strategy: WallpaperApplyStrategy.direct,
      ),
    );
    return result.status == WallpaperOperationStatus.applied;
  }
}
