import 'package:flutter/material.dart';
import 'core/alarm_service.dart';
import 'core/app_locale.dart';
import 'core/app_settings.dart';
import 'core/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings().init();
  await AlarmService.initNotifications();
  // Schedule native background Adhan alarms based on saved city & settings
  AlarmService.scheduleBackgroundPrayerAlarms();
  runApp(const MinaretApp());
}

class MinaretApp extends StatelessWidget {
  const MinaretApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLocale.isUrduNotifier,
      builder: (context, isUrdu, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppTheme.isDarkNotifier,
          builder: (context, isDark, _) {
            return MaterialApp(
              title: isUrdu ? 'المیقات' : 'Al-Meeqat',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getTheme(isUrdu: isUrdu, isDarkMode: isDark),
              builder: (context, child) {
                final media = MediaQuery.of(context);
                // Jameel Noori Nastaleeq has a lower natural x-height compared to Latin typography.
                // Applying 1.16x linear textScaler boost for Urdu ensures crisp, clear, and effortless readability.
                final scaledData = media.copyWith(
                  textScaler: isUrdu
                      ? const TextScaler.linear(1.16)
                      : const TextScaler.linear(1.0),
                );
                return MediaQuery(
                  data: scaledData,
                  child: Directionality(
                    textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                    child: child ?? const SizedBox(),
                  ),
                );
              },
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
