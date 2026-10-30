package de.noswan.no_swan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Android löscht Geofences beim Neustart – danach (und nach Updates) neu registrieren. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val pending = goAsync()
                try {
                    NoSwanGeofence.register(context.applicationContext) { pending.finish() }
                } catch (e: Exception) {
                    pending.finish()
                }
            }
        }
    }
}
