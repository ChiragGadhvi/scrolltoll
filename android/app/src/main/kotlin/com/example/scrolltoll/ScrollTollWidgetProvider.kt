package com.example.scrolltoll

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class ScrollTollWidgetProvider : AppWidgetProvider() {

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
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val todayAmount = prefs.getString("today_amount", "0")?.toFloatOrNull() ?: 0f
            val yesterdayAmount = prefs.getString("yesterday_amount", "0")?.toFloatOrNull() ?: 0f

            val views = RemoteViews(context.packageName, R.layout.scrolltoll_widget_layout)
            views.setTextViewText(R.id.widget_amount, "\u20B9${todayAmount.toInt()}")

            val progress = if (yesterdayAmount > 0) {
                ((todayAmount / yesterdayAmount) * 100).toInt().coerceAtMost(100)
            } else 50
            views.setProgressBar(R.id.widget_progress, 100, progress, false)

            val compareText = when {
                yesterdayAmount <= 0 -> "vs yesterday"
                todayAmount > yesterdayAmount -> "\u25B2 more than yesterday"
                todayAmount < yesterdayAmount -> "\u25BC less than yesterday"
                else -> "same as yesterday"
            }
            views.setTextViewText(R.id.widget_compare, compareText)

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
