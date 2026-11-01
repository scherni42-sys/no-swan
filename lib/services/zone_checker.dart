import 'dart:io';

import 'package:flutter/services.dart';
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
    // Im Hintergrund-Isolate gibt es den nativen Kanal nicht; dort übernimmt
    // das native Geofencing den Wechsel, hier wird nur protokolliert.
    final canApply = source != 'hintergrund';
    String? error;
    if (canApply && (force || s.lastState != zone.name)) {
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

  static const _channel = MethodChannel('de.noswan/geofence');

  /// Setzt das Bild nativ (gleicher Weg wie das Geofencing) und prüft, ob
  /// das System es übernommen hat. Liefert null bei Erfolg, sonst den Fehler.
  static Future<String?> _applyWallpaper(String path) async {
    if (!Platform.isAndroid) return 'Nur auf Android möglich.';
    try {
      return await _channel.invokeMethod<String>('setWallpaper', {'path': path});
    } on PlatformException catch (e) {
      return 'Hintergrundbild nicht gesetzt: ${e.message}';
    } on MissingPluginException {
      return 'Hintergrundbild-Funktion nicht verfügbar.';
    }
  }
}
