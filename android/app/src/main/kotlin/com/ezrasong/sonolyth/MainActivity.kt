package com.ezrasong.sonolyth

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val accentChannelName = "com.ezrasong.sonolyth/system_accent"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+ blocks the media playback notification until the user
        // grants POST_NOTIFICATIONS; declaring it in the manifest alone is
        // not enough, so prompt once on first launch.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
