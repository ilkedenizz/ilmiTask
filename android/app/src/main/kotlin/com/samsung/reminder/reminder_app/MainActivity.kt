package com.samsung.reminder.reminder_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.samsung.reminder/widget"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val count = call.argument<Int>("todayCount") ?: 0
                    val task1 = call.argument<String>("task1")
                    val task2 = call.argument<String>("task2")

                    val prefs = getSharedPreferences(
                        ReminderAppWidgetProvider.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    prefs.edit()
                        .putInt(ReminderAppWidgetProvider.KEY_COUNT, count)
                        .putString(ReminderAppWidgetProvider.KEY_TASK_1, task1)
                        .putString(ReminderAppWidgetProvider.KEY_TASK_2, task2)
                        .apply()

                    ReminderAppWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "checkQuickAddIntent" -> {
                    val isQuickAdd = intent?.action == ReminderAppWidgetProvider.ACTION_QUICK_ADD
                    if (isQuickAdd) {
                        intent?.action = null // Reset so it doesn't re-trigger
                    }
                    result.success(isQuickAdd)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ReminderAppWidgetProvider.ACTION_QUICK_ADD) {
            channel?.invokeMethod("onQuickAddRequested", null)
            intent.action = null
        }
    }
}
