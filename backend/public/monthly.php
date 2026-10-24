<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/AstronomicalCore.php';
require_once __DIR__ . '/../src/HijriCalendar.php';

use Minaret\Core\AstronomicalCore;
use Minaret\Core\HijriCalendar;

$lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 31.8878;
$lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 72.4125;
$tz  = isset($_GET['tz']) ? (float)$_GET['tz'] : 5.0;
$year = isset($_GET['year']) ? (int)$_GET['year'] : (int)date('Y');
$month = isset($_GET['month']) ? (int)$_GET['month'] : (int)date('m');

$calculator = new AstronomicalCore($lat, $lng, $tz);
$daysInMonth = (int)date('t', strtotime("{$year}-{$month}-01"));

$urduMonths = [
    1 => 'جنوری', 2 => 'فروری', 3 => 'مارچ', 4 => 'اپریل', 5 => 'مئی', 6 => 'جون',
    7 => 'جولائی', 8 => 'اگست', 9 => 'ستمبر', 10 => 'اکتوبر', 11 => 'نومبر', 12 => 'دسمبر'
];
$urduWeekdays = [
    'Monday' => 'پیر', 'Tuesday' => 'منگل', 'Wednesday' => 'بدھ',
    'Thursday' => 'جمعرات', 'Friday' => 'جمعہ المبارک', 'Saturday' => 'ہفتہ', 'Sunday' => 'اتوار'
];
$monthNameUrdu = $urduMonths[$month] ?? date('F');

// Previous and next month calculation
$prevMonth = $month - 1;
$prevYear = $year;
if ($prevMonth < 1) {
    $prevMonth = 12;
    $prevYear--;
}

$nextMonth = $month + 1;
$nextYear = $year;
if ($nextMonth > 12) {
    $nextMonth = 1;
    $nextYear++;
}
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>دائمی جنتری - جدول اوقاتِ صلوٰۃ (<?= $monthNameUrdu ?> <?= $year ?>)</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&family=Noto+Nastaliq+Urdu:wght@400;700&family=Outfit:wght@400;600&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: #fff;
            color: #1e293b;
            font-family: 'Outfit', 'Noto Nastaliq Urdu', sans-serif;
            padding: 25px;
            direction: rtl;
        }

        .header-box {
            text-align: center;
            border-bottom: 2px solid #0f172a;
            padding-bottom: 15px;
            margin-bottom: 20px;
        }

        .header-box h1 {
            font-family: 'Amiri', serif;
            font-size: 2.2rem;
            color: #0f766e;
        }

        .header-meta {
            margin-top: 5px;
            font-size: 1.1rem;
            color: #64748b;
        }

        .actions-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
            gap: 10px;
        }

        .btn {
            background: #0f766e;
            color: #fff;
            padding: 8px 18px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.95rem;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .btn:hover { background: #115e59; }

        .filter-form {
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .filter-select {
            padding: 8px 12px;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            font-size: 0.95rem;
            outline: none;
        }

        .timetable {
            width: 100%;
            border-collapse: collapse;
            text-align: center;
            font-size: 0.92rem;
        }

        .timetable th, .timetable td {
            border: 1px solid #cbd5e1;
            padding: 8px 4px;
        }

        .timetable th {
            background: #0f766e;
            color: #fff;
            font-weight: 600;
        }

        .timetable tr:nth-child(even) {
            background: #f8fafc;
        }

        .friday-row {
            background: #ecfdf5 !important;
            font-weight: 600;
        }

        .sehar-iftar {
            color: #b45309;
            font-weight: 600;
        }

        @media print {
            .actions-bar, .filter-form { display: none !important; }
            body { padding: 0; }
            .timetable th { background: #0f766e !important; color: #fff !important; }
        }
    </style>
</head>
<body>

    <div class="actions-bar">
        <div>
            <a href="index.php" class="btn">⬅ واپسی ڈیش بورڈ</a>
            <a href="monthly.php?lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>&year=<?= $prevYear ?>&month=<?= $prevMonth ?>" class="btn">◀ پچھلا مہینہ</a>
            <a href="monthly.php?lat=<?= $lat ?>&lng=<?= $lng ?>&tz=<?= $tz ?>&year=<?= $nextYear ?>&month=<?= $nextMonth ?>" class="btn">اگلا مہینہ ▶</a>
        </div>

        <!-- Month & Year Filter Form -->
        <form method="GET" action="monthly.php" class="filter-form">
            <input type="hidden" name="lat" value="<?= $lat ?>">
            <input type="hidden" name="lng" value="<?= $lng ?>">
            <input type="hidden" name="tz" value="<?= $tz ?>">
            <select name="month" class="filter-select">
                <?php for ($m = 1; $m <= 12; $m++): ?>
                    <option value="<?= $m ?>" <?= $m === $month ? 'selected' : '' ?>><?= $urduMonths[$m] ?></option>
                <?php endfor; ?>
            </select>
            <select name="year" class="filter-select">
                <?php for ($y = 2024; $y <= 2035; $y++): ?>
                    <option value="<?= $y ?>" <?= $y === $year ? 'selected' : '' ?>><?= $y ?></option>
                <?php endfor; ?>
            </select>
            <button type="submit" class="btn">فلٹر کریں</button>
            <button type="button" onclick="window.print()" class="btn">🖨️ پرنٹ / PDF سیو کریں</button>
        </form>
    </div>

    <div class="header-box">
        <h1>جدول اوقاتِ صلوٰۃ (دائمی جنتری)</h1>
        <div class="header-meta">
            مقام: فروکہ / سرگودھا (طول بلد: <?= round($lng, 2) ?>° E, عرض بلد: <?= round($lat, 2) ?>° N) | مہینہ: <strong><?= $monthNameUrdu ?> <?= $year ?>ء</strong>
        </div>
    </div>

    <table class="timetable">
        <thead>
            <tr>
                <th>تاریخ</th>
                <th>دن</th>
                <th>ہجری تاریخ</th>
                <th>ختمِ سحر (-2m)</th>
                <th>فجر</th>
                <th>طلوعِ آفتاب</th>
                <th>ظہر</th>
                <th>عصر (حنفی)</th>
                <th>وقتِ افطار (+2m)</th>
                <th>مغرب</th>
                <th>عشاء</th>
            </tr>
        </thead>
        <tbody>
            <?php
            for ($d = 1; $d <= $daysInMonth; $d++):
                $curDate = new \DateTimeImmutable(sprintf('%04d-%02d-%02d', $year, $month, $d));
                $pTimes = $calculator->calculateTimes($curDate);
                $pHijri = HijriCalendar::fromGregorian($curDate);
                $dayEng = $curDate->format('l');
                $dayUrdu = $urduWeekdays[$dayEng] ?? $dayEng;
                $isFriday = ($dayEng === 'Friday');
            ?>
            <tr class="<?= $isFriday ? 'friday-row' : '' ?>">
                <td><?= $d ?></td>
                <td><?= $dayUrdu ?></td>
                <td><?= $pHijri['formatted_urdu'] ?></td>
                <td class="sehar-iftar"><?= $pTimes['fasting']['sehar_end'] ?></td>
                <td><?= $pTimes['exact']['fajr'] ?></td>
                <td><?= $pTimes['exact']['sunrise'] ?></td>
                <td><?= $pTimes['exact']['dhuhr'] ?></td>
                <td><?= $pTimes['exact']['asr'] ?></td>
                <td class="sehar-iftar"><?= $pTimes['fasting']['iftar_time'] ?></td>
                <td><?= $pTimes['exact']['maghrib'] ?></td>
                <td><?= $pTimes['exact']['isha'] ?></td>
            </tr>
            <?php endfor; ?>
        </tbody>
    </table>

</body>
</html>
