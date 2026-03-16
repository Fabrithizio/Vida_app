// ============================================================================
// FILE: lib/main.dart
//
// Entry-point:
// - Firebase + Hive
// - Inicializa NotificationService (sem isso, schedule/cancel não faz nada)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'presentation/app/app.dart';
import 'services/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Hive.initFlutter();

  await NotificationService.instance.init();

  runApp(const VidaApp());
}
