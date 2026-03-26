import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/timeline_block.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'axyo_agenda';
  static const String _channelName = 'Agenda';
  static const String _channelDescription = 'Lembretes da agenda';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _configureLocalTimeZoneFallback();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );

    await android?.requestNotificationsPermission();

    try {
      // ignore: deprecated_member_use
      await android?.requestExactAlarmsPermission();
    } catch (_) {}

    _initialized = true;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await init();
  }

  void _configureLocalTimeZoneFallback() {
    try {
      tz.setLocalLocation(tz.getLocation('America/Recife'));
      return;
    } catch (_) {}
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      return;
    } catch (_) {}
    tz.setLocalLocation(tz.UTC);
  }

  int _idFromString(String s) => s.hashCode & 0x7fffffff;

  Future<void> cancelForBlock(String blockId) async {
    await _ensureInit();
    await _plugin.cancel(_idFromString(blockId));
  }

  Future<void> scheduleForBlock(TimelineBlock block) async {
    await _ensureInit();

    if (block.type == TimelineBlockType.note) return;
    if (block.reminderMinutes <= 0) return;

    final notifyAt = block.start.subtract(
      Duration(minutes: block.reminderMinutes),
    );
    final now = DateTime.now();

    if (notifyAt.isBefore(now.subtract(const Duration(seconds: 30)))) {
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    final when = tz.TZDateTime.from(notifyAt, tz.local);
    final title = block.reminderMinutes == 10
        ? 'Lembrete (10 min)'
        : 'Lembrete';

    try {
      await _plugin.zonedSchedule(
        _idFromString(block.id),
        title,
        block.title,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Falhou EXACT, tentando INEXACT. Erro: $e');
      }
    }

    await _plugin.zonedSchedule(
      _idFromString(block.id),
      title,
      block.title,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
