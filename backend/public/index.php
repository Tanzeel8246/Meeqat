<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/AstronomicalCore.php';
require_once __DIR__ . '/../src/QiblaCalculator.php';
require_once __DIR__ . '/../src/HijriCalendar.php';
require_once __DIR__ . '/../src/CityDatabase.php';

use Minaret\Core\AstronomicalCore;
use Minaret\Core\QiblaCalculator;
use Minaret\Core\HijriCalendar;
use Minaret\Core\CityDatabase;

$cityName = $_GET['city_name'] ?? 'Farooka, Punjab, Pakistan';
$lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.794;
$lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.430;
$tz  = isset($_GET['tz']) ? (float)$_GET['tz'] : 5.0;
$method = $_GET['method'] ?? AstronomicalCore::METHOD_KARACHI;
$asr = isset($_GET['asr']) ? (int)$_GET['asr'] : AstronomicalCore::ASR_HANAFI;
$dateParam = $_GET['date'] ?? date('Y-m-d');

$currentDate = new \DateTimeImmutable($dateParam);
$prevDate = $currentDate->modify('-1 day')->format('Y-m-d');
$nextDate = $currentDate->modify('+1 day')->format('Y-m-d');

$calculator = new AstronomicalCore($lat, $lng, $tz, $method, $asr);
$times = $calculator->calculateTimes($currentDate);
$qibla = QiblaCalculator::calculate($lat, $lng);
$solarQibla = $calculator->calculateSolarQiblaTimes($currentDate, (float)$qibla['bearing']);
$hijri = HijriCalendar::fromGregorian($currentDate);

$urduWeekdays = [
    'Monday' => 'پیر', 'Tuesday' => 'منگل', 'Wednesday' => 'بدھ',
    'Thursday' => 'جمعرات', 'Friday' => 'جمعہ المبارک', 'Saturday' => 'ہفتہ', 'Sunday' => 'اتوار'
];
$urduMonths = [
    1 => 'جنوری', 2 => 'فروری', 3 => 'مارچ', 4 => 'اپریل', 5 => 'مئی', 6 => 'جون',
    7 => 'جولائی', 8 => 'اگست', 9 => 'ستمبر', 10 => 'اکتوبر', 11 => 'نومبر', 12 => 'دسمبر'
];
$curMonthNum = (int)$currentDate->format('m');
$dayNameUrdu = $urduWeekdays[$currentDate->format('l')] ?? $currentDate->format('l');
$monthNameUrdu = $urduMonths[$curMonthNum] ?? $currentDate->format('F');
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Minaret Modern - فلکیاتی اوقاتِ نماز و سمتِ قبلہ</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&family=Noto+Nastaliq+Urdu:wght@400;700&family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0a0f1d;
            --bg-card: rgba(18, 26, 47, 0.85);
            --border-card: rgba(255, 255, 255, 0.08);
            --accent-emerald: #10b981;
            --accent-gold: #f59e0b;
            --accent-cyan: #06b6d4;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --shadow-glow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background: radial-gradient(circle at 50% -20%, #1e293b, var(--bg-primary) 70%);
            color: var(--text-main);
            font-family: 'Outfit', 'Noto Nastaliq Urdu', sans-serif;
            min-height: 100vh;
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        .container {
            width: 100%;
            max-width: 1100px;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 15px;
            padding: 15px 0 20px 0;
            border-bottom: 1px solid var(--border-card);
            margin-bottom: 20px;
        }

        .logo-box {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .logo-box h1 {
            font-family: 'Amiri', serif;
            font-size: 2.2rem;
            color: var(--accent-gold);
            letter-spacing: 1px;
        }

        .nav-links {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .nav-btn {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border-card);
            color: var(--text-main);
            padding: 8px 16px;
            border-radius: 8px;
            text-decoration: none;
            font-size: 0.95rem;
            transition: all 0.2s ease;
        }

        .nav-btn:hover, .nav-btn.active {
            background: var(--accent-emerald);
            color: #fff;
            border-color: var(--accent-emerald);
        }

        /* Date Navigation Bar */
        .date-nav-bar {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 16px;
            padding: 14px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }

        .date-nav-btn {
            background: rgba(255, 255, 255, 0.08);
            color: var(--accent-emerald);
            padding: 8px 18px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: bold;
            font-size: 0.95rem;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .date-nav-btn:hover {
            background: var(--accent-emerald);
            color: #fff;
        }

        .date-display-center {
            text-align: center;
        }

        .gregorian-date {
            font-size: 1.25rem;
            font-weight: bold;
            color: #fff;
        }

        .hijri-date-gold {
            font-size: 1.15rem;
            color: var(--accent-gold);
            margin-top: 2px;
            font-weight: 600;
        }

        /* Hero Status Card */
        .hero-banner {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 20px;
            padding: 24px 30px;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            box-shadow: var(--shadow-glow);
            margin-bottom: 20px;
        }

        @media (max-width: 768px) {
            .hero-banner {
                grid-template-columns: 1fr;
                text-align: center;
            }
            .next-prayer-box {
                border-right: none !important;
                padding-right: 0 !important;
            }
        }

        .live-clock {
            font-size: 3.4rem;
            font-weight: 700;
            color: #fff;
            letter-spacing: 2px;
            font-variant-numeric: tabular-nums;
        }

        .location-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-emerald);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 0.95rem;
            margin-bottom: 8px;
        }

        .next-prayer-box {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: flex-end;
            border-right: 2px solid rgba(255, 255, 255, 0.05);
            padding-right: 20px;
        }

        .countdown-title {
            font-size: 1.1rem;
            color: var(--accent-gold);
            margin-bottom: 4px;
        }

        .countdown-clock {
            font-size: 2.8rem;
            font-weight: 700;
            color: var(--accent-emerald);
            font-variant-numeric: tabular-nums;
        }

        /* Fasting Times Card */
        .fasting-card {
            background: var(--bg-card);
            border: 1px solid rgba(245, 158, 11, 0.3);
            border-radius: 16px;
            padding: 18px 24px;
            display: flex;
            justify-content: space-around;
            align-items: center;
            margin-bottom: 24px;
            text-align: center;
        }

        .fasting-title {
            color: var(--accent-gold);
            font-size: 1rem;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 6px;
            justify-content: center;
        }

        .fasting-time {
            font-size: 1.8rem;
            font-weight: 700;
            color: #fff;
            margin-top: 4px;
            direction: ltr;
        }

        /* Detailed Prayer Table */
        .prayer-table {
            width: 100%;
            border-collapse: collapse;
            background: var(--bg-card);
            border-radius: 16px;
            overflow: hidden;
            margin-bottom: 25px;
            border: 1px solid var(--border-card);
        }

        .prayer-table th, .prayer-table td {
            padding: 14px 18px;
            text-align: right;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .prayer-table th {
            background: #1e293b;
            color: var(--accent-gold);
            font-size: 1.05rem;
        }

        .time-cell {
            direction: ltr;
            text-align: left;
            font-weight: bold;
            font-size: 1.15rem;
            color: #fff;
            letter-spacing: 1px;
        }

        /* Controls */
        .details-grid {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }

        @media (max-width: 850px) {
            .details-grid { grid-template-columns: 1fr; }
        }

        .panel-box {
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 16px;
            padding: 22px;
        }

        .panel-box h3 {
            font-size: 1.25rem;
            color: var(--accent-emerald);
            margin-bottom: 15px;
        }

        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin-bottom: 12px;
        }

        .form-group label {
            display: block;
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 5px;
        }

        .form-control {
            width: 100%;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid var(--border-card);
            color: #fff;
            padding: 10px 12px;
            border-radius: 8px;
            font-size: 0.95rem;
            outline: none;
        }

        .submit-btn {
            background: var(--accent-emerald);
            color: #fff;
            border: none;
            padding: 12px 20px;
            border-radius: 8px;
            font-size: 1rem;
            cursor: pointer;
            width: 100%;
            font-weight: 600;
            margin-top: 10px;
        }
    </style>
</head>
<body>

<div class="container">
    <header>
        <div class="logo-box">
            <span>🕌</span>
            <h1>مِیقات (Meeqat) <span style="font-size: 0.8rem; background: rgba(16, 185, 129, 0.2); color: var(--accent-emerald); padding: 2px 8px; border-radius: 6px; border: 1px solid var(--accent-emerald); vertical-align: middle;">v1.5.1</span></h1>
        </div>
        <nav class="nav-links">
            <a href="index.php" class="nav-btn active">ہوم ڈیش بورڈ</a>
            <a href="imam_portal.php" class="nav-btn" style="background: rgba(212, 175, 55, 0.2); border-color: var(--accent-gold); color: #fde68a;">🕌 مسجد محلہ کنیکٹ (امام پورٹل)</a>
            <a href="display.php?lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>" class="nav-btn">مسجد اسکرین (TV Display)</a>
            <a href="monthly.php?lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>" class="nav-btn">دائمی جنتری (Print PDF)</a>
            <a href="admin_ruet.php" class="nav-btn">رویتِ ہلال اعلان</a>
            <a href="gazetteer.php" class="nav-btn">شہروں کی فہرست</a>
        </nav>
    </header>

    <!-- Date Navigation Header (پچھلا دن | تاریخیں | اگلا دن) -->
    <div class="date-nav-bar">
        <a href="index.php?date=<?= $prevDate ?>&lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>" class="date-nav-btn">◀ پچھلا دن</a>
        <div class="date-display-center">
            <div class="gregorian-date"><?= $dayNameUrdu ?>، <?= $currentDate->format('d') ?> <?= $monthNameUrdu ?> <?= $currentDate->format('Y') ?>ء</div>
            <div class="hijri-date-gold"><?= $hijri['formatted_urdu'] ?></div>
        </div>
        <a href="index.php?date=<?= $nextDate ?>&lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>" class="date-nav-btn">اگلا دن ▶</a>
    </div>

    <!-- Hero Card -->
    <section class="hero-banner">
        <div class="current-time-box">
            <div class="location-badge">
                📍 <span><?= htmlspecialchars($cityName) ?> (<?= round($lat, 4) ?>°, <?= round($lng, 4) ?>°)</span>
            </div>
            <div class="live-clock" id="liveClock">--:--:--</div>
        </div>

        <div class="next-prayer-box">
            <div class="countdown-title">اگلی نماز کا باقی وقت:</div>
            <div class="countdown-clock" id="countdownClock">00:00:00</div>
            <div style="color: var(--text-muted); font-size: 1rem; margin-top: 5px;" id="nextPrayerName">اگلی نماز...</div>
        </div>
    </section>

    <!-- Daily Sehar & Iftar Card -->
    <div class="fasting-card">
        <div>
            <div class="fasting-title">🌙 اختتامِ سحر</div>
            <div class="fasting-time"><?= $times['fasting']['sehar_end'] ?></div>
        </div>
        <div style="width: 1px; height: 50px; background: rgba(255,255,255,0.1);"></div>
        <div>
            <div class="fasting-title">☀️ وقتِ افطار</div>
            <div class="fasting-time" style="color: var(--accent-emerald);"><?= $times['fasting']['iftar_time'] ?></div>
        </div>
    </div>

    <!-- Detailed Prayer Times Table with Precise Shar'i Milestones -->
    <table class="prayer-table">
        <thead>
            <tr>
                <th>نماز / فلکیاتی مرحلہ</th>
                <th>تفصیلات و اوقاتِ کار</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>فجر</strong></td>
                <td class="time-cell">
                    ختم سحر: <span style="color: #f59e0b;"><?= $times['fajr_card']['sehar_end'] ?></span> | 
                    فجر ابتداء: <span style="color: #10b981;"><?= $times['fajr_card']['start'] ?></span> | 
                    اذان فجر: <span style="color: #f59e0b;"><?= $times['fajr_card']['adhan'] ?></span> | 
                    فجر اختتام: <span style="color: #94a3b8;"><?= $times['fajr_card']['end'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>طلوعِ آفتاب و اشراق</strong></td>
                <td class="time-cell">
                    طلوع: <span style="color: #94a3b8;"><?= $times['sunrise_card']['sunrise'] ?></span> | 
                    اشراق: <span style="color: #10b981;"><?= $times['sunrise_card']['ishraq'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>نصف النہار شرعی</strong></td>
                <td class="time-cell">
                    نصف النہار شرعی (منتصف النہار): <span style="color: #38bdf8;"><?= $times['nisf_nahar_card']['time'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>زوال و وقتِ استواء</strong></td>
                <td class="time-cell">
                    زوال ابتدا: <span style="color: #f59e0b;"><?= $times['zawal_card']['start'] ?></span> | 
                    زوال انتہاء: <span style="color: #10b981;"><?= $times['zawal_card']['end'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>ظہر</strong></td>
                <td class="time-cell">
                    ابتداء ظہر: <span style="color: #10b981;"><?= $times['dhuhr_card']['start'] ?></span> | 
                    اذان ظہر: <span style="color: #f59e0b;"><?= $times['dhuhr_card']['adhan'] ?></span> | 
                    ظہر شافعی اختتام: <span style="color: #94a3b8;"><?= $times['dhuhr_card']['shafi_end'] ?></span> | 
                    ظہر حنفی اختتام: <span style="color: #94a3b8;"><?= $times['dhuhr_card']['hanafi_end'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>عصر</strong></td>
                <td class="time-cell">
                    عصر شافعی ابتداء: <span style="color: #10b981;"><?= $times['asr_card']['shafi_start'] ?></span> | 
                    عصر حنفی: <span style="color: #10b981;"><?= $times['asr_card']['hanafi_start'] ?></span> | 
                    اذان عصر حنفی: <span style="color: #f59e0b;"><?= $times['asr_card']['hanafi_adhan'] ?></span> | 
                    عصر مکروہ: <span style="color: #ef4444;"><?= $times['asr_card']['makrooh'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>مغرب</strong></td>
                <td class="time-cell">
                    غروب: <span style="color: #94a3b8;"><?= $times['maghrib_card']['sunset'] ?></span> | 
                    افطار اور اذان: <span style="color: #10b981;"><?= $times['maghrib_card']['iftar_adhan'] ?></span> | 
                    مغرب اختتام: <span style="color: #94a3b8;"><?= $times['maghrib_card']['end'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>عشاء</strong></td>
                <td class="time-cell">
                    عشاء ابتداء: <span style="color: #10b981;"><?= $times['isha_card']['start'] ?></span> | 
                    عشاء اذان: <span style="color: #f59e0b;"><?= $times['isha_card']['adhan'] ?></span> | 
                    عشاء مکروہ (نصف شب): <span style="color: #ef4444;"><?= $times['isha_card']['makrooh'] ?></span> | 
                    عشاء اختتام: <span style="color: #94a3b8;"><?= $times['isha_card']['end'] ?></span>
                </td>
            </tr>
            <tr>
                <td><strong>تہجد و رات کے فلکیاتی اوقات</strong></td>
                <td class="time-cell">
                    آخری تہائی رات کا آغاز: <span style="color: #10b981;"><?= $times['tahajjud_card']['third_start'] ?></span> | 
                    آخری سدس (چھٹا حصہ) کا آغاز: <span style="color: #f59e0b;"><?= $times['tahajjud_card']['sixth_start'] ?></span>
                </td>
            </tr>
        </tbody>
    </table>

    <!-- Controls Section -->
    <div class="details-grid">
        <div class="panel-box">
            <h3>⚙️ لوکیشن اور فقہی ترتیبات</h3>
            <form method="GET" action="index.php">
                <input type="hidden" name="date" value="<?= $dateParam ?>">
                <div class="form-row">
                    <div class="form-group">
                        <label>مقام کا نام</label>
                        <input type="text" name="city_name" class="form-control" value="<?= htmlspecialchars($cityName) ?>" required>
                    </div>
                    <div class="form-group">
                        <label>ٹائم زون (GMT)</label>
                        <input type="number" step="0.5" name="tz" class="form-control" value="<?= $tz ?>" required>
                    </div>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>Latitude (عرض بلد)</label>
                        <input type="number" step="0.000001" name="lat" class="form-control" value="<?= $lat ?>" required>
                    </div>
                    <div class="form-group">
                        <label>Longitude (طول بلد)</label>
                        <input type="number" step="0.000001" name="lng" class="form-control" value="<?= $lng ?>" required>
                    </div>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>فقہی طریقہ (عصر)</label>
                        <select name="asr" class="form-control">
                            <option value="2" <?= $asr === 2 ? 'selected' : '' ?>>حنفی (مثلِ ثانی - Shadow x2)</option>
                            <option value="1" <?= $asr === 1 ? 'selected' : '' ?>>شافعی / مالکی / حنبلی (مثلِ اول - Shadow x1)</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>فلکیاتی قاعدہ (فجر و عشاء)</label>
                        <select name="method" class="form-control">
                            <option value="KARACHI" <?= $method === 'KARACHI' ? 'selected' : '' ?>>18° - جامعہ العلوم الاسلامیہ کراچی (مسلکِ جمہور علماء)</option>
                            <option value="ISNA" <?= $method === 'ISNA' ? 'selected' : '' ?>>15° - خلافِ جمہور علماء (مفتی طیب سلیم صاحب سرگودھا)</option>
                            <option value="UMM_AL_QURA" <?= $method === 'UMM_AL_QURA' ? 'selected' : '' ?>>ام القریٰ مکہ مکرمہ</option>
                        </select>
                    </div>
                </div>

                <button type="submit" class="submit-btn">محفوظ کریں اور اپ ڈیٹ کریں</button>
            </form>
        </div>

        <div class="panel-box" style="text-align: center;">
            <h3>🧭 سمتِ قبلہ و فاصلہ</h3>
            <div style="font-size: 2.8rem; font-weight: 700; color: var(--accent-gold); margin: 10px 0; direction: ltr;">
                <?= $qibla['bearing'] ?>°
            </div>
            <div style="color: var(--accent-emerald); font-weight: 600; font-size: 1.1rem;">
                <?= $qibla['cardinal'] ?> (مغرب سے جنوب)
            </div>
            <div style="margin-top: 10px; font-size: 0.95rem; color: var(--text-muted);">
                فاصلہ کعبہ: <strong><?= number_format($qibla['distance_km']) ?> کلومیٹر</strong>
            </div>

            <hr style="border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 20px 0;">

            <h4 style="color: var(--accent-gold); margin-bottom: 12px; font-size: 1.15rem;">☀️ شمسی طریقہ سے قبلہ درستگی</h4>
            <div style="text-align: right; display: flex; flex-direction: column; gap: 10px;">
                <?php foreach ($solarQibla as $sq): ?>
                    <div style="background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 10px; padding: 10px 14px;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <strong style="color: var(--accent-gold); font-size: 0.95rem;"><?= htmlspecialchars($sq['title']) ?></strong>
                            <span style="direction: ltr; font-weight: bold; color: <?= $sq['is_observable'] ? 'var(--accent-emerald)' : 'var(--text-muted)' ?>; font-size: 1.05rem;">
                                <?= htmlspecialchars($sq['time']) ?>
                            </span>
                        </div>
                        <div style="color: var(--text-muted); font-size: 0.82rem; margin-top: 4px;">
                            <?= htmlspecialchars($sq['description']) ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>
</div>

<script>
    function updateClock() {
        const now = new Date();
        const hrs = String(now.getHours()).padStart(2, '0');
        const mins = String(now.getMinutes()).padStart(2, '0');
        const secs = String(now.getSeconds()).padStart(2, '0');
        document.getElementById('liveClock').textContent = `${hrs}:${mins}:${secs}`;
    }
    setInterval(updateClock, 1000);
    updateClock();

    const prayerTimes = [
        { name: 'فجر', time: '<?= $times['exact']['fajr'] ?>' },
        { name: 'طلوعِ آفتاب', time: '<?= $times['exact']['sunrise'] ?>' },
        { name: 'ظہر', time: '<?= $times['exact']['dhuhr'] ?>' },
        { name: 'عصر', time: '<?= $times['exact']['asr'] ?>' },
        { name: 'مغرب', time: '<?= $times['exact']['maghrib'] ?>' },
        { name: 'عشاء', time: '<?= $times['exact']['isha'] ?>' }
    ];

    function updateCountdown() {
        const now = new Date();
        const currentMins = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;

        let nextPrayer = null;
        let diffMinutes = 0;

        for (const p of prayerTimes) {
            const [h, m, s] = p.time.split(':').map(Number);
            const pMins = h * 60 + m + (s || 0) / 60;
            if (pMins > currentMins) {
                nextPrayer = p;
                diffMinutes = pMins - currentMins;
                break;
            }
        }

        if (!nextPrayer) {
            nextPrayer = prayerTimes[0];
            const [h, m, s] = nextPrayer.time.split(':').map(Number);
            diffMinutes = (24 * 60 - currentMins) + (h * 60 + m + (s || 0) / 60);
        }

        const totalSecs = Math.floor(diffMinutes * 60);
        const hLeft = String(Math.floor(totalSecs / 3600)).padStart(2, '0');
        const mLeft = String(Math.floor((totalSecs % 3600) / 60)).padStart(2, '0');
        const sLeft = String(totalSecs % 60).padStart(2, '0');

        document.getElementById('countdownClock').textContent = `${hLeft}:${mLeft}:${sLeft}`;
        document.getElementById('nextPrayerName').textContent = `اگلی نماز: ${nextPrayer.name}`;
    }
    setInterval(updateCountdown, 1000);
    updateCountdown();
</script>
</body>
</html>
