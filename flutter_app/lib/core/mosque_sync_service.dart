import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_settings.dart';

/// Ruet-e-Hilal Certified Moon Sighting Declaration Model
class RuetHilalDeclaration {
  final bool active;
  final String committee;
  final int hijriYear;
  final int hijriMonth;
  final String hijriMonthNameUr;
  final int hijriDay;
  final int hijriAdjustment;
  final String titleUr;
  final String textUr;

  RuetHilalDeclaration({
    required this.active,
    required this.committee,
    required this.hijriYear,
    required this.hijriMonth,
    required this.hijriMonthNameUr,
    required this.hijriDay,
    required this.hijriAdjustment,
    required this.titleUr,
    required this.textUr,
  });

  factory RuetHilalDeclaration.fromJson(Map<String, dynamic> json) {
    return RuetHilalDeclaration(
      active: json['announcement_active'] == true || json['announcement_active'] == 1,
      committee: json['committee'] as String? ?? 'مرکزی رویتِ ہلال کمیٹی',
      hijriYear: (json['hijri_year'] as num?)?.toInt() ?? 1448,
      hijriMonth: (json['hijri_month'] as num?)?.toInt() ?? 4,
      hijriMonthNameUr: json['hijri_month_name_ur'] as String? ?? 'ربیع الثانی',
      hijriDay: (json['hijri_day'] as num?)?.toInt() ?? 1,
      hijriAdjustment: (json['hijri_adjustment'] as num?)?.toInt() ?? 0,
      titleUr: json['announcement_title_ur'] as String? ?? 'رویتِ ہلال اعلان',
      textUr: json['announcement_text_ur'] as String? ?? '',
    );
  }
}

/// Mosque Mohalla Connect & Central Ruet-e-Hilal Synchronization Service
class MosqueSyncService {
  static final MosqueSyncService _instance = MosqueSyncService._internal();
  factory MosqueSyncService() => _instance;
  MosqueSyncService._internal();

  /// Primary Production API Host with fallback mirrors
  static const String baseApiUrl = 'https://meeqat.mamfss.com/api';
  static const String secondaryApiUrl = 'https://meeqat.mindcraftsai.com/api';
  static const String localApiUrl = 'http://10.0.2.2/minaret_modern/backend/api';

  RuetHilalDeclaration? _latestDeclaration;
  RuetHilalDeclaration? get latestDeclaration => _latestDeclaration;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Helper to make HTTP GET requests safely with timeout and failover
  Future<Map<String, dynamic>?> _httpGet(String endpoint) async {
    final urls = [
      '$baseApiUrl/$endpoint',
      '$secondaryApiUrl/$endpoint',
      '$localApiUrl/$endpoint',
    ];

    for (final url in urls) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('Accept', 'application/json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
      } catch (e) {
        // Silently try next or return null
        debugPrint('MosqueSyncService GET error ($url): $e');
      } finally {
        client?.close();
      }
    }
    return null;
  }

  /// Helper to make HTTP POST requests safely with timeout and failover
  Future<Map<String, dynamic>?> _httpPost(String endpoint, Map<String, dynamic> bodyMap) async {
    final urls = [
      '$baseApiUrl/$endpoint',
      '$secondaryApiUrl/$endpoint',
      '$localApiUrl/$endpoint',
    ];

    final bodyBytes = utf8.encode(jsonEncode(bodyMap));

    for (final url in urls) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final request = await client.postUrl(Uri.parse(url));
        request.headers.set('Content-Type', 'application/json; charset=UTF-8');
        request.headers.set('Accept', 'application/json');
        request.add(bodyBytes);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      } catch (e) {
        debugPrint('MosqueSyncService POST error ($url): $e');
      } finally {
        client?.close();
      }
    }
    return null;
  }

  /// 1. Synchronize Central Ruet-e-Hilal Certified Moon Sighting Declaration
  Future<RuetHilalDeclaration?> syncRuetHilal() async {
    try {
      final json = await _httpGet('ruet-hilal.php');
      if (json != null && json['status'] == 'success') {
        final decl = RuetHilalDeclaration.fromJson(json);
        _latestDeclaration = decl;

        // Auto-synchronize Hijri Adjustment if committee declared an offset
        final settings = AppSettings();
        if (settings.hijriAdjustment != decl.hijriAdjustment) {
          settings.hijriAdjustment = decl.hijriAdjustment;
          debugPrint('MosqueSyncService: Auto-synced Hijri Adjustment to ${decl.hijriAdjustment}');
        }
        return decl;
      }
    } catch (e) {
      debugPrint('MosqueSyncService.syncRuetHilal error: $e');
    }
    return null;
  }

  /// 2. Search Registered Neighborhood Mosques by query or city
  Future<List<Map<String, dynamic>>> searchMosques({String query = '', String city = '', String code = ''}) async {
    try {
      final queryParams = <String>[];
      if (query.isNotEmpty) queryParams.add('q=${Uri.encodeComponent(query)}');
      if (city.isNotEmpty) queryParams.add('city=${Uri.encodeComponent(city)}');
      if (code.isNotEmpty) queryParams.add('code=${Uri.encodeComponent(code)}');
      final endpoint = 'mosques.php${queryParams.isNotEmpty ? '?${queryParams.join('&')}' : ''}';

      final json = await _httpGet(endpoint);
      if (json != null && json['mosques'] is List) {
        return List<Map<String, dynamic>>.from(json['mosques']);
      }
    } catch (e) {
      debugPrint('MosqueSyncService.searchMosques error: $e');
    }
    return [];
  }

  /// 3. Link Mosque by 5-character Code (e.g. "M7861")
  Future<bool> linkMosqueByCode(String code) async {
    final list = await searchMosques(code: code.trim());
    if (list.isNotEmpty) {
      final m = list.first;
      final settings = AppSettings();
      final active = settings.activeMosque;

      active.id = m['id']?.toString() ?? '';
      active.code = m['code']?.toString() ?? '';
      active.name = m['name_ur']?.toString() ?? active.name;
      active.nameEn = m['name_en']?.toString() ?? active.nameEn;
      active.address = m['area']?.toString() ?? active.address;
      settings.updateActiveMosque(active);

      // Immediately fetch latest congregation times for this mosque
      await syncActiveMosqueTimes();
      return true;
    }
    return false;
  }

  /// 4. Synchronize Active Mosque Jamaat Times with Imam's Web Panel
  Future<bool> syncActiveMosqueTimes() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final settings = AppSettings();
      final active = settings.activeMosque;
      final identifier = active.id.isNotEmpty ? active.id : active.code;

      final endpoint = identifier.isNotEmpty
          ? 'jamaat-sync.php?mosque_id=${Uri.encodeComponent(identifier)}'
          : 'jamaat-sync.php';

      final json = await _httpGet(endpoint);
      if (json != null && json['status'] == 'success' && json['data'] is Map<String, dynamic>) {
        final data = json['data'] as Map<String, dynamic>;

        // Format 24h string "13:15" to 12h display format "01:15 PM"
        String to12H(String? t24, String fallback) {
          if (t24 == null || !t24.contains(':')) return fallback;
          final parts = t24.split(':');
          int h = int.tryParse(parts[0]) ?? 0;
          int m = int.tryParse(parts[1]) ?? 0;
          final period = h >= 12 ? 'PM' : 'AM';
          final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
        }

        active.fajrJamaat = to12H(data['fajr'], active.fajrJamaat);
        active.dhuhrJamaat = to12H(data['dhuhr'], active.dhuhrJamaat);
        active.asrJamaat = to12H(data['asr'], active.asrJamaat);
        active.maghribJamaat = to12H(data['maghrib'], active.maghribJamaat);
        active.ishaJamaat = to12H(data['isha'], active.ishaJamaat);
        active.jumuahTime = to12H(data['jumuah'], active.jumuahTime);
        active.notice = data['notice_ur']?.toString() ?? '';
        active.lastSynced = DateTime.now().toIso8601String();

        settings.updateActiveMosque(active);
        return true;
      }
    } catch (e) {
      debugPrint('MosqueSyncService.syncActiveMosqueTimes error: $e');
    } finally {
      _isSyncing = false;
    }
    return false;
  }

  /// 5. Update Mosque Congregation Times directly from App with Imam Passcode
  Future<Map<String, dynamic>> updateMosqueJamaatTimes({
    required String mosqueId,
    required String pin,
    required Map<String, String> times,
    String notice = '',
  }) async {
    try {
      final body = {
        'mosque_id': mosqueId,
        'pin': pin,
        'fajr': times['fajr'] ?? '05:15',
        'dhuhr': times['dhuhr'] ?? '13:15',
        'asr': times['asr'] ?? '16:30',
        'maghrib': times['maghrib'] ?? '17:45',
        'isha': times['isha'] ?? '19:30',
        'jumuah': times['jumuah'] ?? '13:30',
        'notice_ur': notice,
      };

      final json = await _httpPost('jamaat-sync.php', body);
      if (json != null && json['status'] == 'success') {
        // Automatically sync fresh times locally
        await syncActiveMosqueTimes();
        return {
          'success': true,
          'message': json['message'] ?? 'اوقات کامیابی سے اپ ڈیٹ ہو گئے۔',
          'data': json['data'],
        };
      }
      return {
        'success': false,
        'message': json?['message'] ?? 'خفیہ پاس کوڈ غلط ہے یا سرور سے رابطہ منقطع ہے۔',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'رابطے کی خرابی: $e',
      };
    }
  }

  /// 6. Register a New Mosque with Permanent Code Guarantee from App
  Future<Map<String, dynamic>> registerMosque({
    required String nameUr,
    required String cityUr,
    required String area,
    required String imamName,
    required String pin,
    String? phone,
    Map<String, String>? initialTimes,
  }) async {
    try {
      final body = {
        'name_ur': nameUr,
        'city_ur': cityUr,
        'area': area,
        'imam_name': imamName,
        'pin': pin,
        'phone': phone ?? '',
        'fajr': initialTimes?['fajr'] ?? '05:15',
        'dhuhr': initialTimes?['dhuhr'] ?? '13:15',
        'asr': initialTimes?['asr'] ?? '16:30',
        'maghrib': initialTimes?['maghrib'] ?? '17:45',
        'isha': initialTimes?['isha'] ?? '19:30',
        'jumuah': initialTimes?['jumuah'] ?? '13:30',
      };

      final json = await _httpPost('mosques.php', body);
      if (json != null && json['status'] == 'success') {
        final code = json['code']?.toString() ?? '';
        final mosqueData = json['mosque'] as Map<String, dynamic>?;

        // Automatically link this new mosque as active
        if (code.isNotEmpty) {
          await linkMosqueByCode(code);
        }

        return {
          'success': true,
          'code': code,
          'message': json['message_ur'] ?? 'مسجد کامیابی کے ساتھ رجسٹر ہو چکی ہے۔',
          'permanent_notice': json['permanent_code_notice'] ?? 'یہ کوڈ مستقل ہے اور کبھی تبدیل نہیں ہو گا۔',
          'mosque': mosqueData,
        };
      }
      return {
        'success': false,
        'message': json?['message'] ?? 'مسجد رجسٹریشن نامکمل رہی۔ دوبارہ کوشش فرمائیں۔',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'رابطے کی خرابی: $e',
      };
    }
  }
}
