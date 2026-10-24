<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/AstronomicalCore.php';
require_once __DIR__ . '/../src/QiblaCalculator.php';
require_once __DIR__ . '/../src/HijriCalendar.php';

use Minaret\Core\AstronomicalCore;
use Minaret\Core\QiblaCalculator;
use Minaret\Core\HijriCalendar;

$lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.8878;
$lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.4125;
$tz  = isset($_GET['tz']) ? (float)$_GET['tz'] : 5.0;
$today = new \DateTimeImmutable('today');

$calculator = new AstronomicalCore($lat, $lng, $tz);
$times = $calculator->calculateTimes($today);
$hijri = HijriCalendar::fromGregorian($today);
$qibla = QiblaCalculator::calculate($lat, $lng);
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>جامع مسجد اسکرین - Minaret Mosque Display</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@700&family=Noto+Nastaliq+Urdu:wght@700&family=Outfit:wght@600;800&display=swap" rel="stylesheet">
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background: #020617;
            color: #fff;
            font-family: 'Outfit', 'Noto Nastaliq Urdu', sans-serif;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 30px 45px;
            overflow: hidden;
        }

        /* Top Bar */
        .top-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid rgba(245, 158, 11, 0.3);
            padding-bottom: 20px;
        }

        .mosque-title {
            font-family: 'Amiri', serif;
            font-size: 2.8rem;
            color: #f59e0b;
        }

        .calendar-bar {
            display: flex;
            gap: 30px;
            font-size: 1.5rem;
            color: #94a3b8;
        }

        .calendar-bar span strong {
            color: #10b981;
        }

        /* Center Big Clock & Next Prayer */
        .center-hero {
            display: flex;
            justify-content: space-around;
            align-items: center;
            background: rgba(15, 23, 42, 0.7);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 24px;
            padding: 35px;
            margin: 25px 0;
        }

        .big-clock {
            font-size: 6.5rem;
            font-weight: 800;
            letter-spacing: 4px;
            color: #fff;
            text-shadow: 0 0 40px rgba(16, 185, 129, 0.4);
        }

        .next-prayer-banner {
            text-align: center;
            border-right: 3px solid rgba(245, 158, 11, 0.4);
            padding-right: 40px;
        }

        .next-title {
            font-size: 1.8rem;
            color: #f59e0b;
            font-family: 'Amiri', serif;
        }

        .countdown-digits {
            font-size: 4.5rem;
            font-weight: 800;
            color: #10b981;
        }

        /* Prayer Times Board */
        .prayers-board {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 20px;
        }

        .board-card {
            background: #0f172a;
            border: 2px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            padding: 25px 15px;
            text-align: center;
            transition: all 0.3s;
        }

        .board-card.current {
            border-color: #10b981;
            background: rgba(16, 185, 129, 0.15);
            box-shadow: 0 0 30px rgba(16, 185, 129, 0.3);
        }

        .board-name {
            font-family: 'Amiri', serif;
            font-size: 2.2rem;
            color: #f59e0b;
            margin-bottom: 15px;
        }

        .board-time {
            font-size: 3.2rem;
            font-weight: 800;
            color: #fff;
            direction: ltr;
        }

        .board-label {
            font-size: 1rem;
            color: #94a3b8;
            margin-top: 5px;
        }

        /* Footer ticker */
        .footer-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: #64748b;
            font-size: 1.2rem;
            padding-top: 15px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
        }
    </style>
</head>
<body>

    <div class="top-bar">
        <div class="mosque-title">🕌 جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)</div>
        <div class="calendar-bar">
            <span>عیسوی تاریخ: <strong><?= $today->format('d F Y') ?></strong></span>
            <span>ہجری تاریخ: <strong><?= $hijri['formatted_urdu'] ?></strong></span>
        </div>
    </div>

    <div class="center-hero">
        <div class="big-clock" id="displayClock">--:--:--</div>
        <div class="next-prayer-banner">
            <div class="next-title" id="dispNextName">اگلی نماز کی تیاری</div>
            <div class="countdown-digits" id="dispCountdown">00:00:00</div>
        </div>
    </div>

    <div class="prayers-board">
        <div class="board-card">
            <div class="board-name">فجر</div>
            <div class="board-time"><?= $times['fajr'] ?></div>
            <div class="board-label">ابتداء وقت</div>
        </div>
        <div class="board-card">
            <div class="board-name">ظہر</div>
            <div class="board-time"><?= $times['dhuhr'] ?></div>
            <div class="board-label">ابتداء وقت</div>
        </div>
        <div class="board-card">
            <div class="board-name">عصر</div>
            <div class="board-time"><?= $times['asr'] ?></div>
            <div class="board-label">حنفی وقت</div>
        </div>
        <div class="board-card">
            <div class="board-name">مغرب</div>
            <div class="board-time"><?= $times['maghrib'] ?></div>
            <div class="board-label">غروبِ آفتاب</div>
        </div>
        <div class="board-card">
            <div class="board-name">عشاء</div>
            <div class="board-time"><?= $times['isha'] ?></div>
            <div class="board-label">ابتداء وقت</div>
        </div>
    </div>

    <div class="footer-info">
        <div>مقام: فروکہ / سرگودھا (طول بلد: <?= round($lng, 2) ?>° E, عرض بلد: <?= round($lat, 2) ?>° N)</div>
        <div>سمتِ قبلہ: <strong><?= $qibla['bearing'] ?>°</strong> | فاصلہ کعبہ: <strong><?= number_format($qibla['distance_km']) ?> km</strong></div>
    </div>

    <script>
        function refreshTime() {
            const now = new Date();
            const h = String(now.getHours()).padStart(2, '0');
            const m = String(now.getMinutes()).padStart(2, '0');
            const s = String(now.getSeconds()).padStart(2, '0');
            document.getElementById('displayClock').textContent = `${h}:${m}:${s}`;
        }
        setInterval(refreshTime, 1000);
        refreshTime();

        const schedule = [
            { name: 'فجر', time: '<?= $times['fajr'] ?>' },
            { name: 'ظہر', time: '<?= $times['dhuhr'] ?>' },
            { name: 'عصر', time: '<?= $times['asr'] ?>' },
            { name: 'مغرب', time: '<?= $times['maghrib'] ?>' },
            { name: 'عشاء', time: '<?= $times['isha'] ?>' }
        ];

        function refreshCountdown() {
            const now = new Date();
            const currentMins = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;
            let next = null;
            let diff = 0;

            for (const s of schedule) {
                const [h, m] = s.time.split(':').map(Number);
                const pMins = h * 60 + m;
                if (pMins > currentMins) {
                    next = s;
                    diff = pMins - currentMins;
                    break;
                }
            }

            if (!next) {
                next = schedule[0];
                const [h, m] = next.time.split(':').map(Number);
                diff = (24 * 60 - currentMins) + (h * 60 + m);
            }

            const totalSecs = Math.floor(diff * 60);
            const hl = String(Math.floor(totalSecs / 3600)).padStart(2, '0');
            const ml = String(Math.floor((totalSecs % 3600) / 60)).padStart(2, '0');
            const sl = String(totalSecs % 60).padStart(2, '0');

            document.getElementById('dispCountdown').textContent = `${hl}:${ml}:${sl}`;
            document.getElementById('dispNextName').textContent = `اگلی اذان: ${next.name}`;
        }
        setInterval(refreshCountdown, 1000);
        refreshCountdown();
    </script>
</body>
</html>
