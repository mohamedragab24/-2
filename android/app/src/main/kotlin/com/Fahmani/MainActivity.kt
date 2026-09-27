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
    private val firebaseChannelName = "masar_app/firebase"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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
            firebaseChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureInitialized" -> {
                    try {
                        result.success(ensureNativeFirebase())
                    } catch (e: Exception) {
                        result.error("FIREBASE_NATIVE_INIT", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

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


    /**
     * Ensure the native default FirebaseApp exists.
     *
     * FirebaseInitProvider normally creates it before MainActivity starts.
     * Calling initializeApp() again is safe: Firebase returns the existing
     * default app when it has already been created. This intentionally avoids
     * reflection because R8 can rename FirebaseApp/getApps in release builds,
     * which caused the previous V33 failure.
     */
    private fun ensureNativeFirebase(): Boolean {
        return FirebaseApp.initializeApp(this) != null
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
