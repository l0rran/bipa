package dev.l0rran.bipa

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** O botão da notificação que abriu o app, até o Dart ler. */
    private var launchAction: String? = null

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
                    "requestPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
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
        if (requestCode == REQUEST_NOTIFICATIONS && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            // A notificação pode aparecer agora: o Dart manda o conteúdo de novo.
            channel?.invokeMethod("permissionGranted", null)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) return
        ActivityCompat.requestPermissions(this, arrayOf(permission), REQUEST_NOTIFICATIONS)
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 7002
    }
}
