import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/astronomical_engine.dart';
import '../core/hijri_calendar.dart';
import '../core/city_database.dart';
import '../core/alarm_service.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/app_settings.dart';
import '../core/location_service.dart';
import '../core/update_service.dart';
import '../core/salah_tracker_manager.dart';
import '../core/mosque_sync_service.dart';
import 'package:flutter/services.dart';
import 'gazetteer_screen.dart';
import 'qadha_umri_screen.dart';
import '../widgets/minaret_bottom_nav.dart';
import '../widgets/solar_arc_quick_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CityModel currentCity = AppSettings().defaultCity;
  int asrMethod = AstronomicalEngine.asrHanafi;
  String calcMethod = AstronomicalEngine.methodKarachi;

  late Timer _timer;
  DateTime _currentDisplayDate = DateTime.now(); // Date being viewed
  DateTime _now = DateTime.now();                // Actual live clock
  Map<String, dynamic> _detailedTimes = {};
  String _hijriDate = '';
  String _nextPrayerName = '';
  String _nextPrayerTime = '';
  String _countdownStr = '';
  final Set<String> _triggeredAlarmsToday = {};
  int _lastCheckedAlarmDay = -1;
  bool _isDetectingLocation = false;
  bool _showWidgetBanner = true;
  final Set<String> _expandedCards = {'tahajjud'};

  @override
  void initState() {
    super.initState();
    final settings = AppSettings();
    settings.addListener(_onSettingsChanged);
    currentCity = settings.defaultCity;
    _recalculate();
    if (settings.autoUpdateLocation) {
      _autoDetectCurrentLocation(silent: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkOnStartup(context);
        _checkPendingWidgetAction();
        SalahTrackerManager().init().then((_) {
          if (mounted) setState(() {});
        });
        MosqueSyncService().syncRuetHilal().then((_) {
          if (mounted) setState(() {});
        });
        MosqueSyncService().syncActiveMosqueTimes();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          _updateCountdown();
          _checkLiveAdhanAlarms();
        });
      }
    });
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        currentCity = AppSettings().defaultCity;
        _recalculate();
      });
    }
  }

  Future<void> _autoDetectCurrentLocation({bool silent = false}) async {
    if (_isDetectingLocation) return;
    if (!silent && mounted) {
      setState(() => _isDetectingLocation = true);
    }
    try {
      final detected = await LocationService().detectCurrentLocation();
      if (!mounted) return;
      if (detected != null) {
        setState(() {
          currentCity = detected;
          AppSettings().setDefaultCity(detected);
          _recalculate();
          _isDetectingLocation = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocale.t(
                  ur: '📍 اصل لائیو لوکیشن مل گئی (${detected.source}): ${detected.name} (${detected.latitude.toStringAsFixed(3)}°, ${detected.longitude.toStringAsFixed(3)}°)',
                  en: '📍 Live location activated (${detected.source}): ${detected.name} (${detected.latitude.toStringAsFixed(3)}°, ${detected.longitude.toStringAsFixed(3)}°)',
                ),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isDetectingLocation = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocale.t(
                  ur: 'لوکیشن حاصل نہیں ہو سکی۔ براہ کرم GPS یا انٹرنیٹ کنکشن فعال کریں۔',
                  en: 'Could not detect location. Please check GPS and internet.',
                ),
              ),
              backgroundColor: Colors.amber[800],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  @override
  void dispose() {
    AppSettings().removeListener(_onSettingsChanged);
    _timer.cancel();
    super.dispose();
  }

  void _recalculate() {
    final settings = AppSettings();
    final engine = AstronomicalEngine(
      latitude: currentCity.latitude,
      longitude: currentCity.longitude,
      timeZone: currentCity.timezone,
      method: calcMethod,
      asrJuristic: settings.asrMethod,
      elevation: currentCity.elevation,
      fajrMode: settings.fajrMode,
      fajrDegree: settings.fajrDegree,
      fajrIntervalMin: settings.fajrIntervalMin,
      ishaMode: settings.ishaMode,
      ishaDegree: settings.ishaDegree,
      ishaIntervalMin: settings.ishaIntervalMin,
      is12HourFormat: settings.is12HourFormat,
    );

    _detailedTimes = engine.calculateDetailedTimes(_currentDisplayDate);
    final hijri = HijriCalendar.fromGregorian(_currentDisplayDate.add(Duration(days: settings.hijriAdjustment)));
    _hijriDate = AppLocale.isUrdu ? hijri['formatted_urdu'] : hijri['formatted_en'];
    _updateCountdown();
    // Refresh native background Adhan alarms for Android AlarmManager
    AlarmService.scheduleBackgroundPrayerAlarms(detailedTimes: _detailedTimes);
    _syncHomeWidgetData();
  }

  void _updateCountdown() {
    if (_detailedTimes.isEmpty) return;

    final raw = _detailedTimes['raw'] as Map<String, dynamic>?;
    if (raw == null) return;

    final fajr = _detailedTimes['fajr_card'] as Map<String, dynamic>? ?? {};
    final sunrise = _detailedTimes['sunrise_card'] as Map<String, dynamic>? ?? {};
    final dhuhr = _detailedTimes['dhuhr_card'] as Map<String, dynamic>? ?? {};
    final asr = _detailedTimes['asr_card'] as Map<String, dynamic>? ?? {};
    final maghrib = _detailedTimes['maghrib_card'] as Map<String, dynamic>? ?? {};
    final isha = _detailedTimes['isha_card'] as Map<String, dynamic>? ?? {};

    final schedule = [
      {'key': 'fajr', 'name_ur': 'فجر', 'name_en': 'Fajr', 'hours': raw['fajr'] as double, 'time': fajr['start'] ?? ''},
      {'key': 'sunrise', 'name_ur': 'طلوعِ آفتاب', 'name_en': 'Sunrise', 'hours': raw['sunrise'] as double, 'time': sunrise['sunrise'] ?? ''},
      {'key': 'dhuhr', 'name_ur': 'ظہر', 'name_en': 'Dhuhr', 'hours': raw['dhuhr_start'] as double, 'time': dhuhr['start'] ?? ''},
      {'key': 'asr', 'name_ur': 'عصر', 'name_en': 'Asr', 'hours': raw['asr_hanafi'] as double, 'time': asr['hanafi_start'] ?? ''},
      {'key': 'maghrib', 'name_ur': 'مغرب', 'name_en': 'Maghrib', 'hours': raw['sunset'] as double, 'time': maghrib['sunset'] ?? ''},
      {'key': 'isha', 'name_ur': 'عشاء', 'name_en': 'Isha', 'hours': raw['isha_start'] as double, 'time': isha['start'] ?? ''},
    ];

    double currentHours = _now.hour + _now.minute / 60.0 + _now.second / 3600.0;
    Map<String, dynamic>? next;
    double diffHours = 0;

    for (var s in schedule) {
      double pHours = s['hours'] as double;
      if (pHours > currentHours) {
        next = s;
        diffHours = pHours - currentHours;
        break;
      }
    }

    if (next == null) {
      next = schedule[0];
      double pHours = next['hours'] as double;
      diffHours = (24.0 - currentHours) + pHours;
    }

    _nextPrayerName = AppLocale.t(ur: next['name_ur'] as String, en: next['name_en'] as String);
    _nextPrayerTime = next['time'] as String;

    int totalSecs = (diffHours * 3600.0).floor();
    int h = totalSecs ~/ 3600;
    int m = (totalSecs % 3600) ~/ 60;
    int s = totalSecs % 60;

    _countdownStr =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openSolarArcOverlay() {
    if (_detailedTimes.isEmpty) return;
    SolarArcQuickDialog.show(
      context,
      detailedTimes: _detailedTimes,
      nextPrayerName: _nextPrayerName,
      nextPrayerTime: _nextPrayerTime,
      initialCountdown: _countdownStr,
    );
  }

  Future<void> _checkPendingWidgetAction() async {
    try {
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      final action = await channel.invokeMethod<String>('getPendingWidgetAction');
      if (action == 'OPEN_SOLAR_ARC' && mounted) {
        _openSolarArcOverlay();
      }
    } catch (_) {}
  }

  void _syncHomeWidgetData() {
    if (_detailedTimes.isEmpty) return;
    final fajr = _detailedTimes['fajr_card'] as Map<String, dynamic>? ?? {};
    final sunrise = _detailedTimes['sunrise_card'] as Map<String, dynamic>? ?? {};
    final dhuhr = _detailedTimes['dhuhr_card'] as Map<String, dynamic>? ?? {};
    final asr = _detailedTimes['asr_card'] as Map<String, dynamic>? ?? {};
    final maghrib = _detailedTimes['maghrib_card'] as Map<String, dynamic>? ?? {};
    final isha = _detailedTimes['isha_card'] as Map<String, dynamic>? ?? {};
    final zawal = _detailedTimes['zawal_card'] as Map<String, dynamic>? ?? {};

    final settings = AppSettings();
    final isHanafi = settings.asrMethod == 2;
    final asrTime = isHanafi ? (asr['hanafi_start'] ?? '') : (asr['shafi_start'] ?? '');

    String clean(String? t) {
      if (t == null || t.isEmpty) return '--:--';
      String c = t.replaceAll(RegExp(r'\s*(AM|PM|am|pm)', caseSensitive: false), '').trim();
      final p = c.split(':');
      if (p.length >= 2) return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
      return c;
    }

    int parseMinutes(String timeStr) {
      final p = timeStr.trim().split(':');
      if (p.length >= 2) {
        final h = int.tryParse(p[0]) ?? 0;
        final m = int.tryParse(p[1]) ?? 0;
        return h * 60 + m;
      }
      return 0;
    }

    // Build rolling 31-day deterministic schedule map so launcher widget updates autonomous prayer transitions
    // without ever freezing or needing the app to be opened every day
    final Map<String, dynamic> monthlySchedule = {};
    try {
      final engine = AstronomicalEngine(
        latitude: currentCity.latitude,
        longitude: currentCity.longitude,
        timeZone: currentCity.timezone,
        method: calcMethod,
        asrJuristic: settings.asrMethod,
        elevation: currentCity.elevation,
        fajrMode: settings.fajrMode,
        fajrDegree: settings.fajrDegree,
        fajrIntervalMin: settings.fajrIntervalMin,
        ishaMode: settings.ishaMode,
        ishaDegree: settings.ishaDegree,
        ishaIntervalMin: settings.ishaIntervalMin,
        is12HourFormat: false,
      );

      final now = DateTime.now();
      for (int i = 0; i < 31; i++) {
        final d = now.add(Duration(days: i));
        final dayKey = '${d.year.toString().padLeft(4, '0')}_${d.month.toString().padLeft(2, '0')}_${d.day.toString().padLeft(2, '0')}';
        final dt = engine.calculateDetailedTimes(d);
        final fajrCard = dt['fajr_card'] as Map<String, dynamic>?;
        final sunriseCard = dt['sunrise_card'] as Map<String, dynamic>?;
        final zawalCard = dt['zawal_card'] as Map<String, dynamic>?;
        final dhuhrCard = dt['dhuhr_card'] as Map<String, dynamic>?;
        final asrCard = dt['asr_card'] as Map<String, dynamic>?;
        final maghribCard = dt['maghrib_card'] as Map<String, dynamic>?;
        final ishaCard = dt['isha_card'] as Map<String, dynamic>?;

        final f = clean(fajrCard?['start']?.toString());
        final s = clean(sunriseCard?['sunrise']?.toString());
        final nn = clean(zawalCard?['nisf_nahar']?.toString());
        final dh = clean(dhuhrCard?['start']?.toString());
        String? rawAsr;
        if (settings.asrMethod == 2) {
          rawAsr = asrCard?['hanafi_start']?.toString();
        } else {
          rawAsr = asrCard?['shafi_start']?.toString();
        }
        final asrVal = clean(rawAsr);
        final mg = clean(maghribCard?['sunset']?.toString());
        final ish = clean(ishaCard?['start']?.toString());

        monthlySchedule[dayKey] = {
          'fajr': f,
          'sunrise': s,
          'nisf_nahar': nn,
          'dhuhr': dh,
          'asr': asrVal,
          'maghrib': mg,
          'isha': ish,
          'fajr_min': parseMinutes(f),
          'sunrise_min': parseMinutes(s),
          'dhuhr_min': parseMinutes(dh),
          'asr_min': parseMinutes(asrVal),
          'maghrib_min': parseMinutes(mg),
          'isha_min': parseMinutes(ish),
        };
      }
    } catch (_) {}

    try {
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      channel.invokeMethod('updateWidgetData', {
        'monthly_schedule_json': jsonEncode(monthlySchedule),
        'latitude': currentCity.latitude.toString(),
        'longitude': currentCity.longitude.toString(),
        'timezone': currentCity.timezone.toString(),
        'asr_method': settings.asrMethod.toString(),
        'next_prayer_name': _nextPrayerName,
        'next_prayer_time': clean(_nextPrayerTime),
        'fajr': clean(fajr['start'] ?? fajr['adhan']),
        'sunrise': clean(sunrise['sunrise']),
        'nisf_nahar': clean(zawal['nisf_nahar']),
        'dhuhr': clean(dhuhr['start'] ?? dhuhr['adhan']),
        'asr': clean(asrTime),
        'maghrib': clean(maghrib['sunset']),
        'isha': clean(isha['start'] ?? isha['adhan']),
        'city': currentCity.name,
        'widget_theme': settings.widgetTheme,
        'widget_layout': settings.widgetLayout,
      });
    } catch (_) {}
  }

  void _checkLiveAdhanAlarms() {
    if (_detailedTimes.isEmpty) return;
    final today = _now.day;
    if (_lastCheckedAlarmDay != today) {
      _triggeredAlarmsToday.clear();
      _lastCheckedAlarmDay = today;
    }

    final alarmService = AlarmService();
    final settings = AppSettings();
    final nowSec = _now.hour * 3600 + _now.minute * 60 + _now.second;

    final prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    // Check Tahajjud Alarm if enabled
    if (settings.tahajjudAlarmEnabled) {
      final tahajjudTag = '${_now.year}_${_now.month}_${_now.day}_tahajjud';
      if (!_triggeredAlarmsToday.contains(tahajjudTag)) {
        final targetHour = settings.getPrayerAlarmTargetHour(
          prayerKey: 'tahajjud',
          detailedTimes: _detailedTimes,
        );
        final targetSec = (targetHour * 3600).round() % 86400;
        final diff = nowSec - targetSec;
        if (diff >= 0 && diff <= 120) {
          _triggeredAlarmsToday.add(tahajjudTag);
          final reason = AppLocale.t(
            ur: 'نمازِ تہجد (صبحِ صادق سے ${settings.tahajjudMinutesBefore} منٹ قبل)',
            en: 'Tahajjud Prayer (${settings.tahajjudMinutesBefore}m before dawn)',
          );
          alarmService.triggerPrayerAlarm(context, reason);
        }
      }
    }

    for (final key in prayerKeys) {
      if (!(alarmService.prayerAlarms[key] ?? false)) continue;
      final alarmTag = '${_now.year}_${_now.month}_${_now.day}_$key';
      if (_triggeredAlarmsToday.contains(alarmTag)) continue;

      final targetHour = settings.getPrayerAlarmTargetHour(
        prayerKey: key,
        detailedTimes: _detailedTimes,
      );
      final targetSec = (targetHour * 3600).round() % 86400;

      // Active triggering window of 120 seconds prevents missed triggers if clock ticks by 2s or device briefly sleeps
      final diff = nowSec - targetSec;
      if (diff >= 0 && diff <= 120) {
        _triggeredAlarmsToday.add(alarmTag);
        final prayerDisplayName = AppLocale.t(
          ur: key == 'fajr' ? 'فجر' : (key == 'dhuhr' ? 'ظہر' : (key == 'asr' ? 'عصر' : (key == 'maghrib' ? 'مغرب' : 'عشاء'))),
          en: key[0].toUpperCase() + key.substring(1),
        );
        final reason = (settings.alarmTimingMode == 'BEFORE_JAMAAT')
            ? AppLocale.t(
                ur: '$prayerDisplayName (جماعت سے ${settings.alarmBeforeJamaatMinutes} منٹ قبل)',
                en: '$prayerDisplayName (${settings.alarmBeforeJamaatMinutes}m before Jama\'at)',
              )
            : prayerDisplayName;

        alarmService.triggerPrayerAlarm(context, reason);
      }
    }
  }

  String _getWeekdayName(int weekday) {
    if (AppLocale.isUrdu) {
      switch (weekday) {
        case DateTime.monday: return 'پیر';
        case DateTime.tuesday: return 'منگل';
        case DateTime.wednesday: return 'بدھ';
        case DateTime.thursday: return 'جمعرات';
        case DateTime.friday: return 'جمعہ المبارک';
        case DateTime.saturday: return 'ہفتہ';
        case DateTime.sunday: return 'اتوار';
        default: return '';
      }
    } else {
      switch (weekday) {
        case DateTime.monday: return 'Monday';
        case DateTime.tuesday: return 'Tuesday';
        case DateTime.wednesday: return 'Wednesday';
        case DateTime.thursday: return 'Thursday';
        case DateTime.friday: return 'Friday';
        case DateTime.saturday: return 'Saturday';
        case DateTime.sunday: return 'Sunday';
        default: return '';
      }
    }
  }

  String _getMonthName(int m) {
    if (AppLocale.isUrdu) {
      const list = [
        '', 'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
        'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
      ];
      return list[m];
    } else {
      const list = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return list[m];
    }
  }

  @override
  Widget build(BuildContext context) {
    final fajr = _detailedTimes['fajr_card'] as Map<String, dynamic>? ?? {};
    final sunrise = _detailedTimes['sunrise_card'] as Map<String, dynamic>? ?? {};
    final nisfNahar = _detailedTimes['nisf_nahar_card'] as Map<String, dynamic>? ?? {};
    final zawal = _detailedTimes['zawal_card'] as Map<String, dynamic>? ?? {};
    final dhuhr = _detailedTimes['dhuhr_card'] as Map<String, dynamic>? ?? {};
    final asr = _detailedTimes['asr_card'] as Map<String, dynamic>? ?? {};
    final maghrib = _detailedTimes['maghrib_card'] as Map<String, dynamic>? ?? {};
    final isha = _detailedTimes['isha_card'] as Map<String, dynamic>? ?? {};
    final tahajjud = _detailedTimes['tahajjud_card'] as Map<String, dynamic>? ?? {};
    final fasting = _detailedTimes['fasting'] as Map<String, dynamic>? ?? {};

    final weekdayName = _getWeekdayName(_currentDisplayDate.weekday);
    final monthName = _getMonthName(_currentDisplayDate.month);

    final bool is12h = AppSettings().is12HourFormat;
    final int rawLiveH = _now.hour;
    final String livePeriod = rawLiveH >= 12 ? 'PM' : 'AM';
    final int liveH12Num = (rawLiveH % 12 == 0) ? 12 : rawLiveH % 12;
    final liveH = (is12h ? liveH12Num : rawLiveH).toString().padLeft(2, '0');
    final liveM = _now.minute.toString().padLeft(2, '0');
    final liveS = _now.second.toString().padLeft(2, '0');
    final liveClockStr = is12h ? '$liveH:$liveM:$liveS $livePeriod' : '$liveH:$liveM:$liveS';

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Text('🕌', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocale.t(ur: 'المیقات', en: 'Al-Meeqat'),
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            // Live Clock Pill (Clickable -> Opens Full Screen Solar Arc Overlay without scrolling)
            InkWell(
              onTap: _openSolarArcOverlay,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.6), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wb_sunny, size: 12, color: AppTheme.gold),
                    const SizedBox(width: 4),
                    Text(
                      liveClockStr,
                      style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),

            // Live Dark / Light Mode Switcher
            ValueListenableBuilder<bool>(
              valueListenable: AppTheme.isDarkNotifier,
              builder: (context, isDark, _) {
                return InkWell(
                  onTap: () {
                    AppTheme.toggle();
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.gold, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          size: 15,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDark ? (AppLocale.isUrdu ? 'لائٹ' : 'Light') : (AppLocale.isUrdu ? 'ڈارک' : 'Dark'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Bilingual Language Toggle Button
            Padding(
              padding: const EdgeInsets.only(right: 6.0, left: 6.0),
              child: InkWell(
                onTap: () {
                  AppLocale.toggle();
                  _recalculate();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.emerald, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, size: 15, color: AppTheme.emerald),
                      const SizedBox(width: 4),
                      Text(
                        AppLocale.isUrdu ? 'EN' : 'اردو',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Directionality(
          textDirection: AppLocale.textDirection,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                // Location Row with Location Pill & 1-Tap Live GPS Auto-Detect Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () async {
                          final selected = await Navigator.push<CityModel>(
                            context,
                            MaterialPageRoute(builder: (c) => const GazetteerScreen()),
                          );
                          if (selected != null) {
                            setState(() {
                              currentCity = selected;
                              AppSettings().setDefaultCity(selected);
                              _recalculate();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, color: AppTheme.emerald, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${currentCity.name} (${currentCity.latitude.toStringAsFixed(2)}°, ${currentCity.longitude.toStringAsFixed(2)}°)',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, color: AppTheme.emerald, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dedicated 1-Tap Live GPS Auto Detect Button
                    InkWell(
                      onTap: _isDetectingLocation ? null : () => _autoDetectCurrentLocation(silent: false),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.sky.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppTheme.sky, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isDetectingLocation
                                ? SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(color: AppTheme.sky, strokeWidth: 2),
                                  )
                                : Icon(Icons.my_location, color: AppTheme.sky, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              _isDetectingLocation
                                  ? AppLocale.t(ur: 'تلاش جاری...', en: 'Detecting...')
                                  : AppLocale.t(ur: 'آٹو ڈیٹیکٹ', en: 'Auto GPS'),
                              style: TextStyle(
                                color: AppTheme.sky,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Subtle Elegant Home Screen Clock Widget Announcement Banner
                _buildHomeWidgetBanner(),

                // Date Navigation Bar (پچھلا دن | تاریخیں | اگلا دن)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          AppLocale.isUrdu ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                          color: AppTheme.emerald,
                          size: 18,
                        ),
                        tooltip: AppLocale.t(ur: 'پچھلا دن', en: 'Previous Day'),
                        onPressed: () {
                          setState(() {
                            _currentDisplayDate = _currentDisplayDate.subtract(const Duration(days: 1));
                            _recalculate();
                          });
                        },
                      ),
                      Column(
                        children: [
                          Text(
                            '$weekdayName، ${_currentDisplayDate.day} $monthName ${_currentDisplayDate.year}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hijriDate,
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          AppLocale.isUrdu ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                          color: AppTheme.emerald,
                          size: 18,
                        ),
                        tooltip: AppLocale.t(ur: 'اگلا دن', en: 'Next Day'),
                        onPressed: () {
                          setState(() {
                            _currentDisplayDate = _currentDisplayDate.add(const Duration(days: 1));
                            _recalculate();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Central Ruet-e-Hilal Certified Moon Sighting Banner
                _buildRuetHilalBanner(),

                // Daily Salah Tracker & Qadha-e-Umri Quick Bar
                _buildSalahTrackerBar(),

                // 1. Daily Sehar & Iftar Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              const Text('🌙 ', style: TextStyle(fontSize: 16)),
                              Text(
                                AppLocale.t(ur: 'اختتامِ سحر', en: 'Sehar End'),
                                style: TextStyle(color: AppTheme.gold, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fasting['sehar_end'] ?? '--:--:--',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 45, color: AppTheme.border),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Text('☀️ ', style: TextStyle(fontSize: 16)),
                              Text(
                                AppLocale.t(ur: 'وقتِ افطار', en: 'Iftar Time'),
                                style: TextStyle(color: AppTheme.emerald, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fasting['iftar_time'] ?? '--:--:--',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Next Prayer Countdown Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF059669), const Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _countdownStr,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppLocale.t(ur: 'اگلی نماز', en: 'Next Prayer')}: $_nextPrayerName (${AppLocale.t(ur: 'وقت', en: 'Time')}: \u200E$_nextPrayerTime\u200E)',
                        style: TextStyle(
                          color: AppTheme.isDark ? const Color(0xFFF59E0B) : const Color(0xFFFEF3C7),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Solar Day Arc Progress Timeline Widget (سورج کا بصری راستہ)
                _buildSolarDayArcWidget(),

                // 4. فجر کارڈ
                _buildPrayerCard(
                  cardKey: 'fajr',
                  title: AppLocale.t(
                    ur: 'فجر',
                    en: 'Fajr',
                  ),
                  icon: Icons.nightlight_round,
                  primaryLabel: AppLocale.t(ur: 'اذان فجر', en: 'Fajr Adhan'),
                  primaryTime: fajr['adhan'] ?? fajr['start'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'ختم سحر \u200E(1m-)\u200E', en: 'Sehar End (-1m)'), 'time': fajr['sehar_end'] ?? '', 'color': AppTheme.gold},
                    {'label': AppLocale.t(ur: 'فجر شروع وقت', en: 'Fajr Start'), 'time': fajr['start'] ?? '', 'color': AppTheme.emerald},
                    {'label': AppLocale.t(ur: 'اذان فجر', en: 'Fajr Adhan'), 'time': fajr['adhan'] ?? '', 'color': AppTheme.gold},
                    {'label': AppLocale.t(ur: 'فجر اختتام', en: 'Fajr End'), 'time': fajr['end'] ?? '', 'color': AppTheme.textSecondary},
                  ],
                ),

                // 5. طلوعِ آفتاب کارڈ
                _buildPrayerCard(
                  cardKey: 'sunrise',
                  title: AppLocale.t(ur: 'طلوعِ آفتاب', en: 'Sunrise'),
                  icon: Icons.wb_sunny_outlined,
                  primaryLabel: AppLocale.t(ur: 'طلوع آفتاب', en: 'Sunrise'),
                  primaryTime: sunrise['sunrise'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'طلوع آفتاب', en: 'Sunrise'), 'time': sunrise['sunrise'] ?? '', 'color': AppTheme.textSecondary},
                    {'label': AppLocale.t(ur: 'اشراق مستحب', en: 'Ishraq'), 'time': sunrise['ishraq'] ?? '', 'color': AppTheme.emerald},
                    {'label': AppLocale.t(ur: 'ابتداء اشراق', en: 'Ishraq Start'), 'time': sunrise['ishraq_start'] ?? '', 'color': AppTheme.gold},
                  ],
                ),

                // 6. نصف النہار شرعی کارڈ
                _buildPrayerCard(
                  cardKey: 'nisf_nahar',
                  title: AppLocale.t(ur: 'نصف النہار شرعی', en: 'Shar\'i Midday (Nisf-un-Nahar)'),
                  icon: Icons.brightness_medium,
                  primaryLabel: AppLocale.t(ur: 'نصف النہار شرعی', en: 'Shar\'i Midday'),
                  primaryTime: nisfNahar['time'] ?? '',
                  rows: [],
                ),

                // 7. زوال کارڈ
                _buildPrayerCard(
                  cardKey: 'zawal',
                  title: AppLocale.t(ur: 'زوال و وقتِ استواء', en: 'Zawal & Istiwa'),
                  icon: Icons.hourglass_empty,
                  primaryLabel: AppLocale.t(ur: 'زوال آغاز', en: 'Zawal Start'),
                  primaryTime: zawal['zawal'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'زوال انتہاء', en: 'Zawal End'), 'time': zawal['end'] ?? '', 'color': AppTheme.emerald},
                  ],
                ),

                // 8. ظہر کارڈ
                _buildPrayerCard(
                  cardKey: 'dhuhr',
                  title: AppLocale.t(ur: 'ظہر', en: 'Dhuhr'),
                  icon: Icons.wb_sunny,
                  primaryLabel: AppLocale.t(ur: 'اذان ظہر', en: 'Dhuhr Adhan'),
                  primaryTime: dhuhr['adhan'] ?? dhuhr['start'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'ابتداء ظہر', en: 'Dhuhr Start'), 'time': dhuhr['start'] ?? '', 'color': AppTheme.emerald},
                    {'label': AppLocale.t(ur: 'اذان ظہر', en: 'Dhuhr Adhan'), 'time': dhuhr['adhan'] ?? '', 'color': AppTheme.gold},
                    {'label': AppLocale.t(ur: 'ظہر شافعی اختتام', en: 'Dhuhr Shafi\'i End'), 'time': dhuhr['shafi_end'] ?? '', 'color': AppTheme.textSecondary},
                    {'label': AppLocale.t(ur: 'ظہر حنفی اختتام', en: 'Dhuhr Hanafi End'), 'time': dhuhr['hanafi_end'] ?? '', 'color': AppTheme.textSecondary},
                  ],
                ),

                // 9. عصر کارڈ (حنفی یا شافعی ترجیح صارف کی سیٹنگ کے مطابق)
                _buildPrayerCard(
                  cardKey: 'asr',
                  title: AppLocale.t(
                    ur: AppSettings().asrMethod == 2 ? 'عصر (حنفی معیار)' : 'عصر (شافعی معیار)',
                    en: AppSettings().asrMethod == 2 ? 'Asr (Hanafi Factor)' : 'Asr (Shafi\'i Factor)',
                  ),
                  icon: Icons.cloud,
                  primaryLabel: AppSettings().asrMethod == 2
                      ? AppLocale.t(ur: 'اذان عصر حنفی', en: 'Asr Hanafi Adhan')
                      : AppLocale.t(ur: 'اذان عصر شافعی', en: 'Asr Shafi\'i Adhan'),
                  primaryTime: AppSettings().asrMethod == 2
                      ? (asr['hanafi_adhan'] ?? asr['hanafi_start'] ?? '')
                      : (asr['shafi_adhan'] ?? asr['shafi_start'] ?? ''),
                  rows: AppSettings().asrMethod == 2
                      ? [
                          {'label': AppLocale.t(ur: 'عصر حنفی ابتداء', en: 'Asr Hanafi Start'), 'time': asr['hanafi_start'] ?? '', 'color': AppTheme.emerald},
                          {'label': AppLocale.t(ur: 'اذان عصر حنفی', en: 'Asr Hanafi Adhan'), 'time': asr['hanafi_adhan'] ?? '', 'color': AppTheme.gold},
                          {'label': AppLocale.t(ur: 'عصر شافعی ابتداء', en: 'Asr Shafi\'i Start'), 'time': asr['shafi_start'] ?? '', 'color': AppTheme.textSecondary},
                          {'label': AppLocale.t(ur: 'اذان عصر شافعی', en: 'Asr Shafi\'i Adhan'), 'time': asr['shafi_adhan'] ?? '', 'color': AppTheme.textSecondary},
                          {'label': AppLocale.t(ur: 'عصر مکروہ (غروب سے 15 منٹ قبل)', en: 'Asr Makrooh (15m before Sunset)'), 'time': asr['makrooh'] ?? '', 'color': AppTheme.red},
                        ]
                      : [
                          {'label': AppLocale.t(ur: 'عصر شافعی ابتداء', en: 'Asr Shafi\'i Start'), 'time': asr['shafi_start'] ?? '', 'color': AppTheme.emerald},
                          {'label': AppLocale.t(ur: 'اذان عصر شافعی', en: 'Asr Shafi\'i Adhan'), 'time': asr['shafi_adhan'] ?? '', 'color': AppTheme.gold},
                          {'label': AppLocale.t(ur: 'عصر حنفی ابتداء', en: 'Asr Hanafi Start'), 'time': asr['hanafi_start'] ?? '', 'color': AppTheme.textSecondary},
                          {'label': AppLocale.t(ur: 'اذان عصر حنفی', en: 'Asr Hanafi Adhan'), 'time': asr['hanafi_adhan'] ?? '', 'color': AppTheme.textSecondary},
                          {'label': AppLocale.t(ur: 'عصر مکروہ (غروب سے 15 منٹ قبل)', en: 'Asr Makrooh (15m before Sunset)'), 'time': asr['makrooh'] ?? '', 'color': AppTheme.red},
                        ],
                ),

                // 10. مغرب کارڈ
                _buildPrayerCard(
                  cardKey: 'maghrib',
                  title: AppLocale.t(ur: 'مغرب', en: 'Maghrib'),
                  icon: Icons.wb_twilight,
                  primaryLabel: AppLocale.t(ur: 'افطار اور اذان', en: 'Iftar & Adhan'),
                  primaryTime: maghrib['iftar_adhan'] ?? maghrib['sunset'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'غروبِ آفتاب', en: 'Sunset'), 'time': maghrib['sunset'] ?? '', 'color': AppTheme.textSecondary},
                    {'label': AppLocale.t(ur: 'افطار اور اذان (+1m)', en: 'Iftar & Adhan (+1m)'), 'time': maghrib['iftar_adhan'] ?? '', 'color': AppTheme.emerald},
                    {'label': AppLocale.t(ur: 'مغرب اختتام', en: 'Maghrib End'), 'time': maghrib['end'] ?? '', 'color': AppTheme.textSecondary},
                  ],
                ),

                // 11. عشاء کارڈ
                _buildPrayerCard(
                  cardKey: 'isha',
                  title: AppLocale.t(
                    ur: 'عشاء',
                    en: 'Isha',
                  ),
                  icon: Icons.bedtime,
                  primaryLabel: AppLocale.t(ur: 'عشاء اذان', en: 'Isha Adhan'),
                  primaryTime: isha['adhan'] ?? isha['start'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'عشاء ابتداء', en: 'Isha Start'), 'time': isha['start'] ?? '', 'color': AppTheme.emerald},
                    {'label': AppLocale.t(ur: 'عشاء اذان', en: 'Isha Adhan'), 'time': isha['adhan'] ?? '', 'color': AppTheme.gold},
                    {'label': AppLocale.t(ur: 'عشاء مکروہ (نصف شب)', en: 'Isha Makrooh (Midnight)'), 'time': isha['makrooh'] ?? '', 'color': AppTheme.red},
                    {'label': AppLocale.t(ur: 'عشاء اختتام', en: 'Isha End'), 'time': isha['end'] ?? '', 'color': AppTheme.textSecondary},
                  ],
                ),

                // 12. تہجد کا افضل وقت کارڈ
                _buildPrayerCard(
                  cardKey: 'tahajjud',
                  title: AppLocale.t(ur: 'تہجد کا افضل وقت', en: 'Optimal Tahajjud Time'),
                  icon: Icons.stars,
                  primaryLabel: AppLocale.t(ur: 'آخری تہائی رات', en: 'Last 1/3 Night'),
                  primaryTime: tahajjud['third_start'] ?? '',
                  rows: [
                    {'label': AppLocale.t(ur: 'آخری سدس (چھٹا حصہ - افضل ترین)', en: 'Last 1/6 of Night (Most Optimal)'), 'time': tahajjud['sixth_start'] ?? '', 'color': AppTheme.gold},
                  ],
                  note: AppLocale.t(
                    ur: 'تہجد کا وقت نماز عشاء کی ادائیگی کے بعد شروع ہوتا ہے اور افضل وقت رات کے آخری حصے میں پڑھنا ہے۔',
                    en: 'Tahajjud begins after offering Isha prayer, and the most optimal time is to offer it in the last portion of the night.',
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Persistent Sticky Minaret Bottom Nav
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'home',
          city: currentCity,
          detailedTimes: _detailedTimes,
          hijriDate: _hijriDate,
          onCityChanged: (newCity) {
            setState(() {
              currentCity = newCity;
              _recalculate();
            });
          },
        ),
      ),
    );
  }

  Widget _buildSolarDayArcWidget() {
    final fajr = _detailedTimes['fajr_card'] as Map<String, dynamic>? ?? {};
    final sunrise = _detailedTimes['sunrise_card'] as Map<String, dynamic>? ?? {};
    final dhuhr = _detailedTimes['dhuhr_card'] as Map<String, dynamic>? ?? {};
    final asr = _detailedTimes['asr_card'] as Map<String, dynamic>? ?? {};
    final maghrib = _detailedTimes['maghrib_card'] as Map<String, dynamic>? ?? {};
    final isha = _detailedTimes['isha_card'] as Map<String, dynamic>? ?? {};

    final items = [
      {'key': 'fajr', 'name': AppLocale.t(ur: 'فجر', en: 'Fajr'), 'icon': Icons.nightlight_round, 'time': fajr['adhan'] ?? fajr['start'] ?? ''},
      {'key': 'sunrise', 'name': AppLocale.t(ur: 'طلوع', en: 'Sunrise'), 'icon': Icons.wb_sunny_outlined, 'time': sunrise['sunrise'] ?? ''},
      {'key': 'dhuhr', 'name': AppLocale.t(ur: 'ظہر', en: 'Dhuhr'), 'icon': Icons.wb_sunny, 'time': dhuhr['adhan'] ?? dhuhr['start'] ?? ''},
      {'key': 'asr', 'name': AppLocale.t(ur: 'عصر', en: 'Asr'), 'icon': Icons.cloud, 'time': asr['hanafi_adhan'] ?? asr['hanafi_start'] ?? ''},
      {'key': 'maghrib', 'name': AppLocale.t(ur: 'مغرب', en: 'Maghrib'), 'icon': Icons.wb_twilight, 'time': maghrib['iftar_adhan'] ?? maghrib['sunset'] ?? ''},
      {'key': 'isha', 'name': AppLocale.t(ur: 'عشاء', en: 'Isha'), 'icon': Icons.bedtime, 'time': isha['adhan'] ?? isha['start'] ?? ''},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openSolarArcOverlay,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, size: 16, color: AppTheme.gold),
                      const SizedBox(width: 6),
                      Text(
                        AppLocale.t(ur: 'سورج کا بصری راستہ اور اوقاتِ صلوٰۃ', en: 'Solar Prayer Path Timeline'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_full, size: 13, color: AppTheme.gold),
                    ],
                  ),
                  Text(
                    _nextPrayerName.isNotEmpty ? '${AppLocale.t(ur: 'اگلی:', en: 'Next:')} $_nextPrayerName' : '',
                    style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((it) {
                final bool isNext = _nextPrayerName.toLowerCase().contains(it['key']!.toLowerCase()) ||
                    (it['key'] == 'dhuhr' && _nextPrayerName.contains('ظہر')) ||
                    (it['key'] == 'fajr' && _nextPrayerName.contains('فجر')) ||
                    (it['key'] == 'asr' && _nextPrayerName.contains('عصر')) ||
                    (it['key'] == 'maghrib' && _nextPrayerName.contains('مغرب')) ||
                    (it['key'] == 'isha' && _nextPrayerName.contains('عشاء'));

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isNext ? AppTheme.emerald.withValues(alpha: 0.16) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isNext ? AppTheme.emerald : AppTheme.border,
                      width: isNext ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        it['icon'] as IconData,
                        size: 18,
                        color: isNext ? AppTheme.emerald : (it['key'] == 'sunrise' ? AppTheme.gold : AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        it['name'] as String,
                        style: TextStyle(
                          color: isNext ? AppTheme.emerald : AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        it['time'] as String,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: isNext ? AppTheme.gold : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard({
    required String cardKey,
    required String title,
    required IconData icon,
    required String primaryLabel,
    required String primaryTime,
    required List<Map<String, dynamic>> rows,
    String? note,
  }) {
    final bool isExpanded = _expandedCards.contains(cardKey);
    final bool isNextPrayer = _nextPrayerName.toLowerCase().contains(cardKey.toLowerCase()) ||
        (cardKey == 'dhuhr' && _nextPrayerName.contains('ظہر')) ||
        (cardKey == 'fajr' && _nextPrayerName.contains('فجر')) ||
        (cardKey == 'asr' && _nextPrayerName.contains('عصر')) ||
        (cardKey == 'maghrib' && _nextPrayerName.contains('مغرب')) ||
        (cardKey == 'isha' && _nextPrayerName.contains('عشاء'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNextPrayer ? AppTheme.emerald : AppTheme.border,
          width: isNextPrayer ? 1.5 : 1.0,
        ),
        boxShadow: isNextPrayer ? AppTheme.elevatedShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: rows.isNotEmpty
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCards.remove(cardKey);
                    } else {
                      _expandedCards.add(cardKey);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row: Icon, Title, Primary Time, and Accordion Toggle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isNextPrayer ? AppTheme.emerald.withValues(alpha: 0.16) : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isNextPrayer ? AppTheme.emerald : AppTheme.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.5,
                            ),
                          ),
                          Text(
                            primaryLabel,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          primaryTime,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: isNextPrayer ? AppTheme.emerald : AppTheme.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (rows.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isExpanded
                                    ? AppLocale.t(ur: 'مختصر ▴', en: 'Less ▴')
                                    : AppLocale.t(ur: 'تفصیلات ▾', en: 'Details ▾'),
                                style: TextStyle(
                                  color: AppTheme.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),

                // Expandable Sub-milestone Rows
                if (rows.isNotEmpty && isExpanded) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 6),
                  ...rows.map((r) {
                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r['label'] as String,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            r['time'] as String,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: r['color'] as Color,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Note (if present - placed at the very bottom/end)
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.gold, size: 16),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuetHilalBanner() {
    final decl = MosqueSyncService().latestDeclaration;
    if (decl == null || !decl.active || decl.textUr.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🌙', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      decl.titleUr,
                      style: TextStyle(
                        fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emerald, width: 0.8),
                      ),
                      child: Text(
                        decl.committee,
                        style: TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  decl.textUr,
                  style: TextStyle(
                    fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalahTrackerBar() {
    final tracker = SalahTrackerManager();
    final todayCount = tracker.getCompletedCountForDate(_currentDisplayDate);

    final prayers = [
      {'key': 'fajr', 'name': AppLocale.t(ur: 'فجر', en: 'Fajr')},
      {'key': 'dhuhr', 'name': AppLocale.t(ur: 'ظہر', en: 'Dhuhr')},
      {'key': 'asr', 'name': AppLocale.t(ur: 'عصر', en: 'Asr')},
      {'key': 'maghrib', 'name': AppLocale.t(ur: 'مغرب', en: 'Maghrib')},
      {'key': 'isha', 'name': AppLocale.t(ur: 'عشاء', en: 'Isha')},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${AppLocale.t(ur: 'روزانہ نماز ٹریکر', en: 'Daily Salah Tracker')} ($todayCount/5)',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const QadhaUmriScreen()),
                  ).then((_) => setState(() {}));
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.gold, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_turned_in, size: 13, color: AppTheme.gold),
                      const SizedBox(width: 4),
                      Text(
                        AppLocale.t(ur: 'قضاءِ عمری رجسٹر', en: 'Qadha Ledger'),
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayers.map((p) {
              final key = p['key']!;
              final name = p['name']!;
              final status = tracker.getStatus(_currentDisplayDate, key);

              Color bgCol = AppTheme.surface;
              Color borderCol = AppTheme.border;
              Color textCol = AppTheme.textSecondary;
              IconData icon = Icons.radio_button_unchecked;
              String statusLabel = AppLocale.t(ur: 'غیر ادا', en: 'Pending');

              switch (status) {
                case SalahStatus.jamaat:
                  bgCol = AppTheme.emerald.withValues(alpha: 0.2);
                  borderCol = AppTheme.emerald;
                  textCol = AppTheme.emerald;
                  icon = Icons.mosque;
                  statusLabel = AppLocale.t(ur: 'باجماعت', en: 'Jama\'at');
                  break;
                case SalahStatus.individual:
                  bgCol = AppTheme.sky.withValues(alpha: 0.2);
                  borderCol = AppTheme.sky;
                  textCol = AppTheme.sky;
                  icon = Icons.done;
                  statusLabel = AppLocale.t(ur: 'انفرادی', en: 'Alone');
                  break;
                case SalahStatus.qadha:
                  bgCol = Colors.red.withValues(alpha: 0.2);
                  borderCol = Colors.red;
                  textCol = Colors.red;
                  icon = Icons.priority_high;
                  statusLabel = AppLocale.t(ur: 'قضاء', en: 'Qadha');
                  break;
                case SalahStatus.none:
                  bgCol = AppTheme.surface;
                  borderCol = AppTheme.border;
                  textCol = AppTheme.textSecondary;
                  icon = Icons.radio_button_unchecked;
                  statusLabel = AppLocale.t(ur: 'غیر ادا', en: 'Pending');
                  break;
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () async {
                      await tracker.cycleStatus(_currentDisplayDate, key);
                      if (mounted) setState(() {});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      decoration: BoxDecoration(
                        color: bgCol,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: textCol),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: textCol,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeWidgetBanner() {
    if (!_showWidgetBanner) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.widgets_outlined, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.t(
                        ur: '🏛️ ہوم اسکرین کلاک ویجٹ',
                        en: '🏛️ Home Screen Clock Widget',
                      ),
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocale.t(
                        ur: 'موبائل اسکرین پر براہِ راست لائیو کلاک اور تمام اوقات لگائیں',
                        en: 'Pin live prayer clock directly on your mobile home screen',
                      ),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Close button
              InkWell(
                onTap: () => setState(() => _showWidgetBanner = false),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Prominent "موبائل ہوم اسکرین پر کلاک ویجٹ لگائیں" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.add_to_home_screen, size: 18),
              label: Text(
                AppLocale.t(
                  ur: 'موبائل ہوم اسکرین پر کلاک ویجٹ لگائیں',
                  en: 'Add Clock Widget to Mobile Home Screen',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _showAutoPinWidgetConfirmationDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showAutoPinWidgetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.widgets, color: AppTheme.emerald, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocale.t(ur: 'موبائل ہوم اسکرین پر کلاک ویجٹ لگائیں', en: 'Add Clock Widget to Home Screen'),
                  style: TextStyle(color: AppTheme.gold, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.t(
                  ur: 'کیا آپ اپنے موبائل کی ہوم اسکرین پر المیقات کا جدید لائیو کلاک ویجٹ سیٹ کرنا چاہتے ہیں؟',
                  en: 'Would you like to pin the Meeqat live clock widget to your mobile home screen?',
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.grid_view, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocale.t(
                              ur: 'بہترین اور رسپانسو نظارے کے لیے دائیں سے بائیں مکمل اسکرین اور اوپر سے نیچے نصف اسکرین (کم از کم 4x2 یا 4x3 گرڈ) کی جگہ ہونی چاہیے۔',
                              en: 'For optimal responsive display, requires full screen width and half screen height (at least 4x2 or 4x3 grid space).',
                            ),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocale.t(
                              ur: 'اگر موجودہ ہوم اسکرین پر مطلوبہ خالی جگہ نہ ملی تو آپ کا موبائل سسٹم خود بخود اسے اگلی اسکرین پر سیٹ کر دے گا۔',
                              en: 'If space is unavailable on current screen, your system will automatically place it on the next screen.',
                            ),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocale.t(ur: 'منسوخ', en: 'Cancel'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _pinWidgetToHomeScreen();
              },
              child: Text(AppLocale.t(ur: 'ویجٹ لگائیں', en: 'Add Widget')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pinWidgetToHomeScreen() async {
    try {
      _syncHomeWidgetData();
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      final bool? pinned = await channel.invokeMethod<bool>('pinWidgetToHomeScreen');
      if (!mounted) return;
      if (pinned == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t(
                ur: 'ویجٹ پن کرنے کی درخواست بھیج دی گئی۔ موبائل سسٹم پاپ اپ میں "Add" یا "شامل کریں" پر کلک کریں۔',
                en: 'Widget request sent! Please tap "Add" on the system popup.',
              ),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t(
                ur: 'موبائل لانچر خودکار پننگ کی اجازت نہیں دیتا۔ آپ ہوم اسکرین پر لانگ پریس کر کے ویجٹس سے شامل کر سکتے ہیں۔',
                en: 'Launcher does not support auto-pinning. Please long-press home screen to add manually.',
              ),
            ),
            backgroundColor: Colors.amber[800],
          ),
        );
      }
    } catch (_) {}
  }
}
