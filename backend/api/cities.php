<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../src/CityDatabase.php';

use Minaret\Core\CityDatabase;

$query = $_GET['q'] ?? '';
$results = CityDatabase::search($query);

echo json_encode([
    'status' => 'success',
    'total' => count($results),
    'cities' => $results
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
