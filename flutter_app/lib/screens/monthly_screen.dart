import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/astronomical_engine.dart';
import '../core/hijri_calendar.dart';
import '../core/city_database.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/app_settings.dart';
import '../widgets/minaret_bottom_nav.dart';

class MonthlyScreen extends StatefulWidget {
  final CityModel city;

  const MonthlyScreen({super.key, required this.city});

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  DateTime _currentMonthDate = DateTime.now();
  DateTimeRange? _customDateRange;
  bool _isCustomRangeMode = false;
  String _activeTableMode = 'PRAYER'; // 'PRAYER' (صلوٰۃ) or 'SEHAR_IFTAR' (سحر و افطار)
  String _viewLayout = 'CARD'; // 'CARD' (کارڈ لسٹ) or 'GRID' (مکمل جدول)

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 29)),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDateRange: initialRange,
      helpText: AppLocale.t(ur: 'تاریخ تا تاریخ جدول منتخب کریں', en: 'Select Custom Date Range'),
      saveText: AppLocale.t(ur: 'جدول تیار کریں', en: 'Generate Timetable'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppTheme.isDark
                ? ColorScheme.dark(
                    primary: AppTheme.emerald,
                    onPrimary: Colors.white,
                    surface: AppTheme.surfaceElevated,
                    onSurface: AppTheme.textPrimary,
                  )
                : ColorScheme.light(
                    primary: AppTheme.emerald,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _isCustomRangeMode = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentMonthDate.year;
    final month = _currentMonthDate.month;

    final settings = AppSettings();
    final engine = AstronomicalEngine(
      latitude: widget.city.latitude,
      longitude: widget.city.longitude,
      timeZone: widget.city.timezone,
      asrJuristic: settings.asrMethod,
      elevation: widget.city.elevation,
      fajrMode: settings.fajrMode,
      fajrDegree: settings.fajrDegree,
      fajrIntervalMin: settings.fajrIntervalMin,
      ishaMode: settings.ishaMode,
      ishaDegree: settings.ishaDegree,
      ishaIntervalMin: settings.ishaIntervalMin,
      is12HourFormat: settings.is12HourFormat,
    );

    final lastDay = DateTime(year, month + 1, 0).day;
    final bool isCustomRange = _isCustomRangeMode && _customDateRange != null && _activeTableMode == 'PRAYER';
    final DateTime startDate = isCustomRange ? _customDateRange!.start : DateTime(year, month, 1);
    final DateTime endDate = isCustomRange ? _customDateRange!.end : DateTime(year, month, lastDay);

    final List<Map<String, dynamic>> monthSchedule = [];

    // Hijri span determination
    final firstDate = startDate;
    final lastDate = endDate;
    final firstHijri = HijriCalendar.fromGregorian(firstDate.add(Duration(days: settings.hijriAdjustment)));
    final lastHijri = HijriCalendar.fromGregorian(lastDate.add(Duration(days: settings.hijriAdjustment)));

    final String firstMonthUr = firstHijri['month_name_urdu'] ?? firstHijri['month_urdu'] ?? '';
    final String lastMonthUr = lastHijri['month_name_urdu'] ?? lastHijri['month_urdu'] ?? '';
    final String hijriSpanUr = (firstMonthUr == lastMonthUr)
        ? '$firstMonthUr ${firstHijri['year']}ھ'
        : '$firstMonthUr تا $lastMonthUr ${lastHijri['year']}ھ';

    final String firstMonthEn = firstHijri['month_name_en'] ?? firstHijri['month_en'] ?? '';
    final String lastMonthEn = lastHijri['month_name_en'] ?? lastHijri['month_en'] ?? '';
    final String hijriSpanEn = (firstMonthEn == lastMonthEn)
        ? '$firstMonthEn ${firstHijri['year']} AH'
        : '$firstMonthEn - $lastMonthEn ${lastHijri['year']} AH';

    final totalDays = endDate.difference(startDate).inDays + 1;
    for (int i = 0; i < totalDays; i++) {
      final date = startDate.add(Duration(days: i));
      final d = date.day;
      final detailed = engine.calculateDetailedTimes(date);
      final raw = detailed['raw'] as Map<String, dynamic>;
      final hijri = HijriCalendar.fromGregorian(date.add(Duration(days: settings.hijriAdjustment)));

      // Exact Sehar & Iftar calculation with precise Shar'i safety margins:
      // The 3-minute safety rule ONLY applies on the Sehar & Iftar timetable during Ramadan (Hijri month 9)
      final bool isRamadan = (hijri['month'] == 9);
      final double marginMinutes = (_activeTableMode == 'SEHAR_IFTAR' && isRamadan) ? 3.0 : 1.0;

      final double fajrStartH = (raw['fajr_start'] as double?) ?? (raw['fajr'] as double);
      final double seharEndH = fajrStartH - (marginMinutes / 60.0);
      final double fajrAdhanH = fajrStartH + (marginMinutes / 60.0);
      final double sunsetH = (raw['sunset'] as double);
      final double iftarH = sunsetH + (marginMinutes / 60.0);

      final String nisfNaharTime = (detailed['nisf_nahar_card']?['time'] as String?) ??
          AstronomicalEngine.formatTimeDynamic((fajrStartH + sunsetH) / 2.0, withSeconds: false, is12h: settings.is12HourFormat);
      final String ishaAdhanTime = (detailed['adhan']?['isha'] as String?) ??
          (detailed['isha_card']?['start'] as String?) ??
          AstronomicalEngine.formatTimeDynamic(raw['isha_adhan'] ?? raw['isha_start'], withSeconds: false, is12h: settings.is12HourFormat);

      final String seharEndTime = AstronomicalEngine.formatTimeDynamic(seharEndH, withSeconds: false, is12h: settings.is12HourFormat);
      final String fajrAdhanTime = AstronomicalEngine.formatTimeDynamic(fajrAdhanH, withSeconds: false, is12h: settings.is12HourFormat);
      final String iftarTime = AstronomicalEngine.formatTimeDynamic(iftarH, withSeconds: false, is12h: settings.is12HourFormat);

      monthSchedule.add({
        'day': d,
        'date': date,
        'weekday': _getUrduWeekday(date.weekday),
        'weekdayEn': _getEnWeekday(date.weekday),
        'isFriday': date.weekday == DateTime.friday,
        'isRamadan': isRamadan,
        'hijri': hijri['formatted_urdu'],
        'hijriEn': hijri['formatted_en'],
        'hijriDay': hijri['day'],
        'hijriDayMonth': '${hijri['day']} ${hijri['month_name_urdu']}',
        'hijriDayMonthEn': '${hijri['day']} ${hijri['month_name_en']}',
        'fasting': detailed['fasting'] as Map<String, dynamic>,
        'exact': detailed['exact'] as Map<String, dynamic>,
        'fajr_card': detailed['fajr_card'] as Map<String, dynamic>?,
        'dhuhr_card': detailed['dhuhr_card'] as Map<String, dynamic>?,
        'asr_card': detailed['asr_card'] as Map<String, dynamic>?,
        'maghrib_card': detailed['maghrib_card'] as Map<String, dynamic>?,
        'isha_card': detailed['isha_card'] as Map<String, dynamic>?,
        'sehar_iftar': {
          'sehar_end': seharEndTime,
          'fajr_adhan': fajrAdhanTime,
          'nisf_nahar': nisfNaharTime,
          'iftar': iftarTime,
          'isha_adhan': ishaAdhanTime,
        },
      });
    }

    final monthNameUrdu = _getUrduMonthName(month);
    final monthNameEn = _getEnMonthName(month);

    final startFormatted = '${startDate.day}/${startDate.month}/${startDate.year}';
    final endFormatted = '${endDate.day}/${endDate.month}/${endDate.year}';
    final rangeTitleUr = '$startFormatted تا $endFormatted';
    final rangeTitleEn = '$startFormatted to $endFormatted';

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          title: Text(
            _activeTableMode == 'SEHAR_IFTAR'
                ? AppLocale.t(
                    ur: 'جدول اوقاتِ سحر و افطار - $monthNameUrdu $yearء ($hijriSpanUr)',
                    en: 'Sehar & Iftar Schedule - $monthNameEn $year ($hijriSpanEn)',
                  )
                : (isCustomRange
                    ? AppLocale.t(
                        ur: 'جدول اوقاتِ صلوٰۃ ($rangeTitleUr) - $hijriSpanUr',
                        en: 'Prayer Timetable ($rangeTitleEn) - $hijriSpanEn',
                      )
                    : AppLocale.t(
                        ur: 'جدول اوقاتِ صلوٰۃ - $monthNameUrdu $yearء ($hijriSpanUr)',
                        en: 'Prayer Timetable - $monthNameEn $year ($hijriSpanEn)',
                      )),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          actions: [
            IconButton(
              icon: Icon(Icons.ios_share, color: AppTheme.emerald),
              tooltip: AppLocale.t(ur: 'ایکسپورٹ و شیئر کے اختیارات', en: 'Export & Share Options'),
              onPressed: () => _showExportOptions(
                context,
                monthSchedule,
                isCustomRange ? rangeTitleUr : monthNameUrdu,
                isCustomRange ? rangeTitleEn : monthNameEn,
                year,
                hijriSpanUr,
                hijriSpanEn,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Month Switcher Header & Action Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: isCustomRange ? AppTheme.textSecondary.withValues(alpha: 0.3) : AppTheme.emerald, size: 28),
                        tooltip: AppLocale.t(ur: 'پچھلا مہینہ', en: 'Previous Month'),
                        onPressed: isCustomRange
                            ? null
                            : () {
                                setState(() {
                                  _currentMonthDate = DateTime(year, month - 1, 1);
                                });
                              },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              isCustomRange
                                  ? (AppLocale.isUrdu ? 'تاریخ تا تاریخ: $rangeTitleUr' : 'Range: $rangeTitleEn')
                                  : (AppLocale.isUrdu ? '$monthNameUrdu $yearء' : '$monthNameEn $year'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${widget.city.name} (${widget.city.latitude}°, ${widget.city.longitude}°)',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: isCustomRange ? AppTheme.textSecondary.withValues(alpha: 0.3) : AppTheme.emerald, size: 28),
                        tooltip: AppLocale.t(ur: 'اگلا مہینہ', en: 'Next Month'),
                        onPressed: isCustomRange
                            ? null
                            : () {
                                setState(() {
                                  _currentMonthDate = DateTime(year, month + 1, 1);
                                });
                              },
                      ),
                    ],
                  ),

                  // Custom Date Range Selector (for Prayer Timetable ONLY)
                  if (_activeTableMode == 'PRAYER') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _pickCustomDateRange(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isCustomRange
                                    ? AppTheme.emerald.withValues(alpha: 0.15)
                                    : AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCustomRange ? AppTheme.emerald : AppTheme.cardBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 16,
                                    color: isCustomRange ? AppTheme.emerald : AppTheme.gold,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      isCustomRange
                                          ? AppLocale.t(
                                              ur: 'کسٹم جدول فعال: $rangeTitleUr (تبدیل کریں)',
                                              en: 'Custom Range Active: $rangeTitleEn (Change)',
                                            )
                                          : AppLocale.t(
                                              ur: '📅 تاریخ تا تاریخ جدول نکالیں (Custom Range)',
                                              en: '📅 Generate Custom Date Range Timetable',
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCustomRange ? AppTheme.emerald : AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isCustomRange) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _isCustomRangeMode = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.gold),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.replay_rounded, size: 15, color: AppTheme.gold),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocale.t(ur: 'ماہانہ موڈ', en: 'Monthly'),
                                    style: TextStyle(
                                      color: AppTheme.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  Divider(color: AppTheme.cardBorder, height: 16),
                  // Table Mode Selector Pills: Prayer Timetable vs Sehar & Iftar Schedule
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_activeTableMode != 'PRAYER') {
                                setState(() => _activeTableMode = 'PRAYER');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeTableMode == 'PRAYER' ? AppTheme.emerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mosque, size: 16, color: _activeTableMode == 'PRAYER' ? Colors.white : AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocale.t(ur: 'اوقاتِ صلوٰۃ جدول', en: 'Prayer Timetable'),
                                    style: TextStyle(
                                      color: _activeTableMode == 'PRAYER' ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: _activeTableMode == 'PRAYER' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_activeTableMode != 'SEHAR_IFTAR') {
                                setState(() => _activeTableMode = 'SEHAR_IFTAR');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeTableMode == 'SEHAR_IFTAR' ? AppTheme.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.nights_stay, size: 16, color: _activeTableMode == 'SEHAR_IFTAR' ? const Color(0xFF0F172A) : AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocale.t(ur: 'اوقاتِ سحر و افطار نقشہ', en: 'Sehar & Iftar Schedule'),
                                    style: TextStyle(
                                      color: _activeTableMode == 'SEHAR_IFTAR' ? const Color(0xFF0F172A) : AppTheme.textSecondary,
                                      fontWeight: _activeTableMode == 'SEHAR_IFTAR' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // View Layout Selector Pills: Card List vs Full Table
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_viewLayout != 'CARD') {
                                setState(() => _viewLayout = 'CARD');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _viewLayout == 'CARD' ? AppTheme.emerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.view_agenda_rounded, size: 15, color: _viewLayout == 'CARD' ? Colors.white : AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocale.t(ur: '📱 موبائل کارڈ لسٹ', en: '📱 Card List'),
                                    style: TextStyle(
                                      color: _viewLayout == 'CARD' ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: _viewLayout == 'CARD' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_viewLayout != 'GRID') {
                                setState(() => _viewLayout = 'GRID');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _viewLayout == 'GRID' ? AppTheme.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.table_chart_rounded, size: 15, color: _viewLayout == 'GRID' ? const Color(0xFF0F172A) : AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocale.t(ur: '📊 مکمل جدول', en: '📊 Full Grid'),
                                    style: TextStyle(
                                      color: _viewLayout == 'GRID' ? const Color(0xFF0F172A) : AppTheme.textSecondary,
                                      fontWeight: _viewLayout == 'GRID' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Export Format Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ActionChip(
                          avatar: Icon(Icons.description, size: 16, color: AppTheme.sky),
                          label: Text(
                            AppLocale.t(ur: 'ڈاکومینٹ فائل (.doc)', en: 'Document (.doc)'),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceElevated,
                          onPressed: () => _exportDoc(context, monthSchedule, isCustomRange ? rangeTitleUr : monthNameUrdu, isCustomRange ? rangeTitleEn : monthNameEn, year, hijriSpanUr, hijriSpanEn),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFEF4444)),
                          label: Text(
                            AppLocale.t(ur: 'پی ڈی ایف فارمیٹ (.pdf)', en: 'PDF Format (.pdf)'),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceElevated,
                          onPressed: () => _exportPdf(context, monthSchedule, isCustomRange ? rangeTitleUr : monthNameUrdu, isCustomRange ? rangeTitleEn : monthNameEn, year, hijriSpanUr, hijriSpanEn),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(Icons.table_chart, size: 16, color: AppTheme.emerald),
                          label: Text(
                            AppLocale.t(ur: 'سی ایس وی ایکسل (.csv)', en: 'CSV Excel (.csv)'),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceElevated,
                          onPressed: () => _exportCsv(context, monthSchedule, isCustomRange ? rangeTitleUr : monthNameUrdu, isCustomRange ? rangeTitleEn : monthNameEn, year, hijriSpanUr, hijriSpanEn),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(Icons.text_snippet, size: 16, color: AppTheme.gold),
                          label: Text(
                            AppLocale.t(ur: 'ٹیکسٹ فائل (.txt)', en: 'Text (.txt)'),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceElevated,
                          onPressed: () => _exportTextFile(context, monthSchedule, isCustomRange ? rangeTitleUr : monthNameUrdu, isCustomRange ? rangeTitleEn : monthNameEn, year, hijriSpanUr, hijriSpanEn),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(Icons.share, size: 16, color: AppTheme.emerald),
                          label: Text(
                            AppLocale.t(ur: 'شیئر واٹس ایپ', en: 'Share WhatsApp'),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                          ),
                          backgroundColor: AppTheme.surfaceElevated,
                          onPressed: () => _shareTimetable(context, monthSchedule, isCustomRange ? rangeTitleUr : monthNameUrdu, isCustomRange ? rangeTitleEn : monthNameEn, year, hijriSpanUr, hijriSpanEn),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content: Either Card List View or Full Grid View
            Expanded(
              child: _viewLayout == 'CARD'
                  ? _buildMonthlyCardList(monthSchedule, monthNameUrdu, monthNameEn)
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _activeTableMode == 'SEHAR_IFTAR'
                            ? _buildSeharIftarDataTable(monthSchedule, monthNameUrdu, monthNameEn, hijriSpanUr, hijriSpanEn, year)
                            : _buildPrayerDataTable(monthSchedule, monthNameUrdu, monthNameEn, hijriSpanUr, hijriSpanEn, year),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'timetable',
          city: widget.city,
        ),
      ),
    );
  }

  Widget _buildMonthlyCardList(List<Map<String, dynamic>> monthSchedule, String monthNameUrdu, String monthNameEn) {
    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: monthSchedule.length,
      itemBuilder: (context, index) {
        final row = monthSchedule[index];
        final date = row['date'] as DateTime;
        final isToday = (date.year == now.year && date.month == now.month && date.day == now.day);
        final isFri = row['isFriday'] as bool;
        final dayName = AppLocale.isUrdu ? row['weekday'] : row['weekdayEn'];
        final hijri = AppLocale.isUrdu ? row['hijri'] : row['hijriEn'];

        if (_activeTableMode == 'SEHAR_IFTAR') {
          final si = row['sehar_iftar'] as Map<String, dynamic>;
          final bool isRamadan = (row['isRamadan'] as bool?) ?? false;
          final String marginStr = isRamadan ? '3m' : '1m';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.emerald.withValues(alpha: 0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isToday
                    ? AppTheme.emerald
                    : (isFri ? AppTheme.gold.withValues(alpha: 0.5) : AppTheme.cardBorder),
                width: isToday ? 1.6 : 1.0,
              ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.emerald : (isFri ? AppTheme.gold : AppTheme.surfaceElevated),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${row['day']} $dayName',
                            style: TextStyle(
                              color: (isToday || isFri) ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocale.t(ur: 'آج', en: 'Today'),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      hijri,
                      style: TextStyle(
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocale.t(ur: 'ختم سحر \u200E($marginStr-)\u200E', en: 'Sehar End (-$marginStr)'),
                              style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              si['sehar_end'] ?? '',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${AppLocale.t(ur: 'اذان:', en: 'Adhan:')} \u200E${si['fajr_adhan'] ?? ''}\u200E',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocale.t(ur: 'افطار \u200E($marginStr+)\u200E', en: 'Iftar (+$marginStr)'),
                              style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              si['iftar'] ?? '',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${AppLocale.t(ur: 'عشاء:', en: 'Isha:')} \u200E${si['isha_adhan'] ?? ''}\u200E',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocale.t(ur: 'نصف النہار شرعی', en: 'Shar\'i Midday'),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              si['nisf_nahar'] ?? '',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocale.t(ur: 'فرض روزے کی نیت کی حد', en: 'Fasting Intention Limit'),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 8.5),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          // PRAYER CARD
          final exact = row['exact'] as Map<String, dynamic>;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.emerald.withValues(alpha: 0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isToday
                    ? AppTheme.emerald
                    : (isFri ? AppTheme.gold.withValues(alpha: 0.5) : AppTheme.cardBorder),
                width: isToday ? 1.6 : 1.0,
              ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday ? AppTheme.emerald : (isFri ? AppTheme.gold : AppTheme.surfaceElevated),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${row['day']} $dayName',
                            style: TextStyle(
                              color: (isToday || isFri) ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocale.t(ur: 'آج', en: 'Today'),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      hijri,
                      style: TextStyle(
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'فجر', en: 'Fajr'), exact['fajr'] ?? '', AppTheme.sky),
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'طلوع', en: 'Sunrise'), exact['sunrise'] ?? '', AppTheme.textSecondary),
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'ظہر', en: 'Dhuhr'), exact['dhuhr'] ?? '', AppTheme.gold),
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'عصر', en: 'Asr'), exact['asr'] ?? '', AppTheme.emerald),
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'مغرب', en: 'Maghrib'), exact['maghrib'] ?? '', AppTheme.gold),
                    _buildPrayerMiniColumn(AppLocale.t(ur: 'عشاء', en: 'Isha'), exact['isha'] ?? '', AppTheme.sky),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildPrayerMiniColumn(String label, String time, Color color) {
    // Strip AM/PM so times are compact and legible without clutter as requested
    final cleanTime = time.replaceAll(RegExp(r'\s*(AM|PM|am|pm)', caseSensitive: false), '').trim();
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(
              cleanTime,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeharIftarDataTable(
    List<Map<String, dynamic>> monthSchedule,
    String monthNameUrdu,
    String monthNameEn,
    String hijriSpanUr,
    String hijriSpanEn,
    int year,
  ) {
    final bool hasRamadan = monthSchedule.any((r) => r['isRamadan'] == true);
    final String marginSuffix = hasRamadan ? '3m' : '1m';

    return DataTable(
      columnSpacing: 16,
      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceElevated),
      dataRowColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        return AppTheme.surface;
      }),
      columns: [
        DataColumn(label: Text(AppLocale.t(ur: 'ہجری ($hijriSpanUr)', en: 'Hijri ($hijriSpanEn)'), style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'عیسوی ($monthNameUrdu $yearء)', en: 'Date & Day ($monthNameEn $year)'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'ختم سحر \u200E($marginSuffix-)\u200E', en: 'Sehar End (-$marginSuffix)'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'اذانِ فجر \u200E($marginSuffix+)\u200E', en: 'Fajr Adhan (+$marginSuffix)'), style: TextStyle(color: AppTheme.sky, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'نصف النہار شرعی', en: 'Nisf un-Nahar'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'افطار \u200E($marginSuffix+)\u200E', en: 'Iftar (+$marginSuffix)'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'اذانِ عشاء', en: 'Isha Adhan'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))),
      ],
      rows: monthSchedule.map((row) {
        final isFri = row['isFriday'] as bool;
        final si = row['sehar_iftar'] as Map<String, dynamic>;
        final dayName = AppLocale.isUrdu ? row['weekday'] : row['weekdayEn'];

        return DataRow(
          cells: [
            DataCell(Center(child: Text('${row['hijriDay']}', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13)))),
            DataCell(Text('${row['day']} ($dayName)', style: TextStyle(color: isFri ? AppTheme.emerald : AppTheme.textPrimary, fontWeight: isFri ? FontWeight.bold : FontWeight.w600))),
            DataCell(Text(si['sehar_end'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
            DataCell(Text(si['fajr_adhan'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.sky, fontWeight: FontWeight.w600))),
            DataCell(Text(si['nisf_nahar'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textSecondary))),
            DataCell(Text(si['iftar'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
            DataCell(Text(si['isha_adhan'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPrayerDataTable(
    List<Map<String, dynamic>> monthSchedule,
    String monthNameUrdu,
    String monthNameEn,
    String hijriSpanUr,
    String hijriSpanEn,
    int year,
  ) {
    return DataTable(
      columnSpacing: 14,
      headingRowColor: WidgetStateProperty.all(AppTheme.surfaceElevated),
      dataRowColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        return AppTheme.surface;
      }),
      columns: [
        DataColumn(label: Text(AppLocale.t(ur: 'ہجری ($hijriSpanUr)', en: 'Hijri ($hijriSpanEn)'), style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'عیسوی ($monthNameUrdu $yearء)', en: 'Date & Day ($monthNameEn $year)'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'ختم سحر', en: 'Sehar End'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'فجر', en: 'Fajr'), style: TextStyle(color: AppTheme.sky, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'طلوع', en: 'Sunrise'), style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'ظہر', en: 'Dhuhr'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'عصر', en: 'Asr'), style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'افطار', en: 'Iftar'), style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'مغرب', en: 'Maghrib'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))),
        DataColumn(label: Text(AppLocale.t(ur: 'عشاء', en: 'Isha'), style: TextStyle(color: AppTheme.sky, fontWeight: FontWeight.bold))),
      ],
      rows: monthSchedule.map((row) {
        final isFri = row['isFriday'] as bool;
        final fasting = row['fasting'] as Map<String, dynamic>;
        final exact = row['exact'] as Map<String, dynamic>;
        final dayName = AppLocale.isUrdu ? row['weekday'] : row['weekdayEn'];

        return DataRow(
          cells: [
            DataCell(Center(child: Text('${row['hijriDay']}', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13)))),
            DataCell(Text('${row['day']} ($dayName)', style: TextStyle(color: isFri ? AppTheme.emerald : AppTheme.textPrimary, fontWeight: isFri ? FontWeight.bold : FontWeight.w600))),
            DataCell(Text(fasting['sehar_end'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.gold))),
            DataCell(Text(exact['fajr'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(exact['sunrise'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textSecondary))),
            DataCell(Text(exact['dhuhr'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(exact['asr'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(fasting['iftar_time'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.gold))),
            DataCell(Text(exact['maghrib'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(exact['isha'] ?? '', textDirection: TextDirection.ltr, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
          ],
        );
      }).toList(),
    );
  }

  void _showExportOptions(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.t(ur: 'ایکسپورٹ کے اختیارات منتخب کریں:', en: 'Select Export Format:'),
                style: TextStyle(color: AppTheme.gold, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // 1. PDF Document (.pdf)
              ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.surface, child: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444))),
                title: Text(AppLocale.t(ur: 'پی ڈی ایف دستاویز (.pdf - Download File)', en: 'PDF Document (.pdf)'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text(AppLocale.t(ur: 'موبائل اسٹوریج میں اصل پی ڈی ایف فائل ڈاؤنلوڈ اور محفوظ کریں', en: 'Download and save printable PDF file directly'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdf(context, schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn);
                },
              ),

              // 2. CSV Spreadsheet (.csv)
              ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.surface, child: Icon(Icons.table_chart, color: AppTheme.emerald)),
                title: Text(AppLocale.t(ur: 'سی ایس وی ایکسل فائل (.csv - Excel Compatible)', en: 'CSV Spreadsheet (.csv)'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text(AppLocale.t(ur: 'ایکسل اور گوگل شیٹس کے لیے اصل سی ایس وی فائل ڈاؤنلوڈ کریں', en: 'Download spreadsheet file with UTF-8 BOM'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportCsv(context, schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn);
                },
              ),

              // 3. Document File (.doc - Word)
              ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.surface, child: Icon(Icons.description, color: AppTheme.sky)),
                title: Text(AppLocale.t(ur: 'ڈاکومینٹ فائل (.doc - Word Document)', en: 'Word Document (.doc)'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text(AppLocale.t(ur: 'مائیکروسافٹ ورڈ میں کھولنے اور پرنٹ کرنے کے لیے اصل فائل', en: 'Download formatted file for Microsoft Word & Office'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportDoc(context, schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn);
                },
              ),

              // 4. Plain Text File (.txt)
              ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.surface, child: Icon(Icons.text_snippet, color: AppTheme.gold)),
                title: Text(AppLocale.t(ur: 'پلین ٹیکسٹ فائل (.txt)', en: 'Plain Text File (.txt)'), style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(AppLocale.t(ur: 'سادہ ٹیکسٹ فارمیٹ فائل ڈاؤنلوڈ و محفوظ کریں', en: 'Download monospace table text file'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportTextFile(context, schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn);
                },
              ),

              // 5. WhatsApp / Social Share
              ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.surface, child: Icon(Icons.share, color: AppTheme.emerald)),
                title: Text(AppLocale.t(ur: 'واٹس ایپ و سوشل میڈیا شیئر', en: 'WhatsApp & Social Share'), style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(AppLocale.t(ur: 'موبائل پر فوری شیئرنگ کے لیے ترتیب دیا گیا پیغام', en: 'Fast sharing text message for social media'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareTimetable(context, schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Directory> _getExportDir() async {
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final meeqatDir = Directory('${ext.path}/Meeqat');
          if (!await meeqatDir.exists()) {
            await meeqatDir.create(recursive: true);
          }
          return meeqatDir;
        }
      } catch (_) {}
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (await winDownloads.exists()) return winDownloads;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _saveAndShareFile({
    required BuildContext context,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    required String labelUr,
    required String labelEn,
  }) async {
    try {
      Directory dir;
      File file;
      try {
        dir = await _getExportDir();
        file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Fallback to app documents directory
        dir = await getApplicationDocumentsDirectory();
        file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
            content: Text(
              AppLocale.t(
                ur: '✅ $labelUr تیار ہو گئی!\n📂 فائل شیئر یا محفوظ کریں',
                en: '✅ $labelEn ready!\n📂 Share or save file',
              ),
            ),
          ),
        );
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType, name: fileName)],
        text: _activeTableMode == 'SEHAR_IFTAR'
            ? AppLocale.t(
                ur: 'مِیقات: جدول اوقاتِ سحر و افطار - ${widget.city.name}',
                en: 'Meeqat: Sehar & Iftar Schedule - ${widget.city.name}',
              )
            : AppLocale.t(
                ur: 'مِیقات: جدول اوقاتِ صلوٰۃ - ${widget.city.name}',
                en: 'Meeqat: Prayer Timetable - ${widget.city.name}',
              ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              AppLocale.t(
                ur: 'فائل محفوظ کرنے میں خرابی: $e',
                en: 'Error saving file: $e',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) async {
    final isUr = AppLocale.isUrdu;
    final isSeharIftar = _activeTableMode == 'SEHAR_IFTAR';
    final monthTitle = isUr ? '$monthUrdu $yearء' : '$monthEn $year';
    final pdfBytes = await _generatePdfBytes(schedule, monthTitle, isUr, hijriSpanUr, hijriSpanEn, isSeharIftar, monthEn);
    final safeCity = widget.city.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final prefix = isSeharIftar ? 'Meeqat_Sehar_Iftar' : 'Meeqat_Timetable';
    final isCustom = _isCustomRangeMode && _customDateRange != null && !isSeharIftar;
    final dateSuffix = isCustom
        ? 'range_${_customDateRange!.start.day}_${_customDateRange!.start.month}_to_${_customDateRange!.end.day}_${_customDateRange!.end.month}'
        : '${_currentMonthDate.month}_$year';
    final fileName = '${prefix}_${safeCity}_$dateSuffix.pdf';

    if (!context.mounted) return;
    await _saveAndShareFile(
      context: context,
      fileName: fileName,
      bytes: pdfBytes,
      mimeType: 'application/pdf',
      labelUr: 'پی ڈی ایف فائل ($fileName)',
      labelEn: 'PDF Document ($fileName)',
    );
  }

  Future<List<int>> _generatePdfBytes(
    List<Map<String, dynamic>> schedule,
    String monthTitle,
    bool isUr,
    String hijriSpanUr,
    String hijriSpanEn,
    bool isSeharIftar,
    String monthNameEn,
  ) async {
    final pdf = pw.Document();

    final bool hasRamadan = schedule.any((r) => r['isRamadan'] == true);
    final String marginSuffix = hasRamadan ? '3m' : '1m';

    final List<String> headers = isSeharIftar
        ? [
            'Hijri ($hijriSpanEn)',
            'Date & Day ($monthNameEn)',
            'Sehar End (-$marginSuffix)',
            'Fajr Adhan (+$marginSuffix)',
            'Nisf un-Nahar',
            'Iftar (+$marginSuffix)',
            'Isha Adhan',
          ]
        : [
            'Hijri ($hijriSpanEn)',
            'Date & Day ($monthNameEn)',
            'Sehar End',
            'Fajr',
            'Sunrise',
            'Dhuhr',
            'Asr',
            'Sunset/Iftar',
            'Isha',
          ];

    final List<List<String>> data = isSeharIftar
        ? schedule.map((r) {
            final si = r['sehar_iftar'] as Map<String, dynamic>;
            final dayName = r['weekdayEn'] ?? '';
            return [
              '${r['hijriDay']}',
              '${r['day']} ($dayName)',
              si['sehar_end']?.toString() ?? '',
              si['fajr_adhan']?.toString() ?? '',
              si['nisf_nahar']?.toString() ?? '',
              si['iftar']?.toString() ?? '',
              si['isha_adhan']?.toString() ?? '',
            ];
          }).toList()
        : schedule.map((r) {
            final f = r['fasting'] as Map<String, dynamic>;
            final e = r['exact'] as Map<String, dynamic>;
            final dayName = r['weekdayEn'] ?? '';
            return [
              '${r['hijriDay']}',
              '${r['day']} ($dayName)',
              f['sehar_end']?.toString() ?? '',
              e['fajr']?.toString() ?? '',
              e['sunrise']?.toString() ?? '',
              e['dhuhr']?.toString() ?? '',
              e['asr']?.toString() ?? '',
              f['iftar_time']?.toString() ?? '',
              e['isha']?.toString() ?? '',
            ];
          }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isSeharIftar
                        ? 'Meeqat - Sehar & Iftar Schedule (${widget.city.name})'
                        : 'Meeqat - Prayer Timetable (${widget.city.name})',
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.Text(
                    '$monthTitle ($hijriSpanEn)',
                    style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Location: ${widget.city.name}, ${widget.city.country} | Lat: ${widget.city.latitude}N, Lng: ${widget.city.longitude}E | GMT+${widget.city.timezone}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            if (isSeharIftar)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
                child: pw.Text(
                  'Shar\'i Precision: Sehar End = $marginSuffix before exact Fajr (صبح صادق) | Fajr Adhan = $marginSuffix after exact Fajr | Iftar = $marginSuffix after exact Sunset',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.amber800),
                ),
              ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: isSeharIftar ? PdfColors.amber900 : PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Meeqat (المیقات) Islamic Astronomical Suite', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('All calculations verified with second-precision astronomy & Hanafi/Shafi\'i jurisprudence', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) async {
    final isUr = AppLocale.isUrdu;
    final isSeharIftar = _activeTableMode == 'SEHAR_IFTAR';
    final csvBytes = _generateCsvBytes(schedule, isUr, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn, isSeharIftar);
    final safeCity = widget.city.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final prefix = isSeharIftar ? 'Meeqat_Sehar_Iftar' : 'Meeqat_Timetable';
    final isCustom = _isCustomRangeMode && _customDateRange != null && !isSeharIftar;
    final dateSuffix = isCustom
        ? 'range_${_customDateRange!.start.day}_${_customDateRange!.start.month}_to_${_customDateRange!.end.day}_${_customDateRange!.end.month}'
        : '${_currentMonthDate.month}_$year';
    final fileName = '${prefix}_${safeCity}_$dateSuffix.csv';

    if (!context.mounted) return;
    await _saveAndShareFile(
      context: context,
      fileName: fileName,
      bytes: csvBytes,
      mimeType: 'text/csv',
      labelUr: 'سی ایس وی ایکسل فائل ($fileName)',
      labelEn: 'CSV Spreadsheet ($fileName)',
    );
  }

  List<int> _generateCsvBytes(
    List<Map<String, dynamic>> schedule,
    bool isUr,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
    bool isSeharIftar,
  ) {
    final buffer = StringBuffer();
    final bom = [0xEF, 0xBB, 0xBF];
    final bool hasRamadan = schedule.any((r) => r['isRamadan'] == true);
    final String marginSuffix = hasRamadan ? '3m' : '1m';
    final String marginUrdu = hasRamadan ? '3 منٹ' : '1 منٹ';

    if (isSeharIftar) {
      if (isUr) {
        buffer.writeln('# جدول و نقشہ اوقاتِ سحر و افطار - ${widget.city.name}');
        buffer.writeln('# عیسوی مہینہ: $monthUrdu $yearء | ہجری مہینہ: $hijriSpanUr');
        buffer.writeln('# مقام: ${widget.city.name} (${widget.city.country}) | عرض بلد: ${widget.city.latitude}°, طول بلد: ${widget.city.longitude}°');
        buffer.writeln('ہجری ($hijriSpanUr),عیسوی تاریخ و دن ($monthUrdu $yearء),ختم سحر (احتیاطی \u200E$marginUrdu-\u200E),اذانِ فجر (احتیاطی \u200E$marginUrdu+\u200E),نصف النہار شرعی,افطار (احتیاطی \u200E$marginUrdu+\u200E),اذانِ عشاء');
      } else {
        buffer.writeln('# Sehar & Iftar Schedule - ${widget.city.name}');
        buffer.writeln('# Month: $monthEn $year | Hijri: $hijriSpanEn');
        buffer.writeln('# Location: ${widget.city.name} (${widget.city.country}) | Lat: ${widget.city.latitude}°, Lng: ${widget.city.longitude}°');
        buffer.writeln('Hijri ($hijriSpanEn),Date & Day ($monthEn $year),Sehar End (-$marginSuffix),Fajr Adhan (+$marginSuffix),Nisf un-Nahar Shar\'i,Iftar (+$marginSuffix),Isha Adhan');
      }

      for (var r in schedule) {
        final si = r['sehar_iftar'] as Map<String, dynamic>;
        final dayName = isUr ? r['weekday'] : r['weekdayEn'];
        buffer.writeln(
          '${r['hijriDay']},"${r['day']} ($dayName)","${si['sehar_end']}","${si['fajr_adhan']}","${si['nisf_nahar']}","${si['iftar']}","${si['isha_adhan']}"',
        );
      }
    } else {
      if (isUr) {
        buffer.writeln('# جدول اوقاتِ صلوٰۃ - ${widget.city.name}');
        buffer.writeln('# عیسوی مہینہ: $monthUrdu $yearء | ہجری مہینہ: $hijriSpanUr');
        buffer.writeln('# مقام: ${widget.city.name} (${widget.city.country}) | عرض بلد: ${widget.city.latitude}°, طول بلد: ${widget.city.longitude}°');
        buffer.writeln('ہجری ($hijriSpanUr),عیسوی تاریخ و دن ($monthUrdu $yearء),ختم سحر,فجر,طلوع آفتاب,ظہر,عصر,غروب و افطار,عشاء');
      } else {
        buffer.writeln('# Prayer Timetable - ${widget.city.name}');
        buffer.writeln('# Month: $monthEn $year | Hijri: $hijriSpanEn');
        buffer.writeln('# Location: ${widget.city.name} (${widget.city.country}) | Lat: ${widget.city.latitude}°, Lng: ${widget.city.longitude}°');
        buffer.writeln('Hijri ($hijriSpanEn),Date & Day ($monthEn $year),Sehar End,Fajr,Sunrise,Dhuhr,Asr,Sunset / Iftar,Isha');
      }

      for (var r in schedule) {
        final f = r['fasting'] as Map<String, dynamic>;
        final e = r['exact'] as Map<String, dynamic>;
        final dayName = isUr ? r['weekday'] : r['weekdayEn'];
        buffer.writeln(
          '${r['hijriDay']},"${r['day']} ($dayName)","${f['sehar_end']}","${e['fajr']}","${e['sunrise']}","${e['dhuhr']}","${e['asr']}","${f['iftar_time']}","${e['isha']}"',
        );
      }
    }

    final bytes = utf8.encode(buffer.toString());
    return [...bom, ...bytes];
  }

  Future<void> _exportDoc(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) async {
    final isSeharIftar = _activeTableMode == 'SEHAR_IFTAR';
    final docBytes = _generateDocBytes(schedule, monthUrdu, monthEn, year, hijriSpanUr, hijriSpanEn, isSeharIftar);
    final safeCity = widget.city.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final prefix = isSeharIftar ? 'Meeqat_Sehar_Iftar' : 'Meeqat_Timetable';
    final isCustom = _isCustomRangeMode && _customDateRange != null && !isSeharIftar;
    final dateSuffix = isCustom
        ? 'range_${_customDateRange!.start.day}_${_customDateRange!.start.month}_to_${_customDateRange!.end.day}_${_customDateRange!.end.month}'
        : '${_currentMonthDate.month}_$year';
    final fileName = '${prefix}_${safeCity}_$dateSuffix.doc';

    if (!context.mounted) return;
    await _saveAndShareFile(
      context: context,
      fileName: fileName,
      bytes: docBytes,
      mimeType: 'application/msword',
      labelUr: 'ورڈ ڈاکومینٹ فائل ($fileName)',
      labelEn: 'Word Document ($fileName)',
    );
  }

  List<int> _generateDocBytes(
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
    bool isSeharIftar,
  ) {
    final buffer = StringBuffer();
    final isUr = AppLocale.isUrdu;
    final bool hasRamadan = schedule.any((r) => r['isRamadan'] == true);
    final String marginSuffix = hasRamadan ? '3m' : '1m';
    final String marginUrdu = hasRamadan ? '3 منٹ' : '1 منٹ';

    final title = isSeharIftar
        ? (isUr ? 'نقشہ و جدول اوقاتِ سحر و افطار - ${widget.city.name}' : 'Sehar & Iftar Schedule - ${widget.city.name}')
        : (isUr ? 'جدول اوقاتِ صلوٰۃ - ${widget.city.name}' : 'Prayer Timetable - ${widget.city.name}');
    final monthTitle = isUr ? '$monthUrdu $yearء' : '$monthEn $year';
    final hijriTitle = isUr ? hijriSpanUr : hijriSpanEn;

    buffer.writeln("<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>");
    buffer.writeln("<head><meta charset='utf-8'><title>$title</title>");
    buffer.writeln("<style>");
    buffer.writeln("body { font-family: 'Amiri', 'Segoe UI', Arial, sans-serif; direction: ${isUr ? 'rtl' : 'ltr'}; text-align: ${isUr ? 'right' : 'left'}; }");
    buffer.writeln("h1, h2, h3 { text-align: center; color: #0b2545; margin: 4px 0; }");
    buffer.writeln("table { border-collapse: collapse; width: 100%; margin-top: 15px; }");
    buffer.writeln("th, td { border: 1px solid #333; padding: 6px 8px; text-align: center; font-size: 11pt; }");
    buffer.writeln("th { background-color: ${isSeharIftar ? '#b45309' : '#0f172a'}; color: #ffffff; }");
    buffer.writeln("tr:nth-child(even) { background-color: #f8fafc; }");
    buffer.writeln(".note { text-align: center; font-size: 10pt; color: #b45309; margin-top: 6px; font-weight: bold; }");
    buffer.writeln(".footer { margin-top: 20px; font-size: 10pt; color: #555; text-align: center; }");
    buffer.writeln("</style></head><body>");
    buffer.writeln("<h1>${isSeharIftar ? '🌙' : '🕌'} $title</h1>");
    buffer.writeln("<h2>${isUr ? 'عیسوی مہینہ' : 'Month'}: $monthTitle &nbsp;|&nbsp; ${isUr ? 'ہجری مہینہ' : 'Hijri'}: $hijriTitle</h2>");
    buffer.writeln("<h3>${isUr ? 'مقام' : 'Location'}: ${widget.city.name}, ${widget.city.country} | ${isUr ? 'عرض بلد' : 'Lat'}: ${widget.city.latitude}°, ${isUr ? 'طول بلد' : 'Lng'}: ${widget.city.longitude}°</h3>");
    if (isSeharIftar) {
      buffer.writeln("<p class='note'>${isUr ? 'قاعدہ شرعی: اختتام سحر ایگزیکٹ وقت سحر سے $marginUrdu قبل | اذان فجر ایگزیکٹ وقت سے $marginUrdu بعد | افطار ایگزیکٹ غروب سے $marginUrdu بعد' : 'Shar\'i Rule: Sehar End = -$marginSuffix before dawn | Fajr Adhan = +$marginSuffix after dawn | Iftar = +$marginSuffix after sunset'}</p>");
    }

    buffer.writeln("<table><thead><tr>");
    if (isSeharIftar) {
      if (isUr) {
        buffer.writeln("<th>ہجری ($hijriSpanUr)</th><th>عیسوی تاریخ و دن ($monthUrdu $yearء)</th><th>ختم سحر \u200E($marginSuffix-)\u200E</th><th>اذانِ فجر \u200E($marginSuffix+)\u200E</th><th>نصف النہار شرعی</th><th>افطار \u200E($marginSuffix+)\u200E</th><th>اذانِ عشاء</th>");
      } else {
        buffer.writeln("<th>Hijri ($hijriSpanEn)</th><th>Date & Day ($monthEn $year)</th><th>Sehar End (-$marginSuffix)</th><th>Fajr Adhan (+$marginSuffix)</th><th>Nisf un-Nahar</th><th>Iftar (+$marginSuffix)</th><th>Isha Adhan</th>");
      }
    } else {
      if (isUr) {
        buffer.writeln("<th>ہجری ($hijriSpanUr)</th><th>عیسوی تاریخ و دن ($monthUrdu $yearء)</th><th>ختم سحر</th><th>فجر</th><th>طلوع</th><th>ظہر</th><th>عصر</th><th>افطار/غروب</th><th>عشاء</th>");
      } else {
        buffer.writeln("<th>Hijri ($hijriSpanEn)</th><th>Date & Day ($monthEn $year)</th><th>Sehar End</th><th>Fajr</th><th>Sunrise</th><th>Dhuhr</th><th>Asr</th><th>Sunset/Iftar</th><th>Isha</th>");
      }
    }
    buffer.writeln("</tr></thead><tbody>");

    if (isSeharIftar) {
      for (var r in schedule) {
        final si = r['sehar_iftar'] as Map<String, dynamic>;
        final dayName = isUr ? r['weekday'] : r['weekdayEn'];
        buffer.writeln("<tr><td><b>${r['hijriDay']}</b></td><td>${r['day']} ($dayName)</td><td><b>${si['sehar_end']}</b></td><td>${si['fajr_adhan']}</td><td>${si['nisf_nahar']}</td><td><b>${si['iftar']}</b></td><td>${si['isha_adhan']}</td></tr>");
      }
    } else {
      for (var r in schedule) {
        final f = r['fasting'] as Map<String, dynamic>;
        final e = r['exact'] as Map<String, dynamic>;
        final dayName = isUr ? r['weekday'] : r['weekdayEn'];
        buffer.writeln("<tr><td><b>${r['hijriDay']}</b></td><td>${r['day']} ($dayName)</td><td>${f['sehar_end']}</td><td>${e['fajr']}</td><td>${e['sunrise']}</td><td>${e['dhuhr']}</td><td>${e['asr']}</td><td>${f['iftar_time']}</td><td>${e['isha']}</td></tr>");
      }
    }
    buffer.writeln("</tbody></table>");
    buffer.writeln("<div class='footer'>${isUr ? 'تیار کردہ: مِیقات (المیقات) | جدید فلکیاتی و شرعی اوقاتِ نماز و صیام' : 'Generated by Meeqat (المیقات) | Astronomical Islamic Prayer Suite'}</div>");
    buffer.writeln("</body></html>");

    final bom = [0xEF, 0xBB, 0xBF];
    final bytes = utf8.encode(buffer.toString());
    return [...bom, ...bytes];
  }

  Future<void> _exportTextFile(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) async {
    final buffer = StringBuffer();
    final isUr = AppLocale.isUrdu;
    final isSeharIftar = _activeTableMode == 'SEHAR_IFTAR';
    final bool hasRamadan = schedule.any((r) => r['isRamadan'] == true);
    final String marginSuffix = hasRamadan ? '3m' : '1m';

    final title = isSeharIftar
        ? (isUr ? 'نقشہ و جدول اوقاتِ سحر و افطار - ${widget.city.name}' : 'Sehar & Iftar Schedule - ${widget.city.name}')
        : (isUr ? 'جدول اوقاتِ صلوٰۃ - ${widget.city.name}' : 'Prayer Timetable - ${widget.city.name}');
    final monthTitle = isUr ? '$monthUrdu $yearء' : '$monthEn $year';
    final hijriTitle = isUr ? hijriSpanUr : hijriSpanEn;

    buffer.writeln("==========================================================================================");
    buffer.writeln("  ${isSeharIftar ? '🌙' : '🕌'} $title");
    buffer.writeln("  Gregorian: $monthTitle | Hijri: $hijriTitle");
    buffer.writeln("  Location: ${widget.city.name}, ${widget.city.country} | Lat: ${widget.city.latitude}N, Lng: ${widget.city.longitude}E | GMT+${widget.city.timezone}");
    if (isSeharIftar) {
      buffer.writeln("  Rules: Sehar End = Fajr - $marginSuffix | Fajr Adhan = Fajr + $marginSuffix | Iftar = Sunset + $marginSuffix");
    }
    buffer.writeln("==========================================================================================");

    if (isSeharIftar) {
      buffer.writeln("Hijri ($hijriSpanEn) | Date & Day ($monthEn $year) | Sehar End (-$marginSuffix) | Fajr Adhan (+$marginSuffix) | Nisf Nahar | Iftar (+$marginSuffix) | Isha");
      buffer.writeln("----------------+-------------------+-----------------+------------------+------------+-------------+---------");
      for (var r in schedule) {
        final si = r['sehar_iftar'] as Map<String, dynamic>;
        final dayName = (isUr ? r['weekday'] : r['weekdayEn']).toString();
        final dateDayStr = '${r['day']} ($dayName)'.padRight(19, ' ');
        final hijriStr = '${r['hijriDay']}'.padRight(14, ' ');
        buffer.writeln("$hijriStr | $dateDayStr | ${si['sehar_end']}         | ${si['fajr_adhan']}          | ${si['nisf_nahar']}   | ${si['iftar']}       | ${si['isha_adhan']}");
      }
    } else {
      buffer.writeln("Hijri ($hijriSpanEn) | Date & Day ($monthEn $year) | Sehar    | Fajr     | Sunrise  | Dhuhr    | Asr      | Iftar    | Isha");
      buffer.writeln("---------------+---------------------+----------+----------+----------+----------+----------+----------+---------");
      for (var r in schedule) {
        final f = r['fasting'] as Map<String, dynamic>;
        final e = r['exact'] as Map<String, dynamic>;
        final dayName = (isUr ? r['weekday'] : r['weekdayEn']).toString();
        final hijri = '${r['hijriDay']}'.padRight(13, ' ');
        final dateDayStr = '${r['day']} ($dayName)'.padRight(19, ' ');
        buffer.writeln("$hijri | $dateDayStr | ${f['sehar_end']} | ${e['fajr']} | ${e['sunrise']} | ${e['dhuhr']} | ${e['asr']} | ${f['iftar_time']} | ${e['isha']}");
      }
    }

    buffer.writeln("==========================================================================================");
    buffer.writeln("Generated by: Meeqat (المیقات) Islamic Astronomical App");

    final bytes = utf8.encode(buffer.toString());
    final safeCity = widget.city.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final prefix = isSeharIftar ? 'Meeqat_Sehar_Iftar' : 'Meeqat_Timetable';
    final isCustom = _isCustomRangeMode && _customDateRange != null && !isSeharIftar;
    final dateSuffix = isCustom
        ? 'range_${_customDateRange!.start.day}_${_customDateRange!.start.month}_to_${_customDateRange!.end.day}_${_customDateRange!.end.month}'
        : '${_currentMonthDate.month}_$year';
    final fileName = '${prefix}_${safeCity}_$dateSuffix.txt';

    if (!context.mounted) return;
    await _saveAndShareFile(
      context: context,
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/plain',
      labelUr: 'ٹیکسٹ فائل ($fileName)',
      labelEn: 'Text File ($fileName)',
    );
  }

  Future<void> _shareTimetable(
    BuildContext context,
    List<Map<String, dynamic>> schedule,
    String monthUrdu,
    String monthEn,
    int year,
    String hijriSpanUr,
    String hijriSpanEn,
  ) async {
    final buffer = StringBuffer();
    final isUr = AppLocale.isUrdu;
    final isSeharIftar = _activeTableMode == 'SEHAR_IFTAR';
    final bool hasRamadan = schedule.any((r) => r['isRamadan'] == true);
    final String marginUrdu = hasRamadan ? '3 منٹ' : '1 منٹ';

    if (isSeharIftar) {
      if (isUr) {
        buffer.writeln('🌙 نقشہ و جدول اوقاتِ سحر و افطار - ${widget.city.name}');
        buffer.writeln('عیسوی مہینہ: $monthUrdu $yearء | ہجری مہینہ: $hijriSpanUr');
        buffer.writeln('مقام: ${widget.city.name} | طول بلد: ${widget.city.longitude}°، عرض بلد: ${widget.city.latitude}°');
        buffer.writeln('⚠️ قاعدہ: ختم سحر -$marginUrdu، اذان فجر +$marginUrdu، افطار +$marginUrdu');
        buffer.writeln('═══════════════════════════════════════════════');
        buffer.writeln('ہجری ($hijriSpanUr) | عیسوی تاریخ و دن ($monthUrdu $yearء) | ختم سحر | اذان فجر | نصف النہار | افطار | عشاء');
        buffer.writeln('───────────────────────────────────────────────');
        for (var r in schedule) {
          final si = r['sehar_iftar'] as Map<String, dynamic>;
          buffer.writeln('${r['hijriDay']} | ${r['day']} (${r['weekday']}) | ${si['sehar_end']} | ${si['fajr_adhan']} | ${si['nisf_nahar']} | ${si['iftar']} | ${si['isha_adhan']}');
        }
        buffer.writeln('═══════════════════════════════════════════════');
        buffer.writeln('📲 تیار کردہ: مِیقات (المیقات - Meeqat)');
      } else {
        buffer.writeln('🌙 Sehar & Iftar Schedule - ${widget.city.name}');
        buffer.writeln('Month: $monthEn $year | Hijri: $hijriSpanEn');
        buffer.writeln('Location: ${widget.city.name} | Lat: ${widget.city.latitude}°, Lng: ${widget.city.longitude}°');
        buffer.writeln('===============================================');
        buffer.writeln('Hijri ($hijriSpanEn) | Date & Day ($monthEn $year) | Sehar End | Fajr Adhan | Nisf Nahar | Iftar | Isha');
        buffer.writeln('-----------------------------------------------');
        for (var r in schedule) {
          final si = r['sehar_iftar'] as Map<String, dynamic>;
          buffer.writeln('${r['hijriDay']} | ${r['day']} (${r['weekdayEn']}) | ${si['sehar_end']} | ${si['fajr_adhan']} | ${si['nisf_nahar']} | ${si['iftar']} | ${si['isha_adhan']}');
        }
        buffer.writeln('===============================================');
        buffer.writeln('📲 Generated by: Meeqat (المیقات)');
      }
    } else {
      if (isUr) {
        buffer.writeln('🕌 جدول اوقاتِ صلوٰۃ - ${widget.city.name}');
        buffer.writeln('عیسوی مہینہ: $monthUrdu $yearء | ہجری مہینہ: $hijriSpanUr');
        buffer.writeln('طول بلد: ${widget.city.longitude}°، عرض بلد: ${widget.city.latitude}°');
        buffer.writeln('═══════════════════════════════════════');
        buffer.writeln('ہجری ($hijriSpanUr) | عیسوی تاریخ و دن ($monthUrdu $yearء) | سحر | فجر | طلوع | ظہر | عصر | افطار | مغرب | عشاء');
        buffer.writeln('───────────────────────────────────────');
        for (var r in schedule) {
          final f = r['fasting'] as Map<String, dynamic>;
          final e = r['exact'] as Map<String, dynamic>;
          buffer.writeln('${r['hijriDay']} | ${r['day']} (${r['weekday']}) | ${f['sehar_end']} | ${e['fajr']} | ${e['sunrise']} | ${e['dhuhr']} | ${e['asr']} | ${f['iftar_time']} | ${e['maghrib']} | ${e['isha']}');
        }
        buffer.writeln('═══════════════════════════════════════');
        buffer.writeln('📲 تیار کردہ: مِیقات (المیقات - Meeqat)');
      } else {
        buffer.writeln('🕌 Prayer Timetable - ${widget.city.name}');
        buffer.writeln('Month: $monthEn $year | Hijri: $hijriSpanEn');
        buffer.writeln('Location: ${widget.city.name} | Lat: ${widget.city.latitude}°, Lng: ${widget.city.longitude}°');
        buffer.writeln('=======================================');
        buffer.writeln('Hijri ($hijriSpanEn) | Date & Day ($monthEn $year) | Sehar | Fajr | Sun | Dhuhr | Asr | Iftar | Maghrib | Isha');
        buffer.writeln('---------------------------------------');
        for (var r in schedule) {
          final f = r['fasting'] as Map<String, dynamic>;
          final e = r['exact'] as Map<String, dynamic>;
          buffer.writeln('${r['hijriDay']} | ${r['day']} (${r['weekdayEn']}) | ${f['sehar_end']} | ${e['fajr']} | ${e['sunrise']} | ${e['dhuhr']} | ${e['asr']} | ${f['iftar_time']} | ${e['maghrib']} | ${e['isha']}');
        }
        buffer.writeln('=======================================');
        buffer.writeln('📲 Generated by: Meeqat (المیقات)');
      }
    }

    final shareText = buffer.toString();
    // ignore: deprecated_member_use
    await Share.share(
      shareText,
      subject: isSeharIftar
          ? AppLocale.t(
              ur: 'نقشہ و جدول اوقاتِ سحر و افطار - ${widget.city.name}',
              en: 'Sehar & Iftar Schedule - ${widget.city.name}',
            )
          : AppLocale.t(
              ur: 'جدول اوقاتِ صلوٰۃ - ${widget.city.name}',
              en: 'Prayer Timetable - ${widget.city.name}',
            ),
    );
  }

  String _getUrduWeekday(int d) {
    switch (d) {
      case DateTime.monday: return 'پیر';
      case DateTime.tuesday: return 'منگل';
      case DateTime.wednesday: return 'بدھ';
      case DateTime.thursday: return 'جمعرات';
      case DateTime.friday: return 'جمعہ';
      case DateTime.saturday: return 'ہفتہ';
      case DateTime.sunday: return 'اتوار';
      default: return '';
    }
  }

  String _getEnWeekday(int d) {
    switch (d) {
      case DateTime.monday: return 'Mon';
      case DateTime.tuesday: return 'Tue';
      case DateTime.wednesday: return 'Wed';
      case DateTime.thursday: return 'Thu';
      case DateTime.friday: return 'Fri';
      case DateTime.saturday: return 'Sat';
      case DateTime.sunday: return 'Sun';
      default: return '';
    }
  }

  String _getUrduMonthName(int m) {
    const list = [
      '', 'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
      'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
    ];
    return list[m];
  }

  String _getEnMonthName(int m) {
    const list = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return list[m];
  }
}
