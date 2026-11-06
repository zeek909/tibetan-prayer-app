package com.tenzingtsewang.tibetan_prayer_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Home-screen widget: today's Tibetan date, any special day, and the prayer-flag rule. */
class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val key = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        var bo = "ཞལ་འདོན།"
        var en = "Open the app to load the calendar"
        var ev = ""
        var flag = ""
        try {
            val days = JSONObject(widgetData.getString("days", "{}") ?: "{}")
            if (days.has(key)) {
                val d = days.getJSONObject(key)
                bo = d.optString("bo", bo)
                en = d.optString("en", en)
                ev = d.optString("ev", "")
                flag = d.optString("flag", "")
            }
        } catch (e: Exception) {
        }
        val launch = Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        val pending = PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setTextViewText(R.id.widget_bo, bo)
                setTextViewText(R.id.widget_en, en)
                setTextViewText(R.id.widget_ev, if (ev.isEmpty()) flag else "$ev · $flag")
                setOnClickPendingIntent(R.id.widget_root, pending)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
