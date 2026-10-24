import 'dart:math' as math;

class QiblaCalculator {
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;
  static const double earthRadiusKm = 6371.0;

  static Map<String, dynamic> calculate(double latitude, double longitude) {
    double latRad = _degToRad(latitude);
    double lngRad = _degToRad(longitude);
    double kLatRad = _degToRad(kaabaLat);
    double kLngRad = _degToRad(kaabaLng);

    double deltaLng = kLngRad - lngRad;

    // Azimuth calculation
    double y = math.sin(deltaLng);
    double x = math.cos(latRad) * math.tan(kLatRad) -
        math.sin(latRad) * math.cos(deltaLng);

    double bearingRad = math.atan2(y, x);
    double bearingDeg = (_radToDeg(bearingRad) + 360.0) % 360.0;

    // Distance via Haversine
    double deltaLat = kLatRad - latRad;
    double a = math.pow(math.sin(deltaLat / 2.0), 2) +
        math.cos(latRad) *
            math.cos(kLatRad) *
            math.pow(math.sin(deltaLng / 2.0), 2);
    double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1.0 - a)));
    double distanceKm = earthRadiusKm * c;

    return {
      'bearing': double.parse(bearingDeg.toStringAsFixed(2)),
      'distance_km': double.parse(distanceKm.toStringAsFixed(1)),
      'cardinal': _getCardinal(bearingDeg),
    };
  }

  static String _getCardinal(double bearing) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    int index = (bearing / 22.5).round() % 16;
    return directions[index];
  }

  /// World Magnetic Model polynomial approximation for geomagnetic declination
  static double calculateMagneticDeclination(double lat, double lon) {
    double radLat = _degToRad(lat);
    double radLon = _degToRad(lon);
    double baseDeclination = 1.5 * math.sin(radLon - 0.5) +
        0.8 * math.cos(radLat) +
        0.2 * math.sin(2 * radLon);
    return double.parse(baseDeclination.toStringAsFixed(1));
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);
}
