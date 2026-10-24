import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_locale.dart';
import 'app_theme.dart';

class UpdateService {
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mindcraftsai.meeqat';

  static bool _hasCheckedThisSession = false;

  /// Check for in-app updates automatically on startup.
  /// Runs silently if up-to-date or if outside Google Play environment.
  static Future<void> checkOnStartup(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    // Only Android devices running from Google Play support Play Core In-App Updates
    if (!Platform.isAndroid || kIsWeb) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (!context.mounted) return;
        _promptUserForUpdate(context, info);
      }
    } catch (e) {
      debugPrint('UpdateService checkOnStartup: $e');
    }
  }

  /// Manually check for updates (e.g. from Settings or About screen)
  static Future<void> checkManually(BuildContext context) async {
    if (!Platform.isAndroid || kIsWeb) {
      _showNotice(
        context,
        titleUr: 'معلوماتِ اپڈیٹ',
        titleEn: 'Update Info',
        messageUr: 'اینڈرائیڈ موبائل پر گوگل پلے اسٹور سے براہِ راست اپڈیٹ دستیاب ہے۔',
        messageEn: 'Updates for Android are available directly on Google Play Store.',
        showStoreButton: true,
      );
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (!context.mounted) return;
        _promptUserForUpdate(context, info);
      } else {
        if (!context.mounted) return;
        _showNotice(
          context,
          titleUr: 'کوئی اپڈیٹ دستیاب نہیں',
          titleEn: 'No Update Available',
          messageUr: 'آپ کے پاس مِیقات کا تازہ ترین ورژن پہلے سے انسٹال ہے۔',
          messageEn: 'You already have the latest version of Meeqat installed.',
        );
      }
    } catch (e) {
      debugPrint('UpdateService checkManually: $e');
      if (!context.mounted) return;
      _showNotice(
        context,
        titleUr: 'گوگل پلے اسٹور',
        titleEn: 'Google Play Store',
        messageUr: 'پلے اسٹور پر جا کر تصدیق کریں کہ آیا نئی اپڈیٹ پبلش ہو چکی ہے۔',
        messageEn: 'Please visit Google Play Store to verify published updates.',
        showStoreButton: true,
      );
    }
  }

  static void _promptUserForUpdate(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.emerald, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocale.t(
                    ur: 'مِیقات کی نئی اپڈیٹ دستیاب ہے!',
                    en: 'New Meeqat Update Available!',
                  ),
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
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
                  ur: 'مِیقات کا نیا اور بہتر ورژن پلے اسٹور پر دستیاب ہے۔ اہم ریلیز نوٹس (Release Notes):',
                  en: 'A newer, enhanced version of Meeqat is available on Google Play. Key Release Notes:',
                ),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '🏛️ ہوم اسکرین کلاک ویجٹ: لائیو سیکنڈز، نستعلیق خط، فروسٹڈ کیپسول اور تمام اوقاتِ صلوٰۃ مع نصف النہار',
                          en: '🏛️ Home Screen Clock Widget: Live seconds, Nastaleeq, frosted capsules & all prayer times',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '🕒 نیا کلاک پکر: مسجد جماعت کے اوقات سیٹ کرنے کے لیے آسان گھڑیال سلیکٹر (TimePicker)',
                          en: '🕒 New Clock Picker: Intuitive interactive TimePicker for setting Mosque Jama\'at times',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '🔔 نمازِ تہجد الارم: صبحِ صادق سے حسبِ منشا منٹ قبل الارم اور خودکار نوٹیفکیشن',
                          en: '🔔 Tahajjud Alarm: Customizable auto-waking minutes before dawn (Subh Sadiq)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '☀️ شمسی قبلہ رہنمائی و 3D کمپاس: سورج کے سائے سے 100٪ قطعی سمتِ قبلہ اور صفوں کا تعین',
                          en: '☀️ Solar Qibla & 3D Compass: 100% precise Qibla and Saf row alignment via solar shadow',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '🎨 لائٹ و ڈارک موڈ میں بہترین کنٹراسٹ: تمام اسکرینز اور ٹیکسٹ پر واضح اور خوبصورت بصری لک',
                          en: '🎨 High-Contrast Light & Dark Themes: Crystal clear text readability across all screens',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureBullet(
                        AppLocale.t(
                          ur: '🌍 عالمی تلاش و خودکار لوکیشن: دنیا کے کسی بھی مقام کی تیز رفتار اور مستند تلاش',
                          en: '🌍 Global Search & Location: Lightning fast and accurate worldwide location detection',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocale.t(ur: 'بعد میں', en: 'Later'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _startUpdateProcess(context, info);
              },
              child: Text(
                AppLocale.t(ur: 'ابھی اپڈیٹ کریں', en: 'Update Now'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _startUpdateProcess(BuildContext context, AppUpdateInfo info) async {
    try {
      if (info.flexibleUpdateAllowed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.surfaceElevated,
              content: Text(
                AppLocale.t(
                  ur: 'اپڈیٹ بیک گراؤنڈ میں ڈاؤنلوڈ ہو رہی ہے...',
                  en: 'Downloading update in the background...',
                ),
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          );
        }

        await InAppUpdate.startFlexibleUpdate();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 15),
              content: Text(
                AppLocale.t(
                  ur: '✅ نئی اپڈیٹ ڈاؤنلوڈ ہو گئی۔ انسٹال کرنے کے لیے کلک کریں۔',
                  en: '✅ Update downloaded. Click to install.',
                ),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              action: SnackBarAction(
                label: AppLocale.t(ur: 'انسٹال کریں', en: 'Install'),
                textColor: Colors.white,
                onPressed: () async {
                  await InAppUpdate.completeFlexibleUpdate();
                },
              ),
            ),
          );
        }
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        await openPlayStore();
      }
    } catch (e) {
      debugPrint('Failed to start in-app update: $e');
      await openPlayStore();
    }
  }

  static Future<void> openPlayStore() async {
    final uri = Uri.parse(playStoreUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  static void _showNotice(
    BuildContext context, {
    required String titleUr,
    required String titleEn,
    required String messageUr,
    required String messageEn,
    bool showStoreButton = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            AppLocale.t(ur: titleUr, en: titleEn),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            AppLocale.t(ur: messageUr, en: messageEn),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
          ),
          actions: [
            if (showStoreButton)
              TextButton.icon(
                icon: const Icon(Icons.shop, size: 16),
                label: Text(AppLocale.t(ur: 'پلے اسٹور کھولیں', en: 'Open Play Store')),
                style: TextButton.styleFrom(foregroundColor: AppTheme.emerald),
                onPressed: () {
                  Navigator.pop(ctx);
                  openPlayStore();
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocale.t(ur: 'ٹھیک ہے', en: 'OK'),
                style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildFeatureBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    );
  }
}
