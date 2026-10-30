import 'package:shared_preferences/shared_preferences.dart';

/// Persistente Einstellungen der App.
class Settings {
  static const _kLat = 'home_lat';
  static const _kLng = 'home_lng';
  static const _kRadius = 'radius_m';
  static const _kImgHome = 'img_home';
  static const _kImgAway = 'img_away';
  static const _kLastState = 'last_state'; // 'home' | 'away'

  final double? homeLat;
  final double? homeLng;
  final double radiusMeters;
  final String? imageHome;
  final String? imageAway;
  final String? lastState;

  const Settings({
    this.homeLat,
    this.homeLng,
    this.radiusMeters = 1000,
    this.imageHome,
    this.imageAway,
    this.lastState,
  });

  bool get hasHome => homeLat != null && homeLng != null;

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // wichtig, wenn der Hintergrund-Isolate geschrieben hat
    return Settings(
      homeLat: p.getDouble(_kLat),
      homeLng: p.getDouble(_kLng),
      radiusMeters: p.getDouble(_kRadius) ?? 1000,
      imageHome: p.getString(_kImgHome),
      imageAway: p.getString(_kImgAway),
      lastState: p.getString(_kLastState),
    );
  }

  static Future<void> saveHome(double lat, double lng) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kLat, lat);
    await p.setDouble(_kLng, lng);
    await p.remove(_kLastState); // neu bewerten
  }

  static Future<void> saveRadius(double meters) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kRadius, meters);
    await p.remove(_kLastState);
  }

  static Future<void> saveImage({required bool home, required String path}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(home ? _kImgHome : _kImgAway, path);
    await p.remove(_kLastState);
  }

  static Future<void> saveLastState(String state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastState, state);
  }
}
