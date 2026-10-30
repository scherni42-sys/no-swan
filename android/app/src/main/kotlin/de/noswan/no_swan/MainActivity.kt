package de.noswan.no_swan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.noswan/geofence")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val ctx = applicationContext
                        NoSwanGeofence.save(
                            ctx,
                            lat = call.argument<Double>("lat") ?: 0.0,
                            lng = call.argument<Double>("lng") ?: 0.0,
                            radius = call.argument<Double>("radius") ?: 1000.0,
                            imageHome = call.argument<String>("imageHome"),
                            imageAway = call.argument<String>("imageAway"),
                        )
                        try {
                            NoSwanGeofence.register(ctx) { error -> result.success(error) }
                        } catch (e: Exception) {
                            result.success("Geofence-Fehler: ${e.message}")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
