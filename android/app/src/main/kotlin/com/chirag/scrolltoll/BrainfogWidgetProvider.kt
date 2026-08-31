package com.chirag.scrolltoll

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Build
import android.widget.RemoteViews

/**
 * Home widget showing today's Rotto score and the pose that goes with it.
 *
 * Reads the snapshot Home pushes through the `home_widget` plugin
 * (see `_updateHomeWidget` in lib/screens/home_screen.dart). It renders only
 * what it is given — no usage querying and no threshold maths of its own.
 */
class BrainfogWidgetProvider : AppWidgetProvider() {

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
        private const val COLOR_SCORE_TEXT = 0xFF000000.toInt()

        private fun characterForState(state: String): Int = when (state) {
            "noEnergy" -> R.drawable.rotto_noenergy
            "bingeMode" -> R.drawable.rotto_bingemode
            "tired" -> R.drawable.rotto_tired
            "scrolling" -> R.drawable.rotto_scrolling
            else -> R.drawable.rotto_energetic
        }

        /** Mirrors RottoCharacter.nameFor (lib/utils/rotto_character.dart). */
        private fun nameForState(state: String): String = when (state) {
            "noEnergy" -> "No Energy"
            "bingeMode" -> "Binge Mode"
            "tired" -> "Tired"
            "scrolling" -> "Scrolling"
            else -> "Energetic"
        }

        // Same shape as formatDuration in lib/utils/format_utils.dart.
        private fun formatDuration(minutes: Int): String {
            if (minutes < 60) return "${minutes}m"
            val h = minutes / 60
            val m = minutes % 60
            return if (m == 0) "${h}h" else "${h}h ${m}m"
        }

        @Volatile
        private var cachedTypeface: Typeface? = null

        /**
         * Poppins Black (res/font/poppins_black.ttf) loaded in this app's own
         * process, where custom font resolution actually works -- unlike the
         * widget's inflated XML layout (see scrolltoll_widget_layout.xml).
         * Resources.getFont needs API 26; below that we fall back to the
         * platform bold face rather than crash.
         */
        private fun poppinsBlack(context: Context): Typeface {
            cachedTypeface?.let { return it }
            val loaded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    context.resources.getFont(R.font.poppins_black)
                } catch (e: Exception) {
                    Typeface.DEFAULT_BOLD
                }
            } else {
                Typeface.DEFAULT_BOLD
            }
            cachedTypeface = loaded
            return loaded
        }

        /**
         * Renders the score in Poppins Black to a tightly-cropped bitmap, so
         * the widget can show it via setImageViewBitmap instead of relying on
         * RemoteViews' unreliable custom-font support.
         */
        private fun scoreBitmap(context: Context, text: String, color: Int): Bitmap {
            val density = context.resources.displayMetrics.density
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = poppinsBlack(context)
                textSize = 32f * density
                this.color = color
            }
            val bounds = Rect()
            paint.getTextBounds(text, 0, text.length, bounds)
            val width = paint.measureText(text).toInt().coerceAtLeast(1)
            val height = bounds.height().coerceAtLeast(1)

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            Canvas(bitmap).drawText(text, -bounds.left.toFloat(), -bounds.top.toFloat(), paint)
            return bitmap
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            val trackedMinutes = prefs.getString("tracked_minutes", null)?.toIntOrNull()
            val score = prefs.getString("rotto_score", "100")?.toIntOrNull() ?: 100
            val state = prefs.getString("rotto_state", "energetic") ?: "energetic"

            val views = RemoteViews(context.packageName, R.layout.scrolltoll_widget_layout)

            // Just the number. It is a score out of 100 and reads as one, so
            // "/100" was noise at widget size.
            val headline = if (trackedMinutes == null) "–" else "$score"
            views.setImageViewBitmap(
                R.id.widget_remaining,
                scoreBitmap(context, headline, COLOR_SCORE_TEXT),
            )

            views.setImageViewResource(R.id.widget_character, characterForState(state))

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
