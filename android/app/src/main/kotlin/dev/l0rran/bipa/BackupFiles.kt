package dev.l0rran.bipa

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * O seletor de arquivos do Android (Storage Access Framework) para o backup
 * `.bipa` (ADR 0023, seção 5): "Salvar uma cópia…" abre o "Salvar como"
 * (ACTION_CREATE_DOCUMENT) e "Restaurar de um arquivo…" abre o "Abrir"
 * (ACTION_OPEN_DOCUMENT). O seletor dá acesso só ao arquivo escolhido, sem
 * permissão de armazenamento.
 *
 * Os bytes passam por arquivos do app, copiados aqui numa thread à parte: o
 * Dart grava o backup num arquivo temporário antes de salvar, e lê o arquivo
 * escolhido de uma cópia, em vez de mandar megabytes pelo canal.
 */
class BackupFiles(private val activity: Activity) {
    /** O pedido esperando o seletor; um de cada vez. */
    private var pending: MethodChannel.Result? = null

    /** O arquivo a gravar no destino ("saveAs") ou onde copiar o escolhido ("open"). */
    private var pendingPath: String? = null

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveAs" -> {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(MIME_TYPE)
                    .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                start(intent, REQUEST_SAVE, call.argument<String>("path"), result)
            }
            "open" -> {
                // O .bipa não tem tipo registrado: o Drive o mostra como zip
                // ou binário. A conferência recusa o que não for backup.
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                start(intent, REQUEST_OPEN, call.argument<String>("target"), result)
            }
            "openStore" -> {
                openStore()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(intent: Intent, requestCode: Int, path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("args", "falta o caminho", null)
            return
        }
        if (pending != null) {
            result.error("busy", "o seletor já está aberto", null)
            return
        }
        try {
            pending = result
            pendingPath = path
            activity.startActivityForResult(intent, requestCode)
        } catch (error: ActivityNotFoundException) {
            pending = null
            pendingPath = null
            result.error("unavailable", error.message, null)
        }
    }

    /** Devolve `true` quando a resposta do seletor era daqui. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return false
        val result = pending ?: return true
        val path = pendingPath
        pending = null
        pendingPath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            // A pessoa voltou sem escolher.
            result.success(null)
            return true
        }
        val resolver = activity.contentResolver
        io.execute {
            try {
                val answer: Any = if (requestCode == REQUEST_SAVE) {
                    File(path).inputStream().use { input ->
                        (resolver.openOutputStream(uri) ?: error("destino não abriu")).use { input.copyTo(it) }
                    }
                    true
                } else {
                    val name = displayName(uri)
                    (resolver.openInputStream(uri) ?: error("arquivo não abriu")).use { input ->
                        File(path).outputStream().use { input.copyTo(it) }
                    }
                    name
                }
                main.post { result.success(answer) }
            } catch (error: Exception) {
                main.post { result.error("io", error.message, null) }
            }
        }
        return true
    }

    /** O nome que o seletor mostra ("bipa-2026-10-12.bipa"), para a folha. */
    private fun displayName(uri: Uri): String {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0)?.let { return it }
        }
        return uri.lastPathSegment ?: ""
    }

    /** "Atualizar o Bipa": a página do app na loja, ou no navegador sem a loja. */
    private fun openStore() {
        val id = activity.packageName
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id")))
        } catch (_: ActivityNotFoundException) {
            try {
                activity.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$id")),
                )
            } catch (_: ActivityNotFoundException) {
                // Sem loja nem navegador: nada a abrir.
            }
        }
    }

    /** Sem a Activity, a resposta não vem: o Dart não fica esperando. */
    fun dispose() {
        pending?.success(null)
        pending = null
        pendingPath = null
        io.shutdown()
    }

    companion object {
        const val CHANNEL = "dev.l0rran.bipa/backup_files"
        private const val MIME_TYPE = "application/octet-stream"
        private const val REQUEST_SAVE = 7101
        private const val REQUEST_OPEN = 7102
    }
}
