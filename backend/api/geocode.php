<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../src/CityDatabase.php';
require_once __DIR__ . '/../src/QiblaCalculator.php';

use Minaret\Core\CityDatabase;
use Minaret\Core\QiblaCalculator;

$query = trim($_GET['q'] ?? '');
$latParam = $_GET['lat'] ?? null;
$lngParam = $_GET['lng'] ?? null;

// Estimate standard timezone from longitude and country
function estimateTimezone(string $country, float $lng): float {
    $c = strtolower($country);
    if (str_contains($c, 'pakistan')) return 5.0;
    if (str_contains($c, 'saudi') || str_contains($c, 'qatar') || str_contains($c, 'kuwait') ||
        str_contains($c, 'bahrain') || str_contains($c, 'iraq') || str_contains($c, 'yemen')) return 3.0;
    if (str_contains($c, 'emirates') || str_contains($c, 'uae') || str_contains($c, 'dubai') || str_contains($c, 'oman')) return 4.0;
    if (str_contains($c, 'india') || str_contains($c, 'sri lanka')) return 5.5;
    if (str_contains($c, 'bangladesh')) return 6.0;
    if (str_contains($c, 'afghanistan')) return 4.5;
    if (str_contains($c, 'iran')) return 3.5;
    if (str_contains($c, 'turkey') || str_contains($c, 'türkiye') || str_contains($c, 'egypt') ||
        str_contains($c, 'jordan') || str_contains($c, 'palestine') || str_contains($c, 'syria')) return 3.0;
    if (str_contains($c, 'united kingdom') || str_contains($c, 'britain') || str_contains($c, 'england')) return 0.0;
    if (str_contains($c, 'germany') || str_contains($c, 'france') || str_contains($c, 'italy') || str_contains($c, 'spain')) return 1.0;
    if (str_contains($c, 'malaysia') || str_contains($c, 'singapore') || str_contains($c, 'china')) return 8.0;
    if (str_contains($c, 'japan')) return 9.0;
    if (str_contains($c, 'australia')) {
        if ($lng > 140) return 10.0;
        if ($lng > 125) return 9.5;
        return 8.0;
    }
    return round($lng / 15.0);
}

$results = [];

// 1. Reverse geocoding if lat and lng provided
if ($latParam !== null && $lngParam !== null) {
    $lat = (float)$latParam;
    $lng = (float)$lngParam;
    $qibla = QiblaCalculator::calculate($lat, $lng);
    
    // Try reverse geocoding via OpenStreetMap Nominatim
    $url = "https://nominatim.openstreetmap.org/reverse?lat={$lat}&lon={$lng}&format=json&addressdetails=1";
    $opts = [
        'http' => [
            'header' => "User-Agent: MeeqatBackend/1.5.1 (contact: minaret@al-aqsa.org)\r\n",
            'timeout' => 5
        ]
    ];
    $ctx = stream_context_create($opts);
    $raw = @file_get_contents($url, false, $ctx);
    if ($raw !== false) {
        $json = json_decode($raw, true);
        if (is_array($json) && isset($json['address'])) {
            $addr = $json['address'];
            $cityName = $addr['city'] ?? $addr['town'] ?? $addr['village'] ?? $addr['suburb'] ?? $addr['county'] ?? 'Location';
            $province = $addr['state'] ?? $addr['province'] ?? '';
            $country = $addr['country'] ?? 'Global';
            $tz = estimateTimezone($country, $lng);

            $results[] = [
                'id' => sprintf('rev_%.4f_%.4f', $lat, $lng),
                'name' => $cityName,
                'nameUr' => '',
                'province' => $province,
                'country' => $country,
                'lat' => $lat,
                'lng' => $lng,
                'tz' => $tz,
                'elevation' => 0.0,
                'qibla_bearing' => (float)$qibla['bearing'],
                'source' => 'Reverse Geocode'
            ];
        }
    }
}

// 2. Query search if q provided
if (!empty($query)) {
    // Check local database first
    $localMatches = CityDatabase::search($query);
    foreach ($localMatches as $loc) {
        $qibla = QiblaCalculator::calculate((float)$loc['latitude'], (float)$loc['longitude']);
        $results[] = [
            'id' => 'db_' . strtolower(str_replace(' ', '_', $loc['name'])),
            'name' => $loc['name'],
            'nameUr' => $loc['nameUr'] ?? '',
            'province' => $loc['province'] ?? '',
            'country' => $loc['country'] ?? '',
            'lat' => (float)$loc['latitude'],
            'lng' => (float)$loc['longitude'],
            'tz' => (float)$loc['timezone'],
            'elevation' => (float)($loc['elevation'] ?? 0.0),
            'qibla_bearing' => (float)$qibla['bearing'],
            'source' => 'Verified Local'
        ];
    }

    // Query Global Geocoding service (Open-Meteo)
    $url = "https://geocoding-api.open-meteo.com/v1/search?name=" . urlencode($query) . "&count=15&format=json";
    $raw = @file_get_contents($url);
    if ($raw !== false) {
        $data = json_decode($raw, true);
        $items = $data['results'] ?? [];
        foreach ($items as $item) {
            $name = $item['name'] ?? $query;
            $country = $item['country'] ?? 'Global';
            $state = $item['admin1'] ?? $item['admin2'] ?? '';
            $lat = (float)($item['latitude'] ?? 0.0);
            $lng = (float)($item['longitude'] ?? 0.0);
            $elev = (float)($item['elevation'] ?? 0.0);
            $tz = estimateTimezone($country, $lng);
            $qibla = QiblaCalculator::calculate($lat, $lng);

            // Avoid duplication
            $exists = false;
            foreach ($results as $res) {
                if (abs($res['lat'] - $lat) < 0.04 && abs($res['lng'] - $lng) < 0.04) {
                    $exists = true;
                    break;
                }
            }
            if (!$exists) {
                $results[] = [
                    'id' => sprintf('gm_%.4f_%.4f', $lat, $lng),
                    'name' => $name,
                    'nameUr' => '',
                    'province' => $state,
                    'country' => $country,
                    'lat' => $lat,
                    'lng' => $lng,
                    'tz' => $tz,
                    'elevation' => $elev,
                    'qibla_bearing' => (float)$qibla['bearing'],
                    'source' => 'Google Maps'
                ];
            }
        }
    }
}

echo json_encode([
    'status' => 'success',
    'total' => count($results),
    'cities' => $results
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
