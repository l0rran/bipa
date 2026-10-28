package dev.l0rran.bipa

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * A notificação ao vivo da compra (ADR 0015, protótipo "Notificação ao vivo").
 *
 * No Android 16, é um Live Update: aparece na tela de bloqueio e como chip na
 * barra de status, com um segmento por item da lista. Antes dele, é uma
 * notificação fixa com barra de progresso. Os textos chegam prontos do Dart
 * (ARB); aqui só se monta a notificação.
 */
object LiveShoppingNotification {
    const val CHANNEL = "dev.l0rran.bipa/live_shopping"
    const val EXTRA_ACTION = "dev.l0rran.bipa.LIVE_ACTION"
    const val EXTRA_TRIP = "dev.l0rran.bipa.LIVE_TRIP"

    private const val CHANNEL_ID = "compra_ao_vivo"
    private const val NOTIFICATION_ID = 7001
    private const val PREFS = "live_shopping"
    private const val KEY_DISMISSED_TRIP = "dismissed_trip"

    /** Acima disso, os segmentos ficariam finos demais: vira uma barra só. */
    private const val MAX_SEGMENTS = 12

    private val actions = listOf("scan", "list", "finish")

    fun show(context: Context, args: Map<String, Any?>) {
        val tripId = args["tripId"] as String
        // Dispensada pela pessoa: não volta na mesma compra.
        if (prefs(context).getString(KEY_DISMISSED_TRIP, null) == tripId) return
        if (!canNotify(context)) return
        ensureChannel(context, args["channelName"] as String, args["channelDescription"] as String)

        val done = (args["done"] as Number).toInt()
        val total = (args["total"] as Number).toInt()
        val accent = (args["color"] as Number).toInt()
        @Suppress("UNCHECKED_CAST")
        val labels = args["actions"] as Map<String, String>

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_bipa)
            .setContentTitle(args["title"] as String)
            .setContentText(args["text"] as String?)
            .setSubText(args["subText"] as String?)
            .setColor(accent)
            .setOngoing(true)
            .setRequestPromotedOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setContentIntent(openApp(context, "list"))
            .setDeleteIntent(onDismiss(context, tripId))
        // setShortCriticalText e setRequestPromotedOngoing vêm do androidx.core
        // 1.17 (Live Updates). Se o compilador não achar o primeiro, o plano B
        // é aplicá-lo no Notification.Builder da plataforma (API 36) com
        // Notification.Builder.recoverBuilder.
        (args["chip"] as String?)?.let { builder.setShortCriticalText(it) }
        for (action in actions) {
            labels[action]?.let { builder.addAction(0, it, openApp(context, action)) }
        }

        if (total > 0) {
            if (Build.VERSION.SDK_INT >= 36) {
                val segments = if (total <= MAX_SEGMENTS) {
                    List(total) { NotificationCompat.ProgressStyle.Segment(1).setColor(accent) }
                } else {
                    listOf(NotificationCompat.ProgressStyle.Segment(total).setColor(accent))
                }
                builder.setStyle(
                    NotificationCompat.ProgressStyle()
                        .setStyledByProgress(true)
                        .setProgressSegments(segments)
                        .setProgress(done),
                )
            } else {
                builder.setProgress(total, done, false)
            }
        }

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // A permissão foi retirada entre a conferência e o aviso.
            android.util.Log.w("Bipa", "Notificação ao vivo sem permissão", e)
        }
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /** Chamado pelo [LiveShoppingDismissReceiver] quando a pessoa dispensa a notificação. */
    fun markDismissed(context: Context, tripId: String) {
        prefs(context).edit().putString(KEY_DISMISSED_TRIP, tripId).apply()
    }

    private fun canNotify(context: Context): Boolean {
        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return granted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun ensureChannel(context: Context, name: String, description: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // Importância padrão, sem som: um Live Update não pode estar num canal MIN.
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT).apply {
            this.description = description
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun openApp(context: Context, action: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = "dev.l0rran.bipa.LIVE_$action"
            putExtra(EXTRA_ACTION, action)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            actions.indexOf(action),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun onDismiss(context: Context, tripId: String): PendingIntent {
        val intent = Intent(context, LiveShoppingDismissReceiver::class.java).putExtra(EXTRA_TRIP, tripId)
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
