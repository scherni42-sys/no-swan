import 'dart:io';

import 'package:flutter/services.dart';

import 'settings.dart';

/// Brücke zum nativen Android-Geofencing (siehe NoSwanGeofence.kt).
/// Android meldet Betreten/Verlassen des Radius selbst und setzt das Bild,
/// auch wenn die App geschlossen ist.
class NativeGeofence {
  static const _channel = MethodChannel('de.noswan/geofence');

  /// Überträgt Home, Radius und Bilder und registriert den Geofence neu.
  /// Liefert null, wenn er aktiv ist, sonst eine Fehlermeldung.
  static Future<String?> sync() async {
    if (!Platform.isAndroid) return null;
    final s = await Settings.load();
    if (!s.hasHome) return 'Noch keine Home-Position.';
    try {
      return await _channel.invokeMethod<String>('sync', {
        'lat': s.homeLat,
        'lng': s.homeLng,
        'radius': s.radiusMeters,
        'imageHome': s.imageHome,
        'imageAway': s.imageAway,
      });
    } on PlatformException catch (e) {
      return 'Geofence-Fehler: ${e.message}';
    } on MissingPluginException {
      return 'Geofence nicht verfügbar.';
    }
  }
}
