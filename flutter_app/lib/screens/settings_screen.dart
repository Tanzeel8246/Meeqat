// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_settings.dart';
import '../core/city_database.dart';
import '../core/qibla_calculator.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/hijri_calendar.dart';
import '../core/alarm_service.dart';
import '../core/astronomical_engine.dart';
import '../core/update_service.dart';
import '../core/brand_battery_helper.dart';
import '../core/mosque_sync_service.dart';
import '../widgets/post_adhan_dua_dialog.dart';
import 'gazetteer_screen.dart';
import 'qadha_umri_screen.dart';

class SettingsScreen extends StatefulWidget {
  final CityModel currentCity;
  final Function(CityModel)? onCityChanged;
  final VoidCallback? onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.currentCity,
    this.onCityChanged,
    this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppSettings _settings = AppSettings();
  bool _previewExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (launched) return;
    } catch (_) {}
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t(
                ur: 'لنک اوپن نہیں ہو سکا: $urlStr',
                en: 'Could not open link: $urlStr',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final appUri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WhatsApp: +$cleanPhone')),
          );
        }
      }
    }
  }

  void _notifyChange() {
    setState(() {});
    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          title: Text(
            AppLocale.t(ur: 'ترتیبات و معلومات (Settings)', en: 'Settings & Information'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppTheme.emerald,
            labelColor: AppTheme.emerald,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: const Icon(Icons.tune), text: AppLocale.t(ur: 'عمومی ترتیبات', en: 'General')),
              Tab(icon: const Icon(Icons.mosque), text: AppLocale.t(ur: 'مساجد و جماعت', en: 'Mosques')),
              Tab(icon: const Icon(Icons.bookmark), text: AppLocale.t(ur: 'محفوظ مقامات (100)', en: 'Saved (100)')),
              Tab(icon: const Icon(Icons.event), text: AppLocale.t(ur: 'اسلامی ایام گیلری', en: 'Islamic Events')),
              Tab(icon: const Icon(Icons.info_outline), text: AppLocale.t(ur: 'ایف اے کیو و رابطہ', en: 'FAQ & About')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralSettingsTab(),
            _buildMosquesTab(),
            _buildSavedLocationsTab(),
            _buildIslamicEventsTab(),
            _buildFaqAndAboutTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: GENERAL SETTINGS & DETERMINATION DIALOGS
  // ==========================================
  Widget _buildGeneralSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Hijri Calendar Adjustment (سب سے اوپر)
        _buildSectionHeader(AppLocale.t(ur: 'ہجری تاریخ درستگی (رویتِ ہلال کے مطابق)', en: 'Hijri Date Adjustment')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocale.t(ur: 'تاریخ میں فرق:', en: 'Adjustment:'),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_settings.hijriAdjustment > 0 ? '+' : ''}${_settings.hijriAdjustment} ${AppLocale.t(ur: 'دن', en: 'Days')}',
                    style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Slider(
                value: _settings.hijriAdjustment.toDouble(),
                min: -2.0,
                max: 2.0,
                divisions: 4,
                activeColor: AppTheme.emerald,
                inactiveColor: AppTheme.textSecondary.withValues(alpha: 0.3),
                onChanged: (val) {
                  _settings.hijriAdjustment = val.round();
                  _notifyChange();
                },
              ),
              Text(
                AppLocale.t(
                  ur: 'چاند کی مقامی رویت کے مطابق ہجری تاریخ کو منفی یا مثبت دو دن تک ایڈجسٹ کیا جا سکتا ہے۔',
                  en: 'Adjust Hijri date by -2 to +2 days based on local moon sighting.',
                ),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 1.5 Revolutionary Suite Features (Qadha-e-Umri, Brand Battery Wizard, Post-Adhan Dua)
        _buildSectionHeader(AppLocale.t(ur: '🌟 خصوصی سمارٹ فیچرز (Smart Suite)', en: '🌟 Revolutionary Smart Suite')),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              // Qadha-e-Umri Ledger Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment_turned_in, color: AppTheme.emerald),
                ),
                title: Text(
                  AppLocale.t(ur: 'نماز ٹریکر و قضاءِ عمری رجسٹر', en: 'Salah Tracker & Qadha-e-Umri Ledger'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'زندگی بھر کی قضاء نمازوں کا حساب، خودکار تخمینہ، اور ادائیگی کا ڈیجیٹل ریکارڈ',
                    en: 'Lifetime missed prayers calculator, estimate wizard, and digital progress tracking.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const QadhaUmriScreen()),
                  );
                },
              ),
              Divider(color: AppTheme.border, height: 16),

              // Mobile OEM Autostart Battery Wizard Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.battery_charging_full, color: AppTheme.gold),
                ),
                title: Text(
                  AppLocale.t(ur: 'موبائل برانڈ وزرڈ (Xiaomi / Vivo / Oppo / Samsung)', en: 'OEM Autostart & Battery Wizard'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'الارم اور اذان کو بیٹری آپٹیمائزیشن سے محفوظ رکھنے کے لیے خودکار رہنمائی',
                    en: 'Ensure 100% reliable alarms and notifications across all device brands.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  BrandBatteryHelper.showBrandGuidanceDialog(context);
                },
              ),
              Divider(color: AppTheme.border, height: 16),

              // Post-Adhan Masnoon Dua Preview Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.sky.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book, color: AppTheme.sky),
                ),
                title: Text(
                  AppLocale.t(ur: 'اذان کے بعد کی مسنون دعا کارڈ', en: 'Post-Adhan Masnoon Dua Card'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'الارم بند کرنے پر مسنون دعا، ترجمہ اور شفاعت کی فضیلت کا کارڈ دیکھیں',
                    en: 'Displays after alarm dismissal with Arabic, translation and Wasilah virtue.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.visibility_outlined, size: 20),
                onTap: () {
                  PostAdhanDuaDialog.show(context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Time Format Card
        _buildSectionHeader(AppLocale.t(ur: 'گھڑی کا فارمیٹ', en: 'Time Display Format')),
        Container(
          decoration: _cardDecoration(),
          child: SwitchListTile(
            title: Text(
              AppLocale.t(ur: '12 گھنٹے فارمیٹ (AM / PM)', en: '12-Hour Format (AM / PM)'),
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _settings.is12HourFormat
                  ? AppLocale.t(ur: 'فعال: وقت 12 گھنٹے کے ساتھ ظاہر ہوگا', en: 'Active: 12-Hour format enabled')
                  : AppLocale.t(ur: 'غیر فعال: 24 گھنٹے (فوجی وقت) ظاہر ہوگا', en: '24-Hour format enabled'),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            value: _settings.is12HourFormat,
            activeColor: AppTheme.emerald,
            onChanged: (val) {
              _settings.is12HourFormat = val;
              _notifyChange();
            },
          ),
        ),
        const SizedBox(height: 14),

        // 2.5 App Theme Mode Card (ڈارک موڈ اور لائٹ موڈ)
        _buildSectionHeader(AppLocale.t(ur: 'ڈارک موڈ و لائٹ موڈ (تھیم انتخاب)', en: 'App Theme (Dark / Light)')),
        Container(
          decoration: _cardDecoration(),
          child: ValueListenableBuilder<bool>(
            valueListenable: AppTheme.isDarkNotifier,
            builder: (context, isDark, _) {
              return SwitchListTile(
                title: Text(
                  AppLocale.t(ur: 'ڈارک تھیم (Dark Mode)', en: 'Dark Mode Theme'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isDark
                      ? AppLocale.t(ur: 'فعال: خوبصورت رات کا نائٹ موڈ آن ہے', en: 'Active: Luxury Midnight Navy Theme')
                      : AppLocale.t(ur: 'غیر فعال: پریمیم روشن سفید لائٹ موڈ آن ہے', en: 'Active: Crisp Minimalist Light Theme'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                value: isDark,
                activeColor: AppTheme.emerald,
                onChanged: (val) {
                  AppTheme.toggle();
                  _notifyChange();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // 3. Asr Juristic Method
        _buildSectionHeader(AppLocale.t(ur: 'فقہی طریقۂ عصر', en: 'Asr Juristic Method')),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              RadioListTile<int>(
                value: 2,
                groupValue: _settings.asrMethod,
                title: Text(
                  AppLocale.t(ur: 'فقہ حنفی (مثلِ ثانی - سایہ دو گنا)', en: 'Hanafi (Shadow factor 2)'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: 'پاکستان، بھارت، بنگلہ دیش اور ترکی میں رائج معیار', en: 'Standard in South Asia & Turkey'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                activeColor: AppTheme.emerald,
                onChanged: (val) {
                  if (val != null) {
                    _settings.asrMethod = val;
                    _notifyChange();
                  }
                },
              ),
              Divider(color: AppTheme.cardBorder),
              RadioListTile<int>(
                value: 1,
                groupValue: _settings.asrMethod,
                title: Text(
                  AppLocale.t(ur: 'جمہور ائمہ: شافعی، مالکی، حنبلی (مثلِ اول)', en: 'Shafi\'i / Maliki / Hanbali (Factor 1)'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: 'سایہ ایک گنا ہونے پر عصر کی ابتداء', en: 'Beginning when shadow equals object length'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                activeColor: AppTheme.emerald,
                onChanged: (val) {
                  if (val != null) {
                    _settings.asrMethod = val;
                    _notifyChange();
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5. Adhan Tone & Prayer Reminders Card
        _buildSectionHeader(AppLocale.t(ur: 'اذان و الارم کی ترتیبات', en: 'Adhan & Alarm Tone')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.t(
                        ur: 'منتخب اذان: ${AlarmService().currentTone['name_ur'] ?? 'مکہ مکرمہ'}',
                        en: 'Active Tone: ${AlarmService().currentTone['name_en'] ?? 'Makkah'}',
                      ),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppLocale.t(
                  ur: '5 مستند آف لائن اذانیں بنڈل ہیں جنہیں بغیر انٹرنیٹ فوراً سنا اور سیٹ کیا جا سکتا ہے۔',
                  en: '5 authentic offline Adhans bundled for instant preview and alarm reminders.',
                ),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.music_note, size: 20),
                  label: Text(
                    AppLocale.t(ur: 'اذان سنیں اور سیٹ کریں', en: 'Preview & Set Adhan Tone'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    AlarmService.showAlarmDialog(context, () {
                      _notifyChange();
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5.5 Tahajjud Alarm Card
        _buildSectionHeader(AppLocale.t(ur: 'نمازِ تہجد الارم (صبحِ صادق سے قبل)', en: 'Tahajjud Alarm (Before Dawn)')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.emerald,
                title: Text(
                  AppLocale.t(ur: 'تہجد الارم فعال کریں', en: 'Enable Tahajjud Alarm'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'صبح صادق (فجر ابتداء) سے منتخب منٹ قبل خودکار بیدار کرے گا',
                    en: 'Wakes you up selected minutes before Subh Sadiq / Fajr start',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                value: _settings.tahajjudAlarmEnabled,
                onChanged: (val) {
                  _settings.tahajjudAlarmEnabled = val;
                  AlarmService.scheduleBackgroundPrayerAlarms();
                  _notifyChange();
                },
              ),
              if (_settings.tahajjudAlarmEnabled) ...[
                const SizedBox(height: 10),
                Text(
                  AppLocale.t(ur: 'کتنے منٹ قبل الارم بولے:', en: 'Minutes before Fajr start:'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [20, 30, 40, 60].map((m) {
                    final bool isSel = (_settings.tahajjudMinutesBefore == m);
                    final label = m == 60
                        ? (AppLocale.isUrdu ? '1 گھنٹہ' : '1 Hour')
                        : '$m ${AppLocale.t(ur: 'منٹ', en: 'min')}';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: InkWell(
                          onTap: () {
                            _settings.tahajjudMinutesBefore = m;
                            AlarmService.scheduleBackgroundPrayerAlarms();
                            _notifyChange();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isSel ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSel ? Colors.white : (AppTheme.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 6. Home Screen Widget & Quick Solar Clock Card
        _buildSectionHeader(AppLocale.t(ur: '🏛️ دیدہ زیب کلاک و موبائل ہوم سکرین وزٹ (Home Widget)', en: '🏛️ Clock & Mobile Home Screen Widget')),
        _buildHomeScreenWidgetCard(),
      ],
    );
  }

  Widget _buildHomeScreenWidgetCard() {
    final themes = [
      {
        'key': 'midnight_gold',
        'nameUr': 'نور و وقار (سکون)',
        'nameEn': 'Midnight Gold',
        'bg': const Color(0xFF0F172A),
        'border': const Color(0xFFF59E0B),
        'clock': Colors.white,
        'title': const Color(0xFFFDE68A),
      },
      {
        'key': 'emerald',
        'nameUr': 'زمردی سکون',
        'nameEn': 'Emerald Forest',
        'bg': const Color(0xFF064E3B),
        'border': const Color(0xFF10B981),
        'clock': Colors.white,
        'title': const Color(0xFF34D399),
      },
      {
        'key': 'pure_black',
        'nameUr': 'بلوری نقرئی OLED',
        'nameEn': 'OLED Silver',
        'bg': Colors.black,
        'border': const Color(0xFF94A3B8),
        'clock': Colors.white,
        'title': const Color(0xFFE2E8F0),
      },
      {
        'key': 'warm_amber',
        'nameUr': 'شفق و عنبر',
        'nameEn': 'Warm Amber',
        'bg': const Color(0xFF1C1917),
        'border': const Color(0xFFEA580C),
        'clock': Colors.white,
        'title': const Color(0xFFFDE68A),
      },
    ];

    final currentTheme = themes.firstWhere(
      (t) => t['key'] == _settings.widgetTheme,
      orElse: () => themes.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_outlined, color: AppTheme.gold, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocale.t(
                    ur: 'موبائل ہوم اسکرین و لاک اسکرین وزٹ',
                    en: 'Home & Lock Screen Clock Widget',
                  ),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocale.t(
              ur: 'موبائل کی ہوم اسکرین پر المیقات کا دیدہ زیب کلاک سیٹ کریں تاکہ ایپ کھولے بغیر لائیو کلاک اور اگلی نماز کا وقت دکھائی دیتا رہے، اور کلاک پر کلک کرنے سے ایک ہی لائن میں پورا بصری راستہ ظاہر ہو۔',
              en: 'Place Meeqat clock directly onto your phone launcher to see live clock & next prayer without opening the app, and tap to view the full solar arc.',
            ),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),

          // 1. One-Tap Add to Home Screen Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              icon: const Icon(Icons.add_to_home_screen, size: 22),
              label: Text(
                AppLocale.t(
                  ur: '📲 موبائل کی ہوم اسکرین پر کلاک لگائیں',
                  en: '📲 Add Clock Widget to Home Screen',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _showWidgetConfirmationDialog,
            ),
          ),

          const SizedBox(height: 14),

          // 2. Theme Selection
          Text(
            AppLocale.t(ur: 'کلاک کا جدید تھیم اور رنگ منتخب کریں:', en: 'Choose Clock Widget Theme:'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: themes.map((t) {
              final bool isSel = _settings.widgetTheme == t['key'];
              return InkWell(
                onTap: () {
                  _settings.widgetTheme = t['key'] as String;
                  const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
                  channel.invokeMethod('setWidgetTheme', {
                    'theme': _settings.widgetTheme,
                    'layout': _settings.widgetLayout,
                  });
                  _notifyChange();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t['bg'] as Color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? AppTheme.gold : (t['border'] as Color).withValues(alpha: 0.6),
                      width: isSel ? 2.2 : 1.2,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: (t['border'] as Color).withValues(alpha: 0.4), blurRadius: 6)]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t['clock'] as Color,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocale.t(ur: t['nameUr'] as String, en: t['nameEn'] as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSel)
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // 3. Layout Mode Selection
          Text(
            AppLocale.t(ur: 'وجٹ لے آؤٹ انداز:', en: 'Widget Display Style:'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildWidgetLayoutChip(
                  keyId: 'toggle',
                  labelUr: 'چھتری نما (کلک پر پھیلے)',
                  labelEn: 'Umbrella (Tap)',
                  icon: Icons.touch_app,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildWidgetLayoutChip(
                  keyId: 'always_on',
                  labelUr: 'مستقل چھتری (کھلا رہے)',
                  labelEn: 'Always Umbrella',
                  icon: Icons.view_quilt,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildWidgetLayoutChip(
                  keyId: 'circular',
                  labelUr: 'گول کلاک (Circular)',
                  labelEn: 'Circular Ring',
                  icon: Icons.circle_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Live Visual Preview in App (Transparent Background with Theme Typography & Umbrella Animation)
          Text(
            AppLocale.t(
              ur: 'لائیو پریویو (کلک کر کے چھتری کی طرح اوقات پھیلنے کا مظاہرہ دیکھیں):',
              en: 'Live Preview (Tap to see umbrella expansion):',
            ),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              if (_settings.widgetLayout != 'circular') {
                setState(() {
                  _previewExpanded = !_previewExpanded;
                });
              }
            },
            borderRadius: BorderRadius.circular(_settings.widgetLayout == 'circular' ? 100 : 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), // Transparent glass backdrop
                borderRadius: BorderRadius.circular(_settings.widgetLayout == 'circular' ? 100 : 18),
                border: Border.all(
                  color: (currentTheme['border'] as Color).withValues(alpha: 0.8),
                  width: _settings.widgetLayout == 'circular' ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (currentTheme['border'] as Color).withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _settings.widgetLayout == 'circular'
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x4D000000), // Frosted glass clock capsule
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '04:30',
                                style: TextStyle(
                                  color: currentTheme['clock'] as Color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 44,
                                  letterSpacing: 1.0,
                                  shadows: const [
                                    Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '45',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      shadows: [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                    ),
                                  ),
                                  Text(
                                    'PM',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                      shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocale.t(ur: 'اگلی نماز: مغرب 05:45', en: 'Next: Maghrib 05:45'),
                            style: TextStyle(
                              fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                              color: currentTheme['title'] as Color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Central Row: Left Wing (Isha, Maghrib) + Master Clock Capsule + Right Wing (Fajr, Sunrise)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Wing (West/Night: Isha on top, Maghrib on bottom, tightly spaced)
                            if (_settings.widgetLayout == 'always_on' || _previewExpanded)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildWingPrayerChip('عشاء', '07:15', isVertical: true),
                                  _buildWingPrayerChip('مغرب', '05:45', isVertical: true, isHighlighted: true),
                                ],
                              ),
                            if (_settings.widgetLayout == 'always_on' || _previewExpanded)
                              const SizedBox(width: 3),

                            // Center: Master Unified Frosted Glass Clock Capsule
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0x59000000), // Frosted glass clock capsule
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '04:30',
                                        style: TextStyle(
                                          color: currentTheme['clock'] as Color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 44,
                                          letterSpacing: 1.0,
                                          shadows: const [
                                            Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 5),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '45',
                                            style: TextStyle(
                                              color: Color(0xFFFDE68A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              shadows: [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                            ),
                                          ),
                                          Text(
                                            'PM',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                              shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppLocale.t(ur: 'اگلی نماز: مغرب 05:45', en: 'Next: Maghrib 05:45'),
                                        style: TextStyle(
                                          fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                                          color: currentTheme['title'] as Color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (_settings.widgetLayout == 'always_on' || _previewExpanded) ? '▴' : '▾',
                                        style: TextStyle(
                                          color: currentTheme['title'] as Color,
                                          fontSize: 11,
                                          shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1.5), blurRadius: 4)],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (_settings.widgetLayout == 'always_on' || _previewExpanded)
                              const SizedBox(width: 3),
                            // Right Wing (East/Morning: Fajr on top, Sunrise on bottom, tightly spaced)
                            if (_settings.widgetLayout == 'always_on' || _previewExpanded)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildWingPrayerChip('فجر', '05:14', isVertical: true),
                                  _buildWingPrayerChip('طلوع', '06:32', isVertical: true),
                                ],
                              ),
                          ],
                        ),

                        // Bottom Row: 3 Separate Compact Capsules in Strict RTL (عصر far left, ظہر center, نصف النہار far right)
                        if (_settings.widgetLayout == 'always_on' || _previewExpanded) ...[
                          const SizedBox(height: 3),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Rightmost: نصف النہار
                                _buildWingPrayerChip('نصف النہار', '11:58'),
                                const SizedBox(width: 3),
                                // Center: ظہر
                                _buildWingPrayerChip('ظہر', '12:15'),
                                const SizedBox(width: 3),
                                // Leftmost: عصر
                                _buildWingPrayerChip('عصر', '04:30'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetLayoutChip({
    required String keyId,
    required String labelUr,
    required String labelEn,
    required IconData icon,
  }) {
    final bool isSel = _settings.widgetLayout == keyId;
    return InkWell(
      onTap: () {
        _settings.widgetLayout = keyId;
        const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
        channel.invokeMethod('setWidgetTheme', {
          'theme': _settings.widgetTheme,
          'layout': keyId,
        });
        _notifyChange();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSel ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSel ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                AppLocale.t(ur: labelUr, en: labelEn),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSel ? Colors.white : (AppTheme.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWingPrayerChip(String name, String time, {bool isVertical = false, bool isHighlighted = false}) {
    final Color labelCol = isHighlighted ? const Color(0xFF34D399) : const Color(0xFFFDE68A);
    final Color timeCol = isHighlighted ? const Color(0xFF34D399) : Colors.white;
    return Container(
      margin: EdgeInsets.symmetric(vertical: isVertical ? 1.5 : 0, horizontal: isVertical ? 0 : 1.5),
      padding: EdgeInsets.symmetric(horizontal: isVertical ? 7 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x52000000), // Frosted obsidian glass
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.0),
      ),
      child: isVertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                    color: labelCol,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                    color: timeCol,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                    color: labelCol,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                    color: timeCol,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
              ],
            ),
    );
  }

  void _showWidgetConfirmationDialog() {
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
      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
      await channel.invokeMethod('setWidgetTheme', {
        'theme': _settings.widgetTheme,
        'layout': _settings.widgetLayout,
      });
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

  // ==========================================
  // TAB 2: MOSQUES & JAMA'AT CONGREGATION TIMES
  // ==========================================
  Widget _buildMosquesTab() {
    final mosques = _settings.savedMosques;
    final active = _settings.activeMosque;

    // Compute dynamic Jama'at times based on current city astronomical times
    final engine = AstronomicalEngine(
      latitude: widget.currentCity.latitude,
      longitude: widget.currentCity.longitude,
      timeZone: widget.currentCity.timezone,
      asrJuristic: _settings.asrMethod,
      elevation: widget.currentCity.elevation,
      fajrMode: _settings.fajrMode,
      fajrDegree: _settings.fajrDegree,
      fajrIntervalMin: _settings.fajrIntervalMin,
      ishaMode: _settings.ishaMode,
      ishaDegree: _settings.ishaDegree,
      ishaIntervalMin: _settings.ishaIntervalMin,
      is12HourFormat: _settings.is12HourFormat,
    );
    final detailed = engine.calculateDetailedTimes(DateTime.now());
    final dynamicJamaat = _settings.calculateDynamicJamaat(detailedTimes: detailed);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 0. Mosque Mohalla Connect (Web Panel + App Auto-Sync)
        _buildSectionHeader(AppLocale.t(ur: '🌐 مسجد محلہ کنیکٹ (Auto-Sync)', en: '🌐 Mosque Mohalla Connect')),
        _buildMosqueMohallaConnectCard(active),
        const SizedBox(height: 16),

        // Display Mode Switcher
        _buildSectionHeader(AppLocale.t(ur: 'ڈسپلے بورڈ کے اوقات کا انتخاب', en: 'Mosque Display Mode')),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              _buildDisplayModeBtn(mode: 'BEGINNING', labelUr: 'ابتدائی اوقات (نماز)', labelEn: 'Beginning Times'),
              _buildDisplayModeBtn(mode: 'JAMAAT', labelUr: 'جماعت کے اوقات (مسجد)', labelEn: 'Jama\'at Times'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Mosque Details Card
        _buildSectionHeader(AppLocale.t(ur: 'فعال جامع مسجد', en: 'Active Mosque')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '🕌 ${active.name}',
                      style: TextStyle(color: AppTheme.gold, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: AppTheme.emerald),
                    onPressed: () => _showEditMosqueDialog(active),
                  ),
                ],
              ),
              if (active.address.isNotEmpty)
                Text(active.address, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Divider(color: AppTheme.cardBorder, height: 20),
              _buildJamaatRow('فجر جماعت:', 'Fajr Jama\'at:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['fajr'] ?? active.fajrJamaat) : active.fajrJamaat),
              _buildJamaatRow('ظہر جماعت:', 'Dhuhr Jama\'at:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['dhuhr'] ?? active.dhuhrJamaat) : active.dhuhrJamaat),
              _buildJamaatRow('عصر جماعت:', 'Asr Jama\'at:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['asr'] ?? active.asrJamaat) : active.asrJamaat),
              _buildJamaatRow('مغرب جماعت:', 'Maghrib Jama\'at:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['maghrib'] ?? active.maghribJamaat) : active.maghribJamaat),
              _buildJamaatRow('عشاء جماعت:', 'Isha Jama\'at:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['isha'] ?? active.ishaJamaat) : active.ishaJamaat),
              _buildJamaatRow('نماز جمعہ:', 'Friday Jumu\'ah:', _settings.useAutoDynamicJamaat ? (dynamicJamaat['jumuah'] ?? active.jumuahTime) : active.jumuahTime, isJumuah: true),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.auto_mode, color: _settings.useAutoDynamicJamaat ? AppTheme.emerald : AppTheme.textSecondary),
                title: Text(
                  AppLocale.t(ur: 'خودکار فلکیاتی جماعت فارمولا', en: 'Auto Dynamic Jama\'at Formula'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                subtitle: Text(
                  _settings.useAutoDynamicJamaat
                      ? AppLocale.t(
                          ur: 'فعال: فجر، عصر، مغرب اور عشاء فلکیاتی فارمولے کے مطابق خودکار بدلیں گے',
                          en: 'Active: Fajr, Asr, Maghrib, and Isha adapt automatically.',
                        )
                      : AppLocale.t(
                          ur: 'غیر فعال: آپ کے سیٹ کردہ دستی اوقات ہی ڈسپلے اور ایپ میں نافذ رہیں گے',
                          en: 'Disabled: Your manual saved mosque times are displayed.',
                        ),
                  style: TextStyle(color: _settings.useAutoDynamicJamaat ? AppTheme.emerald : AppTheme.textSecondary, fontSize: 11),
                ),
                value: _settings.useAutoDynamicJamaat,
                activeColor: AppTheme.emerald,
                onChanged: (val) {
                  _settings.useAutoDynamicJamaat = val;
                  _notifyChange();
                },
              ),
              if (_settings.useAutoDynamicJamaat) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      AppLocale.t(
                        ur: 'خودکار فارمولا کے اوقات و منٹس سیٹ کریں',
                        en: 'Configure Dynamic Formula Rules',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _showDynamicFormulaDialog(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Saved Mosques List & Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(AppLocale.t(ur: 'تمام محفوظ مساجد (${mosques.length})', en: 'All Mosques (${mosques.length})')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocale.t(ur: 'نئی مسجد', en: 'Add Mosque')),
              onPressed: () => _showAddMosqueDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...mosques.asMap().entries.map((entry) {
          final int idx = entry.key;
          final MosqueModel m = entry.value;
          final bool isSelected = idx == _settings.activeMosqueIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.emerald : AppTheme.cardBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ListTile(
              leading: Icon(Icons.mosque, color: isSelected ? AppTheme.emerald : AppTheme.textSecondary),
              title: Text(m.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(m.address, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              trailing: isSelected
                  ? Chip(
                      label: const Text('فعال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      backgroundColor: AppTheme.emerald,
                    )
                  : TextButton(
                      child: Text(AppLocale.t(ur: 'منتخب کریں', en: 'Select'), style: TextStyle(color: AppTheme.gold)),
                      onPressed: () {
                        _settings.setActiveMosque(idx);
                        _notifyChange();
                      },
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMosqueMohallaConnectCard(MosqueModel active) {
    final bool hasCode = active.code.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5)),
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
                  Icon(Icons.wifi_tethering, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppLocale.t(ur: 'محلہ کنیکٹ اسٹیٹس', en: 'Mohalla Connect Status'),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasCode ? AppTheme.emerald.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: hasCode ? AppTheme.emerald : Colors.orange),
                ),
                child: Text(
                  hasCode
                      ? '${AppLocale.t(ur: 'منسلک:', en: 'Linked:')} ${active.code}'
                      : AppLocale.t(ur: 'غیر منسلک (آف لائن)', en: 'Unlinked (Local)'),
                  style: TextStyle(
                    color: hasCode ? AppTheme.emerald : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocale.t(
              ur: 'امام صاحب کے ویب پورٹل سے جماعت کے اوقات کو خودکار سنک کریں۔ اپنے محلے کی مسجد کا کوڈ درج کر کے منسلک ہوں۔',
              en: 'Auto-sync congregation times directly from Imam\'s web panel using your neighborhood mosque code.',
            ),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔒 ', style: TextStyle(fontSize: 15)),
                Expanded(
                  child: Text(
                    AppLocale.t(
                      ur: 'مسجد کوڈ مستقل ہے اور کبھی تبدیل نہیں ہو گا۔ اوقات تبدیل کرنے کا اختیار صرف اکاؤنٹ ہولڈر (امام صاحب) کے خفیہ پاس کوڈ کے پاس ہے۔',
                      en: 'Mosque code is permanent and unchangeable. Only the authorized Imam with secret passcode can modify timings.',
                    ),
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (active.notice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📢 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      active.notice,
                      style: TextStyle(
                        fontFamily: AppLocale.isUrdu ? 'Jameel Noori Nastaleeq' : null,
                        color: AppTheme.emerald,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons: Follower Sync, Enter Code, Imam Update, Register Mosque
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(
                    AppLocale.t(ur: 'آن لائن سنک', en: 'Sync Times'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocale.t(ur: 'مسجد کے تازہ ترین اوقات سنک ہو رہے ہیں...', en: 'Syncing latest mosque times...')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    final success = await MosqueSyncService().syncActiveMosqueTimes();
                    if (!mounted) return;
                    _notifyChange();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? AppLocale.t(ur: '✅ جماعت کے اوقات کامیابی سے سنک ہو گئے!', en: '✅ Mosque congregation times updated!')
                              : AppLocale.t(ur: 'سنک مکمل، اوقات پہلے سے اپ ٹو ڈیٹ ہیں۔', en: 'Times are already up to date.'),
                        ),
                        backgroundColor: success ? AppTheme.emerald : Colors.blueGrey,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                  side: BorderSide(color: AppTheme.gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
                icon: const Icon(Icons.pin, size: 18),
                label: Text(
                  AppLocale.t(ur: 'کوڈ درج کریں', en: 'Enter Code'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _showLinkMosqueCodeDialog(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.security, size: 17),
                  label: Text(
                    AppLocale.t(ur: 'امام لاگ ان (اوقات اپڈیٹ)', en: 'Imam Mode (Update)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _showImamUpdateDialog(active),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFDE68A),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.app_registration, size: 17),
                  label: Text(
                    AppLocale.t(ur: 'نئی مسجد رجسٹریشن', en: 'Register Mosque'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _showRegisterNewMosqueDialog(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: Icon(Icons.open_in_browser, size: 16, color: AppTheme.textSecondary),
              label: Text(
                AppLocale.t(ur: 'امام صاحب کے لیے ویب پورٹل (meeqat.mamfss.com)', en: 'Imam Portal (meeqat.mamfss.com)'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, decoration: TextDecoration.underline),
              ),
              onPressed: () => _launchUrl('https://meeqat.mamfss.com/imam_portal.php'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkMosqueCodeDialog() {
    final controller = TextEditingController(text: _settings.activeMosque.code);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocale.t(ur: 'محلہ مسجد کوڈ درج کریں (مقتدی موڈ)', en: 'Enter Mosque Code (Worshipper Mode)'),
          style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Text(
                AppLocale.t(
                  ur: '⚠️ مسجد کا کوڈ مستقل اور ناقابلِ تبدیلی ہوتا ہے۔ ایک بار کوڈ ملا لیں تو ایپ خودکار تازہ ترین اوقات سنک رکھے گی۔',
                  en: '⚠️ Mosque code is permanent and unchangeable. Once linked, the app auto-syncs live prayer times.',
                ),
                style: TextStyle(color: AppTheme.gold, fontSize: 11.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocale.t(
                ur: 'مسجد کے نوٹس بورڈ یا امام صاحب سے حاصل کردہ کوڈ (مثلاً MQ-78601) درج کریں:',
                en: 'Enter the permanent mosque code (e.g. MQ-78601) displayed in your local mosque:',
              ),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 2),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'MQ-78601',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.emerald, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocale.t(ur: 'کوڈ کی تصدیق کی جا رہی ہے...', en: 'Verifying mosque code...'))),
                );
                final linked = await MosqueSyncService().linkMosqueByCode(code);
                if (!mounted) return;
                _notifyChange();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      linked
                          ? AppLocale.t(ur: '✅ مسجد کامیابی کے ساتھ منسلک ہو گئی!', en: '✅ Mosque linked successfully!')
                          : AppLocale.t(ur: 'مسجد کوڈ نہیں ملا، ازراہِ کرم دوبارہ چیک کریں۔', en: 'Mosque code not found. Please verify.'),
                    ),
                    backgroundColor: linked ? AppTheme.emerald : Colors.red,
                  ),
                );
              }
            },
            child: Text(AppLocale.t(ur: 'منسلک کریں', en: 'Connect')),
          ),
        ],
      ),
    );
  }

  void _showImamUpdateDialog(MosqueModel active) {
    final pinCtrl = TextEditingController(text: '1234');
    final fajrCtrl = TextEditingController(text: active.fajrJamaat.replaceAll(RegExp(r' [AP]M'), ''));
    final dhuhrCtrl = TextEditingController(text: active.dhuhrJamaat.replaceAll(RegExp(r' [AP]M'), ''));
    final asrCtrl = TextEditingController(text: active.asrJamaat.replaceAll(RegExp(r' [AP]M'), ''));
    final maghribCtrl = TextEditingController(text: active.maghribJamaat.replaceAll(RegExp(r' [AP]M'), ''));
    final ishaCtrl = TextEditingController(text: active.ishaJamaat.replaceAll(RegExp(r' [AP]M'), ''));
    final jumuahCtrl = TextEditingController(text: active.jumuahTime.replaceAll(RegExp(r' [AP]M'), ''));
    final noticeCtrl = TextEditingController(text: active.notice);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocale.t(ur: 'امام پورٹل: جماعت کے اوقات تبدیل کریں', en: 'Imam Portal: Update Jama\'at Times'),
                style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Text(
                  AppLocale.t(
                    ur: 'مسجد: ${active.name} (${active.code.isNotEmpty ? active.code : 'MQ-78601'})\nصرف مجاز امام صاحب ہی پاس کوڈ لگا کر اوقات کلاؤڈ پر نشر کر سکتے ہیں۔',
                    en: 'Mosque: ${active.name}\nOnly authorized Imam with passcode can publish updates.',
                  ),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                style: TextStyle(color: AppTheme.textPrimary, letterSpacing: 4, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'امام صاحب کا خفیہ پاس کوڈ (PIN)', en: 'Secret Imam Passcode (PIN)'),
                  labelStyle: TextStyle(color: AppTheme.gold, fontSize: 13),
                  hintText: '****',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fajrCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'فجر', en: 'Fajr'),
                        hintText: '05:15',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: dhuhrCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'ظہر', en: 'Dhuhr'),
                        hintText: '01:15',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: asrCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'عصر', en: 'Asr'),
                        hintText: '04:30',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: maghribCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'مغرب', en: 'Maghrib'),
                        hintText: '05:45',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ishaCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'عشاء', en: 'Isha'),
                        hintText: '07:30',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: jumuahCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'جمعہ', en: 'Jumu\'ah'),
                        hintText: '01:30',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noticeCtrl,
                maxLines: 2,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'محلے کے لیے اعلان (اختیاری)', en: 'Mosque Announcement (Optional)'),
                  hintText: 'مثلاً: کل سے عشاء کی جماعت 7:45 پر ہوگی',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.cloud_upload, size: 18),
            label: Text(AppLocale.t(ur: 'کلاؤڈ پر نشر کریں', en: 'Publish Live')),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocale.t(ur: 'پاس کوڈ درج کرنا لازمی ہے', en: 'Passcode is required'))),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocale.t(ur: 'اوقات کلاؤڈ پر اپ ڈیٹ ہو رہے ہیں...', en: 'Publishing times to cloud...'))),
              );

              final res = await MosqueSyncService().updateMosqueJamaatTimes(
                mosqueId: active.code.isNotEmpty ? active.code : active.id,
                pin: pin,
                times: {
                  'fajr': fajrCtrl.text.trim(),
                  'dhuhr': dhuhrCtrl.text.trim(),
                  'asr': asrCtrl.text.trim(),
                  'maghrib': maghribCtrl.text.trim(),
                  'isha': ishaCtrl.text.trim(),
                  'jumuah': jumuahCtrl.text.trim(),
                },
                notice: noticeCtrl.text.trim(),
              );

              if (!mounted) return;
              _notifyChange();

              final bool ok = res['success'] == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['message']?.toString() ?? ''),
                  backgroundColor: ok ? AppTheme.emerald : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRegisterNewMosqueDialog() {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: widget.currentCity.nameUr.isNotEmpty ? widget.currentCity.nameUr : widget.currentCity.name);
    final areaCtrl = TextEditingController();
    final imamCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.app_registration, color: Color(0xFFFDE68A), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocale.t(ur: 'نئی مسجد رجسٹریشن (مستقل کوڈ)', en: 'Register Mosque (Permanent Code)'),
                style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  AppLocale.t(
                    ur: '⚠️ رجسٹریشن پر آپ کی مسجد کو ایک دائمی کوڈ (جیسے MQ-78601) الاٹ ہو گا جو کبھی تبدیل نہیں ہو گا۔',
                    en: '⚠️ A permanent code (e.g. MQ-78601) will be issued which never changes.',
                  ),
                  style: TextStyle(color: AppTheme.gold, fontSize: 11.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'مسجد کا مکمل نام (اردو)', en: 'Mosque Full Name'),
                  hintText: 'مثلاً: جامع مسجد نورِ اسلام',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'شہر', en: 'City'),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: areaCtrl,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'محلہ / علاقہ', en: 'Mohalla / Area'),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imamCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'امام صاحب / متولی کا نام', en: 'Imam / Admin Name'),
                  hintText: 'مثلاً: مولانا عبد الرشید',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'فون / واٹس ایپ (اختیاری)', en: 'Phone / WhatsApp (Optional)'),
                  hintText: '0300-1234567',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                style: TextStyle(color: AppTheme.textPrimary, letterSpacing: 4, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: AppLocale.t(ur: 'خفیہ پاس کوڈ مقرر کریں (PIN)', en: 'Set Secret Passcode (PIN)'),
                  hintText: '****',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocale.t(ur: 'مسجد رجسٹر کریں', en: 'Register Mosque')),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final pin = pinCtrl.text.trim();
              if (name.isEmpty || pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocale.t(ur: 'مسجد کا نام اور پاس کوڈ لازمی ہیں', en: 'Mosque name and PIN required'))),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocale.t(ur: 'مسجد رجسٹر ہو رہی ہے...', en: 'Registering mosque...'))),
              );

              final res = await MosqueSyncService().registerMosque(
                nameUr: name,
                cityUr: cityCtrl.text.trim(),
                area: areaCtrl.text.trim(),
                imamName: imamCtrl.text.trim(),
                pin: pin,
                phone: phoneCtrl.text.trim(),
              );

              if (!mounted) return;
              _notifyChange();

              final bool ok = res['success'] == true;
              if (ok) {
                final code = res['code']?.toString() ?? '';
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: AppTheme.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      AppLocale.t(ur: '🎉 مبارک ہو! مسجد رجسٹر ہو گئی', en: '🎉 Mosque Registered!'),
                      style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocale.t(
                            ur: 'آپ کی مسجد کا مستقل اور ناقابلِ تبدیلی کوڈ ہے:',
                            en: 'Your permanent and unchangeable mosque code is:',
                          ),
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.emerald, width: 2),
                          ),
                          child: SelectableText(
                            code,
                            style: TextStyle(
                              color: AppTheme.emerald,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppLocale.t(
                            ur: '⚠️ یہ کوڈ مستقل ہے اور کبھی تبدیل نہیں ہو گا۔ اپنے محلے کے نمازیوں کو یہ کوڈ فراہم کریں تاکہ وہ ایپ میں یہ کوڈ درج کر کے اوقات سنک کر سکیں۔',
                            en: '⚠️ This code is permanent and never changes. Share this code with your worshippers to auto-sync prayer times.',
                          ),
                          style: TextStyle(color: AppTheme.gold, fontSize: 12.5, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(dCtx),
                        child: Text(AppLocale.t(ur: 'سمجھ گیا', en: 'Got it')),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message']?.toString() ?? ''), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayModeBtn({required String mode, required String labelUr, required String labelEn}) {
    final bool isSelected = _settings.mosqueDisplayMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _settings.mosqueDisplayMode = mode;
          _notifyChange();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            AppLocale.t(ur: labelUr, en: labelEn),
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJamaatRow(String labelUr, String labelEn, String time, {bool isJumuah = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocale.t(ur: labelUr, en: labelEn),
            style: TextStyle(
              color: isJumuah ? AppTheme.gold : AppTheme.textSecondary,
              fontWeight: isJumuah ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: isJumuah ? AppTheme.gold : AppTheme.emerald,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: SAVED LOCATIONS (1 TO 100 LOCATIONS)
  // ==========================================
  Widget _buildSavedLocationsTab() {
    final locations = _settings.savedLocations;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocale.t(
                  ur: 'محفوظ شہر (${locations.length} / 100)',
                  en: 'Saved Locations (${locations.length} / 100)',
                ),
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 17, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_location_alt, size: 18),
                label: Text(AppLocale.t(ur: 'شہر شامل کریں', en: 'Add City')),
                onPressed: () async {
                  final added = await Navigator.push<CityModel>(
                    context,
                    MaterialPageRoute(builder: (c) => const GazetteerScreen()),
                  );
                  if (added != null) {
                    final success = _settings.addSavedLocation(added);
                    if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocale.t(ur: 'یہ شہر پہلے سے محفوظ ہے یا حد مکمل ہے', en: 'City already saved or limit reached'))),
                      );
                    }
                    _notifyChange();
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5.5 Tahajjud Alarm Card
        _buildSectionHeader(AppLocale.t(ur: 'نمازِ تہجد الارم (صبحِ صادق سے قبل)', en: 'Tahajjud Alarm (Before Dawn)')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.emerald,
                title: Text(
                  AppLocale.t(ur: 'تہجد الارم فعال کریں', en: 'Enable Tahajjud Alarm'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'صبح صادق (فجر ابتداء) سے منتخب منٹ قبل خودکار بیدار کرے گا',
                    en: 'Wakes you up selected minutes before Subh Sadiq / Fajr start',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                value: _settings.tahajjudAlarmEnabled,
                onChanged: (val) {
                  _settings.tahajjudAlarmEnabled = val;
                  AlarmService.scheduleBackgroundPrayerAlarms();
                  _notifyChange();
                },
              ),
              if (_settings.tahajjudAlarmEnabled) ...[
                const SizedBox(height: 10),
                Text(
                  AppLocale.t(ur: 'کتنے منٹ قبل الارم بولے:', en: 'Minutes before Fajr start:'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [20, 30, 40, 60].map((m) {
                    final bool isSel = (_settings.tahajjudMinutesBefore == m);
                    final label = m == 60
                        ? (AppLocale.isUrdu ? '1 گھنٹہ' : '1 Hour')
                        : '$m ${AppLocale.t(ur: 'منٹ', en: 'min')}';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: InkWell(
                          onTap: () {
                            _settings.tahajjudMinutesBefore = m;
                            AlarmService.scheduleBackgroundPrayerAlarms();
                            _notifyChange();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isSel ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSel ? Colors.white : (AppTheme.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: locations.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final city = locations[index];
              final qibla = QiblaCalculator.calculate(city.latitude, city.longitude);
              final bool isActive = city.name.toLowerCase() == widget.currentCity.name.toLowerCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppTheme.emerald : AppTheme.cardBorder,
                    width: isActive ? 1.8 : 1.0,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? AppTheme.emerald : AppTheme.surface,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : AppTheme.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(city.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text('(${city.country})', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${city.latitude.toStringAsFixed(2)}°, ${city.longitude.toStringAsFixed(2)}° | قبلہ: ${qibla['bearing']}° (${qibla['cardinal']})',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF10B981)),
                        tooltip: AppLocale.t(ur: 'فعال کریں', en: 'Set Active'),
                        onPressed: () {
                          _settings.setDefaultCity(city);
                          widget.onCityChanged?.call(city);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${city.name} ${AppLocale.t(ur: 'کو فعال منتخب کر لیا گیا ہے', en: 'set as active location')}')),
                          );
                          _notifyChange();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: AppLocale.t(ur: 'حذف کریں', en: 'Delete'),
                        onPressed: () {
                          _settings.removeSavedLocation(city.id);
                          _notifyChange();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: ISLAMIC EVENTS GALLERY & COUNTDOWN
  // ==========================================
  Widget _buildIslamicEventsTab() {
    final now = DateTime.now();
    final hijriNow = HijriCalendar.fromGregorian(now);
    final int hYear = hijriNow['year'] as int;

    // Canonical list of blessed Islamic Events
    final List<Map<String, dynamic>> canonicalEvents = [
      {'name_ur': 'معراج النبی ﷺ', 'name_en': 'Shab-e-Miraj', 'hMonth': 7, 'hDay': 27, 'icon': Icons.stars},
      {'name_ur': 'شبِ برات (لیلتہ النصف من شعبان)', 'name_en': 'Shab-e-Barat', 'hMonth': 8, 'hDay': 15, 'icon': Icons.nightlight_round},
      {'name_ur': 'آغازِ رمضان المبارک', 'name_en': '1st Ramadan (Fasting Begins)', 'hMonth': 9, 'hDay': 1, 'icon': Icons.brightness_3},
      {'name_ur': 'شبِ قدر (لیلتہ القدر)', 'name_en': 'Shab-e-Qadr', 'hMonth': 9, 'hDay': 27, 'icon': Icons.auto_awesome},
      {'name_ur': 'عید الفطر المبارک', 'name_en': 'Eid-ul-Fitr', 'hMonth': 10, 'hDay': 1, 'icon': Icons.celebration},
      {'name_ur': 'یومِ عرفہ (حج کا دن)', 'name_en': 'Day of Arafah (Hajj)', 'hMonth': 12, 'hDay': 9, 'icon': Icons.landscape},
      {'name_ur': 'عید الاضحیٰ المبارک (قربانی)', 'name_en': 'Eid-ul-Adha', 'hMonth': 12, 'hDay': 10, 'icon': Icons.pets},
      {'name_ur': 'یومِ عاشورہ (10 محرم)', 'name_en': 'Youm-e-Ashura', 'hMonth': 1, 'hDay': 10, 'icon': Icons.water_drop},
      {'name_ur': 'عید میلاد النبی ﷺ (12 ربیع الاول)', 'name_en': 'Eid Milad-un-Nabi', 'hMonth': 3, 'hDay': 12, 'icon': Icons.light_mode},
    ];

    final int currentHMonth = hijriNow['month'] as int;
    final int currentHDay = hijriNow['day'] as int;
    final int currentTotalHDay = currentHMonth * 30 + currentHDay;

    final List<Map<String, dynamic>> upcoming = [];
    final List<Map<String, dynamic>> past = [];

    for (var ev in canonicalEvents) {
      final int evTotal = (ev['hMonth'] as int) * 30 + (ev['hDay'] as int);
      if (evTotal >= currentTotalHDay) {
        final daysLeft = evTotal - currentTotalHDay;
        upcoming.add({...ev, 'daysLeft': daysLeft});
      } else {
        past.add(ev);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(AppLocale.t(ur: '⏳ آئندہ اسلامی ایام مع کاؤنٹ ڈاؤن', en: '⏳ Upcoming Events with Countdown')),
        ...upcoming.map((ev) {
          final int days = ev['daysLeft'] as int;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(ev['icon'] as IconData, color: const Color(0xFFF59E0B), size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocale.t(ur: ev['name_ur'] as String, en: ev['name_en'] as String),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ev['hDay']} ${HijriCalendar.getMonthName(ev['hMonth'] as int)} $hYear ہجری',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$days',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppLocale.t(ur: 'دن باقی', en: 'Days Left'),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        _buildSectionHeader(AppLocale.t(ur: '📜 امسال کے گزرے ہوئے ایام', en: '📜 Past Events of Current Year')),
        ...past.map((ev) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(ev['icon'] as IconData, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppLocale.t(ur: ev['name_ur'] as String, en: ev['name_en'] as String),
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${ev['hDay']} ${HijriCalendar.getMonthName(ev['hMonth'] as int)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // TAB 5: FAQ & ABOUT BRANDING SECTION
  // ==========================================
  Widget _buildFaqAndAboutTab() {
    final List<Map<String, String>> faqs = [
      {
        'q_ur': 'زوال اور نصف النہار شرعی میں کیا فرق ہے؟',
        'q_en': 'Difference between Zawal and Shar\'i Midday (Nisf-un-Nahar)?',
        'a_ur': 'نصف النہار شرعی صبحِ صادق (اختتام سحر) سے لے کر غروبِ آفتاب تک کے کل دورانیے کا نصف ہوتا ہے، جو کہ نفل روزے کی نیت کی آخری حد ہے۔ جب کہ زوال (وقتِ استواء) عین دوپہر سورج کے نصف النہار فلکی سے گزرنے کا وقت ہے جس میں 10 منٹ (سورج کے عین سر پر آنے سے 5 منٹ قبل اور 5 منٹ بعد) نماز پڑھنا ممنوع اور مکروہ ہے۔',
        'a_en': 'Shar\'i Midday is the exact midpoint between Subh Sadiq and Sunset. Zawal is the 10-minute Karahah period (5 minutes before and 5 minutes after solar zenith transit) during which prayer is forbidden.',
      },
      {
        'q_ur': 'شمسی سائے سے قبلہ معلوم کرنے کے زاویوں کا کیا مطلب ہے؟',
        'q_en': 'How do solar shadow angles determine Qibla?',
        'a_ur': '180 ڈگری کا مطلب ہے کہ لکڑی کا سایہ عین قبلہ کی لکیر پر بنتا ہے۔ 90 ڈگری کا مطلب ہے کہ سایہ قبلہ سے ٹھیک قائمہ (Right-angle) بناتا ہے، اس سائے کے متوازی کھینچی گئی لکیر مسجد میں نمازیوں کی سیدھی صف ہوگی۔ اور 135 ڈگری محراب اور کارنر کی درستگی کے لیے استعمال ہوتی ہے۔',
        'a_en': '180° aligns the shadow directly towards Kaaba. 90° provides the exact perpendicular line for prayer rows. 135° verifies diagonal corners and Mihrab.',
      },
      {
        'q_ur': 'قبلہ کمپاس کی درستگی کے لیے کیا احتیاط لازم ہے؟',
        'q_en': 'How to ensure maximum accuracy of Qibla Compass?',
        'a_ur': 'موبائل کو دھاتی اشیاء، مقناطیسی کور، اور بجلی کی تاروں سے دور رکھیں، اور اسے بالکل ہموار (Flat) حالت میں رکھ کر 8 کے ہندسے کی طرح گھما کر کیلیبریٹ کریں۔',
        'a_en': 'Keep phone away from metallic objects, magnets, and high voltage cables. Place flat on a level surface and calibrate by moving in a figure-8 motion.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(AppLocale.t(ur: '❓ اکثر پوچھے گئے سوالات (FAQ)', en: '❓ Frequently Asked Questions')),
        ...faqs.map((f) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _cardDecoration(),
            child: ExpansionTile(
              iconColor: AppTheme.gold,
              collapsedIconColor: AppTheme.textSecondary,
              title: Text(
                AppLocale.t(ur: f['q_ur']!, en: f['q_en']!),
                style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Text(
                    AppLocale.t(ur: f['a_ur']!, en: f['a_en']!),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _buildSectionHeader(AppLocale.t(ur: 'ℹ️ اباؤٹ و باضابطہ رابطہ (CodeHub & Mindcrafts AI)', en: 'ℹ️ About & Official Contact')),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5), width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🕌', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                AppLocale.t(ur: 'المیقات (Al-Meeqat)', en: 'Al-Meeqat v1.9.2'),
                style: TextStyle(color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'نسخہ: 1.9.2 (Version 1.9.2+34)',
                style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald.withValues(alpha: 0.18),
                  foregroundColor: AppTheme.emerald,
                  elevation: 0,
                  side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  AppLocale.t(ur: 'اپڈیٹ چیک کریں (Google Play)', en: 'Check for Updates (Google Play)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                onPressed: () => UpdateService.checkManually(context),
              ),
              const SizedBox(height: 12),
              // Project Founder Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocale.t(
                        ur: 'بانیِ پروجیکٹ',
                        en: 'Project Founder',
                      ),
                      style: TextStyle(
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.t(
                        ur: 'تنزیل الرحمن',
                        en: 'Tanzil-ur-Rehman',
                      ),
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocale.t(
                        ur: 'خادم جامع مسجد طوبیٰ (ارائیوں والی مسجد)\nمدرس مدرسہ اشرف المدارس فروکہ (سرگودھا)',
                        en: 'Khadim Jamia Masjid Tooba (Arain-wali Masjid)\nTeacher, Madrasa Ashraf-ul-Madaris, Farooka (Sargodha)',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocale.t(
                  ur: 'فلکیاتی و شرعی اوقاتِ صلوۃ، قبلہ گائیڈ، اور جامع مسجد ٹی وی ڈسپلے سوٹ\nایک باوقار مشترکہ کاوش از CodeHub اور Mindcrafts AI',
                  en: 'Astronomical & Shar\'i Prayer Suite, Qibla Guide, and Mosque TV Board\nA collaboration by CodeHub & Mindcrafts AI',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              Divider(color: AppTheme.cardBorder, height: 28),

              // Official Websites
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                    icon: const Icon(Icons.language, size: 16),
                    label: const Text('codehubb.com'),
                    onPressed: () => _launchUrl('https://codehubb.com'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                    ),
                    icon: const Icon(Icons.public, size: 16),
                    label: const Text('mindcraftsai.com'),
                    onPressed: () => _launchUrl('https://mindcraftsai.com'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Clickable WhatsApp Direct Contact
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.chat, size: 20),
                label: const Text(
                  'WhatsApp: 03023448246 (+923023448246)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => _launchWhatsApp('923023448246'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5.5 Tahajjud Alarm Card
        _buildSectionHeader(AppLocale.t(ur: 'نمازِ تہجد الارم (صبحِ صادق سے قبل)', en: 'Tahajjud Alarm (Before Dawn)')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.emerald,
                title: Text(
                  AppLocale.t(ur: 'تہجد الارم فعال کریں', en: 'Enable Tahajjud Alarm'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  AppLocale.t(
                    ur: 'صبح صادق (فجر ابتداء) سے منتخب منٹ قبل خودکار بیدار کرے گا',
                    en: 'Wakes you up selected minutes before Subh Sadiq / Fajr start',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                value: _settings.tahajjudAlarmEnabled,
                onChanged: (val) {
                  _settings.tahajjudAlarmEnabled = val;
                  AlarmService.scheduleBackgroundPrayerAlarms();
                  _notifyChange();
                },
              ),
              if (_settings.tahajjudAlarmEnabled) ...[
                const SizedBox(height: 10),
                Text(
                  AppLocale.t(ur: 'کتنے منٹ قبل الارم بولے:', en: 'Minutes before Fajr start:'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [20, 30, 40, 60].map((m) {
                    final bool isSel = (_settings.tahajjudMinutesBefore == m);
                    final label = m == 60
                        ? (AppLocale.isUrdu ? '1 گھنٹہ' : '1 Hour')
                        : '$m ${AppLocale.t(ur: 'منٹ', en: 'min')}';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: InkWell(
                          onTap: () {
                            _settings.tahajjudMinutesBefore = m;
                            AlarmService.scheduleBackgroundPrayerAlarms();
                            _notifyChange();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? AppTheme.emerald : (AppTheme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isSel ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSel ? Colors.white : (AppTheme.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // DIALOGS & SHEET HELPERS
  // ==========================================

  TimeOfDay _parseTimeOfDayString(String text, TimeOfDay fallback) {
    try {
      final t = text.trim();
      final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?$').firstMatch(t);
      if (match != null) {
        int h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final p = match.group(3)?.toUpperCase();
        if (p == 'PM' && h < 12) h += 12;
        if (p == 'AM' && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _pickClockTime(
    BuildContext ctx,
    TextEditingController controller,
    StateSetter setDialogState, {
    required TimeOfDay defaultTime,
    required String title,
  }) async {
    final initial = _parseTimeOfDayString(controller.text, defaultTime);
    final picked = await showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: title,
      cancelText: AppLocale.t(ur: 'منسوخ', en: 'Cancel'),
      confirmText: AppLocale.t(ur: 'منتخب', en: 'Select'),
      builder: (context, child) => Theme(
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
        child: Directionality(
          textDirection: AppLocale.textDirection,
          child: child!,
        ),
      ),
    );

    if (picked != null) {
      final h = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final m = picked.minute.toString().padLeft(2, '0');
      final p = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '${h.toString().padLeft(2, '0')}:$m $p';
      setDialogState(() {
        controller.text = formatted;
      });
    }
  }

  Widget _buildJamaatTimePickerTile({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required StateSetter setDialogState,
    required TimeOfDay defaultTime,
    IconData icon = Icons.access_time_rounded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => _pickClockTime(
          context,
          controller,
          setDialogState,
          defaultTime: defaultTime,
          title: '$label: ${AppLocale.t(ur: 'جماعت کا وقت منتخب کریں', en: "Select Jama'at Time")}',
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.emerald),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.text.isEmpty ? '--:-- --' : controller.text,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: AppTheme.emerald,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.edit_calendar_rounded, size: 14, color: AppTheme.emerald),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMosqueDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final fCtrl = TextEditingController(text: '05:30 AM');
    final dCtrl = TextEditingController(text: '01:30 PM');
    final aCtrl = TextEditingController(text: '04:45 PM');
    final mCtrl = TextEditingController(text: '05:45 PM');
    final iCtrl = TextEditingController(text: '07:45 PM');
    final jCtrl = TextEditingController(text: '01:45 PM');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.mosque, color: AppTheme.emerald, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.t(ur: 'نئی جامع مسجد شامل کریں', en: 'Add New Mosque'),
                      style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocale.t(ur: 'مسجد کا نام', en: 'Mosque Name'),
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.location_city, color: AppTheme.emerald, size: 20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: addrCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocale.t(ur: 'پتہ / محلہ / علاقہ', en: 'Address / Area'),
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.place, color: AppTheme.emerald, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 16, color: AppTheme.gold),
                          const SizedBox(width: 6),
                          Text(
                            AppLocale.t(
                              ur: 'نمازِ باجماعت اوقات (گھڑی سے منتخب کریں):',
                              en: "Jama'at Times (Tap to Pick from Clock):",
                            ),
                            style: TextStyle(color: AppTheme.gold, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'فجر جماعت', en: "Fajr Jama'at"),
                        controller: fCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 5, minute: 30),
                        icon: Icons.nightlight_round,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'ظہر جماعت', en: "Dhuhr Jama'at"),
                        controller: dCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 13, minute: 30),
                        icon: Icons.wb_sunny,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'عصر جماعت', en: "Asr Jama'at"),
                        controller: aCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 16, minute: 45),
                        icon: Icons.cloud,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'مغرب جماعت', en: "Maghrib Jama'at"),
                        controller: mCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 17, minute: 45),
                        icon: Icons.wb_twilight,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'عشاء جماعت', en: "Isha Jama'at"),
                        controller: iCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 19, minute: 45),
                        icon: Icons.bedtime,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'نمازِ جمعہ جماعت', en: "Jumu'ah Jama'at"),
                        controller: jCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 13, minute: 45),
                        icon: Icons.groups,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                  child: Text(AppLocale.t(ur: 'شامل کریں', en: 'Add')),
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      _settings.addMosque(
                        MosqueModel(
                          name: nameCtrl.text.trim(),
                          address: addrCtrl.text.trim(),
                          fajrJamaat: fCtrl.text.trim(),
                          dhuhrJamaat: dCtrl.text.trim(),
                          asrJamaat: aCtrl.text.trim(),
                          maghribJamaat: mCtrl.text.trim(),
                          ishaJamaat: iCtrl.text.trim(),
                          jumuahTime: jCtrl.text.trim(),
                        ),
                      );
                      Navigator.pop(ctx);
                      _notifyChange();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMosqueDialog(MosqueModel m) {
    final nameCtrl = TextEditingController(text: m.name);
    final addrCtrl = TextEditingController(text: m.address);
    final fCtrl = TextEditingController(text: m.fajrJamaat);
    final dCtrl = TextEditingController(text: m.dhuhrJamaat);
    final aCtrl = TextEditingController(text: m.asrJamaat);
    final mCtrl = TextEditingController(text: m.maghribJamaat);
    final iCtrl = TextEditingController(text: m.ishaJamaat);
    final jCtrl = TextEditingController(text: m.jumuahTime);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit_calendar_rounded, color: AppTheme.emerald, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.t(ur: 'جماعت کے اوقات کی تصحیح (کلاک سلیکٹر)', en: "Edit Jama'at Times (Clock Picker)"),
                      style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocale.t(ur: 'مسجد کا نام', en: 'Mosque Name'),
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.location_city, color: AppTheme.emerald, size: 20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: addrCtrl,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: AppLocale.t(ur: 'پتہ / محلہ / علاقہ', en: 'Address / Area'),
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.place, color: AppTheme.emerald, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 16, color: AppTheme.gold),
                          const SizedBox(width: 6),
                          Text(
                            AppLocale.t(
                              ur: 'نمازِ باجماعت اوقات (گھڑی سے منتخب کریں):',
                              en: "Jama'at Times (Tap to Pick from Clock):",
                            ),
                            style: TextStyle(color: AppTheme.gold, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'فجر جماعت', en: "Fajr Jama'at"),
                        controller: fCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 5, minute: 30),
                        icon: Icons.nightlight_round,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'ظہر جماعت', en: "Dhuhr Jama'at"),
                        controller: dCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 13, minute: 30),
                        icon: Icons.wb_sunny,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'عصر جماعت', en: "Asr Jama'at"),
                        controller: aCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 16, minute: 45),
                        icon: Icons.cloud,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'مغرب جماعت', en: "Maghrib Jama'at"),
                        controller: mCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 17, minute: 45),
                        icon: Icons.wb_twilight,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'عشاء جماعت', en: "Isha Jama'at"),
                        controller: iCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 19, minute: 45),
                        icon: Icons.bedtime,
                      ),
                      _buildJamaatTimePickerTile(
                        context: context,
                        label: AppLocale.t(ur: 'نمازِ جمعہ جماعت', en: "Jumu'ah Jama'at"),
                        controller: jCtrl,
                        setDialogState: setDlgState,
                        defaultTime: const TimeOfDay(hour: 13, minute: 45),
                        icon: Icons.groups,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                  child: Text(AppLocale.t(ur: 'اپڈیٹ کریں', en: 'Update')),
                  onPressed: () {
                    m.name = nameCtrl.text.trim();
                    m.address = addrCtrl.text.trim();
                    m.fajrJamaat = fCtrl.text.trim();
                    m.dhuhrJamaat = dCtrl.text.trim();
                    m.asrJamaat = aCtrl.text.trim();
                    m.maghribJamaat = mCtrl.text.trim();
                    m.ishaJamaat = iCtrl.text.trim();
                    m.jumuahTime = jCtrl.text.trim();
                    _settings.updateActiveMosque(m);
                    Navigator.pop(ctx);
                    _notifyChange();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDynamicFormulaDialog() {
    int fajrMin = _settings.fajrDynamicMinBeforeSunrise;
    int fajrMax = _settings.fajrDynamicMaxBeforeSunrise;
    int asrMin = _settings.asrDynamicMinAfter;
    int asrMax = _settings.asrDynamicMaxAfter;
    int maghribAfter = _settings.maghribDynamicAfter;
    int ishaMin = _settings.ishaDynamicMinAfter;
    int ishaMax = _settings.ishaDynamicMaxAfter;

    final fajrMinCtrl = TextEditingController(text: fajrMin.toString());
    final fajrMaxCtrl = TextEditingController(text: fajrMax.toString());
    final asrMinCtrl = TextEditingController(text: asrMin.toString());
    final asrMaxCtrl = TextEditingController(text: asrMax.toString());
    final maghribCtrl = TextEditingController(text: maghribAfter.toString());
    final ishaMinCtrl = TextEditingController(text: ishaMin.toString());
    final ishaMaxCtrl = TextEditingController(text: ishaMax.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            Widget buildChoiceChipGroup({
              required String label,
              required List<int> options,
              required int currentVal,
              required TextEditingController controller,
              required Function(int) onSelected,
            }) {
              final isDark = AppTheme.isDark;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: options.map((opt) {
                      final bool isSel = currentVal == opt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: InkWell(
                            onTap: () {
                              setDlgState(() {
                                onSelected(opt);
                                controller.text = opt.toString();
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.emerald : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? AppTheme.emerald : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  width: isSel ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                '$opt ${AppLocale.t(ur: 'منٹ', en: 'm')}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSel ? Colors.white : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: AppTheme.emerald,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocale.t(ur: 'یا دستی منٹ درج کریں:', en: 'Or enter custom minutes:'),
                            style: TextStyle(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 62,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.emerald, width: 1.2),
                          ),
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed > 0) {
                                setDlgState(() {
                                  onSelected(parsed);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocale.t(ur: 'منٹ', en: 'min'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final isDark = AppTheme.isDark;
            final sectionCardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);

            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.cardBorder),
              ),
              title: Text(
                AppLocale.t(ur: 'خودکار جماعت فارمولا ترتیبات', en: 'Dynamic Jama\'at Formula Settings'),
                style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fajr Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.t(
                                ur: '🌅 فجر (طلوعِ آفتاب سے قبل جماعت):',
                                en: '🌅 Fajr (Minutes before sunrise):',
                              ),
                              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'کم سے کم طلوع سے پہلے:', en: 'Minimum before sunrise:'),
                              options: [20, 25, 30, 35],
                              currentVal: fajrMin,
                              controller: fajrMinCtrl,
                              onSelected: (v) => fajrMin = v,
                            ),
                            const SizedBox(height: 10),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'زیادہ سے زیادہ طلوع سے پہلے:', en: 'Maximum before sunrise:'),
                              options: [25, 30, 35, 40],
                              currentVal: fajrMax,
                              controller: fajrMaxCtrl,
                              onSelected: (v) => fajrMax = v,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Zuhr Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('☀️ ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(
                                AppLocale.t(
                                  ur: 'فعال مسجد کے طے کیے گیا وقت ہی ہمیشہ لاگو رہے گا۔',
                                  en: 'The active mosque\'s set time will always apply.',
                                ),
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Asr Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.t(
                                ur: '🌤️ عصر (وقتِ ابتداء / اذان کے بعد):',
                                en: '🌤️ Asr (Minutes after Asr start / adhan):',
                              ),
                              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'کم سے کم بعد از اذان:', en: 'Minimum after adhan:'),
                              options: [5, 10, 15, 20],
                              currentVal: asrMin,
                              controller: asrMinCtrl,
                              onSelected: (v) => asrMin = v,
                            ),
                            const SizedBox(height: 10),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'زیادہ سے زیادہ بعد از اذان:', en: 'Maximum after adhan:'),
                              options: [15, 20, 25, 30],
                              currentVal: asrMax,
                              controller: asrMaxCtrl,
                              onSelected: (v) => asrMax = v,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Maghrib Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.t(
                                ur: '🌇 مغرب (غروبِ آفتاب کے بعد جماعت):',
                                en: '🌇 Maghrib (Minutes after sunset / adhan):',
                              ),
                              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'غروب کے بعد منٹ:', en: 'Minutes after sunset:'),
                              options: [3, 4, 5, 7],
                              currentVal: maghribAfter,
                              controller: maghribCtrl,
                              onSelected: (v) => maghribAfter = v,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Isha Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sectionCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocale.t(
                                ur: '🌌 عشاء (وقتِ ابتداء / اذان کے بعد):',
                                en: '🌌 Isha (Minutes after Isha start / adhan):',
                              ),
                              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 8),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'کم سے کم بعد از اذان:', en: 'Minimum after adhan:'),
                              options: [5, 10, 15, 20],
                              currentVal: ishaMin,
                              controller: ishaMinCtrl,
                              onSelected: (v) => ishaMin = v,
                            ),
                            const SizedBox(height: 10),
                            buildChoiceChipGroup(
                              label: AppLocale.t(ur: 'زیادہ سے زیادہ بعد از اذان:', en: 'Maximum after adhan:'),
                              options: [15, 20, 25, 30],
                              currentVal: ishaMax,
                              controller: ishaMaxCtrl,
                              onSelected: (v) => ishaMax = v,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    AppLocale.t(ur: 'محفوظ کریں', en: 'Save Rules'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final fMin = int.tryParse(fajrMinCtrl.text) ?? fajrMin;
                    final fMax = int.tryParse(fajrMaxCtrl.text) ?? fajrMax;
                    final aMin = int.tryParse(asrMinCtrl.text) ?? asrMin;
                    final aMax = int.tryParse(asrMaxCtrl.text) ?? asrMax;
                    final mAfter = int.tryParse(maghribCtrl.text) ?? maghribAfter;
                    final iMin = int.tryParse(ishaMinCtrl.text) ?? ishaMin;
                    final iMax = int.tryParse(ishaMaxCtrl.text) ?? ishaMax;

                    _settings.fajrDynamicMinBeforeSunrise = fMin;
                    _settings.fajrDynamicMaxBeforeSunrise = fMax;
                    _settings.asrDynamicMinAfter = aMin;
                    _settings.asrDynamicMaxAfter = aMax;
                    _settings.maghribDynamicAfter = mAfter;
                    _settings.ishaDynamicMinAfter = iMin;
                    _settings.ishaDynamicMaxAfter = iMax;

                    Navigator.pop(ctx);
                    _notifyChange();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.cardBorder),
      boxShadow: AppTheme.cardShadow,
    );
  }
}
