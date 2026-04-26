// FILE: lib/features/device/device_usage_service.dart
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceAppUsageEntry {
  const DeviceAppUsageEntry({required this.packageName, required this.minutes});

  final String packageName;
  final int minutes;
}

class DeviceUsageService {
  static const MethodChannel _channel = MethodChannel('vida_app/device_usage');

  // Social apps (Android package names)
  static const List<String> socialPackages = [
    'com.facebook.katana', // Facebook
    'com.google.android.youtube', // YouTube
    'com.whatsapp', // WhatsApp
    'com.instagram.android', // Instagram
    'com.zhiliaoapp.musically', // TikTok
    'com.smile.gifmaker', // Kwai
    'com.facebook.orca', // Messenger
    'com.twitter.android', // X (Twitter)
    'org.telegram.messenger', // Telegram
  ];

  // Positive / signal apps by category
  static const List<String> studyPackages = [
    'com.duolingo',
    'org.khanacademy.android',
    'com.coursera.android',
    'org.edx.mobile',
    'com.udemy.android',
    'com.google.android.apps.classroom',
    'com.todoist',
    'com.notion.id',
    'notion.id',
  ];

  static const List<String> financePackages = [
    'com.nu.production',
    'br.com.intermedium',
    'com.itau',
    'com.santander.app',
    'br.com.bb.android',
    'com.picpay',
    'com.mercadopago.wallet',
    'com.paypal.android.p2pmobile',
    'br.com.guiabolso',
    'br.com.mobills.mobills',
  ];

  static const List<String> focusPackages = [
    'com.forestapp',
    'cc.forestapp',
    'com.ticktick.task',
    'com.anydo',
    'com.todoist',
    'com.google.android.keep',
    'notion.id',
    'com.notion.id',
    'com.microsoft.todos',
  ];

  static const List<String> meditationPackages = [
    'com.getsomeheadspace.android',
    'com.calm.android',
    'org.woheller69.meditationassistant',
    'com.insighttimer',
  ];

  static const List<String> fitnessPackages = [
    'com.google.android.apps.fitness',
    'com.strava',
    'com.fitbit.FitbitMobile',
    'com.myfitnesspal.android',
    'com.samsung.android.app.health',
    'com.nike.plusgps',
  ];

  // Night window: 19:00 -> 04:00
  static const int nightStartHour = 19;
  static const int nightEndHour = 4;

  Future<bool> isAndroidSupported() async => Platform.isAndroid;

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('hasUsageAccess');
    return ok ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  Future<int?> getTodayScreenTimeMinutes() async {
    if (!Platform.isAndroid) return null;
    final minutes = await _channel.invokeMethod<int>(
      'getTodayScreenTimeMinutes',
    );
    return minutes;
  }

  Future<int?> getTodaySocialMediaMinutes() async {
    if (!Platform.isAndroid) return null;
    final minutes = await _channel.invokeMethod<int>(
      'getTodaySocialMediaMinutes',
      <String, dynamic>{'packages': socialPackages},
    );
    return minutes;
  }

  Future<int?> getTodayNightUseMinutes() async {
    if (!Platform.isAndroid) return null;
    final minutes = await _channel.invokeMethod<int>(
      'getTodayNightUseMinutes',
      <String, dynamic>{'startHour': nightStartHour, 'endHour': nightEndHour},
    );
    return minutes;
  }

  Future<List<DeviceAppUsageEntry>> getTodayUsageByPackages(
    List<String> packages,
  ) async {
    if (!Platform.isAndroid || packages.isEmpty) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'getTodayUsageByPackages',
      <String, dynamic>{'packages': packages},
    );

    if (raw == null) return const [];

    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return DeviceAppUsageEntry(
            packageName: (map['packageName'] ?? '').toString(),
            minutes: (map['minutes'] as num?)?.toInt() ?? 0,
          );
        })
        .where(
          (entry) => entry.packageName.trim().isNotEmpty && entry.minutes > 0,
        )
        .toList();
  }

  Future<int> getTodayCategoryMinutes(List<String> packages) async {
    final entries = await getTodayUsageByPackages(packages);
    return entries.fold<int>(0, (sum, entry) => sum + entry.minutes);
  }

  /// "<2h", "2-4h", "4-6h", ">=6h"
  String bucketizeScreenTime(int minutes) {
    final h = minutes / 60.0;
    if (h < 2.0) return '<2h';
    if (h < 4.0) return '2-4h';
    if (h < 6.0) return '4-6h';
    return '>=6h';
  }

  /// "<1h", "1-2h", "2-4h", ">=4h"
  String bucketizeSocialMedia(int minutes) {
    final h = minutes / 60.0;
    if (h < 1.0) return '<1h';
    if (h < 2.0) return '1-2h';
    if (h < 4.0) return '2-4h';
    return '>=4h';
  }

  /// "<0.5h", "0.5-1h", "1-2h", ">=2h"
  String bucketizeNightUse(int minutes) {
    final h = minutes / 60.0;
    if (h < 0.5) return '<0.5h';
    if (h < 1.0) return '0.5-1h';
    if (h < 2.0) return '1-2h';
    return '>=2h';
  }

  double _capRatio(int minutes, int usefulCapMinutes) {
    if (usefulCapMinutes <= 0) return 0;
    return (minutes / usefulCapMinutes).clamp(0.0, 1.0);
  }

  /// 0..100, com teto útil baixo/moderado para evitar distorção.
  int scoreStudyApps(int minutes) => (_capRatio(minutes, 25) * 100).round();

  int scoreFinanceApps(int minutes) => (_capRatio(minutes, 12) * 100).round();

  int scoreFocusApps(int minutes) => (_capRatio(minutes, 18) * 100).round();

  int scoreMeditationApps(int minutes) =>
      (_capRatio(minutes, 15) * 100).round();

  int scoreFitnessApps(int minutes) => (_capRatio(minutes, 20) * 100).round();

  Future<bool> refreshAndPersistDigitalBuckets() async {
    if (!Platform.isAndroid) return false;

    final ok = await hasUsageAccess();
    if (!ok) return false;

    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();

    bool updated = false;

    final totalMin = await getTodayScreenTimeMinutes();
    if (totalMin != null) {
      await prefs.setString('$uid:screen_time', bucketizeScreenTime(totalMin));
      updated = true;
    }

    final socialMin = await getTodaySocialMediaMinutes();
    if (socialMin != null) {
      await prefs.setString(
        '$uid:social_media',
        bucketizeSocialMedia(socialMin),
      );
      updated = true;
    }

    final nightMin = await getTodayNightUseMinutes();
    if (nightMin != null) {
      await prefs.setString('$uid:night_use', bucketizeNightUse(nightMin));
      updated = true;
    }

    final studyMin = await getTodayCategoryMinutes(studyPackages);
    await prefs.setInt('$uid:app_usage_study_minutes', studyMin);
    await prefs.setInt('$uid:app_usage_study_score', scoreStudyApps(studyMin));

    final financeMin = await getTodayCategoryMinutes(financePackages);
    await prefs.setInt('$uid:app_usage_finance_minutes', financeMin);
    await prefs.setInt(
      '$uid:app_usage_finance_score',
      scoreFinanceApps(financeMin),
    );

    final focusMin = await getTodayCategoryMinutes(focusPackages);
    await prefs.setInt('$uid:app_usage_focus_minutes', focusMin);
    await prefs.setInt('$uid:app_usage_focus_score', scoreFocusApps(focusMin));

    final meditationMin = await getTodayCategoryMinutes(meditationPackages);
    await prefs.setInt('$uid:app_usage_meditation_minutes', meditationMin);
    await prefs.setInt(
      '$uid:app_usage_meditation_score',
      scoreMeditationApps(meditationMin),
    );

    final fitnessMin = await getTodayCategoryMinutes(fitnessPackages);
    await prefs.setInt('$uid:app_usage_fitness_minutes', fitnessMin);
    await prefs.setInt(
      '$uid:app_usage_fitness_score',
      scoreFitnessApps(fitnessMin),
    );

    await prefs.setString(
      '$uid:app_usage_categories_updated_at',
      DateTime.now().toIso8601String(),
    );

    return true;
  }

  Future<String?> readSaved(String keySuffix) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();
    final raw = (prefs.getString('$uid:$keySuffix') ?? '').trim();
    return raw.isEmpty ? null : raw;
  }

  Future<int?> readSavedInt(String keySuffix) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();
    return prefs.getInt('$uid:$keySuffix');
  }
}
