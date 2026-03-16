// ============================================================================
// FILE: lib/services/notifications/notification_service.dart
//
// Serviço de notificações locais (Android):
// - init do plugin + canal + permissões
// - timezone (necessário para zonedSchedule)
// - agenda lembrete 10 minutos antes de eventos
//
// Fix importante:
// - Não descarta quando o notifyAt cai “em cima da hora” (tolerância de 30s)
// - Tenta exactAllowWhileIdle e se falhar cai para inexactAllowWhileIdle
// - Faz lazy init (se schedule for chamado antes do init, ele inicializa)
// ============================================================================

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
  static const String _channelDescription =
      'Lembretes da agenda (10 min antes)';

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
      // Depende da versão / OEM.
      // ignore: deprecated_member_use
      await android?.requestExactAlarmsPermission();
    } catch (_) {}

    _initialized = true;

    if (kDebugMode) {
      // ignore: avoid_print
      print('NotificationService OK (tz.local=${tz.local.name}).');
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

  Future<void> scheduleTenMinutesBefore(TimelineBlock block) async {
    await _ensureInit();

    if (block.type != TimelineBlockType.event) return;

    final notifyAt = block.start.subtract(const Duration(minutes: 10));

    // Tolerância: se cair “em cima da hora”, não descarta por milissegundos.
    final now = DateTime.now();
    if (notifyAt.isBefore(now.subtract(const Duration(seconds: 30)))) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Skip notify (passou): notifyAt=$notifyAt now=$now');
      }
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

    // 1) tenta EXACT
    try {
      await _plugin.zonedSchedule(
        _idFromString(block.id),
        'Lembrete (10 min)',
        block.title,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        // ignore: avoid_print
        print('Notificação EXACT agendada: $notifyAt | ${block.title}');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Falhou EXACT, tentando INEXACT. Erro: $e');
      }
    }

    // 2) fallback INEXACT (mais compatível)
    await _plugin.zonedSchedule(
      _idFromString(block.id),
      'Lembrete (10 min)',
      block.title,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (kDebugMode) {
      // ignore: avoid_print
      print('Notificação INEXACT agendada: $notifyAt | ${block.title}');
    }
  }
}
