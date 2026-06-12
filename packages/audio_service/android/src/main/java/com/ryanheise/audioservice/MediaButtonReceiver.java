package com.ryanheise.audioservice;

import android.content.Context;
import android.content.Intent;

public class MediaButtonReceiver extends androidx.media.session.MediaButtonReceiver {
    public static final String ACTION_NOTIFICATION_DELETE = "com.ryanheise.audioservice.intent.action.ACTION_NOTIFICATION_DELETE";
    // Sonolyth patch: custom controls are also attached to the notification as
    // real action buttons (OEM SystemUIs like Vivo/Samsung render the
    // notification's actions instead of building the Android 13+ media card
    // from the session's PlaybackState, so session-only custom actions never
    // show there). Their PendingIntents broadcast this action here.
    public static final String ACTION_NOTIFICATION_CUSTOM_ACTION = "com.ryanheise.audioservice.intent.action.ACTION_NOTIFICATION_CUSTOM_ACTION";
    public static final String EXTRA_CUSTOM_ACTION_NAME = "com.ryanheise.audioservice.extra.CUSTOM_ACTION_NAME";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent != null
                && ACTION_NOTIFICATION_DELETE.equals(intent.getAction())
                && AudioService.instance != null) {
            AudioService.instance.handleDeleteNotification();
            return;
        }
        if (intent != null
                && ACTION_NOTIFICATION_CUSTOM_ACTION.equals(intent.getAction())
                && AudioService.instance != null) {
            AudioService.instance.handleCustomAction(
                    intent.getStringExtra(EXTRA_CUSTOM_ACTION_NAME));
            return;
        }
        // Sonolyth patch: while the service is alive, feed media-button
        // presses straight into its session instead of letting androidx
        // restart it via startForegroundService. After a pause the service is
        // detached from the foreground, and that restart is exactly what OEM
        // background-FGS restrictions (Vivo) reject — the press never reaches
        // the session and the notification's play button does nothing. The
        // super path stays for the cold-boot case (process death left a
        // notification behind), where there is no session to dispatch into.
        if (intent != null
                && Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction())
                && AudioService.instance != null) {
            AudioService.instance.handleMediaButton(intent);
            return;
        }
        super.onReceive(context, intent);
    }
}
