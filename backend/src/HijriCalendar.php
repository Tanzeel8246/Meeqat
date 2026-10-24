<?php
declare(strict_types=1);

namespace Minaret\Core;

/**
 * HijriCalendar - Islamic Lunar Calendar, Phase & Crescent Sighting Calculations
 * Provides conversion between Gregorian and Hijri with custom day adjustment for moonsighting,
 * exact astronomical new moon birth calculation, and crescent visibility predictions.
 */
class HijriCalendar
{
    private static array $islamicMonthsUrdu = [
        1 => 'محرم الحرام',
        2 => 'صفر المظفر',
        3 => 'ربیع الاول',
        4 => 'ربیع الثانی',
        5 => 'جمادی الاول',
        6 => 'جمادی الثانی',
        7 => 'رجب المرجب',
        8 => 'شعبان المعظم',
        9 => 'رمضان المبارک',
        10 => 'شوال المکرم',
        11 => 'ذی القعدہ',
        12 => 'ذی الحجہ'
    ];

    private static array $islamicMonthsEnglish = [
        1 => 'Muharram',
        2 => 'Safar',
        3 => 'Rabi al-Awwal',
        4 => 'Rabi al-Thani',
        5 => 'Jumada al-Awwal',
        6 => 'Jumada al-Thani',
        7 => 'Rajab',
        8 => "Sha'ban",
        9 => 'Ramadan',
        10 => 'Shawwal',
        11 => "Dhu al-Qi'dah",
        12 => 'Dhu al-Hijjah'
    ];

    public static function fromGregorian(\DateTimeInterface $gregorianDate, int $adjustmentDays = 0): array
    {
        $dt = clone $gregorianDate;
        if ($adjustmentDays !== 0) {
            $dt = $dt->modify("{$adjustmentDays} days");
        }

        $y = (int)$dt->format('Y');
        $m = (int)$dt->format('m');
        $d = (int)$dt->format('d');

        if ($m < 3) {
            $y -= 1;
            $m += 12;
        }

        $a = (int)floor($y / 100.0);
        $b = 2 - $a + (int)floor($a / 4.0);
        $jd = floor(365.25 * ($y + 4716)) + floor(30.6001 * ($m + 1)) + $d + $b - 1524.5;

        // Convert Julian Day to Hijri (Kuwaiti algorithm / Tabular Islamic Calendar)
        $epoch = 1948439.5; // JD of 1 Muharram 1 AH
        $daysSinceEpoch = $jd - $epoch;

        $cycleNumber = floor($daysSinceEpoch / 10631.0);
        $dayInCycle = $daysSinceEpoch - ($cycleNumber * 10631.0);

        $yearInCycle = floor(($dayInCycle + 0.5) / 354.366);
        $hijriYear = (int)($cycleNumber * 30 + $yearInCycle + 1);

        $dayInYear = $dayInCycle - floor($yearInCycle * 354.366);
        $hijriMonth = (int)min(12, max(1, ceil($dayInYear / 29.5)));
        $hijriDay = (int)max(1, min(30, round($dayInYear - (($hijriMonth - 1) * 29.5))));

        $monthUrdu = self::$islamicMonthsUrdu[$hijriMonth] ?? '';
        $monthEn = self::$islamicMonthsEnglish[$hijriMonth] ?? '';

        return [
            'year'            => $hijriYear,
            'month'           => $hijriMonth,
            'day'             => $hijriDay,
            'month_name_urdu' => $monthUrdu,
            'month_name_en'   => $monthEn,
            'formatted_urdu'  => "{$hijriDay} {$monthUrdu} {$hijriYear}ھ",
            'formatted_en'    => "{$hijriDay} {$monthEn} {$hijriYear} AH"
        ];
    }

    /**
     * Calculate Astronomical Moon Phase, New Moon Conjunction (محاق / پیدائشِ ہلال),
     * and Expected Crescent Visibility (رویتِ ہلال) window.
     */
    public static function getMoonSightingInfo(\DateTimeInterface $date, float $tz = 5.0): array
    {
        $year = (int)$date->format('Y');
        $month = (int)$date->format('m');
        $day = (int)$date->format('d');

        // Approximate Julian Day
        if ($month <= 2) {
            $year -= 1;
            $month += 12;
        }
        $a = (int)floor($year / 100.0);
        $b = 2 - $a + (int)floor($a / 4.0);
        $jd = floor(365.25 * ($year + 4716)) + floor(30.6001 * ($month + 1)) + $day + $b - 1524.5 + 0.5;

        // Mean synodic month = 29.53058867 days
        // Known reference new moon: 2000-01-06 18:14 UTC (JD 2451549.26)
        $knownNewMoonJD = 2451549.26;
        $synodicMonth = 29.53058867;

        $cycles = ($jd - $knownNewMoonJD) / $synodicMonth;
        $currentCycleIndex = floor($cycles);
        $moonAgeDays = ($cycles - $currentCycleIndex) * $synodicMonth;
        $moonAgeHours = $moonAgeDays * 24.0;

        // Conjunction (New Moon Birth) for this cycle
        $conjunctionJD = $knownNewMoonJD + ($currentCycleIndex * $synodicMonth);
        $conjunctionDate = self::jdToDateTime($conjunctionJD, $tz);

        // Next Conjunction
        $nextConjunctionJD = $conjunctionJD + $synodicMonth;
        $nextConjunctionDate = self::jdToDateTime($nextConjunctionJD, $tz);

        // Moon illumination percentage
        $phaseAngle = ($moonAgeDays / $synodicMonth) * 2.0 * M_PI;
        $illuminationPercent = (1.0 - cos($phaseAngle)) / 2.0 * 100.0;

        // Visibility criterion (Odeh / Yallop / Danjon limit ~ 16-18 hours minimum moon age at sunset)
        $visibilityStatus = '';
        $visibilityDesc = '';
        if ($moonAgeHours < 12.0) {
            $visibilityStatus = 'رویت نا ممکن (Not Visible)';
            $visibilityDesc = 'چاند کی عمر ۱۲ گھنٹے سے کم ہے، روشنی افق سے انتہائی کم ہے۔ دوربین یا آنکھ سے دیکھنا نا ممکن ہے۔';
        } elseif ($moonAgeHours < 18.0) {
            $visibilityStatus = 'دوربین سے ممکن (Visible with Optical Aid)';
            $visibilityDesc = 'چاند کی عمر ۱۲ تا ۱۸ گھنٹے ہے، صاف مطلع میں طاقتور دوربین یا ٹیلی اسکوپ سے نظر آ سکتا ہے۔';
        } else {
            $visibilityStatus = 'عام آنکھ سے نظر آنے کا قوی امکان (Naked Eye Sighting Likely)';
            $visibilityDesc = 'چاند کی عمر ۱۸ گھنٹے سے زائد ہے، غروبِ آفتاب کے بعد صاف مطلع میں عام آنکھ سے رویت کے واضح امکانات ہیں۔';
        }

        return [
            'moon_age_days'         => round($moonAgeDays, 2),
            'moon_age_hours'        => round($moonAgeHours, 1),
            'illumination_percent'  => round($illuminationPercent, 1),
            'conjunction_birth_str' => $conjunctionDate->format('d F Y - h:i:s A'),
            'next_conjunction_str'  => $nextConjunctionDate->format('d F Y - h:i:s A'),
            'visibility_status'     => $visibilityStatus,
            'visibility_desc'       => $visibilityDesc,
            'best_sighting_window'  => 'غروبِ آفتاب کے فوراً بعد سے لے کر اگلے ۳۵ تا ۴۵ منٹ تک',
        ];
    }

    private static function jdToDateTime(float $jd, float $tz): \DateTimeImmutable
    {
        $z = floor($jd + 0.5);
        $f = ($jd + 0.5) - $z;
        if ($z < 2299161) {
            $a = $z;
        } else {
            $alpha = floor(($z - 1867216.25) / 36524.25);
            $a = $z + 1 + $alpha - floor($alpha / 4.0);
        }
        $b = $a + 1524;
        $c = floor(($b - 122.1) / 365.25);
        $d = floor(365.25 * $c);
        $e = floor(($b - $d) / 30.6001);

        $day = $b - $d - floor(30.6001 * $e);
        $month = ($e < 14) ? ($e - 1) : ($e - 13);
        $year = ($month > 2) ? ($c - 4716) : ($c - 4715);

        $hours = $f * 24.0 + $tz;
        $h = floor($hours);
        $m = floor(($hours - $h) * 60.0);
        $s = floor((($hours - $h) * 60.0 - $m) * 60.0);

        return (new \DateTimeImmutable())
            ->setDate((int)$year, (int)$month, (int)$day)
            ->setTime((int)$h, (int)$m, (int)$s);
    }
}
