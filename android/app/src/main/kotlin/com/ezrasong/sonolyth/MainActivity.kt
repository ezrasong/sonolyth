package com.ezrasong.sonolyth

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val channelName = "com.ezrasong.sonolyth/spotiflac"
    private val accentChannelName = "com.ezrasong.sonolyth/system_accent"
    private val spotiFlacPackage = "com.zarz.spotiflac"
    private val spotiFlacDownloadUrl = "https://github.com/spotiflacapp/SpotiFLAC-Mobile"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadUrl" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    if (url.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    result.success(openSpotiFlac(url))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, accentChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAccentColor" -> result.success(getSystemAccentColor())
                else -> result.notImplemented()
            }
        }
    }

    private fun getSystemAccentColor(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return null
        }

        val accentResourceId = resources.getIdentifier(
            "system_accent1_600",
            "color",
            "android"
        )

        if (accentResourceId == 0) {
            return null
        }

        return resources.getColor(accentResourceId, theme)
    }

    private fun openSpotiFlac(url: String): Boolean {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            setPackage(spotiFlacPackage)
            putExtra(Intent.EXTRA_TEXT, url)
        }
        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage(spotiFlacPackage)
        }

        return try {
            startActivity(shareIntent)
            true
        } catch (_: ActivityNotFoundException) {
            try {
                startActivity(viewIntent)
                true
            } catch (_: ActivityNotFoundException) {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(spotiFlacDownloadUrl))
                )
                false
            }
        }
    }
}
