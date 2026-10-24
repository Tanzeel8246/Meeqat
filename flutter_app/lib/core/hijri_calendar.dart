import 'dart:math' as math;

class HijriCalendar {
  static const List<String> monthsUrdu = [
    '',
    'محرم الحرام',
    'صفر المظفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاول',
    'جمادی الثانی',
    'رجب المرجب',
    'شعبان المعظم',
    'رمضان المبارک',
    'شوال المکرم',
    'ذی القعدہ',
    'ذی الحجہ',
  ];

  static const List<String> monthsEn = [
    '',
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' ath-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah'
  ];

  static String getMonthName(int m, {bool isUrdu = true}) {
    if (m >= 1 && m <= 12) {
      return isUrdu ? monthsUrdu[m] : monthsEn[m];
    }
    return '';
  }

  static Map<String, dynamic> fromGregorian(DateTime date, {int adjustmentDays = 0}) {
    DateTime dt = date.add(Duration(days: adjustmentDays));
    int y = dt.year;
    int m = dt.month;
    int d = dt.day;

    if (m < 3) {
      y -= 1;
      m += 12;
    }

    int a = (y / 100.0).floor();
    int b = 2 - a + (a / 4.0).floor();
    double jd = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;

    double epoch = 1948439.5;
    double daysSinceEpoch = jd - epoch;

    double cycleNumber = (daysSinceEpoch / 10631.0).floorToDouble();
    double dayInCycle = daysSinceEpoch - (cycleNumber * 10631.0);

    double yearInCycle = ((dayInCycle + 0.5) / 354.366).floorToDouble();
    int hijriYear = (cycleNumber * 30 + yearInCycle + 1).toInt();

    double dayInYear = dayInCycle - (yearInCycle * 354.366).floorToDouble();
    int hijriMonth = (dayInYear / 29.5).ceil().clamp(1, 12);
    int hijriDay = (dayInYear - ((hijriMonth - 1) * 29.5)).round().clamp(1, 30);

    String monthUrdu = monthsUrdu[hijriMonth];
    String monthEn = monthsEn[hijriMonth];

    return {
      'year': hijriYear,
      'month': hijriMonth,
      'day': hijriDay,
      'month_urdu': monthUrdu,
      'month_en': monthEn,
      'month_name_urdu': monthUrdu,
      'month_name_en': monthEn,
      'formatted_urdu': '$hijriDay $monthUrdu $hijriYearھ',
      'formatted_en': '$hijriDay $monthEn $hijriYear AH',
    };
  }

  /// Calculates astronomical moon birth and visibility window
  static Map<String, dynamic> getMoonSightingInfo(DateTime date, {double tz = 5.0}) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    int y = year;
    int m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    int a = (y / 100.0).floor();
    int b = 2 - a + (a / 4.0).floor();
    double jd = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5 +
        0.5;

    const double knownNewMoonJD = 2451549.26; // 2000-01-06 18:14 UTC
    const double synodicMonth = 29.53058867;

    double cycles = (jd - knownNewMoonJD) / synodicMonth;
    double currentCycleIndex = cycles.floorToDouble();
    double moonAgeDays = (cycles - currentCycleIndex) * synodicMonth;
    double moonAgeHours = moonAgeDays * 24.0;

    double conjunctionJD = knownNewMoonJD + (currentCycleIndex * synodicMonth);
    DateTime conjunctionDate = _jdToDateTime(conjunctionJD, tz);

    double nextConjunctionJD = conjunctionJD + synodicMonth;
    DateTime nextConjunctionDate = _jdToDateTime(nextConjunctionJD, tz);

    double phaseAngle = (moonAgeDays / synodicMonth) * 2.0 * math.pi;
    double illuminationPercent = (1.0 - math.cos(phaseAngle)) / 2.0 * 100.0;

    String visibilityStatusUr;
    String visibilityStatusEn;
    String visibilityDescUr;
    String visibilityDescEn;

    if (moonAgeHours < 12.0) {
      visibilityStatusUr = 'رویت ناممکن ہے';
      visibilityStatusEn = 'Sighting Impossible (Not Visible)';
      visibilityDescUr = 'چاند کی عمر ۱۲ گھنٹے سے کم ہے۔ سورج سے دوری انتہائی قلیل ہے، آنکھ یا کیمرے سے دیکھنا ممکن نہیں۔';
      visibilityDescEn = 'Moon age is below 12 hours. Angular separation from sun is too small to be seen.';
    } else if (moonAgeHours < 18.0) {
      visibilityStatusUr = 'دوربین سے ممکن ہے';
      visibilityStatusEn = 'Visible with Optical Aid / Telescope';
      visibilityDescUr = 'چاند کی عمر ۱۲ تا ۱۸ گھنٹے ہے۔ صاف مطلع میں دوربین یا فلکیاتی ٹیلی اسکوپ سے رویت ہو سکتی ہے۔';
      visibilityDescEn = 'Moon age is 12 to 18 hours. May be observed in clear skies using binoculars or telescopes.';
    } else {
      visibilityStatusUr = 'عام آنکھ سے رویت کا قوی امکان ہے';
      visibilityStatusEn = 'Naked Eye Sighting Highly Likely';
      visibilityDescUr = 'چاند کی عمر ۱۸ گھنٹے سے زائد ہو چکی ہے۔ مطلع صاف ہونے کی صورت میں غروبِ آفتاب کے بعد عام آنکھ سے باآسانی نظر آ سکتا ہے۔';
      visibilityDescEn = 'Moon age exceeds 18 hours. Clearly visible to the naked eye after sunset in good conditions.';
    }

    return {
      'moon_age_days': moonAgeDays.toStringAsFixed(1),
      'moon_age_hours': moonAgeHours.toStringAsFixed(1),
      'illumination_percent': illuminationPercent.toStringAsFixed(1),
      'conjunction_birth_str': _formatDateStr(conjunctionDate, isUrdu: true),
      'conjunction_birth_str_ur': _formatDateStr(conjunctionDate, isUrdu: true),
      'conjunction_birth_str_en': _formatDateStr(conjunctionDate, isUrdu: false),
      'next_conjunction_str': _formatDateStr(nextConjunctionDate, isUrdu: true),
      'next_conjunction_str_ur': _formatDateStr(nextConjunctionDate, isUrdu: true),
      'next_conjunction_str_en': _formatDateStr(nextConjunctionDate, isUrdu: false),
      'visibility_status_ur': visibilityStatusUr,
      'visibility_status_en': visibilityStatusEn,
      'visibility_desc_ur': visibilityDescUr,
      'visibility_desc_en': visibilityDescEn,
      'visibility_status': visibilityStatusUr,
      'visibility_desc': visibilityDescUr,
      'best_sighting_window_ur': 'غروبِ آفتاب کے فوراً بعد ۳۵ تا ۴۵ منٹ تک',
      'best_sighting_window_en': '35 to 45 minutes immediately after Sunset',
      'best_sighting_window': 'غروبِ آفتاب کے فوراً بعد ۳۵ تا ۴۵ منٹ تک',
    };
  }

  static DateTime _jdToDateTime(double jd, double tz) {
    double z = (jd + 0.5).floorToDouble();
    double f = (jd + 0.5) - z;
    double a;
    if (z < 2299161) {
      a = z;
    } else {
      double alpha = ((z - 1867216.25) / 36524.25).floorToDouble();
      a = z + 1 + alpha - (alpha / 4.0).floorToDouble();
    }
    double b = a + 1524;
    double c = ((b - 122.1) / 365.25).floorToDouble();
    double d = (365.25 * c).floorToDouble();
    double e = ((b - d) / 30.6001).floorToDouble();

    int day = (b - d - (30.6001 * e).floorToDouble()).toInt();
    int month = (e < 14) ? (e - 1).toInt() : (e - 13).toInt();
    int year = (month > 2) ? (c - 4716).toInt() : (c - 4715).toInt();

    double hours = f * 24.0 + tz;
    int h = hours.floor() % 24;
    int m = ((hours - hours.floor()) * 60.0).floor();
    int s = ((((hours - hours.floor()) * 60.0) - m) * 60.0).floor();

    return DateTime(year, month, day, h, m, s);
  }

  static String _formatDateStr(DateTime dt, {bool isUrdu = true}) {
    final connector = isUrdu ? 'بوقت' : 'at';
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} $connector ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
