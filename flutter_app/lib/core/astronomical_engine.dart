import 'dart:math' as math;

/// High-Precision Astronomical Calculation Engine in pure Dart
/// Supports exact seconds, adhan & end safety margins, Sehar & Iftar,
/// and Solar Qibla Alignment Times (90°, 135°, 180°).
class AstronomicalEngine {
  static const String methodKarachi = 'KARACHI'; // 18°, 18°
  static const String methodMwl = 'MWL';         // 18°, 17°
  static const String methodIsna = 'ISNA';       // 15°, 15°
  static const String methodUmmAlQura = 'UMM_AL_QURA'; // 18.5°, 90min

  static const int asrHanafi = 2;   // Shadow factor m = 2 (مثلِ ثانی)
  static const int asrStandard = 1; // Shafi'i / Hanbali / Maliki m = 1 (مثلِ اول)

  final double latitude;
  final double longitude;
  final double timeZone;
  final String method;
  final int asrJuristic;
  final double elevation;

  AstronomicalEngine({
    required this.latitude,
    required this.longitude,
    required this.timeZone,
    this.method = methodKarachi,
    this.asrJuristic = asrHanafi,
    this.elevation = 0.0,
    this.fajrMode,
    this.fajrDegree,
    this.fajrIntervalMin,
    this.ishaMode,
    this.ishaDegree,
    this.ishaIntervalMin,
    this.is12HourFormat = true,
  });

  final String? fajrMode;
  final double? fajrDegree;
  final double? fajrIntervalMin;
  final String? ishaMode;
  final double? ishaDegree;
  final double? ishaIntervalMin;
  final bool is12HourFormat;

  Map<String, dynamic> calculateDetailedTimes(DateTime date) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    double jd = _julianDay(year, month, day, 12.0);
    double t = (jd - 2451545.0) / 36525.0;

    Map<String, double> sun = _sunCoordinates(t);
    double delta = sun['declination']!;
    double et = sun['equation_of_time']!;

    // Solar transit in local hours
    double transit = 12.0 + timeZone - (longitude / 15.0) - et;

    double fajrAngleDeg = 18.0;
    double ishaAngleDeg = 18.0;
    int? ishaFixedMinutes;

    if (method == methodMwl) {
      fajrAngleDeg = 18.0;
      ishaAngleDeg = 17.0;
    } else if (method == methodIsna) {
      fajrAngleDeg = 15.0;
      ishaAngleDeg = 15.0;
    } else if (method == methodUmmAlQura) {
      fajrAngleDeg = 18.5;
      ishaFixedMinutes = 90;
    }

    if (fajrDegree != null) {
      fajrAngleDeg = fajrDegree!;
    }
    if (ishaDegree != null) {
      ishaAngleDeg = ishaDegree!;
    }

    double phi = _degToRad(latitude);
    double fajrAngle = _degToRad(fajrAngleDeg);
    double ishaAngle = _degToRad(ishaAngleDeg);

    // Horizon dip correction:
    // Fixed standard astronomical horizon: 50 arcminutes (34' refraction + 16' semidiameter = 0.8333°)
    // Authentic Pakistani calendars (Karachi, Banuri Town, Darul Uloom) and global standards use 0.8333°.
    const double horizonDip = 0.8333;
    final double horizonAngle = _degToRad(-horizonDip);

    // 1. Sunrise & Sunset
    double tSunrise = _hourAngle(phi, delta, horizonAngle);
    double exactSunrise = transit - tSunrise;
    double exactSunset = transit + tSunrise;

    // 2. Fajr (Degree vs Interval)
    double exactFajr;
    if (fajrMode == 'INTERVAL' && fajrIntervalMin != null) {
      exactFajr = exactSunrise - (fajrIntervalMin! / 60.0);
    } else {
      Map<String, double> sunFajr = _sunAtLocalHour(year, month, day, exactSunrise - 1.35);
      double tFajr = _hourAngle(phi, sunFajr['declination']!, -fajrAngle);
      exactFajr = transit - tFajr;
    }

    // 3. Solar Noon Transit

    // 4. Asr calculations (Both Shafi'i m=1 and Hanafi m=2)
    double zenithDistance = (phi - delta).abs();

    double cotH1 = 1.0 + math.tan(zenithDistance);
    double hAsrShafi = math.atan(1.0 / cotH1);
    double tAsrShafi = _hourAngle(phi, delta, hAsrShafi);
    double exactAsrShafi = transit + tAsrShafi;

    double cotH2 = 2.0 + math.tan(zenithDistance);
    double hAsrHanafi = math.atan(1.0 / cotH2);
    double tAsrHanafi = _hourAngle(phi, delta, hAsrHanafi);
    double exactAsrHanafi = transit + tAsrHanafi;

    double exactAsr = asrJuristic == asrHanafi ? exactAsrHanafi : exactAsrShafi;

    // 5. Maghrib & Sunset
    double exactMaghrib = exactSunset;

    // 6. Isha (Degree vs Interval vs Fixed Minutes)
    double exactIsha;
    if (ishaMode == 'INTERVAL' && ishaIntervalMin != null) {
      exactIsha = exactSunset + (ishaIntervalMin! / 60.0);
    } else if (ishaFixedMinutes != null && ishaMode != 'DEGREE') {
      exactIsha = exactMaghrib + (ishaFixedMinutes / 60.0);
    } else {
      double tIsha = _hourAngle(phi, delta, -ishaAngle);
      exactIsha = transit + tIsha;
    }

    // Comprehensive Shar'i & Astronomical Milestones:
    // Standard rule across all 12 months & Home Screen:
    // Previous prayer ends 1 min before (-1m), next starts exact, adhan 1 min after (+1m)
    double seharEnd = exactFajr - (1.0 / 60.0);
    double fajrStart = exactFajr;
    double fajrAdhan = exactFajr + (1.0 / 60.0);
    double fajrEnd = exactSunrise - (1.0 / 60.0);

    // Sunrise & Ishraq (10 min 40 sec after sunrise; ishraq start 1 min after)
    double ishraqTime = exactSunrise + (10.0 / 60.0) + (40.0 / 3600.0);
    double ishraqStart = ishraqTime + (1.0 / 60.0);

    // Nisf-un-Nahar Shar'i (Midpoint of Shar'i Day: Fajr to Sunset)
    double nisfNaharShari = exactFajr + (exactSunset - exactFajr) / 2.0;

    // Zawal / Istiwa interval (Makrooh duration centered around solar transit: ~5 mins total)
    double zawalStart = transit - (2.0 / 60.0) - (40.0 / 3600.0);
    double zawalEnd = transit + (2.0 / 60.0) + (24.0 / 3600.0);

    // Dhuhr: Begins at the conclusion of Zawal/Istiwa interval
    double dhuhrStart = zawalEnd;
    double dhuhrAdhan = dhuhrStart + (1.0 / 60.0);
    double dhuhrShafiEnd = exactAsrShafi - (1.0 / 60.0);
    double dhuhrHanafiEnd = exactAsrHanafi - (1.0 / 60.0);

    // Asr: Begins at the exact astronomical shadow threshold
    double asrShafiStart = exactAsrShafi;
    double asrShafiAdhan = exactAsrShafi + (1.0 / 60.0);
    double asrHanafiStart = exactAsrHanafi;
    double asrHanafiAdhan = exactAsrHanafi + (1.0 / 60.0);
    double asrMakrooh = exactSunset - (14.0 / 60.0) - (58.0 / 3600.0); // 15 mins before sunset (تغیرِ شمس)

    // Maghrib & Iftar: Begins at exact sunset, adhan / iftar 1 min after sunset (+1m), ends 1 min before Isha (-1m)
    double maghribSunset = exactSunset;
    double iftarAdhan = exactSunset + (1.0 / 60.0);
    double maghribEnd = exactIsha - (1.0 / 60.0);

    // Isha & Tahajjud: Begins at exact twilight angle (18° Jamhoor Consensus)
    double ishaStart = exactIsha;
    double ishaAdhan = exactIsha + (1.0 / 60.0);
    
    // Shar'i Night Duration: from Sunset to Subh Sadiq (Sehar End)
    double nightDuration = (24.0 - exactSunset) + seharEnd;
    double nisfShab = (exactSunset + (nightDuration / 2.0)) % 24.0;
    double ishaMakrooh = nisfShab;
    double ishaEnd = seharEnd;

    // Tahajjud Milestones
    double tahajjudThird = (exactSunset + nightDuration * (2.0 / 3.0)) % 24.0;
    double tahajjudSixth = (exactSunset + nightDuration * (5.0 / 6.0)) % 24.0;

    return {
      // Structured canonical nodes for each prayer card
      'fajr_card': {
        'sehar_end': _formatTimeWithSec(seharEnd),
        'start': _formatTimeWithSec(fajrStart),
        'adhan': _formatTimeWithSec(fajrAdhan),
        'end': _formatTimeWithSec(fajrEnd),
      },
      'sunrise_card': {
        'sunrise': _formatTimeWithSec(exactSunrise),
        'ishraq': _formatTimeWithSec(ishraqTime),
        'ishraq_start': _formatTimeWithSec(ishraqStart),
      },
      'nisf_nahar_card': {
        'time': _formatTimeWithSec(nisfNaharShari),
      },
      'zawal_card': {
        'nisf_nahar': _formatTimeWithSec(nisfNaharShari),
        'zawal': _formatTimeWithSec(zawalStart),
        'start': _formatTimeWithSec(zawalStart),
        'end': _formatTimeWithSec(zawalEnd),
      },
      'dhuhr_card': {
        'start': _formatTimeWithSec(dhuhrStart),
        'adhan': _formatTimeWithSec(dhuhrAdhan),
        'shafi_end': _formatTimeWithSec(dhuhrShafiEnd),
        'hanafi_end': _formatTimeWithSec(dhuhrHanafiEnd),
      },
      'asr_card': {
        'shafi_start': _formatTimeWithSec(asrShafiStart),
        'shafi_adhan': _formatTimeWithSec(asrShafiAdhan),
        'hanafi_start': _formatTimeWithSec(asrHanafiStart),
        'hanafi_adhan': _formatTimeWithSec(asrHanafiAdhan),
        'makrooh': _formatTimeWithSec(asrMakrooh),
      },
      'maghrib_card': {
        'sunset': _formatTimeWithSec(maghribSunset),
        'iftar_adhan': _formatTimeWithSec(iftarAdhan),
        'end': _formatTimeWithSec(maghribEnd),
      },
      'isha_card': {
        'start': _formatTimeWithSec(ishaStart),
        'adhan': _formatTimeWithSec(ishaAdhan),
        'makrooh': _formatTimeWithSec(ishaMakrooh),
        'end': _formatTimeWithSec(ishaEnd),
      },
      'tahajjud_card': {
        'third_start': _formatTimeWithSec(tahajjudThird),
        'sixth_start': _formatTimeWithSec(tahajjudSixth),
      },
      // Fasting Header
      'fasting': {
        'sehar_end': _formatTimeWithSec(seharEnd),
        'iftar_time': _formatTimeWithSec(iftarAdhan),
      },
      // Raw decimal values for calculations & comparisons
      'raw': {
        'sehar_end': seharEnd,
        'fajr': fajrStart,
        'fajr_start': fajrStart,
        'fajr_adhan': fajrAdhan,
        'fajr_end': fajrEnd,
        'sunrise': exactSunrise,
        'ishraq': ishraqTime,
        'nisf_nahar': nisfNaharShari,
        'zawal_start': zawalStart,
        'zawal_end': zawalEnd,
        'dhuhr': dhuhrStart,
        'dhuhr_start': dhuhrStart,
        'dhuhr_adhan': dhuhrAdhan,
        'dhuhr_shafi_end': dhuhrShafiEnd,
        'dhuhr_hanafi_end': dhuhrHanafiEnd,
        'asr_shafi': asrShafiStart,
        'asr_hanafi': asrHanafiStart,
        'asr_hanafi_adhan': asrHanafiAdhan,
        'asr_makrooh': asrMakrooh,
        'asr': exactAsr,
        'sunset': maghribSunset,
        'maghrib': iftarAdhan,
        'iftar_adhan': iftarAdhan,
        'maghrib_end': maghribEnd,
        'isha': ishaStart,
        'isha_start': ishaStart,
        'isha_adhan': ishaAdhan,
        'isha_makrooh': ishaMakrooh,
        'isha_end': ishaEnd,
        'tahajjud_third': tahajjudThird,
        'tahajjud_sixth': tahajjudSixth,
      },
      // Backward compatibility maps
      'exact': {
        'fajr': _formatTimeWithSec(fajrStart),
        'sunrise': _formatTimeWithSec(exactSunrise),
        'dhuhr': _formatTimeWithSec(dhuhrStart),
        'asr': _formatTimeWithSec(exactAsr),
        'maghrib': _formatTimeWithSec(exactMaghrib),
        'isha': _formatTimeWithSec(ishaStart),
      },
      'adhan': {
        'fajr': _formatTimeWithSec(fajrAdhan),
        'dhuhr': _formatTimeWithSec(dhuhrAdhan),
        'asr': _formatTimeWithSec(asrJuristic == asrHanafi ? asrHanafiAdhan : asrShafiAdhan),
        'maghrib': _formatTimeWithSec(iftarAdhan),
        'isha': _formatTimeWithSec(ishaAdhan),
      },
      'ending': {
        'fajr': _formatTimeWithSec(fajrEnd),
        'dhuhr': _formatTimeWithSec(asrJuristic == asrHanafi ? dhuhrHanafiEnd : dhuhrShafiEnd),
        'asr': _formatTimeWithSec(maghribSunset),
        'maghrib': _formatTimeWithSec(maghribEnd),
        'isha': _formatTimeWithSec(ishaEnd),
      },
      // Simple HH:mm
      'fajr': _formatTime(fajrStart),
      'sunrise': _formatTime(exactSunrise),
      'dhuhr': _formatTime(dhuhrStart),
      'asr': _formatTime(exactAsr),
      'maghrib': _formatTime(exactMaghrib),
      'isha': _formatTime(ishaStart),
    };
  }

  /// Backward compatible map
  Map<String, String> calculateTimes(DateTime date) {
    final detailed = calculateDetailedTimes(date);
    return {
      'fajr': detailed['fajr'] as String,
      'sunrise': detailed['sunrise'] as String,
      'dhuhr': detailed['dhuhr'] as String,
      'asr': detailed['asr'] as String,
      'maghrib': detailed['maghrib'] as String,
      'isha': detailed['isha'] as String,
    };
  }

  /// Solar Qibla times for the day using scan algorithm (matches solarQibla.ts)
  List<Map<String, dynamic>> calculateSolarQiblaTimes(DateTime date, double qiblaBearing) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    double jd = _julianDay(year, month, day, 12.0);
    double t = (jd - 2451545.0) / 36525.0;

    Map<String, double> sun = _sunCoordinates(t);
    double delta = sun['declination']!;
    double et = sun['equation_of_time']!;
    double transit = 12.0 + timeZone - (longitude / 15.0) - et;

    double phi = _degToRad(latitude);

    // Sunrise and sunset in local solar hours
    double horizonDip = 0.8333 + 0.0347 * math.sqrt(math.max(0.0, elevation));
    double horizonAngle = _degToRad(-horizonDip);
    double tSunriseH = _hourAngle(phi, delta, horizonAngle);
    double sunriseTime = transit - tSunriseH;
    double sunsetTime = transit + tSunriseH;

    // Normalize Qibla bearing to [0, 360)
    double q = (qiblaBearing % 360.0 + 360.0) % 360.0;

    double? findBestTime(List<double> candidateTargetAzimuths) {
      double bestDiff = 999.0;
      double? bestTime;
      double startH = sunriseTime + (3.0 / 60.0);
      double endH = sunsetTime - (3.0 / 60.0);

      double step = 0.5 / 60.0; // 30 seconds
      for (double h = startH; h <= endH; h += step) {
        double? az = _solarAzimuthAtTime(h, phi, delta, transit);
        if (az != null) {
          for (double targetAz in candidateTargetAzimuths) {
            double diff = (az - targetAz).abs();
            if (diff > 180.0) diff = 360.0 - diff;
            if (diff < bestDiff) {
              bestDiff = diff;
              bestTime = h;
            }
          }
        }
      }

      if (bestDiff <= 2.5 && bestTime != null) {
        double fineStart = bestTime - (1.0 / 60.0);
        double fineEnd = bestTime + (1.0 / 60.0);
        double fineStep = 1.0 / 3600.0;
        for (double fh = fineStart; fh <= fineEnd; fh += fineStep) {
          double? az = _solarAzimuthAtTime(fh, phi, delta, transit);
          if (az != null) {
            for (double targetAz in candidateTargetAzimuths) {
              double diff = (az - targetAz).abs();
              if (diff > 180.0) diff = 360.0 - diff;
              if (diff < bestDiff) {
                bestDiff = diff;
                bestTime = fh;
              }
            }
          }
        }
        return bestTime;
      }
      return null;
    }

    double? time0 = findBestTime([q]);
    double? time180 = findBestTime([(q + 180.0) % 360.0]);
    double? time90 = findBestTime([(q + 90.0) % 360.0, (q - 90.0 + 360.0) % 360.0]);
    double? time135 = findBestTime([
      (q + 135.0) % 360.0,
      (q - 135.0 + 360.0) % 360.0,
      (q + 45.0) % 360.0,
      (q - 45.0 + 360.0) % 360.0,
    ]);

    return [
      {
        'title': '0° کعبہ رخ پر سورج (Sun in Qibla)',
        'title_ur': '0° کعبہ رخ پر سورج',
        'title_en': '0° Sun in Qibla (Direct Kaaba Bearing)',
        'description': 'اس منتخب تاریخ کے اس وقت سورج کا رخ خود عین قبلہ کی سمت پر ہو گا۔ سورج کی طرف رخ کرنے سے عین خانہ کعبہ کی سمت حاصل ہو گی۔',
        'description_ur': 'اس منتخب تاریخ کے اس وقت سورج کا رخ خود عین قبلہ کی سمت پر ہو گا۔ سورج کی طرف رخ کرنے سے عین خانہ کعبہ کی سمت حاصل ہو گی۔',
        'description_en': 'At this time on the selected date, the Sun will align directly with the Qibla bearing. Facing the Sun directly faces the Holy Kaaba.',
        'angle': 0,
        'azimuth': q.toStringAsFixed(1),
        'time': time0 != null ? _formatTimeWithSec(time0) : 'اس تاریخ کو سورج اس زاویے پر افق سے اوپر نہیں آتا',
        'time_en': time0 != null ? _formatTimeWithSec(time0) : 'Sun does not reach this angle on this date',
        'is_observable': time0 != null,
      },
      {
        'title': '180° عین سمتِ قبلہ (Shadow Along Qibla)',
        'title_ur': '180° عین سمتِ قبلہ (شاخص کا سایہ)',
        'title_en': '180° Direct Qibla Axis (Stick Shadow)',
        'description': 'اس منتخب تاریخ کے اس وقت عمودی شاخص/لکڑی کا سایہ عین خانہ کعبہ کی سمت پڑے گا۔ سائے کے سرے کی طرف رخ قبلہ کی سیدھ ہو گی۔',
        'description_ur': 'اس منتخب تاریخ کے اس وقت عمودی شاخص/لکڑی کا سایہ عین خانہ کعبہ کی سمت پڑے گا۔ سائے کے سرے کی طرف رخ قبلہ کی سیدھ ہو گی۔',
        'description_en': 'At this time on the selected date, the shadow of a vertical stick will point directly along the Qibla axis towards the Holy Kaaba.',
        'angle': 180,
        'azimuth': ((q + 180.0) % 360.0).toStringAsFixed(1),
        'time': time180 != null ? _formatTimeWithSec(time180) : 'اس تاریخ کو سورج اس زاویے پر افق سے اوپر نہیں آتا',
        'time_en': time180 != null ? _formatTimeWithSec(time180) : 'Sun does not reach this angle on this date',
        'is_observable': time180 != null,
      },
      {
        'title': '90° عمودی زاویہ (صف کی سیدھ / Prayer Rows)',
        'title_ur': '90° عمودی زاویہ (صف کی سیدھ)',
        'title_en': '90° Perpendicular Angle (Prayer Rows / Saf)',
        'description': 'اس منتخب تاریخ کے اس وقت عمودی لکڑی کا سایہ 90° پر ہو گا۔ اس سائے کے متوازی کھینچی گئی لکیر مسجد میں نمازیوں کی صفوں کی بالکل سیدھی لکیر ہو گی۔',
        'description_ur': 'اس منتخب تاریخ کے اس وقت عمودی لکڑی کا سایہ 90° پر ہو گا۔ اس سائے کے متوازی کھینچی گئی لکیر مسجد میں نمازیوں کی صفوں کی بالکل سیدھی لکیر ہو گی۔',
        'description_en': 'At this time on the selected date, the shadow will lie at 90° perpendicular to Qibla. Drawing a line parallel to this shadow will align prayer rows precisely.',
        'angle': 90,
        'azimuth': ((q + 90.0) % 360.0).toStringAsFixed(1),
        'time': time90 != null ? _formatTimeWithSec(time90) : 'اس تاریخ کو سورج اس زاویے پر افق سے اوپر نہیں آتا',
        'time_en': time90 != null ? _formatTimeWithSec(time90) : 'Sun does not reach this angle on this date',
        'is_observable': time90 != null,
      },
      {
        'title': '135° ترچھا زاویہ (کارنر و محراب / Diagonal)',
        'title_ur': '135° ترچھا زاویہ (کارنر و محراب)',
        'title_en': '135° Diagonal Angle (Mihrab & Corners)',
        'description': 'اس منتخب تاریخ کے اس وقت سورج 135° ترچھے زاویے پر ہو گا۔ یہ وقت محراب، عمارت کے کونوں اور ترچھی دیواروں کی سیدھ کی جانچ کے لیے کارآمد ہو گا۔',
        'description_ur': 'اس منتخب تاریخ کے اس وقت سورج 135° ترچھے زاویے پر ہو گا۔ یہ وقت محراب، عمارت کے کونوں اور ترچھی دیواروں کی سیدھ کی جانچ کے لیے کارآمد ہو گا۔',
        'description_en': 'At this time on the selected date, the Sun will reach a 135° diagonal angle, ideal for verifying mihrab and corner alignment of mosques.',
        'angle': 135,
        'azimuth': ((q + 135.0) % 360.0).toStringAsFixed(1),
        'time': time135 != null ? _formatTimeWithSec(time135) : 'اس تاریخ کو سورج اس زاویے پر افق سے اوپر نہیں آتا',
        'time_en': time135 != null ? _formatTimeWithSec(time135) : 'Sun does not reach this angle on this date',
        'is_observable': time135 != null,
      },
    ];
  }

  double? _solarAzimuthAtTime(double hours, double phi, double delta, double transit) {
    double hDeg = (hours - transit) * 15.0;
    double hRad = _degToRad(hDeg);

    double sinAlt = math.sin(phi) * math.sin(delta) + math.cos(phi) * math.cos(delta) * math.cos(hRad);
    if (sinAlt <= -0.01) return null; // Sun below horizon

    double x = -math.sin(hRad) * math.cos(delta);
    double y = math.cos(phi) * math.sin(delta) - math.sin(phi) * math.cos(delta) * math.cos(hRad);

    double azRad = math.atan2(x, y);
    double azDeg = (_radToDeg(azRad) + 360.0) % 360.0;
    return azDeg;
  }

  double _hourAngle(double phi, double delta, double altitude) {
    double cosH = (math.sin(altitude) - math.sin(phi) * math.sin(delta)) /
        (math.cos(phi) * math.cos(delta));
    if (cosH > 1.0) return 0.0;
    if (cosH < -1.0) return 12.0;
    double hRad = math.acos(cosH);
    return _radToDeg(hRad) / 15.0;
  }

  double _julianDay(int year, int month, int day, double utcHours) {
    int y = year;
    int m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    int a = (y / 100.0).floor();
    int b = 2 - a + (a / 4.0).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5 +
        (utcHours / 24.0);
  }

  Map<String, double> _sunAtLocalHour(int year, int month, int day, double localHour) {
    double utcHour = localHour - timeZone;
    double jd = _julianDay(year, month, day, utcHour);
    double t = (jd - 2451545.0) / 36525.0;
    return _sunCoordinates(t);
  }

  Map<String, double> _sunCoordinates(double t) {
    double l0 = (280.46646 + 36000.76983 * t + 0.0003032 * (t * t)) % 360.0;
    if (l0 < 0) l0 += 360.0;

    double m = (357.52911 + 35999.05029 * t - 0.0001537 * (t * t)) % 360.0;
    if (m < 0) m += 360.0;
    double mRad = _degToRad(m);

    double c = (1.914602 - 0.004817 * t - 0.000014 * (t * t)) * math.sin(mRad) +
        (0.019993 - 0.000101 * t) * math.sin(2.0 * mRad) +
        0.000289 * math.sin(3.0 * mRad);

    double trueLong = l0 + c;
    double eps0 = 23.43929111 - 0.013004167 * t;

    double omega = _degToRad(125.04 - 1934.136 * t);
    double lambda = _degToRad(trueLong - 0.00569 - 0.00478 * math.sin(omega));
    double eps = _degToRad(eps0 + 0.00256 * math.cos(omega));

    double delta = math.asin(math.sin(eps) * math.sin(lambda));

    double y = math.pow(math.tan(eps / 2.0), 2).toDouble();
    double l0Rad = _degToRad(l0);
    double ecc = 0.016708634 - 0.000042037 * t;

    double eTime = y * math.sin(2.0 * l0Rad) -
        2.0 * ecc * math.sin(mRad) +
        4.0 * ecc * y * math.sin(mRad) * math.cos(2.0 * l0Rad) -
        0.5 * (y * y) * math.sin(4.0 * l0Rad) -
        1.25 * (ecc * ecc) * math.sin(2.0 * mRad);

    double equationOfTimeHours = _radToDeg(eTime) * 4.0 / 60.0;

    return {
      'declination': delta,
      'equation_of_time': equationOfTimeHours,
    };
  }

  String _formatTime(double hours) {
    return formatTimeDynamic(hours, withSeconds: false, is12h: is12HourFormat);
  }

  String _formatTimeWithSec(double hours) {
    return formatTimeDynamic(hours, withSeconds: true, is12h: is12HourFormat);
  }

  static String formatTimeDynamic(double hours, {bool withSeconds = true, bool is12h = true}) {
    double h = hours % 24.0;
    if (h < 0) h += 24.0;
    int totalSec = (h * 3600.0).round();
    totalSec = (totalSec % 86400 + 86400) % 86400;

    int hour = totalSec ~/ 3600;
    int rem = totalSec % 3600;
    int min = rem ~/ 60;
    int sec = rem % 60;

    if (!is12h) {
      if (withSeconds) {
        return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
      } else {
        return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
      }
    }

    String period = hour >= 12 ? 'PM' : 'AM';
    int h12 = hour % 12;
    if (h12 == 0) h12 = 12;

    if (withSeconds) {
      return '\u200E${h12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')} $period\u200E';
    } else {
      return '\u200E${h12.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $period\u200E';
    }
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / math.pi);
}
