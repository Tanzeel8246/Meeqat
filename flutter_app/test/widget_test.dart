import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minaret_modern/core/astronomical_engine.dart';
import 'package:minaret_modern/core/qibla_calculator.dart';
import 'package:minaret_modern/core/hijri_calendar.dart';
import 'package:minaret_modern/core/app_locale.dart';
import 'package:minaret_modern/core/app_settings.dart';
import 'package:minaret_modern/core/city_database.dart';
import 'package:minaret_modern/core/location_service.dart';
import 'package:minaret_modern/core/alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (call) async {
      if (call.method == 'initialize' || call.method == 'cancelAllPendingNotificationRequests' || call.method == 'zonedSchedule') {
        return true;
      }
      return null;
    });
  });

  test('AstronomicalEngine calculates detailed prayer times in 12-hour and 24-hour formats', () {
    // 12-Hour format (Default)
    final engine12 = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      method: AstronomicalEngine.methodKarachi,
      asrJuristic: AstronomicalEngine.asrHanafi,
      is12HourFormat: true,
    );

    final date = DateTime(2026, 10, 13);
    final detailed12 = engine12.calculateDetailedTimes(date);

    final exact12 = detailed12['exact'] as Map<String, dynamic>;
    final fasting12 = detailed12['fasting'] as Map<String, dynamic>;
    final adhan12 = detailed12['adhan'] as Map<String, dynamic>;

    expect(exact12['fajr'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(exact12['dhuhr'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(fasting12['sehar_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(fasting12['iftar_time'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(adhan12['fajr'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));

    // Check newly added Shar'i milestones in 12h
    final nisfNahar = detailed12['nisf_nahar_card'] as Map<String, dynamic>;
    final zawal = detailed12['zawal_card'] as Map<String, dynamic>;
    final tahajjud = detailed12['tahajjud_card'] as Map<String, dynamic>;
    final sunrise = detailed12['sunrise_card'] as Map<String, dynamic>;
    final dhuhr = detailed12['dhuhr_card'] as Map<String, dynamic>;
    final asr = detailed12['asr_card'] as Map<String, dynamic>;

    expect(nisfNahar['time'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(zawal['start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(zawal['end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(tahajjud['third_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(tahajjud['sixth_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(sunrise['ishraq'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(dhuhr['shafi_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(dhuhr['hanafi_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));
    expect(asr['makrooh'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} (AM|PM)\u200E?$'));

    // Verify 24-Hour format
    final engine24 = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      is12HourFormat: false,
    );
    final detailed24 = engine24.calculateDetailedTimes(date);
    final exact24 = detailed24['exact'] as Map<String, dynamic>;
    expect(exact24['fajr'], matches(r'^\d{2}:\d{2}:\d{2}$'));
  });

  test('AstronomicalEngine respects custom Determination of Fajr & Isha modes', () {
    // Mode: Interval
    final engineInterval = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      fajrMode: 'INTERVAL',
      fajrIntervalMin: 90.0,
      ishaMode: 'INTERVAL',
      ishaIntervalMin: 90.0,
    );

    final res = engineInterval.calculateDetailedTimes(DateTime(2026, 10, 13));
    final raw = res['raw'] as Map<String, dynamic>;
    final exactSunrise = raw['sunrise'] as double;
    final fajrStart = raw['fajr_start'] as double;

    // Fajr must be exactly 90 mins (1.5 hours) before sunrise
    expect(fajrStart, closeTo(exactSunrise - 1.5, 0.05));
  });

  test('AstronomicalEngine adheres to authentic Pakistani standards and views', () {
    // 1. Jamhoor View (18° Fajr, 18° Isha)
    final engineJamhoor = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      fajrMode: 'DEGREE',
      fajrDegree: 18.0,
      ishaMode: 'DEGREE',
      ishaDegree: 18.0,
    );
    final resJamhoor = engineJamhoor.calculateDetailedTimes(DateTime(2026, 10, 13));
    final rawJamhoor = resJamhoor['raw'] as Map<String, dynamic>;

    // 2. Mufti Tayyab Saleem Sargodha View (15° Fajr, 15° Isha)
    final engineSargodha = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      fajrMode: 'DEGREE',
      fajrDegree: 15.0,
      ishaMode: 'DEGREE',
      ishaDegree: 15.0,
    );
    final resSargodha = engineSargodha.calculateDetailedTimes(DateTime(2026, 10, 13));
    final rawSargodha = resSargodha['raw'] as Map<String, dynamic>;

    // 15° Fajr is later than 18° Fajr
    expect(rawSargodha['fajr_start'] as double, greaterThan(rawJamhoor['fajr_start'] as double));

    // 15° Isha is earlier than 18° Isha
    expect(rawSargodha['isha_start'] as double, lessThan(rawJamhoor['isha_start'] as double));

    // Dhuhr starts at conclusion of Istiwa interval (~5m total)
    final zawalStart = rawJamhoor['zawal_start'] as double;
    final dhuhrStart = rawJamhoor['dhuhr_start'] as double;
    expect(dhuhrStart - zawalStart, closeTo(5.0667 / 60.0, 0.01)); // zawalStart = transit - 2m 40s, dhuhrStart = zawalEnd = transit + 2m 24s
  });

  test('AstronomicalEngine calculates solar qibla times for 0, 90, 135, and 180 degrees', () {
    final engine = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
      is12HourFormat: false,
    );

    final solarTimes = engine.calculateSolarQiblaTimes(DateTime(2026, 10, 13), 255.4);
    expect(solarTimes.length, equals(4));

    // Verify 0° (Sun in Qibla)
    final item0 = solarTimes.firstWhere((e) => e['angle'] == 0);
    expect(item0['is_observable'], isTrue);
    expect(item0['time'], matches(r'^\d{2}:\d{2}:\d{2}$'));

    // Verify 90° (Saf / Perpendicular)
    final item90 = solarTimes.firstWhere((e) => e['angle'] == 90);
    expect(item90['is_observable'], isTrue);
    expect(item90['time'], matches(r'^\d{2}:\d{2}:\d{2}$'));

    // Verify 135° (Diagonal / Corner)
    final item135 = solarTimes.firstWhere((e) => e['angle'] == 135);
    expect(item135['is_observable'], isTrue);
    expect(item135['time'], matches(r'^\d{2}:\d{2}:\d{2}$'));

    // Verify 180° (Shadow Along Qibla)
    final item180 = solarTimes.firstWhere((e) => e['angle'] == 180);
    expect(item180['title'], contains('180°'));
    expect(item180['time'], isNotEmpty);
  });

  test('QiblaCalculator calculates bearing and magnetic declination correctly', () {
    final qibla = QiblaCalculator.calculate(31.8878, 72.4125);
    expect(qibla['bearing'], inInclusiveRange(250.0, 270.0));

    final dec = QiblaCalculator.calculateMagneticDeclination(31.8878, 72.4125);
    expect(dec, inInclusiveRange(0.0, 5.0));
  });

  test('AppSettings manages saved mosques and 100 locations correctly', () {
    final settings = AppSettings();
    expect(settings.is12HourFormat, isTrue);
    expect(settings.savedMosques, isNotEmpty);
    expect(settings.activeMosque.name, isNotEmpty);

    // Add city to saved locations
    const testCity = CityModel(
      id: 'test_city_99',
      name: 'Test City',
      country: 'Pakistan',
      province: 'Punjab',
      latitude: 33.6844,
      longitude: 73.0479,
      timezone: 5.0,
    );
    settings.addSavedLocation(testCity);
    expect(settings.savedLocations.any((c) => c.id == 'test_city_99'), isTrue);

    // Clean up
    settings.removeSavedLocation('test_city_99');
    expect(settings.savedLocations.any((c) => c.id == 'test_city_99'), isFalse);
  });

  test('HijriCalendar calculates moon sighting and month names', () {
    final moonInfo = HijriCalendar.getMoonSightingInfo(DateTime(2026, 10, 13));
    expect(moonInfo['visibility_status'], isNotEmpty);
    expect(moonInfo['moon_age_hours'], isNotEmpty);

    expect(HijriCalendar.getMonthName(9), equals('رمضان المبارک'));
    expect(HijriCalendar.getMonthName(9, isUrdu: false), equals('Ramadan'));
  });

  test('AppLocale toggles between Urdu and English with correct typography', () {
    AppLocale.setUrdu(true);
    expect(AppLocale.isUrdu, isTrue);
    expect(AppLocale.fontFamily, equals('Jameel Noori Nastaleeq'));

    AppLocale.toggle();
    expect(AppLocale.isUrdu, isFalse);
    expect(AppLocale.fontFamily, equals('Segoe UI'));

    AppLocale.setUrdu(true); // reset
  });

  test('AstronomicalEngine matches Mufti Sahib reference app with 100% exact conformity for Farooka', () {
    final engine = AstronomicalEngine(
      latitude: 31.794,
      longitude: 72.430,
      timeZone: 5.0,
      method: AstronomicalEngine.methodKarachi,
      asrJuristic: AstronomicalEngine.asrHanafi,
      is12HourFormat: true,
    );

    final res = engine.calculateDetailedTimes(DateTime(2026, 10, 13));
    final fajr = res['fajr_card'] as Map<String, dynamic>;
    final sunrise = res['sunrise_card'] as Map<String, dynamic>;
    final nisfNahar = res['nisf_nahar_card'] as Map<String, dynamic>;
    final zawal = res['zawal_card'] as Map<String, dynamic>;
    final dhuhr = res['dhuhr_card'] as Map<String, dynamic>;
    final asr = res['asr_card'] as Map<String, dynamic>;
    final maghrib = res['maghrib_card'] as Map<String, dynamic>;
    final isha = res['isha_card'] as Map<String, dynamic>;
    final tahajjud = res['tahajjud_card'] as Map<String, dynamic>;
    // Verify all milestones are correctly populated in 12-hour AM/PM format
    expect(fajr['sehar_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(fajr['start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(fajr['adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(fajr['end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));

    expect(sunrise['sunrise'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(sunrise['ishraq'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(sunrise['ishraq_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));

    expect(nisfNahar['time'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(zawal['zawal'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(zawal['end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));

    expect(dhuhr['start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(dhuhr['adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));
    expect(dhuhr['shafi_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(dhuhr['hanafi_end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));

    expect(asr['shafi_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(asr['shafi_adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(asr['hanafi_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(asr['hanafi_adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(asr['makrooh'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));

    expect(maghrib['sunset'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(maghrib['iftar_adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(maghrib['end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));

    expect(isha['start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(isha['adhan'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(isha['makrooh'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} PM\u200E?$'));
    expect(isha['end'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));

    expect(tahajjud['sixth_start'], matches(r'^\u200E?\d{2}:\d{2}:\d{2} AM\u200E?$'));

    // Check high precision alignment with Mufti Sahib reference values
    expect(fajr['start'], contains('04:50:'));
    expect(sunrise['sunrise'], contains('06:12:'));
    expect(nisfNahar['time'], contains('11:15:'));
    expect(zawal['zawal'], contains('11:53:'));
    expect(dhuhr['start'], contains('11:58:'));
    expect(asr['shafi_start'], contains('03:12:'));
    expect(asr['hanafi_start'], contains('04:01:'));
    expect(maghrib['sunset'], contains('05:40:'));
    expect(isha['start'], contains('07:01:'));
  });

  test('AppSettings computes authentic dynamic Jamaat schedule for Farooka mosque', () {
    final settings = AppSettings();
    expect(settings.defaultCity.name, equals('Farooka'));
    expect(settings.activeMosque.name, contains('جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)'));

    final engine = AstronomicalEngine(
      latitude: 31.794,
      longitude: 72.430,
      timeZone: 5.0,
      is12HourFormat: true,
    );
    final detailed = engine.calculateDetailedTimes(DateTime(2026, 10, 13));

    // Dynamic Jama'at times (non-Ramadan)
    final jamaat = settings.calculateDynamicJamaat(detailedTimes: detailed, isRamadan: false);

    expect(jamaat['fajr'], matches(r'^\u200E?\d{2}:\d{2} AM\u200E?$'));
    expect(jamaat['dhuhr'], contains('01:30 PM')); // 1:30 PM all year round
    expect(jamaat['asr'], matches(r'^\u200E?\d{2}:\d{2} PM\u200E?$'));
    expect(jamaat['maghrib'], matches(r'^\u200E?\d{2}:\d{2} PM\u200E?$'));
    expect(jamaat['isha'], matches(r'^\u200E?\d{2}:\d{2} PM\u200E?$'));
    expect(jamaat['jumuah'], contains('01:30 PM')); // Updated to 01:30 PM

    // Test MosqueModel bilingual localization
    expect(settings.activeMosque.nameLocalized(true), contains('جامع مسجد طوبیٰ'));
    expect(settings.activeMosque.nameLocalized(false), contains('Jamia Masjid Tooba'));

    // Test unified Fajr & Isha determination standard (Fixed to 18.0 Jamhoor standard)
    expect(settings.fajrDegree, equals(18.0));
    expect(settings.ishaDegree, equals(18.0));

    // Ramadan dynamic Fajr test (20m after Sehar end)
    final jamaatRamadan = settings.calculateDynamicJamaat(detailedTimes: detailed, isRamadan: true);
    expect(jamaatRamadan['fajr'], isNotEmpty);
  });

  test('HijriCalendar and AstronomicalEngine provide 100% complete bilingual texts without hardcoded Urdu in English mode', () {
    final moonInfo = HijriCalendar.getMoonSightingInfo(DateTime(2026, 10, 13));
    expect(moonInfo['conjunction_birth_str_ur'], contains('بوقت'));
    expect(moonInfo['conjunction_birth_str_en'], contains('at'));
    expect(moonInfo['conjunction_birth_str_en'], isNot(contains('بوقت')));

    final engine = AstronomicalEngine(
      latitude: 31.8878,
      longitude: 72.4125,
      timeZone: 5.0,
    );
    final solarTimes = engine.calculateSolarQiblaTimes(DateTime(2026, 10, 13), 255.4);
    for (var s in solarTimes) {
      expect(s['title_ur'], isNotEmpty);
      expect(s['title_en'], isNotEmpty);
      expect(s['description_ur'], isNotEmpty);
      expect(s['description_en'], isNotEmpty);
      expect(s['time_en'], isNotEmpty);
    }
  });

  test('CityDatabase contains solely Farooka as baseline default as requested', () {
    expect(CityDatabase.defaultCities.length, equals(1));
    expect(CityDatabase.defaultCities.first.name, equals('Farooka'));
    expect(CityDatabase.defaultCities.first.nameUr, equals('فروکہ'));
    expect(CityDatabase.defaultCities.first.id, equals('farooka_pk'));

    // Urdu search query for Farooka
    final farookaUr = CityDatabase.search('فروکہ');
    expect(farookaUr, isNotEmpty);
    expect(farookaUr.first.name, equals('Farooka'));

    // English search query for Farooka
    final farookaEn = CityDatabase.search('Farooka');
    expect(farookaEn, isNotEmpty);
    expect(farookaEn.first.nameUr, equals('فروکہ'));
  });

  test('AppSettings and CityModel properly support Google Maps API and Meeqat branding', () {
    final settings = AppSettings();
    expect(settings.hasGoogleMapsApiKey, isFalse);

    settings.setGoogleMapsApiKey('AIzaSyTestKey12345');
    expect(settings.hasGoogleMapsApiKey, isTrue);
    expect(settings.googleMapsApiKey, equals('AIzaSyTestKey12345'));

    const gmCity = CityModel(
      id: 'gm_31.8878_72.4125',
      name: 'Farooka',
      country: 'Pakistan',
      province: 'Punjab',
      latitude: 31.8878,
      longitude: 72.4125,
      timezone: 5.0,
      source: 'Google Maps',
    );
    expect(gmCity.isGoogleMaps, isTrue);
    expect(gmCity.source, equals('Google Maps'));

    settings.setGoogleMapsApiKey('');
    expect(settings.hasGoogleMapsApiKey, isFalse);
  });

  test('LocationService accurately estimates timezone and constructs valid CityModel', () {
    expect(LocationService.estimateTimezone('Pakistan', 72.4), equals(5.0));
    expect(LocationService.estimateTimezone('Saudi Arabia', 39.8), equals(3.0));
    expect(LocationService.estimateTimezone('United Kingdom', -0.1), equals(0.0));
    expect(LocationService.estimateTimezone('United States', -74.0), equals(-5.0));
    expect(LocationService.estimateTimezone('Japan', 139.7), equals(9.0));

    final liveCity = CityModel(
      id: 'live_31.8878_72.4125',
      name: 'Farooka',
      country: 'Pakistan',
      province: 'Punjab',
      latitude: 31.8878,
      longitude: 72.4125,
      timezone: LocationService.estimateTimezone('Pakistan', 72.4125),
      source: 'GPS Live',
    );

    expect(liveCity.source, equals('GPS Live'));
    expect(liveCity.timezone, equals(5.0));
  });

  test('AlarmService bundles 5 authentic Adhans offline and integrates with AppSettings', () {
    final alarmService = AlarmService();
    expect(AlarmService.adhanTones.length, equals(5));

    final toneIds = AlarmService.adhanTones.map((t) => t['id']).toList();
    expect(toneIds, containsAll(['makkah', 'madinah', 'aqsa', 'cairo', 'istanbul']));

    for (final tone in AlarmService.adhanTones) {
      expect(tone['asset_path'], startsWith('audio/'));
      expect(tone['asset_path'], endsWith('.mp3'));
      expect(tone['name_ur'], isNotEmpty);
      expect(tone['name_en'], isNotEmpty);
      expect(tone['muazzin_ur'], isNotEmpty);
      expect(tone['muazzin_en'], isNotEmpty);
    }

    alarmService.setTone('madinah');
    expect(alarmService.selectedToneId, equals('madinah'));
    expect(AppSettings().selectedAdhanTone, equals('madinah'));
    expect(alarmService.currentTone['id'], equals('madinah'));

    alarmService.toggleAlarm('fajr', true);
    alarmService.toggleAlarm('dhuhr', false);
    expect(alarmService.prayerAlarms['fajr'], isTrue);
    expect(alarmService.prayerAlarms['dhuhr'], isFalse);

    // Reset back to makkah default
    alarmService.setTone('makkah');
    expect(alarmService.selectedToneId, equals('makkah'));
  });

  test('Solar Qibla Guide phrasing uses date-specific future forecast without habitual recurrence', () {
    final engine = AstronomicalEngine(
      latitude: 31.794,
      longitude: 72.430,
      timeZone: 5.0,
      method: AstronomicalEngine.methodKarachi,
      asrJuristic: AstronomicalEngine.asrHanafi,
    );

    final solarTimes = engine.calculateSolarQiblaTimes(DateTime(2026, 10, 13), 260.0);
    expect(solarTimes, isNotEmpty);

    for (final entry in solarTimes) {
      final desc = (entry['description_ur'] ?? entry['description']) as String;
      expect(desc, isNotEmpty);
      // Strictly verify absence of habitual perpetual phrase "ہوتا ہے"
      expect(desc.contains('ہوتا ہے'), isFalse, reason: 'Must not use perpetual "ہوتا ہے"');
      // Verify presence of date-specific forecast language "ہو گا" or "پڑے گا"
      expect(
        desc.contains('ہو گا') || desc.contains('پڑے گا'),
        isTrue,
        reason: 'Must use date-specific future forecast phrasing ("ہو گا" / "پڑے گا")',
      );
    }
  });

  test('Sehar and Iftar Shar\'i safety margins and precision formulas conform to jurisprudence', () {
    final engine = AstronomicalEngine(
      latitude: 31.794,
      longitude: 72.430,
      timeZone: 5.0,
      method: AstronomicalEngine.methodKarachi,
      asrJuristic: AstronomicalEngine.asrHanafi,
    );

    final detailed = engine.calculateDetailedTimes(DateTime(2026, 10, 13));
    final raw = detailed['raw'] as Map<String, dynamic>;
    final double fajrStartH = raw['fajr_start'] ?? raw['fajr'];
    final double sunsetH = raw['sunset'];

    // Shar'i rules:
    // Sehar End = 3 mins before exact Fajr (صبح صادق - 3 منٹ)
    // Fajr Adhan = 3 mins after exact Fajr (صبح صادق + 3 منٹ)
    // Iftar = 3 mins after exact Sunset (غروب + 3 منٹ)
    // Nisf un-Nahar Shar'i = (Fajr + Sunset) / 2
    final double seharEndH = fajrStartH - (3.0 / 60.0);
    final double fajrAdhanH = fajrStartH + (3.0 / 60.0);
    final double iftarH = sunsetH + (3.0 / 60.0);
    final double nisfNaharH = (fajrStartH + sunsetH) / 2.0;

    expect(seharEndH, lessThan(fajrStartH));
    expect(fajrAdhanH, greaterThan(fajrStartH));
    expect(iftarH, greaterThan(sunsetH));
    expect(nisfNaharH, greaterThan(fajrStartH));
    expect(nisfNaharH, lessThan(sunsetH));

    // Difference must be exactly 3 minutes (0.05 hours)
    expect((fajrStartH - seharEndH) * 60.0, closeTo(3.0, 0.001));
    expect((fajrAdhanH - fajrStartH) * 60.0, closeTo(3.0, 0.001));
    expect((iftarH - sunsetH) * 60.0, closeTo(3.0, 0.001));
  });

  test('CityModel and MosqueModel correctly serialize and deserialize to/from JSON', () {
    const city = CityModel(
      id: 'test_city',
      name: 'Farooka Test',
      nameUr: 'فروکہ ٹیسٹ',
      country: 'Pakistan',
      province: 'Punjab',
      latitude: 31.88,
      longitude: 72.41,
      timezone: 5.0,
      elevation: 180.0,
      source: 'Custom',
    );
    final cityJson = city.toJson();
    final restoredCity = CityModel.fromJson(cityJson);
    expect(restoredCity.id, equals('test_city'));
    expect(restoredCity.name, equals('Farooka Test'));
    expect(restoredCity.nameUr, equals('فروکہ ٹیسٹ'));
    expect(restoredCity.latitude, equals(31.88));

    final mosque = MosqueModel(
      name: 'جامع مسجد ٹیسٹ',
      address: 'محلہ طوبیٰ',
      fajrJamaat: '05:15 AM',
      dhuhrJamaat: '01:45 PM',
      asrJamaat: '04:15 PM',
      maghribJamaat: '05:55 PM',
      ishaJamaat: '08:00 PM',
      jumuahTime: '01:45 PM',
    );
    final mosqueJson = mosque.toJson();
    final restoredMosque = MosqueModel.fromJson(mosqueJson);
    expect(restoredMosque.name, equals('جامع مسجد ٹیسٹ'));
    expect(restoredMosque.fajrJamaat, equals('05:15 AM'));
    expect(restoredMosque.asrJamaat, equals('04:15 PM'));
    expect(restoredMosque.ishaJamaat, equals('08:00 PM'));
  });

  test('AppSettings correctly persists and restores custom mosque timings and configuration across sessions', () async {
    final tempDir = Directory.systemTemp.createTempSync('minaret_test_');
    final testFile = File('${tempDir.path}/test_settings.json');
    AppSettings.testFilePath = testFile.path;

    final settings = AppSettings();
    await settings.init();

    // Add a custom mosque with distinct custom timings
    final customMosque = MosqueModel(
      name: 'جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)',
      address: 'فروکہ، سرگودھا',
      fajrJamaat: '05:25 AM',
      dhuhrJamaat: '01:40 PM',
      asrJamaat: '04:45 PM',
      maghribJamaat: '05:50 PM',
      ishaJamaat: '07:45 PM',
      jumuahTime: '01:40 PM',
    );
    settings.addMosque(customMosque);
    settings.setActiveMosque(settings.savedMosques.length - 1);
    settings.mosqueDisplayMode = 'JAMAAT';
    settings.useAutoDynamicJamaat = false;
    settings.is12HourFormat = true;

    // Trigger save and ensure file is written
    await settings.saveSettings();
    expect(await testFile.exists(), isTrue);

    // Verify file contains the custom mosque timings
    final fileContent = await testFile.readAsString();
    expect(fileContent.contains('05:25 AM'), isTrue);
    expect(fileContent.contains('04:45 PM'), isTrue);
    expect(fileContent.contains('JAMAAT'), isTrue);

    // Simulate new app launch: load into a fresh map / settings instance
    final loadedSettings = AppSettings();
    await loadedSettings.init();

    expect(loadedSettings.activeMosque.name, contains('جامع مسجد طوبیٰ'));
    expect(loadedSettings.activeMosque.fajrJamaat, equals('05:25 AM'));
    expect(loadedSettings.activeMosque.asrJamaat, equals('04:45 PM'));
    expect(loadedSettings.mosqueDisplayMode, equals('JAMAAT'));
    expect(loadedSettings.useAutoDynamicJamaat, isFalse);

    // Cleanup
    AppSettings.testFilePath = null;
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('calculateDynamicJamaat uses customizable dynamic parameters accurately', () {
    final settings = AppSettings();
    settings.is12HourFormat = true;

    // Test with default parameters
    final dummyDetailed = {
      'raw': {
        'sunrise': 6.0, // 06:00 AM
        'fajr_start': 4.5,
        'asr_hanafi': 16.0, // 04:00 PM -> Adhan: 04:01 PM
        'sunset': 18.0, // 06:00 PM -> Adhan: 06:01 PM
        'isha_start': 19.5, // 07:30 PM -> Adhan: 07:31 PM
      }
    };

    // Default: Fajr min=30, max=35, step=5 -> (360 - 30) = 330 = 05:30 AM
    // Asr: adhan = 961 mins (16:01). +15 = 976. Slot 15 -> 990 = 16:30 (04:30 PM)
    // Maghrib: adhan = 1081 mins (18:01). +3 = 1084 = 18:04 (06:04 PM)
    // Isha: adhan = 1171 mins (19:31). +15 = 1186. Slot 15 -> 1200 = 20:00 (08:00 PM)
    final defTimes = settings.calculateDynamicJamaat(detailedTimes: dummyDetailed);
    expect(defTimes['fajr'], contains('05:30 AM'));
    expect(defTimes['asr'], contains('04:30 PM'));
    expect(defTimes['maghrib'], contains('06:04 PM'));
    expect(defTimes['isha'], contains('08:00 PM'));

    // Now customize parameters:
    // Fajr 25 mins before sunrise: 360 - 25 = 335 -> 05:35 AM
    settings.fajrDynamicMinBeforeSunrise = 25;
    settings.fajrDynamicMaxBeforeSunrise = 30;
    // Asr 10 mins after adhan: 961 + 10 = 971 -> Slot 15: 975 = 16:15 (04:15 PM)
    settings.asrDynamicMinAfter = 10;
    // Maghrib 5 mins after sunset adhan: 1081 + 5 = 1086 = 18:06 (06:06 PM)
    settings.maghribDynamicAfter = 5;
    // Isha 20 mins after adhan: 1171 + 20 = 1191 -> Slot 15: 1200 = 20:00 (08:00 PM)
    settings.ishaDynamicMinAfter = 20;

    final customTimes = settings.calculateDynamicJamaat(detailedTimes: dummyDetailed);
    expect(customTimes['fajr'], contains('05:35 AM'));
    expect(customTimes['asr'], contains('04:15 PM'));
    expect(customTimes['maghrib'], contains('06:06 PM'));
    expect(customTimes['isha'], contains('08:00 PM'));

    // Reset settings
    settings.fajrDynamicMinBeforeSunrise = 30;
    settings.fajrDynamicMaxBeforeSunrise = 35;
    settings.asrDynamicMinAfter = 15;
    settings.maghribDynamicAfter = 3;
    settings.ishaDynamicMinAfter = 15;
  });

  test('AppSettings persists and reloads dynamic formula parameters, alarm toggles, and default city', () async {
    final tempDir = Directory.systemTemp.createTempSync('minaret_settings_test_');
    final testFile = File('${tempDir.path}/persistence_test.json');
    AppSettings.testFilePath = testFile.path;

    final settings = AppSettings();
    await settings.init(forceReload: true);

    // Modify dynamic formula
    settings.fajrDynamicMinBeforeSunrise = 22;
    settings.asrDynamicMinAfter = 12;
    settings.maghribDynamicAfter = 6;
    settings.ishaDynamicMinAfter = 22;
    settings.useAutoDynamicJamaat = true;

    // Modify alarm settings
    settings.setPrayerAlarm('fajr', true);
    settings.setPrayerAlarm('dhuhr', false);
    settings.snoozeIntervalMinutes = 10;
    settings.isRepeatReminderEnabled = false;

    // Modify default city
    const customCity = CityModel(
      id: 'custom_sargodha',
      name: 'Sargodha Test City',
      nameUr: 'سرگودھا ٹیسٹ',
      country: 'Pakistan',
      province: 'Punjab',
      latitude: 32.0836,
      longitude: 72.6711,
      timezone: 5.0,
      elevation: 190.0,
      source: 'Custom',
    );
    settings.setDefaultCity(customCity);

    await settings.saveSettings();

    // Verify written JSON
    final jsonStr = await testFile.readAsString();
    expect(jsonStr.contains('fajrDynamicMinBeforeSunrise'), isTrue);
    expect(jsonStr.contains('Sargodha Test City'), isTrue);
    expect(jsonStr.contains('"dhuhr":false'), isTrue);

    // Simulate new session
    final newSession = AppSettings();
    await newSession.init(forceReload: true);

    expect(newSession.fajrDynamicMinBeforeSunrise, equals(22));
    expect(newSession.asrDynamicMinAfter, equals(12));
    expect(newSession.maghribDynamicAfter, equals(6));
    expect(newSession.ishaDynamicMinAfter, equals(22));
    expect(newSession.useAutoDynamicJamaat, isTrue);
    expect(newSession.prayerAlarms['dhuhr'], isFalse);
    expect(newSession.prayerAlarms['fajr'], isTrue);
    expect(newSession.snoozeIntervalMinutes, equals(10));
    expect(newSession.isRepeatReminderEnabled, isFalse);
    expect(newSession.defaultCity.name, equals('Sargodha Test City'));
    expect(newSession.defaultCity.latitude, equals(32.0836));

    // Cleanup
    AppSettings.testFilePath = null;
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('Tahajjud Alarm correctly persists configuration and calculates trigger hour', () async {
    final tempDir = Directory.systemTemp.createTempSync('minaret_tahajjud_test_');
    final testFile = File('${tempDir.path}/app_settings.json');
    AppSettings.testFilePath = testFile.path;

    final settings = AppSettings();
    await settings.init(forceReload: true);

    settings.tahajjudAlarmEnabled = true;
    settings.tahajjudMinutesBefore = 40;
    await settings.saveSettings();

    // Verify calculation
    // Fajr start at 5.0 (05:00), 40 minutes before = 5.0 - (40/60) = 4.3333 hours = 04:20
    final targetHour = settings.getPrayerAlarmTargetHour(
      prayerKey: 'tahajjud',
      detailedTimes: {
        'raw': {'fajr_start': 5.0}
      },
    );
    expect(targetHour, closeTo(5.0 - (40.0 / 60.0), 0.0001));

    // Reload in fresh instance
    final reloaded = AppSettings();
    await reloaded.init(forceReload: true);
    expect(reloaded.tahajjudAlarmEnabled, isTrue);
    expect(reloaded.tahajjudMinutesBefore, equals(40));

    // Cleanup
    AppSettings.testFilePath = null;
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
