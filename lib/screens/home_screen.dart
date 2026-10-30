import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/settings.dart';
import '../services/zone_checker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Settings _s = const Settings();
  Zone? _zone;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await Settings.load();
    setState(() => _s = s);
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _msg = 'Standortberechtigung fehlt.');
      return false;
    }
    if (perm == LocationPermission.whileInUse) {
      setState(() => _msg = 'Für den Wechsel im Hintergrund bitte in den '
          'Einstellungen „Standort: Immer erlauben“ wählen.');
    }
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
    await Settings.saveImage(home: home, path: target);
    await _reload();
  }

  Future<void> _check() async {
    if (!await _ensurePermission()) return;
    final z = await ZoneChecker.checkAndApply();
    setState(() => _zone = z);
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
            onPressed: _check,
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
