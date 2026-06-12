package com.ezrasong.sonolyth

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val accentChannelName = "com.ezrasong.sonolyth/system_accent"
    private val updaterChannelName = "com.ezrasong.sonolyth/updater"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                // The in-app updater can't hand a downloaded APK to the
                // package installer until the user allows installs from this
                // app; open_file only reports the denial, so the settings
                // toggle has to be opened from here.
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
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
