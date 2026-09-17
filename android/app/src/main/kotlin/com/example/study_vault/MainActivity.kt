package com.example.study_vault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.study_vault/share_receiver"
    private var methodChannel: MethodChannel? = null
    private var initialSharedData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.let {
            initialSharedData = parseIntent(it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedData" -> {
                        result.success(initialSharedData)
                        initialSharedData = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = parseIntent(intent)
        if (data != null) {
            methodChannel?.invokeMethod("onNewSharedData", data)
        }
    }

    private fun parseIntent(intent: Intent): Map<String, Any?>? {
        val action = intent.action ?: return null

        if (action == Intent.ACTION_SEND) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            val streamUri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }

            if (streamUri != null) {
                val fileInfo = processUri(streamUri)
                if (fileInfo != null) {
                    return mapOf(
                        "type" to "files",
                        "files" to listOf(fileInfo),
                        "subject" to subject
                    )
                }
            }

            if (!text.isNullOrBlank()) {
                val trimmed = text.trim()
                val isUrl = trimmed.startsWith("http://", ignoreCase = true) || 
                            trimmed.startsWith("https://", ignoreCase = true)
                return mapOf(
                    "type" to if (isUrl) "url" else "text",
                    "text" to text,
                    "url" to if (isUrl) trimmed else null,
                    "subject" to subject
                )
            }
        } else if (action == Intent.ACTION_SEND_MULTIPLE) {
            val streamUris = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }

            if (streamUris != null && streamUris.isNotEmpty()) {
                val files = mutableListOf<Map<String, Any?>>()
                for (uri in streamUris) {
                    val fileInfo = processUri(uri)
                    if (fileInfo != null) {
                        files.add(fileInfo)
                    }
                }
                if (files.isNotEmpty()) {
                    return mapOf(
                        "type" to "files",
                        "files" to files,
                        "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT)
                    )
                }
            }
        }

        return null
    }

    private fun processUri(uri: Uri): Map<String, Any?>? {
        return try {
            val contentResolver = applicationContext.contentResolver
            var fileName = "shared_file_${UUID.randomUUID().toString().take(8)}"
            var fileSize = 0L

            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        val name = cursor.getString(nameIndex)
                        if (!name.isNullOrBlank()) {
                            fileName = name
                        }
                    }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex != -1) {
                        fileSize = cursor.getLong(sizeIndex)
                    }
                }
            }

            val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
            val cacheDir = File(cacheDir, "shared_imports").apply { mkdirs() }
            val destFile = File(cacheDir, "${UUID.randomUUID()}_$fileName")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (fileSize <= 0 && destFile.exists()) {
                fileSize = destFile.length()
            }

            mapOf(
                "fileName" to fileName,
                "filePath" to destFile.absolutePath,
                "fileSize" to fileSize,
                "mimeType" to mimeType
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
