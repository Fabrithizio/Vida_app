// FILE: lib/features/device/device_usage_service.dart
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Saves:
  /// - "$uid:screen_time"  => "<2h" / "2-4h" / "4-6h" / ">=6h"
  /// - "$uid:social_media" => "<1h" / "1-2h" / "2-4h" / ">=4h"
  /// - "$uid:night_use"    => "<0.5h" / "0.5-1h" / "1-2h" / ">=2h"
  ///
  /// Returns true if at least one value was updated.
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

    return updated;
  }

  Future<String?> readSaved(String keySuffix) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();
    final raw = (prefs.getString('$uid:$keySuffix') ?? '').trim();
    return raw.isEmpty ? null : raw;
  }
}
