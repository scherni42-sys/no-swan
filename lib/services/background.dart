import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'zone_checker.dart';

const _taskName = 'no_swan_zone_check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await ZoneChecker.checkAndApply();
    } catch (_) {
      // z. B. keine Standortberechtigung im Hintergrund – beim nächsten Lauf erneut.
    }
    return true;
  });
}

class Background {
  /// Android: periodische Prüfung, minimal alle 15 Minuten (Systemgrenze).
  static Future<void> start() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}
