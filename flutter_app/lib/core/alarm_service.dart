// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_locale.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'astronomical_engine.dart';
import '../widgets/post_adhan_dua_dialog.dart';

/// Full-featured Audio Alarm Service with real tone playback,
/// snooze/repeat reminders, famous mosque tones, dual language UI,
/// and native background scheduled notifications that ring even when app is closed.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal() {
    _initPlayer();
  }

  AudioPlayer? _player;
  bool _isPlaying = false;
  Timer? _snoozeTimer;
  VoidCallback? onPlaybackFinished;

  bool get isPlaying => _isPlaying;

  // Prayer alarm toggles delegated directly to persistent AppSettings
  Map<String, bool> get prayerAlarms => AppSettings().prayerAlarms;

  // Snooze / Reminder interval in minutes (5, 10, 15, or 0 = Off)
  int get snoozeIntervalMinutes => AppSettings().snoozeIntervalMinutes;
  set snoozeIntervalMinutes(int val) => AppSettings().snoozeIntervalMinutes = val;

  bool get isRepeatReminderEnabled => AppSettings().isRepeatReminderEnabled;
  set isRepeatReminderEnabled(bool val) => AppSettings().isRepeatReminderEnabled = val;

  // Available Authentic Adhan Audio Streams & Bundled Offline Recordings
  static const List<Map<String, String>> adhanTones = [
    {
      'id': 'makkah',
      'name_ur': 'اذانِ مکہ مکرمہ (مسجد الحرام)',
      'name_en': 'Makkah Adhan (Masjid al-Haram)',
      'muazzin_ur': 'الشیخ علی احمد ملا',
      'muazzin_en': 'Sheikh Ali Ahmed Mulla',
      'asset_path': 'audio/makkah.mp3',
      'audio_url': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Makkah.mp3',
      'audio_fallback': 'https://ia800201.us.archive.org/27/items/AdhanMakkah_201610/AdhanMakkah.mp3',
    },
    {
      'id': 'madinah',
      'name_ur': 'اذانِ مدینہ منورہ (مسجد نبوی)',
      'name_en': 'Madinah Adhan (Al-Masjid an-Nabawi)',
      'muazzin_ur': 'الشیخ عصام بخاری',
      'muazzin_en': 'Sheikh Essam Bukhari',
      'asset_path': 'audio/madinah.mp3',
      'audio_url': 'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Adhan_Al_Haram_Al_Madani_-_Al_Madinah_2_(%D8%A3%D8%B0%D8%A7%D9%86_%D8%A7%D9%84%D8%AD%D8%B1%D9%85_%D8%A7%D9%84%D9%85%D8%AF%D9%86%D9%8A_-_%D8%A7%D9%84%D9%85%D8%AF%D9%8A%D9%86%D8%A9_%D8%A7%D9%84%D9%85%D9%86%D9%88%D8%B1%D8%A9).mp3',
      'audio_fallback': 'https://ia800302.us.archive.org/3/items/AdhanMadinah/AdhanMadinah.mp3',
    },
    {
      'id': 'aqsa',
      'name_ur': 'اذانِ مسجد اقصیٰ (القدس)',
      'name_en': 'Al-Aqsa Adhan (Al-Quds)',
      'muazzin_ur': 'الشیخ صہیب خطبہ',
      'muazzin_en': 'Sheikh Suhaib Khatba',
      'asset_path': 'audio/aqsa.mp3',
      'audio_url': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Suhaib%20Khatba.mp3',
      'audio_fallback': 'https://ia800301.us.archive.org/15/items/AdhanAlAqsa/AdhanAlAqsa.mp3',
    },
    {
      'id': 'cairo',
      'name_ur': 'اذانِ جامع الازہر (قاہرہ)',
      'name_en': 'Al-Azhar Adhan (Cairo)',
      'muazzin_ur': 'الشیخ عبد الباسط عبد الصمد',
      'muazzin_en': 'Sheikh Abdul Basit Abdul Samad',
      'asset_path': 'audio/cairo.mp3',
      'audio_url': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Abed%20Albase6.mp3',
      'audio_fallback': 'https://ia800205.us.archive.org/11/items/AdhanEgypt/AdhanEgypt.mp3',
    },
    {
      'id': 'istanbul',
      'name_ur': 'اذانِ استنبول (جامع سلطان احمد)',
      'name_en': 'Istanbul Adhan (Blue Mosque)',
      'muazzin_ur': 'اذانِ ترکی (مقامِ صبا و راست)',
      'muazzin_en': 'Turkish Adhan (Maqam Saba & Rast)',
      'asset_path': 'audio/istanbul.mp3',
      'audio_url': 'https://raw.githubusercontent.com/Kiwifu/adhan-mp3/main/Adhan_Turkey_1_(%D8%A3%D8%B0%D8%A7%D9%86_%D8%AA%D8%B1%D9%83%D9%8A%D8%A7).mp3',
      'audio_fallback': 'https://ia800200.us.archive.org/22/items/AdhanTurkey/AdhanTurkey.mp3',
    },
  ];

  String get selectedToneId => AppSettings().selectedAdhanTone;
  set selectedToneId(String toneId) {
    AppSettings().selectedAdhanTone = toneId;
  }

  void _initPlayer() {
    try {
      _player = AudioPlayer();
      _player?.onPlayerComplete.listen((_) {
        _isPlaying = false;
        try {
          _notificationsPlugin.cancel(id: 999);
        } catch (_) {}
        onPlaybackFinished?.call();
      });
      _player?.onPlayerStateChanged.listen((state) {
        _isPlaying = (state == PlayerState.playing);
        if (!_isPlaying) {
          try {
            _notificationsPlugin.cancel(id: 999);
          } catch (_) {}
          onPlaybackFinished?.call();
        }
      });
    } catch (_) {}
  }

  void toggleAlarm(String prayerKey, bool enabled) {
    AppSettings().setPrayerAlarm(prayerKey, enabled);
  }

  void setTone(String toneId) {
    selectedToneId = toneId;
  }

  Map<String, String> get currentTone {
    return adhanTones.firstWhere(
      (t) => t['id'] == selectedToneId,
      orElse: () => adhanTones.first,
    );
  }

  // ========================================================
  // NATIVE BACKGROUND SCHEDULED NOTIFICATIONS (APP CLOSED)
  // ========================================================
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse details) {
    if (details.actionId == 'stop_alarm' || details.actionId == 'stop') {
      AlarmService().dismissAlarm();
    }
  }

  static Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.actionId == 'stop_alarm' || details.actionId == 'stop') {
            AlarmService().dismissAlarm();
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();

        // Create high-priority notification channels explicitly
        const prayerChannel = AndroidNotificationChannel(
          'adhan_channel_v4',
          'Adhan & Prayer Times Alarms',
          description: 'High-priority authentic Adhan prayer alarms and reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        const tahajjudChannel = AndroidNotificationChannel(
          'tahajjud_channel_v4',
          'Tahajjud Alarms',
          description: 'Tahajjud prayer wakeup alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        await androidPlugin.createNotificationChannel(prayerChannel);
        await androidPlugin.createNotificationChannel(tahajjudChannel);
      }
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('AlarmService: Notification initialization error: $e');
    }
  }

  /// Cancels previous alarms and reschedules native high-priority background Adhan
  /// audio alarms for all enabled prayers with Android AlarmManager setAlarmClock for 30 rolling days.
  static Future<void> scheduleBackgroundPrayerAlarms({
    Map<String, dynamic>? detailedTimes,
  }) async {
    try {
      await initNotifications();
      await _notificationsPlugin.cancelAllPendingNotifications();

      final settings = AppSettings();
      final alarmService = AlarmService();
      final now = DateTime.now();

      final city = settings.defaultCity;
      final engine = AstronomicalEngine(
        latitude: city.latitude,
        longitude: city.longitude,
        timeZone: city.timezone,
        elevation: city.elevation,
        asrJuristic: settings.asrMethod,
        is12HourFormat: settings.is12HourFormat,
      );

      final prayerKeys = [
        {'key': 'fajr', 'name_ur': 'فجر', 'name_en': 'Fajr', 'id': 101},
        {'key': 'dhuhr', 'name_ur': 'ظہر', 'name_en': 'Dhuhr', 'id': 102},
        {'key': 'asr', 'name_ur': 'عصر', 'name_en': 'Asr', 'id': 103},
        {'key': 'maghrib', 'name_ur': 'مغرب', 'name_en': 'Maghrib', 'id': 104},
        {'key': 'isha', 'name_ur': 'عشاء', 'name_en': 'Isha', 'id': 105},
      ];

      final soundId = settings.selectedAdhanTone; // 'makkah', 'madinah', 'aqsa', 'cairo', 'istanbul'

      // Pre-schedule rolling 30 days of alarms so alarm rings reliably even if app is not opened for weeks/months
      for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final dayTimes = engine.calculateDetailedTimes(targetDate);

        for (final p in prayerKeys) {
          final key = p['key'] as String;
          if (!(alarmService.prayerAlarms[key] ?? false)) continue;

          final targetHour = settings.getPrayerAlarmTargetHour(
            prayerKey: key,
            detailedTimes: dayTimes,
          );
          final int totalMins = (targetHour * 60).round();
          final int targetH = (totalMins ~/ 60) % 24;
          final int targetM = totalMins % 60;

          final scheduledDate = DateTime(targetDate.year, targetDate.month, targetDate.day, targetH, targetM, 0);
          if (scheduledDate.isBefore(now)) continue;

          final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
          final prayerNameUr = p['name_ur'] as String;
          final prayerNameEn = p['name_en'] as String;
          final notificationId = (p['id'] as int) + (dayOffset * 1000);

          final androidDetails = AndroidNotificationDetails(
            'adhan_channel_v4',
            'Adhan & Prayer Times Alarms',
            channelDescription:
                'High-priority authentic Adhan prayer alarms and reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(soundId),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            actions: [
              const AndroidNotificationAction(
                'stop_alarm',
                'الارم بند کریں',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          );

          final notificationDetails =
              NotificationDetails(android: androidDetails);

          await _notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: AppLocale.t(
              ur: 'وقتِ اذان و نماز: $prayerNameUr',
              en: 'Adhan & Prayer Time: $prayerNameEn',
            ),
            body: AppLocale.t(
              ur: 'حی علی الصلاۃ! $prayerNameUr کا وقت ہو چکا ہے۔ نماز قائم کیجیے۔',
              en: 'Hayya \'ala-s-Salah! It is time for $prayerNameEn prayer.',
            ),
            scheduledDate: tzDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
          );
        }

        // Schedule Tahajjud Alarm if enabled for this day
        if (settings.tahajjudAlarmEnabled) {
          final targetHour = settings.getPrayerAlarmTargetHour(
            prayerKey: 'tahajjud',
            detailedTimes: dayTimes,
          );
          final int totalMins = (targetHour * 60).round();
          final int targetH = (totalMins ~/ 60) % 24;
          final int targetM = totalMins % 60;

          final scheduledDate = DateTime(targetDate.year, targetDate.month, targetDate.day, targetH, targetM, 0);
          if (scheduledDate.isBefore(now)) continue;

          final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
          final tahajjudNotificationId = 100 + (dayOffset * 1000);
          final androidDetails = AndroidNotificationDetails(
            'tahajjud_channel_v4',
            'Tahajjud Alarms',
            channelDescription: 'Tahajjud prayer wakeup alarms',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(soundId),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            actions: [
              const AndroidNotificationAction(
                'stop_alarm',
                'الارم بند کریں',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          );

          final notificationDetails = NotificationDetails(android: androidDetails);

          await _notificationsPlugin.zonedSchedule(
            id: tahajjudNotificationId,
            title: AppLocale.t(
              ur: 'وقتِ نمازِ تہجد مبارک',
              en: 'Tahajjud Prayer Call',
            ),
            body: AppLocale.t(
              ur: 'صبحِ صادق سے ${settings.tahajjudMinutesBefore} منٹ قبل: تہجد کا مبارک وقت شروع ہو چکا ہے۔',
              en: '${settings.tahajjudMinutesBefore} minutes before dawn: Tahajjud prayer time has arrived.',
            ),
            scheduledDate: tzDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
          );
        }
      }
    } catch (e) {
      debugPrint('AlarmService: scheduleBackgroundPrayerAlarms error: $e');
    }
  }

  /// Synthesizes a high-fidelity multi-tone Islamic melodic chime WAV buffer
  static Uint8List _generateWavBytes(List<double> frequencies, double durationSec) {
    const int sampleRate = 22050;
    final int numSamples = (sampleRate * durationSec).toInt();
    final ByteData data = ByteData(44 + numSamples * 2);

    // RIFF header
    data.setUint8(0, 0x52); // R
    data.setUint8(1, 0x49); // I
    data.setUint8(2, 0x46); // F
    data.setUint8(3, 0x46); // F
    data.setUint32(4, 36 + numSamples * 2, Endian.little);
    data.setUint8(8, 0x57);  // W
    data.setUint8(9, 0x41);  // A
    data.setUint8(10, 0x56); // V
    data.setUint8(11, 0x45); // E

    // fmt chunk
    data.setUint8(12, 0x66); // f
    data.setUint8(13, 0x6D); // m
    data.setUint8(14, 0x74); // t
    data.setUint8(15, 0x20); // ' '
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);  // PCM
    data.setUint16(22, 1, Endian.little);  // Mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);

    // data chunk
    data.setUint8(36, 0x64); // d
    data.setUint8(37, 0x61); // a
    data.setUint8(38, 0x74); // t
    data.setUint8(39, 0x61); // a
    data.setUint32(40, numSamples * 2, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double progress = i / numSamples;
      double envelope = math.sin(math.pi * progress);
      double sample = 0;
      for (double freq in frequencies) {
        sample += math.sin(2 * math.pi * freq * t);
      }
      sample = (sample / frequencies.length) * envelope;
      int pcm = (sample * 30000).clamp(-32768, 32767).toInt();
      data.setInt16(44 + i * 2, pcm, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  /// Plays authentic Adhan from bundled offline assets with URL & chime fallbacks
  Future<void> playTone(String toneId) async {
    try {
      await stopTone();
      _player ??= AudioPlayer();
      _isPlaying = true;

      final tone = adhanTones.firstWhere((t) => t['id'] == toneId, orElse: () => adhanTones.first);
      final assetPath = tone['asset_path'] ?? 'audio/$toneId.mp3';

      // 1. PRIMARY & INSTANT: Play bundled offline assets directly (0 ms latency, no network)
      try {
        await _player?.play(AssetSource(assetPath));
        return;
      } catch (_) {
        try {
          await _player?.play(AssetSource('assets/$assetPath'));
          return;
        } catch (_) {}
      }

      // 2. Strict timeout on remote stream fallback so it NEVER freezes or stalls
      final audioUrl = tone['audio_url'];
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _player?.play(UrlSource(audioUrl)).timeout(const Duration(seconds: 2));
          return;
        } catch (_) {}
      }

      final fallbackUrl = tone['audio_fallback'];
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        try {
          await _player?.play(UrlSource(fallbackUrl)).timeout(const Duration(seconds: 2));
          return;
        } catch (_) {}
      }

      // 3. Fallback synthesis if hardware audio failure
      List<double> freqs;
      switch (toneId) {
        case 'madinah':
          freqs = [523.25, 659.25, 783.99, 1046.5];
          break;
        case 'aqsa':
          freqs = [392.0, 493.88, 587.33, 783.99];
          break;
        case 'istanbul':
          freqs = [349.23, 440.0, 523.25, 698.46];
          break;
        case 'cairo':
          freqs = [466.16, 587.33, 698.46, 932.33];
          break;
        case 'makkah':
        default:
          freqs = [440.0, 554.37, 659.25, 880.0];
          break;
      }

      final bytes = _generateWavBytes(freqs, 3.5);
      await _player?.play(BytesSource(bytes));
    } catch (_) {
      _isPlaying = false;
      onPlaybackFinished?.call();
    }
  }

  /// Stops audio playback
  Future<void> stopTone() async {
    try {
      if (_player != null) {
        await _player?.stop();
      }
    } catch (_) {}
    _isPlaying = false;
    onPlaybackFinished?.call();
  }

  /// Trigger alarm with continuous repeat reminder until turned off
  void triggerPrayerAlarm(BuildContext context, String prayerName) {
    playTone(selectedToneId);
    _showActiveAlarmNotification(prayerName);

    // Schedule repeat reminder if enabled and not acknowledged
    _snoozeTimer?.cancel();
    if (isRepeatReminderEnabled && snoozeIntervalMinutes > 0) {
      _snoozeTimer = Timer.periodic(Duration(minutes: snoozeIntervalMinutes), (timer) {
        playTone(selectedToneId);
        _showActiveAlarmNotification(prayerName);
      });
    }

    _showAlarmActiveDialog(context, prayerName);
  }

  /// Stop all active alarms, cancel pending reminders, and clear notifications
  void dismissAlarm() {
    stopTone();
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    try {
      _notificationsPlugin.cancel(id: 999);
      _notificationsPlugin.cancel(id: 100);
      _notificationsPlugin.cancel(id: 101);
      _notificationsPlugin.cancel(id: 102);
      _notificationsPlugin.cancel(id: 103);
      _notificationsPlugin.cancel(id: 104);
      _notificationsPlugin.cancel(id: 105);
    } catch (_) {}
  }

  /// Posts high-priority persistent heads-up notification with clear "الارم بند کریں" button
  static Future<void> _showActiveAlarmNotification(String prayerName) async {
    try {
      await initNotifications();
      const androidDetails = AndroidNotificationDetails(
        'adhan_live_alert_v4',
        'Live Prayer Alarm Notification',
        channelDescription: 'Active heads-up notification with one-tap Stop Alarm action',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false, // Tone is already playing through player
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        actions: [
          AndroidNotificationAction(
            'stop_alarm',
            'الارم بند کریں',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
      const details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        id: 999,
        title: AppLocale.t(
          ur: '⏰ الارم اذان و نماز: $prayerName',
          en: '⏰ Prayer Alarm: $prayerName',
        ),
        body: AppLocale.t(
          ur: 'حی علی الصلاۃ! $prayerName کا وقت ہو چکا ہے۔ الارم بند کرنے کے لیے نیچے بٹن دبائیں۔',
          en: 'Hayya \'ala-s-Salah! It is time for $prayerName. Tap below to stop alarm.',
        ),
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('AlarmService: _showActiveAlarmNotification error: $e');
    }
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      await channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      await channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  void _showAlarmActiveDialog(BuildContext context, String prayerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.alarm_on, color: Color(0xFFF59E0B), size: 30),
              const SizedBox(width: 10),
              Text(
                AppLocale.t(ur: 'وقتِ اذان و نماز', en: 'Prayer Call Alert'),
                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocale.t(
                  ur: '$prayerName کا وقت ہو چکا ہے۔',
                  en: 'Time for $prayerName prayer has arrived.',
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (isRepeatReminderEnabled && snoozeIntervalMinutes > 0)
                Text(
                  AppLocale.t(
                    ur: 'یاد دہانی فعال ہے: آف نہ کرنے پر ہر $snoozeIntervalMinutes منٹ بعد دوبارہ الارم بجے گا۔',
                    en: 'Repeat reminder active: Will ring every $snoozeIntervalMinutes mins until turned off.',
                  ),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                dismissAlarm();
                Navigator.pop(ctx);
                if (context.mounted) {
                  PostAdhanDuaDialog.show(context);
                }
              },
              icon: const Icon(Icons.alarm_off, color: Colors.white),
              label: Text(
                AppLocale.t(ur: 'الارم بند کریں', en: 'Turn Off Alarm'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Configuration dialog
  static void showAlarmDialog(BuildContext context, VoidCallback onSave) {
    final service = AlarmService();
    final settings = AppSettings();
    String tempTone = service.selectedToneId;
    Map<String, bool> tempAlarms = Map.from(service.prayerAlarms);
    int tempSnooze = service.snoozeIntervalMinutes;
    bool tempRepeat = service.isRepeatReminderEnabled;
    String tempTimingMode = settings.alarmTimingMode;
    int tempBeforeJamaatMins = settings.alarmBeforeJamaatMinutes;
    bool tempTahajjudEnabled = settings.tahajjudAlarmEnabled;
    int tempTahajjudMins = settings.tahajjudMinutesBefore;
    bool isLocalPlaying = false;
    String? playingToneId;

    final prayerKeys = [
      {'key': 'fajr', 'ur': 'فجر', 'en': 'Fajr'},
      {'key': 'dhuhr', 'ur': 'ظہر', 'en': 'Dhuhr'},
      {'key': 'asr', 'ur': 'عصر', 'en': 'Asr'},
      {'key': 'maghrib', 'ur': 'مغرب', 'en': 'Maghrib'},
      {'key': 'isha', 'ur': 'عشاء', 'en': 'Isha'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: AppLocale.textDirection,
          child: AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.border),
            ),
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text(
                  AppLocale.t(ur: 'اذان و الارم کی ترتیبات', en: 'Adhan & Alarm Settings'),
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 20),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocale.t(
                      ur: 'مسجد کی اذان منتخب کریں (سن کر سیٹ کریں):',
                      en: 'Select Mosque Adhan (Listen Before Setting):',
                    ),
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),

                  // Interactive Adhan Tone List with Individual Play/Preview Buttons
                  ...adhanTones.map((tone) {
                    final String tId = tone['id']!;
                    final bool isSelected = (tempTone == tId);
                    final bool isThisPlaying = (isLocalPlaying && playingToneId == tId);
                    final name = AppLocale.t(ur: tone['name_ur']!, en: tone['name_en']!);
                    final muazzin = AppLocale.t(ur: tone['muazzin_ur']!, en: tone['muazzin_en']!);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.15) : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : AppTheme.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : AppTheme.textSecondary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFF59E0B) : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          muazzin,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isThisPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                            color: isThisPlaying ? Colors.redAccent : const Color(0xFF10B981),
                            size: 32,
                          ),
                          tooltip: AppLocale.t(ur: 'اذان سنیں (آڈیو چیک کریں)', en: 'Preview Listen'),
                          onPressed: () async {
                            if (isThisPlaying) {
                              await service.stopTone();
                              if (ctx.mounted) {
                                setState(() {
                                  isLocalPlaying = false;
                                  playingToneId = null;
                                });
                              }
                            } else {
                              setState(() {
                                isLocalPlaying = true;
                                playingToneId = tId;
                                tempTone = tId;
                              });
                              service.onPlaybackFinished = () {
                                if (ctx.mounted) {
                                  setState(() {
                                    isLocalPlaying = false;
                                    playingToneId = null;
                                  });
                                }
                              };
                              await service.playTone(tId);
                            }
                          },
                        ),
                        onTap: () {
                          setState(() => tempTone = tId);
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  Divider(color: AppTheme.border),

                  // Timing Choice: At Start Time vs Before Jamaat Time
                  Text(
                    AppLocale.t(ur: 'الارم کا وقت (نماز یا جماعت کے وقت کے مطابق):', en: 'Alarm Timing (Start Time vs Before Jama\'at):'),
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  RadioListTile<String>(
                    value: 'START_TIME',
                    groupValue: tempTimingMode,
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocale.t(ur: 'نماز کا وقت شروع ہونے پر (ابتدائی وقت)', en: 'At Prayer Start Time'),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => tempTimingMode = val!),
                  ),
                  RadioListTile<String>(
                    value: 'BEFORE_JAMAAT',
                    groupValue: tempTimingMode,
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocale.t(ur: 'جماعت کے وقت سے پہلے (مسجد کی جماعت سے قبل)', en: 'Before Mosque Jama\'at Time'),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => tempTimingMode = val!),
                  ),
                  if (tempTimingMode == 'BEFORE_JAMAAT')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempBeforeJamaatMins,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceElevated,
                          style: TextStyle(color: AppTheme.textPrimary),
                          items: [
                            DropdownMenuItem(value: 5, child: Text(AppLocale.t(ur: 'جماعت سے 5 منٹ قبل الارم بولے', en: '5 Minutes before Jama\'at'))),
                            DropdownMenuItem(value: 10, child: Text(AppLocale.t(ur: 'جماعت سے 10 منٹ قبل الارم بولے (تجویز کردہ)', en: '10 Minutes before Jama\'at (Recommended)'))),
                            DropdownMenuItem(value: 15, child: Text(AppLocale.t(ur: 'جماعت سے 15 منٹ قبل الارم بولے', en: '15 Minutes before Jama\'at'))),
                            DropdownMenuItem(value: 20, child: Text(AppLocale.t(ur: 'جماعت سے 20 منٹ قبل الارم بولے', en: '20 Minutes before Jama\'at'))),
                            DropdownMenuItem(value: 30, child: Text(AppLocale.t(ur: 'جماعت سے 30 منٹ قبل الارم بولے', en: '30 Minutes before Jama\'at'))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => tempBeforeJamaatMins = val);
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  Divider(color: AppTheme.border),

                  // Repeat Reminder / Snooze Interval
                  Text(
                    AppLocale.t(
                      ur: 'دوبارہ یاد دہانی (نہ سننے کی صورت میں):',
                      en: 'Repeat Reminder (if not turned off):',
                    ),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    activeTrackColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocale.t(ur: 'بار بار یاد دہانی فعال رکھیں', en: 'Enable Repeated Snooze Alerts'),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    value: tempRepeat,
                    onChanged: (val) => setState(() => tempRepeat = val),
                  ),
                  if (tempRepeat)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempSnooze,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceElevated,
                          style: TextStyle(color: AppTheme.textPrimary),
                          items: [
                            DropdownMenuItem<int>(
                              value: 5,
                              child: Text(AppLocale.t(ur: 'ہر 5 منٹ بعد یاد دہانی', en: 'Every 5 Minutes')),
                            ),
                            DropdownMenuItem<int>(
                              value: 10,
                              child: Text(AppLocale.t(ur: 'ہر 10 منٹ بعد یاد دہانی', en: 'Every 10 Minutes')),
                            ),
                            DropdownMenuItem<int>(
                              value: 15,
                              child: Text(AppLocale.t(ur: 'ہر 15 منٹ بعد یاد دہانی', en: 'Every 15 Minutes')),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => tempSnooze = val);
                          },
                        ),
                      ),
                    ),

                  Divider(color: AppTheme.border),
                  Text(
                    AppLocale.t(ur: 'نمازوں کے الارم:', en: 'Individual Prayer Alarms:'),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...prayerKeys.map((p) {
                    final key = p['key']!;
                    final title = AppLocale.t(ur: p['ur']!, en: p['en']!);
                    return SwitchListTile(
                      activeTrackColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                      title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
                      value: tempAlarms[key] ?? true,
                      onChanged: (val) {
                        setState(() => tempAlarms[key] = val);
                      },
                    );
                  }),

                  const SizedBox(height: 8),
                  Divider(color: AppTheme.border),

                  // Tahajjud Alarm Section
                  Text(
                    AppLocale.t(ur: 'نمازِ تہجد الارم (صبحِ صادق سے قبل):', en: 'Tahajjud Alarm (Before Dawn):'),
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    activeTrackColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocale.t(ur: 'تہجد الارم فعال کریں', en: 'Enable Tahajjud Alarm'),
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      AppLocale.t(
                        ur: 'صبح صادق (فجر شروع) سے منتخب منٹ قبل بیدار کرے گا',
                        en: 'Wakes you up selected minutes before dawn / Fajr start',
                      ),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    value: tempTahajjudEnabled,
                    onChanged: (val) => setState(() => tempTahajjudEnabled = val),
                  ),
                  if (tempTahajjudEnabled) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.t(ur: 'کتنے منٹ قبل الارم بولے:', en: 'Minutes before Fajr start:'),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [20, 30, 40, 60].map((m) {
                        final bool isSel = (tempTahajjudMins == m);
                        final label = m == 60
                            ? (AppLocale.isUrdu ? '1 گھنٹہ' : '1 Hour')
                            : '$m ${AppLocale.t(ur: 'منٹ', en: 'min')}';
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: InkWell(
                              onTap: () {
                                setState(() => tempTahajjudMins = m);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF10B981) : (AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF10B981) : (AppTheme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    width: isSel ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : (AppTheme.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  service.onPlaybackFinished = null;
                  service.stopTone();
                  Navigator.pop(ctx);
                },
                child: Text(
                  AppLocale.t(ur: 'منسوخ', en: 'Cancel'),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  service.onPlaybackFinished = null;
                  service.stopTone();
                  service.selectedToneId = tempTone;
                  for (final entry in tempAlarms.entries) {
                    service.toggleAlarm(entry.key, entry.value);
                  }
                  service.snoozeIntervalMinutes = tempSnooze;
                  service.isRepeatReminderEnabled = tempRepeat;
                  settings.alarmTimingMode = tempTimingMode;
                  settings.alarmBeforeJamaatMinutes = tempBeforeJamaatMins;
                  settings.tahajjudAlarmEnabled = tempTahajjudEnabled;
                  settings.tahajjudMinutesBefore = tempTahajjudMins;
                  AlarmService.scheduleBackgroundPrayerAlarms();
                  Navigator.pop(ctx);
                  onSave();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocale.t(
                          ur: 'ترتیبات محفوظ ہوگئیں! منتخب اذان و الارم کامیابی کے ساتھ سیٹ ہو چکے ہیں۔',
                          en: 'Settings saved! Selected Adhan and alarm timings configured successfully.',
                        ),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                child: Text(
                  AppLocale.t(ur: 'محفوظ کریں', en: 'Save'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
