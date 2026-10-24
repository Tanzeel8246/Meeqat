import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/city_database.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/app_settings.dart';
import '../core/location_service.dart';
import '../widgets/minaret_bottom_nav.dart';
import 'monthly_screen.dart';

class GazetteerScreen extends StatefulWidget {
  const GazetteerScreen({super.key});

  @override
  State<GazetteerScreen> createState() => _GazetteerScreenState();
}

class _GazetteerScreenState extends State<GazetteerScreen> {
  String _search = '';
  bool _isAutoDetecting = false;
  bool _isSearchingOnline = false;
  Timer? _debounceTimer;

  final List<CityModel> _onlineResults = [];
  final AppSettings _settings = AppSettings();

  final _customNameCtrl = TextEditingController(text: 'Farooka');
  final _customLatCtrl = TextEditingController(text: '31.8878');
  final _customLngCtrl = TextEditingController(text: '72.4125');
  final _customTzCtrl = TextEditingController(text: '5.0');

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _customNameCtrl.dispose();
    _customLatCtrl.dispose();
    _customLngCtrl.dispose();
    _customTzCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _search = val;
    });

    _debounceTimer?.cancel();
    if (val.trim().length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _searchGlobalOnline(val.trim());
      });
    } else {
      setState(() {
        _onlineResults.clear();
        _isSearchingOnline = false;
      });
    }
  }

  double _estimateTimezone(String country, double lng) {
    final c = country.toLowerCase();
    if (c.contains('pakistan')) return 5.0;
    if (c.contains('saudi') || c.contains('qatar') || c.contains('kuwait') || c.contains('bahrain') || c.contains('iraq') || c.contains('yemen')) return 3.0;
    if (c.contains('emirates') || c.contains('uae') || c.contains('dubai') || c.contains('oman')) return 4.0;
    if (c.contains('india') || c.contains('sri lanka')) return 5.5;
    if (c.contains('bangladesh')) return 6.0;
    if (c.contains('afghanistan')) return 4.5;
    if (c.contains('iran')) return 3.5;
    if (c.contains('turkey') || c.contains('türkiye') || c.contains('egypt') || c.contains('jordan') || c.contains('palestine') || c.contains('syria') || c.contains('lebanon')) return 3.0;
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

  Future<List<CityModel>> _fetchFromOpenMeteo(String query) async {
    final list = <CityModel>[];
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=20&format=json',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'MinaretModern/1.5.1');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        for (var item in results) {
          final String name = item['name']?.toString() ?? query;
          final String country = item['country']?.toString() ?? '';
          final String state = item['admin1']?.toString() ?? item['admin2']?.toString() ?? '';
          final double lat = (item['latitude'] as num).toDouble();
          final double lng = (item['longitude'] as num).toDouble();
          final double elev = (item['elevation'] as num?)?.toDouble() ?? 0.0;
          final double tz = _estimateTimezone(country, lng);

          list.add(CityModel(
            id: 'om_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
            name: name,
            country: country.isNotEmpty ? country : 'Global',
            province: state.isNotEmpty ? state : name,
            latitude: lat,
            longitude: lng,
            timezone: tz,
            elevation: elev,
          ));
        }
      }
      client.close();
    } catch (_) {}
    return list;
  }

  Future<List<CityModel>> _fetchFromPhoton(String query) async {
    final list = <CityModel>[];
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=20',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'MinaretModern/1.5.1');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        for (var f in features) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final geom = f['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [0.0, 0.0];
          final String name = props['name']?.toString() ?? props['city']?.toString() ?? query;
          final String country = props['country']?.toString() ?? '';
          final String state = props['state']?.toString() ?? props['county']?.toString() ?? '';
          final double lng = (coords[0] as num).toDouble();
          final double lat = (coords[1] as num).toDouble();
          final double tz = _estimateTimezone(country, lng);

          list.add(CityModel(
            id: 'ph_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
            name: name,
            country: country.isNotEmpty ? country : 'Global',
            province: state.isNotEmpty ? state : name,
            latitude: lat,
            longitude: lng,
            timezone: tz,
          ));
        }
      }
      client.close();
    } catch (_) {}
    return list;
  }

  Future<List<CityModel>> _fetchFromNominatim(String query) async {
    final list = <CityModel>[];
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=15',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'MinaretModernPrayerApp/1.5 (contact: minaret@al-aqsa.org)');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final results = jsonDecode(body) as List<dynamic>? ?? [];
        for (var item in results) {
          final addr = item['address'] as Map<String, dynamic>? ?? {};
          final String name = addr['city'] ?? addr['town'] ?? addr['village'] ?? item['name'] ?? query;
          final String country = addr['country']?.toString() ?? '';
          final String state = addr['state']?.toString() ?? addr['county']?.toString() ?? '';
          final double lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final double lng = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;
          if (lat == 0.0 && lng == 0.0) continue;
          final double tz = _estimateTimezone(country, lng);

          list.add(CityModel(
            id: 'nom_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
            name: name,
            country: country.isNotEmpty ? country : 'Global',
            province: state.isNotEmpty ? state : name,
            latitude: lat,
            longitude: lng,
            timezone: tz,
          ));
        }
      }
      client.close();
    } catch (_) {}
    return list;
  }

  Future<List<CityModel>> _fetchFromGoogleMaps(String query) async {
    final list = <CityModel>[];
    final apiKey = _settings.googleMapsApiKey.trim();
    if (apiKey.isEmpty) return list;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final lang = AppLocale.isUrdu ? 'ur' : 'en';
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey&language=$lang',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Meeqat/1.5.1 (GoogleMaps Integration)');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        for (var item in results) {
          final formatted = item['formatted_address']?.toString() ?? query;
          final geometry = item['geometry'] as Map<String, dynamic>? ?? {};
          final location = geometry['location'] as Map<String, dynamic>? ?? {};
          final double lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
          final double lng = (location['lng'] as num?)?.toDouble() ?? 0.0;
          if (lat == 0.0 && lng == 0.0) continue;

          String cityName = '';
          String province = '';
          String country = '';

          final components = item['address_components'] as List<dynamic>? ?? [];
          for (var comp in components) {
            final types = (comp['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final longName = comp['long_name']?.toString() ?? '';
            if (types.contains('locality') || types.contains('postal_town') || types.contains('administrative_area_level_2')) {
              if (cityName.isEmpty) cityName = longName;
            }
            if (types.contains('administrative_area_level_1')) {
              province = longName;
            }
            if (types.contains('country')) {
              country = longName;
            }
          }

          if (cityName.isEmpty) {
            cityName = formatted.split(',').first.trim();
          }

          final double tz = _estimateTimezone(country, lng);

          list.add(CityModel(
            id: 'gm_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
            name: cityName,
            country: country.isNotEmpty ? country : 'Global',
            province: province.isNotEmpty ? province : (formatted.length > 30 ? formatted.substring(0, 30) : formatted),
            latitude: lat,
            longitude: lng,
            timezone: tz,
            source: 'Google Maps',
          ));
        }
      }
      client.close();
    } catch (_) {}
    return list;
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String name) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.t(ur: 'گوگل میپ اوپن نہیں ہو سکا', en: 'Could not open Google Maps')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<List<CityModel>> _fetchFromBackendGeocode(String query) async {
    final list = <CityModel>[];
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'http://localhost:8080/api/geocode.php?q=${Uri.encodeComponent(query)}',
      );
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final cities = data['cities'] as List<dynamic>? ?? [];
        for (var c in cities) {
          list.add(CityModel(
            id: c['id']?.toString() ?? 'bg_${c['lat']}_${c['lng']}',
            name: c['name']?.toString() ?? query,
            nameUr: c['nameUr']?.toString() ?? '',
            country: c['country']?.toString() ?? 'Global',
            province: c['province']?.toString() ?? '',
            latitude: (c['lat'] as num).toDouble(),
            longitude: (c['lng'] as num).toDouble(),
            timezone: (c['tz'] as num).toDouble(),
            elevation: (c['elevation'] as num?)?.toDouble() ?? 0.0,
            source: 'Google Maps',
          ));
        }
      }
      client.close();
    } catch (_) {}
    return list;
  }

  Future<void> _searchGlobalOnline(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    setState(() => _isSearchingOnline = true);

    final mappedEnglish = CityDatabase.urduToEnglishMap[q];
    final futures = <Future<List<CityModel>>>[
      _fetchFromBackendGeocode(q),
      if (_settings.hasGoogleMapsApiKey) _fetchFromGoogleMaps(q),
      if (_settings.hasGoogleMapsApiKey && mappedEnglish != null && mappedEnglish.toLowerCase() != q.toLowerCase())
        _fetchFromGoogleMaps(mappedEnglish),
      _fetchFromOpenMeteo(q),
      if (mappedEnglish != null && mappedEnglish.toLowerCase() != q.toLowerCase())
        _fetchFromOpenMeteo(mappedEnglish),
      _fetchFromPhoton(q),
      if (mappedEnglish != null && mappedEnglish.toLowerCase() != q.toLowerCase())
        _fetchFromPhoton(mappedEnglish),
      _fetchFromNominatim(q),
      if (mappedEnglish != null && mappedEnglish.toLowerCase() != q.toLowerCase())
        _fetchFromNominatim(mappedEnglish),
    ];

    final responses = await Future.wait(futures);
    final combinedOnline = <CityModel>[];

    for (var sublist in responses) {
      for (var c in sublist) {
        final bool isDuplicate = combinedOnline.any((existing) {
          final latDiff = (existing.latitude - c.latitude).abs();
          final lngDiff = (existing.longitude - c.longitude).abs();
          return (latDiff < 0.04 && lngDiff < 0.04) ||
              (existing.name.toLowerCase() == c.name.toLowerCase() &&
                  existing.country.toLowerCase() == c.country.toLowerCase());
        });
        if (!isDuplicate) {
          combinedOnline.add(c);
        }
      }
    }

    if (mounted) {
      setState(() {
        _onlineResults.clear();
        _onlineResults.addAll(combinedOnline);
        _isSearchingOnline = false;
      });
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _isAutoDetecting = true);
    try {
      final detected = await LocationService().detectCurrentLocation();
      if (!mounted) return;
      setState(() => _isAutoDetecting = false);

      if (detected != null) {
        _settings.setDefaultCity(detected);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t(
                ur: '📍 اصل لائیو لوکیشن مل گئی (${detected.source}): ${detected.name} (${detected.latitude.toStringAsFixed(3)}°, ${detected.longitude.toStringAsFixed(3)}°)',
                en: '📍 Live location detected (${detected.source}): ${detected.name} (${detected.latitude.toStringAsFixed(3)}°, ${detected.longitude.toStringAsFixed(3)}°)',
              ),
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, detected);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t(
                ur: 'لوکیشن حاصل نہیں ہو سکی۔ براہ کرم GPS یا انٹرنیٹ کنکشن چیک کریں۔',
                en: 'Could not detect location. Please check GPS and internet.',
              ),
            ),
            backgroundColor: Colors.amber[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAutoDetecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localMatches = CityDatabase.search(_search);
    final combinedCities = <CityModel>[];

    // Priority 1: Local DB matches
    combinedCities.addAll(localMatches);

    // Priority 2: Saved locations
    for (var saved in _settings.savedLocations) {
      final matchesSearch = _search.isEmpty ||
          saved.name.toLowerCase().contains(_search.toLowerCase()) ||
          saved.nameUr.toLowerCase().contains(_search.toLowerCase()) ||
          saved.province.toLowerCase().contains(_search.toLowerCase()) ||
          saved.country.toLowerCase().contains(_search.toLowerCase());
      if (matchesSearch &&
          !combinedCities.any((c) =>
              c.name.toLowerCase() == saved.name.toLowerCase() &&
              c.country.toLowerCase() == saved.country.toLowerCase())) {
        combinedCities.add(saved);
      }
    }

    // Priority 3: Online Geocoded matches
    for (var online in _onlineResults) {
      if (!combinedCities.any((c) =>
          (c.name.toLowerCase() == online.name.toLowerCase() &&
              c.country.toLowerCase() == online.country.toLowerCase()) ||
          ((c.latitude - online.latitude).abs() < 0.04 &&
              (c.longitude - online.longitude).abs() < 0.04))) {
        combinedCities.add(online);
      }
    }

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            AppLocale.t(ur: 'شہروں کی فہرست و تلاشِ مقامات', en: 'City Gazetteer & Search'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          actions: [
            IconButton(
              icon: _isAutoDetecting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppTheme.emerald, strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, color: AppTheme.emerald),
              tooltip: AppLocale.t(ur: 'لائیو لوکیشن آٹو ڈیٹیکٹ کریں', en: 'Auto-Detect Live Location'),
              onPressed: _isAutoDetecting ? null : _autoDetectLocation,
            ),
          ],
        ),
        body: Column(
          children: [
            // Live GPS Auto-Detect Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isAutoDetecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isAutoDetecting
                      ? AppLocale.t(ur: 'لوکیشن تلاش کی جا رہی ہے...', en: 'Detecting Location...')
                      : AppLocale.t(ur: '📍 لائیو لوکیشن آٹو ڈیٹیکٹ کریں (GPS Auto Detect)', en: '📍 GPS Auto-Detect Location'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isAutoDetecting ? null : _autoDetectLocation,
              ),
            ),

            // Search Field (Unified Local + Global Map Search)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                style: TextStyle(color: AppTheme.textPrimary),
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  _debounceTimer?.cancel();
                  if (val.trim().length >= 2) {
                    _searchGlobalOnline(val.trim());
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceElevated,
                  hintText: AppLocale.t(
                    ur: 'کسی بھی شہر یا مقام کا نام تلاش کریں...',
                    en: 'Search any city or location worldwide...',
                  ),
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.search, color: AppTheme.emerald),
                  suffixIcon: _isSearchingOnline
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                          ),
                        )
                      : (_search.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppTheme.textMuted),
                              onPressed: () => _onSearchChanged(''),
                            )
                          : null),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Custom Coordinates Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: OutlinedButton.icon(
                icon: Icon(Icons.add_location_alt, color: AppTheme.gold, size: 18),
                label: Text(
                  AppLocale.t(ur: 'دستی کوآرڈینیٹس درج کریں (Custom Coordinates)', en: 'Enter Custom Coordinates'),
                  style: TextStyle(color: AppTheme.gold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold),
                  minimumSize: const Size(double.infinity, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showCustomDialog,
              ),
            ),

            const SizedBox(height: 4),

            // City List with Full Action Suite
            Expanded(
              child: ListView.separated(
                itemCount: combinedCities.length,
                separatorBuilder: (c, i) => Divider(color: AppTheme.border, height: 1),
                itemBuilder: (context, index) {
                  final city = combinedCities[index];
                  final bool isDefault = (_settings.defaultCity.id == city.id || _settings.defaultCity.name == city.name);
                  final bool isOnline = city.isGoogleMaps || city.id.startsWith('om_') || city.id.startsWith('bg_') || city.id.startsWith('ph_');

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDefault ? AppTheme.emerald : AppTheme.border,
                        width: isDefault ? 1.5 : 1.0,
                      ),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: isDefault ? AppTheme.emerald : AppTheme.surface,
                        child: Text(isDefault ? '⭐' : '📍'),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              city.localizedName,
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (city.nameUr.isNotEmpty && !AppLocale.isUrdu)
                            Text(
                              ' (${city.nameUr})',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            )
                          else if (city.nameUr.isNotEmpty && AppLocale.isUrdu && city.name != city.nameUr)
                            Text(
                              ' (${city.name})',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          if (isOnline)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.public, size: 11, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 3),
                                  Text(
                                    AppLocale.t(ur: 'آن لائن مقام', en: 'Online Location'),
                                    style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          if (isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppLocale.t(ur: 'فعال', en: 'Active'),
                                style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${city.localizedProvince}, ${city.localizedCountry} (${city.latitude.toStringAsFixed(2)}°, ${city.longitude.toStringAsFixed(2)}°)',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              // 1. Select City
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: Text(AppLocale.t(ur: 'منتخب کریں', en: 'Select City')),
                                onPressed: () {
                                  _settings.setDefaultCity(city);
                                  Navigator.pop(context, city);
                                },
                              ),

                              // 2. View Monthly Timetable
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.calendar_month, size: 16),
                                label: Text(AppLocale.t(ur: 'ٹائم ٹیبل دیکھیں', en: 'Timetable')),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (c) => MonthlyScreen(city: city)),
                                  );
                                },
                              ),

                              // 3. Save to Locations
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFF59E0B),
                                  side: const BorderSide(color: Color(0xFFF59E0B)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.bookmark_add, size: 16),
                                label: Text(AppLocale.t(ur: 'محفوظ کریں', en: 'Save')),
                                onPressed: () {
                                  _settings.addSavedLocation(city);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocale.t(
                                          ur: '${city.name} محفوظ مقامات میں شامل کر لیا گیا!',
                                          en: '${city.name} saved to locations!',
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                },
                              ),

                              // 4. Set as Default City
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                  side: const BorderSide(color: Colors.amberAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.star, size: 16),
                                label: Text(AppLocale.t(ur: 'ڈیفالٹ بنائیں', en: 'Set Default')),
                                onPressed: () {
                                  setState(() {
                                    _settings.setDefaultCity(city);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocale.t(
                                          ur: '${city.name} کو ڈیفالٹ شہر مقرر کر دیا گیا!',
                                          en: '${city.name} set as default city!',
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                },
                              ),

                              // 5. Open in Maps
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.sky,
                                  side: BorderSide(color: AppTheme.sky),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(AppLocale.t(ur: 'میپ پر دیکھیں', en: 'View on Maps')),
                                onPressed: () => _openInGoogleMaps(city.latitude, city.longitude, city.name),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'cities',
          city: combinedCities.isNotEmpty ? combinedCities.first : _settings.defaultCity,
        ),
      ),
    );
  }

  void _showCustomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            AppLocale.t(ur: 'نیا مقام درج کریں', en: 'Add Custom Coordinates'),
            style: TextStyle(color: AppTheme.gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'مقام کا نام', en: 'Location Name'),
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextField(
                controller: _customLatCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'عرض بلد (Latitude)', en: 'Latitude'),
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextField(
                controller: _customLngCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'طول بلد (Longitude)', en: 'Longitude'),
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextField(
                controller: _customTzCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'ٹائم زون (GMT / UTC)', en: 'Timezone (GMT)'),
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                AppLocale.t(ur: 'منسوخ', en: 'Cancel'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                AppLocale.t(ur: 'محفوظ و منتخب کریں', en: 'Save & Select'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final newCity = CityModel(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: _customNameCtrl.text.trim().isNotEmpty ? _customNameCtrl.text.trim() : 'Custom Location',
                  country: 'Custom',
                  province: 'Custom',
                  latitude: double.tryParse(_customLatCtrl.text) ?? 31.8878,
                  longitude: double.tryParse(_customLngCtrl.text) ?? 72.4125,
                  timezone: double.tryParse(_customTzCtrl.text) ?? 5.0,
                );
                _settings.setDefaultCity(newCity);
                Navigator.pop(ctx);
                Navigator.pop(context, newCity);
              },
            ),
          ],
        ),
      ),
    );
  }
}
