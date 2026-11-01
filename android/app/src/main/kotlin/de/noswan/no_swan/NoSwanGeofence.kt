package de.noswan.no_swan

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import java.io.File
import java.io.IOException

/**
 * Echtes Android-Geofencing: Das System meldet Betreten/Verlassen des
 * Home-Radius selbst (auch bei ruhendem Handy), und der Receiver setzt das
 * Hintergrundbild nativ – ohne Flutter-Hintergrund-Isolate.
 */
object NoSwanGeofence {
    private const val PREFS = "noswan_native"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FENCE_ID = "noswan_home"
    private const val ACTION = "de.noswan.no_swan.GEOFENCE"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        ctx: Context,
        lat: Double,
        lng: Double,
        radius: Double,
        imageHome: String?,
        imageAway: String?,
    ) {
        prefs(ctx).edit()
            .putString("lat", lat.toString())
            .putString("lng", lng.toString())
            .putString("radius", radius.toString())
            .putString("img_home", imageHome)
            .putString("img_away", imageAway)
            .commit()
    }

    private fun granted(ctx: Context, perm: String) =
        ctx.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED

    private fun pendingIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, GeofenceReceiver::class.java).setAction(ACTION)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // Geofencing muss Extras in den Intent schreiben können.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(ctx, 0, intent, flags)
    }

    /** Registriert den Geofence neu. Callback: null = aktiv, sonst Fehlertext. */
    @SuppressLint("MissingPermission")
    fun register(ctx: Context, onResult: (String?) -> Unit) {
        val p = prefs(ctx)
        val lat = p.getString("lat", null)?.toDoubleOrNull()
        val lng = p.getString("lng", null)?.toDoubleOrNull()
        val radius = p.getString("radius", null)?.toDoubleOrNull() ?: 1000.0
        if (lat == null || lng == null) return finish(ctx, "Keine Home-Position.", onResult)
        if (!granted(ctx, Manifest.permission.ACCESS_FINE_LOCATION)) {
            return finish(ctx, "Geofence: Standortberechtigung fehlt.", onResult)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !granted(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ) {
            return finish(ctx, "Geofence braucht „Standort: immer erlauben“.", onResult)
        }

        val fence = Geofence.Builder()
            .setRequestId(FENCE_ID)
            .setCircularRegion(lat, lng, radius.toFloat())
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setNotificationResponsiveness(60_000)
            .build()
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(fence)
            .build()

        val client = LocationServices.getGeofencingClient(ctx)
        val pi = pendingIntent(ctx)
        client.removeGeofences(pi).addOnCompleteListener {
            try {
                client.addGeofences(request, pi)
                    .addOnSuccessListener { finish(ctx, null, onResult) }
                    .addOnFailureListener { e -> finish(ctx, describe(e), onResult) }
            } catch (e: SecurityException) {
                finish(ctx, "Geofence: Standortberechtigung fehlt.", onResult)
            }
        }
    }

    private fun describe(e: Exception): String {
        val code = (e as? ApiException)?.statusCode
        return when (code) {
            GeofenceStatusCodes.GEOFENCE_NOT_AVAILABLE ->
                "Geofence nicht verfügbar: Standort einschalten und in den " +
                    "Standort-Einstellungen „Google-Standortgenauigkeit“ aktivieren."
            GeofenceStatusCodes.GEOFENCE_TOO_MANY_GEOFENCES,
            GeofenceStatusCodes.GEOFENCE_TOO_MANY_PENDING_INTENTS ->
                "Geofence: zu viele registriert."
            else -> "Geofence-Fehler: ${e.message ?: code ?: "unbekannt"}"
        }
    }

    private fun finish(ctx: Context, error: String?, onResult: (String?) -> Unit) {
        prefs(ctx).edit().putString("fence_error", error ?: "").commit()
        onResult(error)
    }

    fun recordError(ctx: Context, error: String) {
        flutterPrefs(ctx).edit()
            .putLong("flutter.last_check", System.currentTimeMillis())
            .putString("flutter.last_source", "geofence")
            .putString("flutter.last_error", error)
            .commit()
    }

    private fun flutterPrefs(ctx: Context) =
        ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    /** Setzt das Bild für die Zone ("home" | "away") und protokolliert für die App. */
    fun applyZone(ctx: Context, zone: String, source: String) {
        val fp = flutterPrefs(ctx)
        // Schon richtig gesetzt (z. B. Initial-Trigger nach Neuregistrierung): nichts tun.
        if (fp.getString("flutter.last_state", null) == zone) {
            fp.edit()
                .putLong("flutter.last_check", System.currentTimeMillis())
                .putString("flutter.last_source", source)
                .remove("flutter.last_error")
                .commit()
            return
        }
        val path = prefs(ctx).getString(if (zone == "home") "img_home" else "img_away", null)
        var error: String? = null
        if (path == null || !File(path).exists()) {
            error = "Kein Bild für „${if (zone == "home") "Zuhause" else "Unterwegs"}“ gewählt."
        } else {
            error = setWallpaperVerified(ctx, path)
        }
        val ed = fp.edit()
            .putLong("flutter.last_check", System.currentTimeMillis())
            .putString("flutter.last_source", source)
        if (error == null) {
            ed.putString("flutter.last_state", zone).remove("flutter.last_error")
        } else {
            ed.putString("flutter.last_error", error)
        }
        ed.commit()
    }

    /**
     * Setzt Start- und Sperrbildschirm und prüft anhand der Wallpaper-ID, ob
     * das System das Bild wirklich übernommen hat. Samsung meldet teils
     * Erfolg, ohne den Startbildschirm zu ändern; dann folgen Ausweichwege.
     * Liefert null bei Erfolg, sonst eine Fehlermeldung mit Diagnose.
     */
    fun setWallpaperVerified(ctx: Context, path: String): String? {
        val wm = WallpaperManager.getInstance(ctx)
        if (!wm.isWallpaperSupported) return "Hintergrundbilder werden nicht unterstützt."
        if (!wm.isSetWallpaperAllowed) return "Hintergrundbild ändern ist auf diesem Gerät gesperrt."
        return try {
            val bmp = loadCropped(ctx, path)
            val sysBefore = wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM)
            val lockBefore = wm.getWallpaperId(WallpaperManager.FLAG_LOCK)
            val tried = mutableListOf<String>()

            // 1. Getrennt pro Bildschirm.
            wm.setBitmap(bmp, null, true, WallpaperManager.FLAG_SYSTEM)
            wm.setBitmap(bmp, null, true, WallpaperManager.FLAG_LOCK)
            tried += "getrennt"

            // 2. Kombiniert, falls der Startbildschirm unverändert blieb.
            if (wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM) == sysBefore) {
                wm.setBitmap(bmp, null, true,
                    WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK)
                tried += "kombiniert"
            }
            // 3. Klassische API ohne Flags.
            if (wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM) == sysBefore) {
                @Suppress("DEPRECATION")
                wm.setBitmap(bmp)
                tried += "klassisch"
            }
            // 4. Als Datenstrom statt Bitmap.
            if (wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM) == sysBefore) {
                File(path).inputStream().use {
                    wm.setStream(it, null, true, WallpaperManager.FLAG_SYSTEM)
                }
                tried += "Datei"
            }
            bmp.recycle()

            val sysAfter = wm.getWallpaperId(WallpaperManager.FLAG_SYSTEM)
            val lockAfter = wm.getWallpaperId(WallpaperManager.FLAG_LOCK)
            if (sysAfter == sysBefore) {
                "Startbildschirm unverändert (ID $sysBefore→$sysAfter, Sperr $lockBefore→$lockAfter, " +
                    "Versuche: ${tried.joinToString()}, ${Build.MANUFACTURER} Android ${Build.VERSION.RELEASE})"
            } else {
                null
            }
        } catch (e: Exception) {
            "Hintergrundbild nicht gesetzt: ${e.message ?: e.javaClass.simpleName}"
        }
    }

    /** Lädt das Bild speicherschonend, dreht es laut EXIF und schneidet es mittig aufs Display zu. */
    private fun loadCropped(ctx: Context, path: String): Bitmap {
        val dm = ctx.resources.displayMetrics
        val screenShort = minOf(dm.widthPixels, dm.heightPixels).coerceAtLeast(1)
        val screenLong = maxOf(dm.widthPixels, dm.heightPixels).coerceAtLeast(1)

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        val imgShort = minOf(bounds.outWidth, bounds.outHeight)
        val imgLong = maxOf(bounds.outWidth, bounds.outHeight)
        var sample = 1
        while (imgShort / (sample * 2) >= screenShort && imgLong / (sample * 2) >= screenLong) sample *= 2

        var bmp = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IOException("Bild nicht lesbar")

        val rotation = when (
            ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (rotation != 0f) {
            val m = Matrix().apply { postRotate(rotation) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }

        // Hochformat-Display: Seitenverhältnis Höhe/Breite
        val target = screenLong.toFloat() / screenShort
        val current = bmp.height.toFloat() / bmp.width
        return if (current > target) {
            val h = (bmp.width * target).toInt().coerceIn(1, bmp.height)
            Bitmap.createBitmap(bmp, 0, (bmp.height - h) / 2, bmp.width, h)
        } else {
            val w = (bmp.height / target).toInt().coerceIn(1, bmp.width)
            Bitmap.createBitmap(bmp, (bmp.width - w) / 2, 0, w, bmp.height)
        }
    }
}
