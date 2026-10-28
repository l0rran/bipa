package dev.l0rran.bipa

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** O botão da notificação que abriu o app, até o Dart ler. */
    private var launchAction: String? = null

    /** O pedido de permissão de notificações esperando a resposta. */
    private var pendingPermission: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Só vale o botão que acabou de ser tocado: recriada (o sistema matou
        // o processo) ou aberta pelos Recentes, a Activity recebe o mesmo
        // intent de antes, e o "Terminei" terminaria outra compra.
        val fromHistory = ((intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (savedInstanceState == null && !fromHistory) {
            launchAction = intent?.getStringExtra(LiveShoppingNotification.EXTRA_ACTION)
        }
        intent?.removeExtra(LiveShoppingNotification.EXTRA_ACTION)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LiveShoppingNotification.CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        @Suppress("UNCHECKED_CAST")
                        LiveShoppingNotification.show(this@MainActivity, call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "cancel" -> {
                        LiveShoppingNotification.cancel(this@MainActivity)
                        result.success(null)
                    }
                    "notificationAccess" -> result.success(notificationAccess())
                    // Responde só quando a pessoa escolher: o Dart espera para
                    // não pedir a câmera por cima.
                    "requestPermission" -> requestNotificationPermission(result)
                    "takeLaunchAction" -> {
                        result.success(launchAction)
                        launchAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.getStringExtra(LiveShoppingNotification.EXTRA_ACTION)
        intent.removeExtra(LiveShoppingNotification.EXTRA_ACTION)
        setIntent(intent)
        action?.let { channel?.invokeMethod("action", it) }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(null)
        pendingPermission = null
        // A notificação pode aparecer agora: o Dart manda o conteúdo de novo.
        if (granted) channel?.invokeMethod("permissionGranted", null)
    }

    /**
     * "granted", "askable" ou "blocked" (os nomes de PermissionAccess no Dart).
     * O Android não diz se a pessoa negou de vez: depois de um pedido, se ele
     * não oferece mais explicar o motivo, o sistema não pergunta mais.
     */
    private fun notificationAccess(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return if (NotificationManagerCompat.from(this).areNotificationsEnabled()) "granted" else "blocked"
        }
        val permission = Manifest.permission.POST_NOTIFICATIONS
        return when {
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED -> "granted"
            ActivityCompat.shouldShowRequestPermissionRationale(this, permission) -> "askable"
            permissionPrefs().getBoolean(KEY_NOTIFICATIONS_ASKED, false) -> "blocked"
            else -> "askable"
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        val permission = Manifest.permission.POST_NOTIFICATIONS
        val needed = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        // Já permitido, ou outro pedido em andamento: nada a esperar.
        if (!needed || pendingPermission != null) {
            result.success(null)
            return
        }
        pendingPermission = result
        permissionPrefs().edit().putBoolean(KEY_NOTIFICATIONS_ASKED, true).apply()
        ActivityCompat.requestPermissions(this, arrayOf(permission), REQUEST_NOTIFICATIONS)
    }

    private fun permissionPrefs() = getSharedPreferences(PERMISSION_PREFS, MODE_PRIVATE)

    override fun onDestroy() {
        // Sem a Activity, a resposta não vem: o Dart não fica esperando.
        pendingPermission?.success(null)
        pendingPermission = null
        super.onDestroy()
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 7002
        const val PERMISSION_PREFS = "bipa_permissions"
        const val KEY_NOTIFICATIONS_ASKED = "notifications_asked"
    }
}
