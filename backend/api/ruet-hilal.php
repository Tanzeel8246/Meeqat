<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$dataFile = __DIR__ . '/../data/ruet_hilal.json';

// Default baseline data if file does not exist
$defaultData = [
    'status' => 'success',
    'committee' => 'Central Ruet-e-Hilal Committee Pakistan',
    'hijri_year' => 1448,
    'hijri_month' => 4,
    'hijri_month_name_ur' => 'ربیع الثانی',
    'hijri_month_name_en' => 'Rabi-ul-Thani',
    'hijri_day' => 10,
    'gregorian_date' => date('Y-m-d'),
    'hijri_adjustment' => 0,
    'announcement_active' => true,
    'announcement_title_ur' => 'مرکزی رویتِ ہلال کمیٹی کا باضابطہ اعلان',
    'announcement_title_en' => 'Official Declaration by Central Ruet-e-Hilal Committee',
    'announcement_text_ur' => 'ربیع الثانی 1448ھ کی تصدیق شدہ رویت کے مطابق المیقات تقویم ہم آہنگ ہے۔',
    'announcement_text_en' => 'Al-Meeqat calendar is aligned with certified Rabi-ul-Thani 1448 AH moon sighting.',
    'updated_at' => date('Y-m-d H:i:s')
];

if (file_exists($dataFile)) {
    $content = file_get_contents($dataFile);
    $saved = json_decode($content, true);
    if (is_array($saved)) {
        $defaultData = array_merge($defaultData, $saved);
    }
} else {
    $dir = dirname($dataFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    @file_put_contents($dataFile, json_encode($defaultData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

echo json_encode($defaultData, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
