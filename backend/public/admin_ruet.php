<?php
$dataFile = __DIR__ . '/../data/ruet_hilal.json';
$msg = '';
$err = '';

$current = [
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
    'announcement_text_en' => 'Al-Meeqat calendar is aligned with certified Rabi-ul-Thani 1448 AH moon sighting.'
];

if (file_exists($dataFile)) {
    $loaded = json_decode(file_get_contents($dataFile), true);
    if (is_array($loaded)) {
        $current = array_merge($current, $loaded);
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $current['hijri_year'] = (int)($_POST['hijri_year'] ?? 1448);
    $current['hijri_month'] = (int)($_POST['hijri_month'] ?? 1);
    $current['hijri_month_name_ur'] = trim($_POST['hijri_month_name_ur'] ?? '');
    $current['hijri_month_name_en'] = trim($_POST['hijri_month_name_en'] ?? '');
    $current['hijri_day'] = (int)($_POST['hijri_day'] ?? 1);
    $current['hijri_adjustment'] = (int)($_POST['hijri_adjustment'] ?? 0);
    $current['announcement_active'] = isset($_POST['announcement_active']);
    $current['announcement_title_ur'] = trim($_POST['announcement_title_ur'] ?? '');
    $current['announcement_title_en'] = trim($_POST['announcement_title_en'] ?? '');
    $current['announcement_text_ur'] = trim($_POST['announcement_text_ur'] ?? '');
    $current['announcement_text_en'] = trim($_POST['announcement_text_en'] ?? '');
    $current['gregorian_date'] = date('Y-m-d');
    $current['updated_at'] = date('Y-m-d H:i:s');

    $dir = dirname($dataFile);
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    if (@file_put_contents($dataFile, json_encode($current, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE))) {
        $msg = 'رویتِ ہلال کا باضابطہ اعلان اور ہجری ایڈجسٹمنٹ کامیابی کے ساتھ محفوظ ہو گئی ہے۔ تمام موبائل ایپس خودکار سنک ہو جائیں گی۔';
    } else {
        $err = 'فائل محفوظ کرتے وقت مسئلہ پیش آیا۔ براہِ کرم اجازتیں چیک کریں۔';
    }
}
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>مرکزی رویتِ ہلال اعلان پینل - المیقات</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&family=Noto+Nastaliq+Urdu:wght@400;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg: #0B132B;
            --surface: #1C2541;
            --surface-elevated: #243056;
            --emerald: #10B981;
            --gold: #F59E0B;
            --text-primary: #F8FAFC;
            --text-secondary: #94A3B8;
            --border: #334155;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: var(--bg);
            color: var(--text-primary);
            font-family: 'Noto Nastaliq Urdu', 'Amiri', Tahoma, sans-serif;
            min-height: 100vh;
            padding: 24px 16px;
            direction: rtl;
        }
        .container {
            max-width: 760px;
            margin: 0 auto;
            background: var(--surface);
            border-radius: 20px;
            padding: 28px;
            border: 1px solid rgba(245, 158, 11, 0.3);
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        }
        .header {
            text-align: center;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        .header h1 {
            color: var(--gold);
            font-size: 26px;
            margin-bottom: 6px;
        }
        .header p {
            color: var(--text-secondary);
            font-size: 14px;
        }
        .alert {
            padding: 12px 16px;
            border-radius: 12px;
            margin-bottom: 20px;
            font-size: 14px;
        }
        .alert-success { background: rgba(16, 185, 129, 0.2); border: 1px solid var(--emerald); color: #34D399; }
        .alert-danger { background: rgba(239, 68, 68, 0.2); border: 1px solid #EF4444; color: #FCA5A5; }
        .form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-bottom: 16px;
        }
        .form-group {
            margin-bottom: 16px;
        }
        label {
            display: block;
            margin-bottom: 6px;
            color: var(--gold);
            font-size: 13.5px;
            font-weight: bold;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px 14px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: var(--surface-elevated);
            color: #fff;
            font-size: 14px;
            font-family: inherit;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: var(--emerald);
        }
        .btn {
            display: block;
            width: 100%;
            background: var(--emerald);
            color: #fff;
            border: none;
            padding: 14px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: background 0.2s;
            margin-top: 10px;
        }
        .btn:hover { background: #059669; }
        .checkbox-container {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 16px;
            background: rgba(255,255,255,0.04);
            padding: 12px;
            border-radius: 10px;
        }
        .checkbox-container input { width: auto; }
        .footer-links {
            display: flex;
            justify-content: space-between;
            margin-top: 20px;
            padding-top: 16px;
            border-top: 1px solid var(--border);
            font-size: 13px;
        }
        .footer-links a { color: var(--emerald); text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌙 پینل اعلانِ رویتِ ہلال و توثیقِ تقویم</h1>
            <p>مرکزی رویتِ ہلال کمیٹی پاکستان کے فیصلوں کو براہِ راست المیقات ایپس اور ٹی وی بورڈ پر نشر کریں</p>
        </div>

        <?php if ($msg): ?>
            <div class="alert alert-success">✔ <?= htmlspecialchars($msg) ?></div>
        <?php endif; ?>
        <?php if ($err): ?>
            <div class="alert alert-danger">✖ <?= htmlspecialchars($err) ?></div>
        <?php endif; ?>

        <form method="POST">
            <div class="form-grid">
                <div class="form-group">
                    <label>ہجری سال (Hijri Year):</label>
                    <input type="number" name="hijri_year" value="<?= htmlspecialchars($current['hijri_year']) ?>" required>
                </div>
                <div class="form-group">
                    <label>ہجری مہینہ (Hijri Month 1-12):</label>
                    <input type="number" name="hijri_month" value="<?= htmlspecialchars($current['hijri_month']) ?>" min="1" max="12" required>
                </div>
            </div>

            <div class="form-grid">
                <div class="form-group">
                    <label>مہینے کا نام اردو (Urdu Month):</label>
                    <input type="text" name="hijri_month_name_ur" value="<?= htmlspecialchars($current['hijri_month_name_ur']) ?>" required>
                </div>
                <div class="form-group">
                    <label>مہینے کا نام انگریزی (English Month):</label>
                    <input type="text" name="hijri_month_name_en" value="<?= htmlspecialchars($current['hijri_month_name_en']) ?>" required>
                </div>
            </div>

            <div class="form-grid">
                <div class="form-group">
                    <label>آج ہجری تاریخ (Hijri Day):</label>
                    <input type="number" name="hijri_day" value="<?= htmlspecialchars($current['hijri_day']) ?>" min="1" max="30" required>
                </div>
                <div class="form-group">
                    <label>رویت فرق / ایڈجسٹمنٹ (Adjustment Offset):</label>
                    <select name="hijri_adjustment">
                        <option value="-2" <?= $current['hijri_adjustment'] == -2 ? 'selected' : '' ?>>منفی ۲ دن (-2 Days)</option>
                        <option value="-1" <?= $current['hijri_adjustment'] == -1 ? 'selected' : '' ?>>منفی ۱ دن (-1 Day)</option>
                        <option value="0" <?= $current['hijri_adjustment'] == 0 ? 'selected' : '' ?>>عین فلکیاتی تقویم مطابق (0 Days)</option>
                        <option value="1" <?= $current['hijri_adjustment'] == 1 ? 'selected' : '' ?>>مثبت ۱ دن (+1 Day)</option>
                        <option value="2" <?= $current['hijri_adjustment'] == 2 ? 'selected' : '' ?>>مثبت ۲ دن (+2 Days)</option>
                    </select>
                </div>
            </div>

            <div class="checkbox-container">
                <input type="checkbox" id="active" name="announcement_active" <?= $current['announcement_active'] ? 'checked' : '' ?>>
                <label for="active" style="margin:0; cursor:pointer;">موبائل ایپس پر اس اعلان کا بینر فعال رکھیں (Active Banner)</label>
            </div>

            <div class="form-group">
                <label>اعلان کا عنوان (اردو):</label>
                <input type="text" name="announcement_title_ur" value="<?= htmlspecialchars($current['announcement_title_ur']) ?>">
            </div>

            <div class="form-group">
                <label>باضابطہ اعلان کی تفصیل (اردو):</label>
                <textarea name="announcement_text_ur" rows="2"><?= htmlspecialchars($current['announcement_text_ur']) ?></textarea>
            </div>

            <button type="submit" class="btn">🚀 اعلان نشر کریں اور ایپس سنک کریں</button>
        </form>

        <div class="footer-links">
            <a href="index.php">← المیقات ویب پینل</a>
            <a href="display.php" target="_blank">مسجد ٹی وی بورڈ لائیو →</a>
        </div>
    </div>
</body>
</html>
