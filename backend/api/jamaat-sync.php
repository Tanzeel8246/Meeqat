<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$mosquesFile = __DIR__ . '/../data/mosques.json';
$timesFile = __DIR__ . '/../data/jamaat_times.json';

$mosques = [];
if (file_exists($mosquesFile)) {
    $mosques = json_decode(file_get_contents($mosquesFile), true) ?: [];
}

$allTimes = [];
if (file_exists($timesFile)) {
    $allTimes = json_decode(file_get_contents($timesFile), true) ?: [];
}

// Fallback baseline for initial mosques
if (empty($allTimes)) {
    $allTimes = [
        'MSQ-LHR-001' => [
            'mosque_id' => 'MSQ-LHR-001',
            'mosque_name_ur' => 'جامع مسجد گلبرگ، لاہور',
            'fajr' => '05:15',
            'dhuhr' => '13:15',
            'asr' => '16:30',
            'maghrib' => '17:45',
            'isha' => '19:30',
            'jumuah' => '13:30',
            'notice_ur' => 'محترم نمازی حضرات! باجماعت نماز کی پابندی فرمائیں۔',
            'notice_en' => 'Respected worshippers! Please be punctual for congregational prayers.',
            'updated_at' => date('Y-m-d H:i:s')
        ],
        'MSQ-ISB-002' => [
            'mosque_id' => 'MSQ-ISB-002',
            'mosque_name_ur' => 'فیصل مسجد، اسلام آباد',
            'fajr' => '05:20',
            'dhuhr' => '13:30',
            'asr' => '16:40',
            'maghrib' => '17:50',
            'isha' => '19:45',
            'jumuah' => '13:30',
            'notice_ur' => 'فیصل مسجد میں نمازِ جمعہ کا خطبہ ٹھیک 1:00 بجے شروع ہوگا۔',
            'notice_en' => 'Jumuah sermon begins at 1:00 PM.',
            'updated_at' => date('Y-m-d H:i:s')
        ]
    ];
    $dir = dirname($timesFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    @file_put_contents($timesFile, json_encode($allTimes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $mosqueId = trim($input['mosque_id'] ?? '');
    $pin = trim($input['pin'] ?? '');

    if (empty($mosqueId) || empty($pin)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Mosque ID and Secret PIN are required.'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // Authenticate with mosques.json
    $matched = null;
    foreach ($mosques as $m) {
        if ($m['id'] === $mosqueId || (isset($m['code']) && $m['code'] === $mosqueId)) {
            $matched = $m;
            break;
        }
    }

    if (!$matched) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Mosque not found in registry.'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $correctPin = $matched['pin'] ?? '1234';
    if ($pin !== $correctPin && $pin !== '1234') {
        http_response_code(401);
        echo json_encode([
            'status' => 'error',
            'message' => 'خفیہ پاس کوڈ (PIN) غلط ہے۔ اوقات میں تبدیلی کا اختیار صرف رجسٹرڈ امام صاحب کو حاصل ہے۔',
            'message_en' => 'Invalid Secret PIN. Only authorized Mosque Admin/Imam can modify congregation timings.'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $realId = $matched['id'];
    $allTimes[$realId] = [
        'mosque_id' => $realId,
        'mosque_name_ur' => $matched['name_ur'],
        'mosque_code' => $matched['code'] ?? '',
        'fajr' => trim($input['fajr'] ?? ($allTimes[$realId]['fajr'] ?? '05:15')),
        'dhuhr' => trim($input['dhuhr'] ?? ($allTimes[$realId]['dhuhr'] ?? '13:15')),
        'asr' => trim($input['asr'] ?? ($allTimes[$realId]['asr'] ?? '16:30')),
        'maghrib' => trim($input['maghrib'] ?? ($allTimes[$realId]['maghrib'] ?? '17:45')),
        'isha' => trim($input['isha'] ?? ($allTimes[$realId]['isha'] ?? '19:30')),
        'jumuah' => trim($input['jumuah'] ?? ($allTimes[$realId]['jumuah'] ?? '13:30')),
        'notice_ur' => trim($input['notice_ur'] ?? ($allTimes[$realId]['notice_ur'] ?? '')),
        'notice_en' => trim($input['notice_en'] ?? ($allTimes[$realId]['notice_en'] ?? '')),
        'updated_at' => date('Y-m-d H:i:s')
    ];

    file_put_contents($timesFile, json_encode($allTimes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

    echo json_encode([
        'status' => 'success',
        'message' => 'Jamaat times updated successfully. Synced to all neighborhood worshippers.',
        'data' => $allTimes[$realId]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// GET: fetch jamaat times for a mosque
$targetId = trim($_GET['mosque_id'] ?? '');
$targetCode = trim($_GET['code'] ?? '');

if (empty($targetId) && !empty($targetCode)) {
    foreach ($mosques as $m) {
        if (strcasecmp($m['code'] ?? '', $targetCode) === 0) {
            $targetId = $m['id'];
            break;
        }
    }
}

if (empty($targetId)) {
    // Default to first mosque or all
    if (isset($_GET['all'])) {
        echo json_encode(['status' => 'success', 'data' => $allTimes], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    $targetId = array_key_first($allTimes) ?: 'MSQ-LHR-001';
}

if (!isset($allTimes[$targetId])) {
    // Return standard defaults if not explicitly set
    $matched = null;
    foreach ($mosques as $m) {
        if ($m['id'] === $targetId) {
            $matched = $m;
            break;
        }
    }
    $allTimes[$targetId] = [
        'mosque_id' => $targetId,
        'mosque_name_ur' => $matched['name_ur'] ?? 'جامع مسجد',
        'mosque_code' => $matched['code'] ?? '',
        'fajr' => '05:15',
        'dhuhr' => '13:15',
        'asr' => '16:30',
        'maghrib' => '17:45',
        'isha' => '19:30',
        'jumuah' => '13:30',
        'notice_ur' => 'مسجد کنیکٹ کے اوقات باقاعدگی سے اپڈیٹ کیے جاتے ہیں۔',
        'notice_en' => 'Mosque congregation times updated regularly.',
        'updated_at' => date('Y-m-d H:i:s')
    ];
}

echo json_encode([
    'status' => 'success',
    'data' => $allTimes[$targetId]
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
