package com.samsung.reminder.reminder_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ReminderAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "ilmi_task_widget"
        const val KEY_COUNT = "today_count"
        const val KEY_TASK_1 = "task_1"
        const val KEY_TASK_2 = "task_2"
        const val ACTION_QUICK_ADD = "com.samsung.reminder.ACTION_QUICK_ADD"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val count = prefs.getInt(KEY_COUNT, 0)
            val task1 = prefs.getString(KEY_TASK_1, null)
            val task2 = prefs.getString(KEY_TASK_2, null)

            val views = RemoteViews(context.packageName, R.layout.widget_reminder_layout)

            // Update Header & Badge
            views.setTextViewText(R.id.widget_count_badge, "$count GÖREV")

            // Update Task 1 & 2
            if (task1 != null && task1.isNotEmpty()) {
                views.setTextViewText(R.id.widget_task_1, "• $task1")
            } else {
                views.setTextViewText(R.id.widget_task_1, "• Bugün için planlanan görev yok")
            }

            if (task2 != null && task2.isNotEmpty()) {
                views.setTextViewText(R.id.widget_task_2, "• $task2")
            } else {
                views.setTextViewText(R.id.widget_task_2, "• Dokun ve yeni görev oluştur")
            }

            // Click root to open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openPendingIntent)

            // Click '+' button to quick add
            val quickAddIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ADD
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val quickAddPendingIntent = PendingIntent.getActivity(
                context,
                1,
                quickAddIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_add, quickAddPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, ReminderAppWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateWidget(context, appWidgetManager, widgetId)
            }
        }
    }
}
