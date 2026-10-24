<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../src/AstronomicalCore.php';
require_once __DIR__ . '/../src/HijriCalendar.php';

use Minaret\Core\AstronomicalCore;
use Minaret\Core\HijriCalendar;

try {
    $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.8878;
    $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.4125;
    $tz  = isset($_GET['tz']) ? (float)$_GET['tz'] : 5.0;
    $year = isset($_GET['year']) ? (int)$_GET['year'] : (int)date('Y');
    $month = isset($_GET['month']) ? (int)$_GET['month'] : (int)date('m');
    $method = $_GET['method'] ?? AstronomicalCore::METHOD_KARACHI;
    $asr = isset($_GET['asr']) ? (int)$_GET['asr'] : AstronomicalCore::ASR_HANAFI;

    $calculator = new AstronomicalCore($lat, $lng, $tz, $method, $asr);
    $daysInMonth = cal_days_in_month(CAL_GREGORIAN, $month, $year);

    $days = [];
    for ($d = 1; $d <= $daysInMonth; $d++) {
        $dateStr = sprintf('%04d-%02d-%02d', $year, $month, $d);
        $date = new \DateTimeImmutable($dateStr);
        $times = $calculator->calculateTimes($date);
        $hijri = HijriCalendar::fromGregorian($date);

        $days[] = [
            'date' => $dateStr,
            'day_number' => $d,
            'day_name' => $date->format('l'),
            'hijri' => $hijri['formatted_urdu'],
            'hijri_en' => $hijri['formatted_en'],
            'times' => [
                'fajr'    => $times['fajr'],
                'sunrise' => $times['sunrise'],
                'dhuhr'   => $times['dhuhr'],
                'asr'     => $times['asr'],
                'maghrib' => $times['maghrib'],
                'isha'    => $times['isha']
            ]
        ];
    }

    echo json_encode([
        'status' => 'success',
        'year' => $year,
        'month' => $month,
        'days_count' => count($days),
        'schedule' => $days
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
} catch (\Throwable $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
