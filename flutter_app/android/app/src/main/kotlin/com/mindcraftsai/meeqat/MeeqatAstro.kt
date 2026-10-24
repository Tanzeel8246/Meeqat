package com.mindcraftsai.meeqat

import kotlin.math.*

/**
 * High-precision astronomical prayer calculation engine in native Kotlin.
 * Guarantees that the Meeqat Home Screen Widget can accurately compute daily prayer times
 * and rollover at midnight without requiring the Flutter app to run in the background.
 */
object MeeqatAstro {

    data class PrayerSchedule(
        val fajr: String,
        val sunrise: String,
        val nisfNahar: String,
        val dhuhr: String,
        val asr: String,
        val maghrib: String,
        val isha: String,
        val fajrMin: Int,
        val sunriseMin: Int,
        val nisfNaharMin: Int,
        val dhuhrMin: Int,
        val asrMin: Int,
        val maghribMin: Int,
        val ishaMin: Int
    )

    fun calculateDaySchedule(
        year: Int,
        month: Int,
        day: Int,
        latitude: Double,
        longitude: Double,
        timeZone: Double,
        isHanafi: Boolean = true
    ): PrayerSchedule {
        val jd = julianDate(year, month, day) - 2451545.0
        val g = fixAngle(357.529 + 0.98560028 * jd)
        val q = fixAngle(280.459 + 0.98564736 * jd)
        val l = fixAngle(q + 1.915 * sin(Math.toRadians(g)) + 0.020 * sin(Math.toRadians(2.0 * g)))
        val e = 23.439 - 0.00000036 * jd
        val ra = Math.toDegrees(atan2(cos(Math.toRadians(e)) * sin(Math.toRadians(l)), cos(Math.toRadians(l)))) / 15.0
        val decl = Math.toDegrees(asin(sin(Math.toRadians(e)) * sin(Math.toRadians(l))))
        val eqT = (q / 15.0) - fixHour(ra)

        val noon = fixHour(12.0 + timeZone - (longitude / 15.0) - eqT)

        // Sunrise & Sunset (geometric 0.833 deg)
        val sunAlt = -0.833
        val sunriseDiff = sunAngleDiff(sunAlt, latitude, decl) ?: 6.0
        val sunriseHour = noon - sunriseDiff
        val sunsetHour = noon + sunriseDiff

        // Fajr (18 degrees Jamhoor)
        val fajrDiff = sunAngleDiff(-18.0, latitude, decl) ?: 1.5
        val fajrHour = noon - fajrDiff

        // Isha (18 degrees Jamhoor)
        val ishaDiff = sunAngleDiff(-18.0, latitude, decl) ?: 1.5
        val ishaHour = noon + ishaDiff

        // Asr (Hanafi shadow = 2, Shafi shadow = 1)
        val shadowFactor = if (isHanafi) 2.0 else 1.0
        val asrAngle = Math.toDegrees(atan(1.0 / (shadowFactor + tan(Math.toRadians(abs(latitude - decl))))))
        val asrDiff = sunAngleDiff(asrAngle, latitude, decl) ?: 3.5
        val asrHour = noon + asrDiff

        // Nisf Nahar (10 minutes before Dhuhr Zawal)
        val nisfNaharHour = noon - (10.0 / 60.0)

        val fajrMin = toMinutesFromMidnight(fajrHour)
        val sunriseMin = toMinutesFromMidnight(sunriseHour)
        val nisfNaharMin = toMinutesFromMidnight(nisfNaharHour)
        val dhuhrMin = toMinutesFromMidnight(noon)
        val asrMin = toMinutesFromMidnight(asrHour)
        val maghribMin = toMinutesFromMidnight(sunsetHour)
        val ishaMin = toMinutesFromMidnight(ishaHour)

        return PrayerSchedule(
            fajr = formatTime(fajrMin),
            sunrise = formatTime(sunriseMin),
            nisfNahar = formatTime(nisfNaharMin),
            dhuhr = formatTime(dhuhrMin),
            asr = formatTime(asrMin),
            maghrib = formatTime(maghribMin),
            isha = formatTime(ishaMin),
            fajrMin = fajrMin,
            sunriseMin = sunriseMin,
            nisfNaharMin = nisfNaharMin,
            dhuhrMin = dhuhrMin,
            asrMin = asrMin,
            maghribMin = maghribMin,
            ishaMin = ishaMin
        )
    }

    private fun sunAngleDiff(angle: Double, lat: Double, decl: Double): Double? {
        val cosDiff = (sin(Math.toRadians(angle)) - sin(Math.toRadians(lat)) * sin(Math.toRadians(decl))) /
                (cos(Math.toRadians(lat)) * cos(Math.toRadians(decl)))
        if (cosDiff < -1.0 || cosDiff > 1.0) return null
        return Math.toDegrees(acos(cosDiff)) / 15.0
    }

    private fun fixAngle(a: Double): Double {
        var x = a - 360.0 * floor(a / 360.0)
        if (x < 0) x += 360.0
        return x
    }

    private fun fixHour(h: Double): Double {
        var x = h - 24.0 * floor(h / 24.0)
        if (x < 0) x += 24.0
        return x
    }

    private fun julianDate(year: Int, month: Int, day: Int): Double {
        var y = year
        var m = month
        if (m <= 2) {
            y -= 1
            m += 12
        }
        val a = floor(y / 100.0)
        val b = 2 - a + floor(a / 4.0)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }

    private fun toMinutesFromMidnight(hours: Double): Int {
        val fixed = fixHour(hours)
        return (fixed * 60.0).roundToInt() % 1440
    }

    fun formatTime(totalMinutes: Int): String {
        val m = totalMinutes % 1440
        val rawH = m / 60
        val mins = m % 60
        val h12 = if (rawH % 12 == 0) 12 else rawH % 12
        return String.format("%02d:%02d", h12, mins)
    }

    fun parseTimeToMinutes(timeStr: String?): Int {
        if (timeStr.isNullOrEmpty() || !timeStr.contains(":")) return -1
        return try {
            val clean = timeStr.replace(Regex("[^0-9:]"), "").trim()
            val parts = clean.split(":")
            val h = parts[0].toInt()
            val m = parts[1].toInt()
            h * 60 + m
        } catch (_: Throwable) {
            -1
        }
    }
}
