import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/city_database.dart';
import '../core/app_locale.dart';
import '../core/app_settings.dart';
import '../core/app_theme.dart';
import '../core/astronomical_engine.dart';
import '../core/hijri_calendar.dart';
import '../widgets/minaret_bottom_nav.dart';

class MosqueDisplayScreen extends StatefulWidget {
  final CityModel city;
  final Map<String, String> prayerTimes;
  final String hijriDate;
  final Map<String, dynamic>? detailedTimes;

  const MosqueDisplayScreen({
    super.key,
    required this.city,
    required this.prayerTimes,
    required this.hijriDate,
    this.detailedTimes,
  });

  @override
  State<MosqueDisplayScreen> createState() => _MosqueDisplayScreenState();
}

class _MosqueDisplayScreenState extends State<MosqueDisplayScreen> {
  late Timer _clockTimer;
  DateTime _time = DateTime.now();
  final AppSettings _settings = AppSettings();

  late Map<String, dynamic> _activeDetailedTimes;
  late Map<String, String> _activePrayerTimes;
  late String _activeHijriDate;

  void _ensureTimes() {
    final bool hasValidTimes = widget.prayerTimes.values.any((v) => v != '--' && v.isNotEmpty);
    if (widget.detailedTimes != null && widget.detailedTimes!.isNotEmpty && hasValidTimes) {
      _activeDetailedTimes = widget.detailedTimes!;
      _activePrayerTimes = Map<String, String>.from(widget.prayerTimes);
      _activeHijriDate = widget.hijriDate.isNotEmpty ? widget.hijriDate : _computeHijri();
    } else {
      _computeTimesFromAstronomicalEngine();
    }
  }

  void _computeTimesFromAstronomicalEngine() {
    final now = DateTime.now();
    final engine = AstronomicalEngine(
      latitude: widget.city.latitude,
      longitude: widget.city.longitude,
      timeZone: widget.city.timezone,
      asrJuristic: _settings.asrMethod,
      elevation: widget.city.elevation,
      fajrMode: _settings.fajrMode,
      fajrDegree: _settings.fajrDegree,
      fajrIntervalMin: _settings.fajrIntervalMin,
      ishaMode: _settings.ishaMode,
      ishaDegree: _settings.ishaDegree,
      ishaIntervalMin: _settings.ishaIntervalMin,
      is12HourFormat: _settings.is12HourFormat,
    );
    _activeDetailedTimes = engine.calculateDetailedTimes(now);
    final exact = _activeDetailedTimes['exact'] as Map<String, dynamic>? ?? {};
    _activePrayerTimes = {
      'fajr': exact['fajr']?.toString() ?? '--:--',
      'dhuhr': exact['dhuhr']?.toString() ?? '--:--',
      'asr': exact['asr']?.toString() ?? '--:--',
      'maghrib': exact['maghrib']?.toString() ?? '--:--',
      'isha': exact['isha']?.toString() ?? '--:--',
    };
    _activeHijriDate = _computeHijri();
  }

  String _computeHijri() {
    final h = HijriCalendar.fromGregorian(DateTime.now().add(Duration(days: _settings.hijriAdjustment)));
    return AppLocale.isUrdu ? (h['formatted_urdu'] ?? '') : (h['formatted_en'] ?? '');
  }

  @override
  void initState() {
    super.initState();
    _ensureTimes();
    // Default to 'BEGINNING' if 'BOTH' was stored
    if (_settings.mosqueDisplayMode != 'BEGINNING' && _settings.mosqueDisplayMode != 'JAMAAT') {
      _settings.mosqueDisplayMode = 'BEGINNING';
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _time = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool is12h = _settings.is12HourFormat;
    final int rawH = _time.hour;
    final String period = rawH >= 12 ? 'PM' : 'AM';
    final int h12Num = (rawH % 12 == 0) ? 12 : rawH % 12;
    final String h = (is12h ? h12Num : rawH).toString().padLeft(2, '0');
    final String m = _time.minute.toString().padLeft(2, '0');
    final String s = _time.second.toString().padLeft(2, '0');

    final activeMosque = _settings.activeMosque;
    final displayMode = (_settings.mosqueDisplayMode == 'JAMAAT') ? 'JAMAAT' : 'BEGINNING';
    final bool useDynamic = _settings.useAutoDynamicJamaat;

    // Compute dynamic Jama'at times only if user enabled the auto dynamic formula
    Map<String, String> dynamicJamaat = {};
    if (useDynamic && _activeDetailedTimes.isNotEmpty) {
      dynamicJamaat = _settings.calculateDynamicJamaat(detailedTimes: _activeDetailedTimes);
    }

    final prayers = [
      {
        'key': 'fajr',
        'name_ur': 'فجر',
        'name_en': 'Fajr',
        'beg': _activePrayerTimes['fajr'] ?? '--:--',
        'jam': (useDynamic && dynamicJamaat.containsKey('fajr')) ? dynamicJamaat['fajr']! : activeMosque.fajrJamaat,
        'icon': Icons.nightlight_round,
      },
      {
        'key': 'dhuhr',
        'name_ur': 'ظہر',
        'name_en': 'Dhuhr',
        'beg': _activePrayerTimes['dhuhr'] ?? '--:--',
        'jam': (useDynamic && dynamicJamaat.containsKey('dhuhr')) ? dynamicJamaat['dhuhr']! : activeMosque.dhuhrJamaat,
        'icon': Icons.wb_sunny,
      },
      {
        'key': 'asr',
        'name_ur': 'عصر',
        'name_en': 'Asr',
        'beg': _activePrayerTimes['asr'] ?? '--:--',
        'jam': (useDynamic && dynamicJamaat.containsKey('asr')) ? dynamicJamaat['asr']! : activeMosque.asrJamaat,
        'icon': Icons.cloud,
      },
      {
        'key': 'maghrib',
        'name_ur': 'مغرب',
        'name_en': 'Maghrib',
        'beg': _activePrayerTimes['maghrib'] ?? '--:--',
        'jam': (useDynamic && dynamicJamaat.containsKey('maghrib')) ? dynamicJamaat['maghrib']! : activeMosque.maghribJamaat,
        'icon': Icons.wb_twilight,
      },
      {
        'key': 'isha',
        'name_ur': 'عشاء',
        'name_en': 'Isha',
        'beg': _activePrayerTimes['isha'] ?? '--:--',
        'jam': (useDynamic && dynamicJamaat.containsKey('isha')) ? dynamicJamaat['isha']! : activeMosque.ishaJamaat,
        'icon': Icons.bedtime,
      },
    ];

    final String jumuahDisplayTime = (useDynamic && dynamicJamaat.containsKey('jumuah'))
        ? dynamicJamaat['jumuah']!
        : activeMosque.jumuahTime;

    final now = DateTime.now();
    final gregorianMonthsUr = [
      '', 'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
    ];
    final gregorianDaysUr = [
      '', 'پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'
    ];
    final gregorianDateStr = AppLocale.isUrdu
        ? '${gregorianDaysUr[now.weekday]}، ${now.day} ${gregorianMonthsUr[now.month]} ${now.year}ء'
        : DateFormat('EEEE, d MMMM yyyy').format(now);

    final mosqueNameLocalized = activeMosque.nameLocalized(AppLocale.isUrdu);
    final mosqueAddressLocalized = activeMosque.addressLocalized(AppLocale.isUrdu);
    final fullMosqueHeader = mosqueAddressLocalized.isNotEmpty
        ? '🕌 $mosqueNameLocalized — $mosqueAddressLocalized'
        : '🕌 $mosqueNameLocalized';
    final fullDateHeader = '$_activeHijriDate   •   $gregorianDateStr';

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Mosque & Hijri Header Bar (Two Rows: Upper = Mosque Name, Lower = Dates)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Upper Row: Back button + Sliding Mosque Name
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              AppLocale.isUrdu ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 28,
                              child: SlidingMarqueeText(
                                text: fullMosqueHeader,
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                isRtl: AppLocale.isUrdu,
                                duration: const Duration(seconds: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Divider(color: AppTheme.cardBorder, height: 1),
                      const SizedBox(height: 5),
                      // Lower Row: Sliding Dates (Both Hijri & Gregorian)
                      Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppTheme.emerald, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 22,
                              child: SlidingMarqueeText(
                                text: fullDateHeader,
                                style: TextStyle(
                                  color: AppTheme.emerald,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                isRtl: AppLocale.isUrdu,
                                duration: const Duration(seconds: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Mode Selector Tabs: ابتدائی اوقات | جماعت کے اوقات (TWO TABS ONLY)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModePill('BEGINNING', 'ابتدائی اوقات (نماز)', 'Beginning Times'),
                      _buildModePill('JAMAAT', 'جماعت کے اوقات (مسجد)', 'Jama\'at Times'),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Giant LED Digital Clock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      textDirection: TextDirection.ltr,
                      children: [
                        Text(
                          '$h:$m:$s',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (is12h) ...[
                          const SizedBox(width: 8),
                          Text(
                            period,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Mosque TV/LED Style Prayers Grid / List
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth >= 650;

                      if (isWide) {
                        // Landscape / LED TV View: 5 Equal Prominent Horizontal Columns
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: prayers.map((p) {
                                final String timeStr = (displayMode == 'BEGINNING')
                                    ? (p['beg'] as String)
                                    : (p['jam'] as String);

                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: (displayMode == 'BEGINNING')
                                            ? AppTheme.emerald.withValues(alpha: 0.4)
                                            : AppTheme.gold.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (displayMode == 'BEGINNING'
                                                  ? AppTheme.emerald
                                                  : AppTheme.gold)
                                              .withValues(alpha: 0.1),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          p['icon'] as IconData,
                                          color: AppTheme.gold,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          AppLocale.t(ur: p['name_ur'] as String, en: p['name_en'] as String),
                                          style: TextStyle(
                                            color: AppTheme.gold,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          timeStr,
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(
                                            color: (displayMode == 'BEGINNING')
                                                ? AppTheme.textPrimary
                                                : AppTheme.emerald,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayMode == 'BEGINNING'
                                              ? AppLocale.t(ur: 'وقتِ ابتداء', en: 'Beginning')
                                              : AppLocale.t(ur: 'وقتِ جماعت', en: 'Jama\'at'),
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            // Friday Jumu'ah Card (If Jama'at mode is active)
                            if (displayMode == 'JAMAAT') ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.gold,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: AppTheme.gold, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      AppLocale.t(
                                        ur: 'نماز جمعۃ المبارک کی جماعت: \u202A$jumuahDisplayTime\u202C',
                                        en: 'Friday Jumu\'ah Jama\'at: \u202A$jumuahDisplayTime\u202C',
                                      ),
                                      style: TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      } else {
                        // Portrait / Mobile View: Prominent Full-Width TV Card Stack
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              ...prayers.map((p) {
                                final String timeStr = (displayMode == 'BEGINNING')
                                    ? (p['beg'] as String)
                                    : (p['jam'] as String);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: (displayMode == 'BEGINNING')
                                          ? AppTheme.emerald.withValues(alpha: 0.3)
                                          : AppTheme.gold.withValues(alpha: 0.35),
                                    ),
                                    boxShadow: AppTheme.cardShadow,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Name + Icon
                                      Row(
                                        children: [
                                          Icon(p['icon'] as IconData, color: AppTheme.gold, size: 26),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocale.t(ur: p['name_ur'] as String, en: p['name_en'] as String),
                                                style: TextStyle(
                                                  color: AppTheme.gold,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                displayMode == 'BEGINNING'
                                                    ? AppLocale.t(ur: 'وقتِ ابتداء', en: 'Beginning Time')
                                                    : AppLocale.t(ur: 'وقتِ جماعت', en: 'Jama\'at Time'),
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      // Prominent Time
                                      Text(
                                        timeStr,
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          color: (displayMode == 'BEGINNING')
                                              ? AppTheme.textPrimary
                                              : AppTheme.emerald,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              // Jumu'ah Card in Jama'at mode
                              if (displayMode == 'JAMAAT')
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                                    boxShadow: AppTheme.cardShadow,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.star, color: AppTheme.gold, size: 22),
                                          const SizedBox(width: 10),
                                          Text(
                                            AppLocale.t(ur: 'جمعۃ المبارک', en: 'Friday Jumu\'ah'),
                                            style: TextStyle(
                                              color: AppTheme.gold,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        jumuahDisplayTime,
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          color: AppTheme.gold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Location Footer
                Text(
                  '${AppLocale.t(ur: 'مقام', en: 'Location')}: ${widget.city.name}, ${widget.city.country} (${widget.city.latitude.toStringAsFixed(2)}°, ${widget.city.longitude.toStringAsFixed(2)}°)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'display',
          city: widget.city,
          detailedTimes: _activeDetailedTimes,
          hijriDate: _activeHijriDate,
        ),
      ),
    );
  }

  Widget _buildModePill(String mode, String labelUr, String labelEn) {
    final bool isSelected = _settings.mosqueDisplayMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _settings.mosqueDisplayMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          AppLocale.t(ur: labelUr, en: labelEn),
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Smooth bidirectional continuous sliding marquee widget
class SlidingMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isRtl;
  final Duration duration;

  const SlidingMarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.isRtl,
    this.duration = const Duration(seconds: 14),
  });

  @override
  State<SlidingMarqueeText> createState() => _SlidingMarqueeTextState();
}

class _SlidingMarqueeTextState extends State<SlidingMarqueeText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant SlidingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration || oldWidget.isRtl != widget.isRtl) {
      _controller.duration = widget.duration;
      _controller.reset();
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double p = _controller.value;
              // Urdu (isRtl == true): moves smoothly from left to right (بائیں سے دائیں)
              // English (isRtl == false): moves smoothly from right to left (دائیں سے بائیں)
              // This ensures that initial letters enter first into view.
              final double offset = widget.isRtl
                  ? containerWidth * (-1.0 + 2.0 * p)
                  : containerWidth * (1.0 - 2.0 * p);

              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
