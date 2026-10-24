package com.mindcraftsai.meeqat

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import org.json.JSONObject
import java.util.Calendar

class MeeqatClockWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "MeeqatWidgetProvider"
        const val ACTION_TOGGLE_SOLAR_ARC = "com.mindcraftsai.meeqat.ACTION_TOGGLE_SOLAR_ARC"
        const val ACTION_ALARM_TRANSITION = "com.mindcraftsai.meeqat.ACTION_ALARM_TRANSITION"
        const val PREFS_NAME = "MeeqatWidgetPrefs"
        const val KEY_EXPANDED = "widget_solar_arc_expanded"
        const val KEY_THEME = "widget_theme"
        const val KEY_LAYOUT = "widget_layout" // "toggle", "always_on", "circular"

        private var cachedNastaleeqTypeface: Typeface? = null

        fun renderNastaleeqBitmap(
            context: Context,
            text: String,
            textSizeSp: Float,
            textColor: Int,
            bold: Boolean = true
        ): Bitmap {
            if (text.isEmpty()) {
                return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            }
            if (cachedNastaleeqTypeface == null) {
                try {
                    cachedNastaleeqTypeface = ResourcesCompat.getFont(context, R.font.jameel_noori_nastaleeq)
                } catch (t: Throwable) {
                    Log.w(TAG, "Failed loading jameel_noori_nastaleeq font", t)
                }
            }
            val density = context.resources.displayMetrics.density
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.typeface = cachedNastaleeqTypeface ?: Typeface.DEFAULT_BOLD
                this.textSize = textSizeSp * density
                this.color = textColor
                this.isFakeBoldText = bold
                setShadowLayer(4f * density, 0f, 1.5f * density, Color.parseColor("#E6000000"))
            }
            val bounds = Rect()
            paint.getTextBounds(text, 0, text.length, bounds)
            val padH = (8 * density).toInt()
            val padV = (5 * density).toInt()
            val width = (bounds.width() + padH * 2).coerceAtLeast(1)
            val height = (bounds.height() + padV * 2).coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val x = (width - bounds.width()) / 2f - bounds.left
            val y = (height - bounds.height()) / 2f - bounds.top
            canvas.drawText(text, x, y, paint)
            return bitmap
        }

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, MeeqatClockWidgetProvider::class.java)
                )
                for (appWidgetId in ids) {
                    updateWidget(context, appWidgetManager, appWidgetId)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to update all widgets", e)
            }
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_meeqat_clock_layout)
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val theme = prefs.getString(KEY_THEME, "midnight_gold") ?: "midnight_gold"
                val layoutMode = prefs.getString(KEY_LAYOUT, "toggle") ?: "toggle"
                val isExpanded = if (layoutMode == "always_on") true else prefs.getBoolean(KEY_EXPANDED, false)

                // Background styling
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val bgRes = if (layoutMode == "circular") {
                            R.drawable.widget_bg_circle_transparent
                        } else {
                            R.drawable.widget_bg_transparent
                        }
                        views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)
                    } catch (t: Throwable) {
                        Log.w(TAG, "setBackgroundResource not supported", t)
                    }
                }

                // Serene, tranquil, spiritually satisfying color palettes
                val clockMainColor: Int
                val clockSecColor: Int
                val clockAmpmColor: Int
                val titleColor: Int
                val defaultLabelColor: Int
                val defaultTimeColor: Int
                val activeHighlightColor: Int

                when (theme) {
                    "emerald" -> { // زمردی سکون
                        clockMainColor = Color.parseColor("#FFFFFF")
                        clockSecColor = Color.parseColor("#6EE7B7")
                        clockAmpmColor = Color.parseColor("#A7F3D0")
                        titleColor = Color.parseColor("#34D399")
                        defaultLabelColor = Color.parseColor("#A7F3D0")
                        defaultTimeColor = Color.parseColor("#FFFFFF")
                        activeHighlightColor = Color.parseColor("#10B981")
                    }
                    "pure_black" -> { // نقرئی و بلوری
                        clockMainColor = Color.parseColor("#FFFFFF")
                        clockSecColor = Color.parseColor("#94A3B8")
                        clockAmpmColor = Color.parseColor("#CBD5E1")
                        titleColor = Color.parseColor("#E2E8F0")
                        defaultLabelColor = Color.parseColor("#CBD5E1")
                        defaultTimeColor = Color.parseColor("#FFFFFF")
                        activeHighlightColor = Color.parseColor("#38BDF8")
                    }
                    "warm_amber" -> { // شفق و عنبر
                        clockMainColor = Color.parseColor("#FFFFFF")
                        clockSecColor = Color.parseColor("#FDE68A")
                        clockAmpmColor = Color.parseColor("#FBBF24")
                        titleColor = Color.parseColor("#F59E0B")
                        defaultLabelColor = Color.parseColor("#FDE68A")
                        defaultTimeColor = Color.parseColor("#FFFFFF")
                        activeHighlightColor = Color.parseColor("#F59E0B")
                    }
                    else -> { // midnight_gold (نور و وقار - Luminous Warm White & Sacred Champagne Gold)
                        clockMainColor = Color.parseColor("#FFFFFF")
                        clockSecColor = Color.parseColor("#FDE68A")
                        clockAmpmColor = Color.parseColor("#CBD5E1")
                        titleColor = Color.parseColor("#FDE68A")
                        defaultLabelColor = Color.parseColor("#FDE68A")
                        defaultTimeColor = Color.parseColor("#FFFFFF")
                        activeHighlightColor = Color.parseColor("#34D399")
                    }
                }

                views.setTextColor(R.id.widget_text_clock_main, clockMainColor)
                views.setTextColor(R.id.widget_text_clock_sec, clockSecColor)

                // Main Clock AM/PM Indicator restored as requested
                views.setTextColor(R.id.widget_text_clock_ampm, clockAmpmColor)
                views.setViewVisibility(R.id.widget_text_clock_ampm, View.VISIBLE)

                views.setTextColor(R.id.widget_toggle_hint, titleColor)

                // Toggle broadcast intent (does NOT launch app)
                val toggleIntent = Intent(context, MeeqatClockWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE_SOLAR_ARC
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_clock_section, togglePendingIntent)
                views.setOnClickPendingIntent(R.id.widget_root, togglePendingIntent)

                // =========================================================================
                // FULLY DYNAMIC DATE, PRAYER TIMES, AND NEXT-PRAYER ROLLOVER CALCULATION
                // =========================================================================
                val now = Calendar.getInstance()
                val currentYear = now.get(Calendar.YEAR)
                val currentMonth = now.get(Calendar.MONTH) + 1
                val currentDay = now.get(Calendar.DAY_OF_MONTH)
                val currentMinute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

                val todayKey = String.format("%04d_%02d_%02d", currentYear, currentMonth, currentDay)
                val monthlyJsonStr = prefs.getString("monthly_schedule_json", null)

                var fajr = ""
                var sunrise = ""
                var nisfNahar = ""
                var dhuhr = ""
                var asr = ""
                var maghrib = ""
                var isha = ""

                var fajrMin = -1
                var sunriseMin = -1
                var dhuhrMin = -1
                var asrMin = -1
                var maghribMin = -1
                var ishaMin = -1

                var tomorrowFajr = ""
                var tomorrowFajrMin = -1

                // 1. Try to load from precalculated monthly schedule
                if (!monthlyJsonStr.isNullOrEmpty()) {
                    try {
                        val rootJson = JSONObject(monthlyJsonStr)
                        if (rootJson.has(todayKey)) {
                            val todayObj = rootJson.getJSONObject(todayKey)
                            fajr = todayObj.optString("fajr", "")
                            sunrise = todayObj.optString("sunrise", "")
                            nisfNahar = todayObj.optString("nisf_nahar", "")
                            dhuhr = todayObj.optString("dhuhr", "")
                            asr = todayObj.optString("asr", "")
                            maghrib = todayObj.optString("maghrib", "")
                            isha = todayObj.optString("isha", "")

                            fajrMin = todayObj.optInt("fajr_min", MeeqatAstro.parseTimeToMinutes(fajr))
                            sunriseMin = todayObj.optInt("sunrise_min", MeeqatAstro.parseTimeToMinutes(sunrise))
                            dhuhrMin = todayObj.optInt("dhuhr_min", MeeqatAstro.parseTimeToMinutes(dhuhr))
                            asrMin = todayObj.optInt("asr_min", MeeqatAstro.parseTimeToMinutes(asr))
                            maghribMin = todayObj.optInt("maghrib_min", MeeqatAstro.parseTimeToMinutes(maghrib))
                            ishaMin = todayObj.optInt("isha_min", MeeqatAstro.parseTimeToMinutes(isha))
                        }

                        // Also fetch tomorrow's Fajr
                        val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                        val tomorrowKey = String.format("%04d_%02d_%02d", tomorrowCal.get(Calendar.YEAR), tomorrowCal.get(Calendar.MONTH) + 1, tomorrowCal.get(Calendar.DAY_OF_MONTH))
                        if (rootJson.has(tomorrowKey)) {
                            val tomObj = rootJson.getJSONObject(tomorrowKey)
                            tomorrowFajr = tomObj.optString("fajr", "")
                            tomorrowFajrMin = tomObj.optInt("fajr_min", MeeqatAstro.parseTimeToMinutes(tomorrowFajr))
                        }
                    } catch (e: Throwable) {
                        Log.w(TAG, "Failed reading monthly_schedule_json", e)
                    }
                }

                // 2. Fallback to native astronomical computation if schedule not available or expired
                if (fajr.isEmpty() || fajrMin < 0) {
                    val lat = prefs.getString("latitude", "31.8878")?.toDoubleOrNull() ?: 31.8878
                    val lng = prefs.getString("longitude", "72.4125")?.toDoubleOrNull() ?: 72.4125
                    val tz = prefs.getString("timezone", "5.0")?.toDoubleOrNull() ?: 5.0
                    val isHanafi = prefs.getString("asr_method", "2") != "1"

                    val todaySched = MeeqatAstro.calculateDaySchedule(currentYear, currentMonth, currentDay, lat, lng, tz, isHanafi)
                    fajr = todaySched.fajr
                    sunrise = todaySched.sunrise
                    nisfNahar = todaySched.nisfNahar
                    dhuhr = todaySched.dhuhr
                    asr = todaySched.asr
                    maghrib = todaySched.maghrib
                    isha = todaySched.isha

                    fajrMin = todaySched.fajrMin
                    sunriseMin = todaySched.sunriseMin
                    dhuhrMin = todaySched.dhuhrMin
                    asrMin = todaySched.asrMin
                    maghribMin = todaySched.maghribMin
                    ishaMin = todaySched.ishaMin

                    val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                    val tomSched = MeeqatAstro.calculateDaySchedule(
                        tomorrowCal.get(Calendar.YEAR),
                        tomorrowCal.get(Calendar.MONTH) + 1,
                        tomorrowCal.get(Calendar.DAY_OF_MONTH),
                        lat, lng, tz, isHanafi
                    )
                    tomorrowFajr = tomSched.fajr
                    tomorrowFajrMin = tomSched.fajrMin
                }

                if (tomorrowFajr.isEmpty()) {
                    tomorrowFajr = fajr
                    tomorrowFajrMin = fajrMin
                }

                // 3. Deterministic calculation of current active upcoming prayer & next transition alarm
                val activeNextName: String
                val activeNextTime: String
                val nextTransitionCal = Calendar.getInstance().apply {
                    set(Calendar.SECOND, 1)
                    set(Calendar.MILLISECOND, 0)
                }

                if (currentMinute < fajrMin) {
                    activeNextName = "فجر"
                    activeNextTime = fajr
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, fajrMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, fajrMin % 60)
                } else if (currentMinute < sunriseMin) {
                    activeNextName = "طلوع"
                    activeNextTime = sunrise
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, sunriseMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, sunriseMin % 60)
                } else if (currentMinute < dhuhrMin) {
                    activeNextName = "ظہر"
                    activeNextTime = dhuhr
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, dhuhrMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, dhuhrMin % 60)
                } else if (currentMinute < asrMin) {
                    activeNextName = "عصر"
                    activeNextTime = asr
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, asrMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, asrMin % 60)
                } else if (currentMinute < maghribMin) {
                    activeNextName = "مغرب"
                    activeNextTime = maghrib
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, maghribMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, maghribMin % 60)
                } else if (currentMinute < ishaMin) {
                    activeNextName = "عشاء"
                    activeNextTime = isha
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, ishaMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, ishaMin % 60)
                } else {
                    // Past Isha -> Next is tomorrow's Fajr
                    activeNextName = "فجر"
                    activeNextTime = tomorrowFajr
                    nextTransitionCal.add(Calendar.DAY_OF_YEAR, 1)
                    nextTransitionCal.set(Calendar.HOUR_OF_DAY, tomorrowFajrMin / 60)
                    nextTransitionCal.set(Calendar.MINUTE, tomorrowFajrMin % 60)
                }

                // Render Subtitle: اگلی نماز in authentic Jameel Noori Nastaleeq Bitmap
                val titleText = "اگلی نماز: $activeNextName $activeNextTime"
                views.setImageViewBitmap(
                    R.id.widget_next_prayer_title,
                    renderNastaleeqBitmap(context, titleText, 13.5f, titleColor, true)
                )
                views.setTextViewText(R.id.widget_toggle_hint, if (isExpanded) "▴" else "▾")

                // Wing visibility (umbrella open / closed)
                val wingVisibility = if (isExpanded && layoutMode != "circular") View.VISIBLE else View.GONE
                views.setViewVisibility(R.id.widget_left_wing, wingVisibility)
                views.setViewVisibility(R.id.widget_right_wing, wingVisibility)
                views.setViewVisibility(R.id.widget_bottom_wing, wingVisibility)

                // Highlight active upcoming prayer
                val isNextFajr = activeNextName == "فجر"
                val isNextSunrise = activeNextName == "طلوع"
                val isNextDhuhr = activeNextName == "ظہر"
                val isNextAsr = activeNextName == "عصر"
                val isNextMaghrib = activeNextName == "مغرب"
                val isNextIsha = activeNextName == "عشاء"

                // Render all prayer titles & times in 100% authentic Jameel Noori Nastaleeq Bitmaps
                // Strictly 12-hour format WITHOUT AM/PM for prayer times
                views.setImageViewBitmap(
                    R.id.widget_fajr_label,
                    renderNastaleeqBitmap(context, "فجر", 13f, if (isNextFajr) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_fajr_time,
                    renderNastaleeqBitmap(context, fajr, 12f, if (isNextFajr) activeHighlightColor else defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_sunrise_label,
                    renderNastaleeqBitmap(context, "طلوع", 13f, if (isNextSunrise) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_sunrise_time,
                    renderNastaleeqBitmap(context, sunrise, 12f, if (isNextSunrise) activeHighlightColor else defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_nisf_nahar_label,
                    renderNastaleeqBitmap(context, "نصف النہار", 12.5f, defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_nisf_nahar_time,
                    renderNastaleeqBitmap(context, nisfNahar, 12f, defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_dhuhr_label,
                    renderNastaleeqBitmap(context, "ظہر", 13f, if (isNextDhuhr) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_dhuhr_time,
                    renderNastaleeqBitmap(context, dhuhr, 12f, if (isNextDhuhr) activeHighlightColor else defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_asr_label,
                    renderNastaleeqBitmap(context, "عصر", 13f, if (isNextAsr) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_asr_time,
                    renderNastaleeqBitmap(context, asr, 12f, if (isNextAsr) activeHighlightColor else defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_maghrib_label,
                    renderNastaleeqBitmap(context, "مغرب", 13f, if (isNextMaghrib) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_maghrib_time,
                    renderNastaleeqBitmap(context, maghrib, 12f, if (isNextMaghrib) activeHighlightColor else defaultTimeColor, true)
                )

                views.setImageViewBitmap(
                    R.id.widget_isha_label,
                    renderNastaleeqBitmap(context, "عشاء", 13f, if (isNextIsha) activeHighlightColor else defaultLabelColor, true)
                )
                views.setImageViewBitmap(
                    R.id.widget_isha_time,
                    renderNastaleeqBitmap(context, isha, 12f, if (isNextIsha) activeHighlightColor else defaultTimeColor, true)
                )

                appWidgetManager.updateAppWidget(appWidgetId, views)

                // 4. Schedule exact transition alarm to flip to next prayer at the exact minute
                scheduleTransitionWakeup(context, nextTransitionCal.timeInMillis)

                // 5. Also schedule midnight rollover at 00:00:05
                val midnightCal = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 5)
                    set(Calendar.MILLISECOND, 0)
                }
                scheduleMidnightWakeup(context, midnightCal.timeInMillis)

            } catch (e: Throwable) {
                Log.e(TAG, "Fatal error updating widget $appWidgetId", e)
            }
        }

        private fun scheduleTransitionWakeup(context: Context, triggerTimeMillis: Long) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, MeeqatClockWidgetProvider::class.java).apply {
                    action = ACTION_ALARM_TRANSITION
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    2001,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val info = AlarmManager.AlarmClockInfo(triggerTimeMillis, pendingIntent)
                    alarmManager.setAlarmClock(info, pendingIntent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to schedule widget transition wakeup", t)
            }
        }

        private fun scheduleMidnightWakeup(context: Context, triggerTimeMillis: Long) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, MeeqatClockWidgetProvider::class.java).apply {
                    action = ACTION_ALARM_TRANSITION
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    2002,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val info = AlarmManager.AlarmClockInfo(triggerTimeMillis, pendingIntent)
                    alarmManager.setAlarmClock(info, pendingIntent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to schedule midnight rollover wakeup", t)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TOGGLE_SOLAR_ARC -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val layoutMode = prefs.getString(KEY_LAYOUT, "toggle") ?: "toggle"
                if (layoutMode != "always_on") {
                    val isExpanded = prefs.getBoolean(KEY_EXPANDED, false)
                    prefs.edit().putBoolean(KEY_EXPANDED, !isExpanded).apply()
                    updateAllWidgets(context)
                }
            }
            ACTION_ALARM_TRANSITION,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED -> {
                updateAllWidgets(context)
            }
            else -> {
                super.onReceive(context, intent)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
