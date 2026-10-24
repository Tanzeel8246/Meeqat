package com.mindcraftsai.meeqat

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mindcraftsai.meeqat/widget_channel"
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "com.mindcraftsai.meeqat.ACTION_SOLAR_ARC_QUICK_VIEW") {
            pendingAction = "OPEN_SOLAR_ARC"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingWidgetAction" -> {
                    val action = pendingAction
                    pendingAction = null
                    result.success(action)
                }
                "updateWidgetData" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val prefs = getSharedPreferences(MeeqatClockWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        args.forEach { (key, value) ->
                            if (key is String && value is String) {
                                editor.putString(key, value)
                            }
                        }
                        editor.apply()
                        MeeqatClockWidgetProvider.updateAllWidgets(this)
                    }
                    result.success(true)
                }
                "pinWidgetToHomeScreen" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val myProvider = ComponentName(this, MeeqatClockWidgetProvider::class.java)
                        if (appWidgetManager.isRequestPinAppWidgetSupported) {
                            val successCallback = PendingIntent.getActivity(
                                this,
                                0,
                                Intent(this, MainActivity::class.java),
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            val requested = appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                            result.success(requested)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "setWidgetTheme" -> {
                    val theme = call.argument<String>("theme") ?: "midnight_gold"
                    val layout = call.argument<String>("layout") ?: "toggle"
                    val prefs = getSharedPreferences(MeeqatClockWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(MeeqatClockWidgetProvider.KEY_THEME, theme)
                        .putString(MeeqatClockWidgetProvider.KEY_LAYOUT, layout)
                        .apply()
                    MeeqatClockWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "getWidgetPreferences" -> {
                    val prefs = getSharedPreferences(MeeqatClockWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(mapOf(
                        "theme" to (prefs.getString(MeeqatClockWidgetProvider.KEY_THEME, "midnight_gold") ?: "midnight_gold"),
                        "layout" to (prefs.getString(MeeqatClockWidgetProvider.KEY_LAYOUT, "toggle") ?: "toggle")
                    ))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                            if (powerManager != null && !powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = android.net.Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "openExactAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "getDeviceManufacturer" -> {
                    result.success(Build.MANUFACTURER.lowercase())
                }
                "openBrandAutostartSettings" -> {
                    val mfr = Build.MANUFACTURER.lowercase()
                    var launched = false
                    try {
                        val intentsToTry = mutableListOf<Intent>()
                        when {
                            mfr.contains("xiaomi") || mfr.contains("redmi") || mfr.contains("poco") -> {
                                intentsToTry.add(Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")))
                                intentsToTry.add(Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings")))
                            }
                            mfr.contains("oppo") || mfr.contains("realme") || mfr.contains("oneplus") -> {
                                intentsToTry.add(Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")))
                                intentsToTry.add(Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")))
                                intentsToTry.add(Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")))
                            }
                            mfr.contains("vivo") || mfr.contains("iqoo") -> {
                                intentsToTry.add(Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")))
                                intentsToTry.add(Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")))
                            }
                            mfr.contains("huawei") || mfr.contains("honor") -> {
                                intentsToTry.add(Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")))
                                intentsToTry.add(Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.bootstart.BootStartActivity")))
                            }
                        }
                        // Fallback generic app details settings
                        intentsToTry.add(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        })

                        for (targetIntent in intentsToTry) {
                            try {
                                targetIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(targetIntent)
                                launched = true
                                break
                            } catch (_: Throwable) {}
                        }
                    } catch (e: Throwable) {
                        launched = false
                    }
                    result.success(launched)
                }
                else -> result.notImplemented()
            }
        }
    }
}
