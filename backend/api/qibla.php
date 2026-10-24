<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../src/QiblaCalculator.php';

use Minaret\Core\QiblaCalculator;

try {
    $lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.8878;
    $lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.4125;

    $result = QiblaCalculator::calculate($lat, $lng);

    echo json_encode([
        'status' => 'success',
        'latitude' => $lat,
        'longitude' => $lng,
        'kaaba' => [
            'latitude' => QiblaCalculator::KAABA_LAT,
            'longitude' => QiblaCalculator::KAABA_LNG
        ],
        'qibla' => $result
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
} catch (\Throwable $e) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
