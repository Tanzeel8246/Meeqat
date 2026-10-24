<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$dataFile = __DIR__ . '/../data/mosques.json';

// Initialize default mosques if file not present
$defaultMosques = [
    [
        'id' => 'MSQ-LHR-001',
        'code' => 'MQ-78601',
        'name_ur' => 'جامع مسجد گلبرگ، لاہور',
        'name_en' => 'Jamia Masjid Gulberg, Lahore',
        'city_ur' => 'لاہور',
        'city_en' => 'Lahore',
        'area' => 'Gulberg III, Main Market',
        'imam_name' => 'مولانا عبد الرحمٰن قاسمی',
        'pin' => '1234',
        'code_permanent' => true,
        'created_at' => '2026-01-01 10:00:00'
    ],
    [
        'id' => 'MSQ-ISB-002',
        'code' => 'MQ-78602',
        'name_ur' => 'فیصل مسجد، اسلام آباد',
        'name_en' => 'Faisal Masjid, Islamabad',
        'city_ur' => 'اسلام آباد',
        'city_en' => 'Islamabad',
        'area' => 'Faisal Avenue, E-7',
        'imam_name' => 'قاری محمد طیب عثمانی',
        'pin' => '1234',
        'code_permanent' => true,
        'created_at' => '2026-01-01 10:00:00'
    ],
    [
        'id' => 'MSQ-KHI-003',
        'code' => 'MQ-78603',
        'name_ur' => 'جامع مسجد بیت المکرم، کراچی',
        'name_en' => 'Jamia Masjid Baitul Mukarram, Karachi',
        'city_ur' => 'کراچی',
        'city_en' => 'Karachi',
        'area' => 'Gulshan-e-Iqbal Block 8',
        'imam_name' => 'مفتی اسد اللہ خان',
        'pin' => '1234',
        'code_permanent' => true,
        'created_at' => '2026-01-01 10:00:00'
    ],
    [
        'id' => 'MSQ-RWP-004',
        'code' => 'MQ-78604',
        'name_ur' => 'مرکزی جامع مسجد روڈ، راولپنڈی',
        'name_en' => 'Central Jamia Masjid Road, Rawalpindi',
        'city_ur' => 'راولپنڈی',
        'city_en' => 'Rawalpindi',
        'area' => 'Jamia Masjid Road',
        'imam_name' => 'مولانا سراج الحق',
        'pin' => '1234',
        'code_permanent' => true,
        'created_at' => '2026-01-01 10:00:00'
    ]
];

$mosques = $defaultMosques;
if (file_exists($dataFile)) {
    $content = file_get_contents($dataFile);
    $saved = json_decode($content, true);
    if (is_array($saved) && count($saved) > 0) {
        $mosques = $saved;
    }
} else {
    $dir = dirname($dataFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    @file_put_contents($dataFile, json_encode($mosques, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        $input = $_POST;
    }

    $nameUr = trim($input['name_ur'] ?? '');
    $cityUr = trim($input['city_ur'] ?? 'پاکستان');
    $area = trim($input['area'] ?? '');
    $imamName = trim($input['imam_name'] ?? '');
    $pin = trim($input['pin'] ?? '1234');

    if (empty($nameUr)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Mosque name is required.'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $count = count($mosques) + 1;
    $id = 'MSQ-' . strtoupper(substr(preg_replace('/[^A-Za-z]/', '', $cityUr), 0, 3) ?: 'PAK') . '-' . str_pad((string)$count, 3, '0', STR_PAD_LEFT);
    
    // Generate unique permanent mosque code e.g. MQ-78605
    do {
        $code = 'MQ-' . rand(10000, 99999);
        $exists = false;
        foreach ($mosques as $m) {
            if (($m['code'] ?? '') === $code) {
                $exists = true;
                break;
            }
        }
    } while ($exists);

    $phone = trim($input['phone'] ?? '');

    $newMosque = [
        'id' => $id,
        'code' => $code,
        'code_permanent' => true,
        'name_ur' => $nameUr,
        'name_en' => trim($input['name_en'] ?? $nameUr),
        'city_ur' => $cityUr,
        'city_en' => trim($input['city_en'] ?? $cityUr),
        'area' => $area,
        'imam_name' => $imamName,
        'phone' => $phone,
        'pin' => $pin,
        'created_at' => date('Y-m-d H:i:s')
    ];

    $mosques[] = $newMosque;
    file_put_contents($dataFile, json_encode($mosques, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

    // Also initialize default jamaat times for this mosque
    $timesFile = __DIR__ . '/../data/jamaat_times.json';
    $allTimes = [];
    if (file_exists($timesFile)) {
        $allTimes = json_decode(file_get_contents($timesFile), true) ?: [];
    }
    $allTimes[$id] = [
        'mosque_id' => $id,
        'mosque_name_ur' => $nameUr,
        'mosque_code' => $code,
        'fajr' => trim($input['fajr'] ?? '05:15'),
        'dhuhr' => trim($input['dhuhr'] ?? '13:15'),
        'asr' => trim($input['asr'] ?? '16:30'),
        'maghrib' => trim($input['maghrib'] ?? '17:45'),
        'isha' => trim($input['isha'] ?? '19:30'),
        'jumuah' => trim($input['jumuah'] ?? '13:30'),
        'notice_ur' => trim($input['notice_ur'] ?? 'خوش آمدید! محلہ مسجد کنیکٹ المیقات سے منسلک ہے۔'),
        'notice_en' => 'Welcome! Connected to Al-Meeqat Mohalla Mosque Network.',
        'updated_at' => date('Y-m-d H:i:s')
    ];
    file_put_contents($timesFile, json_encode($allTimes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

    // Return without exposing PIN
    $pub = $newMosque;
    unset($pub['pin']);
    echo json_encode([
        'status' => 'success',
        'code' => $code,
        'permanent_code_notice' => 'یہ کوڈ مستقل ہے اور کبھی تبدیل نہیں ہو گا۔',
        'message_ur' => "ماشاء اللہ! آپ کی مسجد کامیابی سے رجسٹر ہو گئی۔ آپ کی مسجد کا مستقل کوڈ ہے: {$code}۔ یہ کوڈ مستقل ہے اور کبھی تبدیل نہیں ہو گا۔ نمازی حضرات صرف یہ کوڈ لگا کر لائیو اوقات حاصل کریں گے۔",
        'mosque' => $pub
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

// GET: search or list
$query = trim($_GET['q'] ?? '');
$city = trim($_GET['city'] ?? '');
$code = trim($_GET['code'] ?? '');

$results = [];
foreach ($mosques as $m) {
    if ($code !== '' && strcasecmp($m['code'], $code) === 0) {
        $pub = $m;
        unset($pub['pin']);
        $results[] = $pub;
        break;
    }
    if ($city !== '' && stripos($m['city_ur'], $city) === false && stripos($m['city_en'], $city) === false) {
        continue;
    }
    if ($query !== '') {
        $match = (stripos($m['name_ur'], $query) !== false) ||
                 (stripos($m['name_en'], $query) !== false) ||
                 (stripos($m['area'], $query) !== false) ||
                 (stripos($m['code'], $query) !== false);
        if (!$match) continue;
    }
    $pub = $m;
    unset($pub['pin']);
    $results[] = $pub;
}

echo json_encode([
    'status' => 'success',
    'total' => count($results),
    'mosques' => $results
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
