package com.ezrasong.sonolyth

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val accentChannelName = "com.ezrasong.sonolyth/system_accent"

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
