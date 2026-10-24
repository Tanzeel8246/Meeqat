<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/CityDatabase.php';

use Minaret\Core\CityDatabase;

$query = $_GET['q'] ?? '';
$cities = CityDatabase::search($query);
?>
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>گزیٹیئر - شہروں کا جغرافیائی ڈیٹا بیس</title>
    <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@700&family=Outfit:wght@400;600&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: #0b0f19;
            color: #f1f5f9;
            font-family: 'Outfit', sans-serif;
            padding: 30px 20px;
            display: flex;
            justify-content: center;
        }

        .container {
            width: 100%;
            max-width: 950px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            padding-bottom: 15px;
            margin-bottom: 25px;
        }

        .header h1 {
            font-family: 'Amiri', serif;
            font-size: 2rem;
            color: #f59e0b;
        }

        .btn-back {
            background: rgba(255, 255, 255, 0.1);
            color: #fff;
            padding: 8px 16px;
            border-radius: 8px;
            text-decoration: none;
        }

        .search-box {
            display: flex;
            gap: 10px;
            margin-bottom: 25px;
        }

        .search-input {
            flex: 1;
            background: #1e293b;
            border: 1px solid rgba(255, 255, 255, 0.1);
            padding: 12px 18px;
            border-radius: 8px;
            color: #fff;
            font-size: 1rem;
            outline: none;
        }

        .search-btn {
            background: #10b981;
            color: #fff;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
        }

        .cities-table {
            width: 100%;
            border-collapse: collapse;
            background: #131d31;
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }

        .cities-table th, .cities-table td {
            padding: 14px 18px;
            text-align: right;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .cities-table th {
            background: #1e293b;
            color: #f59e0b;
            font-weight: 600;
        }

        .action-link {
            background: rgba(16, 185, 129, 0.2);
            color: #10b981;
            padding: 6px 14px;
            border-radius: 6px;
            text-decoration: none;
            font-size: 0.9rem;
            transition: 0.2s;
        }

        .action-link:hover {
            background: #10b981;
            color: #fff;
        }
    </style>
</head>
<body>

<div class="container">
    <div class="header">
        <h1>🗺️ گزیٹیئر - شہروں کا جغرافیائی ڈیٹا بیس (Gazetteer)</h1>
        <a href="index.php" class="btn-back">⬅ ہوم پیج</a>
    </div>

    <form method="GET" action="gazetteer.php" class="search-box">
        <input type="text" name="q" class="search-input" placeholder="شہر کا نام یا ملک تلاش کریں..." value="<?= htmlspecialchars($query) ?>">
        <button type="submit" class="search-btn">تلاش کریں</button>
        <button type="button" onclick="detectLiveGps()" class="search-btn" style="background: #0284c7;">📍 لائیو GPS لوکیشن</button>
    </form>

    <table class="cities-table">
        <thead>
            <tr>
                <th>شہر</th>
                <th>ملک / صوبہ</th>
                <th>Latitude (عرض بلد)</th>
                <th>Longitude (طول بلد)</th>
                <th>ٹائم زون</th>
                <th>ایکشن</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($cities as $c): ?>
            <tr>
                <td><strong><?= htmlspecialchars($c['name']) ?></strong></td>
                <td><?= htmlspecialchars($c['province']) ?>, <?= htmlspecialchars($c['country']) ?></td>
                <td><?= $c['latitude'] ?>° N</td>
                <td><?= $c['longitude'] ?>° E</td>
                <td>GMT <?= $c['timezone'] >= 0 ? "+{$c['timezone']}" : $c['timezone'] ?></td>
                <td>
                    <a href="index.php?city_name=<?= urlencode($c['name'] . ', ' . $c['country']) ?>&lat=<?= $c['latitude'] ?>&lng=<?= $c['longitude'] ?>&tz=<?= $c['timezone'] ?>" class="action-link">
                        موجودہ بنائیں ✔
                    </a>
                    <a href="https://www.google.com/maps/search/?api=1&query=<?= $c['latitude'] ?>,<?= $c['longitude'] ?>" target="_blank" class="action-link" style="background: rgba(56, 189, 248, 0.2); color: #38bdf8; margin-right: 6px;">
                        🗺️ گوگل میپ
                    </a>
                </td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>

<script>
function detectLiveGps() {
    if (!navigator.geolocation) {
        alert('آپ کے براؤزر میں جیو لوکیشن دستیاب نہیں ہے۔');
        return;
    }
    const btn = event.target;
    btn.innerText = 'لوکیشن تلاش جاری...';
    btn.disabled = true;
    navigator.geolocation.getCurrentPosition(function(pos) {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        fetch(`../api/geocode.php?lat=${lat}&lng=${lng}`)
            .then(r => r.json())
            .then(data => {
                if (data.cities && data.cities.length > 0) {
                    const c = data.cities[0];
                    window.location.href = `index.php?city_name=${encodeURIComponent(c.name + ', ' + c.country)}&lat=${c.lat}&lng=${c.lng}&tz=${c.tz}`;
                } else {
                    window.location.href = `index.php?city_name=${encodeURIComponent('Live GPS (' + lat.toFixed(2) + '°, ' + lng.toFixed(2) + '°)')}&lat=${lat}&lng=${lng}&tz=5`;
                }
            })
            .catch(() => {
                window.location.href = `index.php?city_name=LiveGPS&lat=${lat}&lng=${lng}&tz=5`;
            });
    }, function(err) {
        btn.innerText = '📍 لائیو GPS لوکیشن';
        btn.disabled = false;
        alert('GPS لوکیشن حاصل نہیں ہو سکی: ' + err.message);
    });
}
</script>
</body>
</html>
