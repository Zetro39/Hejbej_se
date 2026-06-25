package com.example.hejbej_se

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.lang.Exception

class HejbejSeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.hejbej_se_widget).apply {
                var totalDistance = 0.0
                try {
                    val rawVal = widgetData.all["totalDistance"]
                    if (rawVal != null) {
                        totalDistance = when (rawVal) {
                            is Float -> rawVal.toDouble()
                            is Double -> rawVal
                            is Int -> rawVal.toDouble()
                            is Long -> rawVal.toDouble()
                            is String -> rawVal.toDoubleOrNull() ?: 0.0
                            else -> 0.0
                        }
                    }
                } catch (e: Exception) {
                    try {
                        totalDistance = widgetData.getFloat("totalDistance", 0.0f).toDouble()
                    } catch (ex: Exception) {}
                }

                val streak = widgetData.getInt("streak", 0)

                setTextViewText(R.id.widget_distance, String.format("Dnes: %.1f km", totalDistance))
                setTextViewText(R.id.widget_streak, String.format("Série: 🔥 %d dnů", streak))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
