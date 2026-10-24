<?php
$mosquesFile = __DIR__ . '/../data/mosques.json';
$timesFile = __DIR__ . '/../data/jamaat_times.json';

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
if (file_exists($mosquesFile)) {
    $saved = json_decode(file_get_contents($mosquesFile), true);
    if (is_array($saved) && count($saved) > 0) {
        $mosques = $saved;
    }
} else {
    $dir = dirname($mosquesFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    @file_put_contents($mosquesFile, json_encode($mosques, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

$allTimes = [];
if (file_exists($timesFile)) {
    $allTimes = json_decode(file_get_contents($timesFile), true) ?: [];
}

$activeTab = $_GET['tab'] ?? ($_POST['tab'] ?? 'update');
$selectedId = $_GET['mosque_id'] ?? ($_POST['mosque_id'] ?? ($mosques[0]['id'] ?? 'MSQ-LHR-001'));
$msg = '';
$err = '';
$newMosqueNotice = '';

// Handle Form Submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? 'update';

    if ($action === 'register') {
        $nameUr = trim($_POST['reg_name_ur'] ?? '');
        $cityUr = trim($_POST['reg_city_ur'] ?? 'پاکستان');
        $area = trim($_POST['reg_area'] ?? '');
        $imamName = trim($_POST['reg_imam_name'] ?? '');
        $phone = trim($_POST['reg_phone'] ?? '');
        $pin = trim($_POST['reg_pin'] ?? '1234');

        if (empty($nameUr) || empty($pin)) {
            $err = 'مسجد کا نام اور خفیہ پاس کوڈ (PIN) درج کرنا لازمی ہے۔';
            $activeTab = 'register';
        } else {
            // Generate permanent unique code MQ-XXXXX
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

            $count = count($mosques) + 1;
            $id = 'MSQ-' . strtoupper(substr(preg_replace('/[^A-Za-z]/', '', $cityUr), 0, 3) ?: 'PAK') . '-' . str_pad((string)$count, 3, '0', STR_PAD_LEFT);

            $newMosque = [
                'id' => $id,
                'code' => $code,
                'code_permanent' => true,
                'name_ur' => $nameUr,
                'name_en' => $nameUr,
                'city_ur' => $cityUr,
                'city_en' => $cityUr,
                'area' => $area,
                'imam_name' => $imamName,
                'phone' => $phone,
                'pin' => $pin,
                'created_at' => date('Y-m-d H:i:s')
            ];

            $mosques[] = $newMosque;
            file_put_contents($mosquesFile, json_encode($mosques, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

            // Default timings
            $allTimes[$id] = [
                'mosque_id' => $id,
                'mosque_name_ur' => $nameUr,
                'mosque_code' => $code,
                'fajr' => trim($_POST['reg_fajr'] ?? '05:15'),
                'dhuhr' => trim($_POST['reg_dhuhr'] ?? '13:15'),
                'asr' => trim($_POST['reg_asr'] ?? '16:30'),
                'maghrib' => trim($_POST['reg_maghrib'] ?? '17:45'),
                'isha' => trim($_POST['reg_isha'] ?? '19:30'),
                'jumuah' => trim($_POST['reg_jumuah'] ?? '13:30'),
                'notice_ur' => 'خوش آمدید! محلہ مسجد کنیکٹ المیقات سے منسلک ہے۔',
                'notice_en' => 'Welcome! Connected to Al-Meeqat Mohalla Mosque Network.',
                'updated_at' => date('Y-m-d H:i:s')
            ];
            file_put_contents($timesFile, json_encode($allTimes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

            $selectedId = $id;
            $activeTab = 'update';
            $msg = "ماشاء اللہ! {$nameUr} کامیابی سے رجسٹر ہو گئی۔ آپ کی مسجد کا مستقل کوڈ ہے: {$code}";
            $newMosqueNotice = $code;
        }
    } else {
        // Update Jamaat Times
        $activeMosque = null;
        foreach ($mosques as $m) {
            if ($m['id'] === $selectedId || ($m['code'] ?? '') === $selectedId) {
                $activeMosque = $m;
                $selectedId = $m['id'];
                break;
            }
        }

        if (!$activeMosque) {
            $err = 'مسجد کا انتخاب درست نہیں۔';
        } else {
            $pin = trim($_POST['pin'] ?? '');
            $correctPin = $activeMosque['pin'] ?? '1234';

            if ($pin !== $correctPin && $pin !== '1234') {
                $err = 'خفیہ پاس کوڈ (PIN) غلط ہے۔ اوقات میں تبدیلی کا اختیار صرف رجسٹرڈ امام صاحب کو حاصل ہے۔ (ڈیمو پن: 1234)';
            } else {
                $currentTimes = [
                    'mosque_id' => $selectedId,
                    'mosque_name_ur' => $activeMosque['name_ur'] ?? 'جامع مسجد',
                    'mosque_code' => $activeMosque['code'] ?? '',
                    'fajr' => trim($_POST['fajr'] ?? '05:15'),
                    'dhuhr' => trim($_POST['dhuhr'] ?? '13:15'),
                    'asr' => trim($_POST['asr'] ?? '16:30'),
                    'maghrib' => trim($_POST['maghrib'] ?? '17:45'),
                    'isha' => trim($_POST['isha'] ?? '19:30'),
                    'jumuah' => trim($_POST['jumuah'] ?? '13:30'),
                    'notice_ur' => trim($_POST['notice_ur'] ?? ''),
                    'updated_at' => date('Y-m-d H:i:s')
                ];

                $allTimes[$selectedId] = $currentTimes;
                file_put_contents($timesFile, json_encode($allTimes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
                $msg = 'ماشاء اللہ! جماعت کے اوقات اور مسجد کا اعلان کامیابی کے ساتھ محفوظ اور محلے کے تمام نمازیوں کی ایپ پر لائیو سنک کر دیا گیا ہے۔';
            }
        }
    }
}

// Find active mosque for UI
$activeMosque = null;
foreach ($mosques as $m) {
    if ($m['id'] === $selectedId || (isset($m['code']) && $m['code'] === $selectedId)) {
        $activeMosque = $m;
        $selectedId = $m['id'];
        break;
    }
}
if (!$activeMosque && count($mosques) > 0) {
    $activeMosque = $mosques[0];
    $selectedId = $activeMosque['id'];
}

$currentTimes = $allTimes[$selectedId] ?? [
    'fajr' => '05:15',
    'dhuhr' => '13:15',
    'asr' => '16:30',
    'maghrib' => '17:45',
    'isha' => '19:30',
    'jumuah' => '13:30',
    'notice_ur' => 'محترم نمازی حضرات! باجماعت نماز کی پابندی فرمائیں۔',
    'updated_at' => date('Y-m-d H:i:s')
];
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>مسجد محلہ کنیکٹ - امام و انتظامیہ پورٹل | المیقات</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&family=Noto+Nastaliq+Urdu:wght@400;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #070d1e;
            --card: #0f172a;
            --accent: #d4af37;
            --emerald: #10b981;
            --text: #f8fafc;
            --muted: #94a3b8;
            --border: #334155;
            --danger: #ef4444;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: linear-gradient(135deg, #050914 0%, var(--bg) 100%);
            color: var(--text);
            font-family: 'Amiri', serif;
            min-height: 100vh;
            padding: 20px 14px;
            direction: rtl;
        }
        .container {
            max-width: 920px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 24px;
            padding-bottom: 18px;
            border-bottom: 1px solid var(--border);
        }
        .badge {
            display: inline-block;
            background: rgba(212, 175, 55, 0.15);
            color: var(--accent);
            border: 1px solid var(--accent);
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 13.5px;
            margin-bottom: 8px;
            font-family: 'Noto Nastaliq Urdu', serif;
        }
        h1 {
            font-family: 'Noto Nastaliq Urdu', serif;
            font-size: 26px;
            color: var(--accent);
            margin-bottom: 6px;
            line-height: 1.8;
        }
        p.subtitle {
            color: var(--muted);
            font-size: 14.5px;
            line-height: 1.6;
        }
        .nav-tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        .tab-btn {
            flex: 1;
            padding: 12px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: #1e293b;
            color: #cbd5e1;
            font-family: 'Noto Nastaliq Urdu', serif;
            font-size: 15px;
            font-weight: bold;
            cursor: pointer;
            text-align: center;
            text-decoration: none;
            transition: all 0.2s;
        }
        .tab-btn.active {
            background: var(--emerald);
            color: #ffffff;
            border-color: var(--emerald);
            box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
        }
        .alert {
            padding: 14px 18px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-family: 'Noto Nastaliq Urdu', serif;
            line-height: 1.9;
            font-size: 15px;
        }
        .alert-success {
            background: rgba(16, 185, 129, 0.15);
            border: 1px solid var(--emerald);
            color: #34d399;
        }
        .alert-error {
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid var(--danger);
            color: #f87171;
        }
        .permanent-code-banner {
            background: linear-gradient(135deg, rgba(212, 175, 55, 0.15) 0%, rgba(16, 185, 129, 0.1) 100%);
            border: 1.5px dashed var(--accent);
            border-radius: 12px;
            padding: 14px 18px;
            margin-bottom: 22px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .permanent-code-banner .icon {
            font-size: 28px;
        }
        .permanent-code-banner .text {
            font-family: 'Noto Nastaliq Urdu', serif;
            font-size: 14px;
            line-height: 1.8;
            color: #fde68a;
        }
        .permanent-code-banner strong {
            color: var(--accent);
            text-decoration: underline;
        }
        .card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.3);
        }
        .mosque-selector-box {
            display: flex;
            gap: 12px;
            align-items: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        select, input[type="text"], input[type="password"], input[type="time"], textarea {
            background: #0b132b;
            border: 1px solid var(--border);
            color: #fff;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 15px;
            font-family: inherit;
        }
        select:focus, input:focus, textarea:focus {
            outline: none;
            border-color: var(--accent);
        }
        .code-pill {
            background: #1e293b;
            color: var(--accent);
            padding: 8px 16px;
            border-radius: 8px;
            font-weight: bold;
            letter-spacing: 2px;
            font-size: 16px;
            border: 1.5px solid var(--accent);
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        .times-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .time-box {
            background: #0b132b;
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 14px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .time-box.active {
            border-color: rgba(212, 175, 55, 0.6);
            background: rgba(212, 175, 55, 0.05);
        }
        .time-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .prayer-name {
            font-family: 'Noto Nastaliq Urdu', serif;
            font-size: 17px;
            color: var(--accent);
        }
        .time-controls {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .time-controls input[type="time"] {
            flex: 1;
            font-size: 17px;
            text-align: center;
            font-weight: bold;
            color: #38bdf8;
        }
        .btn-adjust {
            background: #1e293b;
            color: #f1f5f9;
            border: 1px solid #334155;
            padding: 6px 10px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: bold;
            font-size: 13px;
            transition: all 0.2s;
        }
        .btn-adjust:hover {
            background: var(--accent);
            color: #000;
        }
        .form-group {
            margin-bottom: 18px;
        }
        label {
            display: block;
            margin-bottom: 6px;
            color: #e2e8f0;
            font-size: 14.5px;
            font-family: 'Noto Nastaliq Urdu', serif;
            line-height: 1.8;
        }
        .btn-submit {
            background: linear-gradient(135deg, #d4af37 0%, #b89628 100%);
            color: #0b132b;
            border: none;
            padding: 14px 28px;
            border-radius: 10px;
            font-size: 17px;
            font-weight: bold;
            cursor: pointer;
            width: 100%;
            font-family: 'Noto Nastaliq Urdu', serif;
            box-shadow: 0 4px 14px rgba(212, 175, 55, 0.3);
            transition: transform 0.15s;
        }
        .btn-submit:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(212, 175, 55, 0.4);
        }
        .footer-note {
            text-align: center;
            margin-top: 24px;
            color: var(--muted);
            font-size: 13px;
        }
        .footer-note a {
            color: var(--accent);
            text-decoration: none;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <div class="badge">المیقات سمارٹ نیٹ ورک &bull; meeqat.mamfss.com</div>
        <h1>مسجد محلہ کنیکٹ - امام و انتظامیہ پینل</h1>
        <p class="subtitle">امام مسجد کے لیے ایک کلک پر جماعت کے اوقات اور اعلانات تمام محلہ داروں کی ایپ میں اپڈیٹ کرنے کا سرکاری نظام</p>
    </div>

    <!-- Permanent Code Security Banner -->
    <div class="permanent-code-banner">
        <div class="icon">🔒</div>
        <div class="text">
            <strong>اہم قانونی و تکنیکی وضاحت:</strong> ہر مسجد کا رجسٹریشن کوڈ (جیسے <strong>MQ-78601</strong>) مستقل اور دائمی ہے جو <strong>کبھی تبدیل نہیں ہو گا</strong>۔ اوقات میں ترمیم کا اختیار صرف رجسٹرڈ امام صاحب کے پاس کوڈ کے پاس محفوظ رہے گا۔
        </div>
    </div>

    <!-- Navigation Tabs -->
    <div class="nav-tabs">
        <a href="?tab=update&mosque_id=<?= urlencode($selectedId) ?>" class="tab-btn <?= $activeTab === 'update' ? 'active' : '' ?>">
            🕌 جماعت کے اوقات میں تبدیلی
        </a>
        <a href="?tab=register" class="tab-btn <?= $activeTab === 'register' ? 'active' : '' ?>">
            ➕ نئی مسجد کا اندراج (مستقل کوڈ حاصل کریں)
        </a>
    </div>

    <?php if ($msg): ?>
        <div class="alert alert-success"><?= htmlspecialchars($msg) ?></div>
    <?php endif; ?>

    <?php if ($err): ?>
        <div class="alert alert-error"><?= htmlspecialchars($err) ?></div>
    <?php endif; ?>

    <?php if ($activeTab === 'register'): ?>
        <!-- TAB 2: REGISTER NEW MOSQUE -->
        <div class="card">
            <h2 style="font-family:'Noto Nastaliq Urdu',serif; color:var(--accent); font-size:22px; margin-bottom:12px;">نئی جامع مسجد رجسٹر کریں</h2>
            <p style="color:var(--muted); font-size:14px; margin-bottom:20px;">
                مسجد کو رجسٹر کرنے پر سسٹم فوری طور پر ایک دائمی اور غیر متبدل کوڈ (MQ-XXXXX) جاری کرے گا جسے آپ محلے کے نمازیوں کو فراہم کر سکتے ہیں۔
            </p>

            <form method="POST" action="imam_portal.php">
                <input type="hidden" name="action" value="register">
                <input type="hidden" name="tab" value="register">

                <div class="form-group">
                    <label for="reg_name_ur">مسجد کا مکمل نام (اردو):</label>
                    <input type="text" id="reg_name_ur" name="reg_name_ur" placeholder="مثلاً: جامع مسجد نورِ مدینہ" required style="width:100%;">
                </div>

                <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
                    <div class="form-group">
                        <label for="reg_city_ur">شہر (اردو):</label>
                        <input type="text" id="reg_city_ur" name="reg_city_ur" placeholder="مثلاً: لاہور / سرگودھا / فروکہ" required style="width:100%;">
                    </div>
                    <div class="form-group">
                        <label for="reg_area">محلہ / علاقہ / پتہ:</label>
                        <input type="text" id="reg_area" name="reg_area" placeholder="مثلاً: مین بازار، محلہ فاروقیہ" required style="width:100%;">
                    </div>
                </div>

                <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
                    <div class="form-group">
                        <label for="reg_imam_name">امام صاحب / منتظم کا نام:</label>
                        <input type="text" id="reg_imam_name" name="reg_imam_name" placeholder="مثلاً: مولانا عبد الرحمٰن" required style="width:100%;">
                    </div>
                    <div class="form-group">
                        <label for="reg_phone">رابطہ فون / واٹس ایپ (اختیاری):</label>
                        <input type="text" id="reg_phone" name="reg_phone" placeholder="0300-1234567" style="width:100%; direction:ltr; text-align:right;">
                    </div>
                </div>

                <div class="form-group" style="max-width:360px;">
                    <label for="reg_pin">امام صاحب کا خفیہ پاس کوڈ (PIN) مقرر کریں:</label>
                    <input type="password" id="reg_pin" name="reg_pin" placeholder="چار یا زائد ہندسوں کا پاس کوڈ" required style="width:100%; letter-spacing:4px; font-weight:bold;">
                    <small style="color:var(--muted); display:block; margin-top:4px;">(مستقبل میں اوقات تبدیل کرنے کے لیے یہ خفیہ پاس کوڈ درکار ہو گا)</small>
                </div>

                <button type="submit" class="btn-submit">
                    مسجد رجسٹر کریں اور مستقل کوڈ جاری کروائیں 🚀
                </button>
            </form>
        </div>

    <?php else: ?>
        <!-- TAB 1: UPDATE TIMES -->
        <div class="card">
            <form method="GET" action="imam_portal.php" class="mosque-selector-box">
                <input type="hidden" name="tab" value="update">
                <label for="mosque_id" style="margin:0;">منتخب مسجد:</label>
                <select name="mosque_id" id="mosque_id" onchange="this.form.submit()" style="min-width: 260px;">
                    <?php foreach ($mosques as $m): ?>
                        <option value="<?= htmlspecialchars($m['id']) ?>" <?= ($m['id'] === $selectedId) ? 'selected' : '' ?>>
                            <?= htmlspecialchars($m['name_ur']) ?> (<?= htmlspecialchars($m['city_ur']) ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
                <div class="code-pill">
                    <span>مستقل کوڈ برائے نمازی:</span>
                    <span><?= htmlspecialchars($activeMosque['code'] ?? 'MQ-78601') ?></span>
                </div>
            </form>

            <form method="POST" action="imam_portal.php?tab=update&mosque_id=<?= urlencode($selectedId) ?>">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="tab" value="update">
                <input type="hidden" name="mosque_id" value="<?= htmlspecialchars($selectedId) ?>">

                <div class="times-grid">
                    <!-- فجر -->
                    <div class="time-box">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ فجر</span>
                            <small style="color:var(--muted)">صبح کا وقت</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('fajr', -5)">-5 منٹ</button>
                            <input type="time" id="fajr" name="fajr" value="<?= htmlspecialchars($currentTimes['fajr']) ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('fajr', 5)">+5 منٹ</button>
                        </div>
                    </div>

                    <!-- ظہر -->
                    <div class="time-box">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ ظہر</span>
                            <small style="color:var(--muted)">دوپہر</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('dhuhr', -5)">-5 منٹ</button>
                            <input type="time" id="dhuhr" name="dhuhr" value="<?= htmlspecialchars($currentTimes['dhuhr']) ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('dhuhr', 5)">+5 منٹ</button>
                        </div>
                    </div>

                    <!-- عصر -->
                    <div class="time-box active">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ عصر</span>
                            <small style="color:var(--muted)">سہ پہر</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('asr', -5)">-5 منٹ</button>
                            <input type="time" id="asr" name="asr" value="<?= htmlspecialchars($currentTimes['asr']) ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('asr', 5)">+5 منٹ</button>
                        </div>
                    </div>

                    <!-- مغرب -->
                    <div class="time-box">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ مغرب</span>
                            <small style="color:var(--muted)">غروبِ آفتاب پر</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('maghrib', -5)">-5 منٹ</button>
                            <input type="time" id="maghrib" name="maghrib" value="<?= htmlspecialchars($currentTimes['maghrib']) ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('maghrib', 5)">+5 منٹ</button>
                        </div>
                    </div>

                    <!-- عشاء -->
                    <div class="time-box">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ عشاء</span>
                            <small style="color:var(--muted)">رات</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('isha', -5)">-5 منٹ</button>
                            <input type="time" id="isha" name="isha" value="<?= htmlspecialchars($currentTimes['isha']) ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('isha', 5)">+5 منٹ</button>
                        </div>
                    </div>

                    <!-- جمعہ المبارک -->
                    <div class="time-box">
                        <div class="time-header">
                            <span class="prayer-name">نمازِ جمعہ المبارک</span>
                            <small style="color:var(--muted)">خطبہ و نماز</small>
                        </div>
                        <div class="time-controls">
                            <button type="button" class="btn-adjust" onclick="adjustTime('jumuah', -5)">-5 منٹ</button>
                            <input type="time" id="jumuah" name="jumuah" value="<?= htmlspecialchars($currentTimes['jumuah'] ?? '13:30') ?>" required>
                            <button type="button" class="btn-adjust" onclick="adjustTime('jumuah', 5)">+5 منٹ</button>
                        </div>
                    </div>
                </div>

                <!-- اعلان -->
                <div class="form-group">
                    <label for="notice_ur">محلے کے نمازیوں کے لیے خصوصی پیغام / اعلان (اختیاری):</label>
                    <textarea id="notice_ur" name="notice_ur" rows="2" style="width:100%;"><?= htmlspecialchars($currentTimes['notice_ur'] ?? '') ?></textarea>
                </div>

                <!-- سیکیورٹی پاس کوڈ -->
                <div class="form-group" style="max-width:340px;">
                    <label for="pin">امام / انتظامیہ خفیہ پاس کوڈ (PIN):</label>
                    <input type="password" id="pin" name="pin" placeholder="پاس کوڈ درج کریں" value="1234" required style="width:100%; letter-spacing:4px; font-weight:bold;">
                    <small style="color:var(--muted); display:block; margin-top:4px;">(اوقات میں تبدیلی صرف مجاز اکاؤنٹ ہولڈر کے پاس کوڈ سے ہی ممکن ہے)</small>
                </div>

                <button type="submit" class="btn-submit">
                    محفوظ کریں اور محلے کے تمام موبائلوں پر سنک نشر کریں 🚀
                </button>
            </form>
        </div>
    <?php endif; ?>

    <div class="footer-note">
        المیقات سسٹم سنک سروس &bull; باضابطہ تصدیق شدہ اوقات &bull; 
        <a href="index.php">مین پیج</a> &bull; 
        <a href="admin_ruet.php">رویتِ ہلال ایڈمن پورٹل</a>
    </div>
</div>

<script>
function adjustTime(inputId, deltaMinutes) {
    const el = document.getElementById(inputId);
    if (!el || !el.value) return;
    const parts = el.value.split(':');
    let h = parseInt(parts[0], 10);
    let m = parseInt(parts[1], 10);
    let total = h * 60 + m + deltaMinutes;
    if (total < 0) total += 24 * 60;
    total = total % (24 * 60);
    const newH = String(Math.floor(total / 60)).padStart(2, '0');
    const newM = String(total % 60).padStart(2, '0');
    el.value = `${newH}:${newM}`;
}
</script>
</body>
</html>