<?php
declare(strict_types=1);

namespace Minaret\Core;

/**
 * QiblaCalculator - Spherical Trigonometry / Great Circle calculation
 * to Kaaba (Makkah al-Mukarramah: 21.422487° N, 39.826206° E)
 */
class QiblaCalculator
{
    public const KAABA_LAT = 21.422487;
    public const KAABA_LNG = 39.826206;
    public const EARTH_RADIUS_KM = 6371.0;

    /**
     * Calculate Qibla bearing in degrees clockwise from True North (0° - 360°)
     * and distance to Kaaba in kilometers.
     *
     * @return array{bearing: float, distance_km: float, cardinal: string}
     */
    public static function calculate(float $latitude, float $longitude): array
    {
        $latRad = deg2rad($latitude);
        $lngRad = deg2rad($longitude);
        $kLatRad = deg2rad(self::KAABA_LAT);
        $kLngRad = deg2rad(self::KAABA_LNG);

        $deltaLng = $kLngRad - $lngRad;

        // Spherical trigonometry formula for forward azimuth
        $y = sin($deltaLng);
        $x = cos($latRad) * tan($kLatRad) - sin($latRad) * cos($deltaLng);

        $bearingRad = atan2($y, $x);
        $bearingDeg = fmod(rad2deg($bearingRad) + 360.0, 360.0);

        // Distance via Haversine formula
        $deltaLat = $kLatRad - $latRad;
        $a = sin($deltaLat / 2.0) ** 2 + cos($latRad) * cos($kLatRad) * (sin($deltaLng / 2.0) ** 2);
        $c = 2.0 * atan2(sqrt($a), sqrt(max(0.0, 1.0 - $a)));
        $distanceKm = round(self::EARTH_RADIUS_KM * $c, 1);

        return [
            'bearing'     => round($bearingDeg, 2),
            'distance_km' => $distanceKm,
            'cardinal'    => self::getCardinalDirection($bearingDeg)
        ];
    }

    private static function getCardinalDirection(float $bearing): string
    {
        $directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
        $index = (int)round($bearing / 22.5) % 16;
        return $directions[$index];
    }
}
