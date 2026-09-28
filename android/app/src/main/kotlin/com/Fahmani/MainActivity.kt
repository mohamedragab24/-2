package com.Fahmani

import android.os.Bundle
import android.view.WindowManager
import android.app.Activity
import android.content.Context
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
        ensurePlugins(flutterEngine)

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
                "diagnostics" -> result.success(pluginReport)
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


    @Volatile
    private var pluginReport: String = "not-run"

    /**
     * Guarantees that the FlutterFire plugins are attached to this engine.
     * The automatic registration can silently fail (it only logs), which makes
     * every plugin channel fail with "channel-error". Registration is
     * idempotent (already-registered plugins are skipped), so it is safe to
     * repeat here. Reflection is used so this can never break compilation, and
     * the outcome is reported to Dart to make any remaining failure visible.
     */
    @Suppress("UNCHECKED_CAST")
    private fun ensurePlugins(engine: FlutterEngine) {
        val notes = StringBuilder()

        try {
            Class.forName("io.flutter.plugins.GeneratedPluginRegistrant")
                .getMethod("registerWith", FlutterEngine::class.java)
                .invoke(null, engine)
            notes.append("registrant=ok; ")
        } catch (t: Throwable) {
            val cause = t.cause ?: t
            notes.append("registrant=${cause.javaClass.simpleName}:${cause.message}; ")
        }

        try {
            val cls = Class.forName("io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin")
                as Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>
            if (engine.plugins.has(cls)) {
                notes.append("firebase_core=registered; ")
            } else {
                engine.plugins.add(cls.getDeclaredConstructor().newInstance())
                notes.append("firebase_core=added-manually; ")
            }
        } catch (t: Throwable) {
            val cause = t.cause ?: t
            notes.append("firebase_core=${cause.javaClass.simpleName}:${cause.message}; ")
        }

        pluginReport = notes.toString()
    }

    /**
     * Ensure the Android Firebase default app exists.
     * google-services.json + FirebaseInitProvider normally initialize it before
     * the Flutter engine; the explicit check also makes startup deterministic.
     */
    private fun ensureNativeFirebase(): Boolean {
        return FirebaseApp.getApps(this).any {
            it.name == FirebaseApp.DEFAULT_APP_NAME
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
