import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_locale.dart';
import 'app_theme.dart';
import 'city_database.dart';

class MosqueModel {
  String id;
  String code;
  String name;
  String nameEn;
  String address;
  String addressEn;
  String fajrJamaat;
  String dhuhrJamaat;
  String asrJamaat;
  String maghribJamaat;
  String ishaJamaat;
  String jumuahTime;
  String notice;
  String lastSynced;

  MosqueModel({
    this.id = '',
    this.code = '',
    required this.name,
    this.nameEn = '',
    this.address = '',
    this.addressEn = '',
    this.fajrJamaat = '05:40 AM',
    this.dhuhrJamaat = '01:30 PM',
    this.asrJamaat = '04:30 PM',
    this.maghribJamaat = '05:44 PM',
    this.ishaJamaat = '07:30 PM',
    this.jumuahTime = '01:30 PM',
    this.notice = '',
    this.lastSynced = '',
  });

  String nameLocalized(bool isUrdu) {
    if (isUrdu) return name;
    return nameEn.isNotEmpty ? nameEn : name;
  }

  String addressLocalized(bool isUrdu) {
    if (isUrdu) return address;
    return addressEn.isNotEmpty ? addressEn : address;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'nameEn': nameEn,
    'address': address,
    'addressEn': addressEn,
    'fajrJamaat': fajrJamaat,
    'dhuhrJamaat': dhuhrJamaat,
    'asrJamaat': asrJamaat,
    'maghribJamaat': maghribJamaat,
    'ishaJamaat': ishaJamaat,
    'jumuahTime': jumuahTime,
    'notice': notice,
    'lastSynced': lastSynced,
  };

  factory MosqueModel.fromJson(Map<String, dynamic> json) => MosqueModel(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    address: json['address'] as String? ?? '',
    addressEn: json['addressEn'] as String? ?? '',
    fajrJamaat: json['fajrJamaat'] as String? ?? '05:40 AM',
    dhuhrJamaat: json['dhuhrJamaat'] as String? ?? '01:30 PM',
    asrJamaat: json['asrJamaat'] as String? ?? '04:30 PM',
    maghribJamaat: json['maghribJamaat'] as String? ?? '05:44 PM',
    ishaJamaat: json['ishaJamaat'] as String? ?? '07:30 PM',
    jumuahTime: json['jumuahTime'] as String? ?? '01:30 PM',
    notice: json['notice'] as String? ?? '',
    lastSynced: json['lastSynced'] as String? ?? '',
  );
}

/// Central application settings & storage manager
class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal() {
    _initDefaults();
  }

  static String? testFilePath;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 1. Time Format: 12-hour (Default) vs 24-hour
  bool _is12HourFormat = true;
  bool get is12HourFormat => _is12HourFormat;
  set is12HourFormat(bool val) {
    if (_is12HourFormat != val) {
      _is12HourFormat = val;
      _notifyAndSave();
    }
  }

  // 2. Asr Juristic Method: Hanafi (2) vs Shafi'i (1)
  int _asrMethod = 2;
  int get asrMethod => _asrMethod;
  set asrMethod(int val) {
    if (_asrMethod != val) {
      _asrMethod = val;
      _notifyAndSave();
    }
  }

  // 3. Determination of Fajr (Strictly 18.0° Jamhoor Consensus)
  final String _fajrMode = 'DEGREE';
  final double _fajrDegree = 18.0;
  final double _fajrIntervalMin = 90.0;

  String get fajrMode => _fajrMode;
  double get fajrDegree => _fajrDegree;
  double get fajrIntervalMin => _fajrIntervalMin;

  // 4. Determination of Isha (Strictly 18.0° Jamhoor Consensus)
  final String _ishaMode = 'DEGREE';
  final double _ishaDegree = 18.0;
  final double _ishaIntervalMin = 90.0;

  String get ishaMode => _ishaMode;
  double get ishaDegree => _ishaDegree;
  double get ishaIntervalMin => _ishaIntervalMin;

  // 5. Hijri Calendar Adjustment (-2 to +2 days)
  int _hijriAdjustment = 0;
  int get hijriAdjustment => _hijriAdjustment;
  set hijriAdjustment(int val) {
    if (_hijriAdjustment != val) {
      _hijriAdjustment = val;
      _notifyAndSave();
    }
  }

  // 6. Font Scale (0.9, 1.0, 1.15)
  double _fontScale = 1.0;
  double get fontScale => _fontScale;
  set fontScale(double val) {
    if (_fontScale != val) {
      _fontScale = val;
      _notifyAndSave();
    }
  }

  // 7. Auto Update GPS Location
  bool _autoUpdateLocation = true;
  bool get autoUpdateLocation => _autoUpdateLocation;
  set autoUpdateLocation(bool val) {
    if (_autoUpdateLocation != val) {
      _autoUpdateLocation = val;
      _notifyAndSave();
    }
  }

  // 8. Google Maps API Key
  String _googleMapsApiKey = '';
  String get googleMapsApiKey => _googleMapsApiKey;
  set googleMapsApiKey(String key) {
    final trimmed = key.trim();
    if (_googleMapsApiKey != trimmed) {
      _googleMapsApiKey = trimmed;
      _notifyAndSave();
    }
  }
  void setGoogleMapsApiKey(String key) {
    googleMapsApiKey = key;
  }
  bool get hasGoogleMapsApiKey => _googleMapsApiKey.isNotEmpty;

  // 9. Saved Locations (1 to 100 entries)
  final List<CityModel> _savedLocations = [];
  List<CityModel> get savedLocations => List.unmodifiable(_savedLocations);

  bool addSavedLocation(CityModel city) {
    if (_savedLocations.length >= 100) return false;
    if (_savedLocations.any((c) => c.name.toLowerCase() == city.name.toLowerCase())) {
      return false; // Already exists
    }
    _savedLocations.add(city);
    _notifyAndSave();
    return true;
  }

  void removeSavedLocation(String cityId) {
    _savedLocations.removeWhere((c) => c.id == cityId);
    _notifyAndSave();
  }

  // Default City (Defaults to Farooka)
  CityModel _defaultCity = CityDatabase.defaultCities.first;
  CityModel get defaultCity => _defaultCity;
  void setDefaultCity(CityModel city) {
    _defaultCity = city;
    addSavedLocation(city);
    _notifyAndSave();
  }

  // 10. Mosque Management (Multiple Mosques with Jama'at & Jumu'ah times)
  final List<MosqueModel> _savedMosques = [];
  List<MosqueModel> get savedMosques => List.unmodifiable(_savedMosques);
  int _activeMosqueIndex = 0;
  int get activeMosqueIndex => _activeMosqueIndex;

  MosqueModel get activeMosque {
    if (_savedMosques.isEmpty) {
      _savedMosques.add(MosqueModel(name: 'جامع مسجد مرکزی', address: 'شہر مرکزی'));
    }
    if (_activeMosqueIndex >= _savedMosques.length) {
      _activeMosqueIndex = 0;
    }
    return _savedMosques[_activeMosqueIndex];
  }

  void setActiveMosque(int index) {
    if (index >= 0 && index < _savedMosques.length) {
      _activeMosqueIndex = index;
      _notifyAndSave();
    }
  }

  void addMosque(MosqueModel mosque) {
    _savedMosques.add(mosque);
    _notifyAndSave();
  }

  void updateActiveMosque(MosqueModel updated) {
    if (_savedMosques.isNotEmpty && _activeMosqueIndex < _savedMosques.length) {
      _savedMosques[_activeMosqueIndex] = updated;
      _notifyAndSave();
    }
  }

  // Mosque Display Mode: 'BEGINNING', 'JAMAAT'
  String _mosqueDisplayMode = 'BEGINNING';
  String get mosqueDisplayMode => _mosqueDisplayMode;
  set mosqueDisplayMode(String mode) {
    if (_mosqueDisplayMode != mode) {
      _mosqueDisplayMode = mode;
      _notifyAndSave();
    }
  }

  // Selected Adhan Tone ('makkah', 'madinah', 'aqsa', 'cairo', 'istanbul')
  String _selectedAdhanTone = 'makkah';
  String get selectedAdhanTone => _selectedAdhanTone;
  set selectedAdhanTone(String tone) {
    if (_selectedAdhanTone != tone) {
      _selectedAdhanTone = tone;
      _notifyAndSave();
    }
  }

  // Auto Dynamic Jama'at Formula (Configurable by user)
  bool _useAutoDynamicJamaat = true;
  bool get useAutoDynamicJamaat => _useAutoDynamicJamaat;
  set useAutoDynamicJamaat(bool val) {
    if (_useAutoDynamicJamaat != val) {
      _useAutoDynamicJamaat = val;
      _notifyAndSave();
    }
  }

  // Dynamic Jama'at Formula Custom Parameters
  int _fajrDynamicMinBeforeSunrise = 30;
  int get fajrDynamicMinBeforeSunrise => _fajrDynamicMinBeforeSunrise;
  set fajrDynamicMinBeforeSunrise(int val) {
    if (_fajrDynamicMinBeforeSunrise != val) {
      _fajrDynamicMinBeforeSunrise = val;
      _notifyAndSave();
    }
  }

  int _fajrDynamicMaxBeforeSunrise = 35;
  int get fajrDynamicMaxBeforeSunrise => _fajrDynamicMaxBeforeSunrise;
  set fajrDynamicMaxBeforeSunrise(int val) {
    if (_fajrDynamicMaxBeforeSunrise != val) {
      _fajrDynamicMaxBeforeSunrise = val;
      _notifyAndSave();
    }
  }

  int _fajrDynamicStepMinutes = 5;
  int get fajrDynamicStepMinutes => _fajrDynamicStepMinutes;
  set fajrDynamicStepMinutes(int val) {
    if (_fajrDynamicStepMinutes != val) {
      _fajrDynamicStepMinutes = val;
      _notifyAndSave();
    }
  }

  int _asrDynamicMinAfter = 15;
  int get asrDynamicMinAfter => _asrDynamicMinAfter;
  set asrDynamicMinAfter(int val) {
    if (_asrDynamicMinAfter != val) {
      _asrDynamicMinAfter = val;
      _notifyAndSave();
    }
  }

  int _asrDynamicMaxAfter = 30;
  int get asrDynamicMaxAfter => _asrDynamicMaxAfter;
  set asrDynamicMaxAfter(int val) {
    if (_asrDynamicMaxAfter != val) {
      _asrDynamicMaxAfter = val;
      _notifyAndSave();
    }
  }

  int _asrDynamicStepMinutes = 15;
  int get asrDynamicStepMinutes => _asrDynamicStepMinutes;
  set asrDynamicStepMinutes(int val) {
    if (_asrDynamicStepMinutes != val) {
      _asrDynamicStepMinutes = val;
      _notifyAndSave();
    }
  }

  int _maghribDynamicAfter = 3;
  int get maghribDynamicAfter => _maghribDynamicAfter;
  set maghribDynamicAfter(int val) {
    if (_maghribDynamicAfter != val) {
      _maghribDynamicAfter = val;
      _notifyAndSave();
    }
  }

  int _ishaDynamicMinAfter = 15;
  int get ishaDynamicMinAfter => _ishaDynamicMinAfter;
  set ishaDynamicMinAfter(int val) {
    if (_ishaDynamicMinAfter != val) {
      _ishaDynamicMinAfter = val;
      _notifyAndSave();
    }
  }

  int _ishaDynamicMaxAfter = 30;
  int get ishaDynamicMaxAfter => _ishaDynamicMaxAfter;
  set ishaDynamicMaxAfter(int val) {
    if (_ishaDynamicMaxAfter != val) {
      _ishaDynamicMaxAfter = val;
      _notifyAndSave();
    }
  }

  int _ishaDynamicStepMinutes = 15;
  int get ishaDynamicStepMinutes => _ishaDynamicStepMinutes;
  set ishaDynamicStepMinutes(int val) {
    if (_ishaDynamicStepMinutes != val) {
      _ishaDynamicStepMinutes = val;
      _notifyAndSave();
    }
  }

  // Alarm Timing Mode: 'START_TIME' (At prayer start) or 'BEFORE_JAMAAT' (Minutes before Jama'at)
  String _alarmTimingMode = 'START_TIME';
  String get alarmTimingMode => _alarmTimingMode;
  set alarmTimingMode(String mode) {
    if (_alarmTimingMode != mode) {
      _alarmTimingMode = mode;
      _notifyAndSave();
    }
  }

  // Minutes before Jama'at when 'BEFORE_JAMAAT' is active (e.g. 5, 10, 15, 20, 30)
  int _alarmBeforeJamaatMinutes = 10;
  int get alarmBeforeJamaatMinutes => _alarmBeforeJamaatMinutes;
  set alarmBeforeJamaatMinutes(int mins) {
    if (_alarmBeforeJamaatMinutes != mins) {
      _alarmBeforeJamaatMinutes = mins;
      _notifyAndSave();
    }
  }

  // Prayer Alarm toggles (fajr, dhuhr, asr, maghrib, isha)
  Map<String, bool> _prayerAlarms = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  Map<String, bool> get prayerAlarms => Map.unmodifiable(_prayerAlarms);
  void setPrayerAlarm(String key, bool enabled) {
    if (_prayerAlarms[key] != enabled) {
      _prayerAlarms[key] = enabled;
      _notifyAndSave();
    }
  }

  // Tahajjud Alarm Settings (20, 30, 40, or 60 minutes before Subh Sadiq / Fajr Start)
  bool _tahajjudAlarmEnabled = false;
  bool get tahajjudAlarmEnabled => _tahajjudAlarmEnabled;
  set tahajjudAlarmEnabled(bool val) {
    if (_tahajjudAlarmEnabled != val) {
      _tahajjudAlarmEnabled = val;
      _notifyAndSave();
    }
  }

  int _tahajjudMinutesBefore = 30; // 20, 30, 40, or 60 minutes
  int get tahajjudMinutesBefore => _tahajjudMinutesBefore;
  set tahajjudMinutesBefore(int val) {
    if (_tahajjudMinutesBefore != val) {
      _tahajjudMinutesBefore = val;
      _notifyAndSave();
    }
  }

  // Snooze / Reminder interval in minutes (5, 10, 15, or 0 = Off)
  int _snoozeIntervalMinutes = 5;
  int get snoozeIntervalMinutes => _snoozeIntervalMinutes;
  set snoozeIntervalMinutes(int val) {
    if (_snoozeIntervalMinutes != val) {
      _snoozeIntervalMinutes = val;
      _notifyAndSave();
    }
  }

  // Repeat Reminder Enabled
  bool _isRepeatReminderEnabled = true;
  bool get isRepeatReminderEnabled => _isRepeatReminderEnabled;
  set isRepeatReminderEnabled(bool val) {
    if (_isRepeatReminderEnabled != val) {
      _isRepeatReminderEnabled = val;
      _notifyAndSave();
    }
  }

  // Home Screen Widget Theme ('midnight_gold', 'emerald', 'pure_black', 'warm_amber')
  String _widgetTheme = 'midnight_gold';
  String get widgetTheme => _widgetTheme;
  set widgetTheme(String val) {
    if (_widgetTheme != val) {
      _widgetTheme = val;
      _notifyAndSave();
    }
  }

  // Home Screen Widget Layout ('toggle' for collapsible, 'always_on' for permanent solar arc)
  String _widgetLayout = 'toggle';
  String get widgetLayout => _widgetLayout;
  set widgetLayout(String val) {
    if (_widgetLayout != val) {
      _widgetLayout = val;
      _notifyAndSave();
    }
  }

  void _notifyAndSave() {
    notifyListeners();
    if (_isInitialized) {
      saveSettings();
    }
  }

  Future<File> _getSettingsFile() async {
    if (testFilePath != null && testFilePath!.isNotEmpty) {
      return File(testFilePath!);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/minaret_settings.json');
    } catch (_) {
      return File('minaret_settings.json');
    }
  }

  Map<String, dynamic> toMap() => {
    'version': 1,
    'is12HourFormat': _is12HourFormat,
    'asrMethod': _asrMethod,
    'hijriAdjustment': _hijriAdjustment,
    'fontScale': _fontScale,
    'autoUpdateLocation': _autoUpdateLocation,
    'googleMapsApiKey': _googleMapsApiKey,
    'activeMosqueIndex': _activeMosqueIndex,
    'savedMosques': _savedMosques.map((m) => m.toJson()).toList(),
    'savedLocations': _savedLocations.map((l) => l.toJson()).toList(),
    'defaultCity': _defaultCity.toJson(),
    'mosqueDisplayMode': _mosqueDisplayMode,
    'selectedAdhanTone': _selectedAdhanTone,
    'useAutoDynamicJamaat': _useAutoDynamicJamaat,
    'fajrDynamicMinBeforeSunrise': _fajrDynamicMinBeforeSunrise,
    'fajrDynamicMaxBeforeSunrise': _fajrDynamicMaxBeforeSunrise,
    'fajrDynamicStepMinutes': _fajrDynamicStepMinutes,
    'asrDynamicMinAfter': _asrDynamicMinAfter,
    'asrDynamicMaxAfter': _asrDynamicMaxAfter,
    'asrDynamicStepMinutes': _asrDynamicStepMinutes,
    'maghribDynamicAfter': _maghribDynamicAfter,
    'ishaDynamicMinAfter': _ishaDynamicMinAfter,
    'ishaDynamicMaxAfter': _ishaDynamicMaxAfter,
    'ishaDynamicStepMinutes': _ishaDynamicStepMinutes,
    'alarmTimingMode': _alarmTimingMode,
    'alarmBeforeJamaatMinutes': _alarmBeforeJamaatMinutes,
    'prayerAlarms': _prayerAlarms,
    'tahajjudAlarmEnabled': _tahajjudAlarmEnabled,
    'tahajjudMinutesBefore': _tahajjudMinutesBefore,
    'widgetTheme': _widgetTheme,
    'widgetLayout': _widgetLayout,
    'snoozeIntervalMinutes': _snoozeIntervalMinutes,
    'isRepeatReminderEnabled': _isRepeatReminderEnabled,
    'isDark': AppTheme.isDark,
    'isUrdu': AppLocale.isUrdu,
  };

  void loadFromMap(Map<String, dynamic> map) {
    if (map.containsKey('is12HourFormat')) {
      _is12HourFormat = map['is12HourFormat'] as bool? ?? true;
    }
    if (map.containsKey('asrMethod')) {
      _asrMethod = (map['asrMethod'] as num?)?.toInt() ?? 2;
    }
    if (map.containsKey('hijriAdjustment')) {
      _hijriAdjustment = (map['hijriAdjustment'] as num?)?.toInt() ?? 0;
    }
    if (map.containsKey('fontScale')) {
      _fontScale = (map['fontScale'] as num?)?.toDouble() ?? 1.0;
    }
    if (map.containsKey('autoUpdateLocation')) {
      _autoUpdateLocation = map['autoUpdateLocation'] as bool? ?? true;
    }
    if (map.containsKey('googleMapsApiKey')) {
      _googleMapsApiKey = map['googleMapsApiKey'] as String? ?? '';
    }
    if (map.containsKey('mosqueDisplayMode')) {
      _mosqueDisplayMode = map['mosqueDisplayMode'] as String? ?? 'BEGINNING';
    }
    if (map.containsKey('selectedAdhanTone')) {
      _selectedAdhanTone = map['selectedAdhanTone'] as String? ?? 'makkah';
    }
    if (map.containsKey('useAutoDynamicJamaat')) {
      _useAutoDynamicJamaat = map['useAutoDynamicJamaat'] as bool? ?? true;
    }
    if (map.containsKey('fajrDynamicMinBeforeSunrise')) {
      _fajrDynamicMinBeforeSunrise = (map['fajrDynamicMinBeforeSunrise'] as num?)?.toInt() ?? 30;
    }
    if (map.containsKey('fajrDynamicMaxBeforeSunrise')) {
      _fajrDynamicMaxBeforeSunrise = (map['fajrDynamicMaxBeforeSunrise'] as num?)?.toInt() ?? 35;
    }
    if (map.containsKey('fajrDynamicStepMinutes')) {
      _fajrDynamicStepMinutes = (map['fajrDynamicStepMinutes'] as num?)?.toInt() ?? 5;
    }
    if (map.containsKey('asrDynamicMinAfter')) {
      _asrDynamicMinAfter = (map['asrDynamicMinAfter'] as num?)?.toInt() ?? 15;
    }
    if (map.containsKey('asrDynamicMaxAfter')) {
      _asrDynamicMaxAfter = (map['asrDynamicMaxAfter'] as num?)?.toInt() ?? 30;
    }
    if (map.containsKey('asrDynamicStepMinutes')) {
      _asrDynamicStepMinutes = (map['asrDynamicStepMinutes'] as num?)?.toInt() ?? 15;
    }
    if (map.containsKey('maghribDynamicAfter')) {
      _maghribDynamicAfter = (map['maghribDynamicAfter'] as num?)?.toInt() ?? 3;
    }
    if (map.containsKey('ishaDynamicMinAfter')) {
      _ishaDynamicMinAfter = (map['ishaDynamicMinAfter'] as num?)?.toInt() ?? 15;
    }
    if (map.containsKey('ishaDynamicMaxAfter')) {
      _ishaDynamicMaxAfter = (map['ishaDynamicMaxAfter'] as num?)?.toInt() ?? 30;
    }
    if (map.containsKey('ishaDynamicStepMinutes')) {
      _ishaDynamicStepMinutes = (map['ishaDynamicStepMinutes'] as num?)?.toInt() ?? 15;
    }
    if (map.containsKey('alarmTimingMode')) {
      _alarmTimingMode = map['alarmTimingMode'] as String? ?? 'START_TIME';
    }
    if (map.containsKey('alarmBeforeJamaatMinutes')) {
      _alarmBeforeJamaatMinutes = (map['alarmBeforeJamaatMinutes'] as num?)?.toInt() ?? 10;
    }
    if (map.containsKey('prayerAlarms') && map['prayerAlarms'] is Map) {
      final pMap = map['prayerAlarms'] as Map;
      _prayerAlarms = {
        'fajr': pMap['fajr'] as bool? ?? true,
        'dhuhr': pMap['dhuhr'] as bool? ?? true,
        'asr': pMap['asr'] as bool? ?? true,
        'maghrib': pMap['maghrib'] as bool? ?? true,
        'isha': pMap['isha'] as bool? ?? true,
      };
    }
    if (map.containsKey('tahajjudAlarmEnabled')) {
      _tahajjudAlarmEnabled = map['tahajjudAlarmEnabled'] as bool? ?? false;
    }
    if (map.containsKey('tahajjudMinutesBefore')) {
      _tahajjudMinutesBefore = (map['tahajjudMinutesBefore'] as num?)?.toInt() ?? 30;
    }
    if (map.containsKey('widgetTheme')) {
      _widgetTheme = map['widgetTheme'] as String? ?? 'midnight_gold';
    }
    if (map.containsKey('widgetLayout')) {
      _widgetLayout = map['widgetLayout'] as String? ?? 'toggle';
    }
    if (map.containsKey('snoozeIntervalMinutes')) {
      _snoozeIntervalMinutes = (map['snoozeIntervalMinutes'] as num?)?.toInt() ?? 5;
    }
    if (map.containsKey('isRepeatReminderEnabled')) {
      _isRepeatReminderEnabled = map['isRepeatReminderEnabled'] as bool? ?? true;
    }

    if (map.containsKey('savedMosques') && map['savedMosques'] is List) {
      final list = map['savedMosques'] as List;
      if (list.isNotEmpty) {
        _savedMosques.clear();
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            _savedMosques.add(MosqueModel.fromJson(item));
          } else if (item is Map) {
            _savedMosques.add(MosqueModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    if (map.containsKey('activeMosqueIndex')) {
      final idx = (map['activeMosqueIndex'] as num?)?.toInt() ?? 0;
      if (idx >= 0 && idx < _savedMosques.length) {
        _activeMosqueIndex = idx;
      } else {
        _activeMosqueIndex = 0;
      }
    }

    if (map.containsKey('savedLocations') && map['savedLocations'] is List) {
      final list = map['savedLocations'] as List;
      if (list.isNotEmpty) {
        _savedLocations.clear();
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            _savedLocations.add(CityModel.fromJson(item));
          } else if (item is Map) {
            _savedLocations.add(CityModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    if (map.containsKey('defaultCity') && map['defaultCity'] is Map) {
      _defaultCity = CityModel.fromJson(Map<String, dynamic>.from(map['defaultCity'] as Map));
    }

    if (map.containsKey('isDark')) {
      AppTheme.isDark = map['isDark'] as bool? ?? true;
    }
    if (map.containsKey('isUrdu')) {
      AppLocale.setUrdu(map['isUrdu'] as bool? ?? true);
    }
  }

  Future<void>? _ongoingSave;

  Future<void> saveSettings() {
    _ongoingSave = (_ongoingSave ?? Future.value()).then((_) => _executeSave());
    return _ongoingSave!;
  }

  Future<void> _executeSave() async {
    try {
      final file = await _getSettingsFile();
      final data = toMap();
      final jsonStr = jsonEncode(data);
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('AppSettings: Error saving settings: $e');
    }
  }

  Future<void> init({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) return;
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            loadFromMap(decoded);
          } else if (decoded is Map) {
            loadFromMap(Map<String, dynamic>.from(decoded));
          }
        }
      }
    } catch (e) {
      debugPrint('AppSettings.init() error: $e');
    } finally {
      _isInitialized = true;
      AppTheme.isDarkNotifier.removeListener(_onThemeOrLocaleChanged);
      AppTheme.isDarkNotifier.addListener(_onThemeOrLocaleChanged);
      AppLocale.isUrduNotifier.removeListener(_onThemeOrLocaleChanged);
      AppLocale.isUrduNotifier.addListener(_onThemeOrLocaleChanged);
      notifyListeners();
    }
  }

  void _onThemeOrLocaleChanged() {
    _notifyAndSave();
  }

  /// Calculates the exact target hour (0.0 to 24.0) for a prayer alarm to trigger
  double getPrayerAlarmTargetHour({
    required String prayerKey,
    required Map<String, dynamic> detailedTimes,
  }) {
    final raw = detailedTimes['raw'] as Map<String, dynamic>? ?? {};

    if (_alarmTimingMode == 'BEFORE_JAMAAT') {
      final Map<String, String> jamaatTimes = _useAutoDynamicJamaat
          ? calculateDynamicJamaat(detailedTimes: detailedTimes)
          : {
              'fajr': activeMosque.fajrJamaat,
              'dhuhr': activeMosque.dhuhrJamaat,
              'asr': activeMosque.asrJamaat,
              'maghrib': activeMosque.maghribJamaat,
              'isha': activeMosque.ishaJamaat,
            };
      final String? jStr = jamaatTimes[prayerKey];
      if (jStr != null && jStr.isNotEmpty) {
        final clean = jStr.replaceAll(RegExp(r'[\u202A\u202C\u200E]'), '').trim();
        final parts = clean.split(' ');
        final hm = parts[0].split(':');
        int hour = int.tryParse(hm[0]) ?? 0;
        final int minute = int.tryParse(hm[1]) ?? 0;
        if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
          hour += 12;
        } else if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) {
          hour = 0;
        }
        int totalMinutes = hour * 60 + minute - _alarmBeforeJamaatMinutes;
        if (totalMinutes < 0) totalMinutes += 1440;
        return totalMinutes / 60.0;
      }
    }

    // Default: Prayer Start Time
    switch (prayerKey) {
      case 'tahajjud':
        final double fajrStart = (raw['fajr_start'] as double?) ?? (raw['fajr'] as double?) ?? 5.0;
        double tH = fajrStart - (_tahajjudMinutesBefore / 60.0);
        if (tH < 0.0) tH += 24.0;
        return tH;
      case 'fajr':
        return (raw['fajr_adhan'] as double?) ?? (raw['fajr_start'] as double?) ?? 5.0;
      case 'dhuhr':
        return (raw['dhuhr_adhan'] as double?) ?? (raw['dhuhr_start'] as double?) ?? 12.5;
      case 'asr':
        return (raw['asr_hanafi_adhan'] as double?) ?? (raw['asr_hanafi'] as double?) ?? 16.0;
      case 'maghrib':
        return (raw['iftar_adhan'] as double?) ?? (raw['sunset'] as double?) ?? 18.0;
      case 'isha':
        return (raw['isha_adhan'] as double?) ?? (raw['isha_start'] as double?) ?? 19.5;
      default:
        return 0.0;
    }
  }

  /// Calculates authentic dynamic Jama'at times based on local astronomical prayer times.
  /// Specifically tailored for: جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)
  Map<String, String> calculateDynamicJamaat({
    required Map<String, dynamic> detailedTimes,
    bool isRamadan = false,
  }) {
    final raw = detailedTimes['raw'] as Map<String, dynamic>? ?? {};
    final bool is12h = _is12HourFormat;

    String formatMins(int totalMins) {
      int h = (totalMins ~/ 60) % 24;
      int m = totalMins % 60;
      if (is12h) {
        String period = h >= 12 ? 'PM' : 'AM';
        int h12 = (h % 12 == 0) ? 12 : h % 12;
        return '\u200E${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period\u200E';
      } else {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }

    int parseTimeToMins(String timeStr, int fallbackMins) {
      try {
        final clean = timeStr.replaceAll(RegExp(r'[\u202A\u202C\u200E\u200F]'), '').trim();
        final parts = clean.split(' ');
        final hm = parts[0].split(':');
        int h = int.parse(hm[0]);
        int m = int.parse(hm[1]);
        if (parts.length > 1) {
          final period = parts[1].toUpperCase();
          if (period == 'PM' && h < 12) h += 12;
          if (period == 'AM' && h == 12) h = 0;
        }
        return h * 60 + m;
      } catch (_) {
        return fallbackMins;
      }
    }

    // 1. Fajr Jama'at:
    // Non-Ramadan: Configurable min & max minutes before sunrise in step intervals
    // Ramadan: Exactly 20 mins after Sehri End
    int fajrJamaatMins;
    double sunriseH = (raw['sunrise'] as double?) ?? 6.2;
    int sunriseMins = (sunriseH * 60.0).round();

    if (isRamadan) {
      double fajrStartH = (raw['fajr_start'] as double?) ?? 4.8;
      int seharEndMins = (fajrStartH * 60.0).round() - 1; // 1 min before Fajr
      fajrJamaatMins = seharEndMins + 20;
    } else {
      int step = _fajrDynamicStepMinutes > 0 ? _fajrDynamicStepMinutes : 5;
      fajrJamaatMins = ((sunriseMins - _fajrDynamicMinBeforeSunrise) ~/ step) * step;
      if (_fajrDynamicMaxBeforeSunrise > _fajrDynamicMinBeforeSunrise) {
        int earliest = sunriseMins - _fajrDynamicMaxBeforeSunrise;
        if (fajrJamaatMins < earliest) {
          fajrJamaatMins = earliest;
        }
      }
    }

    // 2. Zuhr Jama'at: Fixed time set by user / active mosque (default 1:30 PM)
    int dhuhrJamaatMins = parseTimeToMins(activeMosque.dhuhrJamaat, 13 * 60 + 30);

    // 3. Asr Jama'at:
    // Configurable min/max minutes after Asr Adhan in step-quantized clock slots
    double asrHanafiH = (raw['asr_hanafi'] as double?) ?? 16.0;
    int asrAdhanMins = (asrHanafiH * 60.0).round() + 1; // Hanafi Adhan (+1 min)
    int asrStep = _asrDynamicStepMinutes > 0 ? _asrDynamicStepMinutes : 1;
    int asrTarget = asrAdhanMins + _asrDynamicMinAfter;
    int asrJamaatMins = ((asrTarget + (asrStep - 1)) ~/ asrStep) * asrStep;
    if (_asrDynamicMaxAfter > _asrDynamicMinAfter && (asrJamaatMins - asrAdhanMins) > _asrDynamicMaxAfter) {
      asrJamaatMins = asrAdhanMins + _asrDynamicMaxAfter;
    }

    // 4. Maghrib Jama'at: Configurable minutes after Maghrib Adhan (e.g. 3, 4, 5 mins)
    double sunsetH = (raw['sunset'] as double?) ?? 17.68;
    int maghribAdhanMins = (sunsetH * 60.0).round() + 1; // Adhan (+1 min)
    int maghribJamaatMins = maghribAdhanMins + _maghribDynamicAfter;

    // 5. Isha Jama'at:
    // Configurable min/max minutes after Isha Adhan in step-quantized clock slots
    double ishaStartH = (raw['isha_start'] as double?) ?? 19.0;
    int ishaAdhanMins = (ishaStartH * 60.0).round() + 1; // Isha Adhan (+1 min)
    int ishaStep = _ishaDynamicStepMinutes > 0 ? _ishaDynamicStepMinutes : 1;
    int ishaTarget = ishaAdhanMins + _ishaDynamicMinAfter;
    int ishaJamaatMins = ((ishaTarget + (ishaStep - 1)) ~/ ishaStep) * ishaStep;
    if (_ishaDynamicMaxAfter > _ishaDynamicMinAfter && (ishaJamaatMins - ishaAdhanMins) > _ishaDynamicMaxAfter) {
      ishaJamaatMins = ishaAdhanMins + _ishaDynamicMaxAfter;
    }

    // 6. Friday Jumu'ah Jama'at: Fixed time set by user / active mosque
    int jumuahMins = parseTimeToMins(activeMosque.jumuahTime, 13 * 60 + 30);

    return {
      'fajr': formatMins(fajrJamaatMins),
      'dhuhr': formatMins(dhuhrJamaatMins),
      'asr': formatMins(asrJamaatMins),
      'maghrib': formatMins(maghribJamaatMins),
      'isha': formatMins(ishaJamaatMins),
      'jumuah': formatMins(jumuahMins),
    };
  }

  void _initDefaults() {
    // Populate initial saved cities from database
    for (var c in CityDatabase.defaultCities) {
      if (_savedLocations.length < 10) {
        _savedLocations.add(c);
      }
    }
    // Default initial mosque: جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)
    _savedMosques.add(
      MosqueModel(
        code: 'MQ-78601',
        name: 'جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)',
        nameEn: 'Jamia Masjid Tooba (Arain Wali Masjid) Farooka (Sargodha)',
        address: 'فروکہ، ضلع سرگودھا',
        addressEn: 'Farooka, Distt Sargodha',
        fajrJamaat: '05:40 AM',
        dhuhrJamaat: '01:30 PM',
        asrJamaat: '04:30 PM',
        maghribJamaat: '05:44 PM',
        ishaJamaat: '07:30 PM',
        jumuahTime: '01:30 PM',
      ),
    );
    _savedMosques.add(
      MosqueModel(
        name: 'جامع مسجد فاروقیہ',
        nameEn: 'Jamia Masjid Farooqia',
        address: 'فروکہ، ضلع سرگودھا',
        addressEn: 'Farooka, Distt Sargodha',
        fajrJamaat: '05:40 AM',
        dhuhrJamaat: '01:30 PM',
        asrJamaat: '04:30 PM',
        maghribJamaat: '05:44 PM',
        ishaJamaat: '07:30 PM',
        jumuahTime: '01:30 PM',
      ),
    );
  }
}
