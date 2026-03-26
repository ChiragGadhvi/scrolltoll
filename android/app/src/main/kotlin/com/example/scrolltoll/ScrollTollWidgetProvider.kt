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
            val todayAmountString = prefs.getString("today_amount", "0")
            val todayAmount = todayAmountString?.toFloatOrNull() ?: 0f
            
            val budgetString = prefs.getString("daily_budget", "150")
            val budget = budgetString?.toFloatOrNull() ?: 150f

            val amountLeft = Math.max(0f, budget - todayAmount)
            val percentLeft = Math.max(0f, amountLeft / budget)
            
            val views = RemoteViews(context.packageName, R.layout.scrolltoll_widget_layout)

            // Map percentageRemaining logic
            val imageRes = when {
                percentLeft >= 0.8f -> R.drawable.jar_stage_1_full
                percentLeft >= 0.6f -> R.drawable.jar_stage_2_high
                percentLeft >= 0.4f -> R.drawable.jar_stage_3_half
                percentLeft >= 0.2f -> R.drawable.jar_stage_4_low
                else -> R.drawable.jar_stage_5_empty
            }

            views.setImageViewResource(R.id.widget_jar_image, imageRes)
            views.setTextViewText(R.id.widget_amount, "₹${amountLeft.toInt()} left")
            views.setProgressBar(R.id.widget_progress, 100, (percentLeft * 100).toInt(), false)

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
