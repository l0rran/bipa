package dev.l0rran.bipa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Lembra que a pessoa dispensou a notificação ao vivo desta compra. */
class LiveShoppingDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra(LiveShoppingNotification.EXTRA_TRIP)?.let {
            LiveShoppingNotification.markDismissed(context, it)
        }
    }
}
