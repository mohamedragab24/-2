package com.Fahmani

import android.os.Bundle
import android.view.WindowManager
import android.app.Activity
import android.app.Application
import com.google.firebase.FirebaseApp
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "masar_app/screen_protection"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize the native Firebase app as early as Android can. This
        // complements firebase_core and prevents startup from depending on a
        // Dart-side auto-configuration lookup.
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
        } catch (_: Exception) {
            // firebase_core will retry from Dart and expose the real error.
        }

        enableScreenProtection()
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, state: Bundle?) { activity.window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE) }
            override fun onActivityStarted(activity: Activity) { activity.window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE) }
            override fun onActivityResumed(activity: Activity) { activity.window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE) }
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    enableScreenProtection()
                    result.success(true)
                }

                "disable" -> {
                    disableScreenProtection()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun enableScreenProtection() {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    private fun disableScreenProtection() {
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
