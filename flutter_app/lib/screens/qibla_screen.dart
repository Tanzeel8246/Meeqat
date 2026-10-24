import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/city_database.dart';
import '../core/qibla_calculator.dart';
import '../core/astronomical_engine.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../widgets/minaret_bottom_nav.dart';

class QiblaScreen extends StatefulWidget {
  final CityModel city;

  const QiblaScreen({super.key, required this.city});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _deviceHeading = 0.0;
  double _filteredHeading = 0.0;
  bool _isSensorActive = false;
  bool _hasVibratedForCurrentLock = false;

  // 3-axis accelerometer gravity vector for true 3D tilt compensation
  double _ax = 0.0;
  double _ay = 0.0;
  double _az = 9.8;

  // Fine-tuning calibration offset
  double _calibrationOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSensors();
  }

  void _initSensors() {
    try {
      final double declination = QiblaCalculator.calculateMagneticDeclination(
        widget.city.latitude,
        widget.city.longitude,
      );

      // Listen to accelerometer gravity vector to measure real-time pitch & roll tilts
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        (AccelerometerEvent event) {
          // Low-pass filter to reject vibrations and hand tremors
          _ax = _ax * 0.8 + event.x * 0.2;
          _ay = _ay * 0.8 + event.y * 0.2;
          _az = _az * 0.8 + event.z * 0.2;
        },
        onError: (_) {},
      );

      _magnetometerSubscription = magnetometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        (MagnetometerEvent event) {
          // 3D Tilt-Compensation vector algorithm:
          // G = normalized gravity vector pointing downwards
          double gNorm = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
          if (gNorm < 0.001) gNorm = 9.8;
          final double gx = _ax / gNorm;
          final double gy = _ay / gNorm;
          final double gz = _az / gNorm;

          // M = 3D magnetic field vector in phone frame
          final double mx = event.x;
          final double my = event.y;
          final double mz = event.z;

          // Horizontal East vector E = M x G (cross product)
          double ex = my * gz - mz * gy;
          double ey = mz * gx - mx * gz;
          double ez = mx * gy - my * gx;
          double eNorm = math.sqrt(ex * ex + ey * ey + ez * ez);

          double rawMagHeading;
          if (eNorm > 0.001) {
            ex /= eNorm;
            ey /= eNorm;
            ez /= eNorm;

            // Horizontal North vector N = G x E (cross product)
            double nx = gy * ez - gz * ey;
            double ny = gz * ex - gx * ez;
            double nz = gx * ey - gy * ex;
            double nNorm = math.sqrt(nx * nx + ny * ny + nz * nz);
            if (nNorm > 0.001) {
              nx /= nNorm;
              ny /= nNorm;
              nz /= nNorm;
            }

            // Phone forward vector Y=(0, 1, 0) projected on horizontal plane:
            // Forward East = ey; Forward North = ny;
            rawMagHeading = math.atan2(ey, ny) * (180.0 / math.pi);
          } else {
            // Flat fallback
            rawMagHeading = math.atan2(-mx, my) * (180.0 / math.pi);
          }

          if (rawMagHeading < 0) {
            rawMagHeading += 360.0;
          }

          // True geographic heading using WMM declination
          double trueHeading = (rawMagHeading + declination + _calibrationOffset + 360.0) % 360.0;

          // Angular low-pass filter smoothing with 0-360 wraparound
          double diff = trueHeading - _filteredHeading;
          if (diff > 180.0) diff -= 360.0;
          if (diff < -180.0) diff += 360.0;
          _filteredHeading = (_filteredHeading + 0.25 * diff + 360.0) % 360.0;

          if (mounted) {
            setState(() {
              _isSensorActive = true;
              _deviceHeading = double.parse(_filteredHeading.toStringAsFixed(1));
            });
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isSensorActive = false);
        },
      );
    } catch (_) {
      _isSensorActive = false;
    }
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qiblaData = QiblaCalculator.calculate(widget.city.latitude, widget.city.longitude);
    final double qiblaBearing = qiblaData['bearing'] as double;
    final double distanceKm = qiblaData['distance_km'] as double;
    final String cardinal = qiblaData['cardinal'] as String;

    // Relative needle angle = Qibla bearing minus current device heading
    final double relativeNeedleAngle = (qiblaBearing - _deviceHeading + 360.0) % 360.0;

    final engine = AstronomicalEngine(
      latitude: widget.city.latitude,
      longitude: widget.city.longitude,
      timeZone: widget.city.timezone,
    );
    final solarQiblaTimes = engine.calculateSolarQiblaTimes(_selectedDate, qiblaBearing);

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            AppLocale.t(ur: 'سمتِ قبلہ گائیڈ (Qibla Compass)', en: 'Qibla Direction Guide'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.emerald,
            labelColor: AppTheme.emerald,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(icon: const Icon(Icons.explore), text: AppLocale.t(ur: 'لائیو قبلہ کمپاس', en: 'Live Compass')),
              Tab(icon: const Icon(Icons.wb_sunny), text: AppLocale.t(ur: 'شمسی قبلہ معلومات', en: 'Solar Qibla')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildLiveCompassTab(qiblaBearing, relativeNeedleAngle, cardinal, distanceKm),
            _buildSolarQiblaTab(solarQiblaTimes),
          ],
        ),
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'qibla',
          city: widget.city,
        ),
      ),
    );
  }

  Widget _buildLiveCompassTab(double qiblaBearing, double needleAngle, String cardinal, double distanceKm) {
    final double alignmentDiff = (needleAngle % 360.0 > 180.0) ? 360.0 - (needleAngle % 360.0) : needleAngle % 360.0;
    final bool isAligned = alignmentDiff <= 3.5;

    // Haptic Snap on 0° Kaaba Lock
    if (isAligned && !_hasVibratedForCurrentLock) {
      _hasVibratedForCurrentLock = true;
      HapticFeedback.mediumImpact();
    } else if (!isAligned && _hasVibratedForCurrentLock) {
      _hasVibratedForCurrentLock = false;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // City info pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${widget.city.name}, ${widget.city.country} (${widget.city.latitude.toStringAsFixed(2)}°, ${widget.city.longitude.toStringAsFixed(2)}°)',
                  style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sensor Status & High-Frequency Sensitivity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _isSensorActive
                  ? (isAligned ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF10B981).withValues(alpha: 0.15))
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSensorActive ? (isAligned ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.6)) : Colors.amber,
                width: isAligned ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSensorActive ? Icons.sensors : Icons.touch_app,
                  size: 16,
                  color: _isSensorActive ? const Color(0xFF10B981) : Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  _isSensorActive
                      ? AppLocale.t(
                          ur: isAligned ? '🕋 قبلہ رخ لاک ہے! (100٪ درست سیدھ)' : 'سینسر فعال: تھری ڈی جھکاؤ درستگی (Ultra-Sensitive)',
                          en: isAligned ? '🕋 Kaaba Aligned (100% Accurate)' : 'Sensor Active: 3D Tilt-Compensated')
                      : AppLocale.t(
                          ur: 'دستی موڈ: انگلی سے ڈائل گھمائیں',
                          en: 'Manual Mode: Touch & drag to rotate'),
                  style: TextStyle(
                    color: _isSensorActive ? const Color(0xFF10B981) : Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dynamic Compass Dial with sensor auto-rotation
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _deviceHeading = (_deviceHeading + details.delta.dx * 0.5) % 360.0;
                if (_deviceHeading < 0) _deviceHeading += 360.0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF131D31),
                border: Border.all(
                  color: isAligned ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.5),
                  width: isAligned ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isAligned ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: isAligned ? 45 : 35,
                    spreadRadius: isAligned ? 8 : 6,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating Compass Dial based on device heading
                  Transform.rotate(
                    angle: -(_deviceHeading * (math.pi / 180.0)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          top: 14,
                          child: Text('N (شمال)',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const Positioned(
                          bottom: 14,
                          child: Text('S (جنوب)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        const Positioned(
                          left: 14,
                          child: Text('W (مغرب)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        const Positioned(
                          right: 14,
                          child: Text('E (مشرق)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),

                        // Degree ticks
                        for (int i = 0; i < 360; i += 30)
                          Transform.rotate(
                            angle: i * (math.pi / 180.0),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 32),
                                width: 2,
                                height: (i % 90 == 0) ? 14 : 7,
                                color: (i % 90 == 0) ? Colors.amber : Colors.white24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Fixed Target Qibla Needle (Always points accurately to Kaaba)
                  Transform.rotate(
                    angle: (needleAngle * (math.pi / 180.0)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isAligned ? 10 : 8,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAligned
                                  ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                  : [const Color(0xFFF59E0B), const Color(0xFF10B981)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Icon(Icons.navigation, color: isAligned ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 40),
                        const SizedBox(height: 35),
                      ],
                    ),
                  ),

                  // Center Kaaba Marker
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F172A),
                      border: Border.all(
                        color: isAligned ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        width: isAligned ? 3 : 2,
                      ),
                    ),
                    child: const Text('🕋', style: TextStyle(fontSize: 24)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Alignment status & heading readout
          Text(
            isAligned
                ? '🕋 ${AppLocale.t(ur: 'رخ بالکل سیدھا ہے (خانہ کعبہ کی سمت)', en: 'Perfect Alignment with Kaaba')}'
                : '${AppLocale.t(ur: 'موبائل کا رخ', en: 'Heading')}: ${_deviceHeading.toStringAsFixed(1)}° | ${AppLocale.t(ur: 'قبلہ فرق', en: 'Difference')}: ${alignmentDiff.toStringAsFixed(1)}°',
            style: TextStyle(
              color: isAligned ? const Color(0xFF10B981) : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Calibration fine-tuning row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: AppTheme.textSecondary, size: 20),
                tooltip: AppLocale.t(ur: '-1° کالیبریشن', en: '-1° Calibration'),
                onPressed: () => setState(() => _calibrationOffset -= 1.0),
              ),
              Text(
                '${AppLocale.t(ur: 'کالیبریشن', en: 'Offset')}: ${_calibrationOffset >= 0 ? '+' : ''}${_calibrationOffset.toStringAsFixed(0)}°',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppTheme.textSecondary, size: 20),
                tooltip: AppLocale.t(ur: '+1° کالیبریشن', en: '+1° Calibration'),
                onPressed: () => setState(() => _calibrationOffset += 1.0),
              ),
              if (_calibrationOffset != 0.0)
                TextButton(
                  onPressed: () => setState(() => _calibrationOffset = 0.0),
                  child: Text(AppLocale.t(ur: 'ری سیٹ', en: 'Reset'), style: TextStyle(color: AppTheme.emerald, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Qibla Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      AppLocale.t(ur: 'قبلہ ڈگری زاویہ', en: 'Qibla Bearing'),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${qiblaBearing.toStringAsFixed(1)}°',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    Text(cardinal, style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                  ],
                ),
                Container(width: 1, height: 50, color: AppTheme.border),
                Column(
                  children: [
                    Text(
                      AppLocale.t(ur: 'خانہ کعبہ سے فاصلہ', en: 'Kaaba Distance'),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(0)} km',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppLocale.t(ur: 'براستہ عظیم دائرہ', en: 'Great Circle'),
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolarQiblaTab(List<Map<String, dynamic>> solarTimes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner with "طریقہ سمجھیں" button
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppTheme.isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFECFDF5), const Color(0xFFF1F5F9)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocale.t(
                            ur: 'سورج کے سائے سے قبلہ درست کرنے کا طریقہ',
                            en: 'Solar Shadow Qibla Alignment Method'),
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocale.t(
                    ur: 'دن میں مخصوص اوقات پر عمودی لکڑی یا شاخص کے سائے کے ذریعے قطب نما (کمپاس) کی مقناطیسی غلطی سے پاک 100٪ درست سمتِ قبلہ معلوم کی جا سکتی ہے۔',
                    en: 'Using the shadow of a vertical stick at specific solar times gives 100% accurate Qibla direction free from magnetic compass errors.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.help_outline),
                  label: Text(
                    AppLocale.t(
                      ur: 'طریقہ سمجھیں (تفصیلی رہنمائی پاپ اپ)',
                      en: 'Understand Method (Detailed Guide)',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showSolarMethodDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Date Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppLocale.t(ur: 'تاریخ', en: 'Date')}: ${_selectedDate.day}-${_selectedDate.month}-${_selectedDate.year}',
                style: TextStyle(color: AppTheme.gold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: Icon(Icons.calendar_today, color: AppTheme.emerald, size: 18),
                label: Text(
                  AppLocale.t(ur: 'تاریخ تبدیل کریں', en: 'Change Date'),
                  style: TextStyle(color: AppTheme.emerald),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Solar Times Professional Cards
          ...solarTimes.map((item) {
            final bool isObservable = item['is_observable'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isObservable
                      ? AppTheme.emerald.withValues(alpha: 0.35)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocale.isUrdu
                              ? (item['title_ur'] ?? item['title'] as String)
                              : (item['title_en'] ?? item['title'] as String),
                          style: TextStyle(
                            color: AppTheme.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isObservable
                              ? AppTheme.emerald.withValues(alpha: 0.18)
                              : Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isObservable ? AppTheme.emerald : Colors.redAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          AppLocale.isUrdu
                              ? (item['time'] as String)
                              : (item['time_en'] ?? item['time'] as String),
                          style: TextStyle(
                            color: isObservable ? AppTheme.emerald : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocale.isUrdu
                        ? (item['description_ur'] ?? item['description'] as String)
                        : (item['description_en'] ?? item['description'] as String),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.compass_calibration, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${AppLocale.t(ur: 'شمسی زاویہ', en: 'Solar Azimuth')}: ${item['azimuth']}°',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showSolarMethodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.wb_sunny, color: AppTheme.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocale.t(ur: 'شمسی طریقہ سے قبلہ کا قطعی تعین', en: 'Solar Shadow Method Guide'),
                  style: TextStyle(color: AppTheme.gold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocale.t(
                    ur: 'لکڑی (شاخص) سے سمتِ قبلہ جانچنے کا مستند اصول:',
                    en: 'Authentic Principle for Solar Qibla Alignment:',
                  ),
                  style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocale.t(
                    ur: 'ایک بالکل ہموار اور سیدھی زمین پر ایک سیدھی لکڑی (شاخص یا شاقول) ۹۰ ڈگری پر کھڑی کریں۔ سورج کی روشنی میں اس کا سایہ واضح ہوگا۔',
                    en: 'Erect a vertical stick (gnomon) at a 90° angle on level ground. Its shadow will align precisely with astronomical bearings.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                Divider(color: AppTheme.border, height: 24),
                Text(
                  AppLocale.t(ur: '📐 0° اور 180° (عین سمتِ قبلہ)', en: '📐 0° and 180° (Direct Qibla Axis)'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocale.t(
                    ur: 'منتخب تاریخ کے بتائے گئے وقت پر جب سورج 0° پر ہو گا تو سورج کا رخ خود عین قبلہ کی سمت ہو گا۔ اور جب 180° پر ہو گا تو لکڑی کا سایہ عین خانہ کعبہ کی سیدھ پر پڑے گا۔',
                    en: 'At the forecasted time on the selected date: at 0°, the Sun aligns directly with Kaaba; at 180°, the shadow will point along the Kaaba axis.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocale.t(ur: '📐 90° عمودی زاویہ (صفوں کی سیدھ)', en: '📐 90° Perpendicular Angle (Prayer Rows)'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocale.t(
                    ur: 'اس وقت عمودی لکڑی کا سایہ قبلہ کی لائن کے عین عمودی (90 ڈگری) پر ہو گا۔ اس سائے کے متوازی زمین پر جو لکیر کھینچی جائے گی وہ مسجد کی صفوں کی بالکل سیدھی لکیر ہو گی!',
                    en: 'At this time, the stick shadow will lie at 90° perpendicular to Qibla. Drawing a line parallel to this shadow aligns prayer rows (Saf) precisely!',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocale.t(ur: '📐 135° ترچھا زاویہ (کارنر و محراب)', en: '📐 135° Diagonal Angle (Mihrab & Corners)'),
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocale.t(
                    ur: 'اس وقت سورج کا ترچھا رخ مسجد کے محراب اور عمارت کے کونوں کی سیدھ کی تصدیق کرے گا جس سے قبلہ رخ کا قطعی اطمینان ہو جائے گا۔',
                    en: 'At this time, the diagonal solar angle will verify corner angles and mihrab alignment with absolute certainty.',
                  ),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocale.t(ur: 'سمجھ آ گئی ✔', en: 'Understood ✔')),
            ),
          ],
        ),
      ),
    );
  }
}
