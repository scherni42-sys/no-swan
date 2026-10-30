package de.noswan.no_swan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent

/** Wird vom System beim Betreten/Verlassen des Home-Radius aufgerufen. */
class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ctx = context.applicationContext
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            NoSwanGeofence.recordError(
                ctx,
                "Geofence-Fehler: " + GeofenceStatusCodes.getStatusCodeString(event.errorCode),
            )
            return
        }
        val zone = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "home"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "away"
            else -> return
        }
        val pending = goAsync()
        Thread {
            try {
                NoSwanGeofence.applyZone(ctx, zone, "geofence")
            } finally {
                pending.finish()
            }
        }.start()
    }
}
