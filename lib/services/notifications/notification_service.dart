// ============================================================================
// FILE: lib/services/notifications/notification_service.dart
//
// O que faz:
// - inicializa notificações locais
// - agenda lembretes para blocos da timeline
//
// O que mudou:
// - adiciona scheduleForBlock() para compatibilidade
// - evita perder evento criado muito perto da hora
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:vida_app/data/models/timeline_block.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'vida_app_agenda';
  static const String _channelName = 'Agenda';
  static const String _channelDescription = 'Lembretes da agenda e timeline';

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

    if (kDebugMode) {
      print('NotificationService inicializado (tz.local=${tz.local.name})');
    }
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
    await scheduleTenMinutesBefore(block);
  }

  Future<void> scheduleTenMinutesBefore(TimelineBlock block) async {
    await _ensureInit();

    if (block.type != TimelineBlockType.event) return;

    final now = DateTime.now();

    if (block.start.isBefore(now.subtract(const Duration(seconds: 30)))) {
      if (kDebugMode) {
        print('Evento já passou, não agenda: ${block.title}');
      }
      return;
    }

    final rawNotifyAt = block.start.subtract(const Duration(minutes: 10));

    final notifyAt = rawNotifyAt.isBefore(now.add(const Duration(seconds: 5)))
        ? now.add(const Duration(seconds: 5))
        : rawNotifyAt;

    final startsSoon = block.start.difference(now).inMinutes <= 10;

    final title = startsSoon ? 'Evento começando' : 'Lembrete do evento';
    final body = startsSoon ? '${block.title} começa em breve.' : block.title;

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

    try {
      await _plugin.zonedSchedule(
        _idFromString(block.id),
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print('Notificação EXACT agendada: $notifyAt | ${block.title}');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('Falhou EXACT, tentando INEXACT. Erro: $e');
      }
    }

    await _plugin.zonedSchedule(
      _idFromString(block.id),
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (kDebugMode) {
      print('Notificação INEXACT agendada: $notifyAt | ${block.title}');
    }
  }
}
