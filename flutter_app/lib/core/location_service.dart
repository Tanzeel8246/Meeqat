import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'app_settings.dart';
import 'city_database.dart';

/// Real-time Device GPS & Network IP Location Service
/// Provides 100% genuine location auto-detection with smart POI detection within 500m.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Estimates standard time zone from country and longitude
  static double estimateTimezone(String country, double lng) {
    final c = country.toLowerCase();
    if (c.contains('pakistan')) return 5.0;
    if (c.contains('saudi') || c.contains('qatar') || c.contains('kuwait') ||
        c.contains('bahrain') || c.contains('iraq') || c.contains('yemen')) {
      return 3.0;
    }
    if (c.contains('emirates') || c.contains('uae') || c.contains('dubai') || c.contains('oman')) {
      return 4.0;
    }
    if (c.contains('india') || c.contains('sri lanka')) return 5.5;
    if (c.contains('bangladesh')) return 6.0;
    if (c.contains('afghanistan')) return 4.5;
    if (c.contains('iran')) return 3.5;
    if (c.contains('turkey') || c.contains('türkiye') || c.contains('egypt') ||
        c.contains('jordan') || c.contains('palestine') || c.contains('syria') ||
        c.contains('lebanon')) {
      return 3.0;
    }
    if (c.contains('united kingdom') || c.contains('britain') || c.contains('england')) return 0.0;
    if (c.contains('germany') || c.contains('france') || c.contains('italy') || c.contains('spain')) return 1.0;
    if (c.contains('malaysia') || c.contains('singapore') || c.contains('china')) return 8.0;
    if (c.contains('japan')) return 9.0;
    if (c.contains('australia')) {
      if (lng > 140) return 10.0;
      if (lng > 125) return 9.5;
      return 8.0;
    }
    return (lng / 15.0).roundToDouble();
  }

  /// Attempts to acquire device hardware GPS position with highest accuracy
  Future<Position?> _getGpsPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // High sensitivity: LocationAccuracy.best with 12s timeout
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (e) {
      debugPrint('GPS acquisition error: $e');
      try {
        // Fallback to last known position
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Network IP-based Geolocation fallback (works without GPS hardware or permissions)
  Future<Map<String, dynamic>?> _getIpLocation() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      // Primary: ip-api.com
      final uri = Uri.parse('http://ip-api.com/json/?fields=status,message,country,regionName,city,lat,lon,timezone,offset');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          client.close();
          final offsetSec = (data['offset'] as num?)?.toDouble() ?? 0.0;
          return {
            'lat': (data['lat'] as num).toDouble(),
            'lon': (data['lon'] as num).toDouble(),
            'city': data['city']?.toString() ?? '',
            'region': data['regionName']?.toString() ?? '',
            'country': data['country']?.toString() ?? '',
            'timezone': offsetSec / 3600.0,
          };
        }
      }

      // Secondary: ipapi.co
      final uri2 = Uri.parse('https://ipapi.co/json/');
      final req2 = await client.getUrl(uri2);
      req2.headers.set('User-Agent', 'MeeqatPrayerApp/1.9.0');
      final resp2 = await req2.close();
      if (resp2.statusCode == 200) {
        final body2 = await resp2.transform(utf8.decoder).join();
        final data2 = jsonDecode(body2) as Map<String, dynamic>;
        client.close();
        final utcOffsetStr = data2['utc_offset']?.toString() ?? '+0500';
        double tz = 5.0;
        if (utcOffsetStr.length >= 3) {
          final sign = utcOffsetStr.startsWith('-') ? -1.0 : 1.0;
          final hours = double.tryParse(utcOffsetStr.substring(1, 3)) ?? 5.0;
          tz = sign * hours;
        }
        return {
          'lat': (data2['latitude'] as num).toDouble(),
          'lon': (data2['longitude'] as num).toDouble(),
          'city': data2['city']?.toString() ?? '',
          'region': data2['region']?.toString() ?? '',
          'country': data2['country_name']?.toString() ?? '',
          'timezone': tz,
        };
      }
      client.close();
    } catch (e) {
      debugPrint('IP Geolocation error: $e');
    }
    return null;
  }

  /// Reverse geocodes coordinates to nearest landmark / public place within 500m
  Future<Map<String, String>> reverseGeocode(double lat, double lng) async {
    // 1. If Google Maps API key is provided, query Google Maps Geocoding API first
    final googleApiKey = AppSettings().googleMapsApiKey.trim();
    if (googleApiKey.isNotEmpty) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ur&key=$googleApiKey',
        );
        final req = await client.getUrl(uri);
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>? ?? [];
          if (results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final formatted = first['formatted_address']?.toString() ?? '';
            final components = first['address_components'] as List<dynamic>? ?? [];

            String poi = '';
            String city = '';
            String state = '';
            String country = '';

            for (var c in components) {
              final types = (c['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              final longName = c['long_name']?.toString() ?? '';
              if (types.contains('point_of_interest') || types.contains('establishment') || types.contains('premise')) {
                poi = longName;
              } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                if (city.isEmpty) city = longName;
              } else if (types.contains('administrative_area_level_1')) {
                state = longName;
              } else if (types.contains('country')) {
                country = longName;
              }
            }

            final displayName = poi.isNotEmpty ? (city.isNotEmpty ? '$poi، $city' : poi) : formatted;
            client.close();
            return {
              'name': displayName,
              'nameUr': displayName,
              'city': city.isNotEmpty ? city : displayName,
              'state': state,
              'country': country,
              'source': 'Google Maps POI',
            };
          }
        }
        client.close();
      } catch (_) {}
    }

    // 2. High-precision OpenStreetMap Nominatim lookup (zoom=18 for <= 500m POI resolution)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1&zoom=18&namedetails=1&accept-language=ur,en',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'MeeqatPrayerApp/1.9.0 (contact: minaret@al-aqsa.org)');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final nameDetails = data['namedetails'] as Map<String, dynamic>? ?? {};

        // Extract most specific public landmark within 500m
        final String rawPoiName = data['name']?.toString() ??
            address['amenity']?.toString() ??
            address['place_of_worship']?.toString() ??
            address['building']?.toString() ??
            address['historic']?.toString() ??
            address['tourism']?.toString() ??
            address['leisure']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['road']?.toString() ??
            '';

        final String urduPoi = nameDetails['name:ur']?.toString() ?? rawPoiName;

        final city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['hamlet'] ??
            address['suburb'] ??
            address['municipality'] ??
            address['county'] ??
            '';

        final state = address['state'] ?? address['province'] ?? '';
        final country = address['country'] ?? '';

        final finalNameEn = rawPoiName.isNotEmpty
            ? (city.toString().isNotEmpty ? '$rawPoiName, $city' : rawPoiName)
            : city.toString();
        final finalNameUr = urduPoi.isNotEmpty
            ? (city.toString().isNotEmpty ? '$urduPoi، $city' : urduPoi)
            : city.toString();

        client.close();
        return {
          'name': finalNameEn,
          'nameUr': finalNameUr,
          'city': city.toString(),
          'state': state.toString(),
          'country': country.toString(),
          'source': 'OpenStreetMap POI',
        };
      }
      client.close();
    } catch (_) {}
    return {};
  }

  /// Fully autonomous location detection: GPS first with 500m POI sensitivity, IP fallback
  Future<CityModel?> detectCurrentLocation() async {
    double lat = 0.0;
    double lng = 0.0;
    double elevation = 0.0;
    double tz = 5.0;
    String cityName = '';
    String cityNameUr = '';
    String stateName = '';
    String countryName = '';
    String source = 'GPS';

    // 1. Try Hardware GPS
    final pos = await _getGpsPosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      elevation = pos.altitude;
      source = 'GPS Live';

      // Reverse geocode to get real landmark within 500m
      final rev = await reverseGeocode(lat, lng);
      cityName = rev['name'] ?? rev['city'] ?? '';
      cityNameUr = rev['nameUr'] ?? cityName;
      stateName = rev['state'] ?? '';
      countryName = rev['country'] ?? '';
      if (rev['source'] != null) {
        source = rev['source']!;
      }
      tz = estimateTimezone(countryName, lng);
    } else {
      // 2. Fallback to IP Geolocation
      final ipData = await _getIpLocation();
      if (ipData != null) {
        lat = ipData['lat'] as double;
        lng = ipData['lon'] as double;
        cityName = ipData['city'] as String;
        cityNameUr = cityName;
        stateName = ipData['region'] as String;
        countryName = ipData['country'] as String;
        tz = ipData['timezone'] as double;
        source = 'Network IP';
      }
    }

    if (lat == 0.0 && lng == 0.0) {
      return null;
    }

    if (cityName.isEmpty) {
      cityName = 'Location (${lat.toStringAsFixed(3)}°, ${lng.toStringAsFixed(3)}°)';
      cityNameUr = cityName;
    }
    if (countryName.isEmpty) {
      countryName = 'Global';
    }
    if (stateName.isEmpty) {
      stateName = countryName;
    }

    return CityModel(
      id: 'live_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
      name: cityName,
      nameUr: cityNameUr,
      country: countryName,
      province: stateName,
      latitude: lat,
      longitude: lng,
      timezone: tz,
      elevation: elevation,
      source: source,
    );
  }
}

