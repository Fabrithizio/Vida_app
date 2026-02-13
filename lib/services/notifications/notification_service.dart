import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/timeline_block.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  int _idFromString(String s) => s.hashCode & 0x7fffffff;

  Future<void> cancelForBlock(String blockId) async {
    if (!_initialized) return;
    await _plugin.cancel(_idFromString(blockId));
  }

  Future<void> scheduleTenMinutesBefore(TimelineBlock block) async {
    if (!_initialized) return;

    if (block.type != TimelineBlockType.event) return;

    final notifyAt = block.start.subtract(const Duration(minutes: 10));
    if (notifyAt.isBefore(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vida_agenda',
        'Agenda',
        channelDescription: 'Lembretes da agenda (10 min antes)',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      _idFromString(block.id),
      'Lembrete (10 min)',
      block.title,
      tz.TZDateTime.from(notifyAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );

    if (kDebugMode) {
      // útil no debug pra confirmar o agendamento
      // ignore: avoid_print
      print('Notificação agendada para: $notifyAt (${block.title})');
    }
  }
}
