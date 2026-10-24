<?php
declare(strict_types=1);

namespace Minaret\Core;

/**
 * AstronomicalCore - High-Precision Islamic Prayer Times Calculator
 * Based on celestial mechanics and Dr. S. Kamal Abdali's astronomical methods.
 * Enhanced with Exact Seconds, Safety Margins, Sehar & Iftar, and Solar Qibla Alignment.
 */
class AstronomicalCore
{
    // Calculation Methods
    public const METHOD_KARACHI = 'KARACHI'; // University of Islamic Sciences, Karachi (Fajr: 18°, Isha: 18°)
    public const METHOD_MWL     = 'MWL';     // Muslim World League (Fajr: 18°, Isha: 17°)
    public const METHOD_ISNA    = 'ISNA';    // Islamic Society of North America (Fajr: 15°, Isha: 15°)
    public const METHOD_UMM_AL_QURA = 'UMM_AL_QURA'; // Makkah (Fajr: 18.5°, Isha: 90 min after Maghrib)
    public const METHOD_EGYPT   = 'EGYPT';   // Egyptian General Authority (Fajr: 19.5°, Isha: 17.5°)

    // Juristic Methods for Asr
    public const ASR_HANAFI   = 2; // Shadow ratio m = 2 (مثلِ ثانی)
    public const ASR_STANDARD = 1; // Shafi'i, Maliki, Hanbali m = 1 (مثلِ اول)

    private float $latitude;
    private float $longitude;
    private float $timeZone;
    private string $method;
    private int $asrJuristic;
    private float $elevation; // in meters

    public function __construct(
        float $latitude,
        float $longitude,
        float $timeZone,
        string $method = self::METHOD_KARACHI,
        int $asrJuristic = self::ASR_HANAFI,
        float $elevation = 0.0
    ) {
        $this->latitude = $latitude;
        $this->longitude = $longitude;
        $this->timeZone = $timeZone;
        $this->method = $method;
        $this->asrJuristic = $asrJuristic;
        $this->elevation = $elevation;
    }

    /**
     * Calculate comprehensive prayer times with exact seconds, safety adjustments, and fasting times.
     */
    public function calculateTimes(\DateTimeInterface $date): array
    {
        $year = (int)$date->format('Y');
        $month = (int)$date->format('m');
        $day = (int)$date->format('d');

        // Julian Day calculation for noon UTC
        $jd = $this->julianDay($year, $month, $day, 12.0);
        $t = ($jd - 2451545.0) / 36525.0; // Julian Centuries from J2000.0

        // Solar coordinates
        $sunCoords = $this->sunCoordinates($t);
        $delta = $sunCoords['declination']; // in radians
        $et = $sunCoords['equation_of_time']; // in hours

        // Solar Transit (Zawal / Midday in local solar hours)
        $transit = 12.0 + $this->timeZone - ($this->longitude / 15.0) - $et;

        // Angles based on method
        $params = $this->getMethodParameters($this->method);
        $fajrAngle = deg2rad($params['fajr']);
        $ishaAngle = deg2rad($params['isha']);

        $phi = deg2rad($this->latitude);

        // Horizon dip correction (0.8333° standard astronomical horizon for authentic timetables)
        $horizonDip = 0.8333;
        $horizonAngle = deg2rad(-$horizonDip);

        // 1. Sunrise & Sunset
        $tSunrise = $this->hourAngle($phi, $delta, $horizonAngle);
        $exactSunrise = $transit - $tSunrise;
        $exactSunset = $transit + $tSunrise;

        // 2. Fajr (Exact astronomical twilight start)
        $tFajr = $this->hourAngle($phi, $delta, -$fajrAngle);
        $exactFajr = $transit - $tFajr;

        // 3. Dhuhr (True Solar Noon)
        $exactDhuhr = $transit;

        // 4. Asr calculations (Both Shafi'i m=1 and Hanafi m=2)
        $zenithDistance = abs($phi - $delta);

        $cotH1 = 1.0 + tan($zenithDistance);
        $hAsrShafi = atan(1.0 / $cotH1);
        $tAsrShafi = $this->hourAngle($phi, $delta, $hAsrShafi);
        $exactAsrShafi = $transit + $tAsrShafi;

        $cotH2 = 2.0 + tan($zenithDistance);
        $hAsrHanafi = atan(1.0 / $cotH2);
        $tAsrHanafi = $this->hourAngle($phi, $delta, $hAsrHanafi);
        $exactAsrHanafi = $transit + $tAsrHanafi;

        $exactAsr = $this->asrJuristic === self::ASR_HANAFI ? $exactAsrHanafi : $exactAsrShafi;

        // 5. Maghrib
        $exactMaghrib = $exactSunset;

        // 6. Isha
        if ($params['isha_fixed_minutes'] !== null) {
            $exactIsha = $exactMaghrib + ($params['isha_fixed_minutes'] / 60.0);
        } else {
            $tIsha = $this->hourAngle($phi, $delta, -$ishaAngle);
            $exactIsha = $transit + $tIsha;
        }

        // Comprehensive Shar'i Milestones:
        // Fajr & Sehar
        $seharEnd = $exactFajr - (1.0 / 60.0);
        $fajrStart = $exactFajr;
        $fajrAdhan = $exactFajr + (1.0 / 60.0);
        $fajrEnd = $exactSunrise - (1.0 / 60.0);

        // Sunrise & Ishraq
        $ishraqTime = $exactSunrise + (10.0 / 60.0) + (40.0 / 3600.0);
        $ishraqStart = $ishraqTime + (1.0 / 60.0);

        // Nisf-un-Nahar Shar'i (Midpoint of Shar'i Day)
        $nisfNaharShari = $exactFajr + ($exactSunset - $exactFajr) / 2.0;

        // Zawal / Istiwa interval (Makrooh duration centered around solar transit: ~5 mins total)
        $zawalStart = $transit - (2.0 / 60.0) - (40.0 / 3600.0);
        $zawalEnd = $transit + (2.0 / 60.0) + (24.0 / 3600.0);

        // Dhuhr: Begins at the conclusion of Zawal/Istiwa interval
        $dhuhrStart = $zawalEnd;
        $dhuhrAdhan = $dhuhrStart + (1.0 / 60.0);
        $dhuhrShafiEnd = $exactAsrShafi - (1.0 / 60.0);
        $dhuhrHanafiEnd = $exactAsrHanafi - (1.0 / 60.0);

        // Asr: Begins at the exact astronomical shadow threshold
        $asrShafiStart = $exactAsrShafi;
        $asrShafiAdhan = $exactAsrShafi + (1.0 / 60.0);
        $asrHanafiStart = $exactAsrHanafi;
        $asrHanafiAdhan = $exactAsrHanafi + (1.0 / 60.0);
        $asrMakrooh = $exactSunset - (14.0 / 60.0) - (58.0 / 3600.0);

        // Maghrib & Iftar: Begins at exact sunset
        $maghribSunset = $exactSunset;
        $iftarAdhan = $exactSunset + (1.0 / 60.0);
        $maghribEnd = $exactIsha - (1.0 / 60.0);

        // Isha & Tahajjud: Begins at exact twilight angle
        $ishaStart = $exactIsha;
        $ishaAdhan = $exactIsha + (1.0 / 60.0);
        $nightDuration = (24.0 - $exactSunset) + $seharEnd;
        $nisfShab = fmod($exactSunset + ($nightDuration / 2.0), 24.0);
        $ishaMakrooh = $nisfShab;
        $ishaEnd = $seharEnd;

        // Tahajjud Milestones
        $tahajjudThird = fmod($exactSunset + $nightDuration * (2.0 / 3.0), 24.0);
        $tahajjudSixth = fmod($exactSunset + $nightDuration * (5.0 / 6.0), 24.0);

        return [
            'fajr_card' => [
                'sehar_end' => $this->formatTimeWithSec($seharEnd),
                'start'     => $this->formatTimeWithSec($fajrStart),
                'adhan'     => $this->formatTimeWithSec($fajrAdhan),
                'end'       => $this->formatTimeWithSec($fajrEnd),
            ],
            'sunrise_card' => [
                'sunrise'      => $this->formatTimeWithSec($exactSunrise),
                'ishraq'       => $this->formatTimeWithSec($ishraqTime),
                'ishraq_start' => $this->formatTimeWithSec($ishraqStart),
            ],
            'nisf_nahar_card' => [
                'time' => $this->formatTimeWithSec($nisfNaharShari),
            ],
            'zawal_card' => [
                'nisf_nahar' => $this->formatTimeWithSec($nisfNaharShari),
                'zawal'      => $this->formatTimeWithSec($zawalStart),
                'start'      => $this->formatTimeWithSec($zawalStart),
                'end'        => $this->formatTimeWithSec($zawalEnd),
            ],
            'dhuhr_card' => [
                'start'      => $this->formatTimeWithSec($dhuhrStart),
                'adhan'      => $this->formatTimeWithSec($dhuhrAdhan),
                'shafi_end'  => $this->formatTimeWithSec($dhuhrShafiEnd),
                'hanafi_end' => $this->formatTimeWithSec($dhuhrHanafiEnd),
            ],
            'asr_card' => [
                'shafi_start'  => $this->formatTimeWithSec($asrShafiStart),
                'shafi_adhan'  => $this->formatTimeWithSec($asrShafiAdhan),
                'hanafi_start' => $this->formatTimeWithSec($asrHanafiStart),
                'hanafi_adhan' => $this->formatTimeWithSec($asrHanafiAdhan),
                'makrooh'      => $this->formatTimeWithSec($asrMakrooh),
            ],
            'maghrib_card' => [
                'sunset'      => $this->formatTimeWithSec($maghribSunset),
                'iftar_adhan' => $this->formatTimeWithSec($iftarAdhan),
                'end'         => $this->formatTimeWithSec($maghribEnd),
            ],
            'isha_card' => [
                'start'   => $this->formatTimeWithSec($ishaStart),
                'adhan'   => $this->formatTimeWithSec($ishaAdhan),
                'makrooh' => $this->formatTimeWithSec($ishaMakrooh),
                'end'     => $this->formatTimeWithSec($ishaEnd),
            ],
            'tahajjud_card' => [
                'third_start' => $this->formatTimeWithSec($tahajjudThird),
                'sixth_start' => $this->formatTimeWithSec($tahajjudSixth),
            ],
            'fasting' => [
                'sehar_end'  => $this->formatTimeWithSec($seharEnd),
                'iftar_time' => $this->formatTimeWithSec($iftarAdhan),
            ],
            'exact' => [
                'fajr'    => $this->formatTimeWithSec($fajrStart),
                'sunrise' => $this->formatTimeWithSec($exactSunrise),
                'dhuhr'   => $this->formatTimeWithSec($dhuhrStart),
                'asr'     => $this->formatTimeWithSec($exactAsr),
                'maghrib' => $this->formatTimeWithSec($maghribSunset),
                'isha'    => $this->formatTimeWithSec($ishaStart),
            ],
            'adhan' => [
                'fajr'    => $this->formatTimeWithSec($fajrAdhan),
                'dhuhr'   => $this->formatTimeWithSec($dhuhrAdhan),
                'asr'     => $this->formatTimeWithSec($asrHanafiAdhan),
                'maghrib' => $this->formatTimeWithSec($iftarAdhan),
                'isha'    => $this->formatTimeWithSec($ishaAdhan),
            ],
            'ending' => [
                'fajr'    => $this->formatTimeWithSec($fajrEnd),
                'dhuhr'   => $this->formatTimeWithSec($dhuhrHanafiEnd),
                'asr'     => $this->formatTimeWithSec($maghribSunset),
                'maghrib' => $this->formatTimeWithSec($maghribEnd),
                'isha'    => $this->formatTimeWithSec($ishaEnd),
            ],
            'fajr'    => $this->formatTime($fajrStart),
            'sunrise' => $this->formatTime($exactSunrise),
            'dhuhr'   => $this->formatTime($dhuhrStart),
            'asr'     => $this->formatTime($exactAsr),
            'maghrib' => $this->formatTime($maghribSunset),
            'isha'    => $this->formatTime($ishaStart),
            'raw'     => [
                'fajr' => $fajrStart,
                'sunrise' => $exactSunrise,
                'dhuhr' => $dhuhrStart,
                'asr' => $exactAsr,
                'maghrib' => $maghribSunset,
                'isha' => $ishaStart,
                'transit' => $transit,
                'declination' => $delta,
                'equation_of_time' => $et,
            ]
        ];
    }

    /**
     * Calculate Solar Qibla Alignment Times for a given day:
     * 1. Shadow directly along Qibla line (or anti-Qibla)
     * 2. Shadow perpendicular (90°) to Qibla line
     * 3. Shadow at 135° to Qibla line
     */
    public function calculateSolarQiblaTimes(\DateTimeInterface $date, float $qiblaBearing): array
    {
        $year = (int)$date->format('Y');
        $month = (int)$date->format('m');
        $day = (int)$date->format('d');

        $jd = $this->julianDay($year, $month, $day, 12.0);
        $t = ($jd - 2451545.0) / 36525.0;

        $sun = $this->sunCoordinates($t);
        $delta = $sun['declination'];
        $et = $sun['equation_of_time'];
        $transit = 12.0 + $this->timeZone - ($this->longitude / 15.0) - $et;

        $phi = deg2rad($this->latitude);

        $horizonDip = 0.8333 + 0.0347 * sqrt(max(0.0, $this->elevation));
        $horizonAngle = deg2rad(-$horizonDip);
        $tSunriseH = $this->hourAngle($phi, $delta, $horizonAngle);
        $sunriseTime = $transit - $tSunriseH;
        $sunsetTime = $transit + $tSunriseH;

        $q = fmod(fmod($qiblaBearing, 360.0) + 360.0, 360.0);

        $findBestTime = function (array $candidateTargetAzimuths) use ($sunriseTime, $sunsetTime, $phi, $delta, $transit): ?float {
            $bestDiff = 999.0;
            $bestTime = null;
            $startH = $sunriseTime + (3.0 / 60.0);
            $endH = $sunsetTime - (3.0 / 60.0);

            $step = 0.5 / 60.0;
            for ($h = $startH; $h <= $endH; $h += $step) {
                $az = $this->solarAzimuthAtTime($h, $phi, $delta, $transit);
                if ($az !== null) {
                    foreach ($candidateTargetAzimuths as $targetAz) {
                        $diff = abs($az - $targetAz);
                        if ($diff > 180.0) {
                            $diff = 360.0 - $diff;
                        }
                        if ($diff < $bestDiff) {
                            $bestDiff = $diff;
                            $bestTime = $h;
                        }
                    }
                }
            }

            if ($bestDiff <= 2.5 && $bestTime !== null) {
                $fineStart = $bestTime - (1.0 / 60.0);
                $fineEnd = $bestTime + (1.0 / 60.0);
                $fineStep = 1.0 / 3600.0;
                for ($fh = $fineStart; $fh <= $fineEnd; $fh += $fineStep) {
                    $az = $this->solarAzimuthAtTime($fh, $phi, $delta, $transit);
                    if ($az !== null) {
                        foreach ($candidateTargetAzimuths as $targetAz) {
                            $diff = abs($az - $targetAz);
                            if ($diff > 180.0) {
                                $diff = 360.0 - $diff;
                            }
                            if ($diff < $bestDiff) {
                                $bestDiff = $diff;
                                $bestTime = $fh;
                            }
                        }
                    }
                }
                return $bestTime;
            }
            return null;
        };

        $time0 = $findBestTime([$q]);
        $time180 = $findBestTime([fmod($q + 180.0, 360.0)]);
        $time90 = $findBestTime([fmod($q + 90.0, 360.0), fmod($q - 90.0 + 360.0, 360.0)]);
        $time135 = $findBestTime([
            fmod($q + 135.0, 360.0),
            fmod($q - 135.0 + 360.0, 360.0),
            fmod($q + 45.0, 360.0),
            fmod($q - 45.0 + 360.0, 360.0)
        ]);

        return [
            'qibla_direct' => [
                'title' => '0° کعبہ رخ پر سورج (Sun in Qibla)',
                'title_ur' => '0° کعبہ رخ پر سورج',
                'title_en' => '0° Sun in Qibla (Direct Kaaba Axis)',
                'description' => 'اس وقت سورج کا رخ خود عین قبلہ کی سمت ہوتا ہے',
                'description_ur' => 'اس وقت سورج کا رخ خود عین قبلہ کی سمت ہوتا ہے',
                'description_en' => 'At this time, the Sun aligns directly with the Qibla bearing towards Kaaba.',
                'angle' => 0,
                'azimuth' => round($q, 1),
                'time' => $time0 !== null ? $this->formatTimeWithSec($time0) : 'اس تاریخ کو سورج افق سے اوپر نہیں آتا',
                'is_observable' => $time0 !== null,
            ],
            'qibla_shadow' => [
                'title' => '180° عین سمتِ قبلہ (Shadow Along Qibla)',
                'title_ur' => '180° عین سمتِ قبلہ (شاخص کا سایہ)',
                'title_en' => '180° Direct Qibla Axis (Stick Shadow)',
                'description' => 'اس وقت عمودی لکڑی کا سایہ عین خانہ کعبہ کی سمت پڑتا ہے',
                'description_ur' => 'اس وقت عمودی لکڑی کا سایہ عین خانہ کعبہ کی سمت پڑتا ہے',
                'description_en' => 'At this time, the shadow of a vertical stick aligns directly towards Kaaba.',
                'angle' => 180,
                'azimuth' => round(fmod($q + 180.0, 360.0), 1),
                'time' => $time180 !== null ? $this->formatTimeWithSec($time180) : 'اس تاریخ کو سورج افق سے اوپر نہیں آتا',
                'is_observable' => $time180 !== null,
            ],
            'qibla_perp' => [
                'title' => '90° عمودی زاویہ (صف کی سیدھ / Prayer Rows)',
                'title_ur' => '90° عمودی زاویہ (صف کی سیدھ)',
                'title_en' => '90° Perpendicular Angle (Prayer Rows / Saf)',
                'description' => 'اس وقت عمودی لکڑی کا سایہ 90° پر ہوتا ہے جس کے متوازی نماز کی صفیں سیدھی ہوتی ہیں',
                'description_ur' => 'اس وقت عمودی لکڑی کا سایہ 90° پر ہوتا ہے جس کے متوازی نماز کی صفیں سیدھی ہوتی ہیں',
                'description_en' => 'At this time, stick shadow lies perpendicular to Qibla, aligning mosque prayer rows.',
                'angle' => 90,
                'azimuth' => round(fmod($q + 90.0, 360.0), 1),
                'time' => $time90 !== null ? $this->formatTimeWithSec($time90) : 'اس تاریخ کو سورج افق سے اوپر نہیں آتا',
                'is_observable' => $time90 !== null,
            ],
            'qibla_diag' => [
                'title' => '135° ترچھا زاویہ (کارنر و محراب / Diagonal)',
                'title_ur' => '135° ترچھا زاویہ (کارنر و محراب)',
                'title_en' => '135° Diagonal Angle (Mihrab & Corners)',
                'description' => '135 ڈگری کا زاویہ عمارت اور محراب کے ترچھے کونوں کی سیدھ ناپنے کے لیے استعمال ہوتا ہے',
                'description_ur' => '135 ڈگری کا زاویہ عمارت اور محراب کے ترچھے کونوں کی سیدھ ناپنے کے لیے استعمال ہوتا ہے',
                'description_en' => 'Used for diagonal angle verification of corners, mihrab, and mosque layout.',
                'angle' => 135,
                'azimuth' => round(fmod($q + 135.0, 360.0), 1),
                'time' => $time135 !== null ? $this->formatTimeWithSec($time135) : 'اس تاریخ کو سورج افق سے اوپر نہیں آتا',
                'is_observable' => $time135 !== null,
            ],
        ];
    }

    private function findTimeForAzimuth(
        float $targetAz,
        float $tStart,
        float $tEnd,
        float $phi,
        float $delta,
        float $transit,
        float $azStart,
        float $azEnd
    ): ?float {
        if ($azStart > $azEnd || $targetAz < $azStart || $targetAz > $azEnd) {
            return null;
        }

        $low = $tStart;
        $high = $tEnd;
        for ($i = 0; $i < 30; $i++) {
            $mid = ($low + $high) / 2.0;
            $az = $this->solarAzimuthAtTime($mid, $phi, $delta, $transit);
            if ($az === null) {
                $low = $mid;
                continue;
            }
            if ($az < $targetAz) {
                $low = $mid;
            } else {
                $high = $mid;
            }
        }
        return ($low + $high) / 2.0;
    }

    private function solarAzimuthAtTime(float $hours, float $phi, float $delta, float $transit): ?float
    {
        $hDeg = ($hours - $transit) * 15.0;
        $hRad = deg2rad($hDeg);

        $sinAlt = sin($phi) * sin($delta) + cos($phi) * cos($delta) * cos($hRad);
        if ($sinAlt <= -0.01) {
            return null;
        }

        $x = -sin($hRad) * cos($delta);
        $y = cos($phi) * sin($delta) - sin($phi) * cos($delta) * cos($hRad);

        $azRad = atan2($x, $y);
        return fmod(rad2deg($azRad) + 360.0, 360.0);
    }

    private function hourAngle(float $phi, float $delta, float $altitude): float
    {
        $cosH = (sin($altitude) - sin($phi) * sin($delta)) / (cos($phi) * cos($delta));
        if ($cosH > 1.0) {
            return 0.0;
        }
        if ($cosH < -1.0) {
            return 12.0;
        }
        $hRad = acos($cosH);
        return rad2deg($hRad) / 15.0;
    }

    private function julianDay(int $year, int $month, int $day, float $utcHours): float
    {
        if ($month <= 2) {
            $year -= 1;
            $month += 12;
        }
        $a = (int)floor($year / 100.0);
        $b = 2 - $a + (int)floor($a / 4.0);
        return floor(365.25 * ($year + 4716)) + floor(30.6001 * ($month + 1)) + $day + $b - 1524.5 + ($utcHours / 24.0);
    }

    private function sunCoordinates(float $t): array
    {
        $l0 = fmod(280.46646 + 36000.76983 * $t + 0.0003032 * ($t ** 2), 360.0);
        if ($l0 < 0) $l0 += 360.0;

        $m = fmod(357.52911 + 35999.05029 * $t - 0.0001537 * ($t ** 2), 360.0);
        if ($m < 0) $m += 360.0;
        $mRad = deg2rad($m);

        $c = (1.914602 - 0.004817 * $t - 0.000014 * ($t ** 2)) * sin($mRad)
           + (0.019993 - 0.000101 * $t) * sin(2.0 * $mRad)
           + 0.000289 * sin(3.0 * $mRad);

        $trueLong = $l0 + $c;
        $eps0 = 23.43929111 - 0.013004167 * $t - 0.00000016389 * ($t ** 2) + 0.0000005036 * ($t ** 3);

        $omega = deg2rad(125.04 - 1934.136 * $t);
        $lambda = deg2rad($trueLong - 0.00569 - 0.00478 * sin($omega));
        $eps = deg2rad($eps0 + 0.00256 * cos($omega));

        $sinDelta = sin($eps) * sin($lambda);
        $delta = asin($sinDelta);

        $y = (tan($eps / 2.0)) ** 2;
        $l0Rad = deg2rad($l0);
        $ecc = 0.016708634 - 0.000042037 * $t - 0.0000001267 * ($t ** 2);

        $eTime = $y * sin(2.0 * $l0Rad)
               - 2.0 * $ecc * sin($mRad)
               + 4.0 * $ecc * $y * sin($mRad) * cos(2.0 * $l0Rad)
               - 0.5 * ($y ** 2) * sin(4.0 * $l0Rad)
               - 1.25 * ($ecc ** 2) * sin(2.0 * $mRad);

        $equationOfTimeHours = rad2deg($eTime) * 4.0 / 60.0;

        return [
            'declination' => $delta,
            'equation_of_time' => $equationOfTimeHours
        ];
    }

    private function getMethodParameters(string $method): array
    {
        return match ($method) {
            self::METHOD_MWL => ['fajr' => 18.0, 'isha' => 17.0, 'isha_fixed_minutes' => null],
            self::METHOD_ISNA => ['fajr' => 15.0, 'isha' => 15.0, 'isha_fixed_minutes' => null],
            self::METHOD_UMM_AL_QURA => ['fajr' => 18.5, 'isha' => 0.0, 'isha_fixed_minutes' => 90],
            self::METHOD_EGYPT => ['fajr' => 19.5, 'isha' => 17.5, 'isha_fixed_minutes' => null],
            default => ['fajr' => 18.0, 'isha' => 18.0, 'isha_fixed_minutes' => null], // Karachi
        };
    }

    public function formatTime(float $hours): string
    {
        $h = fmod($hours, 24.0);
        if ($h < 0) $h += 24.0;
        $hour = (int)floor($h);
        $min = (int)round(($h - $hour) * 60.0);
        if ($min >= 60) {
            $hour = ($hour + 1) % 24;
            $min = 0;
        }
        return sprintf('%02d:%02d', $hour, $min);
    }

    public function formatTimeWithSec(float $hours): string
    {
        $h = fmod($hours, 24.0);
        if ($h < 0) $h += 24.0;
        $totalSec = (int)round($h * 3600.0);
        $totalSec = ($totalSec % 86400 + 86400) % 86400;

        $hour = (int)floor($totalSec / 3600);
        $rem = $totalSec % 3600;
        $min = (int)floor($rem / 60);
        $sec = $rem % 60;

        return sprintf('%02d:%02d:%02d', $hour, $min, $sec);
    }
}
