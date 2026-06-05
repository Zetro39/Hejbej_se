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
                    totalDistance = widgetData.getFloat("totalDistance", 0.0f).toDouble()
                } catch (e: Exception) {
                    try {
                        val strVal = widgetData.getString("totalDistance", "0.0")
                        totalDistance = strVal?.toDouble() ?: 0.0
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
