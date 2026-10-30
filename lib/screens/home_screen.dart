import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/geofence.dart';
import '../services/settings.dart';
import '../services/zone_checker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Settings _s = const Settings();
  Zone? _zone;
  String? _msg;
  bool _alwaysGranted = false;
  bool _batteryUnrestricted = false;
  String? _fenceError; // null = Geofence aktiv

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nach Rückkehr aus den Einstellungen oder dem Hintergrund neu laden.
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final s = await Settings.load();
    final always = await Permission.locationAlways.isGranted;
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.isGranted
        : true;
    // Geofence bei jedem Laden auffrischen (Android kann ihn z. B. beim
    // Ausschalten des Standorts verwerfen).
    final fence = Platform.isAndroid ? await NativeGeofence.sync() : null;
    if (!mounted) return;
    setState(() {
      _s = s;
      _alwaysGranted = always;
      _batteryUnrestricted = battery;
      _fenceError = fence;
    });
  }

  Future<void> _requestAlways() async {
    if (!await _ensurePermission()) return;
    final status = await Permission.locationAlways.request();
    if (!status.isGranted) await openAppSettings();
    await _reload();
  }

  Future<void> _requestBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _reload();
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final time = '${two(t.hour)}:${two(t.minute)} Uhr';
    return sameDay ? 'heute $time' : '${two(t.day)}.${two(t.month)}. $time';
  }

  Widget _statusCard() {
    final c = _s.lastCheck;
    final d = _s.lastDistance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(c == null
                ? 'Noch keine Prüfung.'
                : 'Letzte Prüfung: ${_fmtTime(c)} (${_s.lastSource ?? 'app'})'),
            if (d != null)
              Text('Entfernung zu Home: ${d.round()} m → '
                  '${d <= _s.radiusMeters ? 'innerhalb' : 'außerhalb'} des Radius'),
            if (_s.lastError != null)
              Text(_s.lastError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            _checkRow(
              ok: _alwaysGranted,
              okText: 'Standort: immer erlaubt',
              badText: 'Standort nur bei Nutzung erlaubt',
              action: 'Immer erlauben',
              onTap: _requestAlways,
            ),
            if (Platform.isAndroid)
              _checkRow(
                ok: _batteryUnrestricted,
                okText: 'Akku-Optimierung aus',
                badText: 'Akku-Optimierung kann Prüfungen verhindern',
                action: 'Ausschalten',
                onTap: _requestBattery,
              ),
            if (Platform.isAndroid)
              _checkRow(
                ok: _fenceError == null,
                okText: 'Geofence aktiv: Wechsel kommt automatisch',
                badText: _fenceError ?? '',
                action: 'Erneut',
                onTap: _reload,
              ),
            const SizedBox(height: 4),
            const Text('Android meldet das Betreten und Verlassen des Radius '
                'selbst, meist innerhalb weniger Minuten. Zusätzlich wird etwa '
                'alle 15 Minuten geprüft.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _checkRow({
    required bool ok,
    required String okText,
    required String badText,
    required String action,
    required VoidCallback onTap,
  }) =>
      Row(children: [
        Icon(ok ? Icons.check_circle : Icons.warning_amber,
            color: ok ? Colors.green : Colors.orange, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(ok ? okText : badText)),
        if (!ok) TextButton(onPressed: onTap, child: Text(action)),
      ]);

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _msg = 'Standortberechtigung fehlt.');
      return false;
    }
    setState(() => _msg = null);
    return true;
  }

  Future<void> _setHomeHere() async {
    if (!await _ensurePermission()) return;
    final pos = await Geolocator.getCurrentPosition();
    await Settings.saveHome(pos.latitude, pos.longitude);
    await _reload();
    await _check();
  }

  Future<void> _pickImage({required bool home}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final target = '${dir.path}/${home ? 'home' : 'away'}.jpg';
    await File(picked.path).copy(target);
    // Gleicher Dateiname: Bild-Cache leeren, damit die Vorschau aktualisiert.
    await FileImage(File(target)).evict();
    await Settings.saveImage(home: home, path: target);
    await _reload();
    if (_s.hasHome) await _check();
  }

  Future<void> _check({bool force = false}) async {
    if (!await _ensurePermission()) return;
    try {
      final z = await ZoneChecker.checkAndApply(force: force);
      setState(() => _zone = z);
    } catch (e) {
      setState(() => _msg = 'Standort konnte nicht ermittelt werden.');
    }
    await _reload();
  }

  Widget _imageTile(String label, String? path, bool home) => Expanded(
        child: GestureDetector(
          onTap: () => _pickImage(home: home),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                image: path != null
                    ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.all(8),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('No Swan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.home),
              title: Text(_s.hasHome
                  ? '${_s.homeLat!.toStringAsFixed(5)}, ${_s.homeLng!.toStringAsFixed(5)}'
                  : 'Noch keine Home-Position'),
              subtitle: const Text('Home-Position'),
              trailing: FilledButton(
                onPressed: _setHomeHere,
                child: const Text('Hier setzen'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Radius: ${_s.radiusMeters.round()} m'),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 250, label: Text('250 m')),
              ButtonSegment(value: 500, label: Text('500 m')),
              ButtonSegment(value: 1000, label: Text('1000 m')),
              ButtonSegment(value: 2000, label: Text('2000 m')),
            ],
            selected: {_s.radiusMeters},
            onSelectionChanged: (v) async {
              await Settings.saveRadius(v.first);
              await _reload();
              await _check();
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            _imageTile('Zuhause', _s.imageHome, true),
            const SizedBox(width: 12),
            _imageTile('Unterwegs', _s.imageAway, false),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _check(force: true),
            icon: const Icon(Icons.my_location),
            label: const Text('Jetzt prüfen'),
          ),
          if (_zone != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_zone == Zone.home
                  ? 'Du bist innerhalb des Radius.'
                  : 'Du bist außerhalb des Radius.'),
            ),
          const SizedBox(height: 16),
          _statusCard(),
          if (Platform.isIOS)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Hinweis iPhone: Apple erlaubt Apps nicht, das '
                  'Hintergrundbild zu ändern. Richte dafür eine Kurzbefehle-'
                  'Automation „Ankommen/Verlassen“ mit „Hintergrundbild festlegen“ ein.'),
            ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_msg!, style: const TextStyle(color: Colors.orange)),
            ),
        ],
      ),
    );
  }
}
