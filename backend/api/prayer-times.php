<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../src/AstronomicalCore.php';
require_once __DIR__ . '/../src/QiblaCalculator.php';
require_once __DIR__ . '/../src/HijriCalendar.php';

use Minaret\Core\AstronomicalCore;
use Minaret\Core\QiblaCalculator;
use Minaret\Core\HijriCalendar;

try {
    $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.8878; // Default Farooka
    $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.4125;
    $tz  = isset($_GET['tz']) ? (float)$_GET['tz'] : 5.0;
    $dateStr = $_GET['date'] ?? date('Y-m-d');
    $method = $_GET['method'] ?? AstronomicalCore::METHOD_KARACHI;
    $asr = isset($_GET['asr']) ? (int)$_GET['asr'] : AstronomicalCore::ASR_HANAFI;
    $elevation = isset($_GET['elevation']) ? (float)$_GET['elevation'] : 0.0;
    $hijriAdjustment = isset($_GET['hijri_adj']) ? (int)$_GET['hijri_adj'] : 0;

    $date = new \DateTimeImmutable($dateStr);

    $calculator = new AstronomicalCore($lat, $lng, $tz, $method, $asr, $elevation);
    $times = $calculator->calculateTimes($date);
    $qibla = QiblaCalculator::calculate($lat, $lng);
    $hijri = HijriCalendar::fromGregorian($date, $hijriAdjustment);

    echo json_encode([
        'status' => 'success',
        'query' => [
            'latitude' => $lat,
            'longitude' => $lng,
            'timezone' => $tz,
            'date' => $dateStr,
            'method' => $method,
            'asr_juristic' => $asr === 2 ? 'Hanafi' : 'Standard',
            'elevation' => $elevation
        ],
        'prayer_times' => [
            'fajr'    => $times['fajr'],
            'sunrise' => $times['sunrise'],
            'dhuhr'   => $times['dhuhr'],
            'asr'     => $times['asr'],
            'maghrib' => $times['maghrib'],
            'isha'    => $times['isha']
        ],
        'hijri_date' => $hijri,
        'qibla' => $qibla
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
} catch (\Throwable $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
