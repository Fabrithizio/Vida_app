import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/timeline_block.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'vida_app_timeline';
  static const String _channelName = 'Timeline';
  static const String _channelDescription =
      'Lembretes da timeline e testes de notificação';

  static const int _testNowId = 990001;
  static const int _testDelayId = 990002;
  static const int _testScheduledId = 990003;
  static const int _testTimelineId = 990004;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings);

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

    if (kDebugMode) {
      print('[notif] init ok | timezone=${tz.local.name}');
    }
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await init();
  }

  void _configureLocalTimeZone() {
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

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  int _idFromString(String value) => value.hashCode & 0x7fffffff;

  bool _supportsReminder(TimelineBlock block) {
    return block.type != TimelineBlockType.note;
  }

  Future<void> cancelForBlock(String blockId) async {
    await _ensureInit();
    await _plugin.cancel(_idFromString(blockId));

    if (kDebugMode) {
      print('[notif] cancel block=$blockId');
    }
  }

  Future<void> cancelTestNotifications() async {
    await _ensureInit();
    await _plugin.cancel(_testNowId);
    await _plugin.cancel(_testDelayId);
    await _plugin.cancel(_testScheduledId);
    await _plugin.cancel(_testTimelineId);

    if (kDebugMode) {
      print('[notif] cancel tests');
    }
  }

  Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();

    if (kDebugMode) {
      print('[notif] cancel all');
    }
  }

  Future<List<PendingNotificationRequest>> pendingRequests() async {
    await _ensureInit();
    return _plugin.pendingNotificationRequests();
  }

  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(id, title, body, _details());
  }

  Future<void> _scheduleSmart({
    required int id,
    required String title,
    required String body,
    required DateTime notifyAt,
  }) async {
    await _ensureInit();

    final now = DateTime.now();
    final diff = notifyAt.difference(now);

    if (kDebugMode) {
      print(
        '[notif] smart schedule | now=$now | notifyAt=$notifyAt | diff=${diff.inSeconds}s',
      );
    }

    if (diff.inSeconds <= 60) {
      final safeDelay = diff.isNegative ? const Duration(seconds: 1) : diff;

      unawaited(
        Future.delayed(safeDelay, () async {
          await _showNow(id: id, title: title, body: body);

          if (kDebugMode) {
            print('[notif] fired by delayed path | id=$id');
          }
        }),
      );

      return;
    }

    final when = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print('[notif] scheduled exact | id=$id | at=$notifyAt');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('[notif] exact failed, fallback to inexact: $e');
      }
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (kDebugMode) {
      print('[notif] scheduled inexact | id=$id | at=$notifyAt');
    }
  }

  Future<void> showTestNow() async {
    await _ensureInit();

    await _showNow(
      id: _testNowId,
      title: 'Teste imediato',
      body: 'Se você viu isso, a notificação imediata está funcionando.',
    );

    if (kDebugMode) {
      print('[notif] test now sent');
    }
  }

  Future<void> showDelayedForegroundTestIn5Seconds() async {
    await _ensureInit();

    await _scheduleSmart(
      id: _testDelayId,
      title: 'Teste com delay simples',
      body: 'Se isso chegou, o delay simples está funcionando.',
      notifyAt: DateTime.now().add(const Duration(seconds: 5)),
    );
  }

  Future<void> showScheduledTestIn10Seconds() async {
    await _ensureInit();

    await _scheduleSmart(
      id: _testScheduledId,
      title: 'Teste agendado em 10 segundos',
      body: 'Se isso chegou, o caminho inteligente está funcionando.',
      notifyAt: DateTime.now().add(const Duration(seconds: 10)),
    );
  }

  Future<void> showTimelineStyleTestIn10Seconds() async {
    await _ensureInit();

    final now = DateTime.now();

    final fakeBlock = TimelineBlock(
      id: 'debug-timeline-test',
      type: TimelineBlockType.event,
      title: 'Teste da timeline',
      start: now.add(const Duration(seconds: 10)),
      reminderMinutes: 1,
    );

    await scheduleForBlock(fakeBlock);

    if (kDebugMode) {
      print('[notif] timeline style test scheduled');
    }
  }

  Future<void> scheduleForBlock(TimelineBlock block) async {
    await _ensureInit();

    if (!_supportsReminder(block)) {
      if (kDebugMode) {
        print('[notif] skipped (type without reminder): ${block.type}');
      }
      return;
    }

    if (block.reminderMinutes <= 0) {
      if (kDebugMode) {
        print('[notif] skipped (reminderMinutes <= 0): ${block.title}');
      }
      return;
    }

    final now = DateTime.now();

    if (block.start.isBefore(now.subtract(const Duration(seconds: 30)))) {
      if (kDebugMode) {
        print('[notif] skipped past event: ${block.title}');
      }
      return;
    }

    final intendedNotifyAt = block.start.subtract(
      Duration(minutes: block.reminderMinutes),
    );

    final notifyAt =
        intendedNotifyAt.isBefore(now.add(const Duration(seconds: 3)))
        ? now.add(const Duration(seconds: 3))
        : intendedNotifyAt;

    final startsSoon =
        block.start.difference(now).inMinutes <= block.reminderMinutes;

    final title = startsSoon ? 'Evento começando' : 'Lembrete';
    final body = startsSoon ? '${block.title} começa em breve.' : block.title;

    final notificationId = _idFromString(block.id);

    await _scheduleSmart(
      id: notificationId,
      title: title,
      body: body,
      notifyAt: notifyAt,
    );
  }
}
